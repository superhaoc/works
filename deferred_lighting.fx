#pragma dcl position texcoord0 texcoord1

#define DEFERRED_UNPACK_LIGHT

#define SPECULAR 1
#define REFLECT 1
#define REFLECT_DYNAMIC 1

#include "../common.fxh"

//Need to include this on PC for puddle define.
#include "../../vfx/vfx_shared.h"

// We don't care for no skinning matrices here, so we can use a bigger constant register file
#pragma constant 130

#include "lighting.fxh"
#include "Lights/light_structs.fxh"

// =============================================================================================== //
// VARIABLES
// =============================================================================================== //

BeginConstantBufferDX10(deferred_lighting_locals)

float4 skinColourTweak = float4(1.0, 1.0, 1.0, 1.0);
float4 skinParams = float4(0.0, 0.0, 0.0, 0.0);

float4 rimLightingParams = float4(0.3, 0.9, 0.0, 0.3);
float4 rimLightingMainColourAndIntensity = float4(0.0f, 0.0f, 0.0f, 0.0f);
float4 rimLightingOffAngleColourAndIntensity = float4(0.0f, 0.0f, 0.0f, 0.0f);
float3 rimLightingLightDirection = float3(0.0f, 0.0f, -1.0f);

EndConstantBufferDX10(deferred_lighting_locals)

#if MULTISAMPLE_TECHNIQUES && ENABLE_PED_PASS_AA_SOURCE
Texture2DMS<float4> deferredLightTextureAA;
#endif	//MULTISAMPLE_TECHNIQUES && ENABLE_PED_PASS_AA_SOURCE

#define MIN_FALLOFF_VOLUME_RADIUS (0.662f)

// =============================================================================================== //
// DATA STRUCTURES
// =============================================================================================== //

struct vertexInputLP
{
	float3	pos					: POSITION;		// Local-space position
};

struct vertexOutputLPS
{
	DECLARE_POSITION(pos)		// input expected in viewport space 0 to 1
	float4 screenPos			: TEXCOORD0;
	float4 eyeRay				: TEXCOORD1;		
};

struct vertexOutputVolumeLPP
{
	DECLARE_POSITION(pos)		// input expected in viewport space 0 to 1
	float4 screenPos			: TEXCOORD0;			
	float4 eyeRay				: TEXCOORD1;		
};

struct vertexInputVolume
{
	float3	pos					: POSITION;		// Local-space position
	float4	col					: COLOR0;
};

struct pixelInputLPS
{
	DECLARE_POSITION_PSIN(pos)
	float4 screenPos			: TEXCOORD0;			
	float4 eyeRay				: TEXCOORD1;
#if SAMPLE_FREQUENCY
	uint sampleIndex			: SV_SampleIndex;
#endif
};

struct pixelInputLPP
{
	DECLARE_POSITION_PSIN(vPos)	// Fragment window position
	float4 eyeRay				: TEXCOORD0;	
};

struct vertexInputLPT
{
	float3	pos					: POSITION;		
	float4	tex					: TEXCOORD0;		
};

struct vertexOutputLPT
{
	DECLARE_POSITION(pos)		// input expected in viewport space 0 to 1
	float4	tex					: TEXCOORD0;
};

// =============================================================================================== //
// VS FUNCTIONS
// =============================================================================================== //

vertexOutputLPS VS_screenTransformS(vertexInputLP IN)
{
    vertexOutputLPS OUT;
	OUT.pos	= float4((IN.pos.xy - 0.5f) * 2.0f, 0, 1); //adjust from viewport space (0 to 1) to screen space (-1 to 1)
	OUT.screenPos = convertToVpos(OUT.pos, deferredLightScreenSize);
	OUT.eyeRay = GetEyeRay(OUT.pos.xy);
	
	return(OUT);
}

// ----------------------------------------------------------------------------------------------- //
#if __XENON
// ----------------------------------------------------------------------------------------------- //

vertexOutputLPT VS_screenTransformT(vertexInputLPT IN)
{
    vertexOutputLPT OUT;

    OUT.pos		= float4( (IN.pos.xy-0.5f)*2.0f, 0, 1); //adjust from viewport space (0 to 1) to screen space (-1 to 1)
	OUT.tex		= IN.tex;
	
	return(OUT);
}

// ----------------------------------------------------------------------------------------------- //
#endif // __XENON
// ----------------------------------------------------------------------------------------------- //

vertexOutputVolumeLPP VS_volumeTransformP(vertexInputVolume IN)
{
    vertexOutputVolumeLPP OUT;

    OUT.pos	= mul(float4(IN.pos, 1), gWorldViewProj);	
	OUT.eyeRay = float4((IN.pos - (gViewInverse[3].xyz+StereoWorldCamOffSet())), OUT.pos.w);
	OUT.screenPos = convertToVpos(MonoToStereoClipSpace(OUT.pos), deferredLightScreenSize);

	return(OUT);
}

// ----------------------------------------------------------------------------------------------- //

vertexOutputVolumeLPP VS_volumeTransformPSP(vertexInputVolume IN)
{
    vertexOutputVolumeLPP OUT;

	float3 vpos = normalize(IN.pos.xyz) * (deferredLightRadius + 0.1) + deferredLightPosition;

    OUT.pos	= mul(float4(vpos, 1), gWorldViewProj);	
	OUT.eyeRay = float4((vpos - (gViewInverse[3].xyz+StereoWorldCamOffSet())), OUT.pos.w);
	OUT.screenPos = convertToVpos(MonoToStereoClipSpace(OUT.pos), deferredLightScreenSize);

	return(OUT);
}

// ----------------------------------------------------------------------------------------------- //
// Ped skin pass
// ----------------------------------------------------------------------------------------------- //

// Xenon uses a packed 7e3 integer buffer format so we need to sample differently
#if __XENON
	float4 SamplePedSkin( sampler2D sSampler, float2 vUV ) { return PointSample7e3( sSampler, vUV, true ); }
#else
	half4 SamplePedSkin( sampler2D sSampler, float2 vUV ) { return h4tex2D(sSampler, vUV); } 
#endif	//__XENON

half4 SamplePedSkinAA( float2 vScreenCoords, uint sampleIndex )	{
#if MULTISAMPLE_TECHNIQUES && ENABLE_PED_PASS_AA_SOURCE
	//Warning: no bilinear interpolation here
	return deferredLightTextureAA.Load( int2(vScreenCoords), sampleIndex );
#else
	return SamplePedSkin( gDeferredLightSampler, convertToNormalizedScreenPos(vScreenCoords,deferredLightScreenSize) );
#endif //MULTISAMPLE_TECHNIQUES && ENABLE_PED_PASS_AA_SOURCE
}

float4 SamplePedSkinForward( sampler2D sSampler, float2 vUV ) 
{
	return h4tex2D(sSampler, vUV);
}

// ----------------------------------------------------------------------------------------------- //
// ped skin pass
// http://giga.cps.unizar.es/~diegog/ficheros/pdf_papers/TAP_Jimenez_LR.pdf
// ----------------------------------------------------------------------------------------------- //

#define _USE_LARGER_TERMINUS 1

// ----------------------------------------------------------------------------------------------- //
// currently only used for ped mugshots and rendering peds as part of ui
// manual gamma encoding/decoding assuming output to rgba8
half4 PS_pedPassForward(pixelInputLPS IN) : COLOR
{
	float2 screenPos = IN.screenPos.xy;	
	half4 colorM = SamplePedSkinForward(gDeferredLightSampler, screenPos.xy);
	half alphaScale= 1.f/gInvColorExpBias;

#if __XENON 
	[branch]
#endif
	if ( (colorM.a*alphaScale)>=0.95 )
	{
		DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy, IN.eyeRay, true, SAMPLE_INDEX);	
		half3 V = normalize(gViewInverse[3].xyz - surfaceInfo.positionWorld.xyz);
		half NdotV = saturate(dot(surfaceInfo.normalWorld,V));

		float ood4=skinParams.w/(-surfaceInfo.depth);

		// calculate teh anisotropic effect
		half ansioEffect= sqrt(NdotV);

		half angle=dot(IN.screenPos.xy, float2( 3.0f*deferredLightScreenSize.x, 1.424*3.0f*deferredLightScreenSize.y ));
#if __PSSL
		float2 scx;
#else
		half2 scx;
#endif
		sincos(angle, scx.x, scx.y);
		half2 scale=float2(deferredLightScreenSize.z,deferredLightScreenSize.w)*ood4 * ansioEffect; 

		half2 toff0 = half2(scx.y,-scx.x)*1.00f*scale; 
		half2 toff1 = half2(scx.x, scx.y)*0.75f*scale; 
		half2 toff2 = half2(-scx.y,scx.x)*0.50f*scale;
		half2 toff3 = half2(-scx.x,-scx.y)*0.25f*scale;

		half4	color0=SamplePedSkinForward(gDeferredLightSampler, screenPos.xy+toff0);
		half4	color1=SamplePedSkinForward(gDeferredLightSampler, screenPos.xy+toff1);
		half4	color2=SamplePedSkinForward(gDeferredLightSampler, screenPos.xy+toff2);
		half4	color3=SamplePedSkinForward(gDeferredLightSampler, screenPos.xy+toff3);

		color0.a=1.f-color0.a*alphaScale;
		color1.a=1.f-color1.a*alphaScale;
		color2.a=1.f-color2.a*alphaScale;
		color3.a=1.f-color3.a*alphaScale;

#if !_USE_LARGER_TERMINUS
		// from http://http.developer.nvidia.com/GPUGems3/gpugems3_ch14.html
		// table is http://http.developer.nvidia.com/GPUGems3/elementLinks/14fig13.jpg
		half3	color=colorM.rgb*half3(0.3f,0.6f,0.7f);
		color.rgb += lerp(color0.rgb, colorM.rgb, color0.a) * half3(0.1f, 0.00f,  0.00f) * skinColourTweak.rgb;	
		color.rgb += lerp(color1.rgb, colorM.rgb, color1.a) * half3(0.3f, 0.005f, 0.00f) * skinColourTweak.rgb;	
		color.rgb += lerp(color2.rgb, colorM.rgb, color2.a) * half3(0.2f, 0.1f,   0.01f) * skinColourTweak.rgb;	
		color.rgb += lerp(color3.rgb, colorM.rgb, color3.a) * half3(0.1f, 0.3f,   0.3f ) * skinColourTweak.rgb;
#else
		half2 toff4 = half2(-scx.x,-scx.y)*1.25f*scale; 
		half4	color4=SamplePedSkinForward(gDeferredLightSampler, screenPos.xy+toff4);
		color4.a=1.f-color4.a*alphaScale;

		half3	color;
		color.rgb = lerp(color3.rgb, colorM.rgb, color3.a) * half3(0.1f,   0.336f, 0.344f) ;
		color.rgb += lerp(color2.rgb, colorM.rgb, color2.a) * half3(0.118f, 0.198f, 0.0f  );	
		color.rgb += lerp(color1.rgb, colorM.rgb, color1.a) * half3(0.113f, 0.007f, 0.007f);	
		color.rgb += lerp(color0.rgb, colorM.rgb, color0.a) * half3(0.258f, 0.004f, 0.00f );	
		color.rgb += lerp(color4.rgb, colorM.rgb, color4.a) * half3(0.178f, 0.00f,  0.00f );
		color.rgb *=skinColourTweak.rgb;
		color += colorM.rgb*half3(0.2333f,0.455f,0.649f);
#endif
		colorM.rgb = lerp(colorM.rgb,color.rgb,skinParams.x);
	}

	return half4(colorM.rgb,1.f);
}

half4 ApplySSS(DeferredSurfaceInfo surfaceInfo, float2 screenPos, float alphaScale)
{
	half4 colorM = h4tex2D(gDeferredLightSampler, screenPos.xy);

	half stepDistance = (skinParams.w * 2.0f) / surfaceInfo.depth;

	if( stepDistance > 0.0 )
	{
				
		const float2 kernel[] = {	float2(-0.8762432f, -0.4074134f),
									float2(-0.1810252f, -0.3849372f),
									float2(-0.2148303f, 0.2538336f),
									float2(-0.5679384f, -0.7737637f),
									float2(-0.8410882f, 0.284752f),
									float2(0.2504667f, -0.7786502f),
									float2(0.2241588f, 0.02291071f),
									float2(0.0774181f, 0.8809837f),
									float2(-0.3951734f, 0.8704594f),
									float2(0.6154138f, 0.6576104f),
									float2(0.6783317f, 0.1708183f),
									float2(0.6315731f, -0.4340712f) 
								};

		float3 skin_kernel[] = {	float3(0.395562, 0.817392, 0.930767),
									float3(0.0311902, 0.00106172, 0.000313938),
									float3(0.0767408, 0.0273962, 0.00450141),
									float3(0.0871975, 0.0473179, 0.0143271),
									float3(0.0315923, 0.00109697, 0.000322965),
									float3(0.0362654, 0.00161671, 0.000436185),
									float3(0.0412312, 0.00246015, 0.000571736),
									float3(0.100745, 0.0887246, 0.0460233),
									float3(0.036511, 0.00165053, 0.000442538),
									float3(0.0318329, 0.00111868, 0.000328423),
									float3(0.0354102, 0.00150454, 0.000414361),
									float3(0.0505692, 0.00524901, 0.000862699),
									float3(0.0451516, 0.00341053, 0.000688329),
								};
		
		float2 scl = deferredLightScreenSize.zw * stepDistance;

		half3 colorSum = colorM.rgb * skin_kernel[0].rgb;

		[unroll]
		for(int i = 0; i < 12; i++)
		{
			float2 texcoord = screenPos.xy + kernel[i].xy * scl;
			float4 color = tex2Dlod(gDeferredLightSampler, float4(texcoord, 0, 0));
			color.a = 1.f-color.a*alphaScale;
			colorSum.rgb += (lerp(color.rgb, colorM.rgb, color.a))  * skin_kernel[i+1].rgb * skinColourTweak.rgb;
		}
		colorM.rgb = colorSum;
	}
	
	return half4(colorM.rgb,1.f);
}

half4 ApplySSS_HQ(DeferredSurfaceInfo surfaceInfo, float2 screenPos, float alphaScale)
{
	half4 colorM = h4tex2D(gDeferredLightSampler, screenPos.xy);

	half stepDistance = (skinParams.w * 2.0f) / surfaceInfo.depth;

	if( stepDistance > 0.0 )
	{
		const float2 kernel[] = { -0.2575131f, -0.4922407f,
			0.1497757f, -0.573093f,
			-0.6675736f, -0.2110253f,
			-0.5622158f, -0.5933861f,
			0.1165013f, -0.1860182f,
			-0.3867628f, -0.008587286f,
			-0.1591922f, -0.926185f,
			0.2494298f, -0.9505377f,
			-0.04154111f, 0.3890864f,
			0.4382282f, -0.05355268f,
			0.6731939f, -0.2738783f,
			0.4363976f, -0.7001255f,
			0.2887293f, 0.290032f,
			0.5984002f, 0.3222849f,
			0.8745571f, 0.08762114f,
			-0.5164875f, 0.5480965f,
			0.3013394f, 0.8343891f,
			-0.2496107f, 0.7112091f,
			-0.9371399f, 0.05445378f,
			0.7789275f, 0.5770676f,
			-0.8432912f, 0.4995143f,
			-0.6268807f, 0.2339009f };
		float3 skin_kernel[] = {
			float3(0.256081, 0.744502, 0.918),
			float3(0.041131, 0.0117272, 0.00145853),
			float3(0.0388776, 0.00939243, 0.00123367),
			float3(0.0327039, 0.00476174, 0.00084912),
			float3(0.0267169, 0.00224791, 0.000564964),
			float3(0.0657234, 0.083444, 0.0478776),
			float3(0.0524064, 0.0312202, 0.00713476),
			float3(0.0212696, 0.00110794, 0.000347231),
			float3(0.0195455, 0.000892224, 0.000288029),
			float3(0.0520868, 0.0304185, 0.00674634),
			float3(0.0485706, 0.0227409, 0.00368627),
			float3(0.0312774, 0.00400935, 0.000777257),
			float3(0.0263567, 0.00214485, 0.000549277),
			float3(0.0508095, 0.0273963, 0.00539477),
			float3(0.0338265, 0.00543116, 0.000908126),
			float3(0.0238781, 0.0015514, 0.000446057),
			float3(0.029906, 0.00338265, 0.000710788),
			float3(0.023515, 0.0014797, 0.000431667),
			float3(0.0298735, 0.00336887, 0.00070924),
			float3(0.0213128, 0.00111404, 0.000348778),
			float3(0.0200698, 0.000952366, 0.000305491),
			float3(0.0196467, 0.000903489, 0.000291362),
			float3(0.0344157, 0.00581119, 0.000940208),
		};

		float2 scl = deferredLightScreenSize.zw * stepDistance;

		half3 colorSum = colorM.rgb * skin_kernel[0].rgb;

		[unroll]
		for(int i = 0; i < 22; i++)
		{
			float2 texcoord = screenPos.xy + kernel[i].xy * scl;
			float4 color = tex2Dlod(gDeferredLightSampler, float4(texcoord, 0, 0));
			color.a = 1.f-color.a*alphaScale;
			colorSum.rgb += (lerp(color.rgb, colorM.rgb, color.a))  * skin_kernel[i+1].rgb * skinColourTweak.rgb;
		}
		colorM.rgb = colorSum;
	}

	return half4(colorM.rgb,1.f);
}

// ----------------------------------------------------------------------------------------------- //
half4 PS_pedSkinPassCommonNG( pixelInputLPS IN, bool bCopyEntirePed, bool useHQBlur )
{
	half4 colorM = SamplePedSkinAA(IN.pos.xy, SAMPLE_INDEX);
	half alphaScale= 1.f/gInvColorExpBias;

	if (bCopyEntirePed)
	{
		if ((colorM.a*alphaScale) < 0.95 )
		{
			return half4(colorM.rgb, 1.0f);
		}
	}
	else
	{
		// Early out if: (colorM.a*alphaScale) < 0.95. 
		//clip( (colorM.a*alphaScale) - 0.95 );

		// We've configured the alpha blender to emulate a clip if SrcAlpha==0. This way early-stencil stays enabled (issuing a discard was disabling early-stencil on NG consoles).
		if ( 0.95 > (colorM.a*alphaScale) )
		{
			return half4(0,0,0,0); 
		}
	}

	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy, IN.eyeRay, true, SAMPLE_INDEX);		
	
	half3 color;
	if(useHQBlur)
	{
		color	= ApplySSS_HQ(surfaceInfo, IN.screenPos.xy, alphaScale);
	}
	else
	{
		color	= ApplySSS(surfaceInfo, IN.screenPos.xy, alphaScale);
	}
	
	colorM.rgb = lerp(colorM.rgb,color.rgb,skinParams.x);

	return half4(colorM.rgb, 1.0f);
}

// ----------------------------------------------------------------------------------------------- //
half4 PS_pedSkinPassCommon( pixelInputLPS IN, bool bCopyEntirePed )
{
	half4 colorM = SamplePedSkinAA(IN.pos.xy, SAMPLE_INDEX);
	half alphaScale= 1.f/gInvColorExpBias;

	if (bCopyEntirePed)
	{
		if ((colorM.a*alphaScale) < 0.95 )
		{
			return half4(colorM.rgb, 1.0f);
		}
	}
	else
	{
		// Early out if: (colorM.a*alphaScale) < 0.95. 
		//clip( (colorM.a*alphaScale) - 0.95 );

		// We've configured the alpha blender to emulate a clip if SrcAlpha==0. This way early-stencil stays enabled (issuing a discard was disabling early-stencil on NG consoles).
		if ( 0.95 > (colorM.a*alphaScale) )
		{
			return half4(0,0,0,0); 
		}
	}

	// no need to branch, since we clip above.
	//if ( (colorM.a*alphaScale) >= 0.95 )
	{
		DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy, IN.eyeRay, true, SAMPLE_INDEX);	
		half3 V = normalize(gViewInverse[3].xyz - surfaceInfo.positionWorld.xyz);
		half NdotV = saturate(dot(surfaceInfo.normalWorld,V));

		float ood4=skinParams.w/(-surfaceInfo.depth);

		// calculate teh anisotropic effect
		half ansioEffect= sqrt(NdotV);

		half angle=dot(IN.screenPos.xy, float2( 3.0f*deferredLightScreenSize.x, 1.424*3.0f*deferredLightScreenSize.y ));
		half2 scx;
		sincos(angle, scx.x, scx.y);
		half2 scale = ood4 * ansioEffect; 

		half2 toff0 = half2(scx.y,-scx.x)*1.00f*scale; 
		half2 toff1 = half2(scx.x, scx.y)*0.75f*scale; 
		half2 toff2 = half2(-scx.y,scx.x)*0.50f*scale;
		half2 toff3 = half2(-scx.x,-scx.y)*0.25f*scale;

		half4 color0=SamplePedSkinAA( IN.pos.xy+toff0, SAMPLE_INDEX );
		half4 color1=SamplePedSkinAA( IN.pos.xy+toff1, SAMPLE_INDEX );
		half4 color2=SamplePedSkinAA( IN.pos.xy+toff2, SAMPLE_INDEX );
		half4 color3=SamplePedSkinAA( IN.pos.xy+toff3, SAMPLE_INDEX );

		color0.a=1.f-color0.a*alphaScale;
		color1.a=1.f-color1.a*alphaScale;
		color2.a=1.f-color2.a*alphaScale;
		color3.a=1.f-color3.a*alphaScale;

		#if !_USE_LARGER_TERMINUS
			// from http://http.developer.nvidia.com/GPUGems3/gpugems3_ch14.html
			// table is http://http.developer.nvidia.com/GPUGems3/elementLinks/14fig13.jpg
			half3	color=colorM.rgb*half3(0.3f,0.6f,0.7f);
			color.rgb += lerp(color0.rgb, colorM.rgb, color0.a) * half3(0.1f, 0.00f,  0.00f) * skinColourTweak.rgb;	
			color.rgb += lerp(color1.rgb, colorM.rgb, color1.a) * half3(0.3f, 0.005f, 0.00f) * skinColourTweak.rgb;	
			color.rgb += lerp(color2.rgb, colorM.rgb, color2.a) * half3(0.2f, 0.1f,   0.01f) * skinColourTweak.rgb;	
			color.rgb += lerp(color3.rgb, colorM.rgb, color3.a) * half3(0.1f, 0.3f,   0.3f ) * skinColourTweak.rgb;
		#else
			half2 toff4 = half2(-scx.x,-scx.y)*1.25f*scale; 
			half4	color4=SamplePedSkinAA( IN.pos.xy+toff4, SAMPLE_INDEX );
			color4.a=1.f-color4.a*alphaScale;

			half3	color;
			color.rgb = lerp(color3.rgb, colorM.rgb, color3.a) * half3(0.1f,   0.336f, 0.344f) ;
			color.rgb += lerp(color2.rgb, colorM.rgb, color2.a) * half3(0.118f, 0.198f, 0.0f  );	
			color.rgb += lerp(color1.rgb, colorM.rgb, color1.a) * half3(0.113f, 0.007f, 0.007f);	
			color.rgb += lerp(color0.rgb, colorM.rgb, color0.a) * half3(0.258f, 0.004f, 0.00f );	
			color.rgb += lerp(color4.rgb, colorM.rgb, color4.a) * half3(0.178f, 0.00f,  0.00f );
			color.rgb *=skinColourTweak.rgb;
			color += colorM.rgb*half3(0.2333f,0.455f,0.649f);
		#endif
		colorM.rgb = lerp(colorM.rgb,color.rgb,skinParams.x);
	}

	return half4(colorM.rgb, 1.0f);
}

half4 PS_pedSkinPass( pixelInputLPS IN ) : COLOR
{
	return PS_pedSkinPassCommon(IN, false);
}
half4 PS_pedSkinPassCopyPed( pixelInputLPS IN ) : COLOR
{
	return PS_pedSkinPassCommon(IN, true);
}

// ----------------------------------------------------------------------------------------------- //
half4 PS_pedSkinPassNG( pixelInputLPS IN ) : COLOR
{
	return PS_pedSkinPassCommonNG(IN, false, false);
}
half4 PS_pedSkinPassCopyPedNG( pixelInputLPS IN ) : COLOR
{
	return PS_pedSkinPassCommonNG(IN, true, false);
}
half4 PS_pedHQSkinPassCopyPedNG( pixelInputLPS IN ) : COLOR
{
	return PS_pedSkinPassCommonNG(IN, true, true);
}
// ----------------------------------------------------------------------------------------------- //

half4 PS_passthrough(pixelInputLPS IN ): COLOR
{
	half4 colorM = SamplePedSkin(gDeferredLightSampler, IN.screenPos.xy);
	return colorM;
}

half4 PS_pedSkinPassForward(pixelInputLPS IN ): COLOR
{
	return PS_pedPassForward(IN);
}

// ----------------------------------------------------------------------------------------------- //
// ----------------------------------------------------------------------------------------------- //

technique MSAA_NAME(sss_skin)
{
	pass MSAA_NAME(p0) // just skin blur
	{
		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_pedSkinPass();
	}

	pass MSAA_NAME(p1) // just skin blur forward
	{
		VertexShader	= compile VERTEXSHADER VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER  PS_pedPassForward();
	}

	pass MSAA_NAME(p2) // skin blur and copy ped copy - PC only
	{
		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_pedSkinPassCopyPed();
	}

	pass MSAA_NAME(p3) // skin blur for next gen
	{
		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_pedSkinPassNG();	
	}

	pass MSAA_NAME(p4) // skin blur for next gen and copy ped copy - PC only
	{
		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_pedSkinPassCopyPedNG();			
	}

	pass MSAA_NAME(p5) // high quality skin blur for next gen and copy ped copy - PC only
	{
		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_pedHQSkinPassCopyPedNG();			
	}
}
// ----------------------------------------------------------------------------------------------- //
// PUDDLE FULL SCREEN PASS
// ----------------------------------------------------------------------------------------------- //
#define _NO_PUDDLE_SHADERS_
#include "..\Megashader\Puddle.fxh"
#define PUDDLE_RANGE 140.f
#define PUDDLE_FADE_RANGE 80.f
#define PUDDLE_MAX_RANGE  ( PUDDLE_RANGE + PUDDLE_FADE_RANGE )


#define _CALC_SLOPE	!USE_SLOPE
float3 blurredNormal( pixelInputLPS IN, float3 norm, DeferredSurfaceInfo surfaceInfo ){
	float angle		= dot( IN.screenPos.xy*gScreenSize.xy*0.5f, float2(9.0f, 29.814f));
	float2 scx;
	sincos(angle, scx.x, scx.y);

	
	float2 tScale	= 32.f* gooScreenSize.xy/(surfaceInfo.depth);

	float2 off0		= float2( scx.y,-scx.x)*(1.00f*tScale);
	float2 off1		= float2( scx.x, scx.y)*(0.75f*tScale);
	float2 off2		= float2(-scx.y, scx.x)*(0.50f*tScale);
	float2 off3		= float2(-scx.x,-scx.y)*(0.25f*tScale);
	float2 tex= IN.screenPos.xy;
	//return norm;
	norm		= h4tex2D(GBufferTextureSampler1Global,  tex + off0).xyz;
	norm		+= h4tex2D(GBufferTextureSampler1Global,  tex + off1).xyz;
	norm		+= h4tex2D(GBufferTextureSampler1Global, tex + off2 ).xyz;
	norm		+= h4tex2D(GBufferTextureSampler1Global,  tex + off3).xyz;
	return norm*1./4.;
}
#define PUDDLE_USE_BAKED_AO 1

half4 PS_puddlePass(pixelInputLPS IN ) : COLOR
{
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy, IN.eyeRay, false, SAMPLE_INDEX);	
	float3 worldPos=surfaceInfo.positionWorld;

	float slope =surfaceInfo.slope;
	float dist = surfaceInfo.depth;  
	float fade = 1.0f - saturate( (dist-PUDDLE_RANGE)/PUDDLE_FADE_RANGE );

	float slopeFactor= saturate( (slope +g_Puddle_ScaleXY_Range.y)* g_Puddle_ScaleXY_Range.z);
	float v = slopeFactor*fade;

	float puddleBump=1.f;
#if PUDDLE_USE_BAKED_AO
	#if (RSG_PC || RSG_DURANGO || RSG_ORBIS ) && MULTISAMPLE_TECHNIQUES
		const int3 iPos = int3(IN.screenPos.xy * g_GBufferTexture3Param.xy, 0);
		float NaturalAmbient= gbufferTexture3Global.Load( iPos.xy, 0 ).x;
	#else
		float NaturalAmbient= tex2D(GBufferTextureSampler3Global, IN.screenPos.xy ).x;
	#endif
	puddleBump*=saturate((NaturalAmbient-.5)*8.);
	NaturalAmbient = saturate(NaturalAmbient*2);
	NaturalAmbient=NaturalAmbient*NaturalAmbient;
	v *= NaturalAmbient*NaturalAmbient;
#endif
	
#if USE_FULLSCREEN_PUDDLE_PASS
	return PuddleGetColor(v, worldPos, surfaceInfo.naturalAmbientScale,puddleBump);
#else
	return v;
#endif
}
#if USE_FULLSCREEN_PUDDLE_PASS
half4 PS_puddlePassDebug(pixelInputLPS IN ) : COLOR
{
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy, IN.eyeRay, false, SAMPLE_INDEX);	
	float3 worldPos=surfaceInfo.positionWorld;

	float slope =surfaceInfo.slope;
	float dist = surfaceInfo.depth;  
	float fade =  saturate(1.0f - (dist-PUDDLE_RANGE)/PUDDLE_FADE_RANGE );

	float puddleBump=1.;
#if PUDDLE_USE_BAKED_AO
	#if (RSG_PC || RSG_DURANGO || RSG_ORBIS ) && MULTISAMPLE_TECHNIQUES
		float NaturalAmbient= gbufferTexture3Global.Load( IN.screenPos.xy, 0 ).x;
	#else
		float NaturalAmbient= tex2D(GBufferTextureSampler3Global, IN.screenPos.xy ).x;
	#endif
	puddleBump*=saturate((NaturalAmbient-.6)*8.);
	
#endif

	float slopeFactor= saturate( (slope +g_Puddle_ScaleXY_Range.y)* g_Puddle_ScaleXY_Range.z);
	float flattness = slopeFactor*fade;
	return PuddleGetBump(flattness, worldPos, surfaceInfo.naturalAmbientScale)*puddleBump;	
}
#define MASK_SLOPE __PS3
half4 PS_puddleMask(pixelInputLPS IN ) : COLOR
{
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy, IN.eyeRay, false, SAMPLE_INDEX);	
	float3 worldPos=surfaceInfo.positionWorld;
	float slope =surfaceInfo.slope;
	float dist = surfaceInfo.depth;  
	float fade =  saturate(1.0f - (dist-PUDDLE_RANGE)/PUDDLE_FADE_RANGE );
	float slopeFactor= saturate( (slope +g_Puddle_ScaleXY_Range.y)* g_Puddle_ScaleXY_Range.z);
#if !MASK_SLOPE
	slopeFactor = 1.f;
#endif
	float flattness = slopeFactor*fade;
	return  GetPuddleDepth( worldPos.xy )* flattness ;
}
#endif


 half4 PS_puddleTest(pixelInputLPS IN): COLOR
{
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy / IN.screenPos.w, IN.eyeRay, false, SAMPLE_INDEX);	
	float3 worldPos=RippleData.xyz;
	float slope =surfaceInfo.slope;
	float dist = surfaceInfo.depth;  
	float fade =  saturate(1.0f - (dist-PUDDLE_RANGE)/PUDDLE_FADE_RANGE );
	float slopeFactor= saturate( (slope +g_Puddle_ScaleXY_Range.y)* g_Puddle_ScaleXY_Range.z);
	float flattness = saturate(slopeFactor*fade);
	float isVisible =   saturate(GetPuddleDepth( worldPos.xy ) - g_Puddle_ScaleXY_Range.w) * flattness;
	rageDiscard(!isVisible);
	return half4(isVisible.xxxx);
//	return half4((!isVisible) ? half4(1,0,0,1) : half4(0,1,0,1));
}

#if USE_COMBINED_PUDDLEMASK_PASS
//On pc we cant read the depth buffer and write to stencil at the same time like on console
//so do the 2 passes in 1.
half4 PS_puddleMaskAndPassCombined(pixelInputLPS IN ) : COLOR
{
	half4 puddleMask = PS_puddleMask( IN );
	half4 puddleOut = half4( 0.0f, 0.0f, 0.0f, 0.0f);

	if( puddleMask.x > 0.0f )
	{
		puddleOut = PS_puddlePass( IN );
	}
	return puddleOut;
}

#endif

#if !USE_COMBINED_PUDDLEMASK_PASS
technique MSAA_NAME(puddlePass)
{
	pass MSAA_NAME(p0) 
	{
		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_puddlePass()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(1));
	}
}
#endif


 technique MSAA_NAME(PuddleTestTechnique)
{
	pass MSAA_NAME(p0) 
	{	
		ColorWriteEnable=0;
		VertexShader = compile VERTEXSHADER			VS_volumeTransformP();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_puddleTest()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(1));
	}
}

technique MSAA_NAME(puddlePassDebug)
{
	pass MSAA_NAME(p0) 
	{
		AlphaBlendEnable=false;
		AlphaTestEnable  = false; 
		BlendOp          = ADD; 
		SrcBlend         = SRCALPHA; 
		DestBlend        = INVSRCALPHA;

		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_puddlePassDebug()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(1));
	}
}

#if !USE_COMBINED_PUDDLEMASK_PASS
technique MSAA_NAME(puddleMask)
{
	pass MSAA_NAME(p0) 
	{

		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_puddleMask()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(1));
	}
}
#else
technique MSAA_NAME(puddleMaskAndPassCombined)
{
	pass MSAA_NAME(p0) 
	{

		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_puddleMaskAndPassCombined()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(1));
	}
}
#endif

// ----------------------------------------------------------------------------------------------- //
// AMBIENT VOLUMES
// ----------------------------------------------------------------------------------------------- //

DeferredGBuffer PS_ambientScaleTexture(pixelInputLPS IN)
{
	float2 tc = IN.screenPos.xy / IN.screenPos.w;
	uint sampleIndex = SAMPLE_INDEX;
	
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(tc, IN.eyeRay, false, sampleIndex);

	float3 epos = deferredLightPosition;

	float3 edirx = cross(deferredLightDirection.xyz, deferredLightTangent.xyz);		
	float3 ediry = deferredLightTangent;
	float3 edirz = -deferredLightDirection;		

	float rx = deferredVolumeSizeX;
	float ry = deferredVolumeSizeY;
	float rz = deferredVolumeSizeZ;

	float3 rpos = surfaceInfo.positionWorld;

	float3 dir = (epos.xyz - rpos.xyz);

	float dotx = dot(edirx, dir);
	float doty = dot(ediry, dir);
	float dotz = dot(edirz, dir);
	
	float2 texcoord0 = saturate((float2(dotx / rx, doty / ry) * 0.5f) + 0.5f);		
	float texsample0 = tex2Dlod(gDeferredLightSampler, float4(texcoord0, 0, 0)).x;

	//if dotz is negative, it means that point is above the volume (on the vehicle) and should not be darkened
	float num0 = saturate(-dot(deferredLightDirection,surfaceInfo.normalWorld)) * step(0.0f, dotz);
	float num1 = saturate(1.0f-((dotz-rz) / (2.0f*rz)));

	float num = texsample0 * (num0*num0) * (num1*num1);
	num *= deferredLightColourAndIntensity.w;
	num = lerp(0.0f, num, gAmbientOcclusionEffect.z);

	DeferredGBuffer OUT;
	OUT.col0 = half4(0,0,0,num * deferredLightColourAndIntensity.r);
	OUT.col1 = 0.0.xxxx;
	OUT.col2 = 0.0.xxxx;
	OUT.col3 = half4(0,0,0,num * (1.0 - deferredLightColourAndIntensity.r));

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

DeferredGBuffer PS_ambientScaleEllipsoid(pixelInputLPS IN)
{	
	float2 tc = IN.screenPos.xy / IN.screenPos.w;
	uint sampleIndex = SAMPLE_INDEX;
	
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(tc, IN.eyeRay, false, sampleIndex);	

	float3 midPos = deferredLightPosition;
 
	float diffZ = abs(midPos.z - surfaceInfo.positionWorld.z);
	diffZ = 1.0 - saturate(diffZ);

	float diffN = saturate((surfaceInfo.normalWorld.z - 0.75) / 0.25);

	float2 diff = surfaceInfo.positionWorld.xy - midPos.xy;
	float num = saturate(0.8 - (length(diff) / deferredLightRadius)) * diffZ * diffN * deferredLightColourAndIntensity.w;
	num *= num;
	num = lerp(0.0f, num, gAmbientOcclusionEffect.y); //strength of ambient occlusion messed with 
	
	DeferredGBuffer OUT;
	OUT.col0 = half4(0,0,0,num * deferredLightColourAndIntensity.r);
	OUT.col1 = 0.0.xxxx;
	OUT.col2 = 0.0.xxxx;
	OUT.col3 = half4(0,0,0,num * (1.0 - deferredLightColourAndIntensity.r));
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

technique MSAA_NAME(ambientScaleVolume)
{
	pass MSAA_NAME(p0) //car projection - cuboid
	{
		VertexShader = compile VERTEXSHADER			VS_volumeTransformP();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ambientScaleTexture()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(p1) //sphere
	{
		VertexShader = compile VERTEXSHADER			VS_volumeTransformPSP();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ambientScaleEllipsoid()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}

// ----------------------------------------------------------------------------------------------- //

half4 PS_snow(pixelInputLPS IN) : COLOR
{
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy, IN.eyeRay, true, SAMPLE_INDEX);	

	float stencil = fmod(surfaceInfo.materialID, 8.0f/255.0f);
	stencil *= 255.0f;
	float validStencil = (abs(stencil - (DEFERRED_MATERIAL_DEFAULT)) <= 0.1f) || 
						 (abs(stencil - (DEFERRED_MATERIAL_TERRAIN)) <= 0.1f);

	float wetblend = 
		saturate((surfaceInfo.normalWorld.z - 0.45) / 0.55) * 
		(1.0 - surfaceInfo.inInterior) * 
		surfaceInfo.naturalAmbientScale;

	float3 colour;
	if (abs(stencil - (DEFERRED_MATERIAL_TREE)) <= 0.1f)
	{
		float treeblend = 
			saturate(surfaceInfo.normalWorld.z - 0.15 / 0.85) * 
			(1.0 - surfaceInfo.inInterior) * 
			surfaceInfo.naturalAmbientScale;

		float lum = dot(surfaceInfo.diffuseColor, LumFactors);
		//colour = saturate(lum + 0.4f) * float(0.88);
		colour = lerp(surfaceInfo.diffuseColor, float3(0.88.xxx), treeblend * 0.8);
	}
	else
	{
		colour = lerp(surfaceInfo.diffuseColor, float3(0.88.xxx), wetblend * validStencil);
	}

	return half4(sqrt(colour), 1.0f);
}

technique MSAA_NAME(snow)
{
	pass MSAA_NAME(p0)
	{
		SET_COLOR_WRITE_ENABLE(RED+GREEN+BLUE, 0, 0, 0)

		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_snow()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(1));
	}

}

// ----------------------------------------------------------------------------------------------- //

half4 PS_foliageMarkNonGrass( pixelInputLPS IN ) : COLOR
{
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S0(IN.screenPos.xy, IN.eyeRay, false, true, SAMPLE_INDEX);

	if(surfaceInfo.bIsGrass)
	{
		rageDiscard(true);	// do not mark grass
	}

	return half4(0,0,0,0);	// mark trees
}


technique MSAA_NAME(foliage_preprocess)
{
	pass MSAA_NAME(p0)
	{
		VertexShader	= compile VERTEXSHADER		VS_screenTransformS();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_foliageMarkNonGrass();
	}
}
