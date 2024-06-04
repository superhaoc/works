// ============================
// cascadeshadows_processing.fx
// (c) 2011 RockstarNorth
// ============================

#pragma dcl position

#include "../../common.fxh"
#pragma constant 85//12 // was 0, but now i need gWorldViewProj now for CASCADE_SHADOWS_STENCIL_REVEAL

#define SHADOW_CASTING            (0)
#define SHADOW_CASTING_TECHNIQUES (0)
#define SHADOW_RECEIVING          (1)
#define SHADOW_RECEIVING_VS       (0)
#include "cascadeshadows.fxh"

// ================================================================================================
#if RSG_ORBIS
#define SOFTSHADOW_PS	ps_5_0
#else
#define SOFTSHADOW_PS	ps_4_1
#endif

struct VertexInput
{
	float3 pos : POSITION;
	float2 tex : TEXCOORD0;
};

struct VertexOutput
{
	DECLARE_POSITION(pos)
	float2 tex : TEXCOORD0;
};

struct VertexOutputShadowMiniMap 
{
	DECLARE_POSITION(pos)
	float2 tex      : TEXCOORD0;
	float3 worldPos : TEXCOORD1;
};

VertexOutput VS_main(VertexInput IN)
{
	VertexOutput OUT;

	OUT.pos = float4(IN.pos, 1);
	OUT.tex = IN.tex.xy;

	return OUT;
}

DECLARE_SAMPLER(sampler2D, shadowMap, shadowMapSamp,
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);

DECLARE_SAMPLER(sampler2D, noiseTexture, noiseSampler,
	AddressU  = WRAP;
	AddressV  = WRAP;
	MIPFILTER = NONE;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
);

OutFloatColor PS_CopyToShadowMapVS(VertexOutput IN) : COLOR
{
	return CastOutFloatColor(rageTexDepth2D(shadowMapSamp, IN.tex));
}

#define POSTFX_CASCADE_INDEX 1 // <- this can be changed locally now

BeginConstantBufferDX10(cascadeshadows_processing_locals)
float gWaterHeight;
EndConstantBufferDX10(cascadeshadows_processing_locals)

VertexOutputShadowMiniMap VS_DownSampleShadow(VertexInput IN)
{
	VertexOutputShadowMiniMap OUT = (VertexOutputShadowMiniMap)0;

	const float3 worldPos = float3(gViewInverse[3].xy, gWaterHeight) + float3(IN.pos.xy, 0)*300;
	const float3 tex = CalcCascadeShadowCoord_internal(CascadeShadowsParams_setup(-1), worldPos, POSTFX_CASCADE_INDEX);

	OUT.pos      = float4(float2(tex.x, 1 - tex.y)*2 - 1, 0, 1);
	OUT.tex      = tex.xy;
	OUT.worldPos = worldPos;

	// since we're downsampling the full shadow map, we need to adjust the texcoord for the particular cascade
	OUT.tex.y = (OUT.tex.y + (float)POSTFX_CASCADE_INDEX)/(float)CASCADE_SHADOWS_COUNT;

	return OUT;
}

OutFloatColor PS_DownSampleShadow(VertexOutputShadowMiniMap IN, out float outDepth : DEPTH) : COLOR
{
	outDepth = rageTexDepth2D(shadowMapSamp, IN.tex).x;

#define gWaterShaftTime (gUmGlobalTimer.x*0.0015)

	const float noiseScale = 0.01;
	const float noiseA = tex2D(noiseSampler, IN.worldPos.xy*noiseScale + gWaterShaftTime).w;
	const float noiseB = tex2D(noiseSampler, IN.worldPos.yx*noiseScale - gWaterShaftTime).w;

	float noise = (noiseA + noiseB) > 1;

	outDepth = min(outDepth, noise);

	return CastOutFloatColor(outDepth);
}

// ================================================================================================

#if CASCADE_SHADOWS_STENCIL_REVEAL

float4x4 StencilRevealShadowToWorld; // TODO -- combine into a single matrix
float4   StencilRevealCascadeSphere;
float4   StencilRevealCascadeColour;

VertexOutput VS_StencilReveal(VertexInput IN)
{
	VertexOutput OUT;

	float3 worldPos = mul(IN.pos, (float3x3)StencilRevealShadowToWorld);

	worldPos.xyz *= StencilRevealCascadeSphere.www;
	worldPos.xyz += StencilRevealCascadeSphere.xyz;

	OUT.pos = mul(float4(worldPos, 1), gWorldViewProj);
	OUT.tex = IN.tex;

	return OUT;
}

float4 PS_StencilReveal(VertexOutput IN) : COLOR
{
	return StencilRevealCascadeColour;
}

#endif // CASCADE_SHADOWS_STENCIL_REVEAL

// ================================================================================================

#if CASCADE_SHADOWS_DO_SOFT_FILTERING

#if SAMPLE_FREQUENCY
#define SAMPLE_INDEX	IN.sampleIndex
#else
#define SAMPLE_INDEX	0
#endif

#define ALLOW_GATHER_EARLYOUT1	(__SHADERMODEL >= 40)
#define ALLOW_GATHER_EARLYOUT2	(__SHADERMODEL >= 40)

#if __SHADERMODEL >= 40

BeginDX10Sampler(	sampler, Texture2D<float2>, intermediateTarget, intermediateTarget_Sampler, intermediateTarget)
ContinueSampler(sampler, intermediateTarget, intermediateTarget_Sampler, intermediateTarget)
	AddressU  = CLAMP;        
	AddressV  = CLAMP;
	MINFILTER = POINT;
	MAGFILTER = POINT;
	MIPFILTER = POINT;
EndSampler;

#if MULTISAMPLE_TECHNIQUES
BeginDX10Sampler(	sampler, TEXTURE2D_TYPE<float2>, intermediateTargetAA, intermediateTargetAA_Sampler, intermediateTargetAA)
ContinueSampler(sampler, intermediateTargetAA, intermediateTargetAA_Sampler, intermediateTargetAA)
	AddressU  = CLAMP;        
	AddressV  = CLAMP;
	MINFILTER = POINT;
	MAGFILTER = POINT;
	MIPFILTER = POINT;
EndSampler;
#endif	//MULTISAMPLE_TECHNIQUES


BeginDX10Sampler(	sampler, Texture2D<float>, earlyOut, earlyOut_Sampler, earlyOut)
ContinueSampler(sampler, earlyOut, earlyOut_Sampler, earlyOut)
	AddressU  = CLAMP;        
	AddressV  = CLAMP;
	MINFILTER = POINT;
	MAGFILTER = POINT;
	MIPFILTER = POINT;
EndSampler;


BeginDX10Sampler(	sampler, TEXTURE2D_TYPE<float>, depthBuffer2, depthBuffer2_Sampler, depthBuffer2)
ContinueSampler(sampler, depthBuffer2, depthBuffer2_Sampler, depthBuffer2)
	AddressU  = CLAMP;        
	AddressV  = CLAMP;
	MINFILTER = POINT;
	MAGFILTER = POINT;
	MIPFILTER = POINT;
EndSampler;

#else // not __SHADERMODEL >= 40

DECLARE_SAMPLER(sampler2D, intermediateTarget, intermediateTarget_Sampler,
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);

/*
DECLARE_SAMPLER(sampler2D, earlyOut, earlyOut_Sampler,
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);
*/


DECLARE_SAMPLER(sampler2D, depthBuffer2, depthBuffer2_Sampler,
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	MIPFILTER = NONE;
	MINFILTER = POINT;
	MAGFILTER = POINT;
);

#endif // not __SHADERMODEL >= 40

BeginConstantBufferDX10(soft_shadow_locals)
float4 projectionParams	: projectionParams0;
float4 targetSizeParam : targetSizeParam0; // Width, Height, 1/Width, 1/Height
float4 kernelParam : kernelParam0; // "penumbra" radius squared, max half kernel size.
float4 earlyOutParams : earlyOutParams;
EndConstantBufferDX10(soft_shadow_locals)

struct VertexOutput_vPos
{
	DECLARE_POSITION(pos)
#if SAMPLE_FREQUENCY
	uint sampleIndex	: SV_SampleIndex;
#endif	//SAMPLE_FREQUENCY
};

float ReadDepthUsingVPOS(float2 vPos, uint sampleIndex)
{
#if MULTISAMPLE_TECHNIQUES
	int3 iPos = int3( int2(vPos), 0 );
	return fixupGBufferDepth(depthBuffer2.Load(iPos, sampleIndex));
#else //MULTISAMPLE_TECHNIQUES
#if __SHADERMODEL >= 40
	float2 tex = float2(vPos*targetSizeParam.zw);
	return fixupGBufferDepth(depthBuffer2.SampleLevel(depthBuffer2_Sampler, tex, 0.0f).r);
#else // not __SHADERMODEL >= 40
	float4 tex = float4(vPos*targetSizeParam.zw, 0.0f, 0.0f);
	return fixupGBufferDepth(tex2Dlod(depthBuffer2_Sampler, tex).r);
#endif // not __SHADERMODEL >= 40
#endif	//MULTISAMPLE_TECHNIQUES
}


void ReadDepthAndShadowUsingVPOS(float2 vPos, out float depth, out float shadow, int sampleIndex)
{
#if MULTISAMPLE_TECHNIQUES
	int3 iPos = int3( int2(vPos), 0 );
	depth = fixupGBufferDepth(depthBuffer2.Load(iPos, sampleIndex));
	shadow = intermediateTargetAA.Load(int2(vPos), sampleIndex).r;
#else	//MULTISAMPLE_TECHNIQUES
#if __SHADERMODEL >= 40
	float2 tex = float2(vPos*targetSizeParam.zw);
	depth = fixupGBufferDepth(depthBuffer2.SampleLevel(depthBuffer2_Sampler, tex, 0.0f).r);
	shadow = intermediateTarget.SampleLevel(intermediateTarget_Sampler, tex, 0.0f).r; 
#else // not __SHADERMODEL >= 40
	float4 tex = float4(vPos*targetSizeParam.zw, 0.0f, 0.0f);
	depth = fixupGBufferDepth(tex2Dlod(depthBuffer2_Sampler, tex).r);
	shadow = tex2Dlod(intermediateTarget_Sampler, tex).r; 
#endif // not __SHADERMODEL >= 40
#endif	//MULTISAMPLE_TECHNIQUES
}

#if __SHADERMODEL >= 40
void ReadDepthAndShadowUsingiVPOS(int3 vPos, int sampleIndex, out float depth, out float shadow)
{
	depth = fixupGBufferDepth(depthBuffer2.Load(vPos,sampleIndex).r);
#if MULTISAMPLE_TECHNIQUES
	shadow = intermediateTargetAA.Load(vPos.xy,sampleIndex).r; 
#else
	shadow = intermediateTarget.Load(vPos).r; 
#endif	//MULTISAMPLE_TECHNIQUES
}

void ReadDepthAndShadowPlusParticleShadowUsingiVPOS(int3 vPos, int sampleIndex, out float depth, out float shadow, out float particleShadow)
{
	float2 v;
	uint depthIndex = sampleIndex;
	depth = fixupGBufferDepth(depthBuffer2.Load(vPos,depthIndex).r);
#if MULTISAMPLE_TECHNIQUES
	v = intermediateTargetAA.Load(vPos.xy,sampleIndex).rg;
#else
	v = intermediateTarget.Load(vPos).rg;
#endif	//MULTISAMPLE_TECHNIQUES
	shadow = v.x;
	particleShadow = v.y;
}
#endif	//__SHADERMODEL >= 40


float3 BackProjectUsingVPOS(float2 vPos, int sampleIndex)
{
	float depth = ReadDepthUsingVPOS(vPos,sampleIndex);

	// Convert to a viewspace depth. 
	depth = getLinearDepth(depth, projectionParams.zw);
	// Convert to a projected clipping space coord.
	float2 projected = (vPos*targetSizeParam.zw)*float2(2.0f, -2.0f) + float2(-1.0f, 1.0f);
	
	// "Expand" by viewing angle and back project.
	return float3(projected*projectionParams.xy, 1)*depth;
}


float ReadIntermediateTarget(float2 vPos)
{
#if __SHADERMODEL >= 40
	return intermediateTarget.SampleLevel(intermediateTarget_Sampler, vPos*targetSizeParam.zw, 0.0f).x;
#else // not __SHADERMODEL >= 40
	return tex2Dlod(intermediateTarget_Sampler, float4(vPos*targetSizeParam.zw, 0.0f, 0.0f)).x;
#endif // not __SHADERMODEL >= 40
}

float ReadIntermediateTargetAA(float2 vPos, int sampleIndex)
{
#if MULTISAMPLE_TECHNIQUES
	return intermediateTargetAA.Load(int2(vPos), sampleIndex).r;
#else
	return ReadIntermediateTarget(vPos).r;
#endif // MULTISAMPLE_TECHNIQUES
}


float4 PS_SoftShadowBlur(VertexOutput_vPos IN) : COLOR
{
	// Back project the position of the centre pixel.
	float3 P = BackProjectUsingVPOS( IN.pos, SAMPLE_INDEX );

	// Project a "disc" of kernel radius onto the projection plane (w=1).
	float2 R = 0.5f*targetSizeParam.xy*float2(kernelParam.x/projectionParams.x, kernelParam.x/projectionParams.y)/P.z;
	R = min(R, float2(kernelParam.y, kernelParam.y));

	// Clmap to the max pixel kernel size.
	float fKernel = max(R.x, R.y);

	// Exit if the kernal size is < 1 pixel.
	if(fKernel < 1.0f)
	{
		float s = ReadIntermediateTarget(IN.pos);
		return float4(s, s, s, s);
	}

	float unused = modf(fKernel, fKernel); 

	int x, y;
	int iKernel = (int)fKernel;

	float acc = 0.0f;
	float accTotalWeights = 0.0f;
	float2 v = float2(0.0f, IN.pos.y - fKernel);

	// The kernel is 2*iKernel + 1 (the centre being the shaded pixel).
	[loop]
	for(y=-iKernel; y<=iKernel; y++)
	{
		v.x = IN.pos.x - fKernel;

		[loop]
		for(x=-iKernel; x<=iKernel; x++)
		{
			// Back project.
			float3 PStar = BackProjectUsingVPOS(v, SAMPLE_INDEX);
			// Read the shadow value.
			float shadow = ReadIntermediateTarget(v); 

			PStar = PStar - P;
			float LSquared = dot(PStar, PStar);

			if(LSquared < kernelParam.x)
			{
				acc += shadow;
				accTotalWeights += 1.0f;
			}
			v.x += 1.0f;
		}
		v.y += 1.0f;
	}

	acc = acc/accTotalWeights;

	return float4(acc, acc, acc, acc);
}

#define X_LOOP_CONTRIB 0
#define Y_LOOP_CONTRIB 1

float4 PS_SoftShadowBlur_Optimised1(VertexOutput_vPos IN) : COLOR
{
	// Back project the position of the centre pixel.
	float3 P = BackProjectUsingVPOS( IN.pos, SAMPLE_INDEX );

	// Project a "disc" of kernel radius onto the projection plane (w=1).
	float2 R = 0.5f*targetSizeParam.xy*float2(kernelParam.x/projectionParams.x, kernelParam.x/projectionParams.y)/P.z;
	R = min(R, float2(kernelParam.y, kernelParam.y));

	// Clmap to the max pixel kernel size.
	float fKernel = max(R.x, R.y);

	// Exit if the kernal size is < 1 pixel.
	if(fKernel < 1.0f)
	{
		float s = ReadIntermediateTarget(IN.pos);
		return float4(s, s, s, s);
	}

	float unused = modf(fKernel, fKernel); 

	int x, y;
	int iKernel = (int)fKernel;

	// Read the shaded pixel.
	float accTotalWeights = 1.0f;
	float acc = ReadIntermediateTarget(IN.pos);
	float4 RSquared = float4(kernelParam.x, kernelParam.x, kernelParam.x, kernelParam.x); 

	float fY = 1.0f;
	float4 xBasis[2] = { float4(1.0f, 0.0f, -1.0f, 0.0f), float4(0.0f, -1.0f, 0.0f, 1.0f) };
	float4 yBasis[2] = { float4(0.0f, 1.0f, 0.0f, -1.0f), float4(1.0f, 0.0f, -1.0f, 0.0f) };

	[loop]
	for(y=0; y<=iKernel; y++)
	{
		float fX = 1.0f;

		[loop]
		for(x=1; x<=iKernel; x++)
		{
			float4 Pz;
			float4 shadow;

			// Rotate the points into 4 quadrants to visit each point in the kernel.
			float4 Px = xBasis[X_LOOP_CONTRIB]*fX + xBasis[Y_LOOP_CONTRIB]*fY + float4(IN.pos.x, IN.pos.x, IN.pos.x, IN.pos.x);
			float4 Py = yBasis[X_LOOP_CONTRIB]*fX + yBasis[Y_LOOP_CONTRIB]*fY + float4(IN.pos.y, IN.pos.y, IN.pos.y, IN.pos.y);

			ReadDepthAndShadowUsingVPOS(float2(Px.x, Py.x), Pz.x, shadow.x, SAMPLE_INDEX);
			ReadDepthAndShadowUsingVPOS(float2(Px.y, Py.y), Pz.y, shadow.y, SAMPLE_INDEX);
			ReadDepthAndShadowUsingVPOS(float2(Px.z, Py.z), Pz.z, shadow.z, SAMPLE_INDEX);
			ReadDepthAndShadowUsingVPOS(float2(Px.w, Py.w), Pz.w, shadow.w, SAMPLE_INDEX);

			// Back project each point.
			Px = Px*targetSizeParam.z*2.0f - float4(1.0f, 1.0f, 1.0f, 1.0f);
			Py = float4(1.0f, 1.0f, 1.0f, 1.0f) - Py*targetSizeParam.w*2.0f;
			Pz = getLinearDepth4(Pz, projectionParams.zw);
			Px = Px*Pz*projectionParams.x;
			Py = Py*Pz*projectionParams.y;

			// Subtract from shaded pixel.
			Px = Px - float4(P.x, P.x, P.x, P.x);
			Py = Py - float4(P.y, P.y, P.y, P.y);
			Pz = Pz - float4(P.z, P.z, P.z, P.z);

			// "Clip" to the penumbra radius.
			float4 LSquared = Px*Px + Py*Py + Pz*Pz;
			float4 weights = step(LSquared, RSquared);

			// Accumulate shadow...
			acc += dot(shadow, weights);
			//...and weights.
			accTotalWeights += dot(weights, float4(1.0f, 1.0f, 1.0f, 1.0f));

			fX += 1.0f;
		}
		fY += 1.0f;
	}

	acc = acc/accTotalWeights;
	return float4(acc, acc, acc, acc);
}


#if __SHADERMODEL >= 40

#if 0
// use this for 7 levels of kernel radius
IMMEDIATECONSTANT int4 ixKOffsets[10] = {	int4( 0, 0,-1, 1 ),		// kernel 1
											int4(-1, 2,-2, 1 ),		// kernel 2
											int4(-3, 3, 0, 0 ),		// kernel 3
											int4(-3,-3, 3, 3 ),		// kernel 4
											int4(-5,-5, 5, 5 ),		// kernel 5
											int4( 2,-2, 2,-2 ),		// kernel 5
											int4(-6, 6, 0, 0 ),		// kernel 6
											int4(-5,-4, 4, 5 ),		// kernel 6
											int4(-7, 2, 7,-2 ),		// kernel 7
											int4(-6,-4, 4, 6 ) };	// kernel 7
										//	int4(-7,-2, 7, 2 ),		// kernel 7 - not used
IMMEDIATECONSTANT int4 iyKOffsets[10] = {	int4( 1,-1, 0, 0 ),		// kernel 1
											int4( 2, 1,-1,-2 ),		// kernel 2
											int4( 0, 0, 3,-3 ),		// kernel 3
											int4(-3, 3,-3, 3 ),		// kernel 4
											int4( 2,-2, 2,-2 ),		// kernel 5
											int4( 5, 5,-5,-5 ),		// kernel 5
											int4( 0, 0, 6,-6 ),		// kernel 6
											int4( 4,-5, 5,-4 ),		// kernel 6
											int4( 2, 7,-2,-7 ),		// kernel 7
											int4(-4, 6,-6, 4 ) };	// kernel 7
										//	int4(-2, 7, 2,-7 ),		// kernel 7 - not used
#define KERNEL_ARRAY_SIZE 7
IMMEDIATECONSTANT int nKernel[KERNEL_ARRAY_SIZE] = { 1, 2, 3, 4, 4, 4, 4 };
IMMEDIATECONSTANT int4 nUseKernel[KERNEL_ARRAY_SIZE] = {	int4( 0,0,0,0 ),
															int4( 0,1,0,0 ),
															int4( 0,1,2,0 ),
															int4( 0,1,2,3 ),
															int4( 0,2,4,5 ),
															int4( 1,3,6,7 ),
															int4( 0,3,8,9 ) };
#else
// use this for 3 levels of kernel radius
IMMEDIATECONSTANT int4 ixKOffsets[3] = {	int4( 0, 0,-1, 1 ),		// kernel 1
											int4(-1, 2,-2, 1 ),		// kernel 2
											int4(-3, 3, 0, 0 ) };	// kernel 3
IMMEDIATECONSTANT int4 iyKOffsets[3] = {	int4( 1,-1, 0, 0 ),		// kernel 1
											int4( 2, 1,-1,-2 ),		// kernel 2
											int4( 0, 0, 3,-3 ) };	// kernel 3
#define KERNEL_ARRAY_SIZE 3
IMMEDIATECONSTANT int nKernel[KERNEL_ARRAY_SIZE] = { 1, 2, 3 };
IMMEDIATECONSTANT int4 nUseKernel[KERNEL_ARRAY_SIZE] = {	int4( 0,0,0,0 ),
															int4( 0,1,0,0 ),
															int4( 0,1,2,0 ) };
#endif
float4 Calculate_SoftBlur_Optimised2(VertexOutput_vPos IN)
{
	uint sampleIndex = SAMPLE_INDEX;
	
	// Back project the position of the centre pixel.
	float3 P = BackProjectUsingVPOS(IN.pos, sampleIndex);

	// Project a "disc" of kernel radius onto the projection plane (w=1).
	float2 R = 0.5f*targetSizeParam.xy*float2(kernelParam.x/projectionParams.x, kernelParam.x/projectionParams.y)/P.z;
	R = min(R, float2(kernelParam.y, kernelParam.y));

	// Clmap to the max pixel kernel size.
	float fKernel = 0.0f;
	fKernel = max(R.x, R.y);

	float acc = ReadIntermediateTargetAA(IN.pos, sampleIndex);

	// Exit if the kernal size is < 1 pixel.
	if(fKernel < 1.0f)
	{
		return acc.xxxx;
	}

	float unused = modf(fKernel, fKernel); 

	int iKernel = min(max(((int)fKernel),1),KERNEL_ARRAY_SIZE)-1;
	int iKernelMax = nKernel[iKernel];
	int4 iUseKernel = nUseKernel[iKernel];

	// Read the shaded pixel.
	float accTotalWeights = 1.0f;
	float4 RSquared = kernelParam.xxxx; 

	float fY = 1.0f;
	float4 startPx = float4(IN.pos.x, IN.pos.x, IN.pos.x, IN.pos.x);
	float4 startPy = float4(IN.pos.y, IN.pos.y, IN.pos.y, IN.pos.y);

	startPx = kernelParam.z*startPx - projectionParams.xxxx;
	startPy = projectionParams.yyyy - kernelParam.w*startPy;

	int3 iP = int3((int)IN.pos.x, (int)IN.pos.y, 0);

	[loop]
	for(iKernel=0; iKernel<iKernelMax; iKernel++)
	{
		int4 ixOffset = ixKOffsets[ iUseKernel.x ];
		int4 iyOffset = iyKOffsets[ iUseKernel.x ];
		float4 xOffset = ixOffset;
		float4 yOffset = iyOffset;

		float4 Px = startPx + ( xOffset * kernelParam.z );
		float4 Py = startPy + ( yOffset * -kernelParam.w );
		int3 iP0 = int3( iP.x + ixOffset.x, iP.y + iyOffset.x, iP.z);
		int3 iP1 = int3( iP.x + ixOffset.y, iP.y + iyOffset.y, iP.z);
		int3 iP2 = int3( iP.x + ixOffset.z, iP.y + iyOffset.z, iP.z);
		int3 iP3 = int3( iP.x + ixOffset.w, iP.y + iyOffset.w, iP.z);

		float4 Pz;
		float4 shadow;
		ReadDepthAndShadowUsingiVPOS(iP0, sampleIndex, Pz.x, shadow.x);
		ReadDepthAndShadowUsingiVPOS(iP1, sampleIndex, Pz.y, shadow.y);
		ReadDepthAndShadowUsingiVPOS(iP2, sampleIndex, Pz.z, shadow.z);
		ReadDepthAndShadowUsingiVPOS(iP3, sampleIndex, Pz.w, shadow.w);

		// Back project into viewspace.
		float4 viewSpacePz = getLinearDepth4(Pz, projectionParams.zw);
		float4 viewSpacePx = Px*viewSpacePz;
		float4 viewSpacePy = Py*viewSpacePz;

		// Subtract from shaded pixel.
		viewSpacePx = viewSpacePx - float4(P.x, P.x, P.x, P.x);
		viewSpacePy = viewSpacePy - float4(P.y, P.y, P.y, P.y);
		viewSpacePz = viewSpacePz - float4(P.z, P.z, P.z, P.z);

		// "Clip" to the penumbra radius.
		float4 LSquared = viewSpacePx*viewSpacePx + viewSpacePy*viewSpacePy + viewSpacePz*viewSpacePz;
		float4 weights = step(LSquared, RSquared);

		// Accumulate shadow...
		acc += dot(shadow, weights);
		//...and weights.
		accTotalWeights += dot(weights, float4(1.0f, 1.0f, 1.0f, 1.0f));
		
		// rotate Usekernel
		iUseKernel = iUseKernel.yzwx;
	}

	acc = acc/accTotalWeights;
	return float4(acc, acc, acc, acc);
}


float4 Calculate_SoftBlurParticleShadowCombine_Optimised2(VertexOutput_vPos IN)
{
	uint sampleIndex = SAMPLE_INDEX;
	
	// Back project the position of the centre pixel.
	float3 P = BackProjectUsingVPOS(IN.pos, sampleIndex);

	// Project a "disc" of kernel radius onto the projection plane (w=1).
	float2 R = 0.5f*targetSizeParam.xy*float2(kernelParam.x/projectionParams.x, kernelParam.x/projectionParams.y)/P.z;
	R = min(R, float2(kernelParam.y, kernelParam.y));

	// Clmap to the max pixel kernel size.
	float fKernel = 0.0f;
	fKernel = max(R.x, R.y);

	// Exit if the kernal size is < 1 pixel.
	if(fKernel < 1.0f)
	{
		float s = ReadIntermediateTargetAA(IN.pos,sampleIndex);
		return float4(s, s, s, s);
	}

	float unused = modf(fKernel, fKernel); 

	int iKernel = min(max(((int)fKernel),1),KERNEL_ARRAY_SIZE)-1;
	int iKernelMax = nKernel[iKernel];
	int4 iUseKernel = nUseKernel[iKernel];

	// Read the shaded pixel.
	float accTotalWeights = 1.0f;
	float2 v = ReadIntermediateTargetAA(IN.pos,sampleIndex);	//FIXME: returns only float2
	float acc = min(v.x, v.y);
	float4 RSquared = float4(kernelParam.x, kernelParam.x, kernelParam.x, kernelParam.x); 

	float fY = 1.0f;
	float4 startPx = float4(IN.pos.x, IN.pos.x, IN.pos.x, IN.pos.x);
	float4 startPy = float4(IN.pos.y, IN.pos.y, IN.pos.y, IN.pos.y);

	startPx = kernelParam.z*startPx - float4(projectionParams.x, projectionParams.x, projectionParams.x, projectionParams.x);
	startPy = float4(projectionParams.y, projectionParams.y, projectionParams.y, projectionParams.y) - kernelParam.w*startPy;

	int3 iP = int3((int)IN.pos.x, (int)IN.pos.y, 0);

	[loop]
	for(iKernel=0; iKernel<iKernelMax; iKernel++)
	{
		int4 ixOffset = ixKOffsets[ iUseKernel.x ];
		int4 iyOffset = iyKOffsets[ iUseKernel.x ];
		float4 xOffset = ixOffset;
		float4 yOffset = iyOffset;

		float4 Px = startPx + ( xOffset * kernelParam.z );
		float4 Py = startPy + ( yOffset * -kernelParam.w );
		int3 iP0 = int3( iP.x + ixOffset.x, iP.y + iyOffset.x, iP.z);
		int3 iP1 = int3( iP.x + ixOffset.y, iP.y + iyOffset.y, iP.z);
		int3 iP2 = int3( iP.x + ixOffset.z, iP.y + iyOffset.z, iP.z);
		int3 iP3 = int3( iP.x + ixOffset.w, iP.y + iyOffset.w, iP.z);

		float4 Pz;
		float4 shadow;
		float4 particleShadow;
		ReadDepthAndShadowPlusParticleShadowUsingiVPOS(iP0, sampleIndex, Pz.x, shadow.x, particleShadow.x);
		ReadDepthAndShadowPlusParticleShadowUsingiVPOS(iP1, sampleIndex, Pz.y, shadow.y, particleShadow.y);
		ReadDepthAndShadowPlusParticleShadowUsingiVPOS(iP2, sampleIndex, Pz.z, shadow.z, particleShadow.z);
		ReadDepthAndShadowPlusParticleShadowUsingiVPOS(iP3, sampleIndex, Pz.w, shadow.w, particleShadow.w);

		// Combine shadow and particle shadows.
		shadow = min(shadow, particleShadow);

		// Back project into viewspace.
		float4 viewSpacePz = getLinearDepth4(Pz, projectionParams.zw);
		float4 viewSpacePx = Px*viewSpacePz;
		float4 viewSpacePy = Py*viewSpacePz;

		// Subtract from shaded pixel.
		viewSpacePx = viewSpacePx - float4(P.x, P.x, P.x, P.x);
		viewSpacePy = viewSpacePy - float4(P.y, P.y, P.y, P.y);
		viewSpacePz = viewSpacePz - float4(P.z, P.z, P.z, P.z);

		// "Clip" to the penumbra radius.
		float4 LSquared = viewSpacePx*viewSpacePx + viewSpacePy*viewSpacePy + viewSpacePz*viewSpacePz;
		float4 weights = step(LSquared, RSquared);
		
		// Accumulate shadow...
		acc += dot(shadow, weights);
		//...and weights.
		accTotalWeights += dot(weights, float4(1.0f, 1.0f, 1.0f, 1.0f));
		
		// rotate Usekernel
		iUseKernel = iUseKernel.yzwx;
	}

	acc = acc/accTotalWeights;
	return float4(acc, acc, acc, acc);
}


float4 PS_SoftShadowBlur_Optimised2(VertexOutput_vPos IN) : COLOR
{
	return Calculate_SoftBlur_Optimised2(IN); 
}

float4 PS_SoftShadowBlur_Optimised2ParticleCombine(VertexOutput_vPos IN) : COLOR
{
	float4 softShadow = Calculate_SoftBlur_Optimised2(IN); 

	int3 vBase = int3(int2(IN.pos.xy), 0);
#if MULTISAMPLE_TECHNIQUES
	float particle_shadow = intermediateTargetAA.Load(vBase.xy, SAMPLE_INDEX).g;
#else
	float particle_shadow = intermediateTarget.Load(vBase).g;
#endif
	float4 shadow = min(softShadow,particle_shadow);

	return shadow;
}


float4 PS_SoftShadowBlur_CreateEarlyOut1(VertexOutput_vPos IN) : COLOR
{
	float acc = 0.0f;

	int y;
	int3 vBase = int3(int2(IN.pos.xy)<<3, 0);

	[loop]
	for(y=0; y<8; y++)
	{
		int x;
		int3 v = vBase;

		[loop]
		for(x=0; x<8; x++)
		{
			acc += intermediateTarget.Load(v).x;
			v.x += 1;
		}
		vBase.y += 1;
	}
	acc = acc/64.0f;
	return float4(acc, acc, acc, acc);
}

#if ALLOW_GATHER_EARLYOUT1

float4 PS_SoftShadowBlur_CreateEarlyOut1_sm50(VertexOutput_vPos IN) : COLOR
{
	float acc = 0.0f;
	float2 vBase = ((IN.pos.xy*8.0f) + 1.0f) * targetSizeParam.zw;

	[loop]
	for(int y=0; y<4; y++)
	{
		float2 v = vBase;

		[loop]
		for(int x=0; x<4; x++)
		{
			float4 t = intermediateTarget.Gather(intermediateTarget_Sampler, v);
			acc += dot(t, 1.0f);
			v.x += 2.0f*targetSizeParam.z;
		}
		vBase.y += 2.0f*targetSizeParam.w;
	}
	acc = acc/64.0f;
	return float4(acc, acc, acc, acc);
}
#endif	//ALLOW_GATHER_EARLYOUT1

float4 PS_SoftShadowBlur_CreateEarlyOut2(VertexOutput_vPos IN) : COLOR
{
	float acc = 0.0f;
	int3 vBase = int3((int)IN.pos.x, (int)IN.pos.y, 0);
	// TODO: optimize this blur kernel using bilinear filtering

	acc  = earlyOut.Load(vBase + int3(-1, +1, 0)).x;
	acc += earlyOut.Load(vBase + int3(+0, +1, 0)).x;
	acc += earlyOut.Load(vBase + int3(+1, +1, 0)).x;

	acc += earlyOut.Load(vBase + int3(-1, +0, 0)).x;
	acc += earlyOut.Load(vBase + int3(+0, +0, 0)).x;
	acc += earlyOut.Load(vBase + int3(+1, +0, 0)).x;

	acc += earlyOut.Load(vBase + int3(-1, -1, 0)).x;
	acc += earlyOut.Load(vBase + int3(+0, -1, 0)).x;
	acc += earlyOut.Load(vBase + int3(+1, -1, 0)).x;
	
	acc = acc/9.0f;
	return float4(acc, acc, acc, acc);
}


#if ALLOW_GATHER_EARLYOUT2

float4 PS_SoftShadowBlur_CreateEarlyOut2_sm50(VertexOutput_vPos IN) : COLOR
{
	float4 acc = 0.0f;
	float2 ooDimenions = earlyOutParams.xy;
	float2 v = (IN.pos + float2(0.5f, 0.5f))*ooDimenions;

	acc   = earlyOut.Gather(earlyOut_Sampler, v);
	v.y -= ooDimenions.y;
	acc  += earlyOut.Gather(earlyOut_Sampler, v);
	v.x -= ooDimenions.x;
	acc  += earlyOut.Gather(earlyOut_Sampler, v);
	v.y += ooDimenions.y;
	acc  += earlyOut.Gather(earlyOut_Sampler, v);

	float totalAcc = dot(acc, float4(1.0f/16.0f, 1.0f/16.0f, 1.0f/16.0f, 1.0f/16.0f));
	return float4(totalAcc, totalAcc, totalAcc, totalAcc);
}
#endif	//ALLOW_GATHER_EARLYOUT2


float4 PS_SoftShadowBlur_EarlyOut(VertexOutput_vPos IN) : COLOR
{
	int3 earlyOutPos = int3(((int)IN.pos.x) >> 3, ((int)IN.pos.y) >> 3, 0); 

	float earlyOutValue = earlyOut.Load(earlyOutPos);

	if(earlyOutValue == 0.0f)
	{
		return float4(0.0f, 0.0f, 0.0f, 0.0f);
	}
	if(earlyOutValue == 1.0f)
	{
		return float4(1.0f, 1.0f, 1.0f, 1.0f);
	}
	return Calculate_SoftBlur_Optimised2(IN); 
}


float4 PS_SoftShadowBlur_EarlyOutWithParticleCombine(VertexOutput_vPos IN) : COLOR
{
	int3 earlyOutPos = int3(int2(IN.pos.xy) >> 3, 0); 
	float earlyOutValue = earlyOut.Load(earlyOutPos).r;

	if(earlyOutValue == 0.0f)
	{
		return float4(0.0f, 0.0f, 0.0f, 0.0f);
	}

	float shadow = 1.0f;

	if(earlyOutValue != 1.0f)
	{
		shadow = Calculate_SoftBlurParticleShadowCombine_Optimised2(IN);
	}

	int3 vBase = int3(int2(IN.pos.xy), 0);
#if MULTISAMPLE_TECHNIQUES
	float particle_shadow = intermediateTargetAA.Load(vBase.xy, SAMPLE_INDEX).g;
#else
	float particle_shadow = intermediateTarget.Load(vBase).g;
#endif
	return min(shadow,particle_shadow);
}


float4 PS_SoftShadowBlur_ShowEarlyOut(VertexOutput_vPos IN) : COLOR
{
	int3 earlyOutPos = int3(((int)IN.pos.x) >> 3, ((int)IN.pos.y) >> 3, 0); 

	float earlyOutValue = earlyOut.Load(earlyOutPos);

	if(earlyOutValue == 0.0f)
	{
		return float4(0.0f, 0.0f, 0.0f, 0.0f);
	}
	if(earlyOutValue == 1.0f)
	{
		return float4(1.0f, 1.0f, 1.0f, 1.0f);
	}
	return float4(0.5f, 0.5f, 0.5f, 0.5f);
}

#if MULTISAMPLE_TECHNIQUES

//	Depth resolve code	//

struct softBlurDepthOutput
{
	DECLARE_POSITION(pos)
	float2 vPos: TEXCOORD0;
};

softBlurDepthOutput VS_Quad(float2 pos:POSITION)
{
	softBlurDepthOutput OUT;
	OUT.pos = float4(2*pos-1,0,1);
	OUT.vPos = (OUT.pos.xy * float2( 0.5f, -0.5f ) + 0.5f) * targetSizeParam.xy;
	return OUT;
}

float PS_SoftShadowBlur_ResolveDepth(softBlurDepthOutput IN) : SV_Target
{
	const int3 iPos = int3( int2(IN.vPos.xy), 0 );
	float dMinOfMax = 1;
	float dMaxOfMin = 0;
	
#if !RSG_ORBIS
	[unroll(16/2)]
#endif
	for(int i=0; i < gMSAANumSamples; i+=2)
	{
		const float d1 = depthBuffer2.Load( iPos, i );
		const float d2 = depthBuffer2.Load( iPos, i+1 );
		dMinOfMax = min( dMinOfMax, max(d1,d2) );
		dMaxOfMin = max( dMaxOfMin, min(d1,d2) );
	}
	
	return 0.5*(dMinOfMax+dMaxOfMin);
}
#endif	//MULTISAMPLE_TECHNIQUES

#else // not __SHADERMODEL >= 40


float4 PS_SoftShadowBlur_Optimised2(VertexOutput_vPos IN) : COLOR
{
	return PS_SoftShadowBlur_Optimised1(IN);
}

float4 PS_SoftShadowBlur_Optimised2ParticleCombine(VertexOutput_vPos IN) : COLOR
{
	float4 softShadow = PS_SoftShadowBlur_Optimised1(IN); 

	return softShadow;
}



float4 PS_SoftShadowBlur_CreateEarlyOut1(VertexOutput_vPos IN) : COLOR
{
	return float4(0.0f, 0.0f, 0.0f, 0.0f);
}


float4 PS_SoftShadowBlur_CreateEarlyOut2(VertexOutput_vPos IN) : COLOR
{
	return float4(0.0f, 0.0f, 0.0f, 0.0f);
}


float4 PS_SoftShadowBlur_EarlyOut(VertexOutput_vPos IN) : COLOR
{
	return float4(0.0f, 0.0f, 0.0f, 0.0f);
}


float4 PS_SoftShadowBlur_EarlyOutWithParticleCombine(VertexOutput_vPos IN) : COLOR
{
	return float4(0.0f, 0.0f, 0.0f, 0.0f);
}


float4 PS_SoftShadowBlur_ShowEarlyOut(VertexOutput_vPos IN) : COLOR
{
	return float4(0.0f, 0.0f, 0.0f, 0.0f);
}


#endif // not __SHADERMODEL >= 40


#endif // CASCADE_SHADOWS_DO_SOFT_FILTERING


// ================================================================================================

technique MSAA_NAME(shadowprocessing)
{
	pass shadowprocessing_CopyToShadowMapVS
	{
		VertexShader = compile VERTEXSHADER VS_main();
		PixelShader  = compile PIXELSHADER  PS_CopyToShadowMapVS() CGC_FLAGS(CGC_DEFAULTFLAGS) PS4_TARGET(FMT_32_R);
	}

	pass shadowprocessing_CopyToShadowMapMini
	{
#if !__XENON
		ZFunc        = Always;
#endif //__XENON
		VertexShader = compile VERTEXSHADER VS_DownSampleShadow();
		PixelShader  = compile PIXELSHADER  PS_DownSampleShadow() CGC_FLAGS(CGC_DEFAULTFLAGS) PS4_TARGET(FMT_32_R);
	}

#if CASCADE_SHADOWS_STENCIL_REVEAL
	pass shadowprocessing_StencilRevealDebug // [TODO -- STATEBLOCK (CASCADE_SHADOWS_STENCIL_REVEAL)]
	{
		CullMode         = CCW;
		ZEnable          = true;
		ZWriteEnable     = false;
		ZFunc            = greater;
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;
		StencilEnable    = true;
		StencilPass      = invert;
		StencilFail      = keep;
		StencilZFail     = keep;
		StencilFunc      = equal;
		StencilRef       = XENON_SWITCH(255, 0); // TODO -- this should be '0', wtf?
		StencilMask      = DEFERRED_MATERIAL_SPAREMASK;
		StencilWriteMask = DEFERRED_MATERIAL_SPAREMASK; // set to revealed
		VertexShader     = compile VERTEXSHADER VS_StencilReveal();
		PixelShader      = compile PIXELSHADER  PS_StencilReveal() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
#endif // CASCADE_SHADOWS_STENCIL_REVEAL

}

#if CASCADE_SHADOWS_DO_SOFT_FILTERING
technique MSAA_NAME(shadowprocessing_SoftShadowBlur)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}


technique MSAA_NAME(shadowprocessing_SoftShadowBlur_Optimised1)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur_Optimised1() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}


technique MSAA_NAME(shadowprocessing_SoftShadowBlur_Optimised2)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur_Optimised2() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}

technique MSAA_NAME(shadowprocessing_SoftShadowBlur_Optimised2ParticleCombine)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur_Optimised2ParticleCombine() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}

technique MSAA_NAME(shadowprocessing_SoftShadowBlur_CreateEarlyOut1)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur_CreateEarlyOut1() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}

#if ALLOW_GATHER_EARLYOUT1
technique shadowprocessing_SoftShadowBlur_CreateEarlyOut1_sm50
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_main();
		PixelShader  = compile SOFTSHADOW_PS PS_SoftShadowBlur_CreateEarlyOut1_sm50() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
#endif	//ALLOW_GATHER_EARLYOUT1

technique MSAA_NAME(shadowprocessing_SoftShadowBlur_CreateEarlyOut2)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur_CreateEarlyOut2() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}


#if ALLOW_GATHER_EARLYOUT2
technique shadowprocessing_SoftShadowBlur_CreateEarlyOut2_sm50
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_main();
		PixelShader  = compile SOFTSHADOW_PS PS_SoftShadowBlur_CreateEarlyOut2_sm50() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
#endif	//ALLOW_GATHER_EARLYOUT2


technique MSAA_NAME(shadowprocessing_SoftShadowBlur_EarlyOut)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur_EarlyOut() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}


technique MSAA_NAME(shadowprocessing_SoftShadowBlur_EarlyOutWithParticleCombine)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur_EarlyOutWithParticleCombine() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}


technique MSAA_NAME(shadowprocessing_SoftShadowBlur_ShowEarlyOut)
{
	pass MSAA_NAME(p0)
	{
		VertexShader = compile VERTEXSHADER			VS_main();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_SoftShadowBlur_ShowEarlyOut() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}

#if MULTISAMPLE_TECHNIQUES
technique shadowprocessing_SoftShadowBlur_ResolveDepth_sm41
{
	pass p0_sm41
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile SOFTSHADOW_PS		PS_SoftShadowBlur_ResolveDepth() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
#endif	//MULTISAMPLE_TECHNIQUES

#endif // CASCADE_SHADOWS_DO_SOFT_FILTERING


