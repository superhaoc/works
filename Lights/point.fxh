#ifndef __POINT_INCLUDE
#define __POINT_INCLUDE

// =============================================================================================== //
// INCLUDES
// =============================================================================================== //

#include "../lighting_common.fxh"
#include "light_common.fxh"

// =============================================================================================== //
// DEFINES
// =============================================================================================== //

#ifndef LTYPE
#define LTYPE pointCM
#endif

// =============================================================================================== //
// TECHNIQUE FUNCTIONS
// =============================================================================================== //

float JOIN(LTYPE,CalcAttenuation)(	
	float	surfaceToLightDistSqr,
	float	lightInvSqrFalloffDist,
	float	lightFalloffExponent,
	float3  surfacePosition,
	float4	cullPlane)
{
	float falloff = distanceFalloff(surfaceToLightDistSqr, lightInvSqrFalloffDist, lightFalloffExponent);
	falloff *= (dot(float4(surfacePosition, 1.0), cullPlane) >= 0);
	return falloff;
}

float4 JOIN(LTYPE,CalcAttenuation)(	
								  float4	surfaceToLightDistSqr,
								  float		lightInvSqrFalloffDist,
								  float		lightFalloffExponent,
								  float4	surfacePositionX,
								  float4	surfacePositionY,
								  float4	surfacePositionZ,
								  float4    cullPlane)
{
	float4 falloff = distanceFalloff(surfaceToLightDistSqr, lightInvSqrFalloffDist, lightFalloffExponent);
	const float4 surfaceBoundsTest = Dot44(surfacePositionX, surfacePositionY, surfacePositionZ, cullPlane.xxxx, cullPlane.yyyy, cullPlane.zzzz);	
	falloff *= ( surfaceBoundsTest >= 0);
	return falloff;
}

// ----------------------------------------------------------------------------------------------- //
#if DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS
// ----------------------------------------------------------------------------------------------- //

LightingResult JOIN(LTYPE,CalculateDeferredLighting)(
	surfaceProperties surface,
	materialProperties material,
	lightProperties light,
	bool useShadow, 
	bool useFiller, 
	bool useInterior, 
	bool useExterior, 
	bool useTexture,
	float3 shadowTexCoords,
	float2 screenPos,
	bool softShadow,
	bool clipAttenuatedPixels,
	bool useAlternateAttenuation,
	float alternateAttenuation)
{
	float lightAttenuation;
	if ( useAlternateAttenuation )
	{
		lightAttenuation = alternateAttenuation;
	}
	else
	{
		lightAttenuation = JOIN(LTYPE,CalcAttenuation)(
		surface.sqrDistToLight,
		light.invSqrRadius,
		light.falloffExponent,
		surface.position,
		light.cullingPlane);
	}

	if ( clipAttenuatedPixels )
	{
		rageDiscard( lightAttenuation < LIGHT_ATTEN_THRESHOLD );
	}

	// Apply shadows
	float shadowAmount = 1.0;
	#if SHADOW_RECEIVING
	if (useShadow)
	{				   
		shadowAmount = shadowCubemap(CalcCubeMapShadowTexCoords(shadowTexCoords, dLocalShadowData), screenPos, softShadow);
	}
	#endif	//SHADOW_RECEIVING

#if !USE_STENCIL_FOR_INTERIOR_EXTERIOR_CHECK // if not stenciling, we need to do the interior/exterior test in the shader
	// Calculate if light is in interior / exterior
	if (useInterior)
		lightAttenuation *= material.inInterior;
	
	if (useExterior)
		lightAttenuation *= 1-material.inInterior;
#endif 

	// Store all the results that we need
	float3 lightColor = light.colour;

	if (useTexture)
	{
		float3 lightToSurface = -surface.lightDir;

		// Project into basis of the light
		float3 tex = float3(dot(cross(-light.direction, light.tangent), lightToSurface), 
							dot(light.tangent, lightToSurface), 
							dot(-light.direction, lightToSurface));

		float dist = length(lightToSurface);
		tex.xy *= (1.0f / (dist * (1.0f - (tex.z / dist))));		
		
		float3 textureColour = tex2Dlod(gDeferredLightSampler, float4((tex.xy * 0.5f) + 0.5f, 0, 0)).rgb;
		textureColour = ProcessDiffuseColor(textureColour);

		lightColor *= lerp(1.0.xxx, textureColour, light.textureFade);
	}	

	lightColor *= light.intensity;

	LightingResult OUT = storeLightingResults(
		material, 
		surface, 
		lightColor, 
		lightAttenuation,
		shadowAmount,
		1.0f);
	
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

float3 JOIN(pos_,LTYPE)(float3 pos, lightProperties light, bool useShadow, bool useTexture, bool useVolume)
{
	float3 vpos = any3(pos) ? normalize(pos) : pos;


	if (useVolume) // don't extend light radius, since we do some calculations per-vertex
	{
		vpos *= light.radius;
		vpos += light.position;
	}
	else
	{
		vpos *= (light.radius + light.extraRadius);
		vpos += light.position;
	}

	return vpos;
}

// ----------------------------------------------------------------------------------------------- //

void JOIN(volume_,LTYPE)(inout lightVolumeData volumeData, lightProperties light, float3 pos, float3 inpos_unused, bool outsideVolume_unused)
{
	const float3 worldPos = pos; // world pos on backface
	const float3 eyePos   = gViewInverse[3].xyz;
	const float3 eyeRay   = worldPos - eyePos;

	const float  r = light.radius; // sphere radius
	const float3 q = eyePos - light.position;
	const float3 v = eyeRay;

	const float vv = dot(v, v);
	const float qv = dot(q, v);
	const float qq = dot(q, q); // constant
	const float rr = r*r;       // constant
	const float qr = qq - rr;   // constant

	const float g = qv*qv - qr*vv;

	//Using abs (and NOT ABS_PC as g gets negative values resulting in NANs at edges)
	const float t0 = (-qv - sqrt(abs(g)))/vv;
	const float t1 = (-qv + sqrt(abs(g)))/vv;

	volumeData.intersect = saturate(float2(t0, t1));
	volumeData.gradient  = 1;

	//if (gradientType == LIGHTVOLUME_GRADIENT_TYPE_1)
	{
		const float3 temp1 = q - v*min(0, qv)/vv;
		const float  temp2 = 1 - dot(temp1, temp1)/rr;

		volumeData.gradient = lerp(deferredLightVolumeParams_outerColour, light.colour, __powapprox(temp2*temp2, deferredLightVolumeParams_outerExponent));
		//volumeData.gradient *= temp2; // soften
	}
}

// ----------------------------------------------------------------------------------------------- //
// ----------------------------------------------------------------------------------------------- //
// INSTANCED
// ----------------------------------------------------------------------------------------------- //

struct JOIN(LTYPE,InstancedVertexInput)
{
	half4 pos							: POSITION;

	float4 positionAndRadius			: TEXCOORD0;
	float2 intensityAndFalloffExponent	: TEXCOORD1;
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
	float2 intensityAndFalloffExponent	: TEXCOORD3;
	float4 colour						: COLOR0;
};

// ----------------------------------------------------------------------------------------------- //

lightProperties JOIN(PopulateLightPropertiesInstanced,LTYPE)(JOIN(LTYPE,InstancedVertexOutput) IN)
{
	lightProperties OUT;

	OUT.position = IN.positionAndRadius.xyz;
	OUT.direction = float4(0.0.xxxx);
	OUT.tangent = float4(0.0.xxxx);
	OUT.colour = IN.colour;
	OUT.intensity = IN.intensityAndFalloffExponent.x;
	OUT.radius = IN.positionAndRadius.w;
	OUT.invSqrRadius = 1.0f / (OUT.radius * OUT.radius);
	OUT.extraRadius = 0.058f;
	OUT.cullingPlane = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.falloffExponent = IN.intensityAndFalloffExponent.y;

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
	OUT.capsuleExtent = 0.0f;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

lightProperties JOIN(PopulateLightPropertiesInstanced,LTYPE)(JOIN(LTYPE,InstancedVertexInput) IN)
{
	lightProperties OUT;

	OUT.position = IN.positionAndRadius.xyz;
	OUT.direction = float4(0.0.xxxx);
	OUT.tangent = float4(0.0.xxxx);
	OUT.colour = IN.colour;
	OUT.intensity = IN.intensityAndFalloffExponent.x;
	OUT.radius = IN.positionAndRadius.w;
	OUT.invSqrRadius = 1.0f / (OUT.radius * OUT.radius);
	OUT.extraRadius = 0.058f;
	OUT.cullingPlane = float4(0.0f, 0.0f, 0.0f, 0.0f);
	OUT.falloffExponent = IN.intensityAndFalloffExponent.y;

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
	OUT.capsuleExtent = 0.0f;

	return OUT;
}

JOIN(LTYPE,InstancedVertexOutput) JOIN(VS_instanced_,LTYPE)(JOIN(LTYPE,InstancedVertexInput) IN)
{
	JOIN(LTYPE,InstancedVertexOutput) OUT;

	OUT.positionAndRadius = IN.positionAndRadius;
	OUT.intensityAndFalloffExponent = IN.intensityAndFalloffExponent;
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

#endif //__POINT_INCLUDE
