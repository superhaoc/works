#ifndef __CAPSULE_INCLUDE
#define __CAPSULE_INCLUDE

// =============================================================================================== //
// INCLUDES
// =============================================================================================== //

#include "../lighting_common.fxh"
#include "light_common.fxh"

#if !defined(EXCLUDE_LIGHT_TECHNIQUES) 
	#define EXCLUDE_LIGHT_TECHNIQUES 1
		#include "point.fxh"
	#undef EXCLUDE_LIGHT_TECHNIQUES
#else
	#include "point.fxh"
#endif

// =============================================================================================== //
// DEFINES
// =============================================================================================== //

#ifndef LTYPE
#define LTYPE capsule
#endif

// =============================================================================================== //
// TECHNIQUE FUNCTIONS
// =============================================================================================== //

float JOIN(LTYPE,CalcAttenuation)(	
	float	surfaceToLightDistSqr,
	float	lightInvSqrFalloffDist,
	float	lightFalloffExponent,
	float	currentPosition,
	float4	cullPlane) //adding this parameter so that it matches point lights
{
	return distanceFalloff(surfaceToLightDistSqr, lightInvSqrFalloffDist, lightFalloffExponent);
}

float4 JOIN(LTYPE,CalcAttenuation)(	
								  float4	surfaceToLightDistSqr,
								  float	lightInvSqrFalloffDist,
								  float	lightFalloffExponent,
								  float4	surfacePositionX,
								  float4	surfacePositionY,
								  float4	surfacePositionZ,
								  float4	cullPlane) //adding this parameter so that it matches point lights
{
	return distanceFalloff(surfaceToLightDistSqr, lightInvSqrFalloffDist, lightFalloffExponent);
}

// ----------------------------------------------------------------------------------------------- //
#if DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS
// ----------------------------------------------------------------------------------------------- //

LightingResult JOIN(LTYPE,CalculateDeferredLighting)(
	inout surfaceProperties surface,
	materialProperties material,
	lightProperties light,
	bool useShadow, 
	bool useFiller, 
	bool useInterior, 
	bool useExterior, 
	bool useTexture,
	half3 shadowTexCoords,
	float2 screenPos,
	bool softShadow,
	bool clipAttenuatedPixels,
	bool useAlternateAttenuation,
	float alternateAttenuation)
{
	// Calculate closest point on line
	float3 P = surface.position;
	float3 AP = P - light.position;
	float ap_dir = dot(AP, light.direction);
	float t = light.capsuleExtent * saturate(ap_dir / light.capsuleExtent);

	float3 closest = light.position + light.direction * t;

	float3 surfaceToLight = (closest - surface.position);

	surface.lightDir = normalize(surfaceToLight);
	surface.sqrDistToLight = dot(surfaceToLight, surfaceToLight);
	#if SPECULAR
		surface.halfVector = normalize(surface.eyeDir + surface.lightDir);
	#endif

	// TODO: Just use the point light at this particular point on the screen.
	LightingResult OUT;
	OUT = pointCMCalculateDeferredLighting(surface, material, light, false, useFiller, useInterior, useExterior, false, shadowTexCoords, screenPos, softShadow, clipAttenuatedPixels, useAlternateAttenuation, alternateAttenuation);
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float3 JOIN(pos_,LTYPE)(float3 pos, lightProperties light, bool useShadow, bool useTexture, bool useVolume)
{
	pos = normalize(pos.xyz);
	
	if (useVolume) // don't extend light radius, since we do some calculations per-vertex
	{
		pos *= light.radius;
	}
	else
	{
		pos *= (light.radius + light.extraRadius);
	}

	float halfCapsuleExtent = light.capsuleExtent * 0.5;
	if (pos.x < 0.0) pos.x -= halfCapsuleExtent;
	if (pos.x > 0.0) pos.x += halfCapsuleExtent;

	float3x3 mat;
	mat[0].xyz = light.direction;
	mat[2].xyz = normalize(cross(light.direction, light.tangent));
	mat[1].xyz = cross(mat[2], mat[0]);

	float3 vpos = mul(pos, mat);

	vpos += light.position + light.direction * halfCapsuleExtent;

	return vpos;
}

// ----------------------------------------------------------------------------------------------- //

void JOIN(volume_,LTYPE)(inout lightVolumeData volumeData, lightProperties light, float3 pos, float3 inpos_unused, bool outsideVolume_unused)
{
	volumeData.gradient = light.colour;
	volumeData.intersect = float4(0.0, 1e-6, 0.0, 0.0);
}

// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
// INSTANCED
// ----------------------------------------------------------------------------------------------- //

struct JOIN(LTYPE,InstancedVertexInput)
{
	half4 pos							: POSITION;

	float4 positionAndRadius			: TEXCOORD0;
	float4 directionAndFalloffExponent	: TEXCOORD1;
	float2 capsuleExtentsAndIntensity	: TEXCOORD2;
	float4 colour						: COLOR0;
};

struct JOIN(LTYPE,InstancedVertexOutput)
{
	DECLARE_POSITION(pos)

	#if MULTISAMPLE_TECHNIQUES
		inside_sample float4 screenPos	: TEXCOORD0;
	#else
		float4 screenPos				: TEXCOORD0;
	#endif
	float4 eyeRay						: TEXCOORD1;

	float4 positionAndRadius			: TEXCOORD2;
	float4 directionAndFalloffExponent	: TEXCOORD3;
	float2 capsuleExtentsAndIntensity	: TEXCOORD4;
	float4 colour						: COLOR0;
};

// ----------------------------------------------------------------------------------------------- //

lightProperties JOIN(PopulateLightPropertiesInstanced,LTYPE)(JOIN(LTYPE,InstancedVertexOutput) IN)
{
	lightProperties OUT;

	OUT.position = IN.positionAndRadius.xyz;
	OUT.direction = IN.directionAndFalloffExponent.xyz;
	OUT.tangent = calculateTangent(OUT.direction);
	OUT.colour = IN.colour;
	OUT.intensity = IN.capsuleExtentsAndIntensity.y;
	OUT.radius = IN.positionAndRadius.w;
	OUT.invSqrRadius = 1.0f / (OUT.radius * OUT.radius);
	OUT.extraRadius = 0.029f;
	OUT.cullingPlane = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.falloffExponent = IN.directionAndFalloffExponent.w;

	// Fades
	OUT.shadowFade = 1.0f;
	OUT.specularFade = 1.0f;
	OUT.textureFade = 1.0f;

	// Vehicle
	OUT.vehicleHeadTwinPos1 = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.vehicleHeadTwinPos2  = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.vehicleHeadTwinDir1 = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.vehicleHeadTwinDir2  = float4(0.0f, 0.0f, 0.0f, 0.0f);

	// Textured
	OUT.textureFlipped = 0.0f;

	// Spot
	OUT.spotCosOuterAngle = 0.0f;
	OUT.spotSinOuterAngle = 0.0f;
	OUT.spotScale  = 1.0f;
	OUT.spotOffset = 0.0f;

	// Capsule
	OUT.capsuleExtent = IN.capsuleExtentsAndIntensity.x;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

lightProperties JOIN(PopulateLightPropertiesInstanced,LTYPE)(JOIN(LTYPE,InstancedVertexInput) IN)
{
	lightProperties OUT;

	OUT.position = IN.positionAndRadius.xyz;
	OUT.direction = IN.directionAndFalloffExponent.xyz;
	OUT.tangent = normalize(cross(OUT.direction, float3(0,0,1)));
	OUT.colour = IN.colour;
	OUT.intensity = IN.capsuleExtentsAndIntensity.x;
	OUT.radius = IN.positionAndRadius.w;
	OUT.invSqrRadius = 1.0f / (OUT.radius * OUT.radius);
	OUT.extraRadius = 0.029f;
	OUT.cullingPlane = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.falloffExponent = IN.directionAndFalloffExponent.w;

	// Fades
	OUT.shadowFade = 1.0f;
	OUT.specularFade = 1.0f;
	OUT.textureFade = 1.0f;

	// Vehicle
	OUT.vehicleHeadTwinPos1 = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.vehicleHeadTwinPos2  = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.vehicleHeadTwinDir1 = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.vehicleHeadTwinDir2  = float4(0.0f, 0.0f, 0.0f, 0.0f);

	// Textured
	OUT.textureFlipped = 0.0f;

	// Spot
	OUT.spotCosOuterAngle = 0.0f;
	OUT.spotSinOuterAngle = 0.0f;
	OUT.spotScale  = 1.0f;
	OUT.spotOffset = 0.0f;

	// Capsule
	OUT.capsuleExtent = IN.capsuleExtentsAndIntensity.x;

	return OUT;
}

JOIN(LTYPE,InstancedVertexOutput) JOIN(VS_instanced_,LTYPE)(JOIN(LTYPE,InstancedVertexInput) IN)
{
	JOIN(LTYPE,InstancedVertexOutput) OUT;

	OUT.positionAndRadius = IN.positionAndRadius;
	OUT.directionAndFalloffExponent = IN.directionAndFalloffExponent;
	OUT.capsuleExtentsAndIntensity = IN.capsuleExtentsAndIntensity;
	OUT.colour = IN.colour;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

#if !EXCLUDE_LIGHT_TECHNIQUES
	#include "Deferred/light_techs_and_funcs.fxh"
#endif

// ----------------------------------------------------------------------------------------------- //
#endif // DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS
// ----------------------------------------------------------------------------------------------- //

#undef LTYPE

#endif //__CAPSULE_INCLUDE
