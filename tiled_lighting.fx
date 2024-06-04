#pragma dcl position texcoord0 texcoord1 texcoord2 texcoord3

#define DEFERRED_UNPACK_LIGHT
#define DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS (0)
#define SPECULAR								   (1)
#define REFLECT									   (1)
#define REFLECT_DYNAMIC					   (1)

// Let get back as many registers as we can.
#pragma constant 18

#include "../common.fxh"
#include "../../Renderer/Lights/TiledLightingSettings.h"

#define SHADOW_CASTING            (0)
#define SHADOW_CASTING_TECHNIQUES (0)
#define SHADOW_RECEIVING          (1)
#define SHADOW_RECEIVING_VS       (0)
#include "Shadows/cascadeshadows.fxh"
#include "lighting.fxh"

#include "Lights/dir.fxh"
#include "../../../rage/base/src/shaderlib/rage_xplatformtexturefetchmacros.fxh"

/*
#if __SHADERMODEL>=40 && !RSG_ORBIS
	#define UNROLL(x)	[unroll(x)]
#else
	#define UNROLL(x)
#endif
*/

#define UNROLL(x)

#if __SHADERMODEL < 40
	#define InterlockedMin(x,y) x = min(x,y)
	#define InterlockedMax(x,y) x = max(x,y)
#endif

// =============================================================================================== //
// DEPTH DOWNSAMPLE
// =============================================================================================== //

BeginSampler(	sampler, downsampledDepth, downsampledDepthSampler, downsampledDepth)
ContinueSampler(sampler, downsampledDepth, downsampledDepthSampler, downsampledDepth)
AddressU  = CLAMP;        
AddressV  = CLAMP;
MINFILTER = POINT;
MAGFILTER = POINT;
MIPFILTER = POINT;
EndSampler;

BeginSampler	(sampler, TiledLightingTexture, TiledLightingSampler, TiledLightingTexture)
ContinueSampler	(sampler, TiledLightingTexture, TiledLightingSampler, TiledLightingTexture)
	AddressU  = CLAMP;        
	AddressV  = CLAMP;
	MINFILTER = POINT;
	MAGFILTER = POINT;
EndSampler;

// ----------------------------------------------------------------------------------------------- //
// VARIABLES
// ----------------------------------------------------------------------------------------------- //

BeginConstantBufferDX10( tiled_lighting_locals1 )

float4 srcTextureSize;
float4 dstTextureSize;
float  tiledPenumbraOffsetValue;
int	   tileSize;
uint4  screenRes;

EndConstantBufferDX10( tiled_lighting_locals1 )

// ----------------------------------------------------------------------------------------------- //
#if __SHADERMODEL >= 40
// ----------------------------------------------------------------------------------------------- //

// ----------------------------------------------------------------------------------------------- //
// STRUCTURES / SAMPLERS
// ----------------------------------------------------------------------------------------------- //

BeginDX10Sampler(sampler, TEXTURE2D_TYPE<float>, reductionDepthTexture, reductionDepthSampler, reductionDepthTexture)
ContinueSampler(sampler, reductionDepthTexture, reductionDepthSampler, reductionDepthTexture)
AddressU  = CLAMP;
AddressV  = CLAMP;
MINFILTER = POINT;
MAGFILTER = POINT;
MIPFILTER = POINT;
EndSampler;

// ----------------------------------------------------------------------------------------------- //

BeginDX10Sampler(sampler, TEXTURE2D_TYPE<float4>, reductionGBufferTexture, reductionGBufferSampler, reductionGBufferTexture)
ContinueSampler(sampler, reductionGBufferTexture, reductionGBufferSampler, reductionGBufferTexture)
AddressU  = CLAMP;        
AddressV  = CLAMP;
MINFILTER = POINT;
MAGFILTER = POINT;
MIPFILTER = POINT;
EndSharedSampler;

// ----------------------------------------------------------------------------------------------- //

struct vertexDepthOutput4
{
	DECLARE_POSITION(pos)
	float4 texcoord0			: TEXCOORD0;
	float4 texcoord1			: TEXCOORD1;
	float4 texcoord2			: TEXCOORD2;
	float4 texcoord3			: TEXCOORD3;
};

// ----------------------------------------------------------------------------------------------- //

struct pixelDepthInput4
{
	DECLARE_POSITION(pos)
	float4 texcoord0			: TEXCOORD0;
	float4 texcoord1			: TEXCOORD1;
	float4 texcoord2			: TEXCOORD2;
	float4 texcoord3			: TEXCOORD3;
};

// ----------------------------------------------------------------------------------------------- //

struct vertexDepthInput
{
	float3 pos					: POSITION;
	float4 texcoord0			: TEXCOORD0;
};

// ----------------------------------------------------------------------------------------------- //

RWTexture2D<float4> ReductionOutputTexture : register(u1);

// Shared memory
struct reductionStruct
{
	uint2	depthMinMax;	//x - min, y - max
	uint4	gBuffSamples;	//x - MaxX, y - max W, z - min W, w - is sky
};

// ----------------------------------------------------------------------------------------------- //

#if RSG_PC
	#define THREAD_GROUP_SIZE		16
	#define TG_SIZE_A				16
	#define TG_SIZE_B				8
	#if MULTISAMPLE_TECHNIQUES
		#define MAX_TILED_SAMPLES_A	4
		#define MAX_TILED_SAMPLES_B	16
	#else
		#define MAX_TILED_SAMPLES_A	1
		#define MAX_TILED_SAMPLES_B	1
	#endif
#else
	#define THREAD_GROUP_SIZE		 20
	#define TG_SIZE_A				20
	#define TG_SIZE_B				20
	#define MAX_TILED_SAMPLES_A		1
#endif

// ----------------------------------------------------------------------------------------------- //

// For MSAA case: 1024 == MAX_TILED_SAMPLES_A * TG_SIZE_A * TG_SIZE_A == MAX_TILED_SAMPLES_B * TG_SIZE_B * TG_SIZE_B
groupshared reductionStruct ReductionSharedMem[TG_SIZE_A * TG_SIZE_A * MAX_TILED_SAMPLES_A];

#define		DO_REDUCTION(s)	\
	ReductionSharedMem[ThreadIdx].depthMinMax.x = min(ReductionSharedMem[ThreadIdx].depthMinMax.x, ReductionSharedMem[ThreadIdx + s].depthMinMax.x);	\
	ReductionSharedMem[ThreadIdx].depthMinMax.y = max(ReductionSharedMem[ThreadIdx].depthMinMax.y, ReductionSharedMem[ThreadIdx + s].depthMinMax.y);	\
	ReductionSharedMem[ThreadIdx].gBuffSamples.w += ReductionSharedMem[ThreadIdx + s].gBuffSamples.w;

void DepthDownsampleCS_helper(uint2 OutCoord, uint ThreadIdx, uint TotalNumThreads, uint2 TexCoord, uint SampleId)
{
#if ENABLE_EQAA && 0 //not needed for 4s1f that we use in next-gen
	if (SampleId < gMSAANumFragments)
	{
#elif RSG_PC
	if (TexCoord.x < screenRes.x && TexCoord.y < screenRes.y
	#if MULTISAMPLE_TECHNIQUES
		&& SampleId < gMSAANumSamples
	#endif
	)
	{
#endif
		#if MULTISAMPLE_TECHNIQUES
			float depthSample = fixupGBufferDepth(reductionDepthTexture.Load(TexCoord, SampleId));
		#else
			float depthSample = fixupGBufferDepth(reductionDepthTexture[TexCoord + uint2(0, 0)]);
		#endif

		uint isNotSky = (depthSample < 1.0f);

		// Store in shared memory
		ReductionSharedMem[ThreadIdx].depthMinMax.x = asuint(depthSample);
		ReductionSharedMem[ThreadIdx].depthMinMax.y = asuint(depthSample);	
		ReductionSharedMem[ThreadIdx].gBuffSamples.w = !isNotSky;
#if (ENABLE_EQAA && 0) || RSG_PC
	}
	else
	{
		ReductionSharedMem[ThreadIdx].depthMinMax.x = asuint(FLT_MAX);
		ReductionSharedMem[ThreadIdx].depthMinMax.y = asuint(0.0f);	

		ReductionSharedMem[ThreadIdx].gBuffSamples.w = 0;
	}
#endif // ENABLE_EQAA || RSG_PC
	GroupMemoryBarrierWithGroupSync();

#if RSG_PC	
	if(TotalNumThreads >=512)
	{
		if(ThreadIdx < 256)	{ DO_REDUCTION(256); }	GroupMemoryBarrierWithGroupSync();
	}
	if(TotalNumThreads >=256)
	{
		if(ThreadIdx < 128)	{ DO_REDUCTION(128); }	GroupMemoryBarrierWithGroupSync();
	}

	if(TotalNumThreads >=128)
	{
		if(ThreadIdx < 64)	{ DO_REDUCTION(64); }	GroupMemoryBarrierWithGroupSync();
	}

	if(TotalNumThreads >=64)
	{
		if(ThreadIdx < 32)	{ DO_REDUCTION(32); }	GroupMemoryBarrierWithGroupSync();
	}
	
	if(ThreadIdx < 16)
	{
		if(TotalNumThreads >= 32)	DO_REDUCTION(16)
		if(TotalNumThreads >= 16)	DO_REDUCTION(8)
		if(TotalNumThreads >= 8)	DO_REDUCTION(4)
		if(TotalNumThreads >= 4)	DO_REDUCTION(2)
		if(TotalNumThreads >= 2)	DO_REDUCTION(1)
	}
#else
	// Parallel reduction
	UNROLL(10)	//TotalNumThreads == 2^10
	for(uint s = TotalNumThreads / 2; s > 0; s >>= 1)
	{
		if(ThreadIdx < s)
		{
			InterlockedMin(ReductionSharedMem[ThreadIdx].depthMinMax.x, ReductionSharedMem[ThreadIdx + s].depthMinMax.x);
			InterlockedMax(ReductionSharedMem[ThreadIdx].depthMinMax.y, ReductionSharedMem[ThreadIdx + s].depthMinMax.y);			

			ReductionSharedMem[ThreadIdx].gBuffSamples.w += ReductionSharedMem[ThreadIdx + s].gBuffSamples.w;
		}

		GroupMemoryBarrierWithGroupSync();
	}
#endif	

	// Have the first thread write out to the output texture
	if(ThreadIdx == 0)
	{
		float depthMin = asfloat(ReductionSharedMem[0].depthMinMax.x);
		float depthMax = asfloat(ReductionSharedMem[0].depthMinMax.y);

		half linearDepthMin = getLinearDepth(depthMin, deferredProjectionParams.zw);
		half linearDepthMax = getLinearDepth(depthMax, deferredProjectionParams.zw);

		bool isSkyFinal = (ReductionSharedMem[0].gBuffSamples.w == TotalNumThreads);

		ReductionOutputTexture[OutCoord] = float4(
		linearDepthMin, 
		linearDepthMax,
		isSkyFinal ? -1.0f : 0.0f, // add a quick test for full-sky tiles (-1)
		0.0f);
	}
}

// Defaut version of the downsample compute for non-MSAA
[numthreads(THREAD_GROUP_SIZE, THREAD_GROUP_SIZE, 1)]
void DepthDownsampleCS_Default(uint3 GroupID : SV_GroupID, uint3 GroupThreadID : SV_GroupThreadID)
{
	const uint ThreadIdx = (GroupThreadID.z * THREAD_GROUP_SIZE + GroupThreadID.y) * THREAD_GROUP_SIZE + GroupThreadID.x;
	const uint2 TexCoord = (GroupID.xy * THREAD_GROUP_SIZE + GroupThreadID.xy);
	
	DepthDownsampleCS_helper(GroupID.xy, ThreadIdx, THREAD_GROUP_SIZE*THREAD_GROUP_SIZE, TexCoord, 0);
}

#if RSG_PC
// Defaut version of the downsample compute, can be used for up to MSAA-4x, has standard tile size (16x16)
[numthreads(TG_SIZE_A, TG_SIZE_A, MAX_TILED_SAMPLES_A)]
void DepthDownsampleCS_A(uint3 GroupID : SV_GroupID, uint3 GroupThreadID : SV_GroupThreadID)
{
	const uint ThreadIdx = (GroupThreadID.z * TG_SIZE_A + GroupThreadID.y) * TG_SIZE_A + GroupThreadID.x;
	const uint2 TexCoord = (GroupID.xy * TG_SIZE_A + GroupThreadID.xy);
	uint numSamples = 1;
#if MULTISAMPLE_TECHNIQUES
	#if ENABLE_EQAA
		numSamples = min(MAX_TILED_SAMPLES_A, gMSAANumFragments);
	#else
		numSamples = min(MAX_TILED_SAMPLES_A, gMSAANumSamples);
	#endif
#endif
	
	DepthDownsampleCS_helper(GroupID.xy, ThreadIdx, numSamples*TG_SIZE_A*TG_SIZE_A, TexCoord, GroupThreadID.z);
}

// High-MSAA version that supports up to MSAA-16x at the cost of reduced tile size (8x8)
[numthreads(TG_SIZE_B, TG_SIZE_B, MAX_TILED_SAMPLES_B)]
void DepthDownsampleCS_B(uint3 GroupID : SV_GroupID, uint3 GroupThreadID : SV_GroupThreadID)
{
	const uint ThreadIdx = (GroupThreadID.z * TG_SIZE_B + GroupThreadID.y) * TG_SIZE_B + GroupThreadID.x;
	const uint2 TexCoord = (GroupID.xy * TG_SIZE_B + GroupThreadID.xy);
	uint numSamples = 1;
#if MULTISAMPLE_TECHNIQUES
	#if ENABLE_EQAA
		numSamples = min(MAX_TILED_SAMPLES_A, gMSAANumFragments);
	#else
		numSamples = min(MAX_TILED_SAMPLES_A, gMSAANumSamples);
	#endif
#endif

	DepthDownsampleCS_helper(GroupID.xy, ThreadIdx, numSamples*TG_SIZE_B*TG_SIZE_B, TexCoord, GroupThreadID.z);
}
#endif //RSG_PC

// ----------------------------------------------------------------------------------------------- //

vertexDepthOutput4 VS_depthDownSample4x2(vertexDepthInput IN)
{
	vertexDepthOutput4 OUT;
	OUT.pos		= float4(IN.pos.xy, 0, 1);
	float2 tex	= IN.texcoord0;

	OUT.texcoord0.xy = tex + float2(-1.5, -0.5) * srcTextureSize.zw;
	OUT.texcoord0.zw = tex + float2(-0.5, -0.5) * srcTextureSize.zw;

	OUT.texcoord1.xy = tex + float2( 0.5, -0.5) * srcTextureSize.zw;
	OUT.texcoord1.zw = tex + float2( 1.5, -0.5) * srcTextureSize.zw;

	OUT.texcoord2.xy = tex + float2(-1.5,  0.5) * srcTextureSize.zw;
	OUT.texcoord2.zw = tex + float2(-0.5,  0.5) * srcTextureSize.zw;

	OUT.texcoord3.xy = tex + float2( 0.5,  0.5) * srcTextureSize.zw;
	OUT.texcoord3.zw = tex + float2( 1.5,  0.5) * srcTextureSize.zw;

	return(OUT);
}

// ----------------------------------------------------------------------------------------------- //

float4 PS_minimumDepthDownSampleMain(pixelDepthInput4 IN): COLOR
{
	float4 info00 = tex2D(TiledLightingSampler,  IN.texcoord0.xy);
	float4 info10 = tex2D(TiledLightingSampler,  IN.texcoord0.zw);
	float4 info20 = tex2D(TiledLightingSampler,  IN.texcoord1.xy);
	float4 info30 = tex2D(TiledLightingSampler,  IN.texcoord1.zw);

	float4 info01 = tex2D(TiledLightingSampler,  IN.texcoord2.xy);
	float4 info11 = tex2D(TiledLightingSampler,  IN.texcoord2.zw);
	float4 info21 = tex2D(TiledLightingSampler,  IN.texcoord3.xy);
	float4 info31 = tex2D(TiledLightingSampler,  IN.texcoord3.zw);

	float4 depthMin0 = float4(info00.x, info10.x, info20.x, info30.x);
	float4 depthMin1 = float4(info01.x, info11.x, info21.x, info31.x);
	float4 depthMinV = min(depthMin0, depthMin1);
	const float  depthMin  = min(depthMinV.x, min(depthMinV.y, min(depthMinV.z, depthMinV.w)));

	return depthMin;
}

// ----------------------------------------------------------------------------------------------- //
// TECHNIQUES
// ----------------------------------------------------------------------------------------------- //

technique depthDownScale_sm50
{
	pass pBase_sm50
	{
		SetComputeShader(	compileshader( cs_5_0, DepthDownsampleCS_Default() ));
	}
#if RSG_PC
	pass pA_sm50
	{
		SetComputeShader(	compileshader( cs_5_0, DepthDownsampleCS_A() ));
	}
	pass pB_sm50
	{
		SetComputeShader(	compileshader( cs_5_0, DepthDownsampleCS_B() ));
	}
#endif // RSG_PC
}

technique minimumDepthDownScale
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_depthDownSample4x2();
		PixelShader  = compile PIXELSHADER PS_minimumDepthDownSampleMain()  PS4_TARGET(FMT_32_R);
	}
}


// =============================================================================================== //
// TILE LIGHTING RENDER
// =============================================================================================== //

// ----------------------------------------------------------------------------------------------- //
// STRUCTS
// ----------------------------------------------------------------------------------------------- //

struct vertexInputTile
{

#if __XENON
	int4 pos					: POSITION;		
	half4 data					: TEXCOORD0;	
#elif __PS3
	half4 pos					: POSITION;		
	half4 data					: TEXCOORD0;	
#else
	half4 pos					: POSITION;		
#if TILED_LIGHTING_INSTANCED_TILES
	half4 instanceData			: TEXCOORD0;
#endif //TILED_LIGHTING_INSTANCED_TILES
#endif
};

// ----------------------------------------------------------------------------------------------- //

struct vertexOutputTile
{
	DECLARE_POSITION(pos)
	float4 screenPos			: TEXCOORD0;
	float4 eyeRay				: TEXCOORD1;		
};

struct pixelInputTile
{
	DECLARE_POSITION(pos)
	float4 screenPos			: TEXCOORD0;
	float4 eyeRay				: TEXCOORD1;		
#if SAMPLE_FREQUENCY
	uint sampleIndex			: SV_SampleIndex;
#endif
};

// ----------------------------------------------------------------------------------------------- //
// FUNCTIONS
// ----------------------------------------------------------------------------------------------- //

#define LIGHT_ON			true
#define SPECULAR_ON			true
#define REFLECTION_ON		true
#define PENUMBRA_ON			true
#define SYNCHFILTER_ON		true

#define LIGHT_OFF			false
#define SPECULAR_OFF		false
#define REFLECTION_OFF		false
#define PENUMBRA_OFF		false
#define SYNCHFILTER_OFF		false

// ----------------------------------------------------------------------------------------------- //

#define GEN_TILED_DIRECTIONAL_FUNCS(name, directLight, specular, reflection ) \
vertexOutputTile JOIN(VS_lightTile_,name)(vertexInputTile IN) \
{ \
	return VS_lightTile(IN, directLight, specular, reflection); \
} \
\
half4 JOIN(PS_lightTile_,name)(pixelInputTile IN) : COLOR \
{ \
	float4 res = PS_lightTile(IN, directLight, specular, reflection); \
	return PackHdr(res); \
} \

// ----------------------------------------------------------------------------------------------- //

#define GEN_TILED_AMBIENT_FUNCS(name, directLight, specular, reflection) \
	vertexOutputTile JOIN(VS_lightTileAmbient_,name)(vertexInputTile IN) \
{ \
	return VS_lightTileAmbient(IN, directLight, specular, reflection); \
} \

// ----------------------------------------------------------------------------------------------- //
float rageTexDepth2DApprox(	float2 texCoords, int sample_index)
{
#if MULTISAMPLE_TECHNIQUES
	const int3 iPos = getIntCoords(texCoords, globalScreenSize.xy);
	return fixupGBufferDepth(gbufferTextureDepthGlobal.Load(iPos, sample_index).x);
#else
	return GBufferTexDepth2D( GBufferTextureSamplerDepthGlobal, texCoords);
#endif
}


float BlurShadowLookup( pixelInputTile IN, float2 posXY, float myDepth, float s, uniform bool useSynchronizedFiltering )
{
	float thresholdDepth=myDepth;
	const float th= (1-thresholdDepth)*0.0075f;
	// TODO - Use gather and int offsets
	const float2 offset = gooScreenSize.xy;
	
	float2 tex0,tex1,tex2,tex3;

	if (useSynchronizedFiltering)
	{
		tex0=posXY+ offset * float2(1.,0.);	   // move to tex2DOffset on the 360
		tex1=posXY + offset * float2(0.,1.);
		tex2=posXY + offset *float2(1.,1.);
	}
	else {
		tex0=posXY+ offset * float2(1.,2.);	   // move to tex2DOffset on the 360
		tex1=posXY + offset * float2(-1.,-2.);
		tex2=posXY + offset *float2(2.,-1.);
		tex3=posXY + offset *float2(-2.,1.);
	}

	// TODO - Come up with better sampling of the MSAA
	float4 depths = float4(rageTexDepth2DApprox(tex0, SAMPLE_INDEX).x,
						   rageTexDepth2DApprox(tex1, SAMPLE_INDEX).x,
						   rageTexDepth2DApprox(tex2, SAMPLE_INDEX).x,
						   useSynchronizedFiltering ? 0 :rageTexDepth2DApprox(tex3, SAMPLE_INDEX).x);
						  
	#if MULTISAMPLE_TECHNIQUES
	// TODO - Come up with better sampling of the MSAA surface
	// TODO: EQAA support
	const int2 iPos = getIntCoords(posXY, globalScreenSize);

		float4 shad= float4( gbufferTexture2Global.Load(iPos, SAMPLE_INDEX, int2( 1, 2)).w,
							 gbufferTexture2Global.Load(iPos, SAMPLE_INDEX, int2(-1,-2)).w,
							 gbufferTexture2Global.Load(iPos, SAMPLE_INDEX, int2( 2,-1)).w,
							 gbufferTexture2Global.Load(iPos, SAMPLE_INDEX, int2(-2, 1)).w);
	#else
		float4 shad= float4(  tex2D(GBufferTextureSampler2Global, tex0).w,
							  tex2D(GBufferTextureSampler2Global, tex1).w,
							  tex2D(GBufferTextureSampler2Global, tex2).w,
							useSynchronizedFiltering ? 0 :tex2D(GBufferTextureSampler2Global, tex3).w);	
	#endif

	float w;
	if ( useSynchronizedFiltering){
		float3 ws = abs(depths.xyz-myDepth.xxx)< th ? float3(1.,1.,1.): float3(0.,0.,0.);	
		
		w= dot( ws.xyz,float3(1,1,1) )+ 1.;
		s += dot(shad.xyz, ws);
	}
	else {
		float4 ws = abs(depths-myDepth)< th ? float4(1.,1.,1.,1.): float4(0.,0.,0.,0.);	
		w= dot( ws.xyzw,float4(1,1,1,1) )+ 1.;
		s += dot(shad, ws);	
	}

	return s/w;
}

float4 PS_lightTile(pixelInputTile IN, bool directLight, bool specular, bool reflection)
{
	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(IN.screenPos, IN.eyeRay, true, SAMPLE_INDEX);

	// Material properties
	materialProperties material = populateMaterialPropertiesDeferred(surfaceInfo); 
	
	// Surface properties
	surfaceProperties surface = populateSurfaceProperties(surfaceInfo, -deferredLightDirection, 0.0f); 

	// Light properties
	directionalLightProperties light;
	light.direction = deferredLightDirection;
	light.color = deferredLightColourAndIntensity.rgb;

	LightingResult res;
	res = directionalCalculateLighting(
		surface,
		material,
		light,
		specular,
		reflection,
		directLight,
			true,
				false,
				false,
			IN.screenPos,
			true,
			true,
			false,
			false,		// scatter
			false);		// useCloudShadows
	
	float4 OUT = float4(0.0f, 0.0f, 0.0f, 0.0f);
	Components components;

	OUT = ApplyLightToSurface(res, true, specular, reflection, components);

	OUT.rgb += calculateAmbient(
		true, 
		true, 
		true, 
		true, 
		surface, 
		material,
		components.Kd); 

	if (reflection) 
	{ 
		OUT.rgb += calculateReflection(
			surface.normal, 
			material, 
			res.surface.eyeDir, 
			1.0 - components.Kd, 
			false); 
	}

	OUT.rgb += material.diffuseColor.rgb * (material.emissiveIntensity * components.EdotN);

	OUT.a = surfaceInfo.specularSkinBlend; // on 360 inverse color bias applied in skin shader

	return OUT;
}

// ----------------------------------------------------------------------------------------------- //

vertexOutputTile VS_lightTileAmbient(vertexInputTile IN, bool directLight, bool specular, bool reflection)
{
	vertexOutputTile OUT;

#if TILED_LIGHTING_INSTANCED_TILES
	float widthMult = IN.pos.z;
	float heightMult = IN.pos.w;
	IN.pos.x += (IN.instanceData.x * widthMult);
	IN.pos.y += 1.0f - (IN.instanceData.y * heightMult);
	IN.pos.zw = IN.instanceData.zw;
#endif //TILED_LIGHTING_INSTANCED_TILES

	float2 pos = IN.pos.xy;
	OUT.pos	= float4((pos - 0.5f) * 2.0f, 0, 1); 
	OUT.screenPos = convertToVpos(OUT.pos, deferredLightScreenSize);
	OUT.eyeRay = GetEyeRay(OUT.pos.xy);	

	// Get tile data
	float4 tileData;
	tileData = tex2Dlod(downsampledDepthSampler, float4(IN.pos.zw, 0, 0));

	// Sky tiles
	OUT.pos *= (tileData.z >= 0.0f);

	if (!specular &&  reflection) { OUT.pos *= (tileData.z >  0.0f); }
	if (!specular && !reflection) { OUT.pos *= (tileData.z == 0.0f);}

	return(OUT);
}


// ----------------------------------------------------------------------------------------------- //

vertexOutputTile VS_lightTile(vertexInputTile IN, uniform bool directLight, uniform bool specular, uniform bool reflection)
{
	vertexOutputTile OUT;
	
#if TILED_LIGHTING_INSTANCED_TILES
	float widthMult = IN.pos.z;
	float heightMult = IN.pos.w;
	IN.pos.x += (IN.instanceData.x * widthMult);
	IN.pos.y += 1.0f - (IN.instanceData.y * heightMult);
	IN.pos.zw = IN.instanceData.zw;
#endif //TILED_LIGHTING_INSTANCED_TILES

	float2 pos = IN.pos.xy;
	OUT.pos	= float4((pos - 0.5f) * 2.0f, 0, 1); 
	OUT.screenPos = convertToVpos(OUT.pos, deferredLightScreenSize);
	OUT.eyeRay = GetEyeRay(OUT.pos.xy);	

	// Get tile data
	float4 tileData;
	tileData = tex2Dlod(downsampledDepthSampler, float4(IN.pos.zw, 0, 0));

	// Sky tiles
	OUT.pos *= (tileData.z >= 0.0f);

	if ( specular &&  reflection) { OUT.pos *= (tileData.z >  0.05f); }
	if ( specular && !reflection) { OUT.pos *= (tileData.z >  0.0f && tileData.z <= 0.05f); }
	if (!specular &&  reflection) { OUT.pos *= (tileData.z >  0.0f); }
	if (!specular && !reflection) { OUT.pos *= (tileData.z == 0.0f);}
	if (directLight) 	{ OUT.pos *= (tileData.w > 0.0f); } else { OUT.pos *= (tileData.w == 0.0f); }

	return(OUT);
}


// ----------------------------------------------------------------------------------------------- //

float3 transformToShadowSpace( float3 worldPos)
{
	float2 sp= worldPos.xy-float3(2000,3815,32.0);
	return float3(sp / 250.f,0.);
	//return float4(mul(worldPos, (float3x3)gWorld), 0);
}
bool InCascade( float2 bmin, float2 bmax )
{
	// intersection of bound with 0..1 bound
	return !( bmin.x<0 || bmin.y<0. || bmax.x > 1. || bmax.y > 1.);
}

const float widthMult = (1.f/96.f )*2.f;
const float heightMult = (1.f/54.f )*2.f;

vertexOutputTile VS_shadowTile(vertexInputTile IN )
{
	vertexOutputTile OUT;

	// mm could do a function and structure for below

	float2 pos = IN.pos.xy;
	OUT.pos	= float4((pos - 0.5f) * 2.0f, 0, 1); 
	OUT.screenPos = convertToVpos(OUT.pos, deferredLightScreenSize);
	OUT.eyeRay = GetEyeRay(OUT.pos.xy);	

	// Get tile data
	float4 tileData;
	tileData = tex2Dlod(downsampledDepthSampler, float4(IN.pos.zw, 0, 0));

	// calculate corner points.
	float2 pos0 = (IN.pos.zw - 0.5f) * 2.0f; 
	float2 pos1 = float2( pos0.x+widthMult, pos0.y);
	float2 pos2 = float2( pos0.x, pos0.y);
	float2 pos3 =float2( pos0.x+widthMult, pos0.y+heightMult);

	float3 eyeRay0 = GetEyeRay(pos0).xyz;

	// calculate box points
	float3 nearp = eyeRay0.xyz*tileData.x + gViewInverse[3].xyz;
	float3 farp = eyeRay0.xyz*tileData.y + gViewInverse[3].xyz;

	float3 snearp=transformToShadowSpace( nearp );
	float3 sfarp=transformToShadowSpace( farp );

	// create cascade space bound
	float2 bmin = min(snearp.xy, sfarp.xy);
	float2 bmax = max(snearp.xy, sfarp.xy);
	// check if either point is in the cascade.
	bool tileInCascade = InCascade( bmin, bmax);

	// Sky tiles
	OUT.pos *= tileInCascade;
	return(OUT);
}

half4 PS_shadowTile(pixelInputTile IN) : COLOR
{
	return 0.0f;
}

// ----------------------------------------------------------------------------------------------- //
// GLUE FUNCS
// ----------------------------------------------------------------------------------------------- //

GEN_TILED_DIRECTIONAL_FUNCS(full,			  LIGHT_ON,  SPECULAR_ON,  REFLECTION_ON)
GEN_TILED_DIRECTIONAL_FUNCS(ambient_refl,	  LIGHT_OFF, SPECULAR_OFF, REFLECTION_ON)
GEN_TILED_DIRECTIONAL_FUNCS(ambient,		  LIGHT_OFF, SPECULAR_OFF, REFLECTION_OFF)
GEN_TILED_DIRECTIONAL_FUNCS(directional,	  LIGHT_ON,  SPECULAR_OFF, REFLECTION_OFF)
GEN_TILED_DIRECTIONAL_FUNCS(directional_spec, LIGHT_ON,  SPECULAR_ON,  REFLECTION_OFF)

// ----------------------------------------------------------------------------------------------- //

GEN_TILED_AMBIENT_FUNCS(ambient_refl,		 LIGHT_OFF, SPECULAR_OFF, REFLECTION_ON)
GEN_TILED_AMBIENT_FUNCS(ambient,			 LIGHT_OFF, SPECULAR_OFF, REFLECTION_OFF)

// ----------------------------------------------------------------------------------------------- //
// TECHNIQUES
// ----------------------------------------------------------------------------------------------- //

technique MSAA_NAME(tiled_directional)
{
	#define DEF_PASS(type) \
	pass MSAA_NAME(type) \
	{ \
		VertexShader = compile VERTEXSHADER			JOIN(VS_lightTile_,type)(); \
		PixelShader  = compile MSAA_PIXEL_SHADER	JOIN(PS_lightTile_,type)() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	} \

	DEF_PASS(full)
	DEF_PASS(ambient_refl)
	DEF_PASS(ambient)
	DEF_PASS(directional)
	DEF_PASS(directional_spec)

	#undef DEF_PASS
}

// ----------------------------------------------------------------------------------------------- //


technique MSAA_NAME(tiled_ambient)
{
	#define DEF_PASS(type) \
	pass MSAA_NAME(type) \
		{ \
		VertexShader = compile VERTEXSHADER			JOIN(VS_lightTileAmbient_,type)(); \
		PixelShader  = compile MSAA_PIXEL_SHADER	JOIN(PS_lightTile_,type)() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	} \

	DEF_PASS(ambient_refl)
	DEF_PASS(ambient)

	#undef DEF_PASS
}

// ----------------------------------------------------------------------------------------------- //

technique MSAA_NAME(tiled_shadow)
{
	pass MSAA_NAME(p0) 
	{ 
		VertexShader = compile VERTEXSHADER			VS_shadowTile(); 
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_shadowTile() CGC_FLAGS(CGC_DEFAULTFLAGS); 
	}
}

// ----------------------------------------------------------------------------------------------- //
#else // __SHADERMODEL >= 40
// ----------------------------------------------------------------------------------------------- //

technique empty { pass empty {} }

// ----------------------------------------------------------------------------------------------- //
#endif // __SHADERMODEL >= 40
// ----------------------------------------------------------------------------------------------- //
