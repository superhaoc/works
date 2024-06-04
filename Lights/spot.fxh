#ifndef __SPOT_INCLUDE
#define __SPOT_INCLUDE

// =============================================================================================== //
// INCLUDES
// =============================================================================================== //

#include "../lighting_common.fxh"
#include "light_common.fxh"
#include "../lighting.fxh"

// =============================================================================================== //
// DEFINES
// =============================================================================================== //

#ifndef LTYPE
#define LTYPE spotCM
#define LTYPE_IS_SPOT
#endif

// =============================================================================================== //
// TECHNIQUE FUNCTIONS
// =============================================================================================== //

float JOIN(LTYPE,CalcAttenuation)(
	float3  surfaceToLightDir,
	float	surfaceToLightDistSqr,
	float3	lightToWorldDir,
	float	lightInvSqrFalloffDist,
	float	lightConeOffset,
	float	lightConeScale,
	float	lightFalloffExponent,
	float3  surfacePosition,
	float4  cullPlane)
{
	// Calc angular attenuation (spotlight specific)
	float atten = distanceFalloff(surfaceToLightDistSqr, lightInvSqrFalloffDist, lightFalloffExponent);
	atten *= angularFalloff(dot(surfaceToLightDir, -lightToWorldDir), lightConeScale, lightConeOffset);
	atten *= (dot(float4(surfacePosition, 1.0), cullPlane) >= 0);
	return atten;
}

float4 JOIN(LTYPE,CalcAttenuation)(
									float4  surfaceToLightDirX,
									float4  surfaceToLightDirY,
									float4  surfaceToLightDirZ,
									//float3  surfaceToLightDir3,
									float4	surfaceToLightDistSqr,
									float3	lightToWorldDir,
									float	lightInvSqrFalloffDist,
									float	lightConeOffset,
									float	lightConeScale,
									float	lightFalloffExponent,
									float4	surfacePositionX,
									float4	surfacePositionY,
									float4	surfacePositionZ,
									float4	cullPlane)
{
	// Calc angular attenuation (spotlight specific)
	float4 atten = distanceFalloff(surfaceToLightDistSqr, lightInvSqrFalloffDist, lightFalloffExponent);
	const float4 surfaceToLightAngle = Dot44(surfaceToLightDirX, surfaceToLightDirY, surfaceToLightDirZ, -lightToWorldDir.xxxx, -lightToWorldDir.yyyy, -lightToWorldDir.zzzz);

	atten *= angularFalloff(surfaceToLightAngle, lightConeScale, lightConeOffset);
#if defined(DEFERRED_UNPACK_LIGHT)
	const float4 surfaceBoundsTest = Dot44(
		surfacePositionX, surfacePositionY, surfacePositionZ, 
		cullPlane.xxxx, cullPlane.yyyy, cullPlane.zzzz) + cullPlane.wwww;
	atten *= (surfaceBoundsTest >= 0);
#endif
	return atten;
}

float JOIN(LTYPE,CalcDistanceAttenuation)(
								  float	surfaceToLightDistSqr,
								  float	lightInvSqrFalloffDist,
								  float	lightFalloffExponent,
								  float3  surfacePosition,
								  float4 cullPlane)
{
	// Calc angular attenuation (spotlight specific)
	float atten = distanceFalloff(surfaceToLightDistSqr, lightInvSqrFalloffDist, lightFalloffExponent);
	atten *= (dot(float4(surfacePosition, 1.0), cullPlane) >= 0);
	return atten;
}

float JOIN(LTYPE,CalcAngleAttenuation)(
	float3  surfaceToLightDir,
	float3	lightToWorldDir,
	float	lightConeOffset,
	float	lightConeScale)
{
	// Calc angular attenuation (spotlight specific)
	float atten = angularFalloff(dot(surfaceToLightDir, -lightToWorldDir), lightConeScale, lightConeOffset);
	return atten;
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
	float alternateAttenuation
	)
{
	float lightAttenuation = 1.0f;
	const float3 lightToWorldDir = light.direction;

	//for attenuation
	if ( useAlternateAttenuation )
	{
		lightAttenuation = alternateAttenuation;
	}
	else
	{
		lightAttenuation = JOIN(LTYPE,CalcAttenuation)(
			surface.lightDir,
			surface.sqrDistToLight,
			lightToWorldDir,
			light.invSqrRadius,
			light.spotOffset,
			light.spotScale,
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
#if USE_SHADOW_CUBEMAP
		if(dShadowType==SHADOW_TYPE_HEMISPHERE) // TODO: make a separate shader for Hemisphere lights, to avoid the shader bloat and branch here
			shadowAmount = shadowCubemap(CalcCubeMapShadowTexCoords(shadowTexCoords, dLocalShadowData), screenPos, softShadow);
		else			   
#endif	
			shadowAmount = shadowSpot(CalcSpotShadowTexCoords(shadowTexCoords, dLocalShadowData), screenPos, softShadow, dShadowDitherRadius ); 
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

	//for textured projection
	if (useTexture)
	{
		float3 lightToSurface = -surface.lightDir;

		float3 texUV = float3(
			dot(cross(-light.direction, light.tangent), lightToSurface), 
			dot(light.tangent, lightToSurface), 
			dot(-light.direction, lightToSurface));

		float t = light.spotCosOuterAngle / sqrt(1.0f - (light.spotCosOuterAngle * light.spotCosOuterAngle));
		texUV.xy *= 0.5 * t / texUV.z;
		texUV.xy = saturate(texUV.xy + 0.5f);

		if(light.textureFlipped == 1.0f)
		{	
			texUV.y = 1.0f - texUV.y;
		}

		float3 textureColour = tex2Dlod(gDeferredLightSampler, float4(texUV.xy,0.f,0.f)).rgb;
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
	float3x3 rotMtx;
	rotMtx[2] = light.direction;
	float3 vpos;

	rotMtx[0] = light.tangent;
	rotMtx[1] = cross(light.tangent, light.direction);

	// project the octahedron vertex position to a cone shape
	const float2 v = (abs(pos.z) <= 0.9999) ? normalize(pos.xy) : 0;

	float3 vs = rotMtx[0]*v.x + rotMtx[1]*v.y;
	float3 vc = rotMtx[2];

	if (pos.z <= 0)
	{
		const float c = 1 - (1 + pos.z)*(1 + pos.z)*(1 - light.spotCosOuterAngle);
		const float s = sqrt(saturate(abs(1 - c*c)));

		vc *= c;
		vs *= s;
	}
	else
	{
		const float c = (1 - pos.z)*light.spotCosOuterAngle;
		const float s = (1 - pos.z)*light.spotSinOuterAngle;

		vc *= c;
		vs *= s;
	}

	vpos = vs + vc;

	if (useShadow || useVolume) // don't extend light radius, since we do some calculations per-vertex
	{
		vpos *= light.radius;
		vpos += light.position;
	}
	else
	{
		vpos *= (light.radius + light.extraRadius * 2.0f);
		vpos += light.position - light.direction * light.extraRadius;
	}

	return vpos;
}

// ----------------------------------------------------------------------------------------------- //

void JOIN(volume_,LTYPE)(inout lightVolumeData volumeData, lightProperties light, float3 pos, float3 inpos, bool outsideVolume)
{
	//In order to understand this code, you should try deriving the equations for intersection of Ray and Cone
	//The ray starts from eye to the vertex on the back face of the cone

	const float3 eyePos = gViewInverse[3].xyz;
	const float3 eyeRay = pos - eyePos;

	const float3 a = light.direction.xyz;
	const float3 q = eyePos - light.position.xyz;
	const float3 v = eyeRay;
	const float cosSqrd = light.spotCosOuterAngle*light.spotCosOuterAngle;

	const float vv = dot(v, v);
	const float qv = dot(q, v);
	const float qq = dot(q, q); // constant (depends on eyePos)
	const float qa = dot(q, a); // constant (depends on eyePos)
	const float va = dot(v, a);

	float t0, t1;

	// quadratic equation components for calculating the planes:
	const float a1 = va*va - cosSqrd*vv;
	const float b1 = va*qa - cosSqrd*qv;
	const float c1 = qa*qa - cosSqrd*qq;

	// testing for reverse cone and cone apex
	const float3 conditionForPointOnApexOfCone = abs(inpos - float3(0,0,1));

	const float g = b1 * b1 - a1 * c1;
	const float h = -a1;
	const float g_plane = sqrt(abs(g));

	//For Calculating intersection on sphere
	const float rr_sphere = light.radius*light.radius; // constant
	const float qr_sphere = qq - rr_sphere; // constant (depends on eyePos)

	const float g_sphere = sqrt(abs(qv*qv - qr_sphere*vv));
	const float h_sphere = vv;

	if(outsideVolume)
	{
		//Front face Technique: 

		//First intersection point will be the vertex we're dealing with
		t0 = 1.0f;
		//calculate 4 points of intersection: 1 on each of 2 planes, and 2 on sphere
		float4 results = float4(g_plane, -g_plane, g_sphere, -g_sphere);
		results += float4(b1,b1,-qv,-qv);
		results /= float4(h, h, h_sphere, h_sphere);

		//Choose the furthest sphere point. Sphere point behind or closer to the camera
		// will get rejected
		results.z = max(results.z, results.w);
		

		float3 intersection1 = eyePos + eyeRay * results.x;
		float3 intersection2 = eyePos + eyeRay * results.y;
		//Check to see if any of the plane points is behind the light source
		//do dot product of vector between intersection point and light source, with light direction
		//If negative, then the intersection is behind so we zero it out.
		results.xy *= (float2(dot(intersection1 - light.position.xyz, a), dot(intersection2 - light.position.xyz, a)) >= 0.0f.xx);

		//Taking the max will ensure that point further away will get chosen
		//It will not choose points behind light source as they will be zeroed out
		//from previous check
		results.x = max(results.x, results.y);

		//Special Condition for using the sphere point and not the plane point
		//if eyeRay direction is within the cone, then force the intersection point
		//to be on the sphere. To ensure this, we multiply a huge number to the plane 
		//intersection point
		float2 forceSphereCondition = (((va*va/vv) >= cosSqrd)  && va > 0.0f);
		results.x +=  forceSphereCondition * 1000000.0f;

		//Choose which ever point is closer, the plane or the sphere point.
		t1 = min(results.x, results.z);


		//in case chosen intersection point is behind the vertex we're dealing with,
		//then ditch that and use a point slightly in front of the vertex
		t1 = max(1.01f, t1);

		volumeData.intersect = (float2(t0, t1));
	}
	else
	{
		//Backface Technique: 

		//We should find the first intersection point. For this check to see point is really close
		//to light source. If so, choose constant value.
		t0 = all(conditionForPointOnApexOfCone < 0.0001) ? 0.99f : (b1 - g_plane)/h ; // using abs(g) here fixes some glitches that sometimes happen on the edge of the cone

		//we have to do this as backface technique is used when the camera is really close to
		//the volume or inside the volume. 
		const bool conditionForCameraOutsideVolume = (c1<0 || qa<0);

		//If camera is inside volume then the ray travels from eye to vertex
		t0 = conditionForCameraOutsideVolume ? t0 : 0.0f;

		//Second intersection point is the vertex itself
		t1 = 1.0;
		//Check to see if we need to choose the sphere point
		t0 = max((-qv - g_sphere)/h_sphere, t0);
		volumeData.intersect = saturate(float2(t0, t1));

	}

	volumeData.gradient  = 1;

	//if (gradientType == LIGHTVOLUME_GRADIENT_TYPE_1)
	{
		const float3 e = pos - light.position.xyz;
		const float3 temp1 = q - v*(min(0, qv)/vv);
		const float  temp2 = 1 - dot(temp1, temp1)/rr_sphere;

		volumeData.gradient = lerp(deferredLightVolumeParams_outerColour, light.colour, __powapprox(temp2*temp2, deferredLightVolumeParams_outerExponent));
	}
	/*else if (gradientType == LIGHTVOLUME_GRADIENT_TYPE_2)
	{
		// integral through radial density function: density(t) = d = (1 - |q + t*v|^2/r^2)
	//	integral_1 =
	//	(
	//		+ s0*(3*qr)
	//		+ s1*(3*qv)
	//		+ s2*(1*vv)
	//	)
	//	/(-3*rr);
	//
	//	// integral through radial density function: density(t) = d^2 --> this function produces too much noise
	//	integral_2 =
	//	(
	//		+ s0*(15*qr*qr           )
	//		+ s1*(30*qr*qv           )
	//		+ s2*(10*vv*qr + 20*qv*qv)
	//		+ s3*(15*vv*qv           )
	//		+ s4*( 3*vv*vv           )
	//	)
	//	/(15*rr*rr);

		volumeData.gradient = float3(-qr_sphere, -qv, -vv/3)/(rr_sphere);
	}
	else
	{
		volumeData.gradient = light.colour;
	}*/
}

// ----------------------------------------------------------------------------------------------- //
// INSTANCED
// ----------------------------------------------------------------------------------------------- //

struct JOIN(LTYPE,InstancedVertexInput)
{
	half4 pos							: POSITION;

	float4 positionAndRadius			: TEXCOORD0;
	float4 directionAndFalloffExponent	: TEXCOORD1;
	float4 spotParamsAndIntensity		: TEXCOORD2;
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
	float4 spotParamsAndIntensity		: TEXCOORD4;
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
	OUT.intensity = IN.spotParamsAndIntensity.w;
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
	OUT.spotCosOuterAngle = IN.spotParamsAndIntensity.x;
	OUT.spotSinOuterAngle = IN.spotParamsAndIntensity.y;
	OUT.spotScale  = IN.spotParamsAndIntensity.z;
	OUT.spotOffset = -OUT.spotCosOuterAngle * OUT.spotScale;

	// Capsule
	OUT.capsuleExtent = 0.0f;

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

lightProperties JOIN(PopulateLightPropertiesInstanced,LTYPE)(JOIN(LTYPE,InstancedVertexInput) IN)
{
	lightProperties OUT;

	OUT.position = IN.positionAndRadius.xyz;
	OUT.direction = IN.directionAndFalloffExponent.xyz;
	OUT.tangent = calculateTangent(OUT.direction);
	OUT.colour = IN.colour;
	OUT.intensity = IN.spotParamsAndIntensity.w;
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
	OUT.spotCosOuterAngle = IN.spotParamsAndIntensity.x;
	OUT.spotSinOuterAngle = IN.spotParamsAndIntensity.y;
	OUT.spotScale  = IN.spotParamsAndIntensity.z;
	OUT.spotOffset = -OUT.spotCosOuterAngle * OUT.spotScale;

	// Capsule
	OUT.capsuleExtent = 0.0f;

	return OUT;
}

JOIN(LTYPE,InstancedVertexOutput) JOIN(VS_instanced_,LTYPE)(JOIN(LTYPE,InstancedVertexInput) IN)
{
	JOIN(LTYPE,InstancedVertexOutput) OUT;

	OUT.positionAndRadius = IN.positionAndRadius;
	OUT.directionAndFalloffExponent = IN.directionAndFalloffExponent;
	OUT.spotParamsAndIntensity = IN.spotParamsAndIntensity;
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
#undef LTYPE_IS_SPOT

#endif // __SPOT_INCLUDE
