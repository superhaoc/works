#pragma dcl position

#include "../common.fxh"
#include "../Util/macros.fxh"
#include "../../renderer/Lights/LightCommon.h"

// We don't care for no skinning matrices here, so we can use a bigger constant register file
#pragma constant 130

#if LIGHTSHAFT_USE_SHADOWS
#define SHADOW_CASTING            (0)
#define SHADOW_CASTING_TECHNIQUES (0)
#define SHADOW_RECEIVING          (1)
#define SHADOW_RECEIVING_VS       (0)
#include "Shadows/cascadeshadows.fxh"
#endif // LIGHTSHAFT_USE_SHADOWS

#define DEFERRED_UNPACK_LIGHT
#include "lights\light_structs.fxh"
#include "lighting.fxh"
#undef DEFERRED_UNPACK_LIGHT


BEGIN_RAGE_CONSTANT_BUFFER(deferred_volume_locals,b0)
float4 deferredVolumePosition; // w=unused
float4 deferredVolumeDirection; // w=unused
float4 deferredVolumeTangentXAndShaftRadius;
float4 deferredVolumeTangentYAndShaftLength;
float4 deferredVolumeColour; // w=unused
float4 deferredVolumeShaftPlanes[3];
float4 deferredVolumeShaftGradient;
float4 deferredVolumeShaftGradientColourInv; // w=softness
ROW_MAJOR float4x4 deferredVolumeShaftCompositeMtx;

EndConstantBufferDX10(deferred_volume_locals)


DECLARE_SAMPLER(sampler2D, deferredVolumeDepthBuffer, deferredVolumeDepthBufferSamp,
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);

// texture used by lights and modifiers - all bi-linear filtered
BeginDX10Sampler(sampler, Texture2D<float4>, gVolumeLightsTexture,gVolumeLightsSampler,gVolumeLightsTexture)
ContinueSampler(sampler, gVolumeLightsTexture,gVolumeLightsSampler,gVolumeLightsTexture)
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	AddressW  = CLAMP; 
	MINFILTER = LINEAR;//POINT;
	MAGFILTER = LINEAR;//POINT;
	MIPFILTER = LINEAR;//POINT;
EndSampler;

BeginDX10Sampler(sampler, Texture2D<float>, gLowResDepthTexture,gLowResDepthSampler,gLowResDepthTexture)
ContinueSampler(sampler, gLowResDepthTexture,gLowResDepthSampler,gLowResDepthTexture)
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	AddressW  = CLAMP; 
	MINFILTER = POINT;
	MAGFILTER = POINT;
	MIPFILTER = POINT;
EndSampler;

#define g_fBilateralCoefficient 0.007f

struct vertexInputVolume
{
	float3 pos : POSITION;
};

struct vertexOutputVolumeShaft
{
	DECLARE_POSITION(pos)
	float3 worldPos  : TEXCOORD0;
	float4 screenPos : TEXCOORD1; // z is 1 - fog opacity, w is oPos.w
	float3 planeP    : TEXCOORD2;
	float3 planeQ    : TEXCOORD3;
};

vertexOutputVolumeShaft volumeShaft_internal(vertexInputVolume IN, bool shadowed)
{
	vertexOutputVolumeShaft OUT;

	const float2 quadPos = IN.pos.xy - 0.5; // -[1/2..1/2]

	const float3 dirx = deferredVolumeTangentXAndShaftRadius.xyz;
	const float3 diry = deferredVolumeTangentYAndShaftLength.xyz;
	const float3 dirz = deferredVolumeDirection.xyz;
	const float3 qpos = deferredVolumePosition.xyz + dirx*quadPos.x + diry*quadPos.y; // position on shaft quad

	const float shaftLength = deferredVolumeTangentYAndShaftLength.w; // how far to extend in light direction

	//if (shadowed) // this doesn't work, remove it?
	//{
	//	length = min(CalcCascadeShadowSampleVS(wpos, true, false), length);
	//}

	const float3 worldPos = qpos + dirz*shaftLength*IN.pos.z;
	const float3 eyePos   = gViewInverse[3].xyz;
	const float3 eyeRay   = worldPos - eyePos;
	const float4 oPos     = mul(float4(worldPos, 1), gWorldViewProj);

	OUT.pos       = mul(float4(worldPos, 1), deferredVolumeShaftCompositeMtx); 
	OUT.worldPos  = worldPos;
	OUT.screenPos = float4(convertToVpos(MonoToStereoClipSpace(oPos), deferredLightScreenSize).xy, 1 - CalcFogData(eyeRay).w, oPos.w);

	OUT.planeP = float3(
		-dot(float4(eyePos, 1), deferredVolumeShaftPlanes[0]),
		-dot(float4(eyePos, 1), deferredVolumeShaftPlanes[1]),
		-dot(float4(eyePos, 1), deferredVolumeShaftPlanes[2])
	);
	OUT.planeQ = float3(
		dot(eyeRay, deferredVolumeShaftPlanes[0].xyz),
		dot(eyeRay, deferredVolumeShaftPlanes[1].xyz),
		dot(eyeRay, deferredVolumeShaftPlanes[2].xyz)
	);

	return (OUT);
}

vertexOutputVolumeShaft VS_volumeShaft(vertexInputVolume IN)
{
	return volumeShaft_internal(IN, false);
}

float intersectPlane(float3 p, float3 v, float4 plane)
{
	return -dot(float4(p, 1), plane)/dot(v, plane.xyz);
}

half4 volumeShaft_internal(vertexOutputVolumeShaft IN, int volumeType, int densityType)
{
	const float3 worldPos    = IN.worldPos; // world pos on backface
	const float3 eyePos      = gViewInverse[3].xyz;
	const float3 eyeRay      = worldPos - eyePos;
	const float  depthSample = tex2D(deferredVolumeDepthBufferSamp, IN.screenPos.xy/IN.screenPos.w).x;
	const float  depth       = getLinearGBufferDepth(depthSample, deferredProjectionParams.zw)/IN.screenPos.w;

	const float  r = deferredVolumeTangentXAndShaftRadius.w; // radius
	const float3 a = deferredVolumeDirection.xyz; // direction
	const float  b = 1; // cos cone angle
	const float3 q = eyePos - deferredVolumePosition.xyz;
	const float3 v = eyeRay;

	// =========================================================================================================================
	// sphere: |q + t*v| == r
	// t = (-qv +/- sqrt((rr - qq)*vv + qv^2))/vv
	// 
	// cylinder: |q - (q.a)*a + t*(v - (v.a)*a)| == r
	// t = (qa*va - qv +/- sqrt((rr - qq + qa^2)*vv + (qq - rr)*va^2 - 2*qa*qv*va + qv^2))/(vv - va^2)
	// 
	// cone: (q + t*v).a == b*|q + t*v|
	// t = (qa*va - bb*qv +/- sqrt((bb*qa^2 - bb^2*qq)*vv + bb*qq*va^2 - 2*bb*qa*qv*va + bb^2*qv^2))/(bb*vv - va^2)
	// 
	// more generalised ..
	// t = (      -    qv +/- sqrt((rr -      qq           )*vv                                     +      qv^2))/(   vv       )
	// t = (qa*va -    qv +/- sqrt((rr -      qq  +    qa^2)*vv + (   qq - rr)*va^2 - 2*   qa*qv*va +      qv^2))/(   vv - va^2)
	// t = (qa*va - bb*qv +/- sqrt((   - bb^2*qq  + bb*qa^2)*vv + (bb*qq     )*va^2 - 2*bb*qa*qv*va + bb^2*qv^2))/(bb*vv - va^2)
	// ..
	// t = (qa*va - bb*qv +/- sqrt((rr - bb^2*qq  + bb*qa^2)*vv + (bb*qq - rr)*va^2 - 2*bb*qa*qv*va + bb^2*qv^2))/(bb*vv - va^2)
	// 
	// where:
	// b = 1 for sphere and cylinder
	// a = 0 for sphere (therefore qa = va = 0)
	// r = 0 for cone
	// =========================================================================================================================

	const float rr = r*r; // constant
	const float bb = b*b; // constant

	const float vv = dot(v, v);
	const float qv = dot(q, v);
	const float qq = dot(q, q); // constant
	const float qa = dot(q, a); // constant
	const float qr = qq - rr;   // constant (same as -xx and -yy for sphere)
	const float va = dot(v, a);
	const float xx = rr - qq*bb*bb + qa*qa*bb; // constant
	const float yy = rr - qq*bb; // constant

	float g = 1;

	float t0 = 0;
	float t1 = 1;

	if (volumeType == LIGHTSHAFT_VOLUMETYPE_SHAFT)
	{
		const float3 f = IN.planeP/IN.planeQ;

		//f.x = intersectPlane(eyePos, eyeRay, deferredVolumeShaftPlanes[0]);
		//f.y = intersectPlane(eyePos, eyeRay, deferredVolumeShaftPlanes[1]);
		//f.z = intersectPlane(eyePos, eyeRay, deferredVolumeShaftPlanes[2]);

		t0 = max(max(f.x, f.y), f.z);
		t1 = saturate(depth);
	}
	else // sphere/cylinder/cone use the same underlying intersection code
	{
		g = xx*vv - yy*va*va + qv*bb*(qv*bb - 2*qa*va);

		t0 = min(saturate((qa*va - bb*qv - sqrt(g))/(bb*vv - va*va)), depth);
		t1 = min(saturate((qa*va - bb*qv + sqrt(g))/(bb*vv - va*va)), depth);
	}

	const float s0 = 1;
	const float s1 = t0*s0 + t1;
	const float s2 = t0*s1 + t1*t1;
	const float s3 = t0*s2 + t1*t1*t1;
	const float s4 = t0*s3 + t1*t1*t1*t1;

	float integral_1 = 0;
	float integral_2 = 0;
	float integral_3 = 0;

	/*if (volumeType == LIGHTSHAFT_VOLUMETYPE_SPHERE)
	{
		// integral through radial density function: density(t) = d = (1 - |q + t*v|^2/r^2)
		integral_1 =
		(
			+ s0*(3*qr)
			+ s1*(3*qv)
			+ s2*(1*vv)
		)
		/(-3*rr);

		// integral through radial density function: density(t) = d^2 --> this function produces too much noise
		integral_2 =
		(
			+ s0*(15*qr*qr           )
			+ s1*(30*qr*qv           )
			+ s2*(10*vv*qr + 20*qv*qv)
			+ s3*(15*vv*qv           )
			+ s4*( 3*vv*vv           )
		)
		/(15*rr*rr);
	}
	else*/ // shaft and cylinder use the same underlying density code
	{
		const float gp = dot(deferredVolumeShaftGradient.xyzw, float4(eyePos, 1)); // constant
		const float gv = dot(deferredVolumeShaftGradient.xyz, eyeRay);

		// integral through density function: density(t) = d = (p + t*v).gradient_xyz + gradient_w
		integral_1 =
		(
			+ s0*(gp)
			+ s1*(gv)/2
		);

		// integral through density function: density(t) = d^2
		integral_2 =
		(
			+ s0*(gp*gp)
			+ s1*(gv*gp)
			+ s2*(gv*gv)/3
		);

		// integral through density function: density(t) = d^3
		integral_3 = integral_1*
		(
			+ (s0           )*(gp*gp)
			+ (s1           )*(gv*gp)
			+ (t1*t1 + t0*t0)*(gv*gv)/2
		);

		// integral through density function: density(t) = exp(-k*(1 - d))
		const float k = 5;
		const float integral_exp = exp(k*(gp - 1))*(exp(k*gv*t1) - exp(k*gv*t0))/(k*gv); // note that this is not divided by t1 - t0
	}

	float3 intensity = saturate(t1 - t0);

	if (0) {}
	else if (densityType == LIGHTSHAFT_DENSITYTYPE_LINEAR            ) { intensity = saturate(t1 - t0)*integral_1; }
	else if (densityType == LIGHTSHAFT_DENSITYTYPE_LINEAR_GRADIENT   ) { intensity = saturate(t1 - t0)*pow(abs(integral_1), deferredVolumeShaftGradientColourInv.xyz); }
	else if (densityType == LIGHTSHAFT_DENSITYTYPE_QUADRATIC         ) { intensity = saturate(t1 - t0)*integral_2; }
	else if (densityType == LIGHTSHAFT_DENSITYTYPE_QUADRATIC_GRADIENT) { intensity = saturate(t1 - t0)*pow(abs(integral_2), deferredVolumeShaftGradientColourInv.xyz); }

#if LIGHTSHAFT_USE_SHADOWS
	if (densityType == LIGHTSHAFT_DENSITYTYPE_SOFT_SHADOW ||
		densityType == LIGHTSHAFT_DENSITYTYPE_SOFT_SHADOW_HD)
	{
		const int cascadeIndex = (densityType == LIGHTSHAFT_DENSITYTYPE_SOFT_SHADOW_HD) ?  0 : 1;
		const int numSamples   = (densityType == LIGHTSHAFT_DENSITYTYPE_SOFT_SHADOW_HD) ? 24 : 8;

		intensity *= CalcCascadeShadowAccum(SHADOWSAMPLER_TEXSAMP, true, eyePos + eyeRay*t0, eyeRay*saturate(t1 - t0)/(float)numSamples, numSamples, cascadeIndex);
	}
#endif // LIGHTSHAFT_USE_SHADOWS

	intensity *= length(eyeRay)*(g > 0);
	intensity *= IN.screenPos.z; // apply fog

	if (densityType != LIGHTSHAFT_DENSITYTYPE_CONSTANT)
	{
		intensity *= lerp(float3(1,1,1), intensity, deferredVolumeShaftGradientColourInv.w);
	}

	return PackColor(float4(intensity*deferredVolumeColour.xyz, 0));
}

// =============================================================================================== //
// VOLUME LIGHTS INTERLEAVE RECONSTRUCTION
// =============================================================================================== //
// This is placed here as deferred_lighting.fx is too big to handle new techniques

struct volumeReconstructVertexIn {
	float3 pos			: POSITION;
	float4 diffuse		: COLOR0;
	float2 texCoord0	: TEXCOORD0;
};

struct volumeReconstructVertex {

	DECLARE_POSITION(pos)
	float2 texCoord0	: TEXCOORD0;
};

volumeReconstructVertex VS_VolumeLight_Interleave_Reconstruction(volumeReconstructVertexIn IN)
{
	volumeReconstructVertex OUT;
	OUT.pos = float4( IN.pos.xyz, 1.0f);
	OUT.texCoord0 = IN.texCoord0;
	return(OUT);
}

// -------------------------------------------------------------
// Bilateral up-sampling. Preserves edge discontinuities. 
// -------------------------------------------------------------
float BilateralWeight( float fOriginal, float fSample)
{
	// Just like a gaussian weight but based on difference between samples
	// rather than distance from kernel center

	const float fDiff = fSample-fOriginal;
	//const float fDiffSqrd = fDiff * fDiff;
	//const float f2CoefSqrd = 2.0f * fBilateralCoef*fBilateralCoef;
	//static const float fTwoPi = 6.283185f;

	//float fWeight = ( 1.0f / ( fTwoPi * f2CoefSqrd ) ) * exp( -(fDiffSqrd) / f2CoefSqrd );
	float fExp = ( abs(fDiff)/g_fBilateralCoefficient );
	float fWeight = exp( -0.5f * ( fExp*fExp ) );
	return fWeight;
}

half3 VolumeUnPack(half3 c) { return UnpackHdr_3h(c); }
half3 VolumePack(half3 c) { return PackHdr_3h(c); }

half4 PS_VolumeLight_Interleave_Reconstruction( volumeReconstructVertex IN , bool bApplyDepthWeights, bool bAlphaClipped )
{
	float3 color = 0.0f;

	if ( bApplyDepthWeights )
	{
		// Using depth weights in 3*3 grid of pixels because the reconstruction is a blur. Any objects closer to 
		// camera would get a halo around them

		// +---+---+---+
		// | 1 | 4 | 6 |
		// +---+---+---+
		// | 2 | 0 | 7 |
		// +---+---+---+
		// | 3 | 5 | 8 |
		// +---+---+---+

		float2 vCoordUpLeft = IN.texCoord0.xy + float2(-0.5,-0.5) * gooScreenSize.xy;
		float2 vCoordDownRight = IN.texCoord0.xy + float2( 0.5, 0.5) * gooScreenSize.xy;

		#if __SHADERMODEL >= 50
			float4 vDepths2041 = gLowResDepthTexture.Gather(gLowResDepthSampler, vCoordUpLeft );
			float4 vDepths5870 = gLowResDepthTexture.Gather(gLowResDepthSampler, vCoordDownRight);
		#elif __SHADERMODEL >= 40
			float4 vDepths2041 = float4( gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy, int2(-1,  0)),
										 gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy),
										 gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy, int2( 0, -1)),
										 gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy, int2(-1, -1)) );
			float4 vDepths5870 = float4( gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy, int2(0, 1) ),
										 gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy, int2(1, 1) ),
										 gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy, int2(1, 0) ),
										 vDepths2041.y );
		#else
			float4 vDepths2041 = float4( tex2D(gLowResDepthSampler, IN.texCoord0.xy+int2(-1,  0)).x,
										 tex2D(gLowResDepthSampler, IN.texCoord0.xy).x,
										 tex2D(gLowResDepthSampler, IN.texCoord0.xy+int2( 0, -1)).x,
										 tex2D(gLowResDepthSampler, IN.texCoord0.xy+int2(-1, -1)).x );
			float4 vDepths5870 = float4( tex2D(gLowResDepthSampler, IN.texCoord0.xy+int2(0, 1)).x,
										 tex2D(gLowResDepthSampler, IN.texCoord0.xy+int2(1, 1)).x,
										 tex2D(gLowResDepthSampler, IN.texCoord0.xy+int2(1, 0)).x,
										 vDepths2041.y );
		#endif

	#if __SHADERMODEL >= 40
		float  fDepth3     = gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy, int2(-1, 1));
		float  fDepth6     = gLowResDepthTexture.Sample(gLowResDepthSampler, IN.texCoord0.xy, int2( 1,-1));
	#else
		float  fDepth3     = tex2D(gLowResDepthSampler, IN.texCoord0.xy+int2(-1, 1)).x;
		float  fDepth6     = tex2D(gLowResDepthSampler, IN.texCoord0.xy+int2( 1,-1)).x;
	#endif
		const float depths[9] = { vDepths2041.y, vDepths2041.w, vDepths2041.x, fDepth3, vDepths2041.z, vDepths5870.x, fDepth6, vDepths5870.z, vDepths5870.y };
		

	#if __SHADERMODEL >= 40
		const half3 colors[9] = {
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy).rgb),                // 0 
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2(-1,-1)).rgb),   // 1 
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2(-1, 0)).rgb),   // 2 
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2(-1, 1)).rgb),   // 3 
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 0,-1)).rgb),   // 4 
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 0, 1)).rgb),   // 5 
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 1,-1)).rgb),   // 6 
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 1, 0)).rgb),   // 7 
			VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 1, 1)).rgb) }; // 8 
	#else
		const half3 colors[9] = {
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy).rgb),                // 0 
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2(-1,-1)).rgb),   // 1 
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2(-1, 0)).rgb),   // 2 
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2(-1, 1)).rgb),   // 3 
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 0,-1)).rgb),   // 4 
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 0, 1)).rgb),   // 5 
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 1,-1)).rgb),   // 6 
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 1, 0)).rgb),   // 7 
			VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 1, 1)).rgb) }; // 8 
	#endif

		float weight = 0.0f;
		float fAccumWeight = 0.0f;
		float3 colorWithoutWeights = 0.0f;
		//Compute weights based on depth of center pixel
		[unroll] for( int i=0; i<9; i++ )
		{
			weight = BilateralWeight( depths[0], depths[i] );
			color += colors[i] * weight;
			colorWithoutWeights += colors[i];
			fAccumWeight += weight;
		}

		//Having additional check to see if only 1-3 pixels gets all the weightage
		//We might end up with completely contrasting pixels in this case
		//We check for condition to see if weights is less than 2. If so, then apply,
		//equal weights to all colors
		colorWithoutWeights.rgb /= 9.0f;
		color.rgb /= fAccumWeight.xxx;
		color.rgb = (fAccumWeight < 3.0f) ? colorWithoutWeights.rgb : color.rgb;
	}
	else
	{
	#if __SHADERMODEL >= 40
		float4 vCenterSample = gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy);
	#else
		float4 vCenterSample = tex2D(gVolumeLightsSampler, IN.texCoord0.xy);
	#endif

		if ( bAlphaClipped )
		{
			rageDiscard( vCenterSample.a < 0.5/255.0 );
		}

	#if __SHADERMODEL >= 40
		color = VolumeUnPack(vCenterSample.rgb);
		color += VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2(-1,-1)).rgb);
		color += VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2(-1, 0)).rgb);
		color += VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2(-1, 1)).rgb);
		color += VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 0,-1)).rgb);
		color += VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 0, 1)).rgb);
		color += VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 1,-1)).rgb);
		color += VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 1, 0)).rgb);
		color += VolumeUnPack(gVolumeLightsTexture.Sample(gVolumeLightsSampler, IN.texCoord0.xy, int2( 1, 1)).rgb);
		color /= 9.0f;	
	#else
		color = VolumeUnPack(vCenterSample.rgb);
		color += VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2(-1,-1)).rgb);
		color += VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2(-1, 0)).rgb);
		color += VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2(-1, 1)).rgb);
		color += VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 0,-1)).rgb);
		color += VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 0, 1)).rgb);
		color += VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 1,-1)).rgb);
		color += VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 1, 0)).rgb);
		color += VolumeUnPack(tex2D(gVolumeLightsSampler, IN.texCoord0.xy+int2( 1, 1)).rgb);
		color /= 9.0f;	
	#endif
	}

	color = VolumePack(color);

	return half4(color,1);
}

half4 PS_VolumeLight_Interleave_Reconstruction_Weighted(volumeReconstructVertex IN ):COLOR
{
	return PS_VolumeLight_Interleave_Reconstruction(IN, true, false);
}

half4 PS_VolumeLight_Interleave_Reconstruction_Unweighted_AlphaClipped(volumeReconstructVertex IN ):COLOR
{
	return PS_VolumeLight_Interleave_Reconstruction(IN, false, true);
}


technique volume_Interleave_Reconstruction
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_VolumeLight_Interleave_Reconstruction();
		PixelShader  = compile PIXELSHADER PS_VolumeLight_Interleave_Reconstruction_Weighted();
	}
	pass p1
	{
		VertexShader = compile VERTEXSHADER VS_VolumeLight_Interleave_Reconstruction();
		PixelShader  = compile PIXELSHADER PS_VolumeLight_Interleave_Reconstruction_Unweighted_AlphaClipped();
	}
}

#define DEF_TECHNIQUE_VOLUMESHAFT_PASS(type) \
	pass pass_volumeShaft_##type \
	{ \
		VertexShader = compile VERTEXSHADER VS_volumeShaft(); \
		PixelShader  = compile PIXELSHADER PS_volumeShaft_##type() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	}

#define DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,dtype) \
	half4 PS_volumeShaft_##vtype##_##dtype(vertexOutputVolumeShaft IN) : COLOR \
	{ \
		return volumeShaft_internal(IN, LIGHTSHAFT_VOLUMETYPE_##vtype, LIGHTSHAFT_DENSITYTYPE_##dtype); \
	}

#define DEF_TECHNIQUE_VOLUMESHAFT(vtype) \
	DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,CONSTANT          ) \
	DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,SOFT              ) \
	DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,SOFT_SHADOW       ) \
	DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,SOFT_SHADOW_HD    ) \
	DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,LINEAR            ) \
	DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,LINEAR_GRADIENT   ) \
	DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,QUADRATIC         ) \
	DEF_TECHNIQUE_VOLUMESHAFT_CODE(vtype,QUADRATIC_GRADIENT) \
	\
	technique volumeShaft_##vtype \
	{ \
		DEF_TECHNIQUE_VOLUMESHAFT_PASS(vtype##_CONSTANT          ) \
		DEF_TECHNIQUE_VOLUMESHAFT_PASS(vtype##_SOFT              ) \
		DEF_TECHNIQUE_VOLUMESHAFT_PASS(vtype##_SOFT_SHADOW       ) \
		DEF_TECHNIQUE_VOLUMESHAFT_PASS(vtype##_SOFT_SHADOW_HD    ) \
		DEF_TECHNIQUE_VOLUMESHAFT_PASS(vtype##_LINEAR            ) \
		DEF_TECHNIQUE_VOLUMESHAFT_PASS(vtype##_LINEAR_GRADIENT   ) \
		DEF_TECHNIQUE_VOLUMESHAFT_PASS(vtype##_QUADRATIC         ) \
		DEF_TECHNIQUE_VOLUMESHAFT_PASS(vtype##_QUADRATIC_GRADIENT) \
	}

DEF_TECHNIQUE_VOLUMESHAFT(SHAFT   )
DEF_TECHNIQUE_VOLUMESHAFT(CYLINDER)

#undef DEF_TECHNIQUE_VOLUMESHAFT
#undef DEF_TECHNIQUE_VOLUMESHAFT_CODE
#undef DEF_TECHNIQUE_VOLUMESHAFT_PASS
