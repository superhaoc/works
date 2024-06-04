#pragma dcl position

#include "../../common.fxh"
#include "../../../renderer/SSAO_shared.h"
#include "../../../../rage/base/src/grcore/AA_shared.h"
#include "../../../../rage/base/src/shaderlib/rage_xplatformtexturefetchmacros.fxh"
// =============================================================================================== //
// SAMPLERS
// =============================================================================================== //

#define SUPPORT_MR	(__SHADERMODEL>=40)

#if SSAO_OUTPUT_DEPTH
#define DEPTH_OUT	SV_Depth
#else
#define DEPTH_OUT	SV_Target
#endif	//SSAO_OUTPUT_DEPTH

#define LocalSampler(type,semantics,name)	\
	BeginDX10Sampler(sampler, Texture2D<type>, semantics, name, semantics)

// ----------------------------------------------------------------------------------------------- //

BeginSampler(sampler, deferredLightTexture0P, gDeferredLightSampler0P, deferredLightTexture0P)
ContinueSampler(sampler, deferredLightTexture0P, gDeferredLightSampler0P, deferredLightTexture0P)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;


LocalSampler	(float4, PointTexture1, PointSampler1)
ContinueSampler	(sampler, PointTexture1, PointSampler1, PointTexture1)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
EndSampler;


// Used instead of PointSampler1 for MSAA compatibility.
BeginDX10Sampler(sampler, TEXTURE2D_TYPE<float4>, MSAAPointTexture1, MSAAPointSampler1, MSAAPointTexture1)
ContinueSampler	(sampler, MSAAPointTexture1, MSAAPointSampler1, MSAAPointTexture1)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
	MIPFILTER	= POINT;
EndSampler;

BeginDX10Sampler(sampler, TEXTURE2D_TYPE<float4>, MSAAPointTexture2, MSAAPointSampler2, MSAAPointTexture2)
ContinueSampler	(sampler, MSAAPointTexture2, MSAAPointSampler2, MSAAPointTexture2)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
	MIPFILTER	= POINT;
EndSampler;


LocalSampler	(float, PointTexture2, PointSampler2)
ContinueSampler	(sampler, PointTexture2, PointSampler2, PointTexture2)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
EndSampler;

#if (__SHADERMODEL >= 40)
LocalSampler	(float, PointTexture3, PointSampler3)
ContinueSampler	(sampler, PointTexture3, PointSampler3, PointTexture3)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
EndSampler;
#endif

BeginSampler	(sampler, LinearTexture1, LinearSampler1, LinearTexture1)
ContinueSampler	(sampler, LinearTexture1, LinearSampler1, LinearTexture1)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;

// ----------------------------------------------------------------------------------------------- //

#if! __PS3
LocalSampler	(float4, gbufferTexture2, GBufferTextureSampler2)
ContinueSampler(sampler, gbufferTexture2, GBufferTextureSampler2, gbufferTexture2)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
EndSampler;
#endif // !__PS3

// ----------------------------------------------------------------------------------------------- //

LocalSampler	(float, gbufferTextureDepth, GBufferTextureSamplerDepth)
ContinueSampler(sampler, gbufferTextureDepth, GBufferTextureSamplerDepth, gbufferTextureDepth)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
EndSampler;

// ----------------------------------------------------------------------------------------------- //

BeginSampler(sampler, deferredLightTexture2, gDeferredLightSampler2, deferredLightTexture2)
ContinueSampler(sampler, deferredLightTexture2, gDeferredLightSampler2, deferredLightTexture2)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;

#if SUPPORT_MR
// Used for MR SSAO g-buffer normals.
BeginDX10Sampler(sampler, TEXTURE2D_TYPE<float4>, PointTexture4, PointSampler4, PointTexture4)
ContinueSampler	(sampler, PointTexture4, PointSampler4, PointTexture4)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
	MIPFILTER	= POINT;
EndSampler;

// Used for MR SSAO g-buffer depths.
BeginDX10Sampler(sampler, TEXTURE_DEPTH_TYPE, PointTexture5, PointSampler5, PointTexture5)
ContinueSampler	(sampler, PointTexture5, PointSampler5, PointTexture5)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
	MIPFILTER	= POINT;
EndSampler;
#endif	//SUPPORT_MR

#if MULTISAMPLE_TECHNIQUES
// Used for custom depth resolves
BeginDX10Sampler(sampler, TEXTURE_DEPTH_TYPE, DepthResolveTexture, DepthResolveSampler, DepthResolveTexture)
ContinueSampler	(sampler, DepthResolveTexture, DepthResolveTexture, DepthResolveTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
	MIPFILTER	= POINT;
EndSampler;
#endif // MULTISAMPLE_TECHNIQUES

#if SUPPORT_HBAO
BeginDX10Sampler(sampler, TEXTURE_STENCIL_TYPE, StencilCopyTexture, StencilCopySampler, StencilCopyTexture)
ContinueSampler(sampler, StencilCopyTexture, StencilCopySampler, StencilCopyTexture)
	AddressU  = CLAMP;        
	AddressV  = CLAMP;
	MINFILTER = POINT;
	MAGFILTER = POINT;
	MIPFILTER = POINT;
EndSampler;
#endif

// =============================================================================================== //
// VARIABLES 
// =============================================================================================== //
BEGIN_RAGE_CONSTANT_BUFFER(ssao_locals,b0)
float4 g_projParams			: projectionParams;		// sx, sy, dscale, doffset 
float4 gNormalOffset		: NormalOffset;			// normal offset xy
float4 gOffsetScale0		: OffsetScale0;
float4 gOffsetScale1		: OffsetScale1;
float g_SSAOStrength		: SSAOStrength = 3.0;
float4 g_CPQSMix_QSFadeIn	: CPQSMix_QSFadeIn;		// Fade in start, end, unused, unused.

#if (__SHADERMODEL >= 40)
float4 TargetSizeParam; // Width, Height, 1/Width, 1/Height
float4 FallOffAndKernelParam; // Fall of distance, max half kernel size, normal weight power, depth weight power.
float4 g_MSAAPointTexture1_Dim : MSAAPointTexture1_Dim;
float4 g_MSAAPointTexture2_Dim : MSAAPointTexture2_Dim;
#endif

#if SUPPORT_HBAO
float4 gExtraParams0		: ExtraParams0; 
float4 gExtraParams1		: ExtraParams1;
float4 gExtraParams2		: ExtraParams2;
float4 gExtraParams3		: ExtraParams3;
float4 gExtraParams4		: ExtraParams4;

float3 gPerspectiveShearParams0 : PerspectiveShearParams0;
float3 gPerspectiveShearParams1 : PerspectiveShearParams1;
float3 gPerspectiveShearParams2 : PerspectiveShearParams2;

row_major SHARED float4x4 gPrevViewProj : PrevViewProj;
#endif

EndConstantBufferDX10(ssao_locals)

#if SUPPORT_HBAO
	#define g_HBAORadius0					gExtraParams0.x
	#define g_HBAORadius1					gExtraParams0.y
	#define g_HBAOCPRadius					gExtraParams0.z
	#define g_HBAOInvBlendDistance			gExtraParams0.w
	#define g_HBAOStrength					gExtraParams1.x
	#define g_HBAOCPStrength				gExtraParams1.y
	#define g_HBAOMaxPixels					gExtraParams1.z
	#define g_HBAOHybridCutoff				gExtraParams1.w
	#define g_HBAOTemporalThreshold			gExtraParams2.z
	#define g_HBAOContinuityThreshold		gExtraParams2.w
	#define g_HBAOTanBias					gExtraParams2.y
	#define g_HBAOMinMulSwitch				gExtraParams2.x
	#define	g_HBAOFoliageStrength			gExtraParams3.x
	#define g_HBAOFalloffExponent			gExtraParams3.y
	#define g_HBAOCPStrengthClose			gExtraParams3.z
	#define g_HBAOBlendDistanceMul			gExtraParams4.x
	#define	g_HBAOBlendDistanceAdd			gExtraParams4.y
#endif

#define g_CPQSMix_QSFadeIn_Start		g_CPQSMix_QSFadeIn.x
#define g_CPQSMix_QSFadeIn_Denominator	g_CPQSMix_QSFadeIn.y
#define g_NDirections_BaseOffset		g_CPQSMix_QSFadeIn.z
#define g_NDirections_Radius			g_CPQSMix_QSFadeIn.w

#define g_MSAAPointTexture1_Dimensions	float2(g_MSAAPointTexture1_Dim.x, g_MSAAPointTexture1_Dim.y)
#define g_MSAAPointTexture2_Dimensions	float2(g_MSAAPointTexture2_Dim.x, g_MSAAPointTexture2_Dim.y)


// =============================================================================================== //
// DATA STRUCTURES
// =============================================================================================== //

struct vertexInputLP
{
	float3	pos					: POSITION;		// Local-space position
	float2	TexCoord			: TEXCOORD;
};

// ----------------------------------------------------------------------------------------------- //

struct vertexOutputSSAO
{
	DECLARE_POSITION(pos)						// input expected in viewport space 0 to 1
	float4	pPos				: TEXCOORD0;
};

struct pixelInputSSAO
{
	DECLARE_POSITION_PSIN(pos)					// input expected in viewport space 0 to 1
	float4	pPos				: TEXCOORD0;
};

struct VS_OUTPUTBILATERAL
{
	DECLARE_POSITION(pos)						// input expected in viewport space 0 to 1
	float2	TexCoord0				: TEXCOORD0;
	float4	TexCoord1				: TEXCOORD1;
	float4	TexCoord2				: TEXCOORD2;
};

#if __SHADERMODEL >= 4 && !defined(SHADER_FINAL)
struct VS_OUTPUTBILATERAL_ENHANCED
{
	DECLARE_POSITION(pos)						// input expected in viewport space 0 to 1
	float2	TexCoord0				: TEXCOORD0;
	float4	TexCoord1				: TEXCOORD1;
	float4	TexCoord2				: TEXCOORD2;
	float4	TexCoord3				: TEXCOORD3;
	float4	TexCoord4				: TEXCOORD4;
	float4	TexCoord5				: TEXCOORD5;
	float4	TexCoord6				: TEXCOORD6;
};
#endif // __SHADERMODEL >= 4 && !defined(SHADER_FINAL)

struct VS_OUTPUTSSAO
{
	DECLARE_POSITION(pos)						// input expected in viewport space 0 to 1
	float4	TexCoord0			: TEXCOORD0;
	float4	TexCoord1			: TEXCOORD1;
};

struct VS_OUTPUTPMSSAO
{
	DECLARE_POSITION(pos)						// input expected in viewport space 0 to 1
	float4	TexCoord			: TEXCOORD0;
	float4	View				: TEXCOORD1;
};

// ----------------------------------------------------------------------------------------------- //

struct vertexOutputLP
{
	DECLARE_POSITION(pos)		// input expected in viewport space 0 to 1
};

// =============================================================================================== //
// HELPER / UTIILITY FUNCTIONS 
// =============================================================================================== //
float SampleSSAODepth(sampler2D depthSampler, float2 tex, float2 texelSize)
{
#if __XENON
	return _Tex2DOffset(depthSampler, tex, .5).x;
#elif __WIN32PC && __SHADERMODEL < 40
	return tex2D(		depthSampler, tex + texelSize/2).x;
#else //__PS3 || __SHADERMODEL >= 40
	return tex2D(		depthSampler, tex);
#endif
}

half hSampleSSAODepth(sampler2D depthSampler, half2 tex, half2 texelSize)
{
#if __XENON
	return _Tex2DOffset(depthSampler, tex, .5).x;
#elif __WIN32PC && __SHADERMODEL < 40
	return tex2D(		depthSampler, tex + texelSize/2).x;
#else //__PS3 || __SHADERMODEL >= 40
	return h1tex2D(		depthSampler, tex).x;
#endif
}

float SSAODecodeDepth ( float3 vCodedDepth )
{
    float fDepth;
    fDepth = -dot( vCodedDepth, float3(255.0f, 1.0f, 1.0f/255.0f) );
    return fDepth;
}

// ----------------------------------------------------------------------------------------------- //

int2 CalcCoord(float2 tex, float2 dimensions, bool useDimemnsionsMinus1)
{
	float2 fRet;
	float2 dimAdjust = float2(0.0f, 0.0f);

	if(useDimemnsionsMinus1)
	{
		dimAdjust = float2(1.0f, 1.0f);
	}
	float2 unused = modf(tex*(dimensions - dimAdjust) + float2(0.5f, 0.5f), fRet);
	return int2(fRet);
}

float4 ReadMSAAPointTexture1(float2 tex, bool useDimemnsionsMinus1)
{
	float unused;
	float2 dimensions;
#if MULTISAMPLE_TECHNIQUES	
	int2 tCoord = CalcCoord(tex, g_MSAAPointTexture1_Dimensions, useDimemnsionsMinus1);
	return MSAAPointTexture1.Load( tCoord, 0 );
#else

#if __SHADERMODEL >= 40	
	int2 tCoord = CalcCoord(tex, g_MSAAPointTexture1_Dimensions, useDimemnsionsMinus1);
	return MSAAPointTexture1.Load( int3(tCoord,0) );
#else
	return tex2D(MSAAPointSampler1, tex);
#endif // __SHADERMODEL >= 40
#endif // MULTISAMPLE_TECHNIQUES
}


float4 ReadMSAAPointTexture2(float2 tex, bool useDimemnsionsMinus1)
{
	float unused;
	float2 dimensions;
#if MULTISAMPLE_TECHNIQUES	
	int2 tCoord = CalcCoord(tex, g_MSAAPointTexture2_Dimensions, useDimemnsionsMinus1);
	return MSAAPointTexture2.Load( tCoord, 0 );
#else

#if __SHADERMODEL >= 40	
	int2 tCoord = CalcCoord(tex, g_MSAAPointTexture2_Dimensions, useDimemnsionsMinus1);
	return MSAAPointTexture2.Load( int3(tCoord,0) );
#else
	return tex2D(MSAAPointSampler2, tex);
#endif // __SHADERMODEL >= 40
#endif // MULTISAMPLE_TECHNIQUES
}

// ----------------------------------------------------------------------------------------------- //

float3 SSAOEncodeDepth ( float fDepth )
{
    float3 vCodedDepth;

    float d0=floor(fDepth)/255.0f;
    float d1=floor((fDepth-d0*255.0f)*255.0f)/255.0f;
    float d2=floor(((fDepth-d0*255.0f)-d1)*255.0f*255.0f)/255.0f;
    vCodedDepth = float3(d0, d1, d2);

	return vCodedDepth;
}

// ----------------------------------------------------------------------------------------------- //
// Bilateral weighting function.
// ----------------------------------------------------------------------------------------------- //

float BilateralWeight( float fOriginal, float fSample )
{
	// Just like a gaussian weight but based on difference between samples
	// rather than distance from kernel center
	float bilateralScale = -50;
	const float fDiff = fSample-fOriginal;
	float fExp = abs(fDiff)/fOriginal*bilateralScale;
	float fWeight = exp(fExp);
	return fWeight;

	// NOTE -- orthographic might not want to divide by fOriginal
}

half4 BilateralWeights4(half originalDepth, half4 sampleDepths)
{
	half bilateralScale	= -50;
	half4 depthDiff		= sampleDepths - originalDepth;
	half4 linearWeights	= abs(depthDiff)/originalDepth*bilateralScale;
	half4 weights		= exp(linearWeights);
	return weights;

	// NOTE -- orthographic might not want to divide by originalDepth
}

// ----------------------------------------------------------------------------------------------- //

float PS_SSAO_UPSCALE(float2 pPos)
{
#if __XENON
	float sampleAO = _Tex2DOffset(gDeferredLightSampler2, pPos, 0.5);
	return pow(sampleAO, g_SSAOStrength);
#elif __PS3
	return pow(tex2D(gDeferredLightSampler2, pPos.xy).x, g_SSAOStrength);
#else
	return pow(tex2D(gDeferredLightSampler2, pPos.xy).x, g_SSAOStrength);
#endif
}


float PS_SSAO_UPSCALE_NoPower(float2 pPos)
{
#if __XENON
	return _Tex2DOffset(gDeferredLightSampler2, pPos, 0.5);
#elif __PS3
	return tex2D(gDeferredLightSampler2, pPos.xy).x;
#else
	return tex2D(gDeferredLightSampler2, pPos.xy).x;
#endif
}


float4 PSCPSSAOUpscaleCommon(float2 pPos, float2 vPos)
{
#if __PS3
	return pow(tex2D(LinearSampler1, pPos.xy + (frac((vPos-.5)*.5)*2 - .5)/float2(gScreenSize.x, gScreenSize.y)).r, g_SSAOStrength);
#elif __WIN32PC || RSG_ORBIS
	return pow(tex2D(LinearSampler1, pPos.xy + (frac((vPos-.5)*.5)*2 - .5)*gooScreenSize.xy).r, g_SSAOStrength);
#else
	return pow(_Tex2DOffset(LinearSampler1, pPos.xy, .5).r, g_SSAOStrength);
#endif //__PS3
}


float4 PSCPSSAOUpscaleCommon_NoPower(float2 pPos, float2 vPos)
{
#if __PS3
	return tex2D(LinearSampler1, pPos.xy + (frac((vPos-.5)*.5)*2 - .5)/float2(gScreenSize.x, gScreenSize.y)).r;
#elif __WIN32PC || RSG_ORBIS
	return tex2D(LinearSampler1, pPos.xy + (frac((vPos-.5)*.5)*2 - .5)*gooScreenSize.xy).r;
#else
	return _Tex2DOffset(LinearSampler1, pPos.xy, .5).r;
#endif //__PS3
}


float4 PS_IsolateView(pixelInputSSAO IN) : COLOR
{
	return float4(tex2D(PointSampler1, IN.pPos.xy).rrr, 1);
}

// ----------------------------------------------------------------------------------------------- //
float4 SSAOCommon(float4 tex, float4 ntex, float2 texelSize, bool enhanced, out float depthAtTex)
{
	float depth		= SampleSSAODepth(PointSampler2, tex,     texelSize).x;
	float ndepth0	= SampleSSAODepth(PointSampler2, ntex.xy, texelSize).x;
	float ndepth1	= SampleSSAODepth(PointSampler2, ntex.zw, texelSize).x;

	depthAtTex = depth.x;
	
	float ao;

#if __SHADERMODEL >= 40 && !defined(SHADER_FINAL)
	if (enhanced)
	{
		// http://www.geeks3d.com/20100628/3d-programming-ready-to-use-64-sample-poisson-disc/
		const float4 pattern[32] =
		{
			float4(-0.613392, +0.617481,	+0.170019, -0.040254),
			float4(-0.299417, +0.791925,	+0.645680, +0.493210),
			float4(-0.651784, +0.717887,	+0.421003, +0.027070),
			float4(-0.817194, -0.271096,	-0.705374, -0.668203),
			float4(+0.977050, -0.108615,	+0.063326, +0.142369),
			float4(+0.203528, +0.214331,	-0.667531, +0.326090),
			float4(-0.098422, -0.295755,	-0.885922, +0.215369),
			float4(+0.566637, +0.605213,	+0.039766, -0.396100),
			float4(+0.751946, +0.453352,	+0.078707, -0.715323),
			float4(-0.075838, -0.529344,	+0.724479, -0.580798),
			float4(+0.222999, -0.215125,	-0.467574, -0.405438),
			float4(-0.248268, -0.814753,	+0.354411, -0.887570),
			float4(+0.175817, +0.382366,	+0.487472, -0.063082),
			float4(-0.084078, +0.898312,	+0.488876, -0.783441),
			float4(+0.470016, +0.217933,	-0.696890, -0.549791),
			float4(-0.149693, +0.605762,	+0.034211, +0.979980),
			float4(+0.503098, -0.308878,	-0.016205, -0.872921),
			float4(+0.385784, -0.393902,	-0.146886, -0.859249),
			float4(+0.643361, +0.164098,	+0.634388, -0.049471),
			float4(-0.688894, +0.007843,	+0.464034, -0.188818),
			float4(-0.440840, +0.137486,	+0.364483, +0.511704),
			float4(+0.034028, +0.325968,	+0.099094, -0.308023),
			float4(+0.693960, -0.366253,	+0.678884, -0.204688),
			float4(+0.001801, +0.780328,	+0.145177, -0.898984),
			float4(+0.062655, -0.611866,	+0.315226, -0.604297),
			float4(-0.780145, +0.486251,	-0.371868, +0.882138),
			float4(+0.200476, +0.494430,	-0.494552, -0.711051),
			float4(+0.612476, +0.705252,	-0.578845, -0.768792),
			float4(-0.772454, -0.090976,	+0.504440, +0.372295),
			float4(+0.155736, +0.065157,	+0.391522, +0.849605),
			float4(-0.620106, -0.328104,	+0.789239, -0.419965),
			float4(-0.545396, +0.538133,	-0.178564, -0.596057),
		};

		for (int i = 0; i < 64; i++)
		{
			float2 off0		= (i&1? pattern[i/2].zw : pattern[i/2].xy) * gOffsetScale1.xy;

			float tdepth	= SampleSSAODepth(PointSampler2, tex + off0, texelSize).x;

			float3 dir0		= float3(off0*g_projParams.xy*tdepth, tdepth - depth);

			float3 nPos0	= float3(gNormalOffset.xy*ndepth0, ndepth0 - depth);
			float3 nPos1	= float3(gNormalOffset.zw*ndepth1, ndepth1 - depth);

			float3 norm		= normalize(cross(nPos1, nPos0));

			float len		= length(dir0);
			float ndot		= dot(dir0, norm);

			ao += saturate(max(len/depth*5, (len-ndot)/len));
			//ao += saturate((len-ndot)/len);
		}

		ao /= 64;
	}
	else
#endif // __SHADERMODEL >= 40 && !defined(SHADER_FINAL)
	{
		float angle		= tex.z;
		float2 scx;
		sincos(angle, scx.x, scx.y);

		float2 off0		= float2(scx.x, scx.y)*gOffsetScale0.xy;
		float2 off1		= float2(scx.x, scx.y)*gOffsetScale0.zw;
		float2 off2		= float2(scx.y, scx.x)*gOffsetScale1.xy;
		float2 off3		= float2(scx.y, scx.x)*gOffsetScale1.zw;

		float4 dsamps;
		dsamps.x = tex2D(PointSampler2, tex + off0).x;
		dsamps.y = tex2D(PointSampler2, tex + off1).x;
		dsamps.z = tex2D(PointSampler2, tex + off2).x;
		dsamps.w = tex2D(PointSampler2, tex + off3).x;

		float4 tdepths	= dsamps;

		float3 dir0		= float3(off0*g_projParams.xy*tdepths.x,	tdepths.x - depth);
		float3 dir1		= float3(off1*g_projParams.xy*tdepths.y,	tdepths.y - depth);
		float3 dir2		= float3(off2*g_projParams.xy*tdepths.z,	tdepths.z - depth);
		float3 dir3		= float3(off3*g_projParams.xy*tdepths.w,	tdepths.w - depth);

		float3 nPos0	= float3(gNormalOffset.xy*ndepth0, ndepth0 - depth);
		float3 nPos1	= float3(gNormalOffset.zw*ndepth1, ndepth1 - depth);

		float3 norm		= normalize(cross(nPos1, nPos0));

		float4 len		= float4(length(dir0), length(dir1), length(dir2), length(dir3));
		float4 ndot		= float4(dot(dir0, norm), dot(dir1, norm), dot(dir2, norm), dot(dir3, norm));

		ao				= dot(saturate(max(len/depth*5, (len-ndot)/len)), 0.25);
	}

	float outAO		= pow(ao, g_SSAOStrength);

#if __XENON 
//Optimization for rolling exponential depth into second channel using G16R16 target, need to scale by 32 since G16R16 goes from -32 to 32
//on 360 EDRAM. Scaled down to 0-1 using expBias. TODO: Implement this optimization for PC and beyond, (without the expBias....)
	float expDepth  = pow(depth/4000, 1.0/64);
	return float4(outAO, expDepth, 0, 0)*32;
#elif __PS3
	float expDepth  = pow(depth/4000, 1.0/64);
	return unpack_4ubyte(pack_2ushort(float2(expDepth, outAO)));
#else
	return outAO;
#endif
}

float3 ReadGBufferNormal(float2 tex)
{
	return ReadMSAAPointTexture1(tex, true).rgb;
}


float3 ReadGBufferNormal_i(int2 tex)
{
#if MULTISAMPLE_TECHNIQUES
	return MSAAPointTexture1.Load( tex, 0 );
#else

#if __SHADERMODEL >= 40
	return MSAAPointTexture1.Load( int3(tex,0) );
#else
	return float3(0, 0, 0);
#endif // __SHADERMODEL >= 40
#endif // MULTISAMPLE_TECHNIQUES
}


float2 PSCPSSAOCommon(float2 pPos, float2 scx, bool orthographic)
{
	float2 tex = pPos;
	float2 offset = float2(16.0f, 16.0f)*gooScreenSize.xy;
	float3 norm		= mul(gViewInverse, float4(2*ReadGBufferNormal(tex).rgb - 1, 0));
	norm.yz			= -norm.yz;

#if SSAO_USE_LINEAR_DEPTH_TARGETS
	float depth		= tex2D(PointSampler2, tex).x;
#else
	float depth		= getLinearGBufferDepth(ReadMSAAPointTexture2(tex, true).x, g_projParams.zw);
#endif

	float oodepth	= 1.0/depth;

	float2	tScale = scx*offset;

	float2 aoTex	= tex + norm.xy*offset;
	float2 tex0		= aoTex + float2( .5, -1)*(tScale);
	float2 tex1		= aoTex + float2( -1, -.5)*(tScale);
	float2 tex2		= aoTex + float2(-.5, 1)*(tScale);
	float2 tex3		= aoTex + float2( 1, .5)*(tScale);

	float4	dsamps;
#if SSAO_USE_LINEAR_DEPTH_TARGETS
	dsamps.x		= tex2D(PointSampler2, tex0).x;
	dsamps.y		= tex2D(PointSampler2, tex1).x;
	dsamps.z		= tex2D(PointSampler2, tex2).x;
	dsamps.w		= tex2D(PointSampler2, tex3).x;
#else
	dsamps.x		= getLinearGBufferDepth(ReadMSAAPointTexture2(tex0, true).x, g_projParams.zw);
	dsamps.y		= getLinearGBufferDepth(ReadMSAAPointTexture2(tex1, true).x, g_projParams.zw);
	dsamps.z		= getLinearGBufferDepth(ReadMSAAPointTexture2(tex2, true).x, g_projParams.zw);
	dsamps.w		= getLinearGBufferDepth(ReadMSAAPointTexture2(tex3, true).x, g_projParams.zw);
#endif

	float4 tdepths = dsamps*oodepth;
	float3 rPos=float3((tex-0.5f)*g_projParams.xy,0.5f);
	float3 dir0=(float3((tex0-0.5f)*g_projParams.xy,0.5f)*tdepths.x)-rPos;
	float3 dir1=(float3((tex1-0.5f)*g_projParams.xy,0.5f)*tdepths.y)-rPos;
	float3 dir2=(float3((tex2-0.5f)*g_projParams.xy,0.5f)*tdepths.z)-rPos;
	float3 dir3=(float3((tex3-0.5f)*g_projParams.xy,0.5f)*tdepths.w)-rPos;

	float4 len=float4(length(dir0), length(dir1), length(dir2), length(dir3));
	float4 ndot = float4(dot(dir0, norm), dot(dir1, norm), dot(dir2, norm), dot(dir3, norm));
	float ao = dot(saturate(max(len*10, (len-ndot)/len)), 0.25);
	return float2(ao, depth.x);
}


float2 PSCPSSAOCommon4Directions(float2 pPos, float2 scx0, float2 scx1, float2 scx2, float2 scx3, bool orthographic)
{
	float2 tex = pPos;
	float2 offset = float2(16.0f, 16.0f)*gooScreenSize.xy;
	float3 norm		= mul(gViewInverse, float4(2*ReadGBufferNormal(tex).rgb - 1, 0));
	norm.yz			= -norm.yz;

#if __PS3 || ((RSG_PC || RSG_DURANGO || RSG_ORBIS) && SSAO_USE_LINEAR_DEPTH_TARGETS)
	float depth		= tex2D(PointSampler2, tex).x;
#elif (RSG_PC || RSG_DURANGO || RSG_ORBIS) && !SSAO_USE_LINEAR_DEPTH_TARGETS
	float dsamp		= ReadMSAAPointTexture2(tex, true).x;
	float depth		= getLinearGBufferDepth(dsamp.x, g_projParams.zw, orthographic);
#else
	float dsamp		= tex2D(GBufferTextureSamplerDepth, tex).x;
	float depth		= getLinearGBufferDepth(dsamp.x, g_projParams.zw, orthographic);
#endif

#if __PS3 || __WIN32PC || RSG_ORBIS
	float oodepth	= 1.002/depth;
#else
	float oodepth	= 1.0/depth;
#endif //__PS3 || __WIN32PC || RSG_ORBIS

	float2	tScale0 = scx0*offset;
	float2	tScale1 = scx1*offset;
	float2	tScale2 = scx2*offset;
	float2	tScale3 = scx3*offset;

	float2 aoTex	= tex + norm.xy*offset;
	float2 tex0		= aoTex + float2( .5, -1)*(tScale0);
	float2 tex1		= aoTex + float2( -1, -.5)*(tScale1);
	float2 tex2		= aoTex + float2(-.5, 1)*(tScale2);
	float2 tex3		= aoTex + float2( 1, .5)*(tScale3);

	float4	dsamps;
#if __PS3 || ((RSG_PC || RSG_DURANGO || RSG_ORBIS) && SSAO_USE_LINEAR_DEPTH_TARGETS)
	dsamps.x		= tex2D(PointSampler2, tex0).x;
	dsamps.y		= tex2D(PointSampler2, tex1).x;
	dsamps.z		= tex2D(PointSampler2, tex2).x;
	dsamps.w		= tex2D(PointSampler2, tex3).x;
#elif (RSG_PC || RSG_DURANGO || RSG_ORBIS) && !SSAO_USE_LINEAR_DEPTH_TARGETS
	dsamps.x		= ReadMSAAPointTexture2(tex0, true).x;
	dsamps.y		= ReadMSAAPointTexture2(tex1, true).x;
	dsamps.z		= ReadMSAAPointTexture2(tex2, true).x;
	dsamps.w		= ReadMSAAPointTexture2(tex3, true).x;
	dsamps			= getLinearGBufferDepth4(dsamps, g_projParams.zw, orthographic);
#else
	dsamps.x		= tex2D(GBufferTextureSamplerDepth, tex0).x;
	dsamps.y		= tex2D(GBufferTextureSamplerDepth, tex1).x;
	dsamps.z		= tex2D(GBufferTextureSamplerDepth, tex2).x;
	dsamps.w		= tex2D(GBufferTextureSamplerDepth, tex3).x;
	dsamps			= getLinearGBufferDepth4(dsamps, g_projParams.zw, orthographic);
#endif

	float4 tdepths = dsamps*oodepth;
	float3 rPos=float3((tex-0.5f)*g_projParams.xy,0.5f);
	float3 dir0=(float3((tex0-0.5f)*g_projParams.xy,0.5f)*tdepths.x)-rPos;
	float3 dir1=(float3((tex1-0.5f)*g_projParams.xy,0.5f)*tdepths.y)-rPos;
	float3 dir2=(float3((tex2-0.5f)*g_projParams.xy,0.5f)*tdepths.z)-rPos;
	float3 dir3=(float3((tex3-0.5f)*g_projParams.xy,0.5f)*tdepths.w)-rPos;

	float4 len=float4(length(dir0), length(dir1), length(dir2), length(dir3));
	float4 ndot = float4(dot(dir0, norm), dot(dir1, norm), dot(dir2, norm), dot(dir3, norm));
	float ao = dot(saturate(max(len*10, (len-ndot)/len)), 0.25);
	return float2(ao, depth.x);
}


half4 PSCPSSAOInternal(pixelInputSSAO IN, float4 vPos_unused, bool orthographic)
{
	// I think float vPos = IN.pos will work now...
#if __PS3
	float2 vPos = floor(IN.pPos.xy*float2(gScreenSize.x, gScreenSize.y));		
	float2 offset = float2(1.0/gScreenSize.x, 1.0/gScreenSize.y);
#elif __WIN32PC || RSG_ORBIS
	float2 vPos = floor(IN.pPos.xy*gScreenSize);		
	float2 offset = gooScreenSize;
#else
	float2 vPos = floor(IN.pPos.xy*float2(gScreenSize.x, gScreenSize.y));		
	float2 offset = float2(1.0/gScreenSize.x, 1.0/gScreenSize.y);
#endif

	float2 tex = IN.pPos.xy + offset;
	float4 ao;
	float4 d4;

	float2 tex0 = tex;
	float2 tex1 = tex + offset*float2(1,0);
	float2 tex2 = tex + offset*float2(0,1);
	float2 tex3 = tex + offset*float2(1,1);

	float outv;
	float2 aa;
	float2 scx;

	float angleOffset = .45;
	sincos(angleOffset*3.142, scx.x, scx.y);
	aa		= PSCPSSAOCommon(tex0, scx, orthographic);
	ao.x	= aa.x;
	d4.x	= aa.y;

	sincos((angleOffset+.25)*3.142, scx.x, scx.y);
	aa		= PSCPSSAOCommon(tex1, scx, orthographic);
	ao.y	= aa.x;
	d4.y	= aa.y;

	sincos((angleOffset+.5)*3.142, scx.x, scx.y);
	aa		= PSCPSSAOCommon(tex2, scx, orthographic);
	ao.z	= aa.x;
	d4.z	= aa.y;

	sincos((angleOffset+.75)*3.142, scx.x, scx.y);
	aa		= PSCPSSAOCommon(tex3, scx, orthographic);
	ao.w	= aa.x;
	d4.w	= aa.y;

	float dAverage = dot(d4, .25);
	float aAverage = dot(ao, .25);
	return aAverage;
}


half4 PSCPSSAOInternal_FullScreenTarget(pixelInputSSAO IN, float4 vPos_unused, bool orthographic)
{

#if RSG_PC || RSG_DURANGO || RSG_ORBIS
	float2 itex = IN.pos;
	float2 tex = IN.pos*gooScreenSize.xy;
#else
	float2 offset = float2(1.0/gScreenSize.x, 1.0/gScreenSize.y);
	float2 tex = IN.pPos.xy + offset;
	float2 itex = tex*gScreenSize.xy;
#endif

	float4 ao;
	float4 d4;
	float2 aa;
	float2 scx;

	float angleOffset = .45;
	sincos(angleOffset*3.142, scx.x, scx.y);
	aa		= PSCPSSAOCommon(tex, scx, orthographic);
	ao.x	= aa.x;
	d4.x	= aa.y;

	sincos((angleOffset+.25)*3.142, scx.x, scx.y);
	aa		= PSCPSSAOCommon(tex, scx, orthographic);
	ao.y	= aa.x;
	d4.y	= aa.y;

	sincos((angleOffset+.5)*3.142, scx.x, scx.y);
	aa		= PSCPSSAOCommon(tex, scx, orthographic);
	ao.z	= aa.x;
	d4.z	= aa.y;

	sincos((angleOffset+.75)*3.142, scx.x, scx.y);
	aa		= PSCPSSAOCommon(tex, scx, orthographic);
	ao.w	= aa.x;
	d4.w	= aa.y;

	float dAverage = dot(d4, .25);
	float aAverage = dot(ao, .25);
	return aAverage;
}


half4 PSCPSSAOInternal_FullScreenTarget_4Directions(pixelInputSSAO IN, float4 vPos_unused, bool orthographic)
{

#if RSG_PC || RSG_DURANGO || RSG_ORBIS
	float2 itex = IN.pos;
	float2 tex = IN.pos*gooScreenSize.xy;
#else
	float2 offset = float2(1.0/gScreenSize.x, 1.0/gScreenSize.y);
	float2 tex = IN.pPos.xy + offset;
	float2 itex = tex*gScreenSize.xy;
#endif

	float2 scx0;
	float2 scx1;
	float2 scx2;
	float2 scx3;

	float angleOffset = .45;
	sincos(angleOffset*3.142, scx0.x, scx0.y);
	sincos((angleOffset+.25)*3.142, scx1.x, scx1.y);
	sincos((angleOffset+.5)*3.142, scx2.x, scx2.y);
	sincos((angleOffset+.75)*3.142, scx3.x, scx3.y);
	float ret = PSCPSSAOCommon4Directions(tex, scx0, scx1, scx2, scx3, orthographic);
	return ret;
}

#define CP_8_DIRECTION_START 0.45f
#define CP_8_DIRECTION_DELTA (2.0f*3.14f/8.0f)

half4 PSCPSSAOInternal_FullScreenTarget_NDirections(pixelInputSSAO IN, float4 vPos_unused, bool orthographic)
{

#if RSG_PC || RSG_DURANGO || RSG_ORBIS
	float2 itex = IN.pos;
	float2 tex = IN.pos*gooScreenSize.xy;
#else
	float2 texoffset = float2(1.0/gScreenSize.x, 1.0/gScreenSize.y);
	float2 tex = IN.pPos.xy + texoffset;
	float2 itex = tex*gScreenSize.xy;
#endif

	float2 baseOffset = float2(g_NDirections_BaseOffset, g_NDirections_BaseOffset)*gooScreenSize.xy;
	float2 radiusOffset = float2(g_NDirections_Radius, g_NDirections_Radius)*gooScreenSize.xy;

#if __SHADERMODEL >= 40
	float3 norm		= mul(gViewInverse, float4(2*ReadGBufferNormal_i(int2(itex)).rgb - 1, 0));
#else
	float3 norm		= mul(gViewInverse, float4(2*ReadGBufferNormal(tex).rgb - 1, 0));
#endif
	norm.yz			= -norm.yz;

#if SSAO_USE_LINEAR_DEPTH_TARGETS
	float depth		= tex2D(PointSampler2, tex).x;
#else
	float depth		= getLinearGBufferDepth(ReadMSAAPointTexture2(tex, true).x, g_projParams.zw);
#endif

#if __PS3 || __WIN32PC || RSG_ORBIS
	float oodepth	= 1.002/depth;
#else
	float oodepth	= 1.0/depth;
#endif //__PS3 || __WIN32PC || RSG_ORBIS

	float2 aoTex = tex + norm.xy*baseOffset;
	float3 rPos	= float3((tex-0.5f)*g_projParams.xy,0.5f);
	float2 txOffset = radiusOffset*float2( .5, -1);

	const float4 directions[8] = {
		float4(sin(CP_8_DIRECTION_START + 0.0f*CP_8_DIRECTION_DELTA), cos(CP_8_DIRECTION_START + 0.0f*CP_8_DIRECTION_DELTA), 0.0f, 0.0f),
		float4(sin(CP_8_DIRECTION_START + 1.0f*CP_8_DIRECTION_DELTA), cos(CP_8_DIRECTION_START + 1.0f*CP_8_DIRECTION_DELTA), 0.0f, 0.0f),
		float4(sin(CP_8_DIRECTION_START + 2.0f*CP_8_DIRECTION_DELTA), cos(CP_8_DIRECTION_START + 2.0f*CP_8_DIRECTION_DELTA), 0.0f, 0.0f),
		float4(sin(CP_8_DIRECTION_START + 3.0f*CP_8_DIRECTION_DELTA), cos(CP_8_DIRECTION_START + 3.0f*CP_8_DIRECTION_DELTA), 0.0f, 0.0f),
		float4(sin(CP_8_DIRECTION_START + 4.0f*CP_8_DIRECTION_DELTA), cos(CP_8_DIRECTION_START + 4.0f*CP_8_DIRECTION_DELTA), 0.0f, 0.0f),
		float4(sin(CP_8_DIRECTION_START + 5.0f*CP_8_DIRECTION_DELTA), cos(CP_8_DIRECTION_START + 5.0f*CP_8_DIRECTION_DELTA), 0.0f, 0.0f),
		float4(sin(CP_8_DIRECTION_START + 6.0f*CP_8_DIRECTION_DELTA), cos(CP_8_DIRECTION_START + 6.0f*CP_8_DIRECTION_DELTA), 0.0f, 0.0f),
		float4(sin(CP_8_DIRECTION_START + 7.0f*CP_8_DIRECTION_DELTA), cos(CP_8_DIRECTION_START + 7.0f*CP_8_DIRECTION_DELTA), 0.0f, 0.0f),
	};


	int i;
	int N = 8;
	float totalAO = 0.0f;

	for(i=0; i<N; i++)
	{
		float dsamp;
		float2 tScale0 = float2(directions[i].x, directions[i].y)*txOffset;
		float2 tex0	= aoTex + tScale0;

#if SSAO_USE_LINEAR_DEPTH_TARGETS
		const float2 subPixelOffset = float2(0.0f, 1.0f) * gooScreenSize.xy;
		float2 itex0 = tex0 * gScreenSize.xy;
		tex0 += SSAIsOpaquePixel( floor(itex0) ) ? subPixelOffset : 0.0.xx;

		dsamp = tex2D(PointSampler2, tex0).x;
#else
		dsamp = getLinearGBufferDepth(ReadMSAAPointTexture2(tex0, true).x, g_projParams.zw);
#endif

		float tdepth = dsamp*oodepth;
		float3 dir0 = (float3((tex0-0.5f)*g_projParams.xy,0.5f)*tdepth)-rPos;
		float len = length(dir0);
		float ndot = dot(dir0, norm);
		float ao = saturate(max(len*10, (len-ndot)/len));
		totalAO += ao;
	}
	return totalAO/(float)N;
}



#if __PS3
#define VPOS_ARG ,float4 vPos: VPOS
#define VPOS_VAR vPos
#else
#define VPOS_ARG
#define VPOS_VAR 0
#endif

half4 PSCPSSAO(pixelInputSSAO IN VPOS_ARG) : COLOR
{
	return PSCPSSAOInternal(IN, VPOS_VAR, false);
}


#if !defined(SHADER_FINAL)
half4 PSCPSSAOOrthographic_BANK_ONLY(pixelInputSSAO IN VPOS_ARG) : COLOR
{
	return PSCPSSAOInternal(IN, VPOS_VAR, true);
}
#endif // !defined(SHADER_FINAL)

#undef VPOS_ARG
#undef VPOS_VAR

//============================================= Position Mapped SSAO ======================================================
float4 PS_PMSSAODownscaleCommon(VS_OUTPUTPMSSAO IN, bool orthographic)
{
	float4 d4 = 0;

#if __SHADERMODEL >= 40
	// NOTE:- No half pixel offset on DX11.
	d4.x	= getLinearGBufferDepth(tex2D(GBufferTextureSamplerDepth, IN.TexCoord.xy + float2(-0.5,-0.5)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
//	d4.x	= getLinearDepth(GBufferTexDepth2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2( 0.0, 0.0)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
//	d4.y	= getLinearDepth(GBufferTexDepth2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2( 0.0, 1.0)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
//	d4.z	= getLinearDepth(GBufferTexDepth2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2( 1.0, 0.0)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
//	d4.w	= getLinearDepth(GBufferTexDepth2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2( 1.0, 1.0)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
#else
	d4.x	= getLinearGBufferDepth(tex2D(GBufferTextureSamplerDepth, IN.TexCoord.xy + float2( 0.5, 0.5)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
	d4.y	= getLinearGBufferDepth(tex2D(GBufferTextureSamplerDepth, IN.TexCoord.xy + float2( 0.5, 1.5)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
	d4.z	= getLinearGBufferDepth(tex2D(GBufferTextureSamplerDepth, IN.TexCoord.xy + float2( 1.5, 0.5)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
	d4.w	= getLinearGBufferDepth(tex2D(GBufferTextureSamplerDepth, IN.TexCoord.xy + float2( 1.5, 1.5)*gooScreenSize.xy).x, g_projParams.zw, orthographic);
#endif

	d4.zw	= max(d4.xy, d4.zw);
	d4.w	= max(d4.z, d4.w);
	float	depth		= d4.w;
	float3	worldPos	= IN.View.xyz*depth*1.002;
	return float4(worldPos, 0);
}

float4 PS_PMSSAODownscale(VS_OUTPUTPMSSAO IN) : COLOR
{
	return PS_PMSSAODownscaleCommon(IN, false);
}

#if !defined(SHADER_FINAL)
float4 PS_PMSSAODownscaleOrthographic_BANK_ONLY(VS_OUTPUTPMSSAO IN) : COLOR
{
	return PS_PMSSAODownscaleCommon(IN, true);
}
#endif // !defined(SHADER_FINAL)

half PMSSAOCommon(half2 tex, half2 offsetTex, half3 V, bool orthographic)
{
	//half3 norm	= 2*h3tex2D(NormalSampler, tex).rgb - 1;
	half3 norm		= 2*ReadGBufferNormal(tex).rgb - 1;

	half dsamp		= tex2D(GBufferTextureSamplerDepth, tex).x;
	half depth		= getLinearGBufferDepth(dsamp.x, g_projParams.zw, orthographic);

	half2 offset	= 1.0f;

	half2 scale		= 48/half2(gScreenSize.x, gScreenSize.y);
	half3 worldPos	= V*depth;
	float3 dir0		= h3tex2D(PointSampler2, tex + offset*(1.00*scale)).rgb - worldPos;
	float3 dir1		= h3tex2D(PointSampler2, tex + offset*(0.75*scale)).rgb - worldPos;
	float3 dir2		= h3tex2D(PointSampler2, tex - offset*(0.50*scale)).rgb - worldPos;
	float3 dir3		= h3tex2D(PointSampler2, tex - offset*(0.25*scale)).rgb - worldPos;

	half4 len		= half4(length(dir0),		length(dir1),		length(dir2),		length(dir3));
	half4 ndot		= half4(dot(dir0, norm),	dot(dir1, norm),	dot(dir2, norm),	dot(dir3, norm));
	half ao			= dot(saturate(max(len/depth*5, (len - ndot)/len)), 0.25);
	return ao;
}

#if __PS3

half4 PS_PMSSAO(VS_OUTPUTPMSSAO IN) : COLOR
{
	return PMSSAOCommon(IN.TexCoord.xy, IN.TexCoord.zw, IN.View.xyz, false);
}

#if !defined(SHADER_FINAL)
half4 PS_PMSSAOOrthographic_BANK_ONLY(VS_OUTPUTPMSSAO IN) : COLOR
{
	return PMSSAOCommon(IN.TexCoord.xy, IN.TexCoord.zw, IN.View.xyz, true);
}
#endif // !defined(SHADER_FINAL)

#else // not __PS3

half4 PS_PMSSAOInternal(VS_OUTPUTPMSSAO IN, bool orthographic)
{
#if __PS3
	float2 texelSize = float2(1.0/gScreenSize.x, 1.0/gScreenSize.y);
#elif __WIN32PC || RSG_ORBIS
	float2 texelSize = gooScreenSize;
#else
	float2 texelSize = float2(1.0/gScreenSize.x, 1.0/gScreenSize.y);
#endif

	float2 tex	= IN.TexCoord.xy;
	float2 off	= IN.TexCoord.zw;
	float3 V	= IN.View.xyz;
	float ao	= 0;

	ao			+= PMSSAOCommon(tex,							off,							V, orthographic);
	ao			+= PMSSAOCommon(tex + texelSize*float2(1,0),	off + texelSize*float2(1,0),	V, orthographic);
	ao			+= PMSSAOCommon(tex + texelSize*float2(0,1),	off + texelSize*float2(0,1),	V, orthographic);
	ao			+= PMSSAOCommon(tex + texelSize*float2(1,1),	off + texelSize*float2(1,1),	V, orthographic);

	return ao;
}

half4 PS_PMSSAO(VS_OUTPUTPMSSAO IN) : COLOR
{
	return PS_PMSSAOInternal(IN, false);
}

#if !defined(SHADER_FINAL)
half4 PS_PMSSAOOrthographic_BANK_ONLY(VS_OUTPUTPMSSAO IN) : COLOR
{
	return PS_PMSSAOInternal(IN, true);
}
#endif // !defined(SHADER_FINAL)

#endif // not __PS3

half4 PS_Offset(pixelInputSSAO IN) : COLOR
{

	float2 tex		= IN.pPos;
	float angle	= dot(tex*32*1, float2(9.0f, 29.814f));

//#define _USE_DITHER_2 1
/*
	float2 vpos = IN.pPos*32;

	float sampleD	= frac(vpos.x*.25)*.25 + frac(vpos.y*.25);
	float angle		= sampleD*3.142f*4;
*/

	float2 offset;
	sincos(angle, offset.x, offset.y);

#if __PS3
	//return offset.xyxy;
	return unpack_4ubyte(pack_2half(offset));
#else
	return offset.xyxy;
#endif
}
//=========================================================================================================================

// =============================================================================================== //
// VS FUNCTIONS 
// =============================================================================================== //

#include "../../../../rage/base/src/grcore/fastquad_switch.h"

#if SSAO_UNIT_QUAD
BeginConstantBufferDX10(fastquad)
float4 QuadPosition;
float4 QuadTexCoords;
EndConstantBufferDX10(fastquad)

#define VIN	float2 pos :POSITION

#else
#define VIN	vertexInputLP IN
#endif	//SSAO_UNIT_QUAD


vertexOutputSSAO VS_screenTransformSSAO_Quad(VIN)
{
	vertexOutputSSAO OUT;
#if SSAO_UNIT_QUAD
	OUT.pos		= float4( QuadTransform(pos,QuadPosition), 0, 1);
	OUT.pPos.xy	= QuadTransform(pos,QuadTexCoords);
#else
	OUT.pos		= float4(IN.pos.xy, 0, 1);
	OUT.pPos.xy	= IN.TexCoord;
#endif	//SSAO_UNIT_QUAD
#if __PS3
	OUT.pPos.zw = OUT.pPos.xy*float2(1280, 720)/2;
#elif __WIN32PC
	OUT.pPos.zw = OUT.pPos.xy*gScreenSize/2;
#else
	OUT.pPos.zw = OUT.pPos.xy*float2(1280, 720)/2;
#endif
	return(OUT);
}

VS_OUTPUTBILATERAL VS_SSAOBilateralCommon(vertexInputLP IN, uniform bool horizontal)
{
	VS_OUTPUTBILATERAL OUT;
	OUT.pos				= float4(IN.pos.xy, 0, 1);
	OUT.TexCoord0		= IN.TexCoord;
	float2 texelSize	= gooScreenSize.xy*2.0f;
	if(horizontal)
	{
		OUT.TexCoord1		= IN.TexCoord.xyxy + float4(-3.5f,  0.5f, -1.5f, -0.5f)*texelSize.xyxy;
		OUT.TexCoord2		= IN.TexCoord.xyxy + float4( 1.5f,  0.5f,  3.5f, -0.5f)*texelSize.xyxy;
	}
	else
	{
		OUT.TexCoord1		= IN.TexCoord.xyxy + float4( 0.5f, -3.5f, -0.5f, -1.5f)*texelSize.xyxy;
		OUT.TexCoord2		= IN.TexCoord.xyxy + float4( 0.5f,  1.5f, -0.5f,  3.5f)*texelSize.xyxy;
	}
	return OUT;
}
VS_OUTPUTBILATERAL VS_SSAOBilateralX(vertexInputLP IN)
{
	return VS_SSAOBilateralCommon(IN, true);
}
VS_OUTPUTBILATERAL VS_SSAOBilateralY(vertexInputLP IN)
{
	return VS_SSAOBilateralCommon(IN, false);
}

#if __SHADERMODEL >= 4 && !defined(SHADER_FINAL)
VS_OUTPUTBILATERAL_ENHANCED VS_SSAOBilateralBlurEnhanced_BANK_ONLY(vertexInputLP IN)
{
	// =====================================
	// 12-tap sample pattern:
	//             +---+---+
	//             |       |
	//             +   x   +---+---+
	//             |       |       |
	//     +---+---+---+---+   x   +
	//     |       |       |       |
	//     +   x   +   x   +---+---+---+---+
	//     |       |       |       |       |
	// +---+---+---+---+---+   x   +   x   +
	// |       |       | x |       |       |
	// +   x   +   x   +---+---+---+---+---+
	// |       |       |       |       |
	// +---+---+---+---+   x   +   x   +
	//         |       |       |       |
	//         +   x   +---+---+---+---+
	//         |       |       |
	//         +---+---+   x   +
	//                 |       |
	//                 +---+---+
	// =====================================

	VS_OUTPUTBILATERAL_ENHANCED OUT;
	OUT.pos				= float4(IN.pos.xy, 0, 1);
	OUT.TexCoord0		= IN.TexCoord;
	float2 texelSize	= gooScreenSize.xy*2.0f;

	OUT.TexCoord1		= IN.TexCoord.xyxy + float4(-1.5f, +0.5f, -0.5f, +1.5f)*texelSize.xyxy;
	OUT.TexCoord2		= IN.TexCoord.xyxy + float4(+1.5f, -0.5f, +0.5f, -1.5f)*texelSize.xyxy;
	OUT.TexCoord3		= IN.TexCoord.xyxy + float4(-3.5f, +0.5f, -1.5f, +2.5f)*texelSize.xyxy;
	OUT.TexCoord4		= IN.TexCoord.xyxy + float4(+3.5f, -0.5f, +1.5f, -2.5f)*texelSize.xyxy;
	OUT.TexCoord5		= IN.TexCoord.xyxy + float4(+0.5f, +3.5f, -2.5f, -1.5f)*texelSize.xyxy;
	OUT.TexCoord6		= IN.TexCoord.xyxy + float4(-0.5f, -3.5f, +2.5f, +1.5f)*texelSize.xyxy;

	return OUT;
}
#endif // __SHADERMODEL >= 4 && 

vertexOutputSSAO VS_screenTransformSSAO(vertexInputLP IN)
{
	vertexOutputSSAO OUT;
	OUT.pos		= float4(IN.pos.xy, 0, 1);
	OUT.pPos.xy	= IN.TexCoord;
#if __PS3
	OUT.pPos.zw = OUT.pPos.xy*float2(gScreenSize.x, gScreenSize.y)/2;
#elif __WIN32PC
	OUT.pPos.zw = OUT.pPos.xy*gScreenSize/2;
#else
	OUT.pPos.zw = OUT.pPos.xy*float2(gScreenSize.x, gScreenSize.y)/2;
#endif
	return(OUT);
}

VS_OUTPUTSSAO VS_SSAO(vertexInputLP IN)
{
	VS_OUTPUTSSAO OUT;
	OUT.pos		= float4(IN.pos.xy, 0, 1);
	OUT.TexCoord0.xy	= IN.TexCoord;
	OUT.TexCoord0.z		= dot(IN.TexCoord*gScreenSize.xy*0.5f, float2(9.0f, 29.814f));
	OUT.TexCoord0.w		= 0;
	OUT.TexCoord1.xy	= IN.TexCoord + gooScreenSize*float2( 2, 0);
	OUT.TexCoord1.zw	= IN.TexCoord + gooScreenSize*float2( 0, 2);
	return(OUT);
}

VS_OUTPUTPMSSAO VS_PMSSAO(vertexInputLP IN)
{
	VS_OUTPUTPMSSAO OUT;
	OUT.pos			= float4(IN.pos.xy, 0, 1);
	OUT.TexCoord.xy	= IN.TexCoord;
#if __PS3
	OUT.TexCoord.zw = OUT.TexCoord.xy*float2(gScreenSize.x, gScreenSize.y)/32;
#elif __WIN32PC
	OUT.TexCoord.zw = OUT.TexCoord.xy*gScreenSize/32;
#else
	OUT.TexCoord.zw = OUT.TexCoord.xy*float2(gScreenSize.x, gScreenSize.y)/32;
#endif

	OUT.View		= float4(mul(float4(OUT.pos.xy * g_projParams.xy, -1, 0), gViewInverse).xyz, 1.0f);

	return(OUT);
}


// ----------------------------------------------------------------------------------------------- //

// Simple Passthrough Transform Vertex Shader
vertexOutputLP VS_screenTransform(vertexInputLP IN)
{
	vertexOutputLP OUT;
	OUT.pos = float4(IN.pos.xy, 0, 1);
	return(OUT);
}


// =============================================================================================== //
// PS FUNCTIONS
// =============================================================================================== //

half4 PS_SSAOUpscale(pixelInputSSAO IN) : COLOR
{
#if __XENON
	float4 sampleAO	= _Tex2DOffset(GBufferTextureSampler2, IN.pPos.xy, 0.5);
	sampleAO.xy		*= lerp(1.0f, PS_SSAO_UPSCALE(IN.pPos), gAmbientOcclusionEffect.w);
	return sampleAO;
#else
	float num = PS_SSAO_UPSCALE(IN.pPos.xy);
	return float4(0, 0, 0, num);
#endif
}

// ----------------------------------------------------------------------------------------------- //

half4 PS_dbgUpscaleSSAO_2_BANK_ONLY(pixelInputSSAO IN) : COLOR
{
#if __XENON
	float num = PS_SSAO_UPSCALE(IN.pPos);
	return float4(num.xxx, 1.0 * gInvColorExpBias);
#else
	float num = PS_SSAO_UPSCALE(IN.pPos.xy);
	return float4(num.xxx, 1.0);
#endif
}

half4 PS_dbgUpscaleSSAO_2_NoPower_BANK_ONLY(pixelInputSSAO IN) : COLOR
{
#if __XENON
	float num = PS_SSAO_UPSCALE_NoPower(IN.pPos);
	return float4(num.xxx, 1.0 * gInvColorExpBias);
#else
	float num = PS_SSAO_UPSCALE_NoPower(IN.pPos.xy);
	return float4(num.xxx, 1.0);
#endif
}

// ----------------------------------------------------------------------------------------------- //
half4 PSCPSSAOUpscale(pixelInputSSAO IN) : COLOR
{
#if __XENON
	float4 sampleAO	= _Tex2DOffset(GBufferTextureSampler2, IN.pPos.xy, 0.5);
	sampleAO.xy		*= lerp(1.0f, PSCPSSAOUpscaleCommon(IN.pPos, IN.pos).r, gAmbientOcclusionEffect.w);
	return sampleAO;
#else
	float num		= PSCPSSAOUpscaleCommon(IN.pPos.xy, IN.pos);
	return float4(0, 0, 0, num);
#endif
}
// ----------------------------------------------------------------------------------------------- //
half4 PSCPSSAOUpscaleIsolated(pixelInputSSAO IN) : COLOR
{
#if __XENON
	float num = PSCPSSAOUpscaleCommon(IN.pPos, IN.pos);
	return float4(num.xxx, 1.0 * gInvColorExpBias);
#else
	float num = PSCPSSAOUpscaleCommon(IN.pPos.xy, IN.pos);
	return float4(num.xxx, 1.0);
#endif
}

half4 PSCPSSAOUpscaleIsolated_NoPower(pixelInputSSAO IN) : COLOR
{
#if __XENON
	float num = PSCPSSAOUpscaleCommon_NoPower(IN.pPos, IN.pos);
	return float4(num.xxx, 1.0 * gInvColorExpBias);
#else
	float num = PSCPSSAOUpscaleCommon_NoPower(IN.pPos.xy, IN.pos);
	return float4(num.xxx, 1.0);
#endif
}
// ----------------------------------------------------------------------------------------------- //

#if SUPPORT_HBAO
// HBAO
float Length2(float3 V)
{
	return dot(V,V);
}

float3 MinDiff(float3 P, float3 Pr, float3 Pl)
{
    float3 V1 = Pr - P;
    float3 V2 = P - Pl;
    return (Length2(V1) < Length2(V2)) ? V1 : V2;
}

float2 SnapUVOffset(float2 uv)
{
    return round(uv * gScreenSize.xy) * gooScreenSize.xy;
}

float TanToSin(float x)
{
	return x * rsqrt(x*x + 1.0);
}

float InvLength(float2 V)
{
	return rsqrt(dot(V,V));
}

float Tangent(float3 V)
{
	return -V.z * InvLength(V.xy);
}

#define HBAO_STEPS (6)
#define HBAO_DIRECTIONS (3)

float3 FetchEyePos(float2 uv)
{		
	float3 P;	
	float depth = tex2Dlod(PointSampler2, float4(uv, 0, 0)).x;
	float2 projPos = (uv * float2(2, -2) + float2(-1, 1)) * g_projParams.xy;
	P = float3(projPos, 1) * depth;
	return P;
}

float BiasedTangent(float3 V)
{
	return Tangent(V) + g_HBAOTanBias;
}

float Tangent(float3 P, float3 S)
{
    return (P.z - S.z) * InvLength(S.xy - P.xy);
}

float3 TangentEyePos(float2 uv, float4 tangentPlane)
{
    // view vector going through the surface point at uv
    float3 V = FetchEyePos(uv);
    float NdotV = dot(tangentPlane.xyz, V);
    // intersect with tangent plane except for silhouette edges
    if (NdotV < 0.0) V *= (tangentPlane.w / NdotV);
    return V;
}

void ComputeSteps(inout float2 stepSizeUv, inout float numSteps, float rayRadiusPix, float rand)
{
    // Avoid oversampling if numSteps is greater than the kernel radius in pixels
    numSteps = min(HBAO_STEPS, rayRadiusPix);

    // Divide by Ns+1 so that the farthest samples are not fully attenuated
    float stepSizePix = rayRadiusPix / (numSteps + 1);

    // Clamp numSteps if it is greater than the max kernel footprint
    float maxNumSteps = g_HBAOMaxPixels / stepSizePix;
    if (maxNumSteps < numSteps)
    {
        // Use dithering to avoid AO discontinuities
        numSteps = floor(maxNumSteps + rand);
        numSteps = max(numSteps, 1);
        stepSizePix = g_HBAOMaxPixels / numSteps;
    }

    // Step size in uv space
    stepSizeUv = stepSizePix * gooScreenSize.xy;
}

float2 RotateDirections(float2 Dir, float2 CosSin)
{
    return float2(Dir.x*CosSin.x - Dir.y*CosSin.y,
                  Dir.x*CosSin.y + Dir.y*CosSin.x);
}

float horizon_occlusion(float2 deltaUV,
                        float2 texelDeltaUV,
                        float2 uv0,
                        float3 P,
                        float numSteps,
                        float randstep,
                        float3 dPdu,
                        float3 dPdv,
						float R2						
						)
{
    float ao = 0;

    // Randomize starting point within the first sample distance
    float2 uv = uv0 + SnapUVOffset( randstep * deltaUV );

    // Snap increments to pixels to avoid disparities between xy
    // and z sample locations and sample along a line
    deltaUV = SnapUVOffset( deltaUV );

    // Compute tangent vector using the tangent plane
    float3 T = deltaUV.x * dPdu + deltaUV.y * dPdv;

    float tanH = BiasedTangent(T);

    float sinH = tanH / sqrt(1.0f + tanH*tanH);

    for (float j = 1; j <= numSteps; ++j)
    {
        uv += deltaUV;
        float3 S = FetchEyePos(uv);
        float tanS = Tangent(P, S);
        float d2 = Length2(S - P);

        // Use a merged dynamic branch
        [branch]
		if ((d2 < R2) && (tanS > tanH))
        {
            // Accumulate AO between the horizon and the sample
            float sinS = tanS * rsqrt(1.0f + tanS*tanS);
			float falloff = 1.0 - d2 * rcp(R2);
			falloff = pow(falloff, g_HBAOFalloffExponent);
			ao += falloff * (sinS - sinH);

            // Update the current horizon angle
            tanH = tanS;
            sinH = sinS;
        }
    }

    return ao;
}

float HBAOHybrid(float2 tex, float3 norm, float rand)
{
	float2 offset = float2(16.0f, 16.0f)*gooScreenSize.xy * g_HBAOCPRadius;
	
	norm *= float3(1,-1, 1);

	float depth		= tex2D(PointSampler2, tex).x;
	
	//sky test
	#if MULTISAMPLE_TECHNIQUES
		if(depth > 9000.0f) return 1.0f;
	#endif

	float oodepth	= 1.0/depth;
	
	float2 scx;
	float angleOffset = .45 + rand;
	sincos(angleOffset*3.142, scx.x, scx.y);

	float2	tScale = scx*offset;
	float2 aoTex	= tex + norm.xy*offset;
	float2 tex0		= aoTex + float2( .5, -1)*(tScale);
	float2 tex1		= aoTex + float2( -1, -.5)*(tScale);
	float2 tex2		= aoTex + float2(-.5, 1)*(tScale);
	float2 tex3		= aoTex + float2( 1, .5)*(tScale);

	float4	dsamps;
	dsamps.x		= tex2D(PointSampler2, tex0).x;
	dsamps.y		= tex2D(PointSampler2, tex1).x;
	dsamps.z		= tex2D(PointSampler2, tex2).x;
	dsamps.w		= tex2D(PointSampler2, tex3).x;

	float4 tdepths = dsamps*oodepth;
	float3 rPos=float3((tex-0.5f)*g_projParams.xy,0.5f);
	float3 dir0=(float3((tex0-0.5f)*g_projParams.xy,0.5f)*tdepths.x)-rPos;
	float3 dir1=(float3((tex1-0.5f)*g_projParams.xy,0.5f)*tdepths.y)-rPos;
	float3 dir2=(float3((tex2-0.5f)*g_projParams.xy,0.5f)*tdepths.z)-rPos;
	float3 dir3=(float3((tex3-0.5f)*g_projParams.xy,0.5f)*tdepths.w)-rPos;

	float4 len=float4(length(dir0), length(dir1), length(dir2), length(dir3));
	float4 ndot = float4(dot(dir0, norm), dot(dir1, norm), dot(dir2, norm), dot(dir3, norm));
	float ao = dot(saturate(max(len*10, (len-ndot)/len)), 0.25);

	float cp_strength_mix = lerp(g_HBAOCPStrengthClose, g_HBAOCPStrength, saturate(depth * g_HBAOBlendDistanceMul + g_HBAOBlendDistanceAdd));
	return pow(ao, cp_strength_mix);
}

float rand_1_05(float2 uv)
{
    float2 noise = (frac(sin(dot(uv ,float2(12.9898,78.233)*2.0)) * 43758.5453));
    return abs(noise.x + noise.y) * 0.5;
}

float3 readNormalCS(float2 uv)
{
#if __SHADERMODEL >= 40
#if MULTISAMPLE_TECHNIQUES
	int2 iPos = int2(uv * g_MSAAPointTexture1_Dimensions);
	float3 raw =  MSAAPointTexture1.Load( iPos.xy, 0 ).xyz;
#else
	float3 raw = MSAAPointTexture1.SampleLevel( MSAAPointSampler1, uv, 0 ).xyz;
#endif

	float4 worldNormal = float4( raw*2 - 1, 0 );
	return mul(gViewInverse,worldNormal).xyz * float3(1,1,-1);
#else
	return float3(0,1,0);
#endif
}

float HBAOCommon(float2 TexCoord, bool useNormal, bool useHybrid)
{	
	float3 P = FetchEyePos(TexCoord);
	float2 tex0 = TexCoord;
	const float2 subPixelOffset = float2(0.0f, 0.5f) * gooScreenSize.xy;
	float2 itex0 = tex0 * 2.0 * gScreenSize.xy;
	tex0 += SSAIsOpaquePixel( floor(itex0) ) ? subPixelOffset : 0.0.xx;
	float3 norm		= readNormalCS(tex0);	

	float grass_mask = 0.0f;
	float sky_test = 0.0f;
	#if __SHADERMODEL > 40 && !MULTISAMPLE_TECHNIQUES
		uint4 stencil = StencilCopyTexture.GatherRed(StencilCopySampler, TexCoord);	

		sky_test = dot((stencil == 0x07), 0.25f);
		grass_mask = dot((stencil == 0x03), 0.25f) * g_HBAOFoliageStrength;
	#elif (__SHADERMODEL == 40)
		uint4 stencil;

		float2 coords[4];
		coords[0] = tex0 + float2(-0.5f, -0.5f) * gooScreenSize.xy;
		coords[1] = tex0 + float2( 0.5f, -0.5f) * gooScreenSize.xy;
		coords[2] = tex0 + float2(-0.5f,  0.5f) * gooScreenSize.xy;
		coords[3] = tex0 + float2( 0.5f,  0.5f) * gooScreenSize.xy;
		
		#if MULTISAMPLE_TECHNIQUES
			stencil.x = StencilCopyTexture.Load(coords[0] * gScreenSize.xy * 2, 0).g;
			stencil.y = StencilCopyTexture.Load(coords[1] * gScreenSize.xy * 2, 0).g;
			stencil.z = StencilCopyTexture.Load(coords[2] * gScreenSize.xy * 2, 0).g;
			stencil.w = StencilCopyTexture.Load(coords[3] * gScreenSize.xy * 2, 0).g;			
		#else
			stencil.x = StencilCopyTexture.Load(int3(coords[0] * gScreenSize.xy * 2, 0)).r;
			stencil.y = StencilCopyTexture.Load(int3(coords[1] * gScreenSize.xy * 2, 0)).r;
			stencil.z = StencilCopyTexture.Load(int3(coords[2] * gScreenSize.xy * 2, 0)).r;
			stencil.w = StencilCopyTexture.Load(int3(coords[3] * gScreenSize.xy * 2, 0)).r;
		#endif	

		sky_test = dot((stencil == 0x07), 0.25f);
		grass_mask = dot((stencil == 0x03), 0.25f) * g_HBAOFoliageStrength;
	#endif			
	if(sky_test > 0.0f)	return 1.0f;	

	float R = lerp(g_HBAORadius0, g_HBAORadius1, saturate(P.z * g_HBAOInvBlendDistance));
	float R2 = R * R;

	int2 ssC = int2(TexCoord * gScreenSize.xy);
	float randangle = rand_1_05(TexCoord);//(3 * ssC.x ^ ssC.y + ssC.x * ssC.y) * 10;
	float2 sc;
	sincos(randangle, sc.x, sc.y);
	
	float3 rand = float3(sc.y, sc.x, randangle);

    float2 ray_radius_uv = 0.5 * R * g_projParams.xy / P.z;
    float ray_radius_pix = ray_radius_uv.x * gScreenSize.x;
    //if (ray_radius_pix < 1) return 1.0;

    float numSteps;
    float2 step_size;
    ComputeSteps(step_size, numSteps, ray_radius_pix, rand.z);

	float3 Pr, Pl, Pt, Pb;
	if(useNormal)
	{
		float3 N = normalize(norm);
		float4 tangentPlane = float4(N, dot(P, N));

		Pr = TangentEyePos(TexCoord + float2(gooScreenSize.x, 0), tangentPlane);
		Pl = TangentEyePos(TexCoord + float2(-gooScreenSize.x, 0), tangentPlane);
		Pt = TangentEyePos(TexCoord + float2(0, gooScreenSize.y), tangentPlane);
		Pb = TangentEyePos(TexCoord + float2(0, -gooScreenSize.y), tangentPlane);
	}
	else
	{    
		Pr = FetchEyePos(TexCoord + float2(gooScreenSize.x, 0));
		Pl = FetchEyePos(TexCoord + float2(-gooScreenSize.x, 0));
		Pt = FetchEyePos(TexCoord + float2(0, gooScreenSize.y));
		Pb = FetchEyePos(TexCoord + float2(0, -gooScreenSize.y));	
	}
    // Screen-aligned basis for the tangent plane
    float3 dPdu = MinDiff(P, Pr, Pl);
    float3 dPdv = MinDiff(P, Pt, Pb) * (gScreenSize.y * gooScreenSize.x);
	
	
    float ao = 0;
    float d;
    float alpha = 2.0f * 3.14159265 / HBAO_DIRECTIONS;
    for (d = 0; d < HBAO_DIRECTIONS; ++d)
    {
         float angle = alpha * d;
         float2 dir = RotateDirections(float2(cos(angle), sin(angle)), rand.xy);
         float2 deltaUV = dir * step_size.xy;
         float2 texelDeltaUV = dir * gooScreenSize.xy;


		ao += horizon_occlusion(deltaUV, texelDeltaUV, TexCoord, P, numSteps, rand.z, dPdu, dPdv, R2);

    }	
	float hbao_strength = saturate(1.0 - grass_mask) * g_HBAOStrength;
    ao = saturate(1.0 - ao / HBAO_DIRECTIONS * hbao_strength);	
	
	if(useHybrid)
	{		
		float ao_cp = HBAOHybrid(TexCoord, norm, randangle);	

		//simple edge detection to avoid normal problems
		float4 depths = float4(Pl.z, Pr.z, Pb.z, Pt.z);
		float4 depth_diff = (P.z - depths) > 10.0f;		
		float edge_mask = max(depth_diff.x, max(depth_diff.y, max(depth_diff.z, depth_diff.w)));
		ao_cp = max(ao_cp, edge_mask);
		
		float ao_mix = lerp(min(ao,ao_cp), ao * ao_cp, g_HBAOMinMulSwitch);
		return lerp(ao_cp, ao_mix, saturate(ray_radius_pix * g_HBAOHybridCutoff));
	}
	return ao;
}

float4 PS_HBAO(pixelInputSSAO IN) : COLOR
{
	return HBAOCommon(IN.pPos.xy, false, false);
}

float4 PS_HBAONormal(pixelInputSSAO IN) : COLOR
{
	return HBAOCommon(IN.pPos.xy, true, false);
}

float4 PS_HBAONormalHybrid(pixelInputSSAO IN) : COLOR
{
	return HBAOCommon(IN.pPos.xy, true, true);
}

float4 PS_HBAOHybrid(pixelInputSSAO IN) : COLOR
{
	return HBAOCommon(IN.pPos.xy, false, true);
}
#endif //SUPPORT_HBAO

// ----------------------------------------------------------------------------------------------- //
float4 PS_SSAO(VS_OUTPUTSSAO IN) : COLOR
{
	float unused;
	return SSAOCommon(IN.TexCoord0, IN.TexCoord1, gooScreenSize*2, false, unused);
}

#if __SHADERMODEL >= 40 && !defined(SHADER_FINAL)
half4 PS_SSAOEnhanced_BANK_ONLY(VS_OUTPUTSSAO IN) : COLOR
{
	float unused;
	return SSAOCommon(IN.TexCoord0, IN.TexCoord1, gooScreenSize*2, true, unused);
}
#endif // __SHADERMODEL >= 40 && !defined(SHADER_FINAL)

float2 BilateralBlurG16R16(VS_OUTPUTBILATERAL IN)
{
	half2 tex			= IN.TexCoord0;

	//5 tap solution for 360 =======================================================
	float2 samples[5];
#if __XENON 
	samples[0]	= _Tex2DOffset(gDeferredLightSampler0P, tex,			 .5).xy;
	samples[1]	= _Tex2DOffset(gDeferredLightSampler0P, IN.TexCoord1.xy, .5).xy;
	samples[2]	= _Tex2DOffset(gDeferredLightSampler0P, IN.TexCoord1.zw, .5).xy;
	samples[3]	= _Tex2DOffset(gDeferredLightSampler0P, IN.TexCoord2.xy, .5).xy;
	samples[4]	= _Tex2DOffset(gDeferredLightSampler0P, IN.TexCoord2.zw, .5).xy;
#else
	samples[0]	= tex2D(gDeferredLightSampler0P, tex).xy;
	samples[1]	= tex2D(gDeferredLightSampler0P, IN.TexCoord1.xy).xy;
	samples[2]	= tex2D(gDeferredLightSampler0P, IN.TexCoord1.zw).xy;
	samples[3]	= tex2D(gDeferredLightSampler0P, IN.TexCoord2.xy).xy;
	samples[4]	= tex2D(gDeferredLightSampler0P, IN.TexCoord2.zw).xy;
#endif

	half4 aoValues		= half4(samples[1].x, samples[2].x, samples[3].x, samples[4].x);
	float4 depths		= float4(samples[1].y, samples[2].y, samples[3].y, samples[4].y);
	half ao				= samples[0].x;
	float depth			= samples[0].y;
	float scale			= 0.0008;
	float4 weights		= saturate(scale - abs(depths - depth))/scale;
	half ao2			= (ao + dot(weights, aoValues)*4)/(dot(weights, 4) + 1);
	//==============================================================================

	return float2(ao2, depth);	
}

half2 BilateralBlur(VS_OUTPUTBILATERAL IN)
{
	half2 tex			= IN.TexCoord0;
	half2 texelSize		= gooScreenSize.xy*2.0f;

	half centerAO		= hSampleSSAODepth(gDeferredLightSampler0P,	tex, texelSize);
	half centerDepth	= hSampleSSAODepth(PointSampler2,			tex, texelSize);

	half4 ao4;
	ao4.x		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord1.xy, texelSize);
	ao4.y		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord1.zw, texelSize);
	ao4.z		= hSampleSSAODepth(gDeferredLightSampler0P,	IN.TexCoord2.xy, texelSize);
	ao4.w		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord2.zw, texelSize);

	half4	depth4;
	depth4.x	= hSampleSSAODepth(PointSampler2, IN.TexCoord1.xy, texelSize).x;
	depth4.y	= hSampleSSAODepth(PointSampler2, IN.TexCoord1.zw, texelSize).x;
	depth4.z	= hSampleSSAODepth(PointSampler2, IN.TexCoord2.xy, texelSize).x;
	depth4.w	= hSampleSSAODepth(PointSampler2, IN.TexCoord2.zw, texelSize).x;

	half4 weight4		= BilateralWeights4(centerDepth, depth4);
	half weightedAO		= dot(ao4, weight4) + centerAO*0.25;
	// Normalize
	half ao1			= weightedAO/(dot(weight4, 1) + 0.25);
	
	return float2(ao1, 0);
}

float2 BilateralBlurCommon(VS_OUTPUTBILATERAL IN)
{
#if __XENON || __PS3
	return BilateralBlurG16R16(IN);
#else
	return BilateralBlur(IN);
#endif //__XENON
}

#if SUPPORT_HBAO
#define BILATERAL_RADIUS 8

float CrossBilateralWeight(float r, float d, float d0)
{
 const float BlurSigma = ((float)BILATERAL_RADIUS+1.0f) * 0.5f;
 const float BlurFalloff = 1.f / (2.0f*BlurSigma*BlurSigma);

 float dz = (d0 - d);
 return exp2(-r*r*BlurFalloff - dz*dz/d0 * 50.0);
}

float4 UnprojectToWorld(float2 uv, float z)
{
	float2 signedScreenPos = uv * float2(2, -2) + float2(-1, 1);
	const float3 transformVec = float3( signedScreenPos, 1.0 );
	float4 eyeRay = float4( dot( transformVec, gPerspectiveShearParams0), 
							dot( transformVec, gPerspectiveShearParams1),
							dot( transformVec, gPerspectiveShearParams2), 1);

	
	return float4(gViewInverse[3].xyz + (eyeRay.xyz * z), 1.0f);
}


float GaussBilateralBlurCommon(pixelInputSSAO IN, bool horizontal, bool temporal)
{
	float2 deltaUV = float2(1.0, 0.0);
	float2 texelSize = gooScreenSize.xy;

	if(!horizontal)
	{
		deltaUV = float2(0.0, 1.0);
	}
	
	float2 tex = IN.pPos;

	deltaUV *= gooScreenSize.xy;
	
	half centerAO		= hSampleSSAODepth(gDeferredLightSampler0P,	tex, texelSize);
	half centerDepth	= hSampleSSAODepth(PointSampler2,			tex, texelSize);
	
	float2 ao_total = centerAO;
	float w_total = 1.0f;
	
	float r = 1;
	for(; r <= BILATERAL_RADIUS/2; r += 1)
	{
		float2 uv = tex + r * deltaUV;
		
		half aoSample		= hSampleSSAODepth(gDeferredLightSampler0P,	uv, texelSize);
		half depthSample	= hSampleSSAODepth(PointSampler2,			uv, texelSize);

		float w = CrossBilateralWeight(r, depthSample, centerDepth);
		ao_total += aoSample * w;
		w_total += w;
	}
	for(; r <= BILATERAL_RADIUS; r += 2)
	{
		float2 uv = tex + (r + 0.5) * deltaUV;
		
		half aoSample		= hSampleSSAODepth(gDeferredLightSampler0P,	uv, texelSize);
		half depthSample	= hSampleSSAODepth(PointSampler2,			uv, texelSize);

		float w = CrossBilateralWeight(r, depthSample, centerDepth);
		ao_total += aoSample * w;
		w_total += w;
	}
	r = 1;
	for(; r <= BILATERAL_RADIUS/2; r += 1)
	{
		float2 uv = tex - r * deltaUV;
		
		half aoSample		= hSampleSSAODepth(gDeferredLightSampler0P,	uv, texelSize);
		half depthSample	= hSampleSSAODepth(PointSampler2,			uv, texelSize);

		float w = CrossBilateralWeight(r, depthSample, centerDepth);
		ao_total += aoSample * w;
		w_total += w;
	}
	
	for(; r <= BILATERAL_RADIUS; r += 2)
	{
		float2 uv = tex - (r + 0.5) * deltaUV;
		
		half aoSample		= hSampleSSAODepth(gDeferredLightSampler0P,	uv, texelSize);
		half depthSample	= hSampleSSAODepth(PointSampler2,			uv, texelSize);

		float w = CrossBilateralWeight(r, depthSample, centerDepth);
		ao_total += aoSample * w;
		w_total += w;
	}

	float ao = ao_total / w_total;

	if(temporal)
	{			
		float zi = centerDepth;
		float4 Pi = UnprojectToWorld(tex, zi);
		float2 uvi1 = mul(Pi, gPrevViewProj).xy / mul(Pi, gPrevViewProj).w * float2(0.5, -0.5) + 0.5f;

		uvi1 = round(gScreenSize.xy * uvi1 + 0.5) * gooScreenSize.xy;

		float zi1 = tex2D(LinearSampler1, uvi1).y;
		float4 Pi1 = UnprojectToWorld(uvi1, zi1);
			
		float wi = mul(Pi, gPrevViewProj).w;
		float wi1 = mul(Pi1, gPrevViewProj).w;	
		
		float isStablePixel = tex2D(PointSampler1, tex);

		if( abs(1 - wi/wi1) < g_HBAOTemporalThreshold && !isStablePixel )
		{
			float ao1 = tex2Dlod(LinearSampler1, float4(uvi1, 0, 0)).x;
			ao = (ao + ao1) * 0.5;
		}				
	}
	return ao;
}

float4 PS_SSAOGaussBilateralBlurX(pixelInputSSAO IN) : COLOR
{
	return GaussBilateralBlurCommon(IN, true, false).x;
}

float4 PS_SSAOGaussBilateralBlurY(pixelInputSSAO IN) : COLOR
{
	return GaussBilateralBlurCommon(IN, false, false).x;
}

float4 PS_SSAOGaussBilateralBlurYTemporal(pixelInputSSAO IN) : COLOR
{
	return GaussBilateralBlurCommon(IN, false, true).x;
}

float4 PS_SSAOTemporalCopy(pixelInputSSAO IN) : COLOR
{
	float2 tex = IN.pPos.xy;
	half aoSample		= hSampleSSAODepth(gDeferredLightSampler0P,	tex, gooScreenSize.xy);
	half depthSample	= hSampleSSAODepth(PointSampler2,			tex, gooScreenSize.xy);

	return float4(aoSample, depthSample, 0.0f, 0.0f);
}

float4 PS_HBAOContinuityMask(pixelInputSSAO IN) : COLOR
{
	float2 tex = IN.pPos.xy;
	
	float3 P;
	P = FetchEyePos(tex);
		
    float3 Pr, Pl, Pt, Pb;
    Pr = FetchEyePos(tex + float2(gooScreenSize.x, 0));
    Pl = FetchEyePos(tex + float2(-gooScreenSize.x, 0));
    Pt = FetchEyePos(tex + float2(0, gooScreenSize.y));
    Pb = FetchEyePos(tex + float2(0, -gooScreenSize.y));
	
	float3 Px = length(P - Pl) < length(P - Pr) ? Pl : Pr;
	float3 Py = length(P - Pt) < length(P - Pb) ? Pt : Pb;

	float L = g_HBAOContinuityThreshold;
	return (length(Px - P) < L && length(Py - P) < L);
}

float4 GatherRedPointSampler(float2 tex, float2 offset)
{
	float4 result;
	offset *= gooScreenSize.xy;
	result.x = h1tex2D(PointSampler1, tex + offset + float2(-0.5,-0.5)*gooScreenSize.xy);
	result.y = h1tex2D(PointSampler1, tex + offset + float2(-0.5, 0.5)*gooScreenSize.xy);
	result.z = h1tex2D(PointSampler1, tex + offset + float2( 0.5,-0.5)*gooScreenSize.xy);
	result.w = h1tex2D(PointSampler1, tex + offset + float2( 0.5, 0.5)*gooScreenSize.xy);
	return result;
}
float4 DilateContinuityMask(float2 tex, bool useGather)
{	
#if __SHADERMODEL >= 40
	if(useGather)
	{
		float4 tex0 = PointTexture1.GatherRed(PointSampler1, tex, int2(-1, -1));
		float4 tex1 = PointTexture1.GatherRed(PointSampler1, tex, int2(-1,  1));
		float4 tex2 = PointTexture1.GatherRed(PointSampler1, tex, int2( 1,  1));
		float4 tex3 = PointTexture1.GatherRed(PointSampler1, tex, int2( 1, -1));

		float4 mask = float4(all(tex0), all(tex1), all(tex2), all(tex3));
		return all(mask);
	}
	else
#endif
	{
		float4 tex0 = GatherRedPointSampler(tex, float2(-1, -1));
		float4 tex1 = GatherRedPointSampler(tex, float2(-1,  1));
		float4 tex2 = GatherRedPointSampler(tex, float2( 1,  1));
		float4 tex3 = GatherRedPointSampler(tex, float2( 1, -1));

		float4 mask = float4(all(tex0), all(tex1), all(tex2), all(tex3));
		return all(mask);
	}	
}

float4 PS_SSAODilateContinuityMask(pixelInputSSAO IN) : COLOR
{
	return DilateContinuityMask(IN.pPos.xy, true);
}
float4 PS_SSAODilateContinuityMaskNoGather(pixelInputSSAO IN) : COLOR
{
	return DilateContinuityMask(IN.pPos.xy, false);
}
#endif //SUPPORT_HBAO

float4 PS_SSAOBilateralBlurY(VS_OUTPUTBILATERAL IN) : COLOR
{
	return BilateralBlurCommon(IN).x;
}

#if __XENON
float4 PS_SSAOBilateralBlurX(VS_OUTPUTBILATERAL IN) : COLOR
{
	return float4(BilateralBlurCommon(IN).xy, 0, 0)*32;
}
#elif __PS3
float4 PS_SSAOBilateralBlurX(VS_OUTPUTBILATERAL IN) : COLOR
{
	return unpack_4ubyte(pack_2ushort(BilateralBlurCommon(IN).yx));
}
#else
#define PS_SSAOBilateralBlurX PS_SSAOBilateralBlurY
#endif //__XENON

#if __SHADERMODEL >= 40 && !defined(SHADER_FINAL)
half4 PS_SSAOBilateralBlurEnhanced_BANK_ONLY(VS_OUTPUTBILATERAL_ENHANCED IN) : COLOR
{
	half2 tex			= IN.TexCoord0;
	half2 texelSize		= gooScreenSize.xy*2.0f;

	half centerAO		= hSampleSSAODepth(gDeferredLightSampler0P,	tex, texelSize);
	half centerDepth	= hSampleSSAODepth(PointSampler2,			tex, texelSize);

	half4 ao4a;
	half4 ao4b;
	half4 ao4c;
	ao4a.x		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord1.xy, texelSize);
	ao4a.y		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord1.zw, texelSize);
	ao4a.z		= hSampleSSAODepth(gDeferredLightSampler0P,	IN.TexCoord2.xy, texelSize);
	ao4a.w		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord2.zw, texelSize);
	ao4b.x		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord3.xy, texelSize);
	ao4b.y		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord3.zw, texelSize);
	ao4b.z		= hSampleSSAODepth(gDeferredLightSampler0P,	IN.TexCoord4.xy, texelSize);
	ao4b.w		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord4.zw, texelSize);
	ao4c.x		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord5.xy, texelSize);
	ao4c.y		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord5.zw, texelSize);
	ao4c.z		= hSampleSSAODepth(gDeferredLightSampler0P,	IN.TexCoord6.xy, texelSize);
	ao4c.w		= hSampleSSAODepth(gDeferredLightSampler0P, IN.TexCoord6.zw, texelSize);

	half4	depth4a;
	half4	depth4b;
	half4	depth4c;
	depth4a.x	= hSampleSSAODepth(PointSampler2, IN.TexCoord1.xy, texelSize).x;
	depth4a.y	= hSampleSSAODepth(PointSampler2, IN.TexCoord1.zw, texelSize).x;
	depth4a.z	= hSampleSSAODepth(PointSampler2, IN.TexCoord2.xy, texelSize).x;
	depth4a.w	= hSampleSSAODepth(PointSampler2, IN.TexCoord2.zw, texelSize).x;
	depth4b.x	= hSampleSSAODepth(PointSampler2, IN.TexCoord3.xy, texelSize).x;
	depth4b.y	= hSampleSSAODepth(PointSampler2, IN.TexCoord3.zw, texelSize).x;
	depth4b.z	= hSampleSSAODepth(PointSampler2, IN.TexCoord4.xy, texelSize).x;
	depth4b.w	= hSampleSSAODepth(PointSampler2, IN.TexCoord4.zw, texelSize).x;
	depth4c.x	= hSampleSSAODepth(PointSampler2, IN.TexCoord5.xy, texelSize).x;
	depth4c.y	= hSampleSSAODepth(PointSampler2, IN.TexCoord5.zw, texelSize).x;
	depth4c.z	= hSampleSSAODepth(PointSampler2, IN.TexCoord6.xy, texelSize).x;
	depth4c.w	= hSampleSSAODepth(PointSampler2, IN.TexCoord6.zw, texelSize).x;

	half4 weight4a		= BilateralWeights4(centerDepth, depth4a);
	half4 weight4b		= BilateralWeights4(centerDepth, depth4b);
	half4 weight4c		= BilateralWeights4(centerDepth, depth4c);
	half weightedAO		= dot(ao4a, weight4a) + dot(ao4b, weight4b) + dot(ao4c, weight4c) + centerAO*0.25;
	// Normalize
	half ao1			= weightedAO/(dot(weight4a, 1) + dot(weight4b, 1) + dot(weight4c, 1) + 0.25);
	
	return ao1;
}
#endif // __SHADERMODEL >= 40 && !defined(SHADER_FINAL)


// ----------------------------------------------------------------------------------------------- //
 
bool IsDepthSampleAtFarPlane(float depth)
{
#if __XENON
	return (depth <= 0.0);
#else
	return (depth >= (255.0/256.0f + 255.0/(256.0f*256.0f) + 255.0/(256.0f*256.0f*256.0f)));  // "1.0" as decoded from the depth buffer
#endif
}

float FindFarthestDepthSample(float4 depthValues)
{
#if  __XENON
	return min(min(depthValues.x,depthValues.y),min(depthValues.z,depthValues.w));
#else
	return max(max(depthValues.x,depthValues.y),max(depthValues.z,depthValues.w));
#endif
}

/*half4 PS_dbgDownscaleSSAO_BANK_ONLY(pixelInputSSAO IN) : COLOR
{
#if __PS3
	float2 tex = IN.pPos;
	float2 off = 0.0 * gooScreenSize.xy; // renabling this improves the ssao slighly, but adds almost 1 ms to the downsampling time!
#else
	float2 tex = IN.pPos;
	float2 off = gooScreenSize.xy;
#endif

	float4 dsamps0;

	dsamps0.x = GBufferTexDepth2D(GBufferTextureSamplerDepth, tex + off * float2(0,  0)).x;
	dsamps0.y = GBufferTexDepth2D(GBufferTextureSamplerDepth, tex + off * float2(1,  0)).x;
	dsamps0.z = GBufferTexDepth2D(GBufferTextureSamplerDepth, tex + off * float2(1, -1)).x;
	dsamps0.w = GBufferTexDepth2D(GBufferTextureSamplerDepth, tex + off * float2(0, -1)).x;

	float farthestNonLinearDepth = FindFarthestDepthSample(dsamps0);
	float depth = getLinearDepth(farthestNonLinearDepth, g_projParams.zw, orthographic);

	depth = min(256, depth); // values > 256 wrap strangely, plus this prevents (1,1,1) from occuring "naturally"

	float3 vCodedDepth = (IsDepthSampleAtFarPlane(farthestNonLinearDepth)) ? float3(1,1,1) : SSAOEncodeDepth(depth);  // (1,1,1) represents "infinity", not the limit of the ssao depth range (256)

	return float4(1.0f, vCodedDepth);
}*/

float PS_SSAODownscaleCommon(pixelInputSSAO IN, bool orthographic, bool useGather)
{
	float4 depths;

#if __SHADERMODEL > 40
	depths = gbufferTextureDepth.GatherRed(GBufferTextureSamplerDepth, IN.pPos.xy);
#else
#if __SHADERMODEL >= 40
	if(useGather)
	{
		depths = gbufferTextureDepth.GatherRed(GBufferTextureSamplerDepth, IN.pPos.xy);
	}
	else
#endif
	{
		depths.x = tex2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2(-0.25,-0.25)*gooScreenSize.xy).x;
		depths.y = tex2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2(-0.25, 0.25)*gooScreenSize.xy).x;
		depths.z = tex2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2( 0.25,-0.25)*gooScreenSize.xy).x;
		depths.w = tex2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2( 0.25, 0.25)*gooScreenSize.xy).x;
	}
#endif


#if SUPPORT_INVERTED_PROJECTION
	depths.xy = min(depths.xy, depths.zw);
	depths.w  = min(depths.x,  depths.y);
#else
	depths.xy = max(depths.xy, depths.zw);
	depths.w  = max(depths.x,  depths.y);
#endif

	return getLinearGBufferDepth(depths.w, g_projParams.zw);
}

OutFloatColor PSCPSSAODownscale(pixelInputSSAO IN) : COLOR
{
	return CastOutFloatColor(PS_SSAODownscaleCommon(IN, false, false));
}

#if RSG_PC
OutFloatColor PSCPSSAODownscaleSM50(pixelInputSSAO IN) : COLOR
{
	return CastOutFloatColor(PS_SSAODownscaleCommon(IN, false, true));
}
#endif

#if !defined(SHADER_FINAL)
OutFloatColor PSCPSSAODownscaleOrthographic_BANK_ONLY(pixelInputSSAO IN) : COLOR
{
	return CastOutFloatColor(PS_SSAODownscaleCommon(IN, true, false));
}

#if RSG_PC
OutFloatColor PSCPSSAODownscaleOrthographic_BANK_ONLYSM50(pixelInputSSAO IN) : COLOR
{
	return CastOutFloatColor(PS_SSAODownscaleCommon(IN, true, true));
}
#endif

#endif // !defined(SHADER_FINAL)

float PS_LinearizeDepthCommon(pixelInputSSAO IN, bool orthographic)
{
	float2 itex = IN.pos;
	float2 tex = IN.pos*gooScreenSize.xy;
	return getLinearGBufferDepth(tex2D(GBufferTextureSamplerDepth, tex).x, g_projParams.zw);
}

OutFloatColor PS_LinearizeDepth(pixelInputSSAO IN) : COLOR
{
	return CastOutFloatColor(PS_LinearizeDepthCommon(IN, false));
}

#if !defined(SHADER_FINAL)
OutFloatColor PS_LinearizeDepthOrthographic_BANK_ONLY(pixelInputSSAO IN) : COLOR
{
	return CastOutFloatColor(PS_LinearizeDepthCommon(IN, true));
}
#endif // !defined(SHADER_FINAL)


OutFloatColor PS_DownscaleFromLinearDepth(pixelInputSSAO IN)  : COLOR
{
	float4 d4 = 0;

	d4.x	= tex2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2(-0.5,-0.5)*gooScreenSize.xy).x;
	d4.y	= tex2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2(-0.5, 0.5)*gooScreenSize.xy).x;
	d4.z	= tex2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2( 0.5,-0.5)*gooScreenSize.xy).x;
	d4.w	= tex2D(GBufferTextureSamplerDepth, IN.pPos.xy + float2( 0.5, 0.5)*gooScreenSize.xy).x;

	d4.zw	= max(d4.xy, d4.zw);
	d4.w	= max(d4.z, d4.w);
	return d4.w;
}


// =============================================================================================== //
// CP/QS mix.																					   //
// =============================================================================================== //

#if __PS3
#define VPOS_ARG ,float4 vPos: VPOS
#define VPOS_VAR vPos
#else
#define VPOS_ARG
#define VPOS_VAR 0
#endif

float4 PS_CPQSMix_ProcessQS(VS_OUTPUTSSAO IN) : COLOR
{
	float depth;
	float4 uv0 = IN.TexCoord0 - float4(gooScreenSize.xy, 0, 0);
	float4 uv1 = IN.TexCoord1 - gooScreenSize.xyxy;
	float ao = 1.0f - SSAOCommon(uv0, uv1, gooScreenSize*2, false, depth);
	float k = saturate((depth - g_CPQSMix_QSFadeIn_Start)*g_CPQSMix_QSFadeIn_Denominator);
	return 1.0f - k*ao;
}


float MixCPAndQS(float cpAONoPower, float qsAO)
{
	float cpAO = pow(cpAONoPower, g_SSAOStrength);
	return min(cpAO, qsAO);
	//return cpAO*qsAO;
}


half4 PS_CPQSMix_ProcessCPAndCombineWithQS(pixelInputSSAO IN VPOS_ARG) : COLOR
{
#if (__SHADERMODEL >= 40)
	float cpAO = PSCPSSAOInternal_FullScreenTarget(IN, VPOS_VAR, false).x;
	float qsAO = tex2D(LinearSampler1, IN.pPos.xy);
	return MixCPAndQS(cpAO, qsAO);
#else // (__SHADERMODEL >= 40)
	return 0.0f;
#endif //(__SHADERMODEL >= 40)
}


#if !defined(SHADER_FINAL)
// Not used yet!
half4 PS_CPQSMix_ProcessCPAndCombineWithQS_Orthographic_BANK_ONLY(pixelInputSSAO IN VPOS_ARG) : COLOR
{
#if (__SHADERMODEL >= 40)
	float cpAO = PSCPSSAOInternal_FullScreenTarget(IN, VPOS_VAR, true).x;
	float qsAO = tex2D(LinearSampler1, IN.pPos.xy);
	return MixCPAndQS(cpAO, qsAO);
#else // (__SHADERMODEL >= 40)
	return 0.0f;
#endif //(__SHADERMODEL >= 40)
}
#endif // !defined(SHADER_FINAL)


half4 PS_CPQSMix_ProcessCP4DirectionsAndCombineWithQS(pixelInputSSAO IN VPOS_ARG) : COLOR
{
#if (__SHADERMODEL >= 40)
	float cpAO = PSCPSSAOInternal_FullScreenTarget_4Directions(IN, VPOS_VAR, false).x;
	float qsAO = tex2D(LinearSampler1, IN.pPos.xy);
	return MixCPAndQS(cpAO, qsAO);
#else // (__SHADERMODEL >= 40)
	return 0.0f;
#endif //(__SHADERMODEL >= 40)
}


#if !defined(SHADER_FINAL)
// Not used yet!
half4 PS_CPQSMix_ProcessCP4DirectionsAndCombineWithQS_Orthographic_BANK_ONLY(pixelInputSSAO IN VPOS_ARG) : COLOR
{
#if (__SHADERMODEL >= 40)
	float cpAO = PSCPSSAOInternal_FullScreenTarget_4Directions(IN, VPOS_VAR, true).x;
	float qsAO = tex2D(LinearSampler1, IN.pPos.xy);
	return MixCPAndQS(cpAO, qsAO);
#else // (__SHADERMODEL >= 40)
	return 0.0f;
#endif //(__SHADERMODEL >= 40)
}
#endif // !defined(SHADER_FINAL)


half4 PS_CPQSMix_ProcessCPNDirectionsAndCombineWithQS(pixelInputSSAO IN VPOS_ARG) : COLOR
{
#if (__SHADERMODEL >= 40)
	float cpAO = PSCPSSAOInternal_FullScreenTarget_NDirections(IN, VPOS_VAR, false).x;
	float qsAO = tex2D(LinearSampler1, IN.pPos.xy);
	return MixCPAndQS(cpAO, qsAO);
#else // (__SHADERMODEL >= 40)
	return 0.0f;
#endif //(__SHADERMODEL >= 40)
}


#if !defined(SHADER_FINAL)
// Not used yet!
half4 PS_CPQSMix_ProcessCPNDirectionsAndCombineWithQS_Orthographic_BANK_ONLY(pixelInputSSAO IN VPOS_ARG) : COLOR
{
#if (__SHADERMODEL >= 40)
	float cpAO = PSCPSSAOInternal_FullScreenTarget_NDirections(IN, VPOS_VAR, true).x;
	float qsAO = tex2D(LinearSampler1, IN.pPos.xy);
	return MixCPAndQS(cpAO, qsAO);
#else // (__SHADERMODEL >= 40)
	return 0.0f;
#endif //(__SHADERMODEL >= 40)
}
#endif // !defined(SHADER_FINAL)


#undef VPOS_ARG
#undef VPOS_VAR

// =============================================================================================== //
// MS SSAO.																						   //
// =============================================================================================== //

#if SUPPORT_MR

#include "../../Util/macros.fxh"

// Based upon paper http://www.comp.nus.edu.sg/~duong/cgi_mssao.pdf

#define FallOffDistance		FallOffAndKernelParam.x
#define MaxHalfKernelSize	FallOffAndKernelParam.y
#define NormalWeightPower	FallOffAndKernelParam.z
#define DepthWeightPower	FallOffAndKernelParam.w


#define Resolution		TargetSizeParam.xy
#define ooResolution	TargetSizeParam.zw

#define UpOneResolution		float2(2.0f*TargetSizeParam.x, 2.0f*TargetSizeParam.y)
#define ooUpOneResolution	float2(0.5f*TargetSizeParam.z, 0.5f*TargetSizeParam.w)

#define DownOneResolution	float2(0.5f*TargetSizeParam.x, 0.5f*TargetSizeParam.y)
#define ooDownOneResolution	float2(2.0f*TargetSizeParam.z, 2.0f*TargetSizeParam.w)

#define g_ProjectParams g_projParams

#define MR_SSAO_POSITION_X_TEXTURE	gbufferTexture2
#define MR_SSAO_POSITION_Y_TEXTURE	gbufferTextureDepth
#define MR_SSAO_NORMAL_TEXTURE		PointTexture1
#define MR_SSAO_DEPTH_TEXTURE		PointTexture2

#define MR_SSAO_NORMAL_GBUFFER_TEXTURE		PointTexture4
#define MR_SSAO_DEPTH_GBUFFER_TEXTURE		PointTexture5

// Uses full MR SSAO down-scaling.
#define MR_SSAO_USE_ORIGINAL_DOWNSCALE	0

#if MR_SSAO_USE_PACKED_NORMALS
#define MR_SSAO_RAW_NORMAL_TYPE float
#else // MR_SSAO_USE_PACKED_NORMALS
#define MR_SSAO_RAW_NORMAL_TYPE float4
#endif // MR_SSAO_USE_PACKED_NORMALS

//--------------------------------------------------------------------------------------------------//
// Depth functions.																					//
//--------------------------------------------------------------------------------------------------//

float2 ConvertCoord(float2 tCoord)
{
	return tCoord;
	//float2 Pixel = tCoord*Resolution;
	//return (Pixel - float2(0.5f, 0.5f))*ooResolution;
}

void ConvertCoord4(inout float4 tX, inout float4 tY)
{
}

float3 BackProjectIntoViewSpaceFromGBuffer_PosDepth(float3 tCoord, bool orthographic)
{
	// Convert to a viewspace depth. 
	float depth = getLinearDepth(tCoord.z, g_projParams.zw, orthographic);
	
	float2 C = ConvertCoord(tCoord.xy);
	
	// Convert the uv coord in clipping space coord.
	float2 Projected = C*float2(2,-2) + float2(-1,1);
	
	// "Expand" by viewing angle and back project.
	return float3(Projected*g_projParams.xy, 1)*depth;
}


float4x3 BackProjectIntoViewSpaceFromGBuffer_PosDepth4(float4 tX, float4 tY, float4 tDepth, bool orthographic)
{	
	// Convert to a viewspace depth. 
	float4 depth = getLinearDepth4(tDepth, g_projParams.zw, orthographic);
	ConvertCoord4(tX,tY);
	
	// Convert the uv coord in clipping space coord.
	// "Expand" by viewing angle and back project.
	float4 ProjectedX = (tX*2-1) * depth * g_projParams.x;
	float4 ProjectedY = (1-2*tY) * depth * g_projParams.y;

	return transpose(float3x4( ProjectedX, ProjectedY, depth ));
}


//--------------------------------------------------------------------------------------------------//
// Regular texture access load functions.															//
//--------------------------------------------------------------------------------------------------//


// Project back into viewspace, using Texture.Load
float2 LoadViewSpacePositionXY_iPos(int2 ti)
{
	int3 Coord = int3( ti, 0 );
	return float2(
		MR_SSAO_POSITION_X_TEXTURE.Load(Coord).r,	// Pos X
		MR_SSAO_POSITION_Y_TEXTURE.Load(Coord).r	// Pos Y
		);
}

float3 LoadViewSpacePosition_PosXY_Depth(float3 tCoord)
{
	return float3(
		LoadViewSpacePositionXY_iPos(int2(tCoord.xy)),
		fixupGBufferDepth(tCoord.z) );
}


float LoadRawDepth(int2 tCoord)
{
	return MR_SSAO_DEPTH_TEXTURE.Load( int3(tCoord,0) ).r;
}

float4 LoadRawDepth4(int4 AB, int4 CD)
{
	return float4(
		LoadRawDepth(AB.xy),
		LoadRawDepth(AB.zw),
		LoadRawDepth(CD.xy),
		LoadRawDepth(CD.zw)
		);
}

float3 LoadRawDepthForSort(float2 tCoord)
{
	return float3( tCoord, LoadRawDepth(int2(tCoord)) );
}


MR_SSAO_RAW_NORMAL_TYPE LoadRawNormal(int2 Coord)	
{
	return MR_SSAO_NORMAL_TEXTURE.Load(int3( Coord, 0 ));
}

float3 LoadViewSpacePosition_PosXY(int2 Coord)
{
	return float3(
		LoadViewSpacePositionXY_iPos(Coord),
		LoadRawDepth(Coord) );
}


float3 LoadViewSpacePosition_PosXY_Clamped(int2 Coord)
{
	int2 clampedCoord = max(int2(0, 0), Coord);
	clampedCoord = min(clampedCoord, int2(Resolution) - int2(1,1));
	return float3(
		LoadViewSpacePositionXY_iPos(clampedCoord),
		LoadRawDepth(clampedCoord));
}


//--------------------------------------------------------------------------------------------------//
// G-buffer texture access load functions.															//
//--------------------------------------------------------------------------------------------------//


float LoadRawDepth_FromGBufferTexture(int2 tCoord)
{
#if MULTISAMPLE_TECHNIQUES
	return fixupGBufferDepth(MR_SSAO_DEPTH_GBUFFER_TEXTURE.Load( tCoord, 0 ));
#else
	return fixupGBufferDepth(MR_SSAO_DEPTH_GBUFFER_TEXTURE.Load( int3(tCoord,0) ));
#endif
}


float4 LoadRawDepth4_FromGBufferTexture(int4 AB, int4 CD)
{
	return float4(
		LoadRawDepth_FromGBufferTexture(AB.xy),
		LoadRawDepth_FromGBufferTexture(AB.zw),
		LoadRawDepth_FromGBufferTexture(CD.xy),
		LoadRawDepth_FromGBufferTexture(CD.zw)
		);
}

float3 LoadRawDepthForSort_FromGBufferTexture(float2 tCoord)
{
	return float3( tCoord, LoadRawDepth_FromGBufferTexture(int2(tCoord)) );
}


float3 LoadRawNormal_FromGBufferTexture(int2 Coord)
{
#if MULTISAMPLE_TECHNIQUES
	 return MR_SSAO_NORMAL_GBUFFER_TEXTURE.Load(Coord, 0);
#else
	 return MR_SSAO_NORMAL_GBUFFER_TEXTURE.Load(int3( Coord, 0 ));
#endif
}


//--------------------------------------------------------------------------------------------------//
// Normal functions.																				//
//--------------------------------------------------------------------------------------------------//


// Unpacks a normal vector.
float3 ShiftNormalTo_MinusOneToOneRange(float3 In)
{
	return 2*In - 1;
}


// Packs a normal.
float3 ShiftNormalTo_ZeroToOneRange(float3 In)
{
	return 0.5f*(In + 1);
}

#if MR_SSAO_USE_PACKED_NORMALS

// Packs a normal.
MR_SSAO_RAW_NORMAL_TYPE PackNormal(float3 N)
{
	N = ShiftNormalTo_ZeroToOneRange(N);
	float Ret = trunc(N.r*256)*(256*256) + trunc(N.g*256)*256 + trunc(N.b*256);
	return Ret;
}

// Unpacks a normal.
float3 UnpackNormal(MR_SSAO_RAW_NORMAL_TYPE T)
{
	float Unused;
	float3 Normal;
	
	Unused = modf(T/(256*256), Normal.x);
	T -= Normal.x*(256*256);
	Unused = modf(T/(256), Normal.y);
	T -= Normal.y*(256);
	Unused = modf(T/(1), Normal.z);
	T -= Normal.z*(1);
	// DX11 TODO:- We don`t need the last two operations!
	Normal = ShiftNormalTo_MinusOneToOneRange(Normal/256.0f);

	return Normal;
}

#else // MR_SSAO_USE_PACKED_NORMALS

// Packs a normal.
MR_SSAO_RAW_NORMAL_TYPE PackNormal(float3 N)
{
	return float4(ShiftNormalTo_ZeroToOneRange(N), 0.0f);
}


// Unpacks a normal.
float3 UnpackNormal(MR_SSAO_RAW_NORMAL_TYPE T)
{
	return ShiftNormalTo_MinusOneToOneRange(T);
}

#endif // MR_SSAO_USE_PACKED_NORMALS

// Loads a normal
float3 LoadNormal(int2 ti)
{
	MR_SSAO_RAW_NORMAL_TYPE N = LoadRawNormal(ti);
	return UnpackNormal(N);
}


// Loads a normal from G-buffer
float3 LoadNormalFromGBuffer(int2 ti)
{
	float3 Raw = LoadRawNormal_FromGBufferTexture(ti);
	float3 Normal = mul(gViewInverse, float4(ShiftNormalTo_MinusOneToOneRange(Raw), 0));
	Normal.z = -Normal.z;
	return Normal;
}


//--------------------------------------------------------------------------------------------------//
// Downscaling functions.																			//
//--------------------------------------------------------------------------------------------------//

struct DOWNSCALE_OUT
{
	float Depth						: SV_Target0;
	MR_SSAO_RAW_NORMAL_TYPE Normal	: SV_Target1;
	float xPos						: SV_Target2;
	float yPos						: SV_Target3;
};

//--------------------------------------------------
// Downscaling: Actual

void SwapIfGreaterVecByZ(inout float3 a, inout float3 b)
{
	//float za = a.z, zb = b.z, r1,r2;
	//SwapIfGreaterVecScalar(za,zb, a,b, r1,r2);
	float Choose = step(b.z, a.z);
	float3 Large = lerp(b,a,Choose);
	float3 Small = lerp(a,b,Choose);
	a = Small;
	b = Large;
}

void SortMultipleDepths(inout float3 p1, inout float3 p2, inout float3 p3, inout float3 p4)
{
	SwapIfGreaterVecByZ(p1,p3);
	SwapIfGreaterVecByZ(p2,p4);
	SwapIfGreaterVecByZ(p1,p2);
	SwapIfGreaterVecByZ(p3,p4);
}

#if MR_SSAO_USE_ORIGINAL_DOWNSCALE

DOWNSCALE_OUT PS_MRSSAO_Downscale(pixelInputSSAO IN)
{
	DOWNSCALE_OUT Ret;
	// DX11 OPTIMISATION:- Use texture object Gather() function.

	float3 X1 = LoadRawDepthForSort( 2*IN.pos.xy + float2(-0.5,-0.5) );
	float3 X2 = LoadRawDepthForSort( 2*IN.pos.xy + float2(-0.5,0.5) );
	float3 X3 = LoadRawDepthForSort( 2*IN.pos.xy + float2(0.5,-0.5) );
	float3 X4 = LoadRawDepthForSort( 2*IN.pos.xy + float2(0.5,0.5) );
	
	SortMultipleDepths(X1,X2,X3,X4);

	float3 P2 = LoadViewSpacePosition_PosXY_Depth( X2 );
	float3 P3 = LoadViewSpacePosition_PosXY_Depth( X3 );
	
	MR_SSAO_RAW_NORMAL_TYPE N2 = LoadRawNormal(int2(X2.xy));
	MR_SSAO_RAW_NORMAL_TYPE N3 = LoadRawNormal(int2(X3.xy));

	// The median will be between the middle values (2 & 3).
	float3 P = 0.5f*(P2 + P3);
	Ret.xPos = P.x;
	Ret.yPos = P.y;
	Ret.Depth = fixupGBufferDepth(P.z);

	float3 aN = UnpackNormal(N2);
	float3 bN = UnpackNormal(N3);
	float3 Normal = 0.5f*(aN + bN);
	Normal = normalize(Normal);
	Ret.Normal = PackNormal(Normal);

	return Ret;	
}


DOWNSCALE_OUT PS_MRSSAO_DownscaleFromGBufferCommon(pixelInputSSAO IN, bool orthographic)
{
	DOWNSCALE_OUT Ret;
	// DX11 OPTIMISATION:- Use texture object Gather() function.

	float3 X1 = LoadRawDepthForSort_FromGBufferTexture( 2*IN.pos.xy + float2(-0.5,-0.5) );
	float3 X2 = LoadRawDepthForSort_FromGBufferTexture( 2*IN.pos.xy + float2(-0.5,0.5) );
	float3 X3 = LoadRawDepthForSort_FromGBufferTexture( 2*IN.pos.xy + float2(0.5,-0.5) );
	float3 X4 = LoadRawDepthForSort_FromGBufferTexture( 2*IN.pos.xy + float2(0.5,0.5) );
	
	SortMultipleDepths(X1,X2,X3,X4);
	
	// TODO: Vectorise the back-projection.
	float3 kf = float3( ooUpOneResolution, 1 );
	float3 P2 = BackProjectIntoViewSpaceFromGBuffer_PosDepth( X2*kf, orthographic );
	float3 P3 = BackProjectIntoViewSpaceFromGBuffer_PosDepth( X3*kf, orthographic );
	
	float3 N2 = LoadRawNormal_FromGBufferTexture(int2( X2.xy ));
	float3 N3 = LoadRawNormal_FromGBufferTexture(int2( X3.xy ));
	
	// The median will be between the middle values (2,3).
	float3 P = 0.5f*(P2 + P3);
	Ret.xPos = P.x;
	Ret.yPos = P.y;
	Ret.Depth = fixupGBufferDepth(P.z);

	// Perform the interpolation then shift into proper normal range.
	float3 Normal = 0.5f*(N2 + N3);
	Normal = ShiftNormalTo_MinusOneToOneRange(Normal);
	// Normalise then transform into view space.
	Normal = normalize(Normal);
	Normal = mul(gViewInverse, float4(Normal, 0));
	Normal.z = -Normal.z;
	
	// Pack it up.
	Ret.Normal = PackNormal(Normal);

	return Ret;	
}

#else // MR_SSAO_USE_ORIGINAL_DOWNSCALE

DOWNSCALE_OUT PS_MRSSAO_Downscale(pixelInputSSAO IN)
{
	DOWNSCALE_OUT Ret;

	float3 X = LoadRawDepthForSort( 2*IN.pos.xy + float2(-0.5,-0.5) );
	float3 P = LoadViewSpacePosition_PosXY_Depth( X );
	Ret.xPos = P.x;
	Ret.yPos = P.y;
	Ret.Depth = fixupGBufferDepth(P.z);
	Ret.Normal = LoadRawNormal(int2(X.xy));

	return Ret;	
}


DOWNSCALE_OUT PS_MRSSAO_DownscaleFromGBufferCommon(pixelInputSSAO IN, bool orthographic)
{
	DOWNSCALE_OUT Ret;

	float3 kf = float3( ooUpOneResolution, 1 );
	float3 X = LoadRawDepthForSort_FromGBufferTexture( 2*IN.pos.xy + float2(-0.5,-0.5) );
	float3 P = BackProjectIntoViewSpaceFromGBuffer_PosDepth( X*kf, orthographic );
	Ret.xPos = P.x;
	Ret.yPos = P.y;
	Ret.Depth = P.z;
	float3 Normal = LoadRawNormal_FromGBufferTexture(int2( X.xy ));
	Normal = ShiftNormalTo_MinusOneToOneRange(Normal);
	// Normalise then transform into view space.
	Normal = normalize(Normal);
	Normal = mul(gViewInverse, float4(Normal, 0));
	Normal.z = -Normal.z;
	Ret.Normal = PackNormal(Normal);

	return Ret;	
}

#endif // MR_SSAO_USE_ORIGINAL_DOWNSCALE

DOWNSCALE_OUT PS_MRSSAO_DownscaleFromGBuffer(pixelInputSSAO IN)
{
	return PS_MRSSAO_DownscaleFromGBufferCommon(IN, false);
}

#if !defined(SHADER_FINAL)
DOWNSCALE_OUT PS_MRSSAO_DownscaleFromGBufferOrthographic_BANK_ONLY(pixelInputSSAO IN)
{
	return PS_MRSSAO_DownscaleFromGBufferCommon(IN, true);
}
#endif // !defined(SHADER_FINAL)

//--------------------------------------------------------------------------------------------------//
// Upsampling functions.																			//
//--------------------------------------------------------------------------------------------------//


#define USE_NORMALS_IN_UPSAMPLE 0


half4 PS_MRSSAO_UpsampleAOFromLowerLevel(pixelInputSSAO IN) : COLOR
{
#if 0
	float3 Pos;
	float3 Normal;
	ReadViewSpacePositionAndNormal(IN.pPos, Pos, Normal);

	float AO2 = UpsampleAOFromLowerLevel(IN.pos, Pos.z, Normal);
	return AO2;
#endif //0
	return 0;
}



// Upsampling: Actual

struct BILATERAL_SAMPLE_PACK
{
	float4 AO;
	float4 Depth;
#if USE_NORMALS_IN_UPSAMPLE
	float4x3 Normal;
#endif
};


BILATERAL_SAMPLE_PACK LoadSamplePack(uint4 AB, uint4 CD)
{
	BILATERAL_SAMPLE_PACK Ret;
	// DX11 OPTIMISATION:- Look in using Gather() here.
	
	Ret.AO = float4(
		PointTexture3.Load( int3(AB.xy/2,0) ),
		PointTexture3.Load( int3(AB.zw/2,0) ),
		PointTexture3.Load( int3(CD.xy/2,0) ),
		PointTexture3.Load( int3(CD.zw/2,0) )
		);

	Ret.Depth = LoadRawDepth4(AB,CD);

#if USE_NORMALS_IN_UPSAMPLE
	Ret.Normal = float4x3(
		LoadNormal(AB.xy),
		LoadNormal(AB.zw),
		LoadNormal(CD.xy),
		LoadNormal(CD.zw)
		);
#endif
	return Ret;
}


BILATERAL_SAMPLE_PACK LoadSamplePack_FromGBuffer(int4 AB, int4 CD, bool orthographic)
{
	BILATERAL_SAMPLE_PACK Ret;
	
	Ret.AO = float4(
		PointTexture3.Load( int3(AB.xy/2,0) ),
		PointTexture3.Load( int3(AB.zw/2,0) ),
		PointTexture3.Load( int3(CD.xy/2,0) ),
		PointTexture3.Load( int3(CD.zw/2,0) )
		);

	Ret.Depth = LoadRawDepth4_FromGBufferTexture(AB,CD);
	Ret.Depth = getLinearDepth4( Ret.Depth, g_projParams.zw, orthographic );

#if USE_NORMALS_IN_UPSAMPLE
	Ret.Normal = float4x3(
		LoadRawNormal_FromGBufferTexture(AB.xy),
		LoadRawNormal_FromGBufferTexture(AB.zw),
		LoadRawNormal_FromGBufferTexture(CD.xy),
		LoadRawNormal_FromGBufferTexture(CD.zw)
		);
#endif
	return Ret;
}


float4 ComputeSampleWeightPack(BILATERAL_SAMPLE_PACK SP, float Depth, float3 Normal)
{
	float4 Delta = abs(SP.Depth - Depth);
	//float4 zWeight = 1/(1 + Delta);
	// LDS DMC TEMP:-
	float4 zWeight = pow(1/(1 + Delta), DepthWeightPower);

#if USE_NORMALS_IN_UPSAMPLE
	float4 Dot = mul(SP.Normal,Normal);
	float4 nWeight = pow(Dot, NormalWeightPower);
	return nWeight*zWeight;
#else
	return zWeight;
#endif
}

float UpsampleAOFromLowerLevel_Load(int2 iPos, float Depth, float3 Normal)
{	
	float4 SubPixel;
	SubPixel.xy = frac( 0.5f*float2(iPos) - float2(0.25,0.25) );
	SubPixel.zw = float2(1,1) - SubPixel.xy;

	float4 BilinearWeights = SubPixel.zxzx * SubPixel.wwyy;

	int2 iBase = iPos - int2(1,1) + (iPos & int2(1,1));

	BILATERAL_SAMPLE_PACK Samples = LoadSamplePack(
		iBase.xyxy + int4(0,0,1,0),
		iBase.xyxy + int4(0,1,1,1) );
	
	float4 ComputedWeights = ComputeSampleWeightPack(Samples, Depth, Normal);

	return dot( BilinearWeights * ComputedWeights, Samples.AO );
}

float UpsampleAOFromLowerLevel_Load_FromGBuffer(int2 iPos, float Depth, float3 Normal, bool orthographic)
{	
	float4 SubPixel;
	SubPixel.xy = frac( 0.5f*float2(iPos) - float2(0.25,0.25) );
	SubPixel.zw = float2(1,1) - SubPixel.xy;

	float4 BilinearWeights = SubPixel.zxzx * SubPixel.wwyy;

	int2 iBase = iPos - int2(1,1) + (iPos & int2(1,1));

	BILATERAL_SAMPLE_PACK Samples = LoadSamplePack_FromGBuffer(
		iBase.xyxy + int4(0,0,1,0),
		iBase.xyxy + int4(0,1,1,1),
		orthographic);
	
	float4 ComputedWeights = ComputeSampleWeightPack(Samples, Depth, Normal);

	return dot( BilinearWeights * ComputedWeights, Samples.AO );
}


//--------------------------------------------------------------------------------------------------//
// AO computing functions.																			//
//--------------------------------------------------------------------------------------------------//

//	Compute: Actual
float ComputeAO_ContributionFromPositionPack(float3 Pos, float3 Normal, float4x3 Pack)
{
	float4x3 Diff = Pack - float4x3(Pos, Pos, Pos, Pos);

#if 0
	float4 len = sqrt(float4(
		dot(Diff[0],Diff[0]),
		dot(Diff[1],Diff[1]),
		dot(Diff[2],Diff[2]),
		dot(Diff[3],Diff[3])
		));
			
	float4 ClampedCosine = max(0,mul(Diff,Normal)) / len;
	float4 F = len/FallOffDistance;

	const float kDist = 1.f;	// option: weight decreasing with distance from (0,0)
	return kDist * dot(1-min(1, F*F), ClampedCosine);
#else
	float4 lenSqr = float4(
		dot(Diff[0],Diff[0]),
		dot(Diff[1],Diff[1]),
		dot(Diff[2],Diff[2]),
		dot(Diff[3],Diff[3])
		);

	float4 ClampedCosineNumerator = max(0,mul(Diff,Normal));
	float4 ClampedCosineSqr = (ClampedCosineNumerator*ClampedCosineNumerator)/lenSqr;
	float4 ClampedCosine = (-0.828427125*ClampedCosineSqr + 1.828427125)*ClampedCosineSqr;
	float4 FSqr = lenSqr/(FallOffDistance*FallOffDistance);

	const float kDist = 1.f;	// option: weight decreasing with distance from (0,0)
	return kDist * dot(1-min(1, FSqr), ClampedCosine);
#endif

}


float ComputeAO_Load_ContributionFromIJ(int2 ti, int i, int j, float3 Pos, float3 Normal)
{
	float4x3 Pack = float4x3(
		LoadViewSpacePosition_PosXY_Clamped( ti + int2(+i,+j) ),
		LoadViewSpacePosition_PosXY_Clamped( ti + int2(+j,-i) ),
		LoadViewSpacePosition_PosXY_Clamped( ti + int2(-i,-j) ),
		LoadViewSpacePosition_PosXY_Clamped( ti + int2(-j,+i) )
		);

	return ComputeAO_ContributionFromPositionPack(Pos, Normal, Pack);
}


// Computes AO at the given texture coordinate.
float ComputeAO_Load(int2 ti, float3 Pos, float3 Normal)
{
	// Project a sphere of AO fall-off distance onto the projection plane (w=1).
	float2 fHalfKernelSize = 0.5f*Resolution*FallOffDistance/(g_ProjectParams.xy*Pos.z);
	// NOTE -- orthographic might not want to divide by Pos.z

	if(max(fHalfKernelSize.x,fHalfKernelSize.y) < 1.0f)
	{
		return 0;
	}
	
	// Clamp to the maximum.
	int2 iHalfKernelSize = (int2)min(fHalfKernelSize,MaxHalfKernelSize);
	int K = max(iHalfKernelSize.x, iHalfKernelSize.y);
	float AO = 0, NumSamples = 0;

	// The kernel is 2*K + 1 (the centre being the shaded pixel).
	[loop]
	for(int i=0; i<=K; i++)
	{
		[loop]
		for(int j=1; j<=K; j++)
		{
			// The basic primitive is a rect [0+K,1+K]
			// We rotate it 4 times by 90 degrees around the center point
			// to cover [-K+K,-K+K] rectangle excluding [0,0] center
			AO += ComputeAO_Load_ContributionFromIJ(ti, i, j, Pos, Normal);
			NumSamples += 4;
		}	
	}

	return AO/NumSamples;
}


// Computes AO at the given texture coordinate.
float ComputeAO_Load_StippledKernel(int2 ti, float3 Pos, float3 Normal)
{
	// Project a sphere of AO fall-off distance onto the projection plane (w=1).
	float2 fHalfKernelSize = 0.5f*Resolution*FallOffDistance/(g_ProjectParams.xy*Pos.z);
	// NOTE -- orthographic might not want to divide by Pos.z

	if(max(fHalfKernelSize.x,fHalfKernelSize.y) < 1.0f)
	{
		return 0;
	}
	
	// Clamp to the maximum.
	int2 iHalfKernelSize = (int2)min(fHalfKernelSize,MaxHalfKernelSize);
	int K = max(iHalfKernelSize.x, iHalfKernelSize.y);
	float AO = 0, NumSamples = 0;

	// The kernel is 2*K + 1 (the centre being the shaded pixel).
	[loop]
	for(int i=0; i<=K; i++)
	{
		int jStart = 1;

		if(i & 0x1)
		{
			jStart = 2;
		}

		[loop]
		for(int j=jStart; j<=K; j+=2)
		{
			// The basic primitive is a rect [0+K,1+K]
			// We rotate it 4 times by 90 degrees around the center point
			// to cover [-K+K,-K+K] rectangle excluding [0,0] center
			AO += ComputeAO_Load_ContributionFromIJ(ti, i, j, Pos, Normal);
			NumSamples += 4;
		}	
	}

	return AO/NumSamples;
}


// Computes AO at the given texture coordinate.
float ComputeAO_Load_StarKernel(int2 ti, float3 Pos, float3 Normal)
{
	// Project a sphere of AO fall-off distance onto the projection plane (w=1).
	float2 fHalfKernelSize = 0.5f*Resolution*FallOffDistance/(g_ProjectParams.xy*Pos.z);
	// NOTE -- orthographic might not want to divide by Pos.z

	if(max(fHalfKernelSize.x,fHalfKernelSize.y) < 1.0f)
	{
		return 0;
	}
	
	// Clamp to the maximum.
	int2 iHalfKernelSize = (int2)min(fHalfKernelSize,MaxHalfKernelSize);
	int K = max(iHalfKernelSize.x, iHalfKernelSize.y);
	float AO = 0, NumSamples = 0;

	[loop]
	for(int i=1; i<=K; i++)
	{
		AO += ComputeAO_Load_ContributionFromIJ(ti, i, 0, Pos, Normal); // Horizontal/Vertical cross.
		AO += ComputeAO_Load_ContributionFromIJ(ti, i, i, Pos, Normal); // Same rotated by 45 degrees.
		NumSamples += 8;
	}

	return AO/NumSamples;
}


//---------------------------------
// Compute from G-buffer
float ComputeAO_Load_FromGBuffer_ContributionFromIJ(int2 ti, int i, int j, float3 Pos, float3 Normal, bool orthographic)
{
	int4 AB = ti.xyxy + int4(+i,+j,+j,-i);
	int4 CD = ti.xyxy + int4(-i,-j,-j,+i);
	float4 depth = LoadRawDepth4_FromGBufferTexture( AB, CD );

	float4x3 Pack = BackProjectIntoViewSpaceFromGBuffer_PosDepth4(
		(float4(AB.xz,CD.xz)+0.5)*ooResolution.x,
		(float4(AB.yw,CD.yw)+0.5)*ooResolution.y,
		depth,
		orthographic);

	return ComputeAO_ContributionFromPositionPack(Pos, Normal, Pack);
}


// Computes AO from G-buffer at the given texture coordinate
float ComputeAO_Load_FromGBuffer(int2 ti, float3 Pos, float3 Normal, bool orthographic)
{
	// Project a sphere of AO fall-off distance onto the projection plane (w=1).
	float2 fHalfKernelSize = 0.5f*Resolution*FallOffDistance/(g_ProjectParams.xy*Pos.z);
	// NOTE -- orthographic might not want to divide by Pos.z

	if(max(fHalfKernelSize.x,fHalfKernelSize.y) < 1.0f)
	{
		return 0;
	}
	
	// Clamp to the maximum.
	int2 iHalfKernelSize = (int2)min(fHalfKernelSize,MaxHalfKernelSize);
	int K = max(iHalfKernelSize.x, iHalfKernelSize.y);
	float AO = 0, NumSamples = 0;

	// The kernel is 2*K + 1 (the centre being the shaded pixel).
	[loop]
	for(int i=0; i<=K; i++)
	{
		[loop]
		for(int j=1; j<=K; j++)
		{
			// The basic primitive is a rect [0+K,1+K]
			// We rotate it 4 times by 90 degrees around the center point
			// to cover [-K+K,-K+K] rectangle excluding [0,0] center
			AO += ComputeAO_Load_FromGBuffer_ContributionFromIJ(ti, i, j, Pos, Normal, orthographic);
			NumSamples += 4;
		}	
	}
	return AO/NumSamples;
}


float ComputeAO_Load_FromGBuffer_StippledKernel(int2 ti, float3 Pos, float3 Normal, bool orthographic)
{
	// Project a sphere of AO fall-off distance onto the projection plane (w=1).
	float2 fHalfKernelSize = 0.5f*Resolution*FallOffDistance/(g_ProjectParams.xy*Pos.z);
	// NOTE -- orthographic might not want to divide by Pos.z

	if(max(fHalfKernelSize.x,fHalfKernelSize.y) < 1.0f)
	{
		return 0;
	}
	
	// Clamp to the maximum.
	int2 iHalfKernelSize = (int2)min(fHalfKernelSize,MaxHalfKernelSize);
	int K = max(iHalfKernelSize.x, iHalfKernelSize.y);
	float AO = 0, NumSamples = 0;

	// The kernel is 2*K + 1 (the centre being the shaded pixel).
	[loop]
	for(int i=0; i<=K; i++)
	{
		int jStart = 1;

		if(i & 0x1)
		{
			jStart = 2;
		}

		[loop]
		for(int j=jStart; j<=K; j+=2)
		{
			// The basic primitive is a rect [0+K,1+K]
			// We rotate it 4 times by 90 degrees around the center point
			// to cover [-K+K,-K+K] rectangle excluding [0,0] center
			AO += ComputeAO_Load_FromGBuffer_ContributionFromIJ(ti, i, j, Pos, Normal, orthographic);
			NumSamples += 4;
		}	
	}
	return AO/NumSamples;
}


float ComputeAO_Load_FromGBuffer_StarKernel(int2 ti, float3 Pos, float3 Normal, bool orthographic)
{
	// Project a sphere of AO fall-off distance onto the projection plane (w=1).
	float2 fHalfKernelSize = 0.5f*Resolution*FallOffDistance/(g_ProjectParams.xy*Pos.z);
	// NOTE -- orthographic might not want to divide by Pos.z

	if(max(fHalfKernelSize.x,fHalfKernelSize.y) < 1.0f)
	{
		return 0;
	}
	
	// Clamp to the maximum.
	int2 iHalfKernelSize = (int2)min(fHalfKernelSize,MaxHalfKernelSize);
	int K = max(iHalfKernelSize.x, iHalfKernelSize.y);
	float AO = 0, NumSamples = 0;

	[loop]
	for(int i=1; i<=K; i++)
	{
		AO += ComputeAO_Load_FromGBuffer_ContributionFromIJ(ti, i, 0, Pos, Normal, orthographic); // Horizontal/Vertical cross.
		AO += ComputeAO_Load_FromGBuffer_ContributionFromIJ(ti, i, i, Pos, Normal, orthographic); // Same rotated by 45 degrees.
		NumSamples += 8;
	}
	return AO/NumSamples;
}


//--------------------------------------------------------------------------------------------------//


// Pixel entry points: Actual

half4 PS_MRSSAO_ComputeAOCommon(pixelInputSSAO IN, int kernelType)
{
	int2 ti = int2( IN.pos.xy );
	float3 Pos = LoadViewSpacePosition_PosXY(ti);
	float3 Normal = LoadNormal(ti);

	if(kernelType == MR_SSAO_FULL_KERNEL)
	{
		return ComputeAO_Load(ti, Pos, Normal);
	}
	else if(kernelType == MR_SSAO_STIPPLED_KERNEL)
	{
		return ComputeAO_Load_StippledKernel(ti, Pos, Normal);
	}
	else if(kernelType == MR_SSAO_STAR_KERNEL)
	{
		return ComputeAO_Load_StarKernel(ti, Pos, Normal);
	}
	else
	{
		return 0;
	}
}

half4 PS_MRSSAO_ComputeAO(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOCommon(IN, MR_SSAO_FULL_KERNEL);
}

half4 PS_MRSSAO_ComputeAO_StippledKernel(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOCommon(IN, MR_SSAO_STIPPLED_KERNEL);
}

half4 PS_MRSSAO_ComputeAO_StarKernel(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOCommon(IN, MR_SSAO_STAR_KERNEL);
}


//---------------------------------
// Compute from G-buffer
half4 PS_MRSSAO_ComputeAOFromGBufferCommon(pixelInputSSAO IN, bool orthographic, int kernelType)
{
	int2 ti = int2( IN.pos.xy );
	float depth = LoadRawDepth(ti);
	float3 Pos = BackProjectIntoViewSpaceFromGBuffer_PosDepth(float3( IN.pos.xy*ooResolution, depth ), orthographic);
	float3 Normal = LoadNormalFromGBuffer(ti);

	if(kernelType == MR_SSAO_FULL_KERNEL)
	{
		return ComputeAO_Load_FromGBuffer(ti, Pos, Normal, orthographic);
	}
	else if(kernelType == MR_SSAO_STIPPLED_KERNEL)
	{
		return ComputeAO_Load_FromGBuffer_StippledKernel(ti, Pos, Normal, orthographic);
	}
	else if(kernelType == MR_SSAO_STAR_KERNEL)
	{
		return ComputeAO_Load_FromGBuffer_StarKernel(ti, Pos, Normal, orthographic);
	}
	else
	{
		return 0;
	}
}


half4 PS_MRSSAO_ComputeAOFromGBuffer(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOFromGBufferCommon(IN, false, MR_SSAO_FULL_KERNEL);
}

half4 PS_MRSSAO_ComputeAOFromGBuffer_StippledKernel(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOFromGBufferCommon(IN, false, MR_SSAO_STIPPLED_KERNEL);
}

half4 PS_MRSSAO_ComputeAOFromGBuffer_StarKernel(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOFromGBufferCommon(IN, false, MR_SSAO_STAR_KERNEL);
}

#if !defined(SHADER_FINAL)
half4 PS_MRSSAO_ComputeAOFromGBufferOrthographic_BANK_ONLY(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOFromGBufferCommon(IN, true, MR_SSAO_FULL_KERNEL);
}
#endif // !defined(SHADER_FINAL)

//---------------------------------
// Compute and combine.
half4 PS_MRSSAO_ComputeAOAndCombineCommon(pixelInputSSAO IN, int kernelType)
{
	int2 ti = int2( IN.pos.xy );
	float3 Pos = LoadViewSpacePosition_PosXY(ti);
	float3 Normal = LoadNormal(ti);

	float AO1;
	float AO2 = UpsampleAOFromLowerLevel_Load(ti, Pos.z, Normal);

	if(kernelType == MR_SSAO_FULL_KERNEL)
	{
		AO1 = ComputeAO_Load(ti, Pos, Normal);
	}
	else if(kernelType == MR_SSAO_STIPPLED_KERNEL)
	{
		AO1 = ComputeAO_Load_StippledKernel(ti, Pos, Normal);
	}
	else if(kernelType == MR_SSAO_STAR_KERNEL)
	{
		AO1 = ComputeAO_Load_StarKernel(ti, Pos, Normal);
	}
	else
	{
		AO1 = 0;
	}
	return max(AO1, AO2);
}


half4 PS_MRSSAO_ComputeAOAndCombine(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOAndCombineCommon(IN, MR_SSAO_FULL_KERNEL);
}

half4 PS_MRSSAO_ComputeAOAndCombine_StippledKernel(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOAndCombineCommon(IN, MR_SSAO_STIPPLED_KERNEL);
}

half4 PS_MRSSAO_ComputeAOAndCombine_StarKernel(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOAndCombineCommon(IN, MR_SSAO_STAR_KERNEL);
}


//---------------------------------
// Compute and combine from G-buffer.
half4 PS_MRSSAO_ComputeAOFromGBufferAndCombineCommon(pixelInputSSAO IN, bool orthographic, int kernelType)
{
	int2 ti = int2( IN.pos.xy );
	float depth = LoadRawDepth(ti);
	float3 Pos = BackProjectIntoViewSpaceFromGBuffer_PosDepth(float3( IN.pos.xy*ooResolution, depth ), orthographic);
	float3 Normal = LoadNormalFromGBuffer(ti);

	float AO1;
	float AO2 = UpsampleAOFromLowerLevel_Load_FromGBuffer(ti, Pos.z, Normal, orthographic);

	if(kernelType == MR_SSAO_FULL_KERNEL)
	{
		AO1 = ComputeAO_Load_FromGBuffer(ti, Pos, Normal, orthographic);
	}
	else if(kernelType == MR_SSAO_STIPPLED_KERNEL)
	{
		 AO1 = ComputeAO_Load_FromGBuffer_StippledKernel(ti, Pos, Normal, orthographic);
	}
	else if(kernelType == MR_SSAO_STAR_KERNEL)
	{
		 AO1 = ComputeAO_Load_FromGBuffer_StarKernel(ti, Pos, Normal, orthographic);
	}
	else
	{
		AO1 = 0;
	}
	return max(AO1, AO2);
}


half4 PS_MRSSAO_ComputeAOFromGBufferAndCombine(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOFromGBufferAndCombineCommon(IN, false, MR_SSAO_FULL_KERNEL);
}

half4 PS_MRSSAO_ComputeAOFromGBufferAndCombine_StippledKernel(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOFromGBufferAndCombineCommon(IN, false, MR_SSAO_STIPPLED_KERNEL);
}

half4 PS_MRSSAO_ComputeAOFromGBufferAndCombine_StarKernel(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOFromGBufferAndCombineCommon(IN, false, MR_SSAO_STAR_KERNEL);
}

#if !defined(SHADER_FINAL)
half4 PS_MRSSAO_ComputeAOFromGBufferAndCombineOrthographic_BANK_ONLY(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_ComputeAOFromGBufferAndCombineCommon(IN, true, MR_SSAO_FULL_KERNEL);
}
#endif // !defined(SHADER_FINAL)

//---------------------------------
half4 PS_MRSSAO_UpsampleAOFromLowerLevel_LoadCommon(pixelInputSSAO IN, bool orthographic)
{
	const int2 ti = int2( IN.pos.xy );
	float RawDepth = LoadRawDepth(ti);
	const float Depth = getLinearDepth(RawDepth, g_projParams.zw, orthographic);
	float3 Normal = LoadNormal(ti);

	return UpsampleAOFromLowerLevel_Load(ti, Depth, Normal);
}

half4 PS_MRSSAO_UpsampleAOFromLowerLevel_Load(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_UpsampleAOFromLowerLevel_LoadCommon(IN, false);
}

#if !defined(SHADER_FINAL)
half4 PS_MRSSAO_UpsampleAOFromLowerLevel_LoadOrthographic_BANK_ONLY(pixelInputSSAO IN) : COLOR
{
	return PS_MRSSAO_UpsampleAOFromLowerLevel_LoadCommon(IN, true);
}
#endif // !defined(SHADER_FINAL)

//--------------------------------------------------------------------------------------------------//
// Blur and Apply functions.																		//
//--------------------------------------------------------------------------------------------------//

float BlurAO_Simple(float2 tc)
{	
	return tex2D( LinearSampler1, tc );
}

float BlurInternal3x3(float2 tc, float centerOffset)
{
	const float2 offsets = float2(centerOffset,-centerOffset);
	return
		0.25f * tex2D( LinearSampler1, tc+offsets.xy*ooResolution )+
		0.25f * tex2D( LinearSampler1, tc+offsets.yx*ooResolution )+
		0.25f * tex2D( LinearSampler1, tc-offsets.xx*ooResolution )+
		0.25f * tex2D( LinearSampler1, tc-offsets.yy*ooResolution );
}

float BlurAO_Gauss3x3(float2 tc)
{	
	return BlurInternal3x3(tc, 0.5);
}

float BlurAO_Box3x3(float2 tc)
{	
	return BlurInternal3x3(tc, 2.0/3.0);
}

float BlurAO_Gauss5x5(float2 tc)
{
	const float4 offsets = float4( 1.0f+7.0f/33.0f, 0.0f, 1.0f+1.0f/5.0f, -1.0f-1.0f/5.0f );
	return 41.0f/273.0f * tex2D(LinearSampler1,tc)+
		33/273.0f * tex2D( LinearSampler1, tc+offsets.xy*ooResolution )+
		33/273.0f * tex2D( LinearSampler1, tc+offsets.yx*ooResolution )+
		33/273.0f * tex2D( LinearSampler1, tc-offsets.xy*ooResolution )+
		33/273.0f * tex2D( LinearSampler1, tc-offsets.yx*ooResolution )+
		25/273.0f * tex2D( LinearSampler1, tc+offsets.zz*ooResolution )+
		25/273.0f * tex2D( LinearSampler1, tc+offsets.zw*ooResolution )+
		25/273.0f * tex2D( LinearSampler1, tc+offsets.ww*ooResolution )+
		25/273.0f * tex2D( LinearSampler1, tc+offsets.wz*ooResolution );
}


half4 PS_MRSSAO_BlurAO(pixelInputSSAO IN) : COLOR
{
	return BlurAO_Gauss3x3( IN.pos.xy * ooResolution );
}


float ApplyPower(float AO, float strength)
{
	return pow(AO, strength);
}


half4 PS_MRSSAO_BlurAOAndInvertThenApplyPower(pixelInputSSAO IN) : COLOR
{
	float AO = BlurAO_Gauss3x3( IN.pos.xy * ooResolution );
	float AOToApply = ApplyPower(AO, g_SSAOStrength);
	float num = lerp(1.0f, AOToApply , gAmbientOcclusionEffect.w);
	return num;
}


half4 PS_MRSSAO_Apply(pixelInputSSAO IN) : COLOR
{
	float AO = 1.0f - tex2D(gDeferredLightSampler2, IN.pos*ooResolution).x;
	float AOToApply = ApplyPower(AO, g_SSAOStrength);
	float num = lerp(1.0f, AOToApply , gAmbientOcclusionEffect.w);
	return num;
}


half4 PS_MRSSAO_BlurAOAndApply(pixelInputSSAO IN) : COLOR
{
	float AO = 1.0f - BlurAO_Gauss3x3( IN.pos*ooResolution );
	float AOToApply = ApplyPower(AO, g_SSAOStrength);
	float num = lerp(1.0f, AOToApply , gAmbientOcclusionEffect.w);
	return num;
}


half4 PS_MRSSAO_ApplyIsolate(pixelInputSSAO IN) : COLOR
{
	float AO = 1.0f - tex2D(gDeferredLightSampler2, IN.pos*ooResolution).x;
	float AOToApply = ApplyPower(AO, g_SSAOStrength);
	return float4(AOToApply, AOToApply, AOToApply, 1.0f);
}


half4 PS_MRSSAO_ApplyIsolateNoPower(pixelInputSSAO IN) : COLOR
{
	float AO = tex2D(LinearSampler1, IN.pos*ooResolution).x;
	return float4(AO, AO, AO, 1.0f);
}


half4 PS_MRSSAO_ApplyIsolateBlur(pixelInputSSAO IN) : COLOR
{
	float AO = 1.0f - BlurAO_Gauss3x3(IN.pos*ooResolution);
	float AOToApply = ApplyPower(AO, g_SSAOStrength);
	return float4(AOToApply, AOToApply, AOToApply, 1.0f);
}

#endif //SUPPORT_MR


// =============================================================================================== //
// TECHNIQUES 
// =============================================================================================== //
technique SSAO
{
	pass ssao_downscale
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PSCPSSAODownscale()						CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_R);
	}
#if RSG_PC && __SHADERMODEL >= 40
	pass ssao_downscale_sm50
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile ps_5_0	PSCPSSAODownscaleSM50()						CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_R);
	}
#endif
	pass ssao_linearizedepth
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_LinearizeDepth()						CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_R);
	}
	pass ssao_downscale_fromlineardepth
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_DownscaleFromLinearDepth()				CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_R);
	}
	pass ssao_upscale
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_SSAOUpscale()						CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass ssao_upscale_isolate
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_dbgUpscaleSSAO_2_BANK_ONLY()			CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass ssao_upscale_isolate_no_power
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_dbgUpscaleSSAO_2_NoPower_BANK_ONLY()	CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass MSAA_NAME(ssao_process)
	{
		VertexShader = compile VERTEXSHADER	VS_SSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_SSAO()							CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass ssao_blur_bilateral_x
	{
		VertexShader = compile VERTEXSHADER	VS_SSAOBilateralX();
		PixelShader  = compile PIXELSHADER	PS_SSAOBilateralBlurX()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass ssao_blur_bilateral_y
	{
		VertexShader = compile VERTEXSHADER	VS_SSAOBilateralY();
		PixelShader  = compile PIXELSHADER	PS_SSAOBilateralBlurY()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass cpssao_downscale
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PSCPSSAODownscale()						CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_R);
	}
	pass MSAA_NAME(cpssao_process)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER	PSCPSSAO()						CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass cpssao_upscale
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PSCPSSAOUpscale()						CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass cpssao_isolate_isolate
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PSCPSSAOUpscaleIsolated()				CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass cpssao_isolate_isolate_no_power
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PSCPSSAOUpscaleIsolated_NoPower()		CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass pmssao_downscale
	{
		VertexShader = compile VERTEXSHADER	VS_PMSSAO();
		PixelShader  = compile PIXELSHADER	PS_PMSSAODownscale()			CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass MSAA_NAME(pmssao_process)
	{
		VertexShader = compile VERTEXSHADER	VS_PMSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_PMSSAO()				CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(cpqsmix_qs_ssao_process)
	{
		VertexShader = compile VERTEXSHADER	VS_SSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_CPQSMix_ProcessQS()							CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(cpqsmix_cp_ssao_process_and_combine_with_qs)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_CPQSMix_ProcessCPAndCombineWithQS()		CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(cpqsmix_cp4Directions_ssao_process_and_combine_with_qs)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_CPQSMix_ProcessCP4DirectionsAndCombineWithQS()		CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(cpqsmix_cpNDirections_ssao_process_and_combine_with_qs)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_CPQSMix_ProcessCPNDirectionsAndCombineWithQS()		CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
#if SUPPORT_HBAO	
	pass MSAA_NAME(hbao_solo)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_HBAO()							CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(hbao_normal)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_HBAONormal()							CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(hbao_normal_hybrid)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_HBAONormalHybrid()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(hbao_hybrid)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_HBAOHybrid()							CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(ssao_blur_gauss_bilateral_x)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_SSAOGaussBilateralBlurX()			CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(ssao_blur_gauss_bilateral_y)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_SSAOGaussBilateralBlurY()			CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(ssao_blur_gauss_bilateral_y_temporal)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_SSAOGaussBilateralBlurYTemporal()	CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(hbao_temporal_copy)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_SSAOTemporalCopy()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(hbao_continuity_mask)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_HBAOContinuityMask()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
#if __SHADERMODEL >= 40
	pass MSAA_NAME(hbao_dilate_continuity_mask_sm50)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile ps_5_0		PS_SSAODilateContinuityMask()			CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
#endif
	pass hbao_dilate_continuity_mask_nogather
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_SSAODilateContinuityMaskNoGather()			CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
#endif
#if SUPPORT_MR

	pass mrssao_downscale
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_Downscale()								CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all);
	}

	pass MSAA_NAME(mrssao_downscale_from_gbuffer)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_DownscaleFromGBuffer()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	
	//---------------------------------
	pass mrssao_compute_ao
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER PS_MRSSAO_ComputeAO()								CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass mrssao_compute_ao_stippledkernel
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER PS_MRSSAO_ComputeAO_StippledKernel()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass mrssao_compute_ao_starkernel
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER PS_MRSSAO_ComputeAO_StarKernel()								CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	//---------------------------------
	pass MSAA_NAME(mrssao_compute_ao_from_gbuffer)
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_ComputeAOFromGBuffer()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(mrssao_compute_ao_from_gbuffer_stippledkernel)
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_ComputeAOFromGBuffer_StippledKernel()	CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(mrssao_compute_ao_from_gbuffer_starkernel)
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_ComputeAOFromGBuffer_StarKernel()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	//---------------------------------
	pass mrssao_compute_ao_and_combine
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_ComputeAOAndCombine()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass mrssao_compute_ao_and_combine_stippledkernel
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_ComputeAOAndCombine_StippledKernel()	CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass mrssao_compute_ao_and_combine_starkernel
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_ComputeAOAndCombine_StarKernel()		CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	//---------------------------------
	pass MSAA_NAME(mrssao_compute_ao_from_gbuffer_and_combine)
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_ComputeAOFromGBufferAndCombine()			CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(mrssao_compute_ao_from_gbuffer_and_combine_stippledkernel)
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_ComputeAOFromGBufferAndCombine_StippledKernel()	CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass MSAA_NAME(mrssao_compute_ao_from_gbuffer_and_combine_starkernel)
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_ComputeAOFromGBufferAndCombine_StarKernel()		CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass mrssao_upsample_ao_from_lower_level
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_UpsampleAOFromLowerLevel()				CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass mrssao_blur_ao
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_BlurAO()									CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass mrssao_blur_ao_and_invert_then_apply_power
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_BlurAOAndInvertThenApplyPower()			CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass mrssao_apply
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_Apply()				CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass mrssao_apply_isolate
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_ApplyIsolate()			CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass mrssao_apply_isolate_no_power
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_ApplyIsolateNoPower()			CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass mrssao_blur_ao_and_apply
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_BlurAOAndApply()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass mrssao_apply_isolate_blur
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile PIXELSHADER	PS_MRSSAO_ApplyIsolateBlur()			CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

#endif	//SUPPORT_MR

#if !defined(SHADER_FINAL)

	pass ssao_downscale_ortho
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PSCPSSAODownscaleOrthographic_BANK_ONLY()			CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_AR);
	}

#if RSG_PC && __SHADERMODEL >= 40
	pass ssao_downscale_ortho_sm50
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile ps_5_0	PSCPSSAODownscaleOrthographic_BANK_ONLYSM50()			CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_AR);
	}
#endif
	
	pass ssao_linearizedepth_ortho
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_LinearizeDepthOrthographic_BANK_ONLY()			CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_AR);
	}
	pass cpssao_downscale_ortho
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PSCPSSAODownscaleOrthographic_BANK_ONLY()			CGC_FLAGS(CGC_DEFAULTFLAGS)	PS4_TARGET(FMT_32_AR);
	}
	pass MSAA_NAME(cpssao_process_ortho)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PSCPSSAOOrthographic_BANK_ONLY()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}
	pass pmssao_downscale_ortho
	{
		VertexShader = compile VERTEXSHADER	VS_PMSSAO();
		PixelShader  = compile PIXELSHADER	PS_PMSSAODownscaleOrthographic_BANK_ONLY()			CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass MSAA_NAME(pmssao_process_ortho)
	{
		VertexShader = compile VERTEXSHADER	VS_PMSSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_PMSSAOOrthographic_BANK_ONLY()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

#if SUPPORT_MR

	pass MSAA_NAME(ssao_process_enhanced)
	{
		VertexShader = compile VERTEXSHADER	VS_SSAO();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_SSAOEnhanced_BANK_ONLY()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass ssao_blur_bilateral_enhanced
	{
		VertexShader = compile VERTEXSHADER	VS_SSAOBilateralBlurEnhanced_BANK_ONLY();
		PixelShader  = compile PIXELSHADER	PS_SSAOBilateralBlurEnhanced_BANK_ONLY()		CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass MSAA_NAME(mrssao_downscale_from_gbuffer_ortho)
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_DownscaleFromGBufferOrthographic_BANK_ONLY()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass MSAA_NAME(mrssao_compute_ao_from_gbuffer_ortho)
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_ComputeAOFromGBufferOrthographic_BANK_ONLY()					CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

	pass MSAA_NAME(mrssao_compute_ao_from_gbuffer_and_combine_ortho)
	{
		//alphablendenable = true;
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_MRSSAO_ComputeAOFromGBufferAndCombineOrthographic_BANK_ONLY()			CGC_FLAGS("-unroll all --O1 -fastmath -disablepc all");
	}

#endif //SUPPORT_MR

#endif // !defined(SHADER_FINAL)
};

technique offset
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER	VS_screenTransformSSAO();
		PixelShader  = compile PIXELSHADER	PS_Offset()								CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
