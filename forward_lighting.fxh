#ifndef __FORWARD_LIGHTING_INCLUDE
#define __FORWARD_LIGHTING_INCLUDE

// Include all light types (without techniques)
#define DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS 0

#include "lighting_common.fxh"
#include "lighting.fxh"

#include "Lights/light_common.fxh"
#include "Lights/spot.fxh"
#include "Lights/point.fxh"
#include "Lights/dir.fxh"

// ----------------------------------------------------------------------------------------------- //
// Define forward lighting functions
// ----------------------------------------------------------------------------------------------- //

void populateForwardLightingStructs(	
	inout surfaceProperties surface,
	inout materialProperties material,
	inout directionalLightProperties light,
	float3 positionWorld,
	float3 normalWorld,
	StandardLightingProperties surfaceLightingInfo)
{
	// Light properties
#if __MAX
	light.direction = -maxLightDirection;
	light.color		= maxLightDirectionColor.rgb * maxLightDirectionColor.a;
#else
	light.direction	= gDirectionalLight.xyz;
	light.color		= gDirectionalColour.rgb;
#endif

	// Surface properties
	surface.position = positionWorld;
	surface.normal = normalWorld;
	surface.lightDir = -light.direction;
	surface.sqrDistToLight = 0.0f;
	#if SPECULAR
		surface.eyeDir = normalize(gViewInverse[3].xyz - positionWorld);
		surface.halfVector = normalize(surface.eyeDir + surface.lightDir);
	#endif

	material = populateMaterialPropertiesForward(surfaceLightingInfo); // Setup all the material properties
}

// ----------------------------------------------------------------------------------------------- //
void calculateLocalLightContributionInternal(
	int numLights,
	bool bSupportCapsule,
	surfaceProperties surface,
	materialProperties material,
	Components components,
	bool diffuse,
	float diffuseMult,
	out float3 diffuseContrib
	#if SPECULAR
	, bool specular
	, float specularMult
	, float3 surfaceToEyeDir
	, out float3 specularContrib
	#endif // SPECULAR
	)
{
	diffuseContrib = float3(0.0, 0.0, 0.0);
#if SPECULAR
	specularContrib = float3(0.0, 0.0, 0.0);
#endif // SPECULAR

	LocalLightResult light =  CalculateLightingForward(
		numLights,
		diffuse, material.diffuseColor.rgb,
		#if SPECULAR
			specular, surfaceToEyeDir, material.specularExponent, material.fresnel,
		#endif
		surface.position, surface.normal
		#if GLASS_LIGHTING
			,material.diffuseColor.a
		#endif // GLASS_LIGHTING
		);

	diffuseContrib = light.diffuseLightContribution * diffuseMult * components.Kd;
	#if SPECULAR
		specularContrib = light.specularLightContribution * specularMult * components.Ks;
	#endif
}

float3 calculateLocalLightContribution(
	int numLights,
	bool bSupportCapsule,
	surfaceProperties surface,
	materialProperties material,
	Components components,
	bool diffuse,
	float diffuseMult
	#if SPECULAR
	, bool specular
	, float specularMult
	, float3 surfaceToEyeDir
	#endif
	)
{
	float3 diffuseContrib;
#if SPECULAR
		float3 specularContrib;
#endif // SPECULAR

	calculateLocalLightContributionInternal(
		  numLights 
		, bSupportCapsule
		, surface 
		, material
		, components
		, diffuse
		, diffuseMult
		, diffuseContrib
		#if SPECULAR
		, specular
		, specularMult
		, surfaceToEyeDir
		, specularContrib
		#endif // SPECULAR
	);

	float3 OUT;

	OUT = (diffuseContrib * components.Kd)
		#if SPECULAR
			+ (specularContrib * components.Ks)
		#endif // SPECULAR
		;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float4 calculateForwardLightingInternal(
	int numLights,
	bool bSupportCapsule,
	surfaceProperties surface,
	materialProperties material,
	directionalLightProperties light,
	bool diffuse,
	bool specular,
	bool reflection,
	bool directional,
		bool receiveShadows,
		bool receiveShadowsHighQuality,
		float2 screenPos,
	bool ambient,
		bool naturalAmbient,
		bool artificialExteriorAmbient,
		bool artificialInteriorAmbient,
		bool directionalAmbient,
	bool useBackLighting,
	bool useCloudShadows)
{
	LightingResult res;
	
	res = directionalCalculateLighting(
		surface, // surfaceProperties surface
		material,
		light,
		specular, // specular
		reflection, // reflection
		directional, // directional
			receiveShadows, // receiveShadows
				false, // receiveShadowsFast
				receiveShadowsHighQuality, // receiveShadowsHighQuality
			screenPos, // screenPos
			diffuse, // directionalDiffuse
			specular, // directionalSpecular
			useBackLighting, // useBackLighting
			false,		// scatter
			useCloudShadows);		// useHighQualityCloudShadows

	Components components;
	float4 OUT = ApplyLightToSurface(res, true, specular, reflection, components);

#if SPECULAR && defined(MIRROR_SHADER)
	if (reflection && !specular) // mirrors have reflection but no specular or fresnel, they still need to use material.specularIntensity
	{
		components.Kd = 1.0f - res.material.specularIntensity;
		components.Ks = res.material.specularIntensity;
	}
#endif // SPECULAR && defined(MIRROR_SHADER)

	OUT.rgb = OUT.rgb + calculateLocalLightContribution(
		numLights,
		bSupportCapsule,
		surface,
		material,
		components,
		diffuse,
		1.0f
		#if SPECULAR
		, specular
		, 1.0f
		, res.surface.eyeDir
		#endif
		);

	// Ambient contribution
	if (ambient) 
	{ 
		OUT.rgb = OUT.rgb + calculateAmbient(
			naturalAmbient,
			artificialExteriorAmbient,
			artificialInteriorAmbient,
			true,
			surface,
			material,
			components.Kd);
	}
	
	// Reflection contribution
	#if SPECULAR
	if (reflection) 
	{ 
		OUT.rgb = OUT.rgb + calculateReflection(
			surface.normal, 
			material, 
			res.surface.eyeDir, 
			1.0 - components.Kd,
			useBackLighting); 
	}
	#endif

	#if EMISSIVE
		OUT.rgb = OUT.rgb + material.diffuseColor.rgb * (material.emissiveIntensity * components.EdotN);
	#endif

    // changed to avoid 'temp register' compile error on x360
	//OUT.a *= globalAlpha * gInvColorExpBias;
    OUT.a = OUT.a * globalAlpha * gInvColorExpBias;

	return OUT;
}


// ----------------------------------------------------------------------------------------------- //

float4 calculateForwardLighting(
	int numLights,
	bool bSupportCapsule,
	surfaceProperties surface,
	materialProperties material,
	directionalLightProperties light,
	bool directional,
		bool directionalShadow,
		bool directionalShadowHighQuality,
	float2 screenPos)
{
	float4 OUT;

	#if defined(NO_FORWARD_AMBIENT_LIGHT)
		const bool ambient = false;
	#else
		const bool ambient = true;
	#endif

	#if defined(NO_FORWARD_DIRECTIONAL_LIGHT)
		directional = false;
	#endif

	#if defined(NO_FORWARD_LOCAL_DIFFUSE_LIGHT)
		const bool diffuse = false;
	#else
		const bool diffuse = true;
	#endif

	#if defined(NO_FORWARD_LOCAL_SPECULAR_LIGHT)
		const bool specular = false;
	#else
		const bool specular = true;
	#endif

	#if defined(MIRROR_FX)
		const bool reflection = true; // mirrors always need reflection even though they don't use specular
	#else
		const bool reflection = specular;
	#endif

	#if defined(NO_FORWARD_LOCAL_LIGHTS)
		const int totalNumLights = 0;
	#else
		const int totalNumLights = numLights;
	#endif

#if defined(USE_FORWARD_CLOUD_SHADOWS)
		const bool useCloudShadows = true;
#else
		const bool useCloudShadows = false;
#endif

	return calculateForwardLightingInternal(
		totalNumLights,
		bSupportCapsule,
		surface,
		material,
		light,
		diffuse, // diffuse
		specular, // specular
		reflection, // reflection
		directional, // directional
			directionalShadow, // receive shadows
			directionalShadowHighQuality, // receive shadows high quality
			screenPos, // screenPos
		ambient, // ambient
			true, // natural ambient
			true, // artificial exterior ambient
			true, // artificial interior ambient
			true, // directional ambient
		false,	// useBackLighting
		useCloudShadows); //useHighQualityCloudShadows
}

// ----------------------------------------------------------------------------------------------- //
// Forward lighting that is based on vertex shader light values
// ----------------------------------------------------------------------------------------------- //

float4 calculateForwardLightingSimple(
	float3 lightDiffuse,
	float3 lightSpecular,
	float3 lightAmbientEmissive,
	float4 matDiffuse
	)
{
	// Apply directional lighting
	half4 OUT = ApplyLightToBRDF(lightDiffuse, lightSpecular, matDiffuse, true, true);

	// Ambient and emissive
	// This is not exactly the same as the pixel shader version as the ambient color is fully multiplied by the material diffuse color in this version
	OUT.rgb += lightAmbientEmissive * matDiffuse.rgb;
	
	// Take global alpha modifications into account
	OUT.a *= globalAlpha * gInvColorExpBias;
	
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float4 calculateForwardLighting_DynamicReflection(
	surfaceProperties surface,
	materialProperties material,
	directionalLightProperties light)
{
	ApplyReflectionTweaks(material, light, surface);

	LightingResult res;

	res = directionalCalculateLighting(
		surface, // surfaceProperties surface
		material,
		light,
		false, // specular
		false, // reflection
		true, // directional
				false, // receiveShadows
				false, // receiveShadowsFast
				false, // receiveshadowsHighQuality
			float2(0.0, 0.0), // screenPos
			true, // directionalDiffuse
			false, // directionalSpecular
			false, // useBackLighting
			false,		// scatter
			false);		// useCloudShadows

	// HACK: Reduce directional light by the natural ambient scale so that interiors aren't lit. 
	// Can remove once we get per vertex lighting in?
	res.lightAttenuation *= material.naturalAmbientScale;

	Components components;

	float4 OUT = ApplyLightToSurfaceFast(
		res,
		true, // diffuse
		false, //specular
		false, // reflection
		components);

	// Ambient contribution
	OUT.rgb += calculateAmbient(
		true, // naturalAmb
		true, // artificialExteriorAmb
		true, // artificialInteriorAmb
		true, // directionalAmb
		surface, 
		material,
		components.Kd); 

	#if EMISSIVE
		OUT.rgb += material.diffuseColor.rgb * (material.emissiveIntensity * components.EdotN);
	#endif

	OUT.a *= globalAlpha * gInvColorExpBias;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float4 calculateForwardLighting_WaterReflection(
	surfaceProperties surface,
	materialProperties material,
	directionalLightProperties light,
	float ambientScale,
	float directionalScale,
	bool directionalShadow)
{
	LightingResult res;

	res = directionalCalculateLighting(
		surface, // surfaceProperties surface
		material,
		light,
		false, // specular
		false, // reflection
		true, // directional
			directionalShadow, // receiveShadows
				true, // receiveShadowsFast
				false, // receiveshadowsHighQuality
			float2(0.0, 0.0), // screenPos
			true, // directionalDiffuse
			false, // directionalSpecular
			false, // useBackLighting
			false,		// scatter
			false);		// useCloudShadows

	Components components;
	float4 OUT = directionalScale*ApplyLightToSurfaceFast(
		res,
		true, // diffuse
		false, // specular
		false, // reflection
		components);

	// Ambient contribution
	OUT.rgb += ambientScale*calculateAmbient(
		true, // naturalAmb
		true, // artificialExteriorAmb
		true, // artificialInteriorAmb (required for vbca tunnels .. this adds 2 cycles to normal_spec/PS_TexturedWaterReflection)
		true, // directionalAmb
		surface, 
		material,
		components.Kd); 

#if EMISSIVE
	OUT.rgb += material.diffuseColor.rgb * (material.emissiveIntensity * gReflectionTweakEmissive);
#endif

	OUT.a *= globalAlpha * gInvColorExpBias;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float4 calculateForwardLighting_Cable(
	surfaceProperties surface,
	materialProperties material,
	directionalLightProperties light,
	bool interiorAmbient,
	bool exteriorAmbient,
	bool directionalShadow)
{
	LightingResult res;

	res = directionalCalculateLighting(
		surface, // surfaceProperties surface
		material,
		light,
		false, // specular
		false, // reflection
		true, // directional
		directionalShadow, // receiveShadows
		true, // receiveShadowsFast
		false, // receiveshadowsHighQuality
		float2(0.0, 0.0), // screenPos
		true, // directionalDiffuse
		false, // directionalSpecular
		false, // useBackLighting
		false,		// scatter
		false);		// useCloudShadows

	Components components;
	float4 OUT = ApplyLightToSurfaceFast(
		res,
		true, // diffuse
		false, // specular
		false, // reflection
		components);

	// Ambient contribution
	OUT.rgb += calculateAmbient(
		true, // naturalAmb
		interiorAmbient, // artificialExteriorAmb
		exteriorAmbient, // artificialInteriorAmb
		true, // directionalAmb
		surface, 
		material,
		components.Kd); 

#if EMISSIVE
	OUT.rgb += material.diffuseColor.rgb * (material.emissiveIntensity * components.EdotN);
#endif

	OUT.a *= globalAlpha * gInvColorExpBias;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

void calculateParticleForwardLighting(
	int numLights,
	bool bSupportCapsule,
	surfaceProperties surface,
	materialProperties material,
	directionalLightProperties light,
	float lightAttenuation,
	float localDiffuseMult,
	out float3 directionalLight, 
	out float3 restOfTheLight)
{
	LightingResult res;

	res = directionalCalculateLighting(
		surface, // surfaceProperties surface
		material,
		light,
		false, // specular
		false, // reflection
		true, // directional
			false, // receiveShadows
				false, // receiveShadowsFast
				false, // receiveshadowsHighQuality
			float2(0.0, 0.0), // screenPos
			true, // directionalDiffuse
			false, // directionalSpecular
			false, // useBackLighting
			false,		// scatter
			false);		// useCloudShadows

	res.lightAttenuation *= lightAttenuation;

	Components components;
	directionalLight = ApplyLightToSurfaceFast(res, true, false, false, components).rgb;

	restOfTheLight = calculateLocalLightContribution(
		numLights,
		bSupportCapsule,
		surface, 
		material,
		components, 
		true, 
		localDiffuseMult
		#if SPECULAR
		, false
		, 1.0f
		, res.surface.eyeDir
		#endif
		);

	// Ambient contribution
	restOfTheLight += calculateAmbient(
		true, 
		true, 
		true, 
		true, 
		surface, 
		material,
		components.Kd); 
}

// ----------------------------------------------------------------------------------------------- //

#endif
