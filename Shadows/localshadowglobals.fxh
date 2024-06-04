// ======================
// localshadowglobals.fxh
// (c) 2010 RockstarNorth
// ======================

// 2010-07-23 - bernie.freidin - start of code cleanup

#ifndef LOCAL_SHADOW_GLOBALS_FXH
#define LOCAL_SHADOW_GLOBALS_FXH

#if (SHADOW_CASTING || SHADOW_RECEIVING) 

#include "../../common.fxh"
#include "../../Util/macros.fxh"
#ifdef USE_VEHICLE_DAMAGE
	#include "../../Vehicles/vehicle_damage.fxh"
#endif

#include "../../../renderer/Shadows/ParaboloidShadows_shared.h" // shared defines with the C++ code

#ifdef SHADOW_CUBEMAP						   // this may be false if spot and hemisphere get separated.
#define USE_SHADOW_CUBEMAP					1  // NOTE: we need to always use radial depth with this
#else
#define USE_SHADOW_CUBEMAP					0 
#endif

#define LOCAL_SHADOWS_USE_RPDB				(1)
#define LOCAL_SHADOWS_SOFT_FILTER_TAPS		(9)   // valid values are 8, 9, 12, or 16. 9 is recommended, it looks the same as 12 and better than 16
#define LOCAL_SHADOWS_USE_HW_PCF_DX10		((__SHADERMODEL >=40))

#define SHADOW_WRITE_DEPTH_AS_COLOR			(__XENON) 

#define SHADOW_MODIFY_DEPTH					(1)
#define SHADOW_NEEDS_DEPTHINFO				(1)

#if SHADOW_NEEDS_DEPTHINFO
	#define SHADOW_NEEDS_DEPTHINFO_ONLY(X)	X
	#define SHADOW_NEEDS_DEPTHINFO_OUT(X)	X.depthInfo
#else
	#define SHADOW_NEEDS_DEPTHINFO_ONLY(X)
	#define SHADOW_NEEDS_DEPTHINFO_OUT(X)	0
#endif

// ================================================================================================
// DEFINES
// ================================================================================================

#define DEBUG_SHADOW_SAMPLE_DITHER_FIXED()	0

#ifdef  SHADOW_USE_TEXTURE
#define SHADOW_USE_TEXTURE_ONLY(x)			x
#define SHADOW_USE_TEXTURE_SWITCH(x,y)		x
#else
#define SHADOW_USE_TEXTURE_ONLY(x)
#define SHADOW_USE_TEXTURE_SWITCH(x,y)		y
#endif

#define LOCALSHADOWS_DEFAULT_DITHER_SCALE	1.0f
#define LOCALSHADOWS_DEFAULT_DITHER_RES		64.0f

#if defined(DEFERRED_UNPACK_LIGHT)
#define DEFERRED_LOCAL_SHADOW_SAMPLING		(1)
#endif
	

// ================================================================================================
// shadow generation 
// ================================================================================================
#if SHADOW_CASTING

// ================================================================================================
// VARIABLES
// ================================================================================================

CBSHARED BeginConstantBufferPagedDX10(warpshadow, b6)
shared           float4   gShadowParam0 : ShadowParam0 REGISTER(c54);
shared           float4   gShadowParam1 : ShadowParam1 REGISTER(c55);
shared row_major float4x4 gShadowMatrix : ShadowMatrix REGISTER(c56);
EndConstantBufferDX10(warpshadow)

// more readable versions...
#define gShadowPos					(gShadowParam0.xyz)
#define gShadowOneOverDepthRange	(gShadowParam0.w)
#define gShadowDepthBias			(gShadowParam1.x)
#define gShadowSlopeScaleDepthBias	(gShadowParam1.y)

// ================================================================================================
// DATA STRUCTURES
// ================================================================================================

struct vertexInputLD
{
	float3 pos         : POSITION;
	float3 norm_REMOVE : NORMAL;
#ifdef SHADOW_USE_TEXTURE
	float4 tex         : TEXCOORD0;
#endif
};

struct vertexSkinInputLD
{
	float3 pos          : POSITION;
	float3 norm_REMOVE  : NORMAL;
	float4 weight       : BLENDWEIGHT;
	index4 blendindices : BLENDINDICES;
	SHADOW_USE_TEXTURE_ONLY(float4 tex : TEXCOORD0;)
};

struct vertexOutputLD
{
	DECLARE_POSITION(pos)
	SHADOW_NEEDS_DEPTHINFO_ONLY(float3 depthInfo: TEXCOORD0;)  
	SHADOW_USE_TEXTURE_ONLY(float4 tex  : TEXCOORD1;)
};

struct pixelInputLD
{
	DECLARE_POSITION_PSIN(pos)
	SHADOW_NEEDS_DEPTHINFO_ONLY(float3 depthInfo: TEXCOORD0;)  
	SHADOW_USE_TEXTURE_ONLY(float4 tex  : TEXCOORD1;)
};

// ================================================================================================


float4 TransformCMShadowVert(float3 pos, SHADOW_NEEDS_DEPTHINFO_ONLY(out) float3 depthInfo)
{
	float4 worldPos = float4(mul(float4(pos,1), gWorld).xyz - gShadowPos,1);  // subtract off the light pos, to reduce error in projection when far from the origin

	float4 projPos = mul(worldPos, gShadowMatrix);  

#if SHADOW_NEEDS_DEPTHINFO
	depthInfo = worldPos.xyz;

#endif
	return projPos;
}


vertexOutputLD VS_LinearDepth(vertexInputLD IN)
{
	vertexOutputLD OUT;

#ifdef USE_VEHICLE_DAMAGE
	float3 inPos	= IN.pos;
	float3 inNrm	= float3(0,0,1);
	float3 inDmgPos = inPos;
	float3 inDmgNrm = inNrm;
	ApplyVehicleDamage(inDmgPos, inDmgNrm, 1, inPos, inNrm);	
#else
	float3 inPos = IN.pos;
#endif

	OUT.pos = TransformCMShadowVert(inPos, SHADOW_NEEDS_DEPTHINFO_OUT(OUT));

	SHADOW_USE_TEXTURE_ONLY(OUT.tex = IN.tex);

	return OUT;
}


vertexOutputLD VS_LinearDepthSkin(vertexSkinInputLD IN)
{
	vertexOutputLD OUT;

#ifdef USE_VEHICLE_DAMAGE
	float3 inPos	= IN.pos;
	float3 inNrm	= float3(0,0,1);
	float3 inDmgPos = inPos;
	float3 inDmgNrm = inNrm;
	ApplyVehicleDamage(inDmgPos, inDmgNrm, 1, inPos, inNrm);
#else
	float3 inPos = IN.pos;
#endif

#ifdef NO_SKINNING
	float3 pos = inPos;
#else
	float3 pos = rageSkinTransform(inPos, ComputeSkinMtx(IN.blendindices, IN.weight));
#endif

	OUT.pos = TransformCMShadowVert(pos, SHADOW_NEEDS_DEPTHINFO_OUT(OUT));

	SHADOW_USE_TEXTURE_ONLY(OUT.tex = IN.tex);

	return OUT;
}


float4 LinearDepthCommon(pixelInputLD IN, uniform float alphaThreshold, out float depth)
{
	depth=1;

#ifdef SHADOW_USE_TEXTURE
	if (alphaThreshold<=0.0f || (tex2D(DiffuseSampler, IN.tex.xy).a * globalAlpha - alphaThreshold)>0.0f)
#endif
	{
	#if SHADOW_NEEDS_DEPTHINFO
		depth = length(IN.depthInfo)*gShadowOneOverDepthRange + gShadowDepthBias;
		
		// slope bias
		float Dx = ddx(depth);
		float Dy = ddy(depth);
		depth += gShadowSlopeScaleDepthBias * max(abs(Dx), abs(Dy));

		depth = fixupDepth(saturate(depth));
	#endif
	}

#if !SHADOW_WRITE_DEPTH_AS_COLOR
	return float4(1,1,1,1);
#else
	return(depth.xxxx);
#endif
}


#if SHADOW_MODIFY_DEPTH
	float4 PS_LinearDepth(pixelInputLD IN, out float depth : DEPTH): COLOR
	{
#else
	float4 PS_LinearDepth(pixelInputLD IN): COLOR
	{
		float depth;
#endif // MODIFY_DEPTH
	return LinearDepthCommon(IN, SHADOW_USE_TEXTURE_SWITCH(0.25f,0.0f),depth);
}

#if SHADOW_MODIFY_DEPTH
	float4 PS_LinearDepthOpaque(pixelInputLD IN, out float depth : DEPTH): COLOR
	{
#else
	float4 PS_LinearDepthOpaque(pixelInputLD IN): COLOR
	{
		float depth;
#endif // MODIFY_DEPTH
	return LinearDepthCommon(IN, 0.0f, depth);
}

#endif // SHADOW_CASTING



// ================================================================================================
// Shadow Receiving
// ================================================================================================
#if SHADOW_RECEIVING && (defined(DEFERRED_UNPACK_LIGHT) || (defined(FORWARD_LOCAL_LIGHT_SHADOWING) && defined(ENABLE_FORWARD_LOCAL_LIGHT_SHADOWING)))

// ================================================================================================
// VARIABLES
// ================================================================================================

#include "cascadeshadows_common.fxh"
#include "cascadeshadows_receiving.fxh"

	// for deferred, just use the first shadow data entry (hard coded to save time)
#define dLocalShadowData			(gLocalLightShadowData[0])

	// readable forms...
#define dShadowType					(dLocalShadowData[0].w)		// 0 point, 1 hemisphere, 2 spot
#define dShadowArrayIndex			(floor(dLocalShadowData[1].w))
#define dShadowUseHiResArray		(frac(dLocalShadowData[1].w)>.25)  // flag in the fractional part: 0.5 = high res array, 0 = low res array
#define dShadowOneOverDepthRange	(dLocalShadowData[2].w)
#define dShadowDitherRadius			(dLocalShadowData[3].w)

#define dShadowTextureWidth			(gShadowTexParam.x)
#define dShadowTextureHeight		(gShadowTexParam.y)
#define dShadowTextureOneOverWidth	(gShadowTexParam.z)
#define dShadowTextureOneOverHeight	(gShadowTexParam.w)

// we reuse the shadow tex params from deferred pass for some forward pass flags
#define gForwardLightShadowsOnGlass (gShadowTexParam.x)    // this is pretty expensive, so it will be flagged on only for HW fast enough



#if USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
#define SHADOW_CUBEMAP_TEXCOORDS(xyz)  float4(xyz,dShadowArrayIndex)
#define SHADOW_TEXCOORDS(xy)		   float3(xy,dShadowArrayIndex)
#else
#define SHADOW_CUBEMAP_TEXCOORDS(xyz)  float3(xyz)
#define SHADOW_TEXCOORDS(xy)		   float2(xy)
#endif

#define SHADOW_TYPE_NONE		0
#define SHADOW_TYPE_POINT		1
#define SHADOW_TYPE_HEMISPHERE	2
#define SHADOW_TYPE_SPOT		3

#if ENABLE_FORWARD_LOCAL_LIGHT_SHADOWING
#if USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
	// with arrays, we should set these once before the forward pass
	shared TextureCubeArray <float>	gLocalLightShadowHiresCubeArray	REGISTER(t24);
	shared TextureCubeArray <float>	gLocalLightShadowLoresCubeArray	REGISTER(t25);
	shared Texture2DArray   <float>	gLocalLightShadowHiresSpotArray	REGISTER(t26);
	shared Texture2DArray   <float>	gLocalLightShadowLoresSpotArray	REGISTER(t27);
#else
	//without arrays the code will set these before each object as the set the lights
	shared Texture2D <float>	gLocalLightShadowSpot0	REGISTER(t24);
	shared TextureCube <float>	gLocalLightShadowCM1	REGISTER(t25);
	shared Texture2D <float>	gLocalLightShadowSpot1	REGISTER(t26);
#if LOCAL_SHADOWS_MAX_FORWARD_SHADOWS>2
	shared TextureCube <float>	gLocalLightShadowCM2	REGISTER(t27);
	shared Texture2D <float>	gLocalLightShadowSpot2	REGISTER(t28);
	shared TextureCube <float>	gLocalLightShadowCM3	REGISTER(t29);
	shared Texture2D <float>	gLocalLightShadowSpot3	REGISTER(t30);
#if LOCAL_SHADOWS_MAX_FORWARD_SHADOWS>4
	shared TextureCube <float>	gLocalLightShadowCM4	REGISTER(t31);
	shared Texture2D <float>	gLocalLightShadowSpot4	REGISTER(t32);  // durango seems to be limited to 32 textures, so for now we'll stay at 4 shadowed lights
	shared TextureCube <float>	gLocalLightShadowCM5	REGISTER(t33);
	shared Texture2D <float>	gLocalLightShadowSpot5	REGISTER(t34);
	shared TextureCube <float>	gLocalLightShadowCM6	REGISTER(t35);
	shared Texture2D <float>	gLocalLightShadowSpot6	REGISTER(t36);
	shared TextureCube <float>	gLocalLightShadowCM7	REGISTER(t37);
	shared Texture2D <float>	gLocalLightShadowSpot7	REGISTER(t38);
#endif // LOCAL_SHADOWS_MAX_FORWARD_SHADOWS>2
#endif // LOCAL_SHADOWS_MAX_FORWARD_SHADOWS>2

#endif // USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
#endif // ENABLE_FORWARD_LOCAL_LIGHT_SHADOWING

// ================================================================================================
// SAMPLERS
// ================================================================================================

#if LOCAL_SHADOWS_USE_HW_PCF_DX10
#define LOCALSHADOW_SAMPLER_STATE SamplerComparisonState
#else
#define LOCALSHADOW_SAMPLER_STATE sampler
#endif

#define SPOT_TEXTURE		gLocalLightShadowSpot0
#define CM_TEXTURE			gLocalLightShadowCM0
#define SPOT_SAMPLER		gShadowZSamplerCache
#define CM_SAMPLER			gShadowZSamplerCache


// we set up sampler 14, with gLocalLightShadowCM0, but we'll use it with other textures too...
#if USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
	BeginDX10SamplerShared(LOCALSHADOW_SAMPLER_STATE, TextureCubeArray, gLocalLightShadowCM0, gShadowZSamplerCache, gLocalLightShadowCM0, s14)
#else
	BeginDX10SamplerShared(LOCALSHADOW_SAMPLER_STATE, TextureCube, gLocalLightShadowCM0, gShadowZSamplerCache, gLocalLightShadowCM0, s14)
#endif
	ContinueSharedSampler(LOCALSHADOW_SAMPLER_STATE, gLocalLightShadowCM0, gShadowZSamplerCache, gLocalLightShadowCM0, s14)
 	AddressU  = WRAP;
 	AddressV  = WRAP;
#if LOCAL_SHADOWS_USE_HW_PCF_DX10
		MinFilter = LINEAR;
		MagFilter = LINEAR;
#if SUPPORT_INVERTED_VIEWPORT
		COMPARISONFUNC = COMPARISON_GREATER_EQUAL;
#else
		COMPARISONFUNC = COMPARISON_LESS_EQUAL;
#endif		
#else
		MinFilter = POINT;	  // If not using PCF, we need to use point samples for depth
		MagFilter = POINT;
#endif
	EndSharedSampler;

#if !ENABLE_FORWARD_LOCAL_LIGHT_SHADOWING 
	shared Texture2D <float>	gLocalLightShadowSpot0	REGISTER(t15);
#endif


#ifdef DEFERRED_UNPACK_LIGHT

	BeginDX10SamplerShared(sampler, Texture2D, gLocalDitherTexture, gLocalDitherTextureSamp, gLocalDitherTexture, s1)
	ContinueSharedSampler(sampler,  gLocalDitherTexture, gLocalDitherTextureSamp, gLocalDitherTexture, s1)
	AddressU  = WRAP;
	AddressV  = WRAP;
	MIPFILTER = NONE;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	EndSharedSampler;

#endif //DEFERRED_UNPACK_LIGHT


float3 CalcSpotShadowTexCoords(float3 eyeToCurrentPos, float4x4 localShadowData)  // depthRay is the eyeRray * depth (the vector from the eye to the point in camera space
{
	float3 shadowLocalPos = eyeToCurrentPos + localShadowData[3].xyz; // localShadowData[3].xyz is the camera position - the lights position
 
	float3 wPos;
	wPos.x = dot(shadowLocalPos,localShadowData[0].xyz);  // simplified matrix multiply, since we don't need depth (we use radius)
	wPos.y = dot(shadowLocalPos,localShadowData[1].xyz);
	wPos.z = dot(shadowLocalPos,localShadowData[2].xyz);

	float3 texCoord;
	texCoord.xy = wPos.xy / -wPos.z;
	texCoord.z = length(shadowLocalPos) * localShadowData[2].w;
	return texCoord * float3(0.5f,-0.5f,XENON_SWITCH(-1.0,1.0f)) + float3(0.5f,0.5f,XENON_SWITCH(1.0,0.0f)); // convert +/-1 to 0..1, and flip y (convert z to 1-z on xenon)
}

float3 CalcCubeMapShadowTexCoords(float3 eyeToCurrentPos, float4x4 localShadowData)
{
	float3 shadowLocalPos = eyeToCurrentPos + localShadowData[3].xyz; // localShadowData[3].xyz is the camera position - the lights position

	float3 wPos;
	wPos.x = dot(shadowLocalPos,localShadowData[0].xyz);  // rotate the point into light space
	wPos.y = dot(shadowLocalPos,localShadowData[1].xyz);
	wPos.z = dot(shadowLocalPos,localShadowData[2].xyz);

	return -wPos; // just the ray from the light source to the world pixel
}


// ================================================================================================
// Forward pass shadows
// ================================================================================================
#ifdef FORWARD_LOCAL_LIGHT_SHADOWING

#if USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
// NOTE THIS code path has most likely entropied...
float CalcForwardLocalLightShadowShadow(float3 worldPos, int shadowIndex)
{
#if ENABLE_FORWARD_LOCAL_LIGHT_SHADOWING
	bool useHiresArray = frac(gLocalLightShadowData[shadowIndex][1].w)>.25;
	int arrayIndex = floor(gLocalLightShadowData[shadowIndex][1].w);

	float eyeToCurrentPos = worldPos-gViewInverse[3].xyz;
	
	if(gLocalLightShadowData[shadowIndex][0].w==SHADOW_TYPE_SPOT)
	{
		float3 coords = CalcSpotShadowTexCoords(eyeToCurrentPos,gLocalLightShadowData[shadowIndex]);
	
 		Texture2DArray tex = useHiresArray?gLocalLightShadowHiresSpotArray:gLocalLightShadowLoresSpotArray;
 #if LOCAL_SHADOWS_USE_HW_PCF_DX10
 		return tex.SampleCmpLevelZero(SPOT_SAMPLER, SHADOW_TEXCOORDS(coords.xy), fixupDepth(coords.z));
 #else
 		return tex.Sample(SPOT_SAMPLER, SHADOW_TEXCOORDS(coords.xy)).x > fixupDepth(coords.z);
 #endif
	}
	else
	{
		float3 ray = CalcCubeMapShadowTexCoords(eyeToCurrentPos, gLocalLightShadowData[shadowIndex]);
		float4 ray_depth = float4(ray, length(ray)*gLocalLightShadowData[shadowIndex][2].w);
 		TextureCubeArray tex = useHiresArray?gLocalLightShadowHiresCubeArray:gLocalLightShadowLoresCubeArray;
#if LOCAL_SHADOWS_USE_HW_PCF_DX10
 		return tex.SampleCmpLevelZero(CM_SAMPLER, CUBEMAP_TEXCOORDS(ray_depth.xyz), fixupDepth(ray_depth.w));
#else
 		return tex.Sample(CM_SAMPLER, CUBEMAP_TEXCOORDS(ray_depth.xyz)).x > fixupDepth(ray_depth.w);
#endif
	}
	return 0; // NOT DONE YET
#else
	return 0;
#endif // ENABLE_FORWARD_LOCAL_LIGHT_SHADOWING

}
#else


#if LOCAL_SHADOWS_USE_HW_PCF_DX10
#define SAMPLE_SPOT_SHADOW(coords)	SampleCmpLevelZero(SPOT_SAMPLER, SHADOW_TEXCOORDS(coords.xy), fixupDepth(coords.z))
#define SAMPLE_CM_SHADOW(coords)	SampleCmpLevelZero(CM_SAMPLER, SHADOW_CUBEMAP_TEXCOORDS(coords.xyz), fixupDepth(coords.w))
#else
#define SAMPLE_SPOT_SHADOW(coords)  Sample(SPOT_SAMPLER, SHADOW_TEXCOORDS(coords.xy)).x > fixupDepth(coords.z)
#define SAMPLE_CM_SHADOW(coords)    Sample(CM_SAMPLER, SHADOW_CUBEMAP_TEXCOORDS(coords.xyz)).x > fixupDepth(coords.w)
#endif

#define LOOKUPLIGHT( n ) \
if (!isSpot){ \
	shadow = gLocalLightShadowCM##n .SAMPLE_CM_SHADOW(float4(ray, length(ray)*gLocalLightShadowData[shadowIndex][2].w)); \
} else {\
	shadow = gLocalLightShadowSpot##n .SAMPLE_SPOT_SHADOW(CalcSpotShadowTexCoords(eyeToCurrentPos, gLocalLightShadowData[shadowIndex])); \
} 


float CalcForwardLocalLightShadowShadow(float3 worldPos, uniform int shadowIndex)
{
	float shadow = 1;

#if ENABLE_FORWARD_LOCAL_LIGHT_SHADOWING

	if(gLocalLightShadowData[shadowIndex][0].w != SHADOW_TYPE_NONE 
		
#if defined(FORWARD_LOCAL_GLASS_LIGHT_SHADOWING) && (RSG_PC && !__LOW_QUALITY)  // it's expensive. just use it on PCs when enabled
 	    && gForwardLightShadowsOnGlass == 1.0f
#endif		
	   )
	{
		float3 eyeToCurrentPos = worldPos-gViewInverse[3].xyz;
		
		bool isSpot = gLocalLightShadowData[shadowIndex][0].w==SHADOW_TYPE_SPOT;
		float3 ray = CalcCubeMapShadowTexCoords(eyeToCurrentPos, gLocalLightShadowData[shadowIndex]);
				
		switch(shadowIndex)
		{
			case 0:
				LOOKUPLIGHT(0);	break;
			case 1:
				LOOKUPLIGHT(1);	break;
#if LOCAL_SHADOWS_MAX_FORWARD_SHADOWS>2
			case 2:
				LOOKUPLIGHT(2);	break;
			case 3:
				LOOKUPLIGHT(3);	break;
#if LOCAL_SHADOWS_MAX_FORWARD_SHADOWS>4
			case 4:
				LOOKUPLIGHT(4);	break;
			case 5:
				LOOKUPLIGHT(5);	break;
			case 6:
				LOOKUPLIGHT(6);	break;
			case 7:
				LOOKUPLIGHT(7);	break;
#endif // LOCAL_SHADOWS_MAX_FORWARD_SHADOWS>2
#endif // LOCAL_SHADOWS_MAX_FORWARD_SHADOWS>4
		}
	}

#endif // ENABLE_FORWARD_LOCAL_LIGHT_SHADOWING

	return shadow;
}
#endif // USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS

#endif //FORWARD_LOCAL_LIGHT_SHADOWING


// ================================================================================================
// Deferred shadows 
// ================================================================================================
#ifdef DEFERRED_UNPACK_LIGHT 

float LocalShadowDepthCmp( float3 uv_depth)
{
#if LOCAL_SHADOWS_USE_HW_PCF_DX10
	return SPOT_TEXTURE.SampleCmpLevelZero(SPOT_SAMPLER, SHADOW_TEXCOORDS(uv_depth.xy), fixupDepth(uv_depth.z));

#else
#if ((__SHADERMODEL >=40))
	return SPOT_TEXTURE.Sample(SPOT_SAMPLER, SHADOW_TEXCOORDS(uv_depth.xy)).x > fixupDepth(uv_depth.z);
#else
	return 1 ;// tex2D(SPOT_SAMPLER, SHADOW_TEXCOORDS(uv_depth.xy)).x > fixupDepth(uv_depth.z);
#endif
#endif
}

float LocalShadowCubeDepthCmp( float4 ray_depth)
{
#if LOCAL_SHADOWS_USE_HW_PCF_DX10
	return CM_TEXTURE.SampleCmpLevelZero(CM_SAMPLER, SHADOW_CUBEMAP_TEXCOORDS(ray_depth.xyz), fixupDepth(ray_depth.w));
#else
#if ((__SHADERMODEL >=40))
	return CM_TEXTURE.Sample(CM_SAMPLER, SHADOW_CUBEMAP_TEXCOORDS(ray_depth.xyz)).x > fixupDepth(ray_depth.w);
#else
	return 1; //texCUBE(CM_SAMPLER, SHADOW_CUBEMAP_TEXCOORDS(ray_depth.xyz)).x > fixupDepth(ray_depth.w);
#endif
#endif
}

float4 calcCubemapSoftSampleCoords(float3 ray, float3 offset, float depth, float3 ddepth_duvw)
{
	return  float4(ray + offset, depth + dot(ddepth_duvw,offset));
}

float3 CalcSoftSampleCoords(float3 uv_depth, float2 offset, float2 ddepth_duv)
{
	return float3(uv_depth.xy + offset, uv_depth.z + dot(ddepth_duv,offset));
}

// receiver plane depth bias. (see GDC 06 paper "Shadow Mapping: GPU-based Tips and Techniques", http://developer.amd.com/wordpress/media/2012/10/Isidoro-ShadowMapping.pdf)
float2 ComputeRecieverPlaneDepthBias(float3 texcoord, float3 scale)
{
	//Packing derivatives of u,v, and distance to light source w.r.t. screen space x, and y
	float3 duvdist_dx = ddx(texcoord.xyz)*scale;
	float3 duvdist_dy = ddy(texcoord.xyz)*scale;

	//Invert texture Jacobian and use chain rule to compute ddist/du and ddist/dv
	// |ddist/du| = |du/dx du/dy|-T * |ddist/dx|
	// |ddist/dv|   |dv/dx dv/dy|     |ddist/dy|
	float2 ddist_duv;

	//Multiply ddist/dx and ddist/dy by inverse transpose of Jacobian
	float invDet = 1 / ((duvdist_dx.x * duvdist_dy.y) - (duvdist_dx.y * duvdist_dy.x) );

	//Top row of 2x2
	ddist_duv.x = duvdist_dy.y * duvdist_dx.z;		// invJtrans[0][0] * ddist_dx
	ddist_duv.x -= duvdist_dx.y * duvdist_dy.z;		// invJtrans[0][1] * ddist_dy
	//Bottom row of 2x2
	ddist_duv.y = duvdist_dx.x * duvdist_dy.z;		// invJtrans[1][1] * ddist_dy
	ddist_duv.y -= duvdist_dy.x * duvdist_dx.z; 	// invJtrans[1][0] * ddist_dx
	ddist_duv *= invDet;

	return clamp(ddist_duv,-1,1); // add a clamp to avoid halos when ddx or ddy goes steep
}

float3 ComputeRecieverPlaneDepthBiasCubeMap(float4 texcoord)
{
	//Packing derivatives of u,v, and distance to light source w.r.t. screen space x, and y
	float4 duvwdist_dx = ddx(texcoord.xyzw);
	float4 duvwdist_dy = ddy(texcoord.xyzw);

	//Multiply ddist/dx and ddist/dy by inverse transpose of Jacobian

	//                                                                                             T (     T) -1
	// since we have a 2x3 matrix, we need to find the right-inverse.  for A the right inverse is A  ( A*A  )
	float2 AAT_Top    = float2(dot(duvwdist_dx.xyz,duvwdist_dx.xyz), dot(duvwdist_dx.xyz,duvwdist_dy.xyz));
	float2 AAT_Bottom = float2(dot(duvwdist_dx.xyz,duvwdist_dy.xyz), dot(duvwdist_dy.xyz,duvwdist_dy.xyz));
	
	float invDet = 1 / ((AAT_Top.x * AAT_Bottom.y) - (AAT_Top.y * AAT_Bottom.x) );
	float2 AATI_Top    = invDet * float2(AAT_Bottom.y,-AAT_Bottom.x);
	float2 AATI_Bottom = invDet * float2(-AAT_Top.y,  AAT_Top.x);

	// finally we get to the the transpose of the right inverse of/
	float3 ATATI_T_0 = float3(duvwdist_dx.x * AATI_Top.x + duvwdist_dy.x * AATI_Bottom.x, duvwdist_dx.y * AATI_Top.x + duvwdist_dy.y * AATI_Bottom.x, duvwdist_dx.z * AATI_Top.x + duvwdist_dy.z * AATI_Bottom.x );
	float3 ATATI_T_1 = float3(duvwdist_dx.x * AATI_Top.y + duvwdist_dy.x * AATI_Bottom.y, duvwdist_dx.y * AATI_Top.y + duvwdist_dy.y * AATI_Bottom.y, duvwdist_dx.z * AATI_Top.y + duvwdist_dy.z * AATI_Bottom.y);

	//TODO change this to use dot products and other optimizations
	
	float3 ddist_duvw;
	//multiply dist_dx and dist_dy but the matrix
	ddist_duvw.x =  duvwdist_dx.w * ATATI_T_0.x + duvwdist_dy.w * ATATI_T_1.x;		
	ddist_duvw.y =  duvwdist_dx.w * ATATI_T_0.y + duvwdist_dy.w * ATATI_T_1.y;		
	ddist_duvw.z =  duvwdist_dx.w * ATATI_T_0.z + duvwdist_dy.w * ATATI_T_1.z;		
	
	return clamp(ddist_duvw,-1,1); // add a clamp to avoid halos when ddx or ddy goes steep
}

float2 SampleDitherRotate(float2 v_, int rot)
{
	const float sqrt_1_2 = 0.70710678118654752440084436210485; // sqrt(1/2)

	float2 v = v_;

	// rotation in 45-degree increments (rot should be constant)
	if (0) {}
	else if (rot == 1) { v = float2(+v.x + v.y, +v.x - v.y)*sqrt_1_2; }
	else if (rot == 2) { v = float2(-v.y, +v.x); }
	else if (rot == 3) { v = float2(-v.x - v.y, +v.x - v.y)*sqrt_1_2; }
	else if (rot == 4) { v = float2(-v.x, -v.y); }
	else if (rot == 5) { v = float2(-v.x + v.y, -v.x - v.y)*sqrt_1_2; }
	else if (rot == 6) { v = float2(+v.y, -v.x); }
	else if (rot == 7) { v = float2(+v.x + v.y, -v.x + v.y)*sqrt_1_2; }

	return v;
}


float shadowSpot(float3 texCoords, float2 screenPos, bool softShadow, float shadowDitherRadius)
{
	if(softShadow)
	{
		const float2 ditherScale = float2(SCR_BUFFER_WIDTH, SCR_BUFFER_HEIGHT)*LOCALSHADOWS_DEFAULT_DITHER_SCALE/LOCALSHADOWS_DEFAULT_DITHER_RES; // constant
		const float3 ditherSample   = tex2D(gLocalDitherTextureSamp, screenPos*ditherScale).xyz;
		const float2 v = (ditherSample.xy*2.-1.f)*shadowDitherRadius;
		float2 ddist_duv = ComputeRecieverPlaneDepthBias(texCoords, 1.0f);

		const float2 v_a = v;
	
		float total = 0;
	
#if LOCAL_SHADOWS_SOFT_FILTER_TAPS==12		
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_a.x, +v_a.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_a.y, +v_a.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_a.x, -v_a.y)*(0.75), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_a.y, -v_a.x)*(0.25), ddist_duv));

		const float2 v_b = SampleDitherRotate(v_a, 3)*0.66; // rotate by 90 degrees
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_b.x, +v_b.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_b.y, +v_b.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_b.x, -v_b.y)*(0.75), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_b.y, -v_b.x)*(0.25), ddist_duv));

		const float2 v_c = SampleDitherRotate(v_a, 6)*0.33; // rotate by 180 degrees
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_c.x, +v_c.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_c.y, +v_c.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_c.x, -v_c.y)*(0.75), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_c.y, -v_c.x)*(0.25), ddist_duv));
		total/=12;

#elif LOCAL_SHADOWS_SOFT_FILTER_TAPS == 9
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_a.x, +v_a.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_a.y, +v_a.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_a.y, -v_a.x)*(0.25), ddist_duv));

		const float2 v_b = SampleDitherRotate(v_a, 3)*.77; // rotate by 135 degrees
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_b.x, +v_b.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_b.y, +v_b.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_b.y, -v_b.x)*(0.25), ddist_duv));

		const float2 v_c = SampleDitherRotate(v_a, 6)*.44; // rotate by 180 degrees
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_c.x, +v_c.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_c.y, +v_c.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_c.y, -v_c.x)*(0.25), ddist_duv));
		total/=9;

#else // original 16 tap
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_a.x, +v_a.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_a.y, +v_a.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_a.x, -v_a.y)*(0.75), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_a.y, -v_a.x)*(0.25), ddist_duv));

		const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; // rotate by 90 degrees
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_b.x, +v_b.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_b.y, +v_b.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_b.x, -v_b.y)*(0.75), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_b.y, -v_b.x)*(0.25), ddist_duv));

		const float2 v_c = SampleDitherRotate(v_a, 4)*0.777; // rotate by 180 degrees
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_c.x, +v_c.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_c.y, +v_c.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_c.x, -v_c.y)*(0.75), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_c.y, -v_c.x)*(0.25), ddist_duv));
		
		const float2 v_d = SampleDitherRotate(v_a, 6)*0.666; // rotate by 270 degrees
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_d.x, +v_d.y)*(1.00), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_d.y, +v_d.x)*(0.50), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(-v_d.x, -v_d.y)*(0.75), ddist_duv));
		total += LocalShadowDepthCmp(CalcSoftSampleCoords(texCoords.xyz, float2(+v_d.y, -v_d.x)*(0.25), ddist_duv));
		total /=16;
#endif
		return total;
	}
	else
	{
#if (__SHADERMODEL >=40)
		float2 shadowTexSize = float2(dShadowTextureWidth, dShadowTextureHeight);
		float2 shadowOneOverTexSize = float2(dShadowTextureOneOverWidth, dShadowTextureOneOverHeight);
#else
		float2 shadowTexSize = 256;			// don't really care about less than 4.0 Max does not use dynamic shadows
		float2 shadowOneOverTexSize = 1/shadowTexSize;   
#endif

 #if LOCAL_SHADOWS_USE_HW_PCF_DX10
		float total=0;
		total += LocalShadowDepthCmp(float3(texCoords.xy + float2(-0.5, -0.5)*shadowOneOverTexSize, texCoords.z));
		total += LocalShadowDepthCmp(float3(texCoords.xy + float2(+0.5, -0.5)*shadowOneOverTexSize, texCoords.z));
		total += LocalShadowDepthCmp(float3(texCoords.xy + float2(-0.5, +0.5)*shadowOneOverTexSize, texCoords.z));
		total += LocalShadowDepthCmp(float3(texCoords.xy + float2(+0.5, +0.5)*shadowOneOverTexSize, texCoords.z));
		return total/4; 
#else
		float4 Weights;
		Weights.xy = frac( texCoords.xy*shadowTexSize.xy ); 
		Weights.zw = 1.0 - Weights.xy;

		float3 accWeights = float3( Weights.z, 1.0f, Weights.x ) /(4.0f);
		texCoords.xy -= Weights.xy*shadowOneOverTexSize; // we like clean texel point sample coords

		float3 DepthRow0,DepthRow1,DepthRow2;

		DepthRow0.x = LocalShadowDepthCmp(float3(texCoords.xy + float2(-1.0,-1.0)*shadowOneOverTexSize,texCoords.z));  // todo: could use the offset parameter, since this is whoe pixels.
		DepthRow0.y = LocalShadowDepthCmp(float3(texCoords.xy + float2( 0.0,-1.0)*shadowOneOverTexSize,texCoords.z));
		DepthRow0.z = LocalShadowDepthCmp(float3(texCoords.xy + float2( 1.0,-1.0)*shadowOneOverTexSize,texCoords.z));

		DepthRow1.x = LocalShadowDepthCmp(float3(texCoords.xy + float2(-1.0, 1.0)*shadowOneOverTexSize,texCoords.z));
		DepthRow1.y = LocalShadowDepthCmp(float3(texCoords.xy + float2( 0.0, 1.0)*shadowOneOverTexSize,texCoords.z));
		DepthRow1.z = LocalShadowDepthCmp(float3(texCoords.xy + float2( 1.0, 1.0)*shadowOneOverTexSize,texCoords.z));

		DepthRow2.x = LocalShadowDepthCmp(float3(texCoords.xy + float2(-1.0, 0.0)*shadowOneOverTexSize,texCoords.z));
		DepthRow2.y = LocalShadowDepthCmp(float3(texCoords.xy + float2( 0.0, 0.0)*shadowOneOverTexSize,texCoords.z));
		DepthRow2.z = LocalShadowDepthCmp(float3(texCoords.xy + float2( 1.0, 0.0)*shadowOneOverTexSize,texCoords.z));

		float attenuation = 0;
		attenuation  = dot( DepthRow0.xyz, accWeights) * Weights.w;
		attenuation += dot( DepthRow1.xyz, accWeights) * Weights.y;
		attenuation += dot( DepthRow2.xyz, accWeights);
		return attenuation;
#endif
	}
}


// for real cubemaps, the texCoors is the ray to the world space point from the light source.
float shadowCubemap(float3 ray, float2 screenPos, bool softShadow)
{
	// calculate the cubemap Ray Tangent (for filtering offsets
	float radius = length(ray);
	ray /= radius;

	radius *= dShadowOneOverDepthRange;
	
	float3 absRay = abs(ray);
	float3 signRay = sign(ray);
	
	if (softShadow) 
	{	
		// compute the tangent and binormal in cubemap space
		float3 tangent = any(absRay.zz < absRay.xy) ? (any(absRay.yy < absRay.xz)?float3(0,0,-signRay.x):float3(-signRay.y,0,0)) : float3(-signRay.z,0,0);
		float3 binormal = normalize(cross(ray,tangent));
		tangent = cross(binormal,ray);
				
#if LOCAL_SHADOWS_USE_RPDB
		const float3 ddist_duvw = ComputeRecieverPlaneDepthBiasCubeMap(float4(ray,radius)); // this does not quite work with cubemaps, need better equation, for now do it per face..
#else
		const float3 ddist_duvw = float3(0,0,0);
#endif
		const float2 ditherScale	= float2(SCR_BUFFER_WIDTH, SCR_BUFFER_HEIGHT)*LOCALSHADOWS_DEFAULT_DITHER_SCALE/LOCALSHADOWS_DEFAULT_DITHER_RES; // constant
		const float3 ditherSample   = tex2D(gLocalDitherTextureSamp, screenPos*ditherScale).xyz;
		const float2 v				= ditherSample.xy*2.-1.f;
 
		tangent  *= dShadowDitherRadius*4;
 		binormal *= dShadowDitherRadius*4;

		const float2 v_a = v;
 
#if LOCAL_SHADOWS_SOFT_FILTER_TAPS==12
		const float2 v_b = SampleDitherRotate(v_a, 3)*.66; // rotate by 90 degrees
		const float2 v_c = SampleDitherRotate(v_a, 6)*.33; // rotate by 180 degrees
		// TODO: optimize this mess...

		float total = 0;
		const float3 v_ax = v_a.x*tangent;
		const float3 v_ay = v_a.y*binormal;
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_ax +v_ay)*(1.00), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_ay +v_ax)*(0.50), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_ax -v_ay)*(0.75), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_ay -v_ax)*(0.25), radius, ddist_duvw));

		const float3 v_bx = v_b.x*tangent;
		const float3 v_by = v_b.y*binormal;
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_bx +v_by)*(1.00), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_by +v_bx)*(0.50), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_bx -v_by)*(0.75), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_by -v_bx)*(0.25), radius, ddist_duvw));
	
		const float3 v_cx = v_c.x*tangent;
		const float3 v_cy = v_c.y*binormal;
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_cx +v_cy)*(1.00), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_cy +v_cx)*(0.50), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_cx -v_cy)*(0.75), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_cy -v_cx)*(0.25), radius, ddist_duvw));

		total/=12;
#elif LOCAL_SHADOWS_SOFT_FILTER_TAPS == 9
		float total = 0;

		const float3 v_ax = v_a.x*tangent;
		const float3 v_ay = v_a.y*binormal;

		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_ax +v_ay)*(1.00), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_ay +v_ax)*(0.50), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_ay -v_ax)*(0.25), radius, ddist_duvw));

		const float2 v_b = SampleDitherRotate(v_a, 3)*.77; // rotate by 135 degrees
		const float3 v_bx = v_b.x*tangent;
		const float3 v_by = v_b.y*binormal;
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_bx +v_by)*(1.00), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_by +v_bx)*(0.5), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_by -v_bx)*(0.25), radius, ddist_duvw));

		const float2 v_c = SampleDitherRotate(v_a, 6)*.44; // rotate by 180 degrees
		const float3 v_cx = v_c.x*tangent;
		const float3 v_cy = v_c.y*binormal;
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_cx +v_cy)*(1.00), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_cy +v_cx)*(0.5), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_cy -v_cx)*(0.25), radius, ddist_duvw));
	
		total/=9;
#elif LOCAL_SHADOWS_SOFT_FILTER_TAPS == 8 
		const float2 v_b = SampleDitherRotate(v_a, 3)*.875; // rotate by 45 degrees
	
		float reduceBlur = 2-sqrt(radius); //  reduce blur a little as we get close to the light
		tangent  /= reduceBlur;
		binormal /= reduceBlur;

		float total = 0;

		const float3 v_ax = v_a.x*tangent;
		const float3 v_ay = v_a.y*binormal;
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_ax +v_ay)*(1.00), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_ay +v_ax)*(0.50), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_ax -v_ay)*(0.75), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_ay -v_ax)*(0.25), radius, ddist_duvw));

		const float3 v_bx = v_b.x*tangent;
		const float3 v_by = v_b.y*binormal;
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_bx +v_by)*(0.25), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_by +v_bx)*(0.75), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (-v_bx -v_by)*(1.00), radius, ddist_duvw));
		total += LocalShadowCubeDepthCmp(calcCubemapSoftSampleCoords(ray, (+v_by -v_bx)*(0.50), radius, ddist_duvw));

		total/=8;
#else // 16 taps
		const float2 v_b = SampleDitherRotate(v_a, 2)*.888; // rotate by 90 degrees
		const float2 v_c = SampleDitherRotate(v_a, 4)*.777; // rotate by 180 degrees
		const float2 v_d = SampleDitherRotate(v_a, 6)*.666; // rotate by 270 degrees
	
		// TODO: optimize this mess...

		const float3 v_ax = v_a.x*tangent;
		const float3 v_ay = v_a.y*binormal;
		const float3 v_bx = v_b.x*tangent;
		const float3 v_by = v_b.y*binormal;
		const float3 v_cx = v_c.x*tangent;
		const float3 v_cy = v_c.y*binormal;
		const float3 v_dx = v_d.x*tangent;
		const float3 v_dy = v_d.y*binormal;
		
		float4 t0_a = calcCubemapSoftSampleCoords(ray, (+v_ax +v_ay)*(1.00), radius, ddist_duvw);
		float4 t1_a = calcCubemapSoftSampleCoords(ray, (-v_ay +v_ax)*(0.50), radius, ddist_duvw);
		float4 t2_a = calcCubemapSoftSampleCoords(ray, (-v_ax -v_ay)*(0.75), radius, ddist_duvw);
		float4 t3_a = calcCubemapSoftSampleCoords(ray, (+v_ay -v_ax)*(0.25), radius, ddist_duvw);

		float4 t0_b = calcCubemapSoftSampleCoords(ray, (+v_bx +v_by)*(1.00), radius, ddist_duvw);
		float4 t1_b = calcCubemapSoftSampleCoords(ray, (-v_by +v_bx)*(0.50), radius, ddist_duvw);
		float4 t2_b = calcCubemapSoftSampleCoords(ray, (-v_bx -v_by)*(0.75), radius, ddist_duvw);
		float4 t3_b = calcCubemapSoftSampleCoords(ray, (+v_by -v_bx)*(0.25), radius, ddist_duvw);

		float4 t0_c = calcCubemapSoftSampleCoords(ray, (+v_cx +v_cy)*(1.00), radius, ddist_duvw);
		float4 t1_c = calcCubemapSoftSampleCoords(ray, (-v_cy +v_cx)*(0.50), radius, ddist_duvw);
		float4 t2_c = calcCubemapSoftSampleCoords(ray, (-v_cx -v_cy)*(0.75), radius, ddist_duvw);
		float4 t3_c = calcCubemapSoftSampleCoords(ray, (+v_cy -v_cx)*(0.25), radius, ddist_duvw);
		
		float4 t0_d = calcCubemapSoftSampleCoords(ray, (+v_dx +v_dy)*(1.00), radius, ddist_duvw);
		float4 t1_d = calcCubemapSoftSampleCoords(ray, (-v_dy +v_dx)*(0.50), radius, ddist_duvw);
		float4 t2_d = calcCubemapSoftSampleCoords(ray, (-v_dx -v_dy)*(0.75), radius, ddist_duvw);
		float4 t3_d = calcCubemapSoftSampleCoords(ray, (+v_dy -v_dx)*(0.25), radius, ddist_duvw);
		
		float total = 0;
		total += LocalShadowCubeDepthCmp(t0_a);
		total += LocalShadowCubeDepthCmp(t1_a);
		total += LocalShadowCubeDepthCmp(t2_a);
		total += LocalShadowCubeDepthCmp(t3_a);

		total += LocalShadowCubeDepthCmp(t0_b);
		total += LocalShadowCubeDepthCmp(t1_b);
		total += LocalShadowCubeDepthCmp(t2_b);
		total += LocalShadowCubeDepthCmp(t3_b);

		total += LocalShadowCubeDepthCmp(t0_c);
		total += LocalShadowCubeDepthCmp(t1_c);
		total += LocalShadowCubeDepthCmp(t2_c);
		total += LocalShadowCubeDepthCmp(t3_c);
		
		total += LocalShadowCubeDepthCmp(t0_d);
		total += LocalShadowCubeDepthCmp(t1_d);
		total += LocalShadowCubeDepthCmp(t2_d);
		total += LocalShadowCubeDepthCmp(t3_d);
		total/=16;
#endif // USE_X_TAP_SOFT_FILTER

		return total;
	}
	else
	{

#if (__SHADERMODEL >=40 ) 
		float shadowOneOverTexSize = dShadowTextureOneOverWidth;
#else
		float shadowOneOverTexSize = 1/256;   // don't really care about less than 4.0 Max does not use dynamic shadows
#endif

		// forget about doing it the sphere space, just filter on the faces for now...
		
		float4 tangentAndMA = all(absRay.zz >= absRay.xy) ? float4(signRay.z,0,0,absRay.z) : (all(absRay.xx >= absRay.yz) ? float4(0,0,-signRay.x,absRay.x) : float4(1,0,0,absRay.y));
		float3 tangent		= tangentAndMA.xyz;
		float3 binormal		= ((tangentAndMA.w==absRay.y)?float3(0,0,-signRay.y) : float3(0,1,0));

#if (__SHADERMODEL >=40 ) 
		ray = ray/(2*shadowOneOverTexSize * tangentAndMA.w); // normalize the major axis and scale to the texel size, so we can get adjacent texels
#endif

#if LOCAL_SHADOWS_USE_HW_PCF_DX10
		float total= 0;
 		total += LocalShadowCubeDepthCmp(float4(ray + -0.5*tangent - 0.5*binormal, radius));
		total += LocalShadowCubeDepthCmp(float4(ray +  0.5*tangent - 0.5*binormal, radius));
		total += LocalShadowCubeDepthCmp(float4(ray + -0.5*tangent + 0.5*binormal, radius));
		total += LocalShadowCubeDepthCmp(float4(ray +  0.5*tangent + 0.5*binormal, radius));
		return total*0.25;
#else
		// this does not work well across seams, since it does not use a 3d tangent, etc. but we shoul dnot really be using it anyway, the HW PCF is beter and faster.
	
		// we project the ray on to the cubemap face, so we can get the fraction bits for interpolation
		float2 faceTexel = float2(dot(ray,tangent), dot(ray,binormal)); 

		float4 Weights;
		Weights.xy = frac(faceTexel);
		Weights.zw = 1.0 - Weights.xy;

		ray -= (Weights.x*tangent + Weights.y*binormal); // we like clean texel point sample coords
		
		float3 accWeights = float3( Weights.z, 1.0f, Weights.x ) /(4.0f);
		float3 DepthRow0,DepthRow1,DepthRow2;

		DepthRow0.x = LocalShadowCubeDepthCmp(float4(ray - tangent - binormal, radius));
		DepthRow0.y = LocalShadowCubeDepthCmp(float4(ray           - binormal, radius));
		DepthRow0.z = LocalShadowCubeDepthCmp(float4(ray + tangent - binormal, radius));

		DepthRow1.x = LocalShadowCubeDepthCmp(float4(ray - tangent + binormal, radius));
		DepthRow1.y = LocalShadowCubeDepthCmp(float4(ray		   + binormal, radius));
		DepthRow1.z = LocalShadowCubeDepthCmp(float4(ray + tangent + binormal, radius));

		DepthRow2.x = LocalShadowCubeDepthCmp(float4(ray - tangent           , radius));
		DepthRow2.y = LocalShadowCubeDepthCmp(float4(ray                     , radius));
		DepthRow2.z = LocalShadowCubeDepthCmp(float4(ray + tangent           , radius));

		float attenuation = 0;
		attenuation += dot( DepthRow0.xyz, accWeights) * Weights.w;
		attenuation += dot( DepthRow1.xyz, accWeights) * Weights.y;
		attenuation += dot( DepthRow2.xyz, accWeights);
		return attenuation;
#endif	
	}
}

#endif // DEFERRED_UNPACK_LIGHT
#endif // SHADOW_RECEIVING && (defined(DEFERRED_UNPACK_LIGHT) || defined(FORWARD_LOCAL_LIGHT_SHADOWING))
// #else
// 	#if (__SHADERMODEL < 40 ) 
// 		#define dLocalShadowData			0
// 		#define dShadowDitherRadius			1
// 		#define dShadowType					0
// 		#define	dShadowOneOverDepthRange	1
// 
// 		float shadowCubemap(float3 ray, float2 screenPos, bool softShadow) {return 1;}
// 		float shadowSpot(float3 texCoords, float2 screenPos, bool softShadow, float shadowDitherRadius) {return 1;}
// 		float3 CalcCubeMapShadowTexCoords(float3 worldPos, float localShadowData) {return float3(1,1,1);}
// 		float3 CalcSpotShadowTexCoords(float3 worldPos, float localShadowData) {return float3(1,1,1);}
// 		float LocalShadowDepthCmp( float3 uv_depth) {return 1;}
// 		float LocalShadowCubeDepthCmp( float4 ray_depth) {return 1;}
// 	#endif // (__SHADERMODEL >=40 ) 
#endif // (SHADOW_CASTING || SHADOW_RECEIVING) //&& (__SHADERMODEL >=40 ) 


#if SHADOW_CASTING_TECHNIQUES 

	#ifdef SHADOW_USE_TEXTURE

		#define DEFINE_ONE_LD_TECHNIQUE(name, vertShader, pixelShader) \
			technique name \
 			{ \
				pass p0 \
 				{ \
					VertexShader = compile VERTEXSHADER vertShader(); \
					PixelShader  = compile PIXELSHADER pixelShader##Opaque()  CGC_FLAGS(CGC_DEFAULTFLAGS); \
				} \
			}\
			technique shadtexture_##name \
 			{ \
				pass p0 \
 				{ \
					VertexShader = compile VERTEXSHADER vertShader(); \
					PixelShader  = compile PIXELSHADER pixelShader()  CGC_FLAGS(CGC_DEFAULTFLAGS); \
				} \
			}

	#else // not SHADOW_USE_TEXTURE

		#define DEFINE_ONE_LD_TECHNIQUE(name, vertShader, pixelShader) \
 			technique name \
 			{ \
				pass p0 \
 				{ \
					VertexShader = compile VERTEXSHADER vertShader(); \
					PixelShader  = compile PIXELSHADER pixelShader()  CGC_FLAGS(CGC_DEFAULTFLAGS); \
				} \
			}

	#endif // not SHADOW_USE_TEXTURE

	#define DEFINE_LD_TECHNIQUES(baseName, vertShader, skinVertShader, pixelShader) \
		DEFINE_ONE_LD_TECHNIQUE(baseName##_draw, vertShader, pixelShader) \
		DRAWSKINNED_TECHNIQUES_ONLY(DEFINE_ONE_LD_TECHNIQUE(baseName##_drawskinned, skinVertShader, pixelShader))

	#define DEFINE_LD_TECHNIQUES_SKINNED_ONLY(baseName, skinVertShader, pixelShader) \
		DRAWSKINNED_TECHNIQUES_ONLY(DEFINE_ONE_LD_TECHNIQUE(baseName##_drawskinned, skinVertShader, pixelShader))

	#if __PS3
		#define SHADERTECHNIQUE_LOCAL_SHADOWS(vertShader, skinVertShader, pixelShader) DEFINE_LD_TECHNIQUES(ldedgepoint, vertShader, skinVertShader, pixelShader)
		#define SHADERTECHNIQUE_LOCAL_SHADOWS_SKINNED_ONLY(skinVertShader, pixelShader) DEFINE_LD_TECHNIQUES_SKINNED_ONLY(ldedgepoint, skinVertShader, pixelShader)
	#elif __XENON || __WIN32PC || RSG_ORBIS
		#define SHADERTECHNIQUE_LOCAL_SHADOWS(vertShader, skinVertShader, pixelShader) DEFINE_LD_TECHNIQUES(ld, vertShader, skinVertShader, pixelShader)
		#define SHADERTECHNIQUE_LOCAL_SHADOWS_SKINNED_ONLY(skinVertShader, pixelShader) DEFINE_LD_TECHNIQUES_SKINNED_ONLY(ld, skinVertShader, pixelShader)
	#else
		#define SHADERTECHNIQUE_LOCAL_SHADOWS(vertShader, skinVertShader, pixelShader)
		#define SHADERTECHNIQUE_LOCAL_SHADOWS_SKINNED_ONLY(skinVertShader, pixelShader)
	#endif

#endif // SHADOW_CASTING_TECHNIQUES

#ifndef SHADERTECHNIQUE_LOCAL_SHADOWS
#define SHADERTECHNIQUE_LOCAL_SHADOWS(v,vs,p)
#endif

#ifndef SHADERTECHNIQUE_LOCAL_SHADOWS_SKINNED_ONLY
#define SHADERTECHNIQUE_LOCAL_SHADOWS_SKINNED_ONLY(vs,p)
#endif

#endif // LOCAL_SHADOW_GLOBALS_FXH
