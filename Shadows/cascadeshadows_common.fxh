// =========================
// cascadeshadows_common.fxh
// (c) 2011 RockstarNorth
// =========================

#ifndef _CASCADESHADOWS_COMMON_FXH_
#define _CASCADESHADOWS_COMMON_FXH_

#include "../../../../rage/base/src/grcore/config_switches.h"

#if __XENON || __PS3
	#define CASCADE_SHADOWS_RES_X      640 // Changing this for the PS3 is no longer so simple, render target pools assume width=640
	#define CASCADE_SHADOWS_RES_Y      640
	#define CASCADE_SHADOWS_RES_XY     float2(CASCADE_SHADOWS_RES_X, CASCADE_SHADOWS_RES_Y)
	#define CASCADE_SHADOWS_RES_INV_X  1.0f/640.f
	#define CASCADE_SHADOWS_RES_INV_Y  1.0f/640.f
	#define CASCADE_SHADOWS_RES_INV_XY float2(CASCADE_SHADOWS_RES_INV_X, CASCADE_SHADOWS_RES_INV_Y)
	#define CASCADE_SHADOWS_RES_VS_X   320
	#define CASCADE_SHADOWS_RES_VS_Y   320
	#define CASCADE_SHADOWS_RES_MINI_X 320
	#define CASCADE_SHADOWS_RES_MINI_Y 320
#elif defined(__SHADERMODEL) && (__SHADERMODEL >= 40)
	#define CASCADE_SHADOWS_RES_X      gCSMResolution.x
	#define CASCADE_SHADOWS_RES_Y      gCSMResolution.y
	#define CASCADE_SHADOWS_RES_XY     gCSMResolution.xy
	#define CASCADE_SHADOWS_RES_INV_X  gCSMResolution.z
	#define CASCADE_SHADOWS_RES_INV_Y  gCSMResolution.w
	#define CASCADE_SHADOWS_RES_INV_XY gCSMResolution.zw
	#define CASCADE_SHADOWS_RES_VS_X   512
	#define CASCADE_SHADOWS_RES_VS_Y   512
	#define CASCADE_SHADOWS_RES_MINI_X 512
	#define CASCADE_SHADOWS_RES_MINI_Y 512
#else
	#define CASCADE_SHADOWS_RES_X      1024
	#define CASCADE_SHADOWS_RES_Y      1024
	#define CASCADE_SHADOWS_RES_XY     float2(CASCADE_SHADOWS_RES_X, CASCADE_SHADOWS_RES_Y)
	#define CASCADE_SHADOWS_RES_INV_X  1.0f/1024.f
	#define CASCADE_SHADOWS_RES_INV_Y  1.0f/1024.f
	#define CASCADE_SHADOWS_RES_INV_XY float2(CASCADE_SHADOWS_RES_INV_X, CASCADE_SHADOWS_RES_INV_Y)
	#define CASCADE_SHADOWS_RES_VS_X   512
	#define CASCADE_SHADOWS_RES_VS_Y   512
	#define CASCADE_SHADOWS_RES_MINI_X 512
	#define CASCADE_SHADOWS_RES_MINI_Y 512
#endif

#ifndef DEFERRED_LOCAL_SHADOW_SAMPLING
#define DEFERRED_LOCAL_SHADOW_SAMPLING 0
#endif

#ifndef LOCAL_SHADOWS_USE_HW_PCF_DX10
#define LOCAL_SHADOWS_USE_HW_PCF_DX10 0 
#endif

#define CASCADE_SHADOWS_USE_HW_PCF_DX10 (1 && (RSG_PC || RSG_DURANGO || RSG_ORBIS) && __SHADERMODEL >= 40)
#define CASCADE_SHADOWS_DO_SOFT_FILTERING (1 && (__WIN32PC || RSG_DURANGO || RSG_ORBIS)) //  && !__LOW_QUALITY) // Disabled via code to not use soft shadows.
#if CASCADE_SHADOWS_DO_SOFT_FILTERING
	#define SOFT_FILTERING_ONLY(x) x
#else
	#define SOFT_FILTERING_ONLY(x)
#endif

#ifdef CASCADE_SET_USE_EDGE_DITHERING
#define CASCADE_USE_EDGE_DITHERING (1)
#else
#define CASCADE_USE_EDGE_DITHERING (0)	  	// This controls the dithering between the cascade boundaries
#endif

#define CASCADE_USE_EDGE_SMOOTHING 0
#define CASCADE_USE_SYNCHRONIZED_FILTERING (1 * CASCADE_SHADOWS_DO_SOFT_FILTERING)
#define CASCADE_SYNCHRONIZED_FILTERING_ON (CASCADE_SHADOWS_DO_SOFT_FILTERING ? false : true)

#if CASCADE_USE_SYNCHRONIZED_FILTERING
#define CASCADE_SHADOWS_DITHER_RES       64
#else
#define CASCADE_SHADOWS_DITHER_RES       64
#endif
#define CASCADE_DITHER_TEX_HAS_EDGE_FILTER	1

#define CASCADE_SHADOWS_VS_CASCADE_INDEX 2 // used for particle and light shaft shadowing
#define CASCADE_SHADOWS_PS_CASCADE_INDEX 1 // mini (downsampled) for postfx shadows

#define CASCADE_SHADOWS_SHADER_VAR_COUNT_SHARED_MAX 12 // max is 12 (c50..c61)
#define CASCADE_SHADOWS_SHADER_VAR_COUNT_SHARED   4 + CASCADE_SHADOWS_COUNT + CASCADE_SHADOWS_COUNT
#define CASCADE_SHADOWS_SHADER_VAR_COUNT_DEFERRED 1
#define CASCADE_SHADOWS_SHADER_VAR_COUNT_DEBUG    3
#define CASCADE_SHADOWS_SHADER_VAR_FOG_SHADOWS	  3


#define CASCADE_SHADOWS_NUM_PORTAL_BOUNDS				8

#define _cascadeBoundsConstA_packed_start 4 // offset into gCSMShaderVars_shared
#define _cascadeBoundsConstB_packed_start (_cascadeBoundsConstA_packed_start + CASCADE_SHADOWS_COUNT)

#define CASCADE_SHADOWS_CLOUD_SHADOWS             (1)
#define CASCADE_SHADOWS_CLOUD_SHADOWS_ON_WATER_FX (1 /*&& __PS3*/ && CASCADE_SHADOWS_CLOUD_SHADOWS)

#define CASCADE_SHADOWS_TREE_MICROMOVEMENTS       ((RSG_ORBIS || RSG_DURANGO || RSG_PC) ? 1 : 0) // <-- this is expensive, but worth keeping around for testing

/*
a bunch of semi-experimental features which are all interdependent in strange ways .. just awesome
currently STENCIL_REVEAL cannot be used on conjunction with BLEND_WITH_GBUFFER (since it blows the
TinySharedHeap::EncodeHandle in effect_internal.h, which limits the number of renderstates in a
shader pass to 15, and there are 17). also PROCESSING is not supported with BLEND_WITH_GBUFFER, and
on the 360 the only supported feature is BLEND_WITH_GBUFFER. if TARGET_SCALE is not 1, then both
STENCIL_REVEAL and BLEND_WITH_GBUFFER are not supported, since they require a full-res target.
*/

#if !defined(__GTA_COMMON_FXH)
#define CASCADE_SHADOWS_ALTERNATE_SHADOW_MAPS 0
//((1 && __XENON) || ( __PS3 && __DEV ) || (1 && __WIN32PC) || (1 && RSG_DURANGO))
#endif
// Forces the base pass to use point shadow sampling for speed.
#define CASCADE_SHADOWS_SOFT_FILTERING_USE_POINT_AS_BASE_FILTER 0

#define CASCADE_SHADOWS_STENCIL_REVEAL     (0 && __PS3) // experimental .. histencil not supported on 360 yet, cannot be used with processing or blend
#define CASCADE_SHADOWS_ENTITY_ID_TARGET__ (0 && __PS3) // <- change this to enable/disable shadow entity IDs

#if CASCADE_SHADOWS_ENTITY_ID_TARGET__
	#if defined(__GTA_COMMON_FXH) // shader code
		#define CASCADE_SHADOWS_ENTITY_ID_TARGET 1
	#elif __DEV // engine code, dev
		#define CASCADE_SHADOWS_ENTITY_ID_TARGET 1
	#else // engine code, non-dev
		#define CASCADE_SHADOWS_ENTITY_ID_TARGET 0
	#endif
#else
	#define CASCADE_SHADOWS_ENTITY_ID_TARGET 0
#endif

#if defined(__GTA_COMMON_FXH)
	#include "../../Util/macros.fxh"
	#define Vec4V   float4
	#define Vec3V   float3
	#define Vec2V   float2
	#define ScalarV float
#endif // defined(__GTA_COMMON_FXH)

// ================================================================================================

#define CSM_DEFAULT_MODIFIED_FAR_DISTANCE_SCALE (1.45f)
#define CSM_USE_IRREGULAR_FADE                  (1)
#define CSM_FORCE_MODIFICATIONS                 (1)

// ================================================================================================

#if CASCADE_SHADOWS_CLOUD_SHADOWS
	#define CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(x) x
#else
	#define CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(x)
#endif

#define FOREACH_ARG1_DEF_CSMSampleType(arg0, DEF) \
	DEF(arg0, CSM_ST_POINT               ) \
	DEF(arg0, CSM_ST_LINEAR              ) \
	DEF(arg0, CSM_ST_TWOTAP              ) \
	DEF(arg0, CSM_ST_BOX3x3              ) \
	DEF(arg0, CSM_ST_BOX4x4              ) \
	DEF(arg0, CSM_ST_DITHER2_LINEAR      ) \
	DEF(arg0, CSM_ST_CUBIC               ) \
	DEF(arg0, CSM_ST_DITHER4             ) \
	DEF(arg0, CSM_ST_DITHER16            ) \
	DEF(arg0, CSM_ST_SOFT16              ) \
	DEF(arg0, CSM_ST_DITHER16_RPDB       ) \
	DEF(arg0, CSM_ST_POISSON16_RPDB_GNORM ) \
	DEF(arg0, CSM_ST_HIGHRES_BOX4x4      ) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_SIMPLE              )) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_LINEAR              )) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_TWOTAP              )) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_BOX3x3              )) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_BOX4x4              )) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_DITHER2_LINEAR      )) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_SOFT16		       )) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_DITHER16_RPDB       )) \
	CASCADE_SHADOWS_CLOUD_SHADOWS_ONLY(DEF(arg0, CSM_ST_CLOUDS_POISSON16_RPDB_GNORM )) \
	DEF_TERMINATOR
#if defined(__GTA_COMMON_FXH)
	#define CSM_ST_POINT                       0
	#define CSM_ST_LINEAR                      1
	#define CSM_ST_TWOTAP                      2
	#define CSM_ST_BOX3x3                      3
	#define CSM_ST_BOX4x4                      4	
	#define CSM_ST_DITHER2_LINEAR              5
	#define CSM_ST_CUBIC                       6
	#define CSM_ST_DITHER4                     7
	#define CSM_ST_DITHER16                    8
	#define CSM_ST_SOFT16                      9
	#define CSM_ST_DITHER16_RPDB              10
	#define CSM_ST_POISSON16_RPDB_GNORM        11
	#define CSM_ST_HIGHRES_BOX4x4             12
#if CASCADE_SHADOWS_CLOUD_SHADOWS
	#define CSM_ST_CLOUDS_SIMPLE              13
	#define CSM_ST_CLOUDS_LINEAR              14
	#define CSM_ST_CLOUDS_TWOTAP              15
	#define CSM_ST_CLOUDS_BOX3x3              16
	#define CSM_ST_CLOUDS_BOX4x4              17
	#define CSM_ST_CLOUDS_DITHER2_LINEAR      18
	#define CSM_ST_CLOUDS_SOFT16              19
	#define CSM_ST_CLOUDS_DITHER16_RPDB       20
	#define CSM_ST_CLOUDS_POISSON16_RPDB_GNORM 21
	#define CSM_ST_COUNT                      21
#else
	#define CSM_ST_COUNT                      12
#endif
#else // not defined(__GTA_COMMON_FXH)
	enum eCSMSampleType
	{
		#define ARG1_DEF_CSMSampleType(arg0, type) type,
		FOREACH_ARG1_DEF_CSMSampleType(arg0, ARG1_DEF_CSMSampleType)
		#undef  ARG1_DEF_CSMSampleType
		CSM_ST_COUNT,
		CSM_ST_STANDARD_COUNT = CSM_ST_DITHER16 + 1, // standard sample types available to cutscenes etc.
		CSM_ST_INVALID = -1
	};
#endif // not defined(__GTA_COMMON_FXH)

#define CSM_ST_CLOUDS_FIRST CSM_ST_CLOUDS_SIMPLE
#define CSM_ST_CLOUDS_LAST  CSM_ST_CLOUDS_POISSON16_RPDB_GNORM

#define CSM_ST_DEFAULT CSM_ST_POISSON16_RPDB_GNORM

// ================================================================================================

/*** !! If you change the depth bias or slope values you'll probably also need to thange the particle shadow bias values at the bottom of this file!! ***/

#define CSM_DEFAULT_SPHERE_THRESHOLD 1.0f
#define CSM_DEFAULT_SPHERE_THRESHOLD_TWEAKS Vec4V(1.0f, 1.0f, 1.0f, 1.0f)
#define CSM_DEFAULT_SPHERE_THRESHOLD_BIAS_V (CSM_DEFAULT_SPHERE_THRESHOLD_TWEAKS*ScalarV(CSM_DEFAULT_SPHERE_THRESHOLD))

#define CSM_DEFAULT_DEPTH_BIAS 0.02f

#if RSG_ORBIS
#define CSM_DEPTH_BIAS_SCALE 1000.0f
#else
#define CSM_DEPTH_BIAS_SCALE 0.0001f
#endif //RSG_ORBIS

#define CSM_DEFAULT_DEPTH_BIAS_TWEAKS Vec4V(1.0f, 1.0f, 1.0f, 1.0f)
#define CSM_DEFAULT_DEPTH_BIAS_V (CSM_DEFAULT_DEPTH_BIAS_TWEAKS*ScalarV(CSM_DEFAULT_DEPTH_BIAS*CSM_DEPTH_BIAS_SCALE))

#if RSG_ORBIS
#define CSM_SLOPE_BIAS_SCALE 26.4f
#else
#define CSM_SLOPE_BIAS_SCALE 1.0f
#endif

#define CSM_DEFAULT_SLOPE_BIAS       (3.30f*CSM_SLOPE_BIAS_SCALE)
#define CSM_DEFAULT_SLOPE_BIAS_RPDB  (0.82f*CSM_SLOPE_BIAS_SCALE)

#define CSM_DEFAULT_SLOPE_BIAS_TWEAKS Vec4V(1.0f, 1.0f, 1.0f, 1.0f)

#define CSM_DEFAULT_SLOPE_BIAS_V      (CSM_DEFAULT_SLOPE_BIAS_TWEAKS*ScalarV(CSM_DEFAULT_SLOPE_BIAS))
#define CSM_DEFAULT_SLOPE_BIAS_RPDB_V (CSM_DEFAULT_SLOPE_BIAS_TWEAKS*ScalarV(CSM_DEFAULT_SLOPE_BIAS_RPDB))

#define CSM_DEFAULT_DEPTH_BIAS_CLAMP 0.0015f
#define CSM_DEFAULT_DEPTH_BIAS_CLAMP_TWEAKS Vec4V(1.0f, 1.0f, 1.0f, 1.0f)
#define CSM_DEFAULT_DEPTH_BIAS_CLAMP_V (CSM_DEFAULT_DEPTH_BIAS_CLAMP_TWEAKS*ScalarV(CSM_DEFAULT_DEPTH_BIAS_CLAMP))

#define CSM_DEFAULT_LINEAR_OFFSET 0.0f//0.08f
#define CSM_DEFAULT_LINEAR_OFFSET_TWEAKS Vec4V(1.0f, 1.0f, 1.0f, 1.0f)//Vec4V(1.0f, 2.0f, 4.0f, 8.0f)
#define CSM_DEFAULT_LINEAR_OFFSET_V (CSM_DEFAULT_LINEAR_OFFSET_TWEAKS*ScalarV(CSM_DEFAULT_LINEAR_OFFSET/100.0f))

#define CSM_DEFAULT_NORMAL_OFFSET 0.75f
#define CSM_DEFAULT_NORMAL_OFFSET_TWEAKS Vec4V(1.0f, 1.0f, 1.0f, 1.0f)
#define CSM_DEFAULT_NORMAL_OFFSET_V (CSM_DEFAULT_NORMAL_OFFSET_TWEAKS*ScalarV(CSM_DEFAULT_NORMAL_OFFSET/100.0f))

#define CSM_DEFAULT_DITHER_SCALE  1.0f
#define CSM_DEFAULT_DITHER_RADIUS 0.35f
#define CSM_DEFAULT_DITHER_RADIUS_TWEAKS Vec4V(4.0f, 3.0f, 2.0f, 1.0f)//Vec4V(4.0f, 1.5f, 1.25f, 1.0f)//Vec4V(4.0f, 3.0f, 2.0f, 1.0f)
#define CSM_DEFAULT_DITHER_RADIUS_V (CSM_DEFAULT_DITHER_RADIUS_TWEAKS*ScalarV(CSM_DEFAULT_DITHER_RADIUS))

#define CSM_DEFAULT_FADE_START 0.5f

#if RSG_ORBIS
#define CSM_PARTICLE_SHADOWS_DEPTH_SLOPE_BIAS	0.85f
#else
#define CSM_PARTICLE_SHADOWS_DEPTH_SLOPE_BIAS	0.6f
#endif

#define CSM_PARTICLE_SHADOWS_DEPTH_BIAS_RANGE			6.0f
#define CSM_PARTICLE_SHADOWS_DEPTH_BIAS_RANGE_FALLOFF	2.0f

#endif // _CASCADESHADOWS_COMMON_FXH_
