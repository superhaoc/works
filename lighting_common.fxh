#ifndef __LIGHTING_COMMON
#define __LIGHTING_COMMON

// =============================================================================================== //
// DEFINES
// =============================================================================================== //

#ifndef SELF_SHADOW
	#if defined(NO_SELF_SHADOW) || __MAX
		#define SELF_SHADOW 0
	#else
		#define SELF_SHADOW 1
	#endif
#endif

#ifndef USE_WRAP_LIGHTING
	#define WRAP_LIGHTING (0)
#else
	#define WRAP_LIGHTING (1)
#endif 

#ifndef HALF_PRECISION_LIGHT_STRUCTS
	#define ENABLE_LIGHTING_HALF 0
#else
	#define ENABLE_LIGHTING_HALF 1
#endif

#if ENABLE_LIGHTING_HALF
	#define LFLOAT half
	#define LFLOAT2 half2
	#define LFLOAT3 half3
	#define LFLOAT4 half4
	#define LFLOAT3x3 half3x3
	#define LFLOAT4x4 half4x4
#else
	#define LFLOAT float
	#define LFLOAT2 float2
	#define LFLOAT3 float3
	#define LFLOAT4 float4
	#define LFLOAT3x3 float3x3
	#define LFLOAT4x4 float4x4
#endif

// =============================================================================================== //
// STRUCTS
// =============================================================================================== //

struct directionalLightProperties
{
	LFLOAT3 direction;
	LFLOAT3 color;
};

// ----------------------------------------------------------------------------------------------- //


struct StandardLightingProperties
{
	LFLOAT4 diffuseColor;

	LFLOAT naturalAmbientScale;
	LFLOAT artificialAmbientScale;

	LFLOAT inInterior;

#if SPECULAR
	LFLOAT specularSkin;
	LFLOAT reflectionIntensity;
	LFLOAT specularIntensity;
	LFLOAT specularExponent;
	LFLOAT fresnel;
#endif	// SPECULAR	

#if REFLECT
	LFLOAT3 reflectionColor;
#endif	// REFLECT

	LFLOAT emissiveIntensity;

#if SELF_SHADOW
	LFLOAT selfShadow;
#endif // SELF_SHADOW
#if USE_SLOPE
	LFLOAT slope;
#endif

#if WETNESS_MULTIPLIER
	LFLOAT wetnessMult;
#endif
};

// ----------------------------------------------------------------------------------------------- //

struct DeferredSurfaceInfo
{
	LFLOAT3 positionWorld;

#ifdef DECAL_USE_NORMAL_MAP_ALPHA
	LFLOAT4 normalWorld;
#else
	LFLOAT3 normalWorld;
#endif
	LFLOAT3 diffuseColor;
	LFLOAT naturalAmbientScale;
	LFLOAT artificialAmbientScale;

	LFLOAT specularIntensity;
	LFLOAT specularExponent;
	LFLOAT3 reflectionColor; 
	LFLOAT3 eyeRay; 

	LFLOAT fresnel;	

	LFLOAT materialID;
	LFLOAT inInterior;

	LFLOAT depth;
	LFLOAT rawD;

	LFLOAT specularSkinBlend;
	LFLOAT reflectionIntensity;

	LFLOAT emissiveIntensity;
	LFLOAT selfShadow;
#if USE_SLOPE
	LFLOAT slope;
#endif
	bool   bIsGrass;	// backlit pass only: true=grass, false=tree
};

// ----------------------------------------------------------------------------------------------- //

struct LocalLightResult
{
	LFLOAT3 diffuseLightContribution;
	LFLOAT3 specularLightContribution;
};

// ----------------------------------------------------------------------------------------------- //
// PROPERTY STRUCTURES
// ----------------------------------------------------------------------------------------------- //

struct materialProperties
{
	LFLOAT ID;
	float4 diffuseColor;
#if SPECULAR
	LFLOAT skinBlend;
	LFLOAT reflectionIntensity;
	LFLOAT specularIntensity;
	LFLOAT specularExponent;
	LFLOAT fresnel;
#endif // SPECULAR
#if REFLECT
	LFLOAT3 reflectionColor;
#endif // REFLECT
	LFLOAT naturalAmbientScale;
	LFLOAT artificialAmbientScale;
	LFLOAT inInterior;
	LFLOAT emissiveIntensity;
#if SELF_SHADOW
	LFLOAT selfShadow;
#endif // SELF_SHADOW
};

// ----------------------------------------------------------------------------------------------- //

materialProperties populateMaterialPropertiesDeferred(DeferredSurfaceInfo surfaceInfo)
{
	materialProperties OUT;

	OUT.ID = surfaceInfo.materialID;
	OUT.diffuseColor = float4(surfaceInfo.diffuseColor, 1.0);
#if SPECULAR
	OUT.skinBlend = surfaceInfo.specularSkinBlend;		
	OUT.reflectionIntensity = surfaceInfo.reflectionIntensity;
	OUT.specularIntensity = saturate(surfaceInfo.specularIntensity);
	OUT.specularExponent = surfaceInfo.specularExponent;
	OUT.fresnel = surfaceInfo.fresnel;
#endif // SPECULAR
#if REFLECT
	OUT.reflectionColor = surfaceInfo.reflectionColor;
#endif // REFLECT
	OUT.naturalAmbientScale = surfaceInfo.naturalAmbientScale;
	OUT.artificialAmbientScale = surfaceInfo.artificialAmbientScale;
	OUT.emissiveIntensity = surfaceInfo.emissiveIntensity;
	OUT.inInterior = surfaceInfo.inInterior;
#if SELF_SHADOW
	OUT.selfShadow = surfaceInfo.selfShadow;
#endif // SELF_SHADOW

	OUT.naturalAmbientScale *= OUT.naturalAmbientScale;
	OUT.artificialAmbientScale *= OUT.artificialAmbientScale;

#if SPECULAR
	// Adjust range (0..512 -> 0..500 = 0..1500 and 501-512 = 1500-8192)
	const float expandRange = max(0.0, OUT.specularExponent - 500);
	OUT.specularExponent = (OUT.specularExponent - expandRange) * 3.0f + expandRange * 558.0f;
#endif // SPECULAR

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

materialProperties populateMaterialPropertiesForward(StandardLightingProperties surfaceLightingInfo)
{
	materialProperties OUT;

	OUT.ID = -1.0;
	OUT.diffuseColor = surfaceLightingInfo.diffuseColor;
#if SPECULAR
	OUT.skinBlend = surfaceLightingInfo.specularSkin;
	OUT.reflectionIntensity = 1.0f;
	OUT.specularIntensity = saturate(surfaceLightingInfo.specularIntensity);
	OUT.specularExponent = surfaceLightingInfo.specularExponent;
	OUT.fresnel = surfaceLightingInfo.fresnel;
#endif // SPECULAR
#if REFLECT
	OUT.reflectionColor = surfaceLightingInfo.reflectionColor;
#endif // REFLECT
	OUT.naturalAmbientScale = surfaceLightingInfo.naturalAmbientScale;
	OUT.artificialAmbientScale = surfaceLightingInfo.artificialAmbientScale;
	OUT.inInterior = surfaceLightingInfo.inInterior;
	OUT.emissiveIntensity = surfaceLightingInfo.emissiveIntensity;
#if SELF_SHADOW
	OUT.selfShadow = surfaceLightingInfo.selfShadow;
#endif // SELF_SHADOW

	OUT.naturalAmbientScale *= OUT.naturalAmbientScale;
	OUT.artificialAmbientScale *= OUT.artificialAmbientScale;

#if SPECULAR
	// Adjust range (0..512 -> 0..500 = 0..1500 and 501-512 = 1500-8192)
	const float expandRange = max(0.0, OUT.specularExponent - 500);
	OUT.specularExponent = (OUT.specularExponent - expandRange) * 3.0f + expandRange * 558.0f;
#endif // SPECULAR

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

struct surfaceProperties
{
	float3 position;
	float3 normal;
	#if SPECULAR
		float3 eyeDir;
		float3 halfVector;
	#endif
	float3 lightDir;
	float sqrDistToLight;
};

// ----------------------------------------------------------------------------------------------- //

struct lightProperties
{
	float3 position;
	float3 direction;
	float3 tangent;
	float3 colour;
	float intensity;
	float radius;
	float invSqrRadius;
	float extraRadius;
	float4 cullingPlane;
	float falloffExponent;

	// Fades
	float shadowFade;
	float specularFade;
	float textureFade;

	// Vehicle
	float3 vehicleHeadTwinPos1;
	float3 vehicleHeadTwinPos2;
	float3 vehicleHeadTwinDir1;
	float3 vehicleHeadTwinDir2;

	// Textured
	float textureFlipped;

	// Spot
	float spotCosOuterAngle;
	float spotSinOuterAngle;
	float spotOffset;
	float spotScale;

	// Capsule
	float capsuleExtent;
};

// ----------------------------------------------------------------------------------------------- //

surfaceProperties populateSurfaceProperties(DeferredSurfaceInfo surfaceInfo, float3 lightDir, float sqrDistToLight)
{
	surfaceProperties OUT;

	OUT.position = surfaceInfo.positionWorld;
	OUT.normal = surfaceInfo.normalWorld.xyz;
	OUT.lightDir = lightDir;
	OUT.sqrDistToLight = sqrDistToLight;
	#if SPECULAR
		OUT.eyeDir = -normalize(surfaceInfo.eyeRay);
		OUT.halfVector = normalize(OUT.eyeDir + OUT.lightDir);
	#endif

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

struct LightingResult
{
	materialProperties material;
	surfaceProperties surface;
	float3 lightColor;
	float lightAttenuation;
	float shadowAmount;
	float backLightingAdjust;
};

// ----------------------------------------------------------------------------------------------- //

struct Components
{
	float Kd;
	float Ks;
	float NdotL;
	float EdotN;
};

// =============================================================================================== //
// FUNCTIONS
// =============================================================================================== //

LightingResult storeLightingResults(
	materialProperties material, 
	surfaceProperties surface,
	float3 lightColor,
	float lightAttenuation,
	float shadowAmount,
	float backLightingAdjust)
{
	LightingResult OUT;

	OUT.material = material;
	OUT.surface = surface;
	OUT.lightColor = lightColor;
	OUT.lightAttenuation = lightAttenuation;
	OUT.shadowAmount = shadowAmount;
	OUT.backLightingAdjust = backLightingAdjust;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float calculateBlinnPhong(float3 surfaceNormal, float3 halfVector, float specularExponent)
{
	return pow(saturate(dot(surfaceNormal, halfVector) + 1e-8f), specularExponent + 1e-8f);
}

// ----------------------------------------------------------------------------------------------- //

float calculateDiffuse(float3 surfaceNormal, float3 surfaceToLightDir)
{
#if WRAP_LIGHTING
	float NdotL = saturate(dot(surfaceNormal, surfaceToLightDir));
	return saturate((NdotL + wrapLigthtingTerm) / ((1 + wrapLigthtingTerm) * (1 + wrapLigthtingTerm)));
#else
	return saturate(dot(surfaceNormal, surfaceToLightDir));
#endif
}

// ----------------------------------------------------------------------------------------------- //

float distanceFalloff(float distSqr, float invMaxDistSqr, float exponent)
{
	return __powapprox(saturate(1.0f - distSqr * invMaxDistSqr), exponent);
}
// ----------------------------------------------------------------------------------------------- //

float4 distanceFalloff(float4 distSqr, float invMaxDistSqr, float exponent)
{
	return __powapprox(saturate(1.0f.xxxx - distSqr * invMaxDistSqr.xxxx), exponent.xxxx);
}

// ----------------------------------------------------------------------------------------------- //

float angularFalloff(float angle, float lightConeScale, float lightConeOffset)
{
	return saturate((angle * lightConeScale) + lightConeOffset);
}
// ----------------------------------------------------------------------------------------------- //

float4 angularFalloff(float4 angle, float lightConeScale, float lightConeOffset)
{
	return saturate((angle * lightConeScale.xxxx) + lightConeOffset.xxxx);
}

// ----------------------------------------------------------------------------------------------- //

float3 calculateAmbient(
	bool naturalAmb,
	bool artificialExteriorAmb,
	bool artificialInteriorAmb,
	bool directionalAmb,
	surfaceProperties surface,
	materialProperties material,
	float Kd)
{
	// Add in reflections
	float3 environmentalAmbient = float3(0.0, 0.0, 0.0);
	float3 naturalDirAmbient = float3(0.0, 0.0, 0.0);

	// Ambient lighting
	const float downMult = max(0.0, (surface.normal.z + ambientDownWrap) * ooOnePlusAmbientDownWrap);

	if (artificialInteriorAmb || artificialExteriorAmb)
	{
		if (artificialExteriorAmb && !artificialInteriorAmb) 
		{
			environmentalAmbient += artificialExteriorAmbient(downMult);
		}

		if (artificialInteriorAmb && !artificialExteriorAmb) 
		{
			environmentalAmbient += artificialInteriorAmbient(downMult);
		}

		if (artificialInteriorAmb && artificialExteriorAmb)
		{
			environmentalAmbient += 
				artificialExteriorAmbient(downMult) *
				(1.0 - material.inInterior); 

			environmentalAmbient += 
				artificialInteriorAmbient(downMult) *
				material.inInterior;
		}
		
		environmentalAmbient *= material.artificialAmbientScale;
	}
	
	if (naturalAmb || directionalAmb)
	{
		if (naturalAmb) 
		{ 
			naturalDirAmbient += naturalAmbient(downMult); 
		}

		if (directionalAmb)
		{
			float dotProd = saturate(dot(directionalAmbientDirection, surface.normal));

			naturalDirAmbient += gDirectionalAmbientColour.rgb * dotProd;
		}
		
		naturalDirAmbient *= material.naturalAmbientScale;
	}

	return (naturalDirAmbient + environmentalAmbient) * Kd * material.diffuseColor.rgb;
}

// ----------------------------------------------------------------------------------------------- //

float3 calculateReflection(
	float3 surfaceNormal,
	materialProperties material,
	float3 surfaceToEyeDir,
	float Kr,
	bool useBackLighting)
{
#if REFLECT 
	float3 reflectedLight = material.reflectionColor;
#else
	float3 reflectedLight = float3(0.0, 0.0, 0.0);
#endif

#if REFLECT && REFLECT_DYNAMIC
	// Calculate reflection
	const float3 eyeToSurfaceDir = -surfaceToEyeDir;
	reflectedLight = calcReflection(ReflectionSampler, eyeToSurfaceDir, surfaceNormal, material.specularExponent);
	if (!useBackLighting)
	{
		reflectedLight  *=material.reflectionIntensity*material.reflectionIntensity;		
	}
#endif

	// Tweak the environmental reflection
#if REFLECT && !REFLECT_MIRROR
	reflectedLight *= max(material.naturalAmbientScale, material.artificialAmbientScale);
	#if SPECULAR
		reflectedLight = lerp(
			reflectedLight / PI, 
			reflectedLight, 
			saturate(material.specularExponent / 563.0f));
	#endif
#endif

	return reflectedLight * Kr;
}

// ----------------------------------------------------------------------------------------------- //

void ApplyReflectionTweaks(inout materialProperties material, inout directionalLightProperties light, inout surfaceProperties surface)
{
#if !__MAX
	// Reflection tweaks
	float directionalMult = material.naturalAmbientScale * material.naturalAmbientScale * gReflectionTweakDirectional;
	light.color *= directionalMult;

	material.emissiveIntensity *= gReflectionTweakEmissive;

	float3 surfaceToEye = gViewInverse[3].xyz - surface.position;

	float3 surfaceToEyeDir;
	#if SPECULAR
		surfaceToEyeDir = surface.eyeDir;
	#else
		surfaceToEyeDir = normalize(surfaceToEye);
	#endif
	
	float dotVec = dot(surfaceToEye.xy, surfaceToEye.xy);
	float3 emissiveDistFade = saturate((dotVec - 100.0f) * 0.0001);

	float mult = saturate(saturate(dot(gReflectionTweaksCameraDir.xy, surfaceToEyeDir.xy)) + emissiveDistFade);
	material.emissiveIntensity *= mult;
#endif
}

// ----------------------------------------------------------------------------------------------- //

/*
float3 intersectRaySphere(float3 origin, float3 dir, float4 sphere, float maxT)
{
	float3 O = origin - sphere.xyz;
	float3 D = dir;

	float C =  dot(O,O) - sphere.w;
	float B = dot(O, D);
	float disc = B * B - C;
	float t0, t1;
	t0 = t1 = maxT;
	if ( disc > 0.0f )
	{
		float r = sqrt(disc);
		t0 = -(r+B); 
		t1 =  (r-B);
	}

	t1 = min(t1, maxT);
	t0 = max(t0, 0.0f);

	return float3(t0, t1, disc);
}
*/

// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //

float4 GetDistSquared4(float4 vecX, float4 vecY, float4 vecZ)
{
	float4 OUT;
	OUT = vecX * vecX;
	OUT = (vecY * vecY) + OUT;
	OUT = (vecZ * vecZ) + OUT;
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float4 Dot41(float4 vecX, float4 vecY, float4 vecZ, float3 vec)
{
	float4 OUT;
	OUT = vecX * vec.xxxx;
	OUT = (vecY * vec.yyyy) + OUT;
	OUT = (vecZ * vec.zzzz) + OUT;
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float4 Dot44(float4 vec0X, float4 vec0Y, float4 vec0Z, float4 vec1X, float4 vec1Y, float4 vec1Z)
{
	float4 OUT;
	OUT =  vec0X * vec1X;
	OUT = (vec0Y * vec1Y) + OUT;
	OUT = (vec0Z * vec1Z) + OUT;
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //
#if __SHADERMODEL >= 40
// ----------------------------------------------------------------------------------------------- //

LocalLightResult CalculateLightingForward(
	int maxLights,
	bool diffuse, float3 diffuseColour,
	#if SPECULAR
		bool specular, float3 surfaceToEyeDir, float specularExponent, float fresnel,
	#endif
	float3 surfacePosition, float3 surfaceNormal
	#if GLASS_LIGHTING
		, float diffuseAlpha
	#endif // GLASS_LIGHTING
	)
{
	LocalLightResult OUT;
	OUT.specularLightContribution = 0.0.xxx;
	OUT.diffuseLightContribution  = 0.0.xxx;

	[unroll]
	for (int i = 0; i < maxLights; i++)
	{
		#if __SHADERMODEL >= 40
		if (i >= gNumForwardLights)
			break;
		#endif

		float3 surfaceToLight = float3(0.0f, 0.0f, 0.0f);

		if (gLightColourAndCapsuleExtent[i].w == 0.0f)
		{
			surfaceToLight = gLightPositionAndInvDistSqr[i].xyz - surfacePosition;
		}
		else
		{
			// Update light position for capsule lights
			float3 ap = surfacePosition - gLightPositionAndInvDistSqr[i].xyz;
			float ap_dir = dot(ap, gLightDirectionAndFalloffExponent[i].xyz);
			float t = gLightColourAndCapsuleExtent[i].w * saturate(ap_dir / (gLightColourAndCapsuleExtent[i].w + EPSILON));

			// Calculate direction from the surface to the light source
			surfaceToLight = (gLightPositionAndInvDistSqr[i].xyz + gLightDirectionAndFalloffExponent[i].xyz * t) - surfacePosition;
		}

		float surfaceToLightDistSqr = dot(surfaceToLight, surfaceToLight);		
		float3 surfaceToLightDir = normalize(surfaceToLight + 1.e-6.xxx);
		float3 lightToWorldDir = gLightDirectionAndFalloffExponent[i].xyz;

		float distanceAttenuation = distanceFalloff(
			surfaceToLightDistSqr, 
			gLightPositionAndInvDistSqr[i].w, 
			gLightDirectionAndFalloffExponent[i].w);

		float angularAttenuation = angularFalloff(
			dot(surfaceToLightDir, -lightToWorldDir), 
			gLightConeScale[i], 
			gLightConeOffset[i]);

		float cosTheta = dot(surfaceToLightDir, surfaceNormal);

		#if GLASS_LIGHTING
			cosTheta = lerp(abs(cosTheta), saturate(cosTheta), diffuseAlpha);
		#else
			cosTheta = saturate(cosTheta);
		#endif // GLASS_LIGHTING

		#if WRAP_LIGHTING
			float4 diffNdotL = saturate((cosTheta + wrapLigthtingTerm) / ((1 + wrapLigthtingTerm) * (1 + wrapLigthtingTerm)));
			float4 specNdotL = cosTheta;
		#else
			float4 diffNdotL = cosTheta;
			float4 specNdotL = cosTheta;
		#endif
#if defined(FORWARD_LOCAL_LIGHT_SHADOWING)
		float shadowAmount = CalcForwardLocalLightShadowShadow(surfacePosition,i);
#else 
		float shadowAmount = 1.0;
#endif
		// Diffuse Attenuation
		if (diffuse)
		{
			float4 lightDiffuse = shadowAmount * diffNdotL * angularAttenuation * distanceAttenuation;
			OUT.diffuseLightContribution += lightDiffuse * gLightColourAndCapsuleExtent[i].rgb * diffuseColour;	
		}

		#if SPECULAR
		// Blinn-phong attentuation
		if (specular)
		{
			const float3 H = normalize(surfaceToEyeDir + surfaceToLightDir);

			// Specular Fresnel
			
			float HdotL = saturate(dot(H, surfaceToEyeDir));
			float specFresnel = (1.0f - fresnel) + fresnel * pow(1.0 - HdotL, 5.0);

			// Blinn phong
			const float HdotN = saturate(dot(H, surfaceNormal));
			const float blinnPhong = pow(HdotN, specularExponent + 1e-8f);
			const float specNormalisation = (2.0 + specularExponent) / 8.0;

			float lightSpecular = shadowAmount * (specFresnel * blinnPhong) * (specNdotL * angularAttenuation) * distanceAttenuation * specNormalisation;

			OUT.specularLightContribution += lightSpecular * gLightColourAndCapsuleExtent[i];
		}
		#else
			OUT.specularLightContribution = float3(0.0, 0.0, 0.0);
		#endif
	}

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //
#else
// ----------------------------------------------------------------------------------------------- //

LocalLightResult CalculateLightingForward(
	int maxLights,
	bool diffuse, float3 diffuseColour,
#if SPECULAR
	bool specular, float3 surfaceToEyeDir, float specularExponent, float fresnel,
#endif
	float3 surfacePosition, float3 surfaceNormal
#if GLASS_LIGHTING
	, float diffuseAlpha
#endif // GLASS_LIGHTING
	)
{
	LocalLightResult OUT;
	OUT.specularLightContribution = 0.0.xxx;
	OUT.diffuseLightContribution  = 0.0.xxx;
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //
#endif
// ----------------------------------------------------------------------------------------------- //

float3 calculateTangent(float3 dir)
{
	// Pick an axis to start that is the most different from the direction 
	float3 absDir = abs(dir);
	float3 xyz_CmpLT_yzx = absDir.xyz < absDir.yzx;
	float3 xyz_CmpLE_zxy = absDir.xyz <= absDir.zxy;

	float3 a = xyz_CmpLT_yzx * xyz_CmpLE_zxy;
	a.x += any(a) ? 0.0f : 1.0f;

	// calculate a proper tangent 
	float3 binormal = normalize(cross(dir, a));
	float3 tangent = cross(binormal, dir);
	return tangent;
}


#endif
