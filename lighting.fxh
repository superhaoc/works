//
//	gta_lighting - all shared lighting stuff for gta_xxx shaders;
//
//	02/06/2006	- AdamCR:	- initial;
//	01/03/2006	- Andrzej:	- SPECULAR_HAIR stuff added;
//	10/03/2006	- Andrzej:	- USE_PARALLAX added;
//	13/02/2007	- Andrzej:	- USE_REFLECT_MAP_MODULATE_ALPHA added;
//
//
//
//
#ifndef __GTA_LIGHTING_FXH__
#define __GTA_LIGHTING_FXH__

#ifndef SELF_SHADOW
	#if defined(NO_SELF_SHADOW) || __MAX
		#define SELF_SHADOW 0
	#else
		#define SELF_SHADOW 1
	#endif
#endif

#ifndef SPEC_MAP_INTFALLOFF_PACK
	#define SPEC_MAP_INTFALLOFF_PACK			(0)
#endif
#ifndef SPEC_MAP_INTFALLOFFFRESNEL_PACK
	#define SPEC_MAP_INTFALLOFFFRESNEL_PACK		(0)
#endif

#include "../util/macros.fxh"
#include "lighting_common.fxh"
#include "../../../rage/base/src/grcore/AA_shared.h"
#include "../../renderer/Lights/LightCommon.h"

// =============================================================================================== //
// Surface Property helpers
// =============================================================================================== //

struct SurfaceProperties
{
#ifdef DECAL_USE_NORMAL_MAP_ALPHA
	float4	surface_worldNormal;
#else
	float3	surface_worldNormal;
#endif
#if NORMAL_MAP2
	float3	surface_worldNormal2;
#endif
	float4	surface_baseColor;
#if PALETTE_TINT
	float4 surface_baseColorTint;
#endif
	float4	surface_diffuseColor;
#if DIFFUSE2 || DIFFUSE3 || OVERLAY_DIFFUSE2
	float4	surface_overlayColor;
#endif	// DIFFUSE2 || DIFFUSE3 || OVERLAY_DIFFUSE2
#if SPECULAR
	float surface_specularSkin;
	float surface_specularIntensity;
	float surface_specularExponent;
	#if DIFFUSE2
		#if DIFFUSE2_SPEC_MASK
			float	surface_diffuse2SpecClamp;
		#else
			float	surface_diffuse2SpecMod;
		#endif // DIFFUSE2_SPEC_MASK
	#endif	// DIFFUSE2
	#if SPEC_MAP
		float4 surface_specMapSample;
	#endif
	#ifdef WET_PED_EFFECT
		float surface_isSkin;
	#endif
#endif	// SPECULAR

#if REFLECT
	float3	surface_reflectionColor;
#endif // REFLECT
	float	surface_fresnel;
//	float	surface_globalAlpha;
	float	surface_emissiveIntensity;
#if SELF_SHADOW || __MAX
	float  surface_selfShadow;
#endif
#if USE_SLOPE
	float slope;
#endif
};

// ----------------------------------------------------------------------------------------------- //
// NOTE: Please keep this structure and comments in sync with GBufferRT in DeferredConfig.h!

// struct DeferredGBuffer
// {
// 	half4	col0	: SV_Target0;	// col0.rgb = Albedo (diffuse)
// 									// col0.a   = SSA
// 	half4	col1	: SV_Target1;	// col1.rgb = Normal (xyz)
// 									// col1.a   = Twiddle
// 	half4	col2	: SV_Target2;	// col2.r   = Specular Diffuse Mix
// 									// col2.g   = Specular Exponent 
// 									// col2.b   = Fresnel
// 									// col2.a   = Shadow
// 	half4	col3	: SV_Target3;	// col3.r   = Natural Ambient Scale
// 									// col3.g   = Artificial Ambient Scale
// 									// col3.b   = Emissive
// 									// col3.a   = Ped Skin (top bit), Reflection Intensity (bottom 7 bits), for trees this is Translucency Control
// #if GBUFFER_COVERAGE
// 	uint	coverage;				// Manual multisample coverage output
// #endif // GBUFFER_COVERAGE
// };

#if GBUFFER_COVERAGE

struct DeferredGBuffer
{
	half4	col0;
	half4	col1;
	half4	col2;
	half4	col3;
	uint	coverage;
};

struct DeferredGBufferC
{
	half4	col0	: SV_Target0;
	half4	col1	: SV_Target1;
	half4	col2	: SV_Target2;
	half4	col3	: SV_Target3;
	uint	coverage: SV_Coverage;
};
struct DeferredGBufferNC
{
	half4	col0	: SV_Target0;
	half4	col1	: SV_Target1;
	half4	col2	: SV_Target2;
	half4	col3	: SV_Target3;
};

DeferredGBufferNC PackDeferredGBufferNC( DeferredGBuffer Src )
{
	DeferredGBufferNC Dest;

	Dest.col0 = Src.col0;
	Dest.col1 = Src.col1;
	Dest.col2 = Src.col2;
	Dest.col3 = Src.col3;

	return Dest;
}

DeferredGBufferC PackDeferredGBufferC( DeferredGBuffer Src )
{
	DeferredGBufferC Dest;

	Dest.col0		= Src.col0;
	Dest.col1		= Src.col1;
	Dest.col2		= Src.col2;
	Dest.col3		= Src.col3;
	Dest.coverage	= Src.coverage;

	return Dest;
}

#else

struct DeferredGBuffer
{
	half4	col0	: SV_Target0;
	half4	col1	: SV_Target1;
	half4	col2	: SV_Target2;
	half4	col3	: SV_Target3;
};

#define DeferredGBufferC			DeferredGBuffer
#define DeferredGBufferNC			DeferredGBuffer
#define PackDeferredGBufferC( x )	x
#define PackDeferredGBufferNC( x )	x
#endif // GBUFFER_COVERAGE

// ----------------------------------------------------------------------------------------------- //
#if defined(DEFERRED_UNPACK_LIGHT)
// ----------------------------------------------------------------------------------------------- //

BEGIN_RAGE_CONSTANT_BUFFER(lighting_locals,b13)

	float4 deferredLightParams[LIGHT_PARAM_COUNT];

	#define deferredLightPosition				(deferredLightParams[0].xyz)
	
	#define deferredLightDirection				(deferredLightParams[1].xyz)

	#define deferredLightTangent				(deferredLightParams[2].xyz)

	#define deferredLightColourAndIntensity		(deferredLightParams[3].xyzw)

	#define deferredLightType					(deferredLightParams[4].x)	// Type of light
	#define deferredLightRadius					(deferredLightParams[4].y)	// falloff
	#define deferredLightInvSqrRadius			(deferredLightParams[4].z)	// 1 / (r^2) where r = falloff radius of light
	#define deferredLightExtraRadius			(deferredLightParams[4].w)  // how far to extend the light mesh volume so the entire light fits inside it

	// Cone lights
	#define deferredLightConeCosOuterAngle		(deferredLightParams[5].x)
	#define deferredLightConeSinOuterAngle		(deferredLightParams[5].y)
	#define deferredLightConeOffset				(deferredLightParams[5].z)
	#define deferredLightConeScale				(deferredLightParams[5].w)

	// AO Volumes
	#define deferredVolumeSizeX					(deferredLightParams[5].x)
	#define deferredVolumeSizeY					(deferredLightParams[5].y)
	#define deferredVolumeSizeZ					(deferredLightParams[5].z)
	#define deferredVolumeBaseIntensity			(deferredLightParams[5].w)
	
	// Capsule lights
	#define deferredLightCapsuleExtent			(deferredLightParams[5].x)
	#define deferredLightShadowBleedInvScalar	(deferredLightParams[5].z)	// Shadow bleed scalar inv
	#define deferredLightShadowBleedScalar		(deferredLightParams[5].w)	// Shadow bleed scalar

	#define deferredLightPlane					(deferredLightParams[6])	// Plane (with distance in w)

	#define deferredLightFalloffExponent		(deferredLightParams[7].x)	// Falloff exponent
	#define deferredLightFalloffInvScale		(deferredLightParams[7].y)	// Falloff scale
	#define deferredLightWaterHeight			(deferredLightParams[7].z)	// Water height
	#define deferredLightWaterTime				(deferredLightParams[7].w)	// Caustic animation time

	#define deferredLightShadowFade				(deferredLightParams[8].y)	// Shadow fade
	#define deferredLightSpecularFade			(deferredLightParams[8].z)	// Specular light fade	
	
	#define deferredLightVehicleHeadTwinPos1	(deferredLightParams[9].xyz) // Distance between center light source and actual headlight

	#define deferredLightVehicleHeadTwinPos2	(deferredLightParams[10].xyz) // Distance between center light source and actual headlight
	
	#define deferredLightVehicleHeadTwinDir1	(deferredLightParams[12].xyz) // Direction of left light
	#define deferredLightVehicleHeadTwinDir2	(deferredLightParams[13].xyz) // Direction of right light

	#define deferredLightTextureFlipped			(deferredLightParams[11].x) // Should this headligh texture be flipped
	#define deferredLightTextureFade			(deferredLightParams[11].y) // Fade value for texture

	float4	deferredLightVolumeParams[LIGHTVOLUME_PARAM_COUNT];					// 
	#define	deferredLightVolumeParams_intensity						deferredLightVolumeParams[0].x // TODO -- can we combine this with deferredLightColourAndIntensity above?
	#define deferredLightVolumeParams_NearPlaneFadeRange			deferredLightVolumeParams[0].y
	// deferredLightVolumeParams[0].zw is free
	#define	deferredLightVolumeParams_outerColour					deferredLightVolumeParams[1].xyz
	#define deferredLightVolumeParams_outerExponent					deferredLightVolumeParams[1].w

	float4	deferredLightScreenSize;											// xywh
	float4	deferredProjectionParams;											// sx, sy, dscale, doffset 
	float3	deferredPerspectiveShearParams0;									// combination of perspective shear, deferred projection params,and inverse view matrix. 
	float3	deferredPerspectiveShearParams1;									// set up for quick combination with the screen position to get eye vectors. 
	float3	deferredPerspectiveShearParams2;									

EndConstantBufferDX10(lighting_locals)

	// ----------------------------------------------------------------------------------------------- //
	#if !defined(DEFERRED_NO_LIGHT_SAMPLERS) //don't setup light samplers (use custom ones)
	// ----------------------------------------------------------------------------------------------- //

		// texture used by lights and modifiers - all bi-linear filtered
		BeginSampler(	sampler, deferredLightTexture, gDeferredLightSampler, deferredLightTexture)
		ContinueSampler(sampler, deferredLightTexture, gDeferredLightSampler, deferredLightTexture)
			AddressU  = CLAMP;
			AddressV  = CLAMP;
			AddressW  = CLAMP; 
			MINFILTER = LINEAR;
			MAGFILTER = LINEAR;
			MIPFILTER = LINEAR;
		EndSampler;

		BeginSampler(	sampler, deferredLightTexture1, gDeferredLightSampler1, deferredLightTexture1)
		ContinueSampler(sampler, deferredLightTexture1, gDeferredLightSampler1, deferredLightTexture1)
			AddressU  = WRAP;
			AddressV  = WRAP;
			AddressW  = WRAP; 
			MINFILTER = LINEAR;
			MAGFILTER = LINEAR;
			MIPFILTER = LINEAR;
		EndSampler;

		BeginSampler(	sampler, deferredLightTexture2, gDeferredLightSampler2, deferredLightTexture2)
		ContinueSampler(sampler, deferredLightTexture2, gDeferredLightSampler2, deferredLightTexture2)
			AddressU  = CLAMP;
			AddressV  = CLAMP;
			AddressW  = CLAMP; 
			MINFILTER = LINEAR;
			MAGFILTER = LINEAR;
			MIPFILTER = LINEAR;
		EndSampler;

	// ----------------------------------------------------------------------------------------------- //
	#endif // !defined(DEFERRED_NO_LIGHT_SAMPLERS)
	// ----------------------------------------------------------------------------------------------- //


/******************************************************************************************************************
Following GBuffer Samplers are set to global because there are many light shaders that use them.
If they are local, there is a good chance that they get alloted different sampler slots in each of
the shaders. By declaring them global, we assign specific slots to these samplers, and so it will 
always be in the same slot for all shaders that use these samplers. Now we can set them once before
we start rendering the lights, instead of resetting them for each light source. We save around 0.15ms 
on the 360 with this change. Following is how the slots are assigned:

GBuffer 0			= s7
GBuffer 1			= s8
GBuffer 2			= s9
GBuffer 3			= s10
GBuffer Stencil		= s11
GBuffer Depth		= s12

They have the word "Global" appended to their names because this will make sure there is no conflict with other
shaders that use the same name for a local sampler. 
********************************************************************************************************************/

	// MSAA: TODO: Need to devise a devious macro to auto-create multiple definitions of this for each multisample type.

	BeginDX10SamplerShared(	sampler, TEXTURE2D_TYPE<float4>, gbufferTexture0Global, GBufferTextureSampler0Global, gbufferTexture0Global, s7)
	ContinueSharedSampler(sampler, gbufferTexture0Global, GBufferTextureSampler0Global, gbufferTexture0Global, s7)
		AddressU  = CLAMP;        
		AddressV  = CLAMP;
		MINFILTER = POINT;
		MAGFILTER = POINT;
		MIPFILTER = POINT;
	EndSharedSampler;

	BeginDX10SamplerShared(	sampler, TEXTURE2D_TYPE<float4>, gbufferTexture1Global, GBufferTextureSampler1Global, gbufferTexture1Global, s8)
	ContinueSharedSampler(sampler, gbufferTexture1Global, GBufferTextureSampler1Global, gbufferTexture1Global, s8)
		AddressU  = CLAMP;        
		AddressV  = CLAMP;
		MINFILTER = POINT;
		MAGFILTER = POINT;
		MIPFILTER = POINT;
	EndSharedSampler;

	BeginDX10SamplerShared(	sampler, TEXTURE2D_TYPE<float4>, gbufferTexture2Global, GBufferTextureSampler2Global, gbufferTexture2Global, s9)
	ContinueSharedSampler(sampler, gbufferTexture2Global, GBufferTextureSampler2Global, gbufferTexture2Global, s9)
		AddressU  = CLAMP;        
		AddressV  = CLAMP;
		MINFILTER = POINT;
		MAGFILTER = POINT;
		MIPFILTER = POINT;
	EndSharedSampler;

	BeginDX10SamplerShared(	sampler, TEXTURE2D_TYPE<float4>, gbufferTexture3Global, GBufferTextureSampler3Global, gbufferTexture3Global, s10)
	ContinueSharedSampler(sampler, gbufferTexture3Global, GBufferTextureSampler3Global, gbufferTexture3Global, s10)
		AddressU  = CLAMP;        
		AddressV  = CLAMP;
		MINFILTER = POINT;
		MAGFILTER = POINT;
		MIPFILTER = POINT;
	EndSharedSampler;

	BeginDX10SamplerShared(sampler, TEXTURE_STENCIL_TYPE, gbufferStencilTextureGlobal, GBufferStencilTextureSamplerGlobal, gbufferStencilTextureGlobal, s11)
	ContinueSharedSampler(sampler, gbufferStencilTextureGlobal, GBufferStencilTextureSamplerGlobal, gbufferStencilTextureGlobal, s11)
		AddressU  = CLAMP;        
		AddressV  = CLAMP;
		MINFILTER = POINT;
		MAGFILTER = POINT;
		MIPFILTER = POINT;
	EndSharedSampler;

	BeginDX10SamplerShared(	sampler, TEXTURE_DEPTH_TYPE, gbufferTextureDepthGlobal, GBufferTextureSamplerDepthGlobal, gbufferTextureDepthGlobal, s12)
	ContinueSharedSampler(sampler, gbufferTextureDepthGlobal, GBufferTextureSamplerDepthGlobal, gbufferTextureDepthGlobal, s12)
		AddressU  = CLAMP;        
		AddressV  = CLAMP;
		MINFILTER = POINT;
		MAGFILTER = POINT;
		MIPFILTER = POINT;
	EndSharedSampler;

#if MULTISAMPLE_TECHNIQUES && ENABLE_EQAA
	shared Texture2D<uint>	gbufferFragmentMask0Global	REGISTER(t20);
# if EQAA_DECODE_GBUFFERS
	shared Texture2D<uint>	gbufferFragmentMask1Global	REGISTER(t21);
	shared Texture2D<uint>	gbufferFragmentMask2Global	REGISTER(t22);
	shared Texture2D<uint>	gbufferFragmentMask3Global	REGISTER(t23);
# endif // EQAA_DECODE_GBUFFERS
#endif // MULTISAMPLE_TECHNIQUES && ENABLE_EQAA

// ----------------------------------------------------------------------------------------------- //

lightProperties PopulateLightPropertiesDeferred()
{
	lightProperties OUT;

	OUT.position = deferredLightPosition;
	OUT.direction = deferredLightDirection;
	OUT.tangent = deferredLightTangent;
	OUT.colour = deferredLightColourAndIntensity.rgb;
	OUT.intensity = deferredLightColourAndIntensity.a;
	OUT.radius = deferredLightRadius;
	OUT.invSqrRadius = deferredLightInvSqrRadius;
	OUT.extraRadius = deferredLightExtraRadius;
	OUT.cullingPlane = deferredLightPlane;
	OUT.falloffExponent = deferredLightFalloffExponent;

	// Fades
	OUT.shadowFade = deferredLightShadowFade;
	OUT.specularFade = deferredLightSpecularFade;
	OUT.textureFade = deferredLightTextureFade;

	// Vehicle
	OUT.vehicleHeadTwinPos1 = deferredLightVehicleHeadTwinPos1;
	OUT.vehicleHeadTwinPos2 = deferredLightVehicleHeadTwinPos2;
	OUT.vehicleHeadTwinDir1 = deferredLightVehicleHeadTwinDir1;
	OUT.vehicleHeadTwinDir2 = deferredLightVehicleHeadTwinDir2;

	// Textured
	OUT.textureFlipped = deferredLightTextureFlipped;

	// Spot
	OUT.spotCosOuterAngle = deferredLightConeCosOuterAngle;
	OUT.spotSinOuterAngle = deferredLightConeSinOuterAngle;
	OUT.spotOffset = deferredLightConeOffset;
	OUT.spotScale  = deferredLightConeScale;

	// Capsule
	OUT.capsuleExtent = deferredLightCapsuleExtent;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //
#endif //DEFERRED_UNPACK_LIGHT
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
#if PARALLAX
// ----------------------------------------------------------------------------------------------- //

float4 CalculateParallax(
	float3 IN_tanEyePos, 
	float4 bumpMapPixel, 
	float2 IN_diffuseTexCoord, 
	float2 IN_bumpTexCoord, 
	sampler2D IN_bumpSampler, 
	out float2 OUT_diffuseTexCoord)
{
	float3 tanEyePos		= normalize(IN_tanEyePos);
	float4 outBumpMapPixel	= bumpMapPixel;

	#if PARALLAX_STEEP

	// steep parallax:
	#define NUM_STEPS		(8)				//(10)

			float	_step	= 1.0f / float(NUM_STEPS);	
			float2	_dt		= (-tanEyePos.xy) * parallaxScaleBias / (float(NUM_STEPS)/* * tanEyePos.z*/);
			float	_height	= 1.0f;
			#if PARALLAX_REVERTED
				_height	= -1.0f;
			#endif
			
			float2 _t		= IN_diffuseTexCoord.xy;	//bumpTexCoord.xy;
			float4 _nb		= bumpMapPixel;
			#if PARALLAX_REVERTED
				_nb.a *= -1.0f;
//				_nb.a = _nb.a - 1.0f;
			#endif
			
//			while(_nb.a < _height)
			for(int i=0; i<NUM_STEPS; i++)
			{
				float4 _nb_sample = tex2D_NormalHeightMap(IN_bumpSampler, _t + _dt);
			#if PARALLAX_REVERTED
				if(_nb.a > _height)
			#else
				if(_nb.a < _height)
			#endif
				{
				#if PARALLAX_REVERTED
					_height += _step;
				#else
					_height -= _step;
				#endif
					_t += _dt;
					_nb = _nb_sample;
					

					#if PARALLAX_REVERTED
						//_nb.a = 1.0f - _nb.a;			// invert height map
						_nb.a *= -1.0f;				// make parallax reverted
						//_nb.a = _nb.a - 1.0f;			// invert heightmap + make parallax reverted
					#endif
				}
			}

			outBumpMapPixel			= _nb;
			OUT_diffuseTexCoord.xy	= _t;

	#else // PARALLAX_STEEP...

			// standard parallax:
			float2 height		= float2(bumpMapPixel.a, bumpMapPixel.a);
			#if PARALLAX_REVERTED
				height.xy *= -1.0f;
			#endif
			// scale and bias:
			height *= parallaxScaleBias;			// 0.04f;
			height += -(parallaxScaleBias*0.5f);	// -0.02f;
			height.xy *= tanEyePos.xy;
			OUT_diffuseTexCoord.xy = IN_diffuseTexCoord.xy + height.xy;	
			
			#if PARALLAX_CLAMP
				// projtex: force clamping:
				OUT_diffuseTexCoord.xy = saturate(OUT_diffuseTexCoord.xy);
			#endif

		#if PARALLAX_BUMPSHIFT
			// deform normal mapping coords:
			IN_bumpTexCoord.xy += height.xy;
			// projtex: force clamping:
			#if PARALLAX_CLAMP
				IN_bumpTexCoord.xy = saturate(IN_bumpTexCoord.xy);
			#endif
			outBumpMapPixel = tex2D_NormalHeightMap(IN_bumpSampler, IN_bumpTexCoord.xy);
		#endif //PARALLAX_BUMPSHIFT...
		#if PARALLAX_REVERTED
			//bumpMapPixel.xyz *= -1.0f;
		#endif
		
	#endif // PARALLAX_STEEP...

	return(outBumpMapPixel);
}

// ----------------------------------------------------------------------------------------------- //
#endif //PARALLAX
// ----------------------------------------------------------------------------------------------- //

#if SSTAA
// We need access to the MSAA offsets here. I've put in the offsets used by MSAA.
// These are different between MSAA and EQAA - and then set up differently between
// Durango and Orbis. We could use texture2DMS.GetSamplePosition() but this needs
// a multisampled texture to be set and I don't want to force a bind in such shaders, 
// so for now, just use the MSAA sample positions (the result of which looks good to me anyway).
#if RSG_PC
IMMEDIATECONSTANT uint aaIndexOffsets[3] =
{
	0, 2, 6
};

IMMEDIATECONSTANT float2 aaOffsets[14] =
{
	// 2x MSAA offsets
	float2( 0.25, 0.25 ), float2( -0.25, -0.25 ),

	// 4x MSAA offsets
 	float2( -0.125, -0.375),	float2(0.375, -0.125),
 	float2( -0.375,  0.125),	float2(0.125, 0.375),

	// 8x MSAA offsets
	float2( 0.0625),	float2( -0.1875 ),
	float2( -0.0625),	float2( 0.1875 ),
	float2( 0.3125),	float2( 0.0625 ),
	float2( -0.1875),	float2( -0.3125 ),
	float2( -0.3125),	float2( 0.3125 ),
	float2( -0.4375),	float2( -0.0625 ),
	float2( 0.1875),	float2( 0.4375 ),
	float2( 0.4375),	float2( -0.4375 )
};

#elif RSG_DURANGO
IMMEDIATECONSTANT float2 aaOffsets[4] =
{
	// (Current) Durango EQAA offsets
//  	float2(-0.375,-0.375),	float2(0.375,0.375),
//  	float2(-0.125,0.125),	float2(0.125,-0.125)
	// 'Standard' MSAA 4x offsets. Provide a better coverage IMO.
 	float2( -0.125, -0.375),	float2(0.375, -0.125),
 	float2( -0.375,  0.125),	float2(0.125, 0.375),

};
#elif RSG_ORBIS
IMMEDIATECONSTANT float2 aaOffsets[4] =
{
	// Orbis EQAA offsets
// 	float2(0.125,0.125),	float2(-0.125,-0.125),
// 	float2(0.375,0.375),	float2(-0.375,-0.375)
	// 'Standard' MSAA 4x offsets. Provide a better coverage IMO.
 	float2( -0.125, -0.375),	float2(0.375, -0.125),
 	float2( -0.375,  0.125),	float2(0.125, 0.375),
};
#endif // RSG_ORBIS
#endif // SSTAA

float GetSurfaceAlpha_( float2 IN_diffuseTexCoord, sampler2D IN_diffuseSampler, float alpha )
{
	return tex2D(IN_diffuseSampler, IN_diffuseTexCoord).w * alpha;
}

float GetSurfaceAlphaWithCoverage( float2 IN_diffuseTexCoord, sampler2D IN_diffuseSampler, float aaAlpha, float aaAlphaRef, inout uint Coverage )
{
	float surfaceAlpha = 1;
#if SSTAA
	if (ENABLE_TRANSPARENCYAA)
	{
		float2 texCoord_ddx = ddx(IN_diffuseTexCoord);
		float2 texCoord_ddy = ddy(IN_diffuseTexCoord);

		Coverage = 0;

		uint numSamples;
	#if RSG_PC
		// Or any platform that uses MSAA 2x, 4x, 8x etc.
		uint offset = aaIndexOffsets[firstbitlow(gMSAANumSamples)-1];
		numSamples = gMSAANumSamples;
	#else
		// Hard-code 4 to allow the loop to unroll.
		numSamples = 4;
		uint offset = 0;
	#endif

		[unroll]
		for (uint i=0; i<numSamples; ++i)
		{
			float2 texelOffset = aaOffsets[offset+i].x * texCoord_ddx;
			texelOffset += aaOffsets[offset+i].y * texCoord_ddy;
			// Note that we should probably use point sampling here for a true super-sampling 
			// representation of the alpha cutout value.
//			float subSample = DiffuseTex.Sample(DiffuseSampler, TexCoord + texelOffset).a;
			float subSample = GetSurfaceAlpha_(IN_diffuseTexCoord + texelOffset, IN_diffuseSampler, aaAlpha);

			if (subSample > aaAlphaRef)
			{
				Coverage |= (1 << i);
			}
		}
	}
	else
#endif // SSTAA
	{
		surfaceAlpha = GetSurfaceAlpha_(IN_diffuseTexCoord, IN_diffuseSampler, globalAlpha);
	}

	return surfaceAlpha;
}

float GetSurfaceAlpha( float2 IN_diffuseTexCoord, sampler2D IN_diffuseSampler)
{
	uint Coverage = 0xffffffff;
	return GetSurfaceAlphaWithCoverage(IN_diffuseTexCoord, IN_diffuseSampler, 1, 0, Coverage);
}

// ----------------------------------------------------------------------------------------------- //
#if !defined(DEFERRED_UNPACK_LIGHT)
// ----------------------------------------------------------------------------------------------- //

float4 calculateDiffuseColor(float4 IN_diffuseColor)
{
	float4 OUT = float4(0.0, 0.0, 0.0, 0.0);

	float4 diffuseColor;
	diffuseColor = IN_diffuseColor;

#if EMISSIVE_ADDITIVE
	diffuseColor = float4(diffuseColor.rgb * diffuseColor.a, diffuseColor.a);
	#if (EMISSIVE_NIGHTONLY)
		diffuseColor.rgba *= gDayNightEffects;
	#endif
#endif

#if defined(DECAL_DIRT)
	OUT = float4( 1.0f, 1.0f, 1.0f, dot(diffuseColor.rgb, dirtDecalMask.rgb));
#elif defined(DISPLACEMENT_SHADER)
	OUT.rgba = float4(1,1,1,1);
#else
	#if defined(DECAL_SPEC_ONLY) 
		OUT = 0; // don't do a texture read when we don't need the colour
	#else
		OUT = diffuseColor;
	#endif
#endif

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //
#if NORMAL_MAP
// ----------------------------------------------------------------------------------------------- //
float3 CalculatePackedNormal(
	float3 IN_packedNormalHeight,
	#if PARALLAX
		float3 parallaxPackedNormalHeight,
	#endif
	#if DIRT_NORMALMAP
		sampler2D IN_dirtBumpSampler,
		float3 dirtTexCoord,
	#endif
	float2 texCoord)
{
	float3 packedNormalHeight;

	#if !PARALLAX
		packedNormalHeight = IN_packedNormalHeight;
	#else
		packedNormalHeight = parallaxPackedNormalHeight;
	#endif

	#if DIRT_NORMALMAP
		// limit dirt bumplevel to 0.5
		packedNormalHeight = lerp(packedNormalHeight, tex2D_NormalMap(IN_dirtBumpSampler, dirtTexCoord.xy).xyz, min(dirtTexCoord.z, 0.5f)); 
	#endif

	return packedNormalHeight;
}
// ----------------------------------------------------------------------------------------------- //
#endif
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
#if WRINKLE_MAP
// ----------------------------------------------------------------------------------------------- //
float3 CalculateWrinkleNormal(
	sampler2D normalSampler, 
	float2 texCoord, 
	float3 worldTangent, 
	float3 worldBinormal, 
	float3 worldNormal)
{
	#if PARALLAX
		#error "WRINKLE_MAP and PARALLAX used together!"
	#endif
	#if DIRT_NORMALMAP
		#error "WRINKLE_MAP and DIRT_NORMALMAP used together!"
	#endif

	return PS_GetWrinkledNormal(
		normalSampler,
		WrinkleSampler_A,
		WrinkleSampler_B,
		WrinkleMaskSampler_0,
		WrinkleMaskSampler_1,
		WrinkleMaskSampler_2,
		WrinkleMaskSampler_3,
		wrinkleMaskStrengths0,
		wrinkleMaskStrengths1,
		wrinkleMaskStrengths2,
		wrinkleMaskStrengths3,
		texCoord,
		bumpiness,
		worldNormal.xyz,
		worldTangent.xyz,
		worldBinormal.xyz
		);
}
// ----------------------------------------------------------------------------------------------- //
#endif
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
#if SPECULAR
// ----------------------------------------------------------------------------------------------- //
void CalculateSpecularContribution(
	inout SurfaceProperties surfaceInfo,
	#if SPEC_MAP
		sampler2D specularSampler,
		float2 specularTexCoords,
	#endif
	float4 baseColor,
	float3 worldNormal)
{
	// Calculate fresnel
	#if FRESNEL
		surfaceInfo.surface_fresnel = specularFresnel;
	#else
		surfaceInfo.surface_fresnel = 0;
	#endif

	// Specular contribution
	surfaceInfo.surface_specularSkin	= 0;
	#if SPEC_MAP
		#if SPECULAR_DIFFUSE
			// See https://mp.rockstargames.com/index.php/Specular_Shading_Enviroment_Palette
			// Step taken by art
			// Translate diffuse map into specular map
			float4 vSpecSamp = tex2D(specularSampler, specularTexCoords.xy);
			float4 specSamp = float4(0,0,0,0); // x = Intensity, y = Falloff/Exponent
			// 1. Flood a layer - Used for finding specular intensity base value - Done in photoshop and put into a constant value exposed in 3DMax
			// 2. Desaturate diffuse - Spec Intensity first
			specSamp.x = dot(vSpecSamp.rgb, SpecDesaturateIntensity.rgb);
			specSamp.y = dot(vSpecSamp.rgb, SpecDesaturateExponent.rgb);
			// 3. Check levels - Art
			// 4. Paste above the base value layer and set the layer blending mode to Overlay - http://en.wikipedia.org/wiki/Blend_modes#Overlay
			// 5. Stamp visible to create a single layer			
			specSamp.x = (specSamp.x < 0.5f) ? (2.0f * specSamp.x * SpecBaseIntensity) : (1.0f - 2.0f * (1 - specSamp.x) * (1 - SpecBaseIntensity));
			specSamp.y = (specSamp.y < 0.5f) ? (2.0f * specSamp.y * SpecBaseExponent ) : (1.0f - 2.0f * (1 - specSamp.y) * (1 - SpecBaseExponent ));

			#ifdef WET_PED_EFFECT
				surfaceInfo.surface_isSkin = 0;
			#endif

			surfaceInfo.surface_specularSkin = 0;
		#else
			float4 specSamp = tex2D(specularSampler, specularTexCoords.xy);
			specSamp.xy *= specSamp.xy; // linearise mix and falloff

			surfaceInfo.surface_specMapSample = specSamp;

			#ifdef WET_PED_EFFECT
				surfaceInfo.surface_isSkin = PedIsSkin(specSamp.xyz);
			#endif

			#ifdef PED_CAN_BE_SKIN
				surfaceInfo.surface_specularSkin	= PedIsSubSurfaceSkin(specSamp.xyz);
			#else
				surfaceInfo.surface_specularSkin	= 0;
			#endif
		#endif // SPECULAR_DIFFUSE

		#if SPEC_MAP_INTFALLOFF_PACK
			surfaceInfo.surface_specularIntensity	= specSamp.x*specularIntensityMult;	
			surfaceInfo.surface_specularExponent	= specSamp.y*specularFalloffMult;
			
		#elif SPEC_MAP_INTFALLOFFFRESNEL_PACK
			#if FRESNEL
				surfaceInfo.surface_fresnel = specularFresnel * (1.0f - specSamp.z);
			#else
				surfaceInfo.surface_fresnel = 0.0f;
			#endif
			surfaceInfo.surface_specularIntensity	= specSamp.x*specularIntensityMult;
			surfaceInfo.surface_specularExponent	= specSamp.y*specularFalloffMult;
		#else
			surfaceInfo.surface_specularIntensity	= dot(specSamp.xyz, specMapIntMask)*specularIntensityMult;
			surfaceInfo.surface_specularExponent	= specSamp.w*specularFalloffMult;
			#ifdef DECAL_SPEC_ONLY
				surfaceInfo.surface_diffuseColor.a	= specSamp.g;
			#endif
		#endif
	#elif INV_DIFFUSE_AS_SPECULAR_MAP
		float specMult = 1.0f - dot(surfaceInfo.surface_diffuseColor.rgb, LumFactors.rgb);
		surfaceInfo.surface_specularExponent	= specMult*specularFalloffMult;
		surfaceInfo.surface_specularIntensity	= specMult*specularIntensityMult;	
	#else	
		surfaceInfo.surface_specularIntensity = specularIntensityMult;
		surfaceInfo.surface_specularExponent = specularFalloffMult;	
	#endif	// SPEC_MAP

	#if DIFFUSE2
		#if DIFFUSE2_SPEC_MASK
			surfaceInfo.surface_diffuse2SpecClamp = diffuse2SpecClamp;
		#else
			surfaceInfo.surface_diffuse2SpecMod = diffuse2SpecMod;
		#endif
	#endif	// DIFFUSE2
}
// ----------------------------------------------------------------------------------------------- //
#endif // SPECULAR
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
#if REFLECT
// ----------------------------------------------------------------------------------------------- //

#if REFLECT_MIRROR
float3 CalculateMirrorReflection(sampler2D samp, float4 screenPos, float3 worldNormal, float2 texcoord)
{
	float2 refUV = gMirrorBounds.xy + gMirrorBounds.zw*(screenPos.xy/screenPos.ww);

#if defined(USE_MIRROR_CRACK_MAP)
	refUV += gMirrorCrackAmount*(tex2D(gMirrorCrackSampler, texcoord).xy*2 - 1)/float2(512.0,256.0);
#endif // defined(USE_MIRROR_CRACK_MAP)

#if defined(USE_MIRROR_DISTORTION)
	refUV += gMirrorDistortionAmount*worldNormal.xy/float2(512.0,256.0);
#endif // defined(USE_MIRROR_DISTORTION)

#if __XENON
	float3 refColour0;
	float3 refColour1;
	float3 refColour2;
	float3 refColour3;
	asm
	{
		tfetch2D refColour0.xyz, refUV, samp, OffsetX = 0.0, OffsetY = 0.0
		tfetch2D refColour1.xyz, refUV, samp, OffsetX = 0.0, OffsetY = 1.0
		tfetch2D refColour2.xyz, refUV, samp, OffsetX = 1.0, OffsetY = 0.0
		tfetch2D refColour3.xyz, refUV, samp, OffsetX = 1.0, OffsetY = 1.0
	};
	float3 refColour = (refColour0 + refColour1 + refColour2 + refColour3)/4.0;
	return UnpackHdr_3h(refColour);
#else
	float3 refColour = tex2D(samp, refUV).xyz;
	return UnpackColor_3h(refColour);
#endif
}
#endif // REFLECT_MIRROR

void CalculateReflection(
	inout SurfaceProperties surfaceInfo,
	REFLECT_SAMPLER environmentSampler,
	#if REFLECT_MIRROR
		float4 screenPos,
		#if defined(USE_MIRROR_CRACK_MAP)
			float2 mirrorTexCoord,
		#endif
	#endif
	#if SPECULAR
		float specularExponent,
	#endif
	float3 surfaceToEyeDir,
	float3 worldNormal)
{
	#if REFLECT_MIRROR
		float3 colorReflect = CalculateMirrorReflection(environmentSampler, screenPos, worldNormal,
			#if defined(USE_MIRROR_CRACK_MAP)
					mirrorTexCoord
			#else
					float2(0,0)
			#endif
		);
	#elif !REFLECT_DYNAMIC
		float3 temp_reflectionVector = normalize(reflect(-surfaceToEyeDir, worldNormal));
		#if REFLECT_SPHERICAL
			// spherical reflection:	
			temp_reflectionVector = (temp_reflectionVector + 1.0) * -0.5;
			float2 reflectUVs = temp_reflectionVector.xz;	// swap y<->z for proper uv mapping
		#else
			// cubemap reflection (swap y<->z for proper D3D's texCUBE coords handling):
			float3 reflectUVs = temp_reflectionVector.xzy;
		#endif	// REFLECT_SPHERICAL
		float3 colorReflect = REFLECT_TEXOP(environmentSampler, reflectUVs) * reflectivePower;
		colorReflect *= gEmissiveScale == 0.0f ? 0.0f : 1.0f;
	#else
		float3 colorReflect = float3(0.0f, 0.0f, 0.0f);
	#endif 
	surfaceInfo.surface_reflectionColor = colorReflect.xyz;
}
// ----------------------------------------------------------------------------------------------- //
#endif //REFLECT...
// ----------------------------------------------------------------------------------------------- //

void CalculateEmissiveContribution(inout SurfaceProperties surfaceInfo)
{
#if EMISSIVE || EMISSIVE_ADDITIVE
	surfaceInfo.surface_emissiveIntensity = emissiveMultiplier * 
											surfaceInfo.surface_diffuseColor.a * 
											gEmissiveScale;

	#if EMISSIVE_NIGHTONLY
		surfaceInfo.surface_emissiveIntensity *= gDayNightEffects;
	#endif
#else
	surfaceInfo.surface_emissiveIntensity = 0.0;
#endif
}

// ----------------------------------------------------------------------------------------------- //
#define MIN_NUM_OF_PXM_STEPS 8
#define MAX_NUM_OF_PXM_STEPS 30

SurfaceProperties GetSurfaceProperties(	float4			IN_baseColor,
#if PALETTE_TINT
										float4			IN_baseColorTint,
#endif
#if DIFFUSE_TEXTURE
										float2			IN_diffuseTexCoord,
										sampler2D		IN_diffuseSampler,
#endif
#if DIFFUSE2 || DIFFUSE3 || OVERLAY_DIFFUSE2
										float2			IN_diffuseTexCoord2,
										sampler2D		IN_diffuseSampler2,
#endif
#if OVERLAY_DIFFUSE2 && OVERLAY_DIFFUSE2_SEPARATE_ALPHA_SOURCE
										float			IN_diffuse2Alpha,
#endif
#if SPEC_MAP
										float2			IN_specularTexCoord,
										sampler2D		IN_specularSampler,
#endif	// SPEC_MAP
#if REFLECT
										float3			IN_worldEyePos,
										REFLECT_SAMPLER	IN_environmentSampler,
	#if REFLECT_MIRROR
										float2			IN_mirrorTexCoord,
										float4			IN_screenPos,
	#endif // REFLECT_MIRROR
#endif // REFLECT 
#if NORMAL_MAP
										float2			IN_bumpTexCoord,
										sampler2D		IN_bumpSampler,
										float3			IN_worldTangent,
										float3			IN_worldBinormal,
	#if PARALLAX || PARALLAX_MAP_V2
		#if PARALLAX
										float3			IN_tanEyePos,
		#endif
		#if PARALLAX_MAP_V2
										float3			IN_worldEyePosPOM,
										sampler2D		IN_heightSampler,
			#if EDGE_WEIGHT
										float2			IN_edgeWeight,
			#endif // EDGE_WEIGHT
		#endif // PARALLAX_MAP_V2
	#endif //  PARALLAX || PARALLAX_MAP_V2
#endif	// NORMAL_MAP
#if NORMAL_MAP2
										float2			IN_bumpTexCoord2,
										sampler2D		IN_bumpSampler2,
										float3			IN_worldTangent2,
										float3			IN_worldBinormal2,
#endif	// NORMAL_MAP2
#if DIRT_NORMALMAP
										float3			IN_dirtBumpUV,		// xy = UV, z = dirtLevel
										sampler2D		IN_dirtBumpSampler,
#endif//DIRT_NORMALMAP...
#if DETAIL_UV
										float2			IN_detailUV,
#endif //DETAIL_UV...
										float3			IN_worldNormal
						)
{
	SurfaceProperties OUT = (SurfaceProperties)0;

	OUT.surface_baseColor		= IN_baseColor;	

#if PALETTE_TINT
	OUT.surface_baseColorTint	= IN_baseColorTint;
#endif

#if DIFFUSE2 || DIFFUSE3 || OVERLAY_DIFFUSE2
	OUT.surface_overlayColor = tex2D(IN_diffuseSampler2, IN_diffuseTexCoord2);	
#if OVERLAY_DIFFUSE2_SEPARATE_ALPHA_SOURCE
	OUT.surface_overlayColor.a = IN_diffuse2Alpha;
#endif // OVERLAY_DIFFUSE2_SEPARATE_ALPHA_SOURCE
#endif	// DIFFUSE2

#if PARALLAX
	float2 outTexCoord;
	float3 parallaxPackedNormalHeight = CalculateParallax(
		IN_tanEyePos, 
		tex2D_NormalHeightMap(IN_bumpSampler, IN_bumpTexCoord.xy), 
		IN_diffuseTexCoord, 
		IN_bumpTexCoord, 
		IN_bumpSampler, 
		outTexCoord).xyz;
	IN_diffuseTexCoord = outTexCoord;
#endif // NORMAL_MAP

#if PARALLAX_MAP_V2 && __SHADERMODEL >= 40
#if EDGE_WEIGHT
	float edgeWeight = 1.0f - clamp(IN_edgeWeight.x, 0.0f, 1.0f);
	float zLimit = clamp(1.0f - IN_edgeWeight.y, 0.1f, 1.0f);
#else
	float edgeWeight = 1.0f;
	float zLimit = 0.1f;
#endif

	if(POMDisable == 0)
	{
		float3 tanEyePos;

		tanEyePos.x = dot(IN_worldTangent.xyz, IN_worldEyePosPOM.xyz);
		tanEyePos.y = dot(IN_worldBinormal.xyz, IN_worldEyePosPOM.xyz);
		tanEyePos.z = dot(IN_worldNormal.xyz,	IN_worldEyePosPOM.xyz);

		tanEyePos = normalize(tanEyePos);
		float clampedZ = max(zLimit, tanEyePos.z);
		
		float VdotN = abs(dot(normalize(IN_worldEyePosPOM.xyz), normalize(IN_worldNormal.xyz)));
		float numberOfSteps = lerp(POMMaxSteps, POMMinSteps, VdotN);

		float globalScale = globalHeightScale * edgeWeight * saturate(numberOfSteps - 1.0f) * saturate(VdotN / POMVDotNBlendFactor);

		float2 maxParallaxOffset = (-tanEyePos.xy / clampedZ) * heightScale * globalScale;
		float2 heightBiasOffset = (tanEyePos.xy / clampedZ) * heightBias * globalScale;

		float height = TraceHeight(IN_heightSampler, IN_diffuseTexCoord, maxParallaxOffset, heightBiasOffset, numberOfSteps).r;
		float2 textCoordOffset = heightBiasOffset + (maxParallaxOffset * (1.0f - height));

		IN_diffuseTexCoord += textCoordOffset;
		IN_bumpTexCoord += textCoordOffset;
#if SPEC_MAP
		IN_specularTexCoord += textCoordOffset;
#endif // SPEC_MAP	
	}
#endif // PARALLAX_MAP_V2 && __SHADERMODEL >= 40

	#if DIFFUSE_TEXTURE
		float4 diffuseColor = tex2D(IN_diffuseSampler, IN_diffuseTexCoord);
	#else
		float4 diffuseColor = float4(1.0, 1.0, 1.0, 1.0);
	#endif
	OUT.surface_diffuseColor = calculateDiffuseColor(diffuseColor);
	
#ifdef USE_DETAIL_MAP
	float detailInten=1.f;
	#if DETAIL_USE_SPEC_ALPHA_AS_CONTROL && SPECULAR && SPEC_MAP	
		detailInten = tex2D(IN_specularSampler, IN_specularTexCoord.xy).w;
	#endif

	#if DETAIL_UV
		float2 detailUV	= IN_detailUV.xy;
	#elif DIRT_NORMALMAP
		float2 detailUV = IN_dirtBumpUV.xy;	
	#else
		float2 detailUV = IN_diffuseTexCoord.xy;
	#endif
	float3 detailBumpAndIntensity = GetDetailBumpAndIntensity(  detailUV,  detailInten);

	OUT.surface_diffuseColor  *= detailBumpAndIntensity.z;
#endif

#if WRINKLE_MAP
	OUT.surface_worldNormal.xyz = CalculateWrinkleNormal(
		IN_bumpSampler, 
		IN_bumpTexCoord.xy, 
		IN_worldTangent, 
		IN_worldBinormal,
		IN_worldNormal);
#else
	#if NORMAL_MAP
		#if PARALLAX
			float3 packedNormal = float3(0.0, 0.0, 0.0);
		#else
			float3 packedNormal = tex2D_NormalMap(IN_bumpSampler, IN_bumpTexCoord.xy).xyz;
		#endif
		float3 packedNormalHeight = CalculatePackedNormal(
			packedNormal,
			#if PARALLAX
				parallaxPackedNormalHeight,
			#endif
			#if DIRT_NORMALMAP
				IN_dirtBumpSampler,
				IN_dirtBumpUV.xyz,
			#endif
			IN_bumpTexCoord.xy);

			#ifdef USE_DETAIL_MAP
				packedNormalHeight.xy += detailBumpAndIntensity.xy;
			#endif

			OUT.surface_worldNormal.xyz = CalculateWorldNormal(
				packedNormalHeight.xy, 
				bumpiness, 
				IN_worldTangent, 
				IN_worldBinormal, 
				IN_worldNormal);
	#else
		//should be normalized as the normal is interpolated from vertex normals
		OUT.surface_worldNormal.xyz = normalize(IN_worldNormal.xyz); 
	#endif
#endif

#ifdef DECAL_USE_NORMAL_MAP_ALPHA
	OUT.surface_worldNormal.a = packedNormalHeight.z;
#endif

#if NORMAL_MAP2
	float3 packedNormalHeight2 = tex2D_NormalMap(IN_bumpSampler2, IN_bumpTexCoord2.xy).xyz;
	OUT.surface_worldNormal2.xyz = CalculateWorldNormal(packedNormalHeight2.xy, bumpiness, IN_worldTangent2, IN_worldBinormal2, IN_worldNormal);
#endif

#if SPECULAR
	CalculateSpecularContribution(
		OUT,
		#if SPEC_MAP
			IN_specularSampler,
			IN_specularTexCoord.xy,
		#endif
		IN_baseColor,
		OUT.surface_worldNormal);

	#ifdef USE_DETAIL_MAP
		OUT.surface_specularIntensity *=detailBumpAndIntensity.z;
	#endif

#endif

#if REFLECT
	float3 surfaceToEyeDir = normalize(IN_worldEyePos);	
	CalculateReflection(
		OUT,
		IN_environmentSampler,
		#if REFLECT_MIRROR
			IN_screenPos,
		#endif
		#if defined(USE_MIRROR_CRACK_MAP)
			IN_mirrorTexCoord,
		#endif
		#if SPECULAR
			OUT.surface_specularExponent,
		#endif
		surfaceToEyeDir,
		OUT.surface_worldNormal);
#endif

#if PARALLAX
	// parallax only: if BumpMap.xy is (0,0), then we want no lighting:
	const float threshold = 0.002f; // 0.00001f
	float parallaxLightMask = (dot(packedNormalHeight.xy, packedNormalHeight.xy) >= threshold);

	OUT.surface_diffuseColor.rgb	*= parallaxLightMask;
	OUT.surface_baseColor.rgb		*= parallaxLightMask;
	OUT.surface_specularIntensity	*= parallaxLightMask;
#endif //PARALLAX...

#ifdef COLORIZE
	OUT.surface_diffuseColor.rgba*=colorize;
#endif

#if SELF_SHADOW
	OUT.surface_selfShadow = 1.0f;
#endif

#if PARALLAX_MAP_V2 && __SHADERMODEL >= 40
	float3 tanLightDirection;

	tanLightDirection.x = dot(IN_worldTangent.xyz, gDirectionalLight.xyz);
	tanLightDirection.y = dot(IN_worldBinormal.xyz, gDirectionalLight.xyz);
	tanLightDirection.z = dot(IN_worldNormal.xyz, gDirectionalLight.xyz);
	float shadowAmount = TraceSelfShadow(IN_diffuseTexCoord, IN_heightSampler, tanLightDirection, 1.0f - IN_edgeWeight, heightScale * globalHeightScale);
	OUT.surface_selfShadow = (1.0f - shadowAmount * parallaxSelfShadowAmount);

#if EDGE_WEIGHT
	if(POMEdgeVisualiser)
	{
		OUT.surface_diffuseColor.r = clamp(IN_edgeWeight.x, 0.0f, 1.0f);
		OUT.surface_diffuseColor.g = 1.0f - clamp(IN_edgeWeight.y, 0.0f, 1.0f);
		OUT.surface_diffuseColor.b = 0.0f;
	}
#endif
#endif

#if USE_SLOPE
	OUT.slope = CalcSlope(IN_worldNormal.z);
#endif

	CalculateEmissiveContribution(OUT);

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

SurfaceProperties GetSurfacePropertiesVeryBasic(float4 IN_baseColor, float3 IN_worldNormal)
{
	SurfaceProperties OUT = (SurfaceProperties)0;
	
	OUT.surface_baseColor		= IN_baseColor;
	OUT.surface_diffuseColor	= 1.0f;

#if DIFFUSE2 || DIFFUSE3 || OVERLAY_DIFFUSE2
	OUT.surface_overlayColor=0;
#endif	

	OUT.surface_worldNormal.xyz = normalize(IN_worldNormal); //should be normalized as the normal is interpolated from vertex normals

#ifdef DECAL_USE_NORMAL_MAP_ALPHA
	OUT.surface_worldNormal.a=1.0f;
#endif

	// Disable spec on very simple surfaces
#if SPECULAR
	OUT.surface_specularExponent = 0.0f;	
	OUT.surface_specularIntensity = 0.0f;
	OUT.surface_fresnel = 1.0f;
	#if DIFFUSE2
		#if DIFFUSE2_SPEC_MASK
			OUT.surface_diffuse2SpecClamp=0;
		#else
			OUT.surface_diffuse2SpecMod=0;
		#endif // DIFFUSE2_SPEC_MASK
	#endif	// DIFFUSE2
#endif	// SPECULAR

#if REFLECT
	OUT.surface_reflectionColor=0;
#endif 

#if EMISSIVE || EMISSIVE_ADDITIVE
	OUT.surface_emissiveIntensity = emissiveMultiplier * 
									OUT.surface_diffuseColor.a * 
									gEmissiveScale;

	#if !PALETTE_TINT
		OUT.surface_emissiveIntensity *= OUT.surface_baseColor.b;
	#endif


	#if EMISSIVE_NIGHTONLY
		OUT.surface_emissiveIntensity *= gDayNightEffects;
	#endif
#else
	OUT.surface_emissiveIntensity = 0.0;
#endif

#if SELF_SHADOW
	OUT.surface_selfShadow = 1.0f;
#endif
#if USE_SLOPE
	OUT.slope = CalcSlope(IN_worldNormal.z);
#endif
	return OUT;
}

SurfaceProperties GetSurfacePropertiesBasicAlphaClip(float4		IN_baseColor,
					#if PALETTE_TINT
											float4		IN_baseColorTint,
					#endif
					#if DIFFUSE_TEXTURE
											float2		IN_diffuseTexCoord,
											sampler2D	IN_diffuseSampler,
					#endif
											float3		IN_worldNormal
#if DIFFUSE_TEXTURE
											, bool		IN_useAlphaClip
#endif // DIFFUSE_TEXTURE
											)
{
#if DIFFUSE_TEXTURE
	float4 diffuseColor		= tex2D(IN_diffuseSampler, IN_diffuseTexCoord);

	rageDiscard(IN_useAlphaClip && (diffuseColor.a < 0.5) );
#endif

	SurfaceProperties OUT	= GetSurfacePropertiesVeryBasic(IN_baseColor, IN_worldNormal);

#if DIFFUSE_TEXTURE
	OUT.surface_diffuseColor = diffuseColor;
#endif // DIFFUSE_TEXTURE
	
#if PALETTE_TINT
	OUT.surface_baseColorTint	= IN_baseColorTint;
#endif

	return OUT;
}

SurfaceProperties GetSurfacePropertiesBasic(float4		IN_baseColor,
					#if PALETTE_TINT
											float4		IN_baseColorTint,
					#endif
					#if DIFFUSE_TEXTURE
											float2		IN_diffuseTexCoord,
											sampler2D	IN_diffuseSampler,
					#endif
											float3		IN_worldNormal
											)
{
	return GetSurfacePropertiesBasicAlphaClip(	IN_baseColor,
					#if PALETTE_TINT
												IN_baseColorTint,
					#endif
					#if DIFFUSE_TEXTURE
												IN_diffuseTexCoord,
												IN_diffuseSampler,
					#endif
												IN_worldNormal
#if DIFFUSE_TEXTURE
												, false
#endif // DIFFUSE_TEXTURE
										);

}

// ----------------------------------------------------------------------------------------------- //
#endif //DEFERRED_UNPACK_LIGHT
// ----------------------------------------------------------------------------------------------- //

StandardLightingProperties DeriveLightingPropertiesForCommonSurfaceInternal( SurfaceProperties surfaceInfo, bool useTint, float naturalAmbientScale, float artificialAmbientScale )
{
	StandardLightingProperties OUT;

	OUT.diffuseColor = surfaceInfo.surface_diffuseColor;

	if (useTint)
	{
#if PALETTE_TINT
		OUT.diffuseColor.rgb *= surfaceInfo.surface_baseColorTint.rgb;
#endif
#if PALETTE_TINT_MAX	// Max: unpacked tint color is directly fed into COLOR0 (from MapChannel=13)
		OUT.diffuseColor.rgb *= surfaceInfo.surface_baseColor.rgb;
#endif
	}

#if DIFFUSE2 || DIFFUSE3 || OVERLAY_DIFFUSE2
	// Overlay colour contribution.
	float invAlpha = 1.0 - surfaceInfo.surface_overlayColor.a;
	OUT.diffuseColor.rgb = (OUT.diffuseColor.rgb * invAlpha) + (surfaceInfo.surface_overlayColor.rgb * surfaceInfo.surface_overlayColor.a);
#endif	

#if defined(DECAL_DIRT)
	OUT.diffuseColor.rgba	   *= surfaceInfo.surface_baseColor.rgba;
	OUT.naturalAmbientScale		= 1.0f;
	OUT.artificialAmbientScale	= 1.0f;
#elif defined(DECAL_NORMAL_ONLY)
	OUT.diffuseColor.a		    = surfaceInfo.surface_baseColor.a;	// save per-vertex alpha
	OUT.naturalAmbientScale		= surfaceInfo.surface_baseColor.r;
	OUT.artificialAmbientScale	= surfaceInfo.surface_baseColor.g;
#elif defined(PROJTEX_SHADER)
	OUT.diffuseColor.rgba		*= surfaceInfo.surface_baseColor.rgba;
	OUT.naturalAmbientScale		= 1.0f;
	OUT.artificialAmbientScale	= 1.0f;
#elif EMISSIVE
	OUT.diffuseColor.a		   *= surfaceInfo.surface_baseColor.a;
	OUT.naturalAmbientScale		= surfaceInfo.surface_baseColor.r; 
	OUT.artificialAmbientScale	= surfaceInfo.surface_baseColor.g; 
#elif defined(IS_PED_SHADER)
	OUT.diffuseColor.a		   *= surfaceInfo.surface_baseColor.a;
	OUT.naturalAmbientScale		= surfaceInfo.surface_baseColor.r; 
	OUT.artificialAmbientScale	= surfaceInfo.surface_baseColor.r;
#else
	OUT.diffuseColor.a		   *= surfaceInfo.surface_baseColor.a;
	OUT.naturalAmbientScale		= surfaceInfo.surface_baseColor.r;
	OUT.artificialAmbientScale	= surfaceInfo.surface_baseColor.g;
#endif	

	// Multiple by scales
		//if( gEmissiveScale > 0.5f )

	OUT.naturalAmbientScale *= naturalAmbientScale;
	OUT.artificialAmbientScale *= artificialAmbientScale;

#if USE_DYNAMIC_AMBIENT_BAKE
	half wrapAdjust = surfaceInfo.surface_worldNormal.z * 0.5 + 0.5;
	half2 dynamicBake = half2(gDynamicBakeStart, 0.3) + wrapAdjust * half2(gDynamicBakeRange, 1.0);
	OUT.naturalAmbientScale = dynamicBake.x * OUT.naturalAmbientScale;
	OUT.artificialAmbientScale = dynamicBake.y * OUT.artificialAmbientScale;
#endif

	OUT.inInterior = gInInterior;

#if SPECULAR
	OUT.specularSkin = surfaceInfo.surface_specularSkin;
	OUT.reflectionIntensity = 1.0; // set to full envir reflection shader may change later

	OUT.specularIntensity = surfaceInfo.surface_specularIntensity;
	OUT.specularExponent = surfaceInfo.surface_specularExponent;	

	OUT.fresnel = surfaceInfo.surface_fresnel;

	#ifdef DIFFUSE2_IGNORE_SPEC_MODULATION
		// do nothing
	#else
		#if DIFFUSE2
			#if DIFFUSE2_SPEC_MASK
				OUT.specularIntensity *= max(invAlpha, diffuse2SpecClamp);
			#else
				OUT.specularIntensity *= (1.0-invAlpha) * diffuse2SpecMod;
			#endif
		#endif
	#endif
#endif	// SPECULAR

#if REFLECT
	OUT.reflectionColor = surfaceInfo.surface_reflectionColor;
#endif	// REFLECT

#if __MAX //Gamma compensation for lighting and specular clamp scale and quantize (to be adjusted when new spec range decided)
	OUT.diffuseColor.rgb *= OUT.diffuseColor.rgb; 
#endif

	OUT.emissiveIntensity = surfaceInfo.surface_emissiveIntensity;
	#if !PALETTE_TINT
		OUT.emissiveIntensity *= surfaceInfo.surface_baseColor.b;
	#endif
#if SELF_SHADOW
	OUT.selfShadow = surfaceInfo.surface_selfShadow;
#endif
#if USE_SLOPE
	OUT.slope = surfaceInfo.slope;
#endif
	return OUT;	
}

StandardLightingProperties DeriveLightingPropertiesForCommonSurface( SurfaceProperties surfaceInfo, float naturalAmbientScale, float artificalAmbientScale )
{
	return DeriveLightingPropertiesForCommonSurfaceInternal( surfaceInfo, true, naturalAmbientScale, artificalAmbientScale );
}

StandardLightingProperties DeriveLightingPropertiesForCommonSurfaceNoTint( SurfaceProperties surfaceInfo, float naturalAmbientScale, float artificalAmbientScale )
{
	return DeriveLightingPropertiesForCommonSurfaceInternal( surfaceInfo, false, naturalAmbientScale, artificalAmbientScale );
}

//Support for shaders that have not yet been converted to enable instancing.
StandardLightingProperties DeriveLightingPropertiesForCommonSurfaceInternal( SurfaceProperties surfaceInfo, bool useTint )
{
	return DeriveLightingPropertiesForCommonSurfaceInternal(surfaceInfo, useTint, gNaturalAmbientScale, gArtificialAmbientScale);
}

StandardLightingProperties DeriveLightingPropertiesForCommonSurface( SurfaceProperties surfaceInfo )
{
	return DeriveLightingPropertiesForCommonSurface( surfaceInfo, gNaturalAmbientScale, gArtificialAmbientScale );
}

StandardLightingProperties DeriveLightingPropertiesForCommonSurfaceNoTint( SurfaceProperties surfaceInfo )
{
	return DeriveLightingPropertiesForCommonSurfaceNoTint( surfaceInfo, gNaturalAmbientScale, gArtificialAmbientScale );
}

// ----------------------------------------------------------------------------------------------- //

void GetLightValuesCommon(
	inout LightingResult res,
	out float diffNdotL,
	out float specNdotL)
{
	// Apply back-lighting adjustment
	res.surface.normal *= res.backLightingAdjust;

	// Apply to both diffuse and specular
	#if GLASS_LIGHTING && !WRAP_LIGHTING
		float cosTheta = dot(res.surface.normal, res.surface.lightDir);
		cosTheta = lerp(abs(cosTheta), saturate(cosTheta), res.material.diffuseColor.a);
	#else
		float cosTheta = saturate(dot(res.surface.normal, res.surface.lightDir));
	#endif
	
	#if WRAP_LIGHTING
		diffNdotL = saturate((cosTheta + wrapLigthtingTerm) / ((1 + wrapLigthtingTerm) * (1 + wrapLigthtingTerm)));
		specNdotL = cosTheta;
	#else
		diffNdotL = cosTheta;
		specNdotL = cosTheta;
	#endif

	// Remove back-lighting adjustment
	res.surface.normal *= res.backLightingAdjust;
}

// ----------------------------------------------------------------------------------------------- //

void GetLightValuesFast(
	LightingResult res,
	out Components components,
	out float3 lightDiffuse,
	out float3 lightSpecular)
{
	float diffNdotL;
	float specNdotL;
	GetLightValuesCommon(res, diffNdotL, specNdotL);

	components.NdotL = diffNdotL;
	components.Kd = 1.0f;
	components.Ks = 0.0f;
	components.EdotN = 1.0f;

#if SPECULAR
	components.Kd -= res.material.specularIntensity;
#endif

	lightDiffuse = diffNdotL * components.Kd;
	lightSpecular = float3(0.0f, 0.0f, 0.0f);
}

// ----------------------------------------------------------------------------------------------- //

void GetLightValues(
	inout LightingResult res, 
	bool diffuse, 
	bool specular,
	bool reflection,
	out Components components,
	out float3 lightDiffuse,
	out float3 lightSpecular)
{
	
	float diffNdotL;
	float specNdotL;
	GetLightValuesCommon(res, diffNdotL, specNdotL);

#if SPECULAR
	const float EdotN = saturate(dot(res.surface.eyeDir, res.surface.normal));

	components.NdotL = diffNdotL;
	components.EdotN = EdotN;

	if (!specular && reflection)
	{
		float reflectFresnel = fresnelSlick(res.material.fresnel, EdotN);

		// Adjust alpha based on fresnel (mostly for glass)
		#if ALPHA_FRESNEL_ADJUST && 1
			res.material.diffuseColor.a = max(res.material.diffuseColor.a, reflectFresnel);
			components.Kd = 1.0f - res.material.specularIntensity * lerp(1.0, reflectFresnel, res.material.diffuseColor.a);
		#else
			components.Kd = 1.0f - res.material.specularIntensity * reflectFresnel;
		#endif
		components.Ks = res.material.specularIntensity;

		lightSpecular = float3(0.0f, 0.0f, 0.0f);
	}
	else if (!specular && !reflection)
	{
		float reflectFresnel = fresnelSlick(res.material.fresnel, EdotN);

		components.Kd = 1.0f - res.material.specularIntensity * reflectFresnel;
		components.Ks = 0.0f;

		lightSpecular = float3(0.0f, 0.0f, 0.0f);
	}
	else
	{
		const float HdotL = saturate(dot(res.surface.halfVector, res.surface.lightDir));

		float2 reflectAndSpecularFresnel = fresnelSlick2(res.material.fresnel.xx, float2(EdotN, HdotL));

		const float specNormalisation = (2.0 + res.material.specularExponent) / (8.0);

		// Adjust alpha based on fresnel (mostly for glass)
		#if ALPHA_FRESNEL_ADJUST && 1
			res.material.diffuseColor.a = max(res.material.diffuseColor.a, reflectAndSpecularFresnel.x);
			components.Kd = 1.0f - res.material.specularIntensity * lerp(1.0, reflectAndSpecularFresnel.x, res.material.diffuseColor.a);
		#else
			components.Kd = 1.0f - res.material.specularIntensity * reflectAndSpecularFresnel.x;
		#endif
		components.Ks = res.material.specularIntensity;

		// Specular contribution
		float3 specularBrdf = calculateBlinnPhong(res.surface.normal, res.surface.halfVector, res.material.specularExponent) * 
			reflectAndSpecularFresnel.y * 
			specNormalisation;

		lightSpecular = specularBrdf * components.Ks * specNdotL;
	}
#else
	components.Kd = 1.0f;
	components.Ks = 0.0f;
	components.EdotN = 1.0f;
	components.NdotL = diffNdotL;

	lightSpecular = float3(0.0f, 0.0f, 0.0f);
#endif // SPECULAR

	// Diffuse contribution
	if (diffuse)
	{
		lightDiffuse = diffNdotL * components.Kd;
	}
	else
	{
		lightDiffuse = 0.0f;
	}
}

// ----------------------------------------------------------------------------------------------- //

float4 ApplyLightToBRDF(float3 lightDiffuse, float3 lightSpecular, float4 materialDiffuse, bool diffuse, bool specular)
{
	float4 finalColor = float4(0.0, 0.0, 0.0, 1.0);

#if SPECULAR
	if(specular)
	{
		if(diffuse)
		{
			// Diffuse contribution
			float3 diffuseBrdf = materialDiffuse.rgb;
			finalColor.rgb += diffuseBrdf * lightDiffuse;
		}
		
		finalColor.rgb += lightSpecular;
	}
	else if (diffuse)
#endif // SPECULAR
	{
		// Diffuse contribution
		float3 diffuseBrdf = materialDiffuse.rgb;
		finalColor.rgb = diffuseBrdf * lightDiffuse;
	}

	finalColor.a = materialDiffuse.a;

	return finalColor;
}

// ----------------------------------------------------------------------------------------------- //

float4 ApplyLightToSurface(
	inout LightingResult res, 
	bool diffuse, 
	bool specular,
	bool reflection,
	out Components components)
{
	float3 lightDiffuse;
	float3 lightSpecular;
	GetLightValues(res, diffuse, specular, reflection, components, lightDiffuse, lightSpecular);

	float4 finalColor = ApplyLightToBRDF(lightDiffuse, lightSpecular, res.material.diffuseColor, diffuse, specular);
	
	// Light colour and attenuation
	finalColor.rgb = finalColor.rgb * res.lightColor * res.lightAttenuation * res.shadowAmount;
	
	return finalColor;
}

// ----------------------------------------------------------------------------------------------- //

float4 ApplyLightToSurfaceFast(
	inout LightingResult res, 
	bool diffuse, 
	bool specular,
	bool reflection,
	out Components components)
{
	float3 lightDiffuse;
	float3 lightSpecular;
	GetLightValuesFast(res, components, lightDiffuse, lightSpecular);

	float4 finalColor = ApplyLightToBRDF(lightDiffuse, lightSpecular, res.material.diffuseColor, diffuse, specular);
	finalColor.rgb = finalColor.rgb * res.lightColor * res.lightAttenuation * res.shadowAmount;

	return finalColor;
}

// ----------------------------------------------------------------------------------------------- //

float Pack2ZeroOneValuesToU8( float a, float b )
{
	if ( a>.5)
		b +=1.+5./255.f;

	return b*(.5f-1./255.f);
}
void UnPack2ZeroOneValuesToU8( float v, out float a, out float b )
{	
	a =0.;
	if (v > .5f){
		a =1.;
		v-=.5f;
	}	
	b=saturate(v*2.);
	
}

float Pack2ZeroToOneValuesToU8( float a, float b )
{
	return (floor(a*15.0f)*16.0f + floor(b*15.0f))/255.0f;
}

void UnPack2ZeroToOneValuesToU8( float v, out float a, out float b )
{
	float oneOverSixteen = 1.0f/16.0f;
	float vv = round(v * 255.0f) * oneOverSixteen;
	a = floor(vv) * oneOverSixteen;
	b = frac(vv);
}

float Pack2ZeroToOneValuesToU8_5_3( float a, float b )
{
	return (floor(a*31.0f)*8.0f + floor(b*7.0f))/255.0f;
}

void UnPack2ZeroToOneValuesToU8_5_3( float v, out float a, out float b )
{
	float vv = round(v*255.0f) * 1.0f/8.0f;
	a = floor(vv)		*	1.0f/31.0f;
	b = (frac(vv)*8.0f)	*	1.0f/ 7.0f;
}

#if __XENON || __PS3 || __WIN32PC || RSG_ORBIS

// Pack the information into the GBuffer
DeferredGBuffer PackGBuffer(
							#ifdef DECAL_USE_NORMAL_MAP_ALPHA
								float4 surface_worldNormal,
							#else
								float3 surface_worldNormal,
							#endif
								StandardLightingProperties surfaceStandardLightingProperties, float alpha )
{
	DeferredGBuffer OUT;

#if GBUFFER_COVERAGE
	OUT.coverage = 0xffffffff;
#endif // SSTAA

#if defined(DECAL_AMB_ONLY)
	float blend=saturate(1.0f-dot(surfaceStandardLightingProperties.diffuseColor.rgb, ambientDecalMask))*surfaceStandardLightingProperties.diffuseColor.a*alpha;
	
	//strength of ambient occlusion messed with 
	blend= lerp(0.0f, blend, gAmbientOcclusionEffect.x);

	OUT.col0 = 0;
	OUT.col1 = 0;
	OUT.col2 = 0;
	OUT.col3 = float4(0, 0, 0, blend);

#elif defined(DECAL_DIRT)

	OUT.col0.rgb = surfaceStandardLightingProperties.diffuseColor.rgb;
	OUT.col0.a = surfaceStandardLightingProperties.diffuseColor.a * alpha;

	OUT.col1 = 0;

	#if SPECULAR
	float3 specularValues = float3(
		surfaceStandardLightingProperties.specularIntensity,
		surfaceStandardLightingProperties.specularExponent / 512.0f,
		surfaceStandardLightingProperties.fresnel);
	#else
		float3 specularValues = float3(0.0f, 0.0, 0.0f);
	#endif
	
	OUT.col2.xyz = specularValues;
	OUT.col2.a = OUT.col0.a;

	OUT.col3 = 0;
#elif defined(DECAL_SHADOW_ONLY)
	OUT.col0 =0;
	OUT.col0.a = surfaceStandardLightingProperties.diffuseColor.a * alpha;
	OUT.col1 = 0;
	OUT.col2 = 0;	 
	OUT.col2.a = 1.-surfaceStandardLightingProperties.diffuseColor.a * alpha;
	OUT.col3 = 0;

#elif defined(DECAL_DIFFUSE_ONLY)

	OUT.col0.rgb= surfaceStandardLightingProperties.diffuseColor.rgb;
	OUT.col0.a	= surfaceStandardLightingProperties.diffuseColor.a * alpha;
	OUT.col1 = 0;
	OUT.col2 = 0;
	OUT.col3 = 0;

#elif defined(DECAL_NORMAL_ONLY)

	OUT.col0 = 0;

	OUT.col1.xyz = (surface_worldNormal.xyz*0.5f)+0.5f;
	OUT.col1.a = surface_worldNormal.a * surfaceStandardLightingProperties.diffuseColor.a * alpha;	
	
	OUT.col2 = 0;

	OUT.col3 = 0;

#elif defined(DECAL_SPEC_ONLY)

	OUT.col0 = 0;
	
	OUT.col1.xyz = (surface_worldNormal.xyz * 0.5f) + 0.5f;
	OUT.col1.a = 1.0;

	#if SPECULAR
	float3 specularValues = float3(
		surfaceStandardLightingProperties.specularIntensity,
		surfaceStandardLightingProperties.specularExponent / 512.0f,
		surfaceStandardLightingProperties.fresnel);
	#else
		float3 specularValues = float3(0.0f, 0.0, 0.0f);
	#endif

	OUT.col2.xyz = specularValues;
	OUT.col2.a = surfaceStandardLightingProperties.diffuseColor.a*alpha;

	OUT.col3 = 0;

#elif defined(DECAL_EMISSIVE_ONLY) || defined(DECAL_EMISSIVENIGHT_ONLY)

	half4 albedo = surfaceStandardLightingProperties.diffuseColor; 

	float emissive = saturate(surfaceStandardLightingProperties.emissiveIntensity*dot(albedo.rgb, LumFactors) / 16.0f);

	#if EMISSIVE_ADDITIVE
		albedo.rgb *= albedo.a;
		#if EMISSIVE_NIGHTONLY
			albedo.rgb *= gDayNightEffects;
		#endif
	#else
		#if EMISSIVE_NIGHTONLY
			albedo.a *= gDayNightEffects;
		#endif
	#endif


	albedo.a *= alpha;

	OUT.col0 = albedo;
	OUT.col1 = 0;
	OUT.col2 = 0;
	OUT.col3 = float4(0, 0, emissive, albedo.a);

#else //DECAL_XXX_ONLY

	// store diffuse colour
	OUT.col0.rgb = (half3)surfaceStandardLightingProperties.diffuseColor.rgb;	

	//alpha - much simplified now that material IDs are in stencil
	half alphaBlend = half(surfaceStandardLightingProperties.diffuseColor.a * alpha);

	// Reset alpha
	OUT.col0.a = alphaBlend;
	OUT.col2.a = 1.0f;
	OUT.col1.a = 0.0;
	OUT.col3.a = 0.0;

	#if SELF_SHADOW
		OUT.col2.a = surfaceStandardLightingProperties.selfShadow;
	#endif

	#if defined(DECAL_SHADER) //|| defined(PEDSHADER_HAIR_ORDERED) || defined(PEDSHADER_HAIR_CUTOUT) || defined(PEDSHADER_HAIR_LONGHAIR) 
		// Propogate alpha so all render targets are blended correctly
		OUT.col0.a = alphaBlend;
		OUT.col1.a = alphaBlend;
		OUT.col2.a = alphaBlend;
		OUT.col3.a = alphaBlend;
	#endif

	#if defined(DECAL_USE_NORMAL_MAP_ALPHA)
		OUT.col0.a = alphaBlend;
		#if PARALLAX // we want blending normals for projected textures too
			OUT.col1.a = surface_worldNormal.a*surfaceStandardLightingProperties.diffuseColor.a*alpha;	
		#else
			OUT.col1.a = surface_worldNormal.a*alpha;	
		#endif
		OUT.col2.a = OUT.col0.a;
		OUT.col3.a = OUT.col0.a;
	#endif

	// store normal
	float3 tnorm = (surface_worldNormal.xyz*0.5f)+0.5f;
	float twiddle = 0.0;

	#if defined(USE_TWIDDLE) && !defined(DECAL_SHADER)
		tnorm.xyz *= 256.0f;	
		float3 tnorm0=floor(tnorm.xyz);
		float3 twiddle0=(tnorm.xyz-tnorm0.xyz);
		twiddle0.xyz=floor(twiddle0.xyz*float3(8.0f,8.0f,4.0f));
		twiddle=dot(twiddle0.xyz,float3(32.0f,4.0f,1.0f))/255.0f;
		OUT.col1.xyz = half3(tnorm0.xyz*(1.0f/256.0f));
		OUT.col1.a = half(twiddle);
	#else
		OUT.col1.xyz = half3(tnorm.xyz);		
		#if USE_SLOPE && !defined(DECAL_SHADER)
			#if WETNESS_MULTIPLIER 
			#if( defined(IS_TERRAIN_SHADER))
					const float cullPuddleEnd= .2f;
					const float cullPuddleStart= .1f;
				#else
					const float cullPuddleEnd= .3f;
					const float cullPuddleStart= .2f;
				#endif
				 surfaceStandardLightingProperties.slope *= saturate((surfaceStandardLightingProperties.wetnessMult-cullPuddleStart)/(cullPuddleEnd-cullPuddleStart));				
			#endif
			OUT.col1.a =surfaceStandardLightingProperties.slope;
		#endif
	#endif

	#if SPECULAR
		float specDiffuseMix = surfaceStandardLightingProperties.specularIntensity;		
		float specExponent = surfaceStandardLightingProperties.specularExponent / 512.0f;
		float specFresnel = surfaceStandardLightingProperties.fresnel;
		
		OUT.col2.xyz = half3(
			specDiffuseMix, 
			specExponent, 
			specFresnel);
	#else
		OUT.col2.xyz = half3(0.0f, 0.0, 0.98f);
	#endif

#if defined(DECAL_SHADER)
	#if (EMISSIVE)
		float emissive = saturate(surfaceStandardLightingProperties.emissiveIntensity / 16.0f);
		OUT.col3.xyz = float3(0.0, 0.0, emissive);
		#if (EMISSIVE_NIGHTONLY)
			OUT.col0.a *= gDayNightEffects;
		#endif
	#elif (EMISSIVE_ADDITIVE)
		float emissive = saturate(surfaceStandardLightingProperties.emissiveIntensity / 16.0f);
		OUT.col3.xyz = float3(0.0, 0.0, emissive)
		OUT.col0.xyz = float4(OUT.col0.xyz * OUT.col0.w, 1.0);
		#if (EMISSIVE_NIGHTONLY)
			OUT.col0.xyz *= gDayNightEffects;
		#endif
	#else
		#if defined(PROJTEX_SHADER) || defined(DECAL_GLUE) || defined(IS_PED_SHADER) || defined(WATER_DECAL)
			OUT.col3 = 0.0f;
		#else
			OUT.col3 = float4(0.0f, 0.0f, 0.0f, 1.0f);
		#endif
	#endif
#else

	OUT.col3.x = (surfaceStandardLightingProperties.naturalAmbientScale + naturalAmbientPush);
	OUT.col3.y = surfaceStandardLightingProperties.artificialAmbientScale;
	OUT.col3.xy = sqrt(OUT.col3.xy * 0.5);

	#if (EMISSIVE || EMISSIVE_ADDITIVE)
		float emissive = saturate(surfaceStandardLightingProperties.emissiveIntensity / 16.0f);
		#if (EMISSIVE_ADDITIVE)
			OUT.col0.xyz = float4(OUT.col0.xyz * OUT.col0.w, 1.0);
			#if (EMISSIVE_NIGHTONLY)
				OUT.col0.xyz *= gDayNightEffects;
			#endif
		#else
			#if (EMISSIVE_NIGHTONLY)
				OUT.col0.a *= gDayNightEffects;
			#endif
		#endif
	#else
		float emissive = 0.0f;
	#endif
	OUT.col3.z = emissive;

	#if SPECULAR
		#if PED_RIM_LIGHT
			OUT.col3.a = Pack2ZeroOneValuesToU8(1.0f-surfaceStandardLightingProperties.specularSkin, surfaceStandardLightingProperties.reflectionIntensity);
		#else
			OUT.col3.a = Pack2ZeroOneValuesToU8(1.0f-surfaceStandardLightingProperties.specularSkin, 1.0f);
		#endif
	#else
		OUT.col3.a = 1.0f;
	#endif
	
	#ifdef USE_BACKLIGHTING_HACK  
	// use the skin to mark that it is backlit cloth
		OUT.col3.a = Pack2ZeroOneValuesToU8(1.0f-1.f, 0.0f);
	#endif
#endif

#endif //DECAL_XXX_ONLY

#if !defined(IS_PED_SHADER) && !defined(TREE_DRAW) && (!defined(GRASS_SHADER) || (defined(GRASS_FUR_SHADER) && WETNESS_MULTIPLIER)) && !defined(IS_VEHICLE_INTERIOR)
	
	float wetblend = 
		gWetnessBlend * 
		saturate((surface_worldNormal.z - 0.35) / 0.65) * 
		(1.0 - surfaceStandardLightingProperties.inInterior) * 
		surfaceStandardLightingProperties.naturalAmbientScale;
	
	float wetBlendSpecular = wetblend;
	#if SPECULAR
		float wetBlendDiffuse = wetblend * (1.0 - surfaceStandardLightingProperties.specularIntensity * 0.5);
	#else
		float wetBlendDiffuse = wetblend;
	#endif

	#if WETNESS_MULTIPLIER && ((defined(IS_TERRAIN_SHADER) || TERRAIN_WETNESS) || defined(GRASS_FUR_SHADER))
		wetBlendDiffuse *= 1.0 - surfaceStandardLightingProperties.wetnessMult;
	#endif

	#if WETNESS_MULTIPLIER
		wetBlendSpecular *= surfaceStandardLightingProperties.wetnessMult;
	#endif

	// Diffuse wet adjust
	OUT.col0.rgb *= lerp(1.0f, 0.5f, wetBlendDiffuse);

	// Specular wet adjust
	#if defined(IS_VEHICLE_SHADER)
		float3 targetSpecular = float3(0.5f, 250.0f / 512.0f, OUT.col2.z);
	#else
		float3 targetSpecular = float3(0.5f, 250.0f / 512.0f, 0.97f);
	#endif

	#if !defined(IS_TERRAIN_SHADER) && !TERRAIN_WETNESS && SPECULAR
		#if defined(DECAL_SHADER)
			targetSpecular.xy *= saturate(surfaceStandardLightingProperties.specularIntensity + 0.7);
		#else
			targetSpecular.xy *= saturate(surfaceStandardLightingProperties.specularIntensity + 0.4);
		#endif
	#endif

	#if SPECULAR
		float3 diff = max(0.0f, targetSpecular - OUT.col2.xyz);
		OUT.col2.xyz = (diff * wetBlendSpecular) + OUT.col2.xyz;
		OUT.col2.xy = sqrt(OUT.col2.xy);
	#else
		OUT.col2.xy = sqrt(OUT.col2.xy + targetSpecular * wetBlendSpecular);
	#endif

#else
	#if SPECULAR
		OUT.col2.xy = sqrt(OUT.col2.xy);
	#endif
#endif

	return(OUT);
}

DeferredGBuffer PackGBuffer(
#ifdef DECAL_USE_NORMAL_MAP_ALPHA
							float4 surface_worldNormal,
#else
							float3 surface_worldNormal,
#endif
							StandardLightingProperties surfaceStandardLightingProperties )
{
	return PackGBuffer(surface_worldNormal, surfaceStandardLightingProperties, globalAlpha);
}

// now unpack
// ----------------------------------------------------------------------------------------------- //
#if defined(DEFERRED_UNPACK_LIGHT)
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
// NOTE: ViewPos is in range [-1,1]
float4 GetEyeRay(float2 signedScreenPos)
{
	// Some constants are precombined, to avoid constant ops 
	// Originally was:
	//  	const float2 projPos = (signedScreenPos + deferredPerspectiveShearParams.xy) * deferredProjectionParams.xy;
	//      return float4(mul( float4(projPos,-1,0), gViewInverse ).xyz, 1);
	// 
	// After factoring, it is now only a 3x3 transform instead of add + scale + 4x4 transform
    const float3 transformVec = float3( signedScreenPos, 1.0 );
	return float4( dot( transformVec, deferredPerspectiveShearParams0), 
                   dot( transformVec, deferredPerspectiveShearParams1),
	               dot( transformVec, deferredPerspectiveShearParams2), 1);
}


DeferredSurfaceInfo UnPackGBuffer_S0(float2 screenPos, float4 eyeRay, bool usetwiddle, bool UnpackFoliageBit, uint sampleIndex)
{
	DeferredSurfaceInfo OUT=(DeferredSurfaceInfo)0;

	// materialID is stored in stencil buffer:
	float2 posXY = screenPos.xy;
	float stencilSample = 0.0f;
	float depthSample = 0.0f;
#if MULTISAMPLE_TECHNIQUES
	uint4 sampleIndexEQAA = uint4(sampleIndex, sampleIndex, sampleIndex, sampleIndex);
	const int3 iPos = getIntCoordsWithEyeRay(gbufferTextureDepthGlobal, screenPos, sampleIndex, gViewInverse, eyeRay.xyz, globalScreenSize.xy);
	float4 depthStencilSample = gbufferTextureDepthGlobal.Load(iPos, sampleIndex);
	stencilSample = getStencilValueScreenMS(gbufferStencilTextureGlobal, iPos, sampleIndex);
	depthSample = fixupGBufferDepth(depthStencilSample.x);
#if ENABLE_EQAA
	// Color decompression is disabled for regular MSAA as well as for ambient volumes on EQAA
	if (gMSAAFmaskEnabled)
	{
		const uint fmask0 = gbufferFragmentMask0Global.Load( iPos );
		#if EQAA_DECODE_GBUFFERS
		const uint4 fragmentMasks = uint4(
			fmask0,
			gbufferFragmentMask1Global.Load( iPos ),
			gbufferFragmentMask2Global.Load( iPos ),
			gbufferFragmentMask3Global.Load( iPos )
			);
		sampleIndexEQAA.z = sampleIndex;	//Not using fragment compression for GBuffer[2]
		sampleIndexEQAA.yw = translateAASampleExt( fragmentMasks.yw, sampleIndex );
		#endif //EQAA_DECODE_GBUFFERS
		sampleIndexEQAA.x = translateAASample( fmask0, sampleIndex );
		//Assert(sampleIndexEQAA < gMSAANumFragments);
		//it has to exist since we are only processing anchored samples
	}
#endif // ENABLE_EQAA
#else
	float4 depthStencilSample = GBufferTexDepth2D(GBufferTextureSamplerDepthGlobal, posXY.xy);
	depthSample = depthStencilSample.x;
#if __SHADERMODEL >= 40
	stencilSample = getStencilValueScreen(gbufferStencilTextureGlobal, screenPos * globalScreenSize.xy);
#endif // __SHADERMODEL >= 40
#endif // MULTISAMPLE_TECHNIQUES

	OUT.materialID = stencilSample;

	// Determine if we are in the interior (we always need this)
	OUT.inInterior = IsInInterior(OUT.materialID);

	// Unpack the material diffuse colour and specular contrib factor.
#if __XENON
	float4	materialDiffuseAlphaSample;
	asm 
    { 
		tfetch2D materialDiffuseAlphaSample.xyzw, posXY.xy, GBufferTextureSampler0Global 
	};
#elif __PS3
	float4	materialDiffuseAlphaSample	= h4tex2D(GBufferTextureSampler0Global, posXY.xy );
#elif RSG_PC || RSG_DURANGO || RSG_ORBIS
#if MULTISAMPLE_TECHNIQUES
	float4 materialDiffuseAlphaSample	= gbufferTexture0Global.Load(iPos, sampleIndexEQAA.x);
#else
	float4 materialDiffuseAlphaSample	= tex2D(GBufferTextureSampler0Global, posXY.xy );	
#endif // MULTISAMPLE_TECHNIQUES
#endif // __XENON

	OUT.diffuseColor = materialDiffuseAlphaSample.xyz;
	OUT.diffuseColor = ProcessDiffuseColor(OUT.diffuseColor);
	
	// Unpack the world space position from depth
	float linearDepth = getLinearDepth(depthSample, deferredProjectionParams.zw);
	
	// Normalize eye ray if needed
	eyeRay.xyz /= eyeRay.w;

#ifdef NVSTEREO
	float3 StereorizedCamPos = float3(0.0f,0.0f,0.0f);
//#if 0
	if (gStereoPuddle && (eyeRay.w == 1.0f))
	{
		float fStereoScalar = StereoToMonoScalar(linearDepth);
		fStereoScalar *= deferredProjectionParams.x;
		StereorizedCamPos= gViewInverse[3].xyz + gViewInverse[0].xyz * fStereoScalar * -1.0f;
	}
	else
//#endif
	{
		StereorizedCamPos = gViewInverse[3].xyz + (StereoWorldCamOffSet());
	}
	OUT.positionWorld = StereorizedCamPos + (eyeRay.xyz * linearDepth);
#else
	OUT.positionWorld = gViewInverse[3].xyz + (eyeRay.xyz * linearDepth);
#endif

	OUT.rawD = depthSample; 
	OUT.depth = linearDepth;
	OUT.eyeRay = eyeRay.xyz;

#if __XENON
	// Unpack the spec and amb
	float4	SpecIntExpAmbSample;
	asm 
    { 
		tfetch2D SpecIntExpAmbSample.xyzw, posXY.xy, GBufferTextureSampler2Global 
	};
#elif __PS3
	float4	SpecIntExpAmbSample= h4tex2D(GBufferTextureSampler2Global, posXY.xy );	
#elif RSG_PC || RSG_DURANGO || RSG_ORBIS
#if MULTISAMPLE_TECHNIQUES
	//careful: Gbuffer2 doesn't have Fmask, so its anchor samples are already resolved
	float4 SpecIntExpAmbSample= gbufferTexture2Global.Load(iPos, sampleIndexEQAA.z);
#else
	float4 SpecIntExpAmbSample= tex2D(GBufferTextureSampler2Global, posXY.xy );	
#endif // MULTISAMPLE_TECHNIQUES

#endif	// platforms

	// Gamma 2.0 to linear
	SpecIntExpAmbSample.xy *= SpecIntExpAmbSample.xy;

	OUT.specularIntensity = SpecIntExpAmbSample.x; 
	OUT.specularExponent = SpecIntExpAmbSample.y * 512.0f;
	OUT.fresnel = SpecIntExpAmbSample.z;
	OUT.selfShadow = SpecIntExpAmbSample.w;

	// Unpack the normal
#if __PS3
	float4	normalSample = h4tex2D(GBufferTextureSampler1Global, posXY.xy );	
#elif RSG_PC || RSG_DURANGO || RSG_ORBIS
#if MULTISAMPLE_TECHNIQUES
	float4 normalSample = gbufferTexture1Global.Load(iPos, sampleIndexEQAA.y);
#else
	float4 normalSample = h4tex2D(GBufferTextureSampler1Global, posXY.xy );	
#endif // MULTISAMPLE_TECHNIQUES

#else	// platforms
	float4	normalSample;
	asm 
	{ 
		tfetch2D normalSample.xyzw, posXY.xy, GBufferTextureSampler1Global
	};	
#endif	// platforms

#if 1 //faster normal de-twiddle 
	if (usetwiddle==true) // this branch should be compiled out
	{
		float3 twiddle = frac(normalSample.w*float3(0.998046875f,7.984375f,63.875f));
		twiddle.xy -= float2(twiddle.y,twiddle.z)*0.125f;
		OUT.normalWorld.xyz=normalize(normalSample.xyz*256.0f+twiddle.xyz-128.0f);
	}
	else
	{
		OUT.normalWorld.xyz=normalize((normalSample.xyz*2.0f)-1.0f);
	}

	if(UnpackFoliageBit)
	{
		OUT.bIsGrass = (normalSample.w==1.0f)? true : false;
		normalSample.w = 0.0f;
	}
	else
	{
		OUT.bIsGrass = false;
	}
#else
	float3 twiddle = frac(normalSample.w*float3(0.998046875f,7.984375f,63.875f)))/256.0f;
	twiddle -= float3(twiddle.y,twiddle.z,0.0f)*0.125f;
	OUT.normalWorld.xyz=normalize(((normalSample.xyz+twiddle.xyz)-0.5f)*2.0f);
#endif

#if USE_SLOPE
	OUT.slope = normalSample.w;
#endif

	#if __XENON
		// Unpack extra
		float4	ExtraSample;
		asm 
		{ 
			tfetch2D ExtraSample.xyzw, posXY.xy, GBufferTextureSampler3Global
		};
	#elif __PS3
		float4	ExtraSample= h4tex2D(GBufferTextureSampler3Global, posXY.xy );	
	#elif RSG_PC || RSG_DURANGO || RSG_ORBIS
		#if MULTISAMPLE_TECHNIQUES
			float4 ExtraSample= gbufferTexture3Global.Load( iPos, sampleIndexEQAA.w );
		#else
			float4 ExtraSample= tex2D(GBufferTextureSampler3Global, posXY.xy );
		#endif // MULTISAMPLE_TECHNIQUES
	#endif	// platforms

#if !defined(DEFERRED_NO_LIGHT_SAMPLERS) 
	float SSAO		= h1tex2D(gDeferredLightSampler2, posXY.xy);
	ExtraSample.xy *= SSAO;
#endif

	ExtraSample.xy *= ExtraSample.xy;
	ExtraSample.xy *= 2.0f;

	OUT.naturalAmbientScale		= ExtraSample.x;
	OUT.artificialAmbientScale	= ExtraSample.y;

	OUT.emissiveIntensity = ExtraSample.z * 16.0f;

	UnPack2ZeroOneValuesToU8( ExtraSample.w, OUT.specularSkinBlend, OUT.reflectionIntensity );
	OUT.specularSkinBlend=1.-OUT.specularSkinBlend;

	OUT.reflectionColor = float3(0.0, 0.0, 0.0);

	return OUT;
}

DeferredSurfaceInfo UnPackGBuffer_S(float2 screenPos, float4 eyeRay, bool usetwiddle, uint sampleIndex)
{
	return UnPackGBuffer_S0(screenPos, eyeRay, usetwiddle, false, sampleIndex);
}

// ----------------------------------------------------------------------------------------------- //

float UnPackGBufferDepth(float2 screenPos, uint sampleIndex)
{
#if MULTISAMPLE_TECHNIQUES
	const int3 iPos = getIntCoords(screenPos, globalScreenSize.xy);
	float4 depthStencilSample = gbufferTextureDepthGlobal.Load(iPos, sampleIndex);
	float depthSample = depthStencilSample.x;
#else
	float4 depthStencilSample = tex2D(GBufferTextureSamplerDepthGlobal, screenPos.xy);
	float depthSample = depthStencilSample.x;
#endif // __XENON
	return	getLinearGBufferDepth(depthSample, deferredProjectionParams.zw);
}

// ----------------------------------------------------------------------------------------------- //

DeferredSurfaceInfo UnPackGBuffer(float2 vPos, int sampleIndex)
{
	float2 screenPos = convertToNormalizedScreenPos(vPos, deferredLightScreenSize);
	float4 eyeRay = GetEyeRay(screenPos.xy * 2.0f - float2(1,1));	
	return UnPackGBuffer_S(screenPos, eyeRay, false, sampleIndex);
}	

// ----------------------------------------------------------------------------------------------- //

DeferredSurfaceInfo UnPackGBuffer_P(float2 vPos, float4 eyeRay, bool usetwiddle, int sampleIndex )
{
	float2 screenPos = convertToNormalizedScreenPos(vPos, deferredLightScreenSize);
	return UnPackGBuffer_S(screenPos, eyeRay, usetwiddle, sampleIndex);
}	

// ----------------------------------------------------------------------------------------------- //
#endif //DEFERRED_UNPACK_LIGHT
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
#else //PC? - probably broken
// ----------------------------------------------------------------------------------------------- //
DeferredGBuffer PackGBuffer(float3 surface_worldNormal,
							StandardLightingProperties surfaceStandardLightingProperties, float alpha)
{
	DeferredGBuffer OUT;
	OUT.col0.rgba = 0;
	OUT.col1.rgba = 0;
	OUT.col2.rgba = 0;
	OUT.col3.rgba = 0;
	return OUT;
}

DeferredGBuffer PackGBuffer(float3 surface_worldNormal,
							StandardLightingProperties surfaceStandardLightingProperties)
{
	return PackGBuffer(surface_worldNormal, surfaceStandardLightingProperties, globalAlpha);
}

// ----------------------------------------------------------------------------------------------- //
#ifdef DEFERRED_UNPACK_LIGHT
// ----------------------------------------------------------------------------------------------- //
	float4 GetEyeRay(float2 signedScreenPos)
	{
		return float4(signedScreenPos,1,0);
	}

	DeferredSurfaceInfo UnPackGBuffer_S0(float2 screenPos, float4 eyeRay, bool usetwiddle, bool UnpackFoliageBit, uint sampleIndex)
	{
		DeferredSurfaceInfo OUT=(DeferredSurfaceInfo)0;
		OUT.diffuseColor=0;
		OUT.materialID=0;
		OUT.depth=0; 
		OUT.positionWorld=0;
		OUT.naturalAmbientScale=0;
		OUT.artificialAmbientScale=0;
		OUT.normalWorld.xyz=float3(0,0,1);				
		OUT.specularIntensity=0;
		OUT.specularExponent=0;
		OUT.rawD=0;
		OUT.eyeRay=float3(1,0,0);
		return OUT;
	}

	DeferredSurfaceInfo UnPackGBuffer_S(float2 screenPos, float4 eyeRay, bool usetwiddle, int sampleIndex)
	{
		return UnPackGBuffer_S0(screenPos, eyeRay, usetwiddle, false, sampleIndex);
	}

	DeferredSurfaceInfo UnPackGBuffer(float2 vPos)
	{
		return UnPackGBuffer_S(0, 0, false, 0);
	}
	DeferredSurfaceInfo UnPackGBuffer_P(float2 vPos, float4 pPos, bool usetwiddle, int sampleIndex)
	{
		return UnPackGBuffer_S(0, pPos, usetwiddle, sampleIndex);
	}

	float UnPackGBufferDepth(float2 screenPos, int sampleIndex)
	{
		return 0.0f;
	}

// ----------------------------------------------------------------------------------------------- //
#endif
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
#endif //PC? - probably broken
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
#endif//__GTA_LIGHTING_FXH__...
// ----------------------------------------------------------------------------------------------- //
