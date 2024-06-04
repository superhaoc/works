#ifndef __LIGHT_STRUCTS
#define __LIGHT_STRUCTS

// ----------------------------------------------------------------------------------------------- //
// SHADER STURCTURES
// ----------------------------------------------------------------------------------------------- //

struct lightVertexInput
{
	float4 pos			: POSITION;
};

// ----------------------------------------------------------------------------------------------- //

struct lightVertexOutput
{
	DECLARE_POSITION(pos)
	float4 screenPos	: TEXCOORD0; 
	float4 eyeRay		: TEXCOORD1;
};

struct stencilOutput
{
	DECLARE_POSITION(pos)
};

// ----------------------------------------------------------------------------------------------- //
#if SAMPLE_FREQUENCY
#define SAMPLE_INDEX	IN.sampleIndex
#else
#define SAMPLE_INDEX	0
#endif

struct lightPixelInput
{
	DECLARE_POSITION(pos)
#if SAMPLE_FREQUENCY
	inside_sample float4 screenPos	: TEXCOORD0;
#else
	float4 screenPos				: TEXCOORD0;
#endif
	float4 eyeRay					: TEXCOORD1;
#if SAMPLE_FREQUENCY
	uint sampleIndex				: SV_SampleIndex;
#endif
};

// ----------------------------------------------------------------------------------------------- //

struct lightVertexVolumeOutput
{
	DECLARE_POSITION(pos)
	float3 worldPos				: TEXCOORD0;
	float4 screenPos			: TEXCOORD1; // z is intensity, w is oPos.w
	float3 intersectAndPlaneDist: TEXCOORD2; // x=t0, y=t1, z=t1's signed distance from view plane
	float3 gradient				: TEXCOORD3; // params for spherical gradient
#ifdef NVSTEREO
	float4 screenPosStereo		: TEXCOORD4;
#endif
};

// ----------------------------------------------------------------------------------------------- //

struct lightPixelVolumeInput
{
	DECLARE_POSITION_PSIN(pos)
	float3 worldPos				: TEXCOORD0;
	float4 screenPos			: TEXCOORD1;
	float3 intersectAndPlaneDist: TEXCOORD2;
	float3 gradient				: TEXCOORD3;
#ifdef NVSTEREO
	float4 screenPosStereo		: TEXCOORD4;
#endif
};

// ----------------------------------------------------------------------------------------------- //

struct lightVolumeData
{
	float2 intersect;
	float3 gradient;
};

// ----------------------------------------------------------------------------------------------- //

struct lightPixelOutput
{
	half4 col : COLOR;
};

// ----------------------------------------------------------------------------------------------- //

#endif
