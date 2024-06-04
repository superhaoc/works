#ifndef __DIRECTIONAL_INCLUDE
#define __DIRECTIONAL_INCLUDE

#include "../../Util/macros.fxh"
#include "../lighting_common.fxh"
#include "../Lights/light_common.fxh"
#include "../Shadows/cascadeshadows_receiving.fxh"

// =============================================================================================== //
// DEFINES
// =============================================================================================== //

// =============================================================================================== //
// TECHNIQUE FUNCTIONS
// =============================================================================================== //

#if DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS
// ----------------------------------------------------------------------------------------------- //
// http://www.iryoku.com/separable-sss-released
//const float4 SSS_Params = float4(0.005,0.1,0.3,0,0.3);
#define SSS_Params		(deferredLightParams[9])
#define SSS_Params2		(deferredLightParams[10])
#define fNormalShift	(SSS_Params.x)
#define fShadowDistScale (SSS_Params.y * SSS_Params.y)
#define fOverScatter	(SSS_Params.z)
#define fAmbientScale	(SSS_Params.w)
#define fShadowOffset   (SSS_Params2.x)

float _calculateSSS_distance(surfaceProperties surface)
{
	float2 ditherRadius = 0, lastPos = 0;
	int cascadeIndex = 0;
	const float3 shrinkedPos = surface.position - fNormalShift*surface.normal;
	const CascadeShadowsParams params = CascadeShadowsParams_setup(CSM_ST_LINEAR);
	
	const float edgeDither = 0.0f;
	const float linearDepth = 1.0f;		

	const float4 texCoords = float4(ComputeCascadeShadowsTexCoord(params, shrinkedPos, 0, true, false, 
	                         ditherRadius, lastPos, cascadeIndex,
							 edgeDither, linearDepth));	

	//const float4 depth = __tex2DPCF(SHADOWSAMPLER_TEXSAMP, texCoords);
	const float4 depth = SampleShadowDepth4(texCoords.xyw);
	return abs( texCoords.z - dot(0.25,depth)) + fShadowOffset;
}

float3 _calculateSSS_transport(float s, float3 fAmbientAcculation)
{
	/*return fAmbient+
		float3(0.233, 0.455, 0.649) * exp(-s*s/0.0064)+
		float3(0.100, 0.336, 0.344) * exp(-s*s/0.0484)+
		float3(0.118, 0.198, 0.000) * exp(-s*s/0.1870)+
		float3(0.113, 0.007, 0.007) * exp(-s*s/0.5670)+
		float3(0.358, 0.004, 0.000) * exp(-s*s/1.9900)+
		float3(0.078, 0.000, 0.000) * exp(-s*s/7.4100);*/
	return (fAmbientAcculation * fAmbientScale) + exp(-s*s);
}

float3 calculateSubSurfaceScattering(LightingResult res, float3 fAmbientAcc, float fShadowFallOff)
{
	const float s = fShadowFallOff * fShadowDistScale * _calculateSSS_distance( res.surface );
	const float NdotL = dot( res.surface.normal.xyz, res.surface.lightDir.xyz );
	const float E = max( fOverScatter - NdotL , 0.0 );
	const float3 transported = E * _calculateSSS_transport(s, fAmbientAcc);
	return transported * res.lightColor.rgb * res.material.diffuseColor.rgb;
}
#endif // DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS

LightingResult directionalCalculateLighting(
	surfaceProperties surface,
	materialProperties material,
	directionalLightProperties light,
	bool specular,
	bool reflection,
	bool directLight,
	bool receiveShadows,
	bool receiveShadowsFast,
	bool receiveShadowsHighQuality,
	float2 screenPos,
	bool directionalDiffuse,
	bool directionalSpecular,
	bool useBackLighting,
	bool bScatter,
	bool useCloudShadows)
{
	float3 lightColor = float3(0.0, 0.0, 0.0);

	float lightAttenuation = 1.0f;
	float isBackLightingRequired = 1.0f;
	float shadowAmount = 1.0f;

	// Calculate the directional lighting (so just attenuation + shadows)
	if (directLight)
	{
		if(useBackLighting)
		{
			float BackLightingRequired = dot(surface.normal.xyz, surface.lightDir) < 0.0f ? -1.f : 1.f;
			surface.normal = surface.normal * BackLightingRequired;

			if (!bScatter)
				isBackLightingRequired = BackLightingRequired;
		}

		// Calculate shadows
		if (receiveShadows)
		{
			#if SHADOW_RECEIVING
				
			#if DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS
				/*
				if (bScatter)
				{
					shadowAmount = saturate(CalcCascadeShadowsSSS(gViewInverse[3].xyz, surface.position, surface.normal, screenPos) + deferredLightShadowBleedScalar / deferredLightShadowBleedScalar);
				}
				else
				*/
			#endif // DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS
				if (receiveShadowsHighQuality)
				{
					shadowAmount = CalcCascadeShadowsHighQuality(gViewInverse[3].xyz, surface.position, surface.normal, screenPos);
				}
				else
				{
				#if defined(USE_SHADOW_FAST_NO_FADE)
					{
						shadowAmount = CalcCascadeShadowsFastNoFade(gViewInverse[3].xyz, surface.position, surface.normal, screenPos);
					}
				#else
					if (receiveShadowsFast)
					{
						// note that this disables the irregular fade, so the results might not look quite the same, but it's faster
						// TODO -- i'm not disabling irregular fade anymore, but i'd like to ..
						shadowAmount = CalcCascadeShadowsFast(gViewInverse[3].xyz, surface.position, surface.normal, screenPos);
					}
					else
					{
						shadowAmount = CalcCascadeShadows(gViewInverse[3].xyz, surface.position, surface.normal, screenPos);
					}
				#endif
				}
				#if SELF_SHADOW
				// if (!bScatter)
					shadowAmount *= material.selfShadow;
				#endif

				if(useCloudShadows)
				{
					//the fog shadow density is already accounted for in CalcCascadeShadows
					shadowAmount *= CalcCloudShadows(surface.position);
				}
			#endif // SHADOW_RECEIVING
		}

		// Calculate light colour
		lightColor = light.color;

		if (!bScatter && useBackLighting && (isBackLightingRequired < 0.0f))
		{
			float transluceny = 0.5f;

			#if SPECULAR
			if (material.skinBlend > 0.0)
			{
				transluceny = 0.25f;
			}
			#endif

			float3 tintColor =  lerp(material.diffuseColor.rgb, 1.0f.xxx, transluceny);
			lightColor *= (isBackLightingRequired > 0.f) ? 1.f : tintColor;
			surface.normal = isBackLightingRequired * surface.normal;  // flip normal back for the ambient							
		}
#if SPECULAR
		if (bScatter)
		{
			material.reflectionIntensity *= shadowAmount;
			material.specularIntensity *= shadowAmount;
			material.specularExponent *= shadowAmount;
		}
#endif // SPECULAR
	}

	// Store all the results that we need
	LightingResult OUT;
	OUT = (LightingResult)0;
	
	OUT.lightColor = lightColor;
	OUT.lightAttenuation = lightAttenuation;
	OUT.shadowAmount = shadowAmount;
	OUT.material = material;
	OUT.surface = surface;
	OUT.backLightingAdjust = isBackLightingRequired;
	
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //
#if DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS
// ----------------------------------------------------------------------------------------------- //

#define BLUR_GBUFFER_SHADOW		(0 && RSG_ORBIS && defined(DEFERRED_UNPACK_LIGHT))

#if BLUR_GBUFFER_SHADOW
// The following code is derived from tiled_lighting.fx

float blurGbufferShadow(float2 screenPos, float myDepth, float selfShadow, uint sampleIndex)
{
	const int2 offsets[4] = { int2(1,2), int2(-1,-2), int2(2,-1), int2(-2,1) };
#if MULTISAMPLE_TECHNIQUES
	// TODO - Come up with better sampling of the MSAA surface
	const int2 iPos = getIntCoords(screenPos, globalScreenSize.xy);
	int shadeIndex = sampleIndex;
# if ENABLE_EQAA && EQAA_DECODE_GBUFFERS && 0
	// not using Fmask for Gbuffer2
	if (gMSAAFmaskEnabled)
	{
		const int shadeFmask = gbufferFragmentMask2Global.Load( int3(iPos,0) );
		shadeIndex = translateAASample( shadeFmask, sampleIndex );
	}
# endif // ENABLE_EQAA
#define GET_DEPTH(i)	gbufferTextureDepthGlobal	.Load(iPos, sampleIndex, offsets[i]).x
#define GET_SHADE(i)	gbufferTexture2Global		.Load(iPos, shadeIndex, offsets[i]).w
#else	//MULTISAMPLE_TECHNIQUES
	const float2 texel = gooScreenSize.xy;
#define GET_DEPTH(i)	tex2D(GBufferTextureSamplerDepthGlobal,	screenPos + texel*offsets[i]).x
#define GET_SHADE(i)	tex2D(GBufferTextureSampler2Global,		screenPos + texel*offsets[i]).w
#endif	//MULTISAMPLE_TECHNIQUES

	float4 depths = float4(	GET_DEPTH(0), GET_DEPTH(1), GET_DEPTH(2), GET_DEPTH(3) );
	float4 shades = float4( GET_SHADE(0), GET_SHADE(1), GET_SHADE(2), GET_SHADE(3) );

	float thresholdDepth = myDepth;
#if __XENON
	thresholdDepth = 1 - thresholdDepth;
#endif
	const float th= (1-thresholdDepth)*0.0075f;

	float4 weights = step( abs(depths-myDepth), th );
	float totalWeight = 1 + dot(weights,1);
	selfShadow += dot(shades,weights);
	return selfShadow/totalWeight;

#undef GET_DEPTH
#undef GET_SHADE
}
#endif	//BLUR_GBUFFER_SHADOW


float4 calculateCaustics(materialProperties material, surfaceProperties surface, float surfaceHeight, bool transform)
{
	float time	= deferredLightWaterTime;

	if(!transform)
		surfaceHeight = deferredLightWaterHeight;

	const float offsetScale = 0.3f;
	float4 texCoords;
	float4 caustTex = surface.position.xyyx * float4(1.0f, 1.0f, 0.74546f, 0.74546f);
	float4 bumpTex = frac(caustTex/50.0f + time);
	float4 bump = float4(tex2D(gDeferredLightSampler, bumpTex.xy).ag, tex2D(gDeferredLightSampler, bumpTex.zw).ga);

	float2 alpha = float2(2*(surfaceHeight - surface.position.z), 1.0f);
	if(transform)
		alpha.y = (40.0f - (gViewInverse[3].z - surface.position.z)) / 8.0f;
	alpha = saturate(alpha);
	alpha.x = alpha.x * alpha.y;

	bump = bump - 0.5;
	texCoords = caustTex + offsetScale * bump + float4(1,1,-1,-1)*time*15;

	float3 causticIntensity = tex2D(gDeferredLightSampler1, texCoords.xy).rgb*tex2D(gDeferredLightSampler1, texCoords.zw).rgb;
	causticIntensity = causticIntensity*10;

	return float4(causticIntensity.rgb, alpha.x);
}

// ----------------------------------------------------------------------------------------------- //

float4 deferred_directional_internal(lightPixelInput IN, float2 screenPos, DeferredSurfaceInfo surfaceInfo, bool directional, bool caustics, bool transform, bool useBackLighting, bool useScattering, bool orthographic, bool extra, bool shadow)
{
	// Material Properties
	materialProperties material = populateMaterialPropertiesDeferred(surfaceInfo); // Setup all the material properties

#if SELF_SHADOW && BLUR_GBUFFER_SHADOW
	if (shadow)
	{	// use filtering on the shadow edges
		material.selfShadow = blurGbufferShadow( screenPos, surfaceInfo.rawD, material.selfShadow, SAMPLE_INDEX );
	}
#endif	//SELF_SHADOW && BLUR_GBUFFER_SHADOW

	// Light properties
	directionalLightProperties light;
	light.direction = deferredLightDirection;
	light.color = deferredLightColourAndIntensity.rgb;

	// Surface Properties
	surfaceProperties surface = populateSurfaceProperties(
		surfaceInfo, 
		-deferredLightDirection, 
		0.0f);

	LightingResult res;
	res = directionalCalculateLighting(
		surface,
		material,
		light,
		true,		// Specular
		true,		// Reflection
		directional,
		shadow,		// Receive Shadows
		false,		// Receive Shadows Fast
		false,		// Receive High Quality Shadows
		screenPos,
		true,		// Directional Diffuse
		true,		// Directional Specular
		useBackLighting,
		useScattering && (surfaceInfo.reflectionIntensity > 0),
		false);		//useCloudShadows

	if (caustics)
	{
		float4 causticIntensity = calculateCaustics(material, surface, IN.screenPos.z, transform);
		res.lightColor *= (causticIntensity.rgb * causticIntensity.a) + 1.0f.xxx;
	}

	Components components;
	
	float4 OUT = ApplyLightToSurface(res, true, true, true, components);

	if (extra)
	{
		float3 fAmbientAcc;
		fAmbientAcc = calculateAmbient(true, true, true, true, surface, material, components.Kd); // Ambient contribution	
		OUT.rgb += fAmbientAcc;
		OUT.rgb += calculateReflection(surface.normal, material, surface.eyeDir, 1.0 - components.Kd, useBackLighting); // Reflection contribution
		OUT.rgb += material.diffuseColor.rgb * (material.emissiveIntensity * components.EdotN); // Emissive contribution
		
		if (useScattering && (surfaceInfo.reflectionIntensity > 0))
		{
			OUT.rgb += calculateSubSurfaceScattering(res, fAmbientAcc, surfaceInfo.reflectionIntensity); // surfaceInfo.specularSkinBlend == Shadow Falloff for trees
		}
				
		if (!useBackLighting)							// don't write skin out if backlighting as it marks cloth
			OUT.a = surfaceInfo.specularSkinBlend;		// on 360 inverse color bias applied in skin shader
		else
			OUT.a = 0.f;
	}
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float4 deferred_directional(lightPixelInput IN, bool directional, bool caustics, bool transform, bool useBackLighting, bool useScattering, bool orthographic, bool extra, bool shadow)
{
#if MULTISAMPLE_EMULATE_INTERPOLATOR && 0
	// the only thing that is sampled (with fractional tex-coords) here is SSAO, which needs to represent all the samples (not just sample[0])
	adjustPixelInputForSample(gbufferTextureDepthGlobal, 0, IN.screenPos.xyw);
#endif
	float2 screenPos = IN.screenPos.xy / IN.screenPos.w;

#if RSG_PC
	// foliage prepass only for Orbis/Durango - BS#2069821:
	DeferredSurfaceInfo surfaceInfo;
	if(useBackLighting)
	{	// foliage pass: extract grass-or-tree bit
		surfaceInfo = UnPackGBuffer_S0(screenPos, IN.eyeRay, false, true, SAMPLE_INDEX);
		if(surfaceInfo.bIsGrass)
		{
			// switch back to standard lighting for grass
			useBackLighting = false;
			useScattering	= false;
		}
	}
	else
	{
		surfaceInfo = UnPackGBuffer_S(screenPos, IN.eyeRay, true, SAMPLE_INDEX);
	}
#else
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(screenPos, IN.eyeRay, true, SAMPLE_INDEX);
#endif

	if (orthographic)
	{
		const float orthoTileAspect = 1280.0/720.0;
		const float orthoTileSize = 150.0;
		const float3 orthoTileExtent = float3(orthoTileAspect, -1, 0)*orthoTileSize/2; // TODO -- support arbitrary tile extent and orientation

		float3 eyePos = gViewInverse[3].xyz + float3(IN.screenPos.xy*2 - 1, 0)*orthoTileExtent;

		surfaceInfo.depth = getLinearDepthOrtho(surfaceInfo.rawD, deferredProjectionParams.zw);
		surfaceInfo.positionWorld = eyePos + (IN.eyeRay.xyz * surfaceInfo.depth);
	}

	return deferred_directional_internal(IN, screenPos, surfaceInfo, directional, caustics, transform, useBackLighting, useScattering, orthographic, extra, shadow);
}


// ----------------------------------------------------------------------------------------------- //

#define DIRECTIONAL_ON		true
#define CAUSTICS_ON			true
#define TRANSFORM_ON		true
#define BACKLIGHTING_ON		true
#define ORTHOGRAPHIC_ON		true
#define EXTRA_ON			true
#define SHADOW_ON			true
#define SCATTERING_ON		true

#define DIRECTIONAL_OFF		false
#define CAUSTICS_OFF		false
#define TRANSFORM_OFF		false
#define BACKLIGHTING_OFF	false
#define ORTHOGRAPHIC_OFF	false
#define EXTRA_OFF			false
#define SHADOW_OFF			false
#define SCATTERING_OFF		false

// ----------------------------------------------------------------------------------------------- //
#define GEN_DIR_FUNCS(name, vInput, vOutput, pInput, pOutput, directional, caustics, transform, useBacklighting, useScattering, orthographic, extra, shadow) \
	vOutput JOIN(VS_directional_,name)(vInput IN) \
	{ \
		vOutput OUT = VS_directional(IN, caustics, transform, orthographic, extra, shadow); \
		return(OUT); \
	} \
	\
	pOutput JOIN(PS_directional_,name)(pInput IN) \
	{ \
		float4 res = deferred_directional(IN, directional, caustics, transform, useBacklighting, useScattering, orthographic, extra, shadow); \
		pOutput OUT; \
		OUT.col = PackHdr(res); \
		return OUT; \
	} 

// ----------------------------------------------------------------------------------------------- //

lightVertexOutput VS_directional(lightVertexInput IN, bool caustics, bool transform, bool orthographic, bool extra, bool shadow)
{
	float4 vPos;
	lightVertexOutput OUT;
		
	float height = 0;
	if (transform)
	{
		OUT.pos	= mul(float4(IN.pos.xyz, 1), gWorldViewProj);
		float3 worldPos = mul(float4(IN.pos.xyz, 1), gWorld).xyz;
		OUT.eyeRay = float4(worldPos - gViewInverse[3].xyz, OUT.pos.w);
		height = worldPos.z;
	}
	else
	{
		OUT.pos = float4((IN.pos.xy - 0.5f) * 2.0f, 0.0, 1.0);
#ifdef NVSTEREO
		float2 stereoParams = StereoParmsTexture.Load(int3(0,0,0)).xy;
		OUT.eyeRay = GetEyeRay(OUT.pos.xy - float2(stereoParams.x,0.0f));
#else
		OUT.eyeRay = GetEyeRay(OUT.pos.xy);
#endif
	}

	if (orthographic)
	{
		OUT.eyeRay = float4(-gViewInverse[2].xyz, 1);
	}

	OUT.screenPos = convertToVpos(OUT.pos, deferredLightScreenSize);

	if(transform)
	{
		OUT.screenPos.z = height;
	}

	return(OUT);
}

// =============================================================================================== //
// STANDARD FUNCTIONS
// =============================================================================================== //

GEN_DIR_FUNCS(standard, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  DIRECTIONAL_ON, CAUSTICS_OFF, TRANSFORM_OFF, BACKLIGHTING_OFF, SCATTERING_OFF, ORTHOGRAPHIC_OFF, EXTRA_ON, SHADOW_ON);

// ----------------------------------------------------------------------------------------------- //

GEN_DIR_FUNCS(ambient, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  DIRECTIONAL_OFF, CAUSTICS_OFF, TRANSFORM_OFF, BACKLIGHTING_OFF, SCATTERING_OFF, ORTHOGRAPHIC_OFF, EXTRA_ON, SHADOW_ON);

// ----------------------------------------------------------------------------------------------- //

GEN_DIR_FUNCS(underwater, 
		  lightVertexInput, lightVertexOutput,
		  lightPixelInput, lightPixelOutput,
		  DIRECTIONAL_ON, CAUSTICS_ON, TRANSFORM_OFF, BACKLIGHTING_OFF, SCATTERING_OFF, ORTHOGRAPHIC_OFF, EXTRA_ON, SHADOW_ON);

// ----------------------------------------------------------------------------------------------- //

GEN_DIR_FUNCS(underwater_surface, 
		  lightVertexInput, lightVertexOutput,
		  lightPixelInput, lightPixelOutput,
		  DIRECTIONAL_ON, CAUSTICS_ON, TRANSFORM_ON, BACKLIGHTING_OFF, SCATTERING_OFF, ORTHOGRAPHIC_OFF, EXTRA_ON, SHADOW_ON);

// ----------------------------------------------------------------------------------------------- //

GEN_DIR_FUNCS(backlit, 
		  lightVertexInput, lightVertexOutput,
		  lightPixelInput, lightPixelOutput,
		  DIRECTIONAL_ON, CAUSTICS_OFF, TRANSFORM_OFF, BACKLIGHTING_ON, SCATTERING_OFF, ORTHOGRAPHIC_OFF, EXTRA_ON, SHADOW_ON);

// ----------------------------------------------------------------------------------------------- //

GEN_DIR_FUNCS(just_dir, 
			  lightVertexInput, lightVertexOutput,
			  lightPixelInput, lightPixelOutput,
			  DIRECTIONAL_ON, CAUSTICS_OFF, TRANSFORM_OFF, BACKLIGHTING_OFF, SCATTERING_OFF, ORTHOGRAPHIC_OFF, EXTRA_OFF, SHADOW_OFF);

// ----------------------------------------------------------------------------------------------- //

GEN_DIR_FUNCS(scatter, 
		  	  lightVertexInput, lightVertexOutput,
		  	  lightPixelInput, lightPixelOutput,
		  	  DIRECTIONAL_ON, CAUSTICS_OFF, TRANSFORM_OFF, BACKLIGHTING_ON, SCATTERING_ON, ORTHOGRAPHIC_OFF, EXTRA_ON, SHADOW_ON);

// ----------------------------------------------------------------------------------------------- //

#if !defined(SHADER_FINAL)
GEN_DIR_FUNCS(orthographic_BANK_ONLY, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  DIRECTIONAL_ON, CAUSTICS_OFF, TRANSFORM_OFF, BACKLIGHTING_OFF, SCATTERING_OFF, ORTHOGRAPHIC_ON, EXTRA_ON, SHADOW_ON);
#endif // !defined(SHADER_FINAL)

// =============================================================================================== //
// TECHNIQUES
// =============================================================================================== //

technique MSAA_NAME(directional)
{
	pass MSAA_NAME(standard)
	{
		VertexShader = compile VERTEXSHADER			VS_directional_standard();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_directional_standard()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(3));
	}

	pass MSAA_NAME(ambient)
	{
		VertexShader = compile VERTEXSHADER			VS_directional_ambient();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_directional_ambient()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(underwater)
	{
		VertexShader = compile VERTEXSHADER			VS_directional_underwater();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_directional_underwater()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(3));
	}

	pass MSAA_NAME(underwater_surface)
	{
		VertexShader = compile VERTEXSHADER			VS_directional_underwater_surface();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_directional_underwater_surface()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(underwater_stencil)
	{
		VertexShader = compile VERTEXSHADER VS_directional_underwater_surface();
		#if __XENON
			PixelShader  = NULL;
		#else
			ColorWriteEnable = 0;
			PixelShader  = compile MSAA_PIXEL_SHADER PS_directional_underwater_surface()  CGC_FLAGS(CGC_DEFAULTFLAGS);
		#endif //__XENON
	}

	pass MSAA_NAME(backlit)
	{
		VertexShader = compile VERTEXSHADER			VS_directional_backlit();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_directional_backlit()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(3));
	}

	pass MSAA_NAME(just_dir)
	{
		VertexShader = compile VERTEXSHADER			VS_directional_just_dir();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_directional_just_dir()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(3));
	}

	pass MSAA_NAME(scatter)
	{
		VertexShader = compile VERTEXSHADER			VS_directional_scatter();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_directional_scatter()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(3));
	}	

#if !defined(SHADER_FINAL)
	pass MSAA_NAME(orthographic)
	{
		VertexShader = compile VERTEXSHADER			VS_directional_orthographic_BANK_ONLY();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_directional_orthographic_BANK_ONLY()  CGC_FLAGS(CGC_DEFAULTFLAGS_NPC(3));
	}
#endif // !defined(SHADER_FINAL)
}

// ----------------------------------------------------------------------------------------------- //
#endif  // DEFINE_TECHNIQUES_AND_FUNCTIONS
// ----------------------------------------------------------------------------------------------- //

#endif // __DIRECTIONAL_INCLUDE
