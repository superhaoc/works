#pragma dcl position

#define SPECULAR 1

#include "../common.fxh"
#include "../Util/macros.fxh"
#include "../../renderer/Lights/LightCommon.h"

// We don't care for no skinning matrices here, so we can use a bigger constant register file
#pragma constant 130


#define DEFERRED_UNPACK_LIGHT
#include "lights\light_structs.fxh"
#include "lighting.fxh"
#undef DEFERRED_UNPACK_LIGHT


//BEGIN_RAGE_CONSTANT_BUFFER(deferred_ambient_locals,b0)
//EndConstantBufferDX10(deferred_ambient_locals)

struct vertexInputAmbient 
{
	float3 pos : POSITION;
	float4 portalNormal : NORMAL;	// normal.xyz, intensity.w
	float4 portalPos : TEXCOORD0;	// portalPos.xyz, pullFront.w 
	float4 unit1 : TEXCOORD1;		// unit1.xyz, line1Length.w
	float4 unit2 : TEXCOORD2;		// unit2.xyz, line2Length.w
};

struct vertexOutputAmbient
{
	DECLARE_POSITION(pos)
	float4 screenPos : TEXCOORD0;
	float4 eyeRay : TEXCOORD1;
	float4 portalNormal : TEXCOORD2;// normal.xyz, intensity.w
	float4 portalPos : TEXCOORD3;	// portalPos.xyz, pullFront.w 
	float4 unit1 : TEXCOORD4;		// unit1.xyz, line1Length.w
	float4 unit2 : TEXCOORD5;		// unit2.xyz, line2Length.w
};

struct pixelInputAmbient
{
	DECLARE_POSITION(pos)
	float4 screenPos : TEXCOORD0;
	float4 eyeRay : TEXCOORD1;
	float4 portalNormal : TEXCOORD2;// normal.xyz, intensity.w
	float4 portalPos : TEXCOORD3;	// portalPos.xyz, pullFront.w 
	float4 unit1 : TEXCOORD4;		// unit1.xyz, line1Length.w
	float4 unit2 : TEXCOORD5;		// unit2.xyz, line2Length.w
#if MULTISAMPLE_TECHNIQUES
	uint sampleIndex			: SV_SampleIndex;
#endif
};

#define intensity portalNormal.w
#define pullFront portalPos.w
#define line1Length unit1.w
#define line2Length unit2.w

vertexOutputAmbient VS_ambient(vertexInputAmbient IN)
{
	vertexOutputAmbient OUT;

    OUT.pos	= mul(float4(IN.pos, 1), gWorldViewProj);
	OUT.screenPos = convertToVpos(MonoToStereoClipSpace(OUT.pos), deferredLightScreenSize);
	OUT.eyeRay = float4(IN.pos - (gViewInverse[3].xyz+StereoWorldCamOffSet()), OUT.pos.w);
	OUT.portalNormal = IN.portalNormal;
	OUT.portalPos = IN.portalPos;
	OUT.unit1 = IN.unit1;
	OUT.unit2 = IN.unit2;
	
	return (OUT);
}

half4 PS_ambient(pixelInputAmbient IN) : COLOR
{
	// Read surface info
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy/IN.screenPos.w, IN.eyeRay, true, SAMPLE_INDEX);
	materialProperties material = populateMaterialPropertiesDeferred(surfaceInfo);
	surfaceProperties surface = populateSurfaceProperties(surfaceInfo, -deferredLightDirection, 0.0f);

	// Calc Ambient
	const float EdotN = saturate(dot(surface.eyeDir, surface.normal));
	float reflectFresnel = fresnelSlick(material.fresnel, EdotN);

	float Kd = 1.0f - material.specularIntensity * reflectFresnel;

	const float downMult = max(0.0f, (surface.normal.z + ambientDownWrap) * ooOnePlusAmbientDownWrap);
	const float3 artExtAmb = artificialExteriorAmbient(downMult);
	const float3 artIntAmb = artificialInteriorAmbient(downMult);

	float3 intEnvironmentalAmbient = artIntAmb - artExtAmb;
	float3 ambient = (intEnvironmentalAmbient) * Kd * material.diffuseColor.rgb * material.artificialAmbientScale;

	// Calc Attenuation : Distance, sides, normal wrap.
	float3 ctrToPos = surfaceInfo.positionWorld-IN.portalPos.xyz;

	float distAttenuation = 1.0f - saturate(dot(IN.portalNormal.xyz,ctrToPos) - IN.pullFront);

	float topBottomAtten = 1.0f - saturate( (abs(dot(IN.unit1.xyz,ctrToPos)) - (IN.line1Length) * 0.75f )/ (IN.line1Length * 0.25f));
	float leftRightAtten = 1.0f - saturate( (abs(dot(IN.unit2.xyz,ctrToPos)) - (IN.line2Length) * 0.75f )/ (IN.line2Length * 0.25f));

	float wrapAmount = 0.75f;
	float ndotl = saturate(-1.0*dot(IN.portalNormal.xyz,surfaceInfo.normalWorld));
	float wrap = saturate((distAttenuation-wrapAmount)/(1.0f - wrapAmount));
	float normalAtten = lerp(ndotl,1.0f,wrap);
	
	// return : carefull, distAttenuation is squared, to take ambient difference into account.
	float atten = distAttenuation * distAttenuation * topBottomAtten * leftRightAtten * normalAtten * IN.intensity;
	return PackHdr(float4(ambient * atten,1.0f - material.inInterior));
}

#if 0
// Reference implementation, 37 passes
half4 PS_ambient(pixelInputAmbient IN) : COLOR
{
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos.xy/IN.screenPos.w, IN.eyeRay, true, SAMPLE_INDEX);

	float3 ctrToPos = surfaceInfo.positionWorld-IN.portalPos.xyz;
	float distAttenuation = 1.0f - saturate(dot(IN.portalNormal.xyz,ctrToPos) - IN.pullFront);
	
	materialProperties material = populateMaterialPropertiesDeferred(surfaceInfo);
	surfaceProperties surface = populateSurfaceProperties(surfaceInfo, -deferredLightDirection, 0.0f);
	
	float isInInterior = material.inInterior;
	
	material.inInterior = distAttenuation;

	const float EdotN = saturate(dot(surface.eyeDir, surface.normal));
	float reflectFresnel = fresnelSlick(material.fresnel, EdotN);

	float Kd = 1.0f - material.specularIntensity * reflectFresnel;
	float3 intAmbient = calculateAmbient(
		false, 
		true, 
		true, 
		false, 
		surface, 
		material,
		Kd); 
		
	material.inInterior = 0.0f;
	float3 extAmbient = calculateAmbient(
		false, 
		true, 
		true, 
		false, 
		surface, 
		material,
		Kd); 

	float3 ambient = intAmbient - extAmbient;

	float topBottomAtten = 1.0f - saturate( (abs(dot(IN.unit1.xyz,ctrToPos)) - (IN.line1Length) * 0.75f )/ (IN.line1Length * 0.25f));
	float leftRightAtten = 1.0f - saturate( (abs(dot(IN.unit2.xyz,ctrToPos)) - (IN.line2Length) * 0.75f )/ (IN.line2Length * 0.25f));

	float wrapAmount = 0.75f;
	float ndotl = saturate(-1.0*dot(IN.portalNormal.xyz,surfaceInfo.normalWorld));
	float wrap = saturate((distAttenuation-wrapAmount)/(1.0f - wrapAmount));
	float normalAtten = lerp(ndotl,1.0f,wrap);

	float atten = distAttenuation * topBottomAtten * leftRightAtten * normalAtten * IN.intensity;
	return PackHdr(float4(ambient * atten,1.0f - isInInterior));
}

#endif

technique MSAA_NAME(ambientLight)
{
	pass MSAA_NAME(pp_0)
	{
		VertexShader = compile VERTEXSHADER VS_ambient();
		PixelShader = compile MSAA_PIXEL_SHADER PS_ambient() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
