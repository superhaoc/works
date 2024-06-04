// =============================================
// Lighting/Shadows/cascadeshadows_receiving.fxh
// (c) 2011 RockstarNorth
// =============================================

#ifndef _CASCADESHADOWS_RECEIVING_FXH_
#define _CASCADESHADOWS_RECEIVING_FXH_

#include "../../../renderer/Shadows/ParaboloidShadows_shared.h" // shared defines with the C++ code

// this constant buffer is now shaded between the cascade and local light shadows during forward rendering, since available global constant buffers are such a limit resource 
CBSHARED BeginConstantBufferPagedDX10(csmshader, b6)
	shared float4 gCSMShaderVars_shared[CASCADE_SHADOWS_SHADER_VAR_COUNT_SHARED_MAX] : gCSMShaderVars_shared
	#if __SHADERMODEL >= 40
	REGISTER(c52)	// possibly could be removed?
	#endif
	;
	#if __SHADERMODEL >= 40
	shared float4 gCSMDepthBias : gCSMDepthBias;
	shared float4 gCSMDepthSlopeBias : gCSMDepthSlopeBias;
	shared float4 gCSMResolution : gCSMResolution;
	#endif

	shared float4   gCSMShadowParams;               // xyz = shadowDirection, w = offset;
#define  gCloudOffset		gCSMShadowParams.w
#define  gShadowDirection	gCSMShadowParams.xyz

	#if __SHADERMODEL >= 40
		// these are for the forward lighting of local shadows, we put them here because constant buffers are very limited   and this buffer is already used
		#if USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
			shared row_major float4x4 gLocalLightShadowData[MAX_CACHED_PARABOLOID_SHADOWS] : gLocalLightShadowData; 
		#else
			shared row_major float4x4 gLocalLightShadowData[8] : gLocalLightShadowData; 
		#endif
		shared	float4	  gShadowTexParam	: gShadowTexParam; // in deferred pass: Shadow Texture x=Width, y=Height, z=1/Width, w=1/Height, in forward pass it's x = render local light shadows for glass
	#else
		shared row_major float4x4 gLocalLightShadowData[1] : gLocalLightShadowData;  // we keep running out of registers on SM3.0
	#endif

EndConstantBufferDX10(csmshader)

#if !DEFERRED_LOCAL_SHADOW_SAMPLING

#if CASCADE_SHADOW_TEXARRAY
#define gShadowRes   float4(CASCADE_SHADOWS_RES_X, CASCADE_SHADOWS_RES_Y, CASCADE_SHADOWS_RES_INV_X, CASCADE_SHADOWS_RES_INV_Y)
#else
#define gShadowRes   float4(CASCADE_SHADOWS_RES_X, CASCADE_SHADOWS_RES_Y*CASCADE_SHADOWS_COUNT, CASCADE_SHADOWS_RES_INV_X, CASCADE_SHADOWS_RES_INV_Y * (1.0f / CASCADE_SHADOWS_COUNT))
#endif
#define gShadowResHR float4(CASCADE_SHADOWS_RES_X*2, CASCADE_SHADOWS_RES_Y*2, CASCADE_SHADOWS_RES_INV_X * 0.5, CASCADE_SHADOWS_RES_INV_Y * 0.5f)


#include "cascadeshadows_sampling.fxh"

// ================================================================================================
// ================================================================================================

#define CASCADE_SHADOWS_SUPPORT_DITHER_WORLD         (1 &&  defined(DEBUG_SHADOWS_FX)) // 1=enable worldspace dithering (kinda slow)
#define CASCADE_SHADOWS_SUPPORT_NORMAL_OFFSET        (1 &&  defined(DEBUG_SHADOWS_FX)) // 1=enable normal offset (0 might save some instructions/regs)

#if defined(DEFERRED_UNPACK_LIGHT) && !defined(DEFERRED_UNPACK_LIGHT_CSM_FORWARD_ONLY)
	#define DEFERRED_ONLY(x) x
	#define DEFERRED_SWITCH(_if_DEFERRED_,_else_) _if_DEFERRED_
#else
	#define DEFERRED_ONLY(x)
	#define DEFERRED_SWITCH(_if_DEFERRED_,_else_) _else_
#endif

#if defined(DEBUG_SHADOWS_FX)
	#define DEBUG_SHADOWS_FX_ONLY(x) x
	#define DEBUG_SHADOWS_FX_SWITCH(_if_DEBUG_SHADOWS_FX_,_else_) _if_DEBUG_SHADOWS_FX_
#else
	#define DEBUG_SHADOWS_FX_ONLY(x)
	#define DEBUG_SHADOWS_FX_SWITCH(_if_DEBUG_SHADOWS_FX_,_else_) _else_
#endif

BeginSharedSampler		(sampler, gCSMCloudTexture, gCSMCloudSampler, gCSMCloudTexture, s12)
ContinueSharedSampler	(sampler, gCSMCloudTexture, gCSMCloudSampler, gCSMCloudTexture, s12)
AddressU		= WRAP;
AddressV		= WRAP;
MINFILTER		= LINEAR;
MAGFILTER		= LINEAR;
MIPFILTER		= NONE;//This causes seam issues along large depth discontinuities
EndSharedSampler;

#ifndef NVSTEREO
BeginSharedSampler		(sampler, gCSMSmoothStepTexture, gCSMSmoothStepSampler, gCSMSmoothStepTexture, s13)
ContinueSharedSampler	(sampler, gCSMSmoothStepTexture, gCSMSmoothStepSampler, gCSMSmoothStepTexture, s13)
AddressU	= CLAMP;
AddressV	= CLAMP;
MINFILTER	= LINEAR;
MAGFILTER	= LINEAR;
EndSharedSampler;
#endif // NVSTEREO

#if USE_PARTICLE_SHADOWS
#if CASCADE_SHADOW_TEXARRAY
BeginDX10Sampler(sampler, Texture2DArray, gCSMParticleShadowTexture, gCSMParticleShadowSamp, gCSMParticleShadowTexture)
#else
BeginDX10Sampler(sampler, Texture2D, gCSMParticleShadowTexture, gCSMParticleShadowSamp, gCSMParticleShadowTexture)
#endif
ContinueSampler( sampler,                 gCSMParticleShadowTexture, gCSMParticleShadowSamp, gCSMParticleShadowTexture)
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	AddressW  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
EndSampler;
#endif // USE_PARTICLE_SHADOWS

#if SHADOW_RECEIVING_VS
DECLARE_SHARED_SAMPLER(sampler2D, gCSMShadowTextureVS, gCSMShadowTextureVSSamp, s3, // overlap with ShadowZSamplerDirVS
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	AddressW  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);
#endif // SHADOW_RECEIVING_VS

#if CASCADE_SHADOWS_SUPPORT_DITHER
DECLARE_SHARED_SAMPLER(sampler2D, gCSMDitherTexture, gCSMDitherTextureSamp, s14, // overlap with ShadowZTextureCache
	AddressU  = WRAP;
	AddressV  = WRAP;
	MIPFILTER = NONE;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
);
#endif // CASCADE_SHADOWS_SUPPORT_DITHER


BeginConstantBufferDX10(cascadeshadows_recieving_locals)

float4 gCSMShaderVars_deferred[CASCADE_SHADOWS_SHADER_VAR_COUNT_DEFERRED];
#if defined(DEBUG_SHADOWS_FX)
float4 gCSMShaderVars_debug[CASCADE_SHADOWS_SHADER_VAR_COUNT_DEBUG];
#endif // defined(DEBUG_SHADOWS_FX)

#if USE_PARTICLE_SHADOWS
float4 particleShadowsParams;
#endif // USE_PARTICLE_SHADOWS

EndConstantBufferDX10(cascadeshadows_recieving_locals)

#define PARTICLE_SHADOWS_READ_TEXTURE	particleShadowsParams.x
#define PARTICLE_SHADOWS_COMBINE		particleShadowsParams.y

struct CascadeShadowsParams
{
	float3x3 worldToShadow33;
	int      sampleType; // eCSMSampleType
	float2   shadowFade;
	float2   ditherRadius0;
	float    ditherScale;
	bool     useIrregularFade;
	bool     usePrecomputedShadowPos;
	float3   shadowPos;
	float3   shadowDirection;
	float    edgeFilterRange;
#if defined(DEBUG_SHADOWS_FX)
	float    shadowDebugOpacity;
	float    shadowDebugSaturation;
	float    shadowDebugRingOpacity;
	float    shadowDebugGridOpacity;
	float2   shadowDebugGridDivisions;
#endif // defined(DEBUG_SHADOWS_FX)
};

CascadeShadowsParams CascadeShadowsParams_setup(int sampleType)
{
	CascadeShadowsParams params;

	params.worldToShadow33 = float3x3(gCSMShaderVars_shared[0].xyz, gCSMShaderVars_shared[1].xyz, gCSMShaderVars_shared[2].xyz);
	params.sampleType      = sampleType; // compile-time constant
	params.shadowFade      = float2(gCSMShaderVars_shared[0].w, gCSMShaderVars_shared[1].w);
	
	params.ditherRadius0   = CSM_DEFAULT_DITHER_RADIUS_V.xx*gShadowRes.zw; // DEFERRED_SWITCH(gCSMShaderVars_deferred[0].xy, CSM_DEFAULT_DITHER_RADIUS_V.xx/gShadowRes);
	params.ditherScale     = 1; 

	params.edgeFilterRange = gCSMShaderVars_deferred[0].w;

#if CSM_FORCE_MODIFICATIONS
	params.useIrregularFade = true;
#else // pack these into one value
	params.useIrregularFade = (gCSMShaderVars_shared[2].w) > 1;
#endif

#if defined(DEBUG_SHADOWS_FX)
	params.shadowDebugOpacity       = gCSMShaderVars_debug[0].x;
	params.shadowDebugRingOpacity   = gCSMShaderVars_debug[0].z;
	params.shadowDebugGridOpacity   = gCSMShaderVars_debug[0].w;
	params.shadowDebugGridDivisions = gCSMShaderVars_debug[1].xy;
	params.shadowDebugSaturation    = gCSMShaderVars_debug[2].x;
#endif // defined(DEBUG_SHADOWS_FX)

	params.shadowDirection          = -transpose(params.worldToShadow33)[2];

	params.usePrecomputedShadowPos  = false;
	params.shadowPos                = 0;

	return params;
}

//================================================================================================

float GetEdgeDither( CascadeShadowsParams p, float2 screenPos, float linearDepth )
{
#if CASCADE_USE_EDGE_DITHERING
	float2 dither=frac(screenPos.xy*gScreenSize.xy*.25f);
	return  linearDepth > 2. ? dot(dither,p.edgeFilterRange*float2(1.,2.f)): 0;
#else
	return 0.;
#endif
}

#define fogShadowGradientA half(gCSMShaderVars_shared[CASCADE_SHADOWS_SHADER_VAR_FOG_SHADOWS].x)
#define fogShadowGradientB half(gCSMShaderVars_shared[CASCADE_SHADOWS_SHADER_VAR_FOG_SHADOWS].y)
#define fogShadowAmount    half(gCSMShaderVars_shared[CASCADE_SHADOWS_SHADER_VAR_FOG_SHADOWS].z)
#define fogShadowFast      half(gCSMShaderVars_shared[CASCADE_SHADOWS_SHADER_VAR_FOG_SHADOWS].w) // applies to CalcCascadeShadowsFast only (water reflections)

float CalcFogShadowDensity(float3 worldPos)
{
	return sqrt(saturate(worldPos.z*fogShadowGradientA + fogShadowGradientB))*fogShadowAmount;
}

float2 SampleDither(float2 screenPos)
{
#if CASCADE_SHADOWS_SUPPORT_DITHER
	const float2 ditherScale = float2(SCR_BUFFER_WIDTH, SCR_BUFFER_HEIGHT)*CSM_DEFAULT_DITHER_SCALE/CASCADE_SHADOWS_DITHER_RES; // constant
	const float4 sampleD = tex2D(gCSMDitherTextureSamp, screenPos*ditherScale);
# if __SHADERMODEL>=40
	return sampleD.xy*2 - 1;
# else
	return sampleD.wx*2 - 1;
# endif	//__SHADERMODEL
#else	//CASCADE_SHADOWS_SUPPORT_DITHER
	return 0;
#endif	//CASCADE_SHADOWS_SUPPORT_DITHER
}


//================================================================================================

half CalcCloudShadowsCustom(sampler cloudSampler, sampler smoothStepSampler, float3 worldPos, float4 cloudShadowParams)
{
	half density = h2tex2D(cloudSampler, worldPos.xy/3500 - float2(cloudShadowParams.x, 0)).g;
	return h1tex1D(smoothStepSampler, density);
}

//================================================================================================

half CalcCloudShadows(float3 worldPos)
{
#if NVSTEREO
	half density = h2tex2D(gCSMCloudSampler, worldPos.xy/3500 - float2(gCloudOffset.x, 0)).g;
	return density;
#else // NVSTEREO
	return CalcCloudShadowsCustom(gCSMCloudSampler, gCSMSmoothStepSampler, worldPos, float4(gCloudOffset, 0, 0, 0));
#endif // NVSTEREO
	
}
//================================================================================================

#if defined(DEBUG_SHADOWS_FX)

float4 AlphaBlendComposite(float4 c, float3 colour, float opacity) // alpha blends {colour,opacity} on top of {c.xyz,c.w}
{
	return float4(lerp(c.xyz, colour, opacity), 1 - (1 - c.w)*(1 - opacity));
}

float4 CalcAestheticGrid(CascadeShadowsParams params, float2 f, float3 colour, float2 res, float ringOpacity, float gridOpacity, float2 gridDivisions)
{
	const float2 v = f*2 - 1;

	const float2 g1 = frac(f*res*gridDivisions.x);
	const float2 g2 = frac(f*res*gridDivisions.y);

	const float grid = pow(1 - min(min(g1.x, g1.y), min(1 - g1.x, 1 - g1.y)), 20);
	const float fine = pow(1 - min(min(g2.x, g2.y), min(1 - g2.x, 1 - g2.y)), 20);
	const float diag = pow(1 - min(abs(v.x - v.y), abs(v.x + v.y)), 200);
	const float axis = pow(1 - min(abs(v.x), abs(v.y)), 200);
	const float edge = pow(1 - min(abs(1 - abs(v.x)), abs(1 - abs(v.y))), 20);

	// note - to verify pixel stability, force grid=diag=edge=0
	const float g = all(abs(v) <= 1) ? saturate(fine*1 + grid*0.25 + edge*0) : 0;
	const float3 gridColour = lerp(colour*0.75, float3(1,1,1), g)*(1 - diag*0 - axis*0.5);

	float4 c = float4(gridColour*gridOpacity, gridOpacity);
	float  d = max(abs(v.x), abs(v.y)); // use dot(v, v) for cylinder selection

	c = AlphaBlendComposite(c, colour, pow(d, 12)*ringOpacity);
	c = AlphaBlendComposite(c, 1     , pow(d, 20)*ringOpacity); // ring outer highlight

	return c;
}

#if CASCADE_SHADOWS_SUPPORT_DITHER_WORLD

// note this only works when CASCADE_SHADOWS_DITHER_RES is 64
float2 CalcVolumeCoord(float3 worldPos, float2 res, float scale)
{
	const float i = dot(fmod(floor(worldPos*scale), 16), float3(1, 16, 16*16));

	return (float2(fmod(i, res.x), i/res.y) + 0.5)/res;
}

#endif // CASCADE_SHADOWS_SUPPORT_DITHER_WORLD

#if CASCADE_SHADOWS_ENTITY_ID_TARGET

DECLARE_SAMPLER(sampler2D, entityIDTexture, entityIDTextureSamp,
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);

#endif // CASCADE_SHADOWS_ENTITY_ID_TARGET

float4 CalcCascadeShadows_debug(CascadeShadowsParams params, float linearDepth, float3 eyePos, float3 worldPos, float3 worldNormal, float2 screenPos)
{
	const float4 shadowPos = float4(mul(worldPos - gViewInverse[3].xyz, params.worldToShadow33), 0);

	const float4 pos0 = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 0] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 0]; // transform into texture space
	const float4 pos1 = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 1] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 1];
	const float4 pos2 = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 2] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 2];
	const float4 pos3 = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 3] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 3];

	// pos.xy is +/-0.5, so abs|pos.xy| is <= 0.5 if shadowPos is within cascade
	float range = (1.0 - 1.5 * (float)CASCADE_SHADOWS_RES_INV_X) * 0.5f - GetEdgeDither( params, screenPos.xy, linearDepth); // have to allow for filtering
	float4 pos;

	if (params.sampleType == CSM_ST_HIGHRES_BOX4x4)
	{
		pos = float4(pos0.xyz, 0);
	}
	else
	{
		pos =
			max(abs(pos0.x), abs(pos0.y)) < range ? float4(pos0.xyz, 0) :
			max(abs(pos1.x), abs(pos1.y)) < range ? float4(pos1.xyz, 1) :
			max(abs(pos2.x), abs(pos2.y)) < range ? float4(pos2.xyz, 2) :
													float4(pos3.xyz, 3) ;
	}

	const float3 cascadeColour[] =
	{
		float3(0,0,1), // blue
		float3(0,1,0), // green
		float3(1,0,0), // red
		float3(1,0,1), // magenta
		float3(1,1,0), // yellow
		float3(0,1,1), // cyan
	};

	float3 temp;

	if      (pos.w == 0) { temp = cascadeColour[0]; }
	else if (pos.w == 1) { temp = cascadeColour[1]; }
	else if (pos.w == 2) { temp = cascadeColour[2]; }
	else                 { temp = cascadeColour[3]; }

	float4 colour = CalcAestheticGrid(
		params,
		pos.xy + 0.5,
		temp,
		gShadowRes.xy,
		params.shadowDebugRingOpacity,
		params.shadowDebugGridOpacity,
		params.shadowDebugGridDivisions*(params.sampleType == CSM_ST_HIGHRES_BOX4x4 ? 2 : 1)
	);

	if (max(abs(pos.x), abs(pos.y)) > 0.5)
	{
		colour = 0;
	}

	// apply saturation
	{
		colour.xyz = lerp(float3(1,1,1), colour.xyz, params.shadowDebugSaturation);
	}

	return colour;
}

#endif // defined(DEBUG_SHADOWS_FX)

// ================================================================================================

#include "../../../../rage/base/src/grcore/config_switches.h"
#define SIMULATE_DEPTH_BIAS	(GS_INSTANCED_SHADOWS && !SHADOW_RECEIVING_VS && !RSG_ORBIS)

float4 ComputeCascadeShadowsTexCoord(	CascadeShadowsParams params, float3 worldPos, float3 worldNormal, bool useFourCascades, bool useSimpleNormalOffset,
										out float2 ditherRadius, out float2 lastPos, out int cascadeIndex,
										float edgeDither, float linearDepth)
{
	float4 shadowPos;
	if(params.usePrecomputedShadowPos)
		shadowPos = float4(params.shadowPos, 0);
	else
		shadowPos = float4(mul(worldPos - gViewInverse[3].xyz, params.worldToShadow33), 0);

	float4 positions[4];
	positions[0] = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 0] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 0]; // transform into texture space
	positions[1] = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 1] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 1];
	positions[2] = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 2] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 2];
	positions[3] = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 3] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 3];

	if (!useFourCascades)
	{
		positions[3] = positions[2]; // TODO: place branches everywhere else
	}

	// pos.xy is +/-0.5, so abs|pos.xy| is <= 0.5 if shadowPos is within cascade
	float filterSizeTexels = CASCADE_SHADOW_TEXARRAY ? 0 : ((params.sampleType == CSM_ST_BOX4x4  || params.sampleType == CSM_ST_DITHER2_LINEAR) ? 3 : 1.5);
#if CASCADE_USE_EDGE_SMOOTHING
	filterSizeTexels+=4.;
#endif
	const float range = (1.0 - filterSizeTexels * (float)CASCADE_SHADOWS_RES_INV_X)*0.5 - edgeDither; // have to allow for filtering
	float4 pos;

	cascadeIndex = 3;

#if SIMULATE_DEPTH_BIAS
	float2 fDepthBiasSlope = float2(0.0f,0.0f);
#endif	//SIMULATE_DEPTH_BIAS
	if (params.sampleType == CSM_ST_HIGHRES_BOX4x4)
	{
		pos = float4(positions[0].xyz, (0.0 + 0.5)/CASCADE_SHADOWS_COUNT);
#if SIMULATE_DEPTH_BIAS
		fDepthBiasSlope = float2(gCSMDepthBias.x,gCSMDepthSlopeBias.x);
#endif	//SIMULATE_DEPTH_BIAS
	}
	else
	{
		cascadeIndex = (max(abs(positions[2].x), abs(positions[2].y)) < range)? 2 : cascadeIndex;
		cascadeIndex = (max(abs(positions[1].x), abs(positions[1].y)) < range)? 1 : cascadeIndex;
		cascadeIndex = (max(abs(positions[0].x), abs(positions[0].y)) < range)? 0 : cascadeIndex;
		pos.xyz = positions[cascadeIndex].xyz;
		pos.w   = (cascadeIndex + 0.5)/CASCADE_SHADOWS_COUNT;

#if SIMULATE_DEPTH_BIAS
		float4 depthBiasMask = float4(0, 1, 2, 3) == cascadeIndex;
		fDepthBiasSlope = float2(dot(depthBiasMask, gCSMDepthBias), dot(depthBiasMask, gCSMDepthSlopeBias));
#endif	//SIMULATE_DEPTH_BIAS
	}

#if CASCADE_USE_EDGE_SMOOTHING
	const float smoothRangeTexels	 = 256.f * (float)CASCADE_SHADOWS_RES_INV_X;
	const float smoothRangeTexelsInv = (float)CASCADE_SHADOWS_RES_X * (1.0f / 256.0f);
	const float ditherRange=1.5f * (float)CASCADE_SHADOWS_RES_INV_X;
	float edgeDist = max(abs(pos.x), abs(pos.y));
	float ditherSmooth = saturate( (edgeDist*2. - (1.-smoothRangeTexels))*smoothRangeTexelsInv);
	
	pos.z-=0.00004*ditherSmooth;
	ditherSmooth *= ditherRange;
#endif

	// rescale into vertical texture
	float num = 0.0f;
#if CASCADE_SHADOW_TEXARRAY
	num = pos.w * CASCADE_SHADOWS_COUNT - 0.5f;
#endif
	float4 texcoord = float4(pos.xyz, num);// + float3(0.5, 0.5, 0);
	texcoord.x += 0.5f;
	texcoord.y *= (params.sampleType == CSM_ST_HIGHRES_BOX4x4) ? 1 : 1.0/CASCADE_SHADOWS_COUNT;
	texcoord.y += pos.w;
#if CASCADE_SHADOW_TEXARRAY
	texcoord.y = (texcoord.y - (1.0/CASCADE_SHADOWS_COUNT * num)) * CASCADE_SHADOWS_COUNT;
#endif

#if SIMULATE_DEPTH_BIAS
	// ddx,ddy returns less value for steep sloped surface 
	if (fDepthBiasSlope.x != 0.0f)
	{
		texcoord.z -= fDepthBiasSlope.x;

		float3 duvdist_dx = ddx(texcoord);
		float3 duvdist_dy = ddy(texcoord);

		float invDet = 1.0f / ((duvdist_dx.x * duvdist_dy.y) - (duvdist_dx.y * duvdist_dy.x) );

		float2 ddist_duv;
		ddist_duv.x = duvdist_dy.y * duvdist_dx.z;
		ddist_duv.x -= duvdist_dx.y * duvdist_dy.z;

		ddist_duv.y = duvdist_dx.x * duvdist_dy.z;
		ddist_duv.y -= duvdist_dy.x * duvdist_dx.z;
		ddist_duv *= invDet;

		texcoord.z -= fDepthBiasSlope.y * clamp(ddist_duv.x/*ddistdx*/,0.0f,0.5f);
		texcoord.z -= fDepthBiasSlope.y * clamp(ddist_duv.y/*ddistdy*/,0.0f,0.5f);
	}
#endif	//SIMULATE_DEPTH_BIAS

	// dither radius cannot be controlled per-cascade anymore, so assume {4,3,2,1}/4 scaling factor
#if CASCADE_USE_SYNCHRONIZED_FILTERING	
	ditherRadius = params.ditherRadius0;
#else
	ditherRadius = (1 - (pos.w*CASCADE_SHADOWS_COUNT - 0.5f)*0.25f)*params.ditherRadius0;  
#endif	
#if CASCADE_USE_EDGE_SMOOTHING
	ditherRadius += ditherSmooth;
#endif
	lastPos = positions[3].xy;

	return texcoord.xyzw;
}

// ================================================================================================

#if USE_PARTICLE_SHADOWS
#define CALC_CASCADE_SHADOWS_RESULT float2
#else // not USE_PARTICLE_SHADOWS
#define CALC_CASCADE_SHADOWS_RESULT float
#endif // not USE_PARTICLE_SHADOWS

CALC_CASCADE_SHADOWS_RESULT CalcCascadeShadows_internal(CascadeShadowsParams params, float linearDepth, float3 eyePos, float3 worldPos, float3 worldNormal, float2 screenPos, bool applyOpacity, bool useFourCascades, bool useSimpleNormalOffset, bool useIrregularFade, bool combineParticleShadow)
{
	float2 ditherRadius = 0, ditherVec = 0, lastPos = 0;
	int cascadeIndex = 0;
	const float4 shadowRes   = (params.sampleType == CSM_ST_HIGHRES_BOX4x4) ? gShadowResHR : gShadowRes;
	const float2 ditherScale = float2(SCR_BUFFER_WIDTH, SCR_BUFFER_HEIGHT)*CSM_DEFAULT_DITHER_SCALE/CASCADE_SHADOWS_DITHER_RES; // constant

	float edgeDither = 0;


#if CASCADE_SHADOWS_SUPPORT_DITHER
#if CASCADE_DITHER_TEX_HAS_EDGE_FILTER

	const float3 ditherSample   = tex2D(gCSMDitherTextureSamp, screenPos*ditherScale).xyz;

#if CASCADE_USE_EDGE_DITHERING
	edgeDither = ditherSample.z*params.edgeFilterRange; 
#endif //CASCADE_USE_EDGE_DITHERING

	ditherVec = ditherSample.xy*2.-1.f;

#else

	ditherVec   = tex2D(gCSMDitherTextureSamp, screenPos*ditherScale).wx*2 - 1 ;
	float edgeDither = GetEdgeDither( params, screenPos.xy,linearDepth );

#endif
#endif //CASCADE_SHADOWS_SUPPORT_DITHER


	float4 texcoord = ComputeCascadeShadowsTexCoord(params, worldPos, worldNormal, useFourCascades, useSimpleNormalOffset, 
													ditherRadius, lastPos, cascadeIndex, //out params
													edgeDither, linearDepth);

	ditherRadius *= params.ditherScale;

	ShadowSampleParams sampleParams;
	sampleParams.samp      = SHADOWSAMPLER_TEXSAMP;
	sampleParams.texcoord  = texcoord;
	sampleParams.res       = shadowRes;
	sampleParams.v         = ditherVec;
	sampleParams.scale     = ditherRadius;
	sampleParams.ddist_duv = 0;
	
#if CASCADE_USE_RPDB
	if(params.sampleType == CSM_ST_POISSON16_RPDB_GNORM || 
	   params.sampleType == CSM_ST_CLOUDS_POISSON16_RPDB_GNORM
#if RSG_PC
		|| params.sampleType == CSM_ST_CLOUDS_BOX3x3
#endif
	   )
	{
		//compute shadow slope
		const float3 shadowNormal   = -mul(worldNormal, 
		                                   float3x3(gCSMShaderVars_shared[0].xyz, gCSMShaderVars_shared[1].xyz, gCSMShaderVars_shared[2].xyz));

		const float3 shadowBinormal = cross(shadowNormal, float3(0,0,-1));
		const float3 shadowTangent  = cross(shadowNormal, shadowBinormal);
		sampleParams.ddist_duv = normalize(shadowTangent.xy)*shadowTangent.z/length(shadowTangent.xy)/ //TODO: See if pow(length(), 2) is faster
		                                   gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + cascadeIndex].xy* //TODO: roll this into a single constant
			                               gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + cascadeIndex].z/
			                               float2(1.0f, 1.0f/CASCADE_SHADOWS_COUNT);
	}
	else
	{
		sampleParams.ddist_duv = ComputeRecieverPlaneDepthBias(params.shadowPos, 
		                                                       gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + cascadeIndex].xyz*
															   float3(1.0f, 1.0f/CASCADE_SHADOWS_COUNT, 1.0f));
	}
#endif //CASCADE_USE_RPDB

	// sampleType is fixed at compile time, so only one of these will be evaluated
	float shadowTemp = 1; if (0) {}
	#define ARG1_DEF_CSMSampleType(arg0, type) else if (params.sampleType == type) { shadowTemp = Sample_##type(sampleParams); }
	FOREACH_ARG1_DEF_CSMSampleType(arg0, ARG1_DEF_CSMSampleType)
	#undef  ARG1_DEF_CSMSampleType

	CALC_CASCADE_SHADOWS_RESULT shadow = shadowTemp;

#if USE_PARTICLE_SHADOWS

	shadow = float2(shadowTemp, 1);

	//Needed to added != 0 to this if statement to fix Nvidia compiler bug, not sure why it fixes it but it`ll do
	//for now until we can talk to Nvidia about it.
#if __SHADERMODEL >= 40
	if (PARTICLE_SHADOWS_READ_TEXTURE != 0)
		shadow.y = 1 - gCSMParticleShadowTexture.Sample(gCSMParticleShadowSamp, texcoord.xyw).a;
#else
	if (PARTICLE_SHADOWS_READ_TEXTURE != 0)
		shadow.y = 1 - tex2D(gCSMParticleShadowSamp, texcoord.xyw).a;
#endif

#endif // USE_PARTICLE_SHADOWS

	if (applyOpacity && params.sampleType != CSM_ST_HIGHRES_BOX4x4) // apply shadow opacity
	{
		const float fade = saturate(linearDepth*params.shadowFade.x + params.shadowFade.y);

		if (params.useIrregularFade && useIrregularFade)
		{
			float fadeLastCascade;
			const float2 a = abs(lastPos);

			if (useFourCascades)
			{
				fadeLastCascade = saturate(max(a.x, a.y)*15 - 0.42*15); // magic numbers?
			}
			else
			{
				fadeLastCascade = saturate(max(a.x, a.y)*15 - 0.40*15); // magic numbers?
			}

			shadow += (1 - fade)*fadeLastCascade;

		}
		else // fade purely based on distance from eye
		{
			shadow = 1 - (1 - shadow)*fade;
		}
	}

	shadow = saturate(shadow*shadow);

#if USE_PARTICLE_SHADOWS
	if (combineParticleShadow) // Compile time switch.
	{
		shadow.x = shadow.x*shadow.y;
	}
	else if (PARTICLE_SHADOWS_COMBINE) // Run-time switch.
	{
		shadow.x = shadow.x*shadow.y;
	}
#endif // USE_PARTICLE_SHADOWS

	return shadow;
}

// single-cascade version
float CalcCascadeShadows_internal_LastCascade(CascadeShadowsParams params, float linearDepth, float3 eyePos, float3 worldPos, int cascadeIndex)
{
	const float4 shadowRes = (params.sampleType == CSM_ST_HIGHRES_BOX4x4) ? gShadowResHR : gShadowRes;
	const float4 shadowPos = float4(mul(worldPos, params.worldToShadow33), 0);

	//  pos.xy is +/-0.5, so |pos.xy|^2 is <= 0.25 if shadowPos is within cascade
	const float4 pos = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + cascadeIndex] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + cascadeIndex]; // transform into texture space
	//const float3 pos =mul(float4(worldPos,1), gWorld);

	// rescale into vertical texture
	float4 texcoord = float4(pos.xyz + float3(0.5, 0.5, 0),0);  // could be all calculated
	texcoord.y += (float)cascadeIndex;
	texcoord.y *= (params.sampleType == CSM_ST_HIGHRES_BOX4x4) ? 1 : 1.0/CASCADE_SHADOWS_COUNT;

	ShadowSampleParams sampleParams;
	sampleParams.samp      = SHADOWSAMPLER_TEXSAMP;
	sampleParams.texcoord  = texcoord;
	sampleParams.res       = shadowRes;
	sampleParams.v         = 0;
	sampleParams.scale     = 0;
	sampleParams.ddist_duv = 0;
	// sampleType is fixed at compile time, so only one of these will be evaluated
	float shadow = 1; if (0) {}
	#define ARG1_DEF_CSMSampleType(arg0, type) else if (params.sampleType == type) { shadow = Sample_##type(sampleParams); }
	FOREACH_ARG1_DEF_CSMSampleType(arg0, ARG1_DEF_CSMSampleType)
	#undef  ARG1_DEF_CSMSampleType

	float fadeLastCascade = 0;
	float fade = saturate(linearDepth*params.shadowFade.x + params.shadowFade.y);

	// could do a fade texture lookup??
	const float2 a = abs(pos.xy);

	fadeLastCascade = saturate((max(a.x, a.y) - 0.45)*15); // magic numbers?

	return shadow + fade + fadeLastCascade; 
}

#if CASCADE_SHADOWS_STENCIL_REVEAL

// single-cascade version
float CalcCascadeShadowsStencilReveal_internal(CascadeShadowsParams params, float3 eyePos, float3 worldPos, float3 worldNormal, float2 screenPos, bool applyOpacity, int cascadeIndex)
{
	const float4 shadowRes   = (params.sampleType == CSM_ST_HIGHRES_BOX4x4) ? gShadowResHR : gShadowRes;
	const float4 shadowPos   = float4(mul(worldPos, params.worldToShadow33), 0);

	const float2 ditherVec	 = SampleDither(screenPos);

	// pos.xy is +/-0.5, so |pos.xy|^2 is <= 0.25 if shadowPos is within cascade
	const float4 pos = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + cascadeIndex] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + cascadeIndex]; // transform into texture space

#if CASCADE_SHADOWS_SUPPORT_DITHER
	// dither radius cannot be controlled per-cascade anymore, so assume {4,3,2,1}/4 scaling factor
	const float2 ditherRadius = (1 - (float)cascadeIndex * 0.25f)*params.ditherRadius0;
#else
	const float2 ditherRadius = float2(0.0f, 0.0f);
#endif

	// rescale into vertical texture
	float3 texcoord = pos.xyz + float3(0.5, 0.5, 0);
	texcoord.y += (float)cascadeIndex;
	texcoord.y *= (params.sampleType == CSM_ST_HIGHRES_BOX4x4) ? 1 : 1.0/CASCADE_SHADOWS_COUNT;

	// sampleType is fixed at compile time, so only one of these will be evaluated
	float shadow = 1; if (0) {}
	#define ARG1_DEF_CSMSampleType(arg0, type) else if (params.sampleType == type) { shadow = Sample_##type(SHADOWSAMPLER_TEXSAMP, texcoord, shadowRes, ditherVec, ditherRadius); }
	FOREACH_ARG1_DEF_CSMSampleType(arg0, ARG1_DEF_CSMSampleType)
	#undef  ARG1_DEF_CSMSampleType

	if (applyOpacity && params.sampleType != CSM_ST_HIGHRES_BOX4x4) // apply shadow opacity
	{
		shadow = 1 - (1 - shadow)*saturate(dot(worldPos - eyePos, worldPos - eyePos)*params.shadowFade.x + params.shadowFade.y);
		shadow = shadow*shadow; // square the output, makes the filter look much better
	}

	return shadow;
}

#endif // CASCADE_SHADOWS_STENCIL_REVEAL

float3 CalcCascadeShadowCoord_internal(CascadeShadowsParams params, float3 worldPos, int cascadeIndex)
{
	// [[OPTIMISE]] -- this could be a single matrix-vector multiply
	const float4 shadowPos = float4(mul(worldPos - gViewInverse[3].xyz, params.worldToShadow33), 0);
	const float4 pos = shadowPos*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + cascadeIndex] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + cascadeIndex];
	const float3 texcoord = pos.xyz + float3(0.5, 0.5, 0);
	return texcoord;
}

#endif // !DEFERRED_LOCAL_SHADOW_SAMPLING

#endif // _CASCADESHADOWS_RECEIVING_FXH_
