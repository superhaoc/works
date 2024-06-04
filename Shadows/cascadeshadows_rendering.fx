// ===========================
// cascadeshadows_rendering.fx
// (c) 2011 RockstarNorth
// ===========================
#pragma dcl position

#include "../../common.fxh"
#pragma constant 85//0

#define DEFERRED_UNPACK_LIGHT // hook up deferred shader vars to this shader (e.g. dither radius)

#define SHADOW_CASTING            (0)
#define SHADOW_CASTING_TECHNIQUES (0)
#define SHADOW_RECEIVING          (1)
#define SHADOW_RECEIVING_VS       (0)

#define USE_PARTICLE_SHADOWS	  (1 && PARTICLE_SHADOWS_SUPPORT)

#define CASCADE_USE_RPDB               (1)
#define CASCADE_SHADOWS_SUPPORT_DITHER (1)
#define CASCADE_SET_USE_EDGE_DITHERING

#include "../../../../rage/base/src/grcore/AA_shared.h"
#include "cascadeshadows.fxh"

#if SAMPLE_FREQUENCY
#define SAMPLE_INDEX	IN.sampleIndex
#else
#define SAMPLE_INDEX	0
#endif

// ================================================================================================

BEGIN_RAGE_CONSTANT_BUFFER(cascadeshadows_rendering_locals,b10)

ROW_MAJOR float4x4 viewToWorldProjectionParam; // w components store deferred projection params
float4   perspectiveShearParam;      // xy = shear offsets
float4   shadowParams2;				// x = ditherScale
#define  gDitherScale		shadowParams2.x

EndConstantBufferDX10(cascadeshadows_rendering_locals)

DECLARE_DX10_SAMPLER_INTERNAL(sampler, TEXTURE_DEPTH_TYPE, depthBuffer, depthBufferSamp,
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);

DECLARE_DX10_SAMPLER_MS(float4, normalBuffer, normalBufferSamp,
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);

#if ENABLE_EQAA && EQAA_DECODE_GBUFFERS
Texture2D<uint>	normalBufferFmask	REGISTER(t21);
#endif // ENABLE_EQAA && EQAA_DECODE_GBUFFERS

struct ShadowRenderVertexIn
{
	float4 pos : POSITION;
	float2 tex : TEXCOORD0;
};

struct ShadowRenderVertexOut
{
	DECLARE_POSITION(pos)
	float2 tex				: TEXCOORD0;
	float3 eye				: TEXCOORD1;
	float3 eyeShadowSpace	: TEXCOORD2;
};

struct ShadowRenderPixelIn
{
	DECLARE_POSITION_PSIN(pos)
	float2 tex							: TEXCOORD0;
#if SAMPLE_FREQUENCY
	inside_sample float3 eye			: TEXCOORD1;
	inside_sample float3 eyeShadowSpace : TEXCOORD2;
	uint sampleIndex					: SV_SampleIndex;
#else
	float3 eye							: TEXCOORD1;
	float3 eyeShadowSpace				: TEXCOORD2;
#endif// SAMPLE_FREQUENCY
};


float3 CalcEyeViewRayFromTex(float2 tex)
{
	const float4 deferredProjectionParam = float4(
		viewToWorldProjectionParam[0].w,
		viewToWorldProjectionParam[1].w,
		viewToWorldProjectionParam[2].w,
		viewToWorldProjectionParam[3].w
	);

	const float2 tcProj = ((tex*2 - 1)*float2(1,-1) + perspectiveShearParam.xy) * deferredProjectionParam.xy;
	const float3 eyeRay = mul(float3(tcProj, -1), (float3x3)viewToWorldProjectionParam); // in worldspace
	return eyeRay;
}

ShadowRenderVertexOut VS_ShadowRender(ShadowRenderVertexIn IN)
{
	ShadowRenderVertexOut OUT;
	OUT.pos				= IN.pos;
	
	OUT.eye				= CalcEyeViewRayFromTex(IN.tex);
	OUT.eyeShadowSpace	= mul(OUT.eye, float3x3(gCSMShaderVars_shared[0].xyz, gCSMShaderVars_shared[1].xyz, gCSMShaderVars_shared[2].xyz));
	OUT.tex = IN.tex;
	return OUT;
}

half4 PS_ShadowRenderCloudShadows(ShadowRenderPixelIn IN ) : COLOR
{
	const float4 deferredProjectionParam = float4(
		viewToWorldProjectionParam[0].w,
		viewToWorldProjectionParam[1].w,
		viewToWorldProjectionParam[2].w,
		viewToWorldProjectionParam[3].w
	);

	CascadeShadowsParams params = CascadeShadowsParams_setup(CSM_ST_DEFAULT);
	const float3 eyePos         = viewToWorldProjectionParam[3].xyz;
	const float3 eyeRay         = IN.eye;
#if MULTISAMPLE_TECHNIQUES
	const float  sampleDepth    = fetchTexDepth2DMS(depthBuffer, IN.tex, SAMPLE_INDEX, globalScreenSize.xy);
#else
	const float  sampleDepth    = tex2D(depthBufferSamp, IN.tex).x;
#endif // MULTISAMPLE_TECHNIQUES
	const float  linearDepth    = getLinearGBufferDepth(sampleDepth, deferredProjectionParam.zw);

#ifdef NVSTEREO
	float fStereoScalar = StereoToMonoScalar(linearDepth);
	fStereoScalar *= deferredProjectionParam.x;
	float3 StereorizedCamPos= viewToWorldProjectionParam[3].xyz + viewToWorldProjectionParam[0].xyz * fStereoScalar * -1.0f;
	const float3 worldPos		= StereorizedCamPos + eyeRay*linearDepth;
#else
	 
	const float3 worldPos       = eyePos + eyeRay*linearDepth;
#endif

	return lerp(CalcCloudShadows(worldPos), 0, CalcFogShadowDensity(worldPos));
}

half4 PS_ShadowRender_internal(ShadowRenderPixelIn IN, int sampleType, bool useFourCascades, bool lastCascadeOnly, bool orthographic, bool nosoft, bool cloudsAndParticlesOnly)
{
#if MULTISAMPLE_EMULATE_INTERPOLATOR
	adjustPixelInputForSample(depthBuffer, 0, IN.eye);
	adjustPixelInputForSample(depthBuffer, 0, IN.eyeShadowSpace);
#endif

	const float4 deferredProjectionParam = float4(
		viewToWorldProjectionParam[0].w,
		viewToWorldProjectionParam[1].w,
		viewToWorldProjectionParam[2].w,
		viewToWorldProjectionParam[3].w
	);

	const float orthoTileAspect = 1280.0/720.0;
	const float orthoTileSize = 150.0;
	const float3 orthoTileExtent = float3(orthoTileAspect, 1, 0)*orthoTileSize/2; // TODO -- support arbitrary tile extent and orientation

	float2 texCoord = IN.tex;
	float3 eyeRay   = orthographic ? -gViewInverse[2].xyz : IN.eye;
	float3 eyePos   = orthographic ? (gViewInverse[3].xyz + float3(IN.tex.x*2 - 1, -(IN.tex.y*2 - 1), 0)*orthoTileExtent) : viewToWorldProjectionParam[3].xyz;
	float3 worldPos;

	eyeRay = CalcEyeViewRayFromTex(texCoord);

#if MULTISAMPLE_TECHNIQUES
	uint depthIndex = SAMPLE_INDEX;
	const int3   iPos        = getIntCoordsWithEyeRay(depthBuffer, texCoord, depthIndex, gViewInverse, eyeRay, globalScreenSize.xy);
	const float  sampleDepth = depthBuffer.Load(iPos, depthIndex);
	uint normalIndex = SAMPLE_INDEX;
# if ENABLE_EQAA && EQAA_DECODE_GBUFFERS
	if (gMSAAFmaskEnabled)
	{
		const int shadeFmask = normalBufferFmask.Load( iPos, 0 );
		normalIndex = translateAASampleExt( shadeFmask, normalIndex );
	}
# endif // ENABLE_EQAA && EQAA_DECODE_GBUFFERS
	const float4 rawNormal   = normalBuffer.Load(iPos, normalIndex);
	const float3 worldNormal = rawNormal.xyz*2 - 1; // untwiddled, not normalizing as no linear sampling used
#else	//MULTISAMPLE_TECHNIQUES
	const float  sampleDepth = tex2D(depthBufferSamp, texCoord).x;
	const float4 rawNormal   = tex2D(normalBufferSamp, texCoord);
	const float3 worldNormal = normalize(rawNormal.xyz*2 - 1); // untwiddled
#endif	//MULTISAMPLE_TECHNIQUES
	const float  linearDepth = getLinearGBufferDepth(sampleDepth, deferredProjectionParam.zw);

#ifdef NVSTEREO
	if (!orthographic)
	{
		float fStereoScalar = StereoToMonoScalar(linearDepth);
		fStereoScalar *= deferredProjectionParam.x;
		float3 StereorizedCamPos = eyePos + viewToWorldProjectionParam[0].xyz * fStereoScalar * -1.0f;
		worldPos = StereorizedCamPos + eyeRay*linearDepth;
	}
	else
#endif // NVSTEREO
	{
		worldPos = eyePos + eyeRay*linearDepth;
	}

	CascadeShadowsParams params = CascadeShadowsParams_setup(sampleType);
#ifdef NVSTEREO
	// nvstereo needs to figure out left/right eye dependent info using depth information
	params.usePrecomputedShadowPos = !IsStereoActive();
#else
	params.usePrecomputedShadowPos = true;
#endif
	params.shadowPos	           = IN.eyeShadowSpace*linearDepth;

	if( params.sampleType == CSM_ST_DITHER16_RPDB || 
		params.sampleType == CSM_ST_CLOUDS_DITHER16_RPDB ||
		params.sampleType == CSM_ST_POISSON16_RPDB_GNORM ||
		params.sampleType == CSM_ST_CLOUDS_POISSON16_RPDB_GNORM)
	{
		params.ditherScale	= gDitherScale;
		//Using shadow pos derived from transformed worldpos causes a loss of precision far from origin, use relative shadowpos from camerapos for best results
	}

	CALC_CASCADE_SHADOWS_RESULT shadow;


	if (lastCascadeOnly)
	{
		shadow = CalcCascadeShadows_internal_LastCascade(params, linearDepth, eyePos, worldPos, CASCADE_SHADOWS_COUNT - 1);
	}
	else
	{
		shadow = CalcCascadeShadows_internal(params, linearDepth, eyePos, worldPos, worldNormal, texCoord, true, useFourCascades, true, true, false);
	}

	if (cloudsAndParticlesOnly)
		shadow.x = 1;

	if(params.sampleType >= CSM_ST_CLOUDS_FIRST || cloudsAndParticlesOnly)
	{
		// This accounts for dusk variations in the shadow reveal output that Nv shadows don't implement.
		float cloudFogShadow	= CalcCloudShadows(worldPos)*(1 - CalcFogShadowDensity(worldPos));
		shadow					= shadow*cloudFogShadow;
	}

#if USE_PARTICLE_SHADOWS
	if (nosoft)
	{
		shadow.x = min(shadow.x, shadow.y);
		return shadow.xxxx;
	}
	else
		return shadow.xyyy;
#else //USE_PARTICLE_SHADOWS
	return shadow.xxxx;
#endif //USE_PARTICLE_SHADOWS
}

half4 PS_ShadowRevealCloudsAndParticlesOnly(ShadowRenderPixelIn IN) : COLOR
{
	return PS_ShadowRender_internal(IN, CSM_ST_POINT, true, false, false, true, true);
}



/*
some shaders are faster with optimisation flags, some are slower .. here's a breakdown:
DF: I updated the numbers and removed techniques that are no longer around

filter type            non-opt     optimised
--------------------   ---------   ---------
CSM_ST_POINT           23 cycles   22 cycles (opt is faster by 1 cycles)
CSM_ST_LINEAR          22 cycles   21 cycles (opt is faster by 1 cycles)
CSM_ST_TWOTAP          24 cycles   23 cycles (opt is faster by 1 cycles)
CSM_ST_BOX3x3          29 cycles   26 cycles (opt is faster by 3 cycles)
CSM_ST_BOX4x4          37 cycles   34 cycles (opt is faster by 2 cycles)
CSM_ST_CUBIC           47 cycles   49 cycles (opt is faster by 1 cycles)
CSM_ST_DITHER4         35 cycles   32 cycles (opt is faster by 3 cycles)
CSM_ST_DITHER16        85 cycles   70 cycles (opt is faster by 3 cycles)
CSM_ST_SOFT16          85 cycles   70 cycles (opt is faster by 3 cycles)
*/

#if 1
	#define CGC_SHADOW_RENDER_FLAGS() CGC_FLAGS("-unroll all --O3 -fastmath -fastprecision -disablepc all")
#else
	#define CGC_SHADOW_RENDER_FLAGS() CGC_FLAGS(CGC_DEFAULTFLAGS)
#endif

// you are now entering MACRO CITY .. enjoy your visit

// ============================================================

#define DEF_ShadowRender_code(arg0, sampleType) \
	float4 PS_ShadowRender_##sampleType(ShadowRenderPixelIn IN) : COLOR \
	{ \
		return PS_ShadowRender_internal(IN, sampleType, true, false, false,false,false); \
	}

#define DEF_ShadowRender_pass(arg0, sampleType) \
	pass MSAA_NAME(pass_##sampleType) \
	{ \
		VertexShader = compile VERTEXSHADER			VS_ShadowRender(); \
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ShadowRender_##sampleType() CGC_SHADOW_RENDER_FLAGS(); \
	}

FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_ShadowRender_code)

technique MSAA_NAME(ShadowRender)
{
	FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_ShadowRender_pass)
}

#undef DEF_ShadowRender_code
#undef DEF_ShadowRender_pass

#define DEF_ShadowRenderNoSoft_code(arg0, sampleType) \
	float4 PS_ShadowRenderNoSoft_##sampleType(ShadowRenderPixelIn IN) : COLOR \
	{ \
		return PS_ShadowRender_internal(IN, sampleType, true, false, false,true,false); \
	}

#define DEF_ShadowRenderNoSoft_pass(arg0, sampleType) \
	pass MSAA_NAME(pass_##sampleType) \
	{ \
		VertexShader = compile VERTEXSHADER			VS_ShadowRender(); \
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ShadowRenderNoSoft_##sampleType() CGC_SHADOW_RENDER_FLAGS(); \
	}

FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_ShadowRenderNoSoft_code)

technique MSAA_NAME(ShadowRenderNoSoft)
{
	FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_ShadowRenderNoSoft_pass)
}

#undef DEF_ShadowRenderNoSoft_code
#undef DEF_ShadowRenderNoSoft_pass
// ============================================================

// Technique to render first three cascades of shadow map
#define DEF_SRFTCS_code(arg0, sampleType) \
	float4 PS_SRFTCS_##sampleType(ShadowRenderPixelIn IN) : COLOR \
	{ \
		return PS_ShadowRender_internal(IN, sampleType, false, false, false,false,false); \
	}

#define DEF_SRFTCS_pass(arg0, sampleType) \
	pass MSAA_NAME(pass_##sampleType) \
	{ \
		VertexShader = compile VERTEXSHADER			VS_ShadowRender(); \
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SRFTCS_##sampleType() CGC_SHADOW_RENDER_FLAGS(); \
	}

FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_SRFTCS_code)

technique MSAA_NAME(ShadowRenderFirstThreeCascades)
{
	FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_SRFTCS_pass)
}

#undef DEF_SRFTCS_code
#undef DEF_SRFTCS_pass


#define DEF_SRFTCSNoSoft_code(arg0, sampleType) \
	float4 PS_SRFTCSNoSoft_##sampleType(ShadowRenderPixelIn IN) : COLOR \
	{ \
		return PS_ShadowRender_internal(IN, sampleType, false, false, false,true,false); \
	}

#define DEF_SRFTCSNoSoft_pass(arg0, sampleType) \
	pass MSAA_NAME(pass_##sampleType) \
	{ \
		VertexShader = compile VERTEXSHADER			VS_ShadowRender(); \
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SRFTCSNoSoft_##sampleType() CGC_SHADOW_RENDER_FLAGS(); \
	}

FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_SRFTCSNoSoft_code)

technique MSAA_NAME(ShadowRenderFirstThreeCascadesNoSoft)
{
	FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_SRFTCSNoSoft_pass)
}

#undef DEF_SRFTCSNoSoft_code
#undef DEF_SRFTCSNoSoft_pass
// ============================================================

// Technique to render last cascade by itself
#define DEF_ShadowRenderLastCascade_code(arg0, sampleType) \
	float4 PS_ShadowRenderLastCascade_##sampleType(ShadowRenderPixelIn IN) : COLOR \
	{ \
		return PS_ShadowRender_internal(IN, sampleType, false, true, false,false,false); \
	}

#define DEF_ShadowRenderLastCascade_pass(arg0, sampleType) \
	pass MSAA_NAME(pass_##sampleType) \
	{ \
		VertexShader = compile VERTEXSHADER			VS_ShadowRender(); \
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ShadowRenderLastCascade_##sampleType() CGC_SHADOW_RENDER_FLAGS(); \
	}

FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_ShadowRenderLastCascade_code)

technique MSAA_NAME(ShadowRenderLastCascade)
{
	FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_ShadowRenderLastCascade_pass)
}

#undef DEF_ShadowRenderLastCascade_code
#undef DEF_ShadowRenderLastCascade_pass


#define DEF_ShadowRenderLastCascadeNoSoft_code(arg0, sampleType) \
	float4 PS_ShadowRenderLastCascadeNoSoft_##sampleType(ShadowRenderPixelIn IN) : COLOR \
	{ \
		return PS_ShadowRender_internal(IN, sampleType, false, true, false,true,false); \
	}

#define DEF_ShadowRenderLastCascadeNoSoft_pass(arg0, sampleType) \
	pass MSAA_NAME(pass_##sampleType) \
	{ \
		VertexShader = compile VERTEXSHADER			VS_ShadowRender(); \
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ShadowRenderLastCascadeNoSoft_##sampleType() CGC_SHADOW_RENDER_FLAGS(); \
	}

FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_ShadowRenderLastCascadeNoSoft_code)

technique MSAA_NAME(ShadowRenderLastCascadeNoSoft)
{
	FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF_ShadowRenderLastCascadeNoSoft_pass)
}

#undef DEF_ShadowRenderLastCascadeNoSoft_code
#undef DEF_ShadowRenderLastCascadeNoSoft_pass
// ============================================================


#if !defined(SHADER_FINAL)
float4 PS_ShadowRenderOrthographic_BANK_ONLY(ShadowRenderPixelIn IN) : COLOR
{
	return PS_ShadowRender_internal(IN, CSM_ST_BOX3x3, true, false, true,false,false);
}

technique MSAA_NAME(ShadowRenderOrthographic)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_ShadowRender();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ShadowRenderOrthographic_BANK_ONLY() CGC_SHADOW_RENDER_FLAGS();
	}
}

float4 PS_ShadowRenderOrthographicNoSoft_BANK_ONLY(ShadowRenderPixelIn IN) : COLOR
{
	return PS_ShadowRender_internal(IN, CSM_ST_BOX3x3, true, false, true,true,false);
}

technique MSAA_NAME(ShadowRenderOrthographicNoSoft)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_ShadowRender();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ShadowRenderOrthographicNoSoft_BANK_ONLY() CGC_SHADOW_RENDER_FLAGS();
	}
}
#endif // !defined(SHADER_FINAL)

// ============================================================

technique MSAA_NAME(ShadowRenderCloudShadows)
{
	pass MSAA_NAME(p0)
	{ 
		VertexShader	= compile VERTEXSHADER		VS_ShadowRender();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_ShadowRenderCloudShadows() CGC_FLAGS(CGC_DEFAULTFLAGS_NPC_HALF(1));
	}
};

technique MSAA_NAME(ShadowRevealCloudsAndParticlesOnly)
{
	pass MSAA_NAME(p0)
	{ 
		VertexShader	= compile VERTEXSHADER		VS_ShadowRender();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_ShadowRevealCloudsAndParticlesOnly() CGC_FLAGS(CGC_DEFAULTFLAGS_NPC_HALF(1));
	}
};

struct VS_INPUTSMOOTHSTEP
{
	float3 pos : POSITION;
	float2 tex : TEXCOORD0;
	float4 col : COLOR0;
};

ShadowRenderVertexOut VS_SmoothStep(VS_INPUTSMOOTHSTEP IN)
{
	ShadowRenderVertexOut OUT;
	OUT.pos            = float4(IN.pos.xy, 0, 1);
	OUT.eye            = float3(IN.pos.z, IN.tex.y, IN.col.x);
	OUT.eyeShadowSpace = 0;
	OUT.tex            = float2(IN.tex.x, IN.col.y);
	return OUT;
}

float4 PS_SmoothStep(ShadowRenderPixelIn IN) : COLOR
{
	float smoothVal = smoothstep(IN.eye.x, IN.eye.y, IN.tex.x);
	smoothVal		= lerp(smoothVal, IN.eye.z, IN.tex.y);
	smoothVal		= pow(smoothVal, 2.2);
	return smoothVal;
}

technique MSAA_NAME(SmoothStep)
{
	pass MSAA_NAME(draw)
	{
		VertexShader	= compile VERTEXSHADER		VS_SmoothStep();
		PixelShader		= compile MSAA_PIXEL_SHADER	PS_SmoothStep() CGC_SHADOW_RENDER_FLAGS();
	}
};

// ================================================================================================

#if CASCADE_SHADOWS_STENCIL_REVEAL

struct StencilRevealVertexOut
{
	float4 pos : POSITION;
};

ROW_MAJOR FLOAT4x4 StencilRevealShadowToWorld; // TODO -- combine into a single matrix
float4   StencilRevealCascadeSphere;

StencilRevealVertexOut VS_StencilReveal(ShadowRenderVertexIn IN)
{
	StencilRevealVertexOut OUT;

	float3 worldPos = mul(IN.pos, (float3x3)StencilRevealShadowToWorld);

	worldPos.xyz *= StencilRevealCascadeSphere.www;
	worldPos.xyz += StencilRevealCascadeSphere.xyz;

	OUT.pos = mul(float4(worldPos, 1), gWorldViewProj);

	return OUT;
}

float4 PS_ShadowRenderCascade_internal(ShadowRenderPixelIn IN, int sampleType, int cascadeIndex)
{
	const float4 deferredProjectionParam = float4(
		viewToWorldProjectionParam[0].w,
		viewToWorldProjectionParam[1].w,
		viewToWorldProjectionParam[2].w,
		viewToWorldProjectionParam[3].w
	);

	const float3 eyePos      = viewToWorldProjectionParam[3].xyz;
	const float3 eyeRay      = IN.eye;
	const float  sampleDepth = GBufferTexDepth2D(depthBufferSamp, IN.tex).x;
	const float  linearDepth = getLinearDepth(sampleDepth, deferredProjectionParam.zw);
	const float3 worldNormal = normalize(tex2D(normalBufferSamp, IN.tex).xyz*2 - 1); // untwiddled
	const float3 worldPos    = eyePos + eyeRay*linearDepth;

	const CascadeShadowsParams params = CascadeShadowsParams_setup(sampleType);

	float shadow = CalcCascadeShadowsStencilReveal_internal(params, eyePos, worldPos, worldNormal, IN.tex, true, cascadeIndex);

	shadow = 1 - shadow;

	return shadow.xxxx;
}

#define DEF_ShadowRenderCascade_code(cascadeIndex, sampleType) \
	float4 PS_ShadowRenderCascade##cascadeIndex##_##sampleType(ShadowRenderPixelIn IN) : COLOR \
	{ \
		return PS_ShadowRenderCascade_internal(IN, sampleType, cascadeIndex); \
	}

#define DEFERRED_MATERIAL_SHADOW_00 0
#define DEFERRED_MATERIAL_SHADOW_01 32
#define DEFERRED_MATERIAL_SHADOW_10 64
#define DEFERRED_MATERIAL_SHADOW_11 96

// [TODO -- STATEBLOCK (CASCADE_SHADOWS_STENCIL_REVEAL)]
#define DEF_ShadowRenderCascade_pass(cascadeIndex, sampleType, _stencilref_) \
	pass pass_##cascadeIndex##_##sampleType \
	{ \
		DEF_ShadowRender_states(); \
		StencilEnable    = true; \
		StencilPass      = keep; \
		StencilFail      = keep; \
		StencilZFail     = keep; \
		StencilFunc      = equal; \
		StencilRef       = _stencilref_; \
		StencilMask      = DEFERRED_MATERIAL_SHADOW_11; \
		StencilWriteMask = 0; \
		VertexShader     = compile VERTEXSHADER VS_ShadowRender(); \
		PixelShader      = compile PIXELSHADER  PS_ShadowRenderCascade##cascadeIndex##_##sampleType() CGC_SHADOW_RENDER_FLAGS(); \
	}

FOREACH_ARG1_DEF_CSMSampleType(0, DEF_ShadowRenderCascade_code)
FOREACH_ARG1_DEF_CSMSampleType(1, DEF_ShadowRenderCascade_code)
FOREACH_ARG1_DEF_CSMSampleType(2, DEF_ShadowRenderCascade_code)
FOREACH_ARG1_DEF_CSMSampleType(3, DEF_ShadowRenderCascade_code)

technique StencilReveal
{
	pass reveal0 // [TODO -- STATEBLOCK (CASCADE_SHADOWS_STENCIL_REVEAL)]
	{
		ColorWriteEnable = 0;
		CullMode         = CCW;
		ZEnable          = true;
		ZWriteEnable     = false;
		ZFunc            = greater;
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;
		StencilEnable    = true;
		StencilPass      = invert;
		StencilFail      = keep;
		StencilZFail     = keep;
		StencilFunc      = equal;
		StencilRef       = DEFERRED_MATERIAL_SHADOW_00;
		StencilMask      = DEFERRED_MATERIAL_SHADOW_11;
		StencilWriteMask = DEFERRED_MATERIAL_SHADOW_01; // 00 -> 01
		VertexShader     = compile VERTEXSHADER VS_StencilReveal();
		COMPILE_PIXELSHADER_NULL()
	}

	pass reveal1 // [TODO -- STATEBLOCK (CASCADE_SHADOWS_STENCIL_REVEAL)]
	{
		ColorWriteEnable = 0;
		CullMode         = CCW;
		ZEnable          = true;
		ZWriteEnable     = false;
		ZFunc            = greater;
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;
		StencilEnable    = true;
		StencilPass      = invert;
		StencilFail      = keep;
		StencilZFail     = keep;
		StencilFunc      = equal;
		StencilRef       = DEFERRED_MATERIAL_SHADOW_00;
		StencilMask      = DEFERRED_MATERIAL_SHADOW_11;
		StencilWriteMask = DEFERRED_MATERIAL_SHADOW_10; // 00 -> 10
		VertexShader     = compile VERTEXSHADER VS_StencilReveal();
		COMPILE_PIXELSHADER_NULL()
	}

	pass reveal2 // [TODO -- STATEBLOCK (CASCADE_SHADOWS_STENCIL_REVEAL)]
	{
		ColorWriteEnable = 0;
		CullMode         = CCW;
		ZEnable          = true;
		ZWriteEnable     = false;
		ZFunc            = greater;
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;
		StencilEnable    = true;
		StencilPass      = invert;
		StencilFail      = keep;
		StencilZFail     = keep;
		StencilFunc      = equal;
		StencilRef       = DEFERRED_MATERIAL_SHADOW_00;
		StencilMask      = DEFERRED_MATERIAL_SHADOW_11;
		StencilWriteMask = DEFERRED_MATERIAL_SHADOW_11; // 00 -> 11
		VertexShader     = compile VERTEXSHADER VS_StencilReveal();
		COMPILE_PIXELSHADER_NULL()
	}

	DEF_ShadowRenderCascade_pass(0, CSM_ST_DITHER4, DEFERRED_MATERIAL_SHADOW_01)
	DEF_ShadowRenderCascade_pass(1, CSM_ST_DITHER4, DEFERRED_MATERIAL_SHADOW_10)
	DEF_ShadowRenderCascade_pass(2, CSM_ST_DITHER4, DEFERRED_MATERIAL_SHADOW_11)
	DEF_ShadowRenderCascade_pass(3, CSM_ST_DITHER4, DEFERRED_MATERIAL_SHADOW_00)
}

#undef DEF_ShadowRenderCascade_code
#undef DEF_ShadowRenderCascade_pass

#endif // CASCADE_SHADOWS_STENCIL_REVEAL
