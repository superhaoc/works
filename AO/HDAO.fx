#pragma strip off
#pragma dcl position

#include "../../common.fxh"

BeginDX10Sampler(sampler, TEXTURE_DEPTH_TYPE, depthTexture, depthSampler, depthTexture)
ContinueSampler(sampler, depthTexture, depthSampler, depthTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;

BeginDX10Sampler(sampler, TEXTURE2D_TYPE<float4>, normalTexture, normalSampler, normalTexture)
ContinueSampler(sampler, normalTexture, normalSampler, normalTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= POINT;
	MAGFILTER	= POINT;
EndSampler;

BeginDX10Sampler(sampler, Texture2D<float>, occlusionTexture, occlusionSampler, occlusionTexture)
ContinueSampler(sampler, occlusionTexture, occlusionSampler, occlusionTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;

#define HDAO_HALF_RESOLUTION	1
#define HDAO_USE_NORMALS		1
#define HDAO_RANDOM_TAPS		1
//0=depth threshold, 1=based on max depth, 2=jump stop
#define HDAO_BLUR_TYPE			2
#define HDAO_NICE_UPSAMPLE		1

#if __SHADERMODEL>=40 && !RSG_ORBIS
	#define UNROLL(x)	[unroll(x)]
#else
	#define UNROLL(x)
#endif


BEGIN_RAGE_CONSTANT_BUFFER(hdao_locals,b0)
float4	g_projParams				: projectionParams;		// sx, sy, dscale, doffset 
float4	g_projShear					: projectionShear;		// shearX, shearY
float4	g_targetSize				: targetSize;			// Width, Height, 1/Width, 1/Height
float4	g_HDAOComputeParams			: HDAOComputeParams	= float4(0.5f,0.03f,3,0.1f);	// reject radius, accept radius, fade-out distance, normal scale
float4	g_HDAOApplyParams			: HDAOApplyParams	= float4(0.f,0.f,0.01,1.f);		// blur vector XY, blur depth threshold, strength
float4	g_HDAOValleyParams			: HDAOValleyParams	= float4(0.9f,1.2f,3.f,1.0);	// dot offset, dot scale, dot power
float4	g_HDAOExtraParams			: HDAOExtraParams	= float4(0.5,0.1,2.0,1.0);		// world space, target radius, radius scale, base weight
float4  g_OcclusionTextureParams	: occlusionTexParams; 
EndConstantBufferDX10(hdao_locals)

// Camera Z values must fall within the reject and accept radius to be considered as a valley
#define	g_HDAORejectRadius		(g_HDAOComputeParams.x)
#define	g_HDAOAcceptRadius		(g_HDAOComputeParams.y)
#define	g_HDAORecipFadeOutDist	(g_HDAOComputeParams.z)
#define	g_HDAONormalScale		(g_HDAOComputeParams.w)
#define g_HDAOBlurVector		(g_HDAOApplyParams.xy)
#define g_HDAOBlurThreshold		(g_HDAOApplyParams.z)
#define g_HDAOStrength			(g_HDAOApplyParams.w)
#define g_HDAODotOffset			(g_HDAOValleyParams.x)
#define g_HDAODotScale			(g_HDAOValleyParams.y)
#define g_HDAODotPower			(g_HDAOValleyParams.z)
#define g_HDAOWorldSpace		(g_HDAOExtraParams.x)
#define g_HDAOTargetRadius		(g_HDAOExtraParams.y)
#define g_HDAORadiusScale		(g_HDAOExtraParams.z)
#define g_HDAOBaseWeight		(g_HDAOExtraParams.w)


#define HDAO_RESOLUTION_MUL	(HDAO_HALF_RESOLUTION ? 2 : 1)
#define HDAO_OFFSET_SCALE	(HDAO_HALF_RESOLUTION ? 2 : 4)
#define HDAO_NUM_VALLEYS	16
#define HDAO_PATTERN_RADIUS	10
#define HDAO_FILTER_RADIUS_DIV2	5
#define	HDAO_FILTER_RADIUS	(HDAO_FILTER_RADIUS_DIV2*2)
static const uint	HDAO_SAMPLE_INDEX	= 0;

static const float2 g_SamplePattern[HDAO_NUM_VALLEYS] =
{
	{ 0, -9 },
	{ 4, -9 },
	{ 2, -6 },
	{ 6, -6 },
	{ 0, -3 },
	{ 4, -3 },
	{ 8, -3 },
	{ 2, 0 },
	{ 6, 0 },
	{ 10, 0 },
	{ 4, 3 },
	{ 8, 3 },
	{ 2, 6 },
	{ 6, 6 },
	{ 10, 6 },
	{ 4, 9 },
};

//#define SOME_SAMPLE_INDEX	(gMSAANumSamples>>1)
#define SOME_SAMPLE_INDEX	(0)


struct vertexOutputHDAO
{
	DECLARE_POSITION(pos)
};

struct pixelInputHDAO
{
	DECLARE_POSITION_PSIN(pos)
};

// Note: Input expected in viewport space 0 to 1
vertexOutputHDAO VS_Quad(float2 pos : POSITION)
{
	pixelInputHDAO OUT;
	OUT.pos		= float4( pos*2 - 1, 0,1 );
	return OUT;
}

float computeGaussianWeight(float offset)
{
	// Assuming [-3o,3o] is our effective range
	const float xd = offset * (3.0f / HDAO_FILTER_RADIUS);
	return exp( -0.5*xd*xd );
}


float3 getCameraSpacePos(float2 screenPos)
{
	float2 unitPos = screenPos * g_targetSize.zw;
	float2 projPos = (2*unitPos - 1 + g_projShear.xy) * g_projParams.xy;

#if  __SHADERMODEL<40
	float fDepth = tex2D( depthSampler, unitPos ).x;
#elif MULTISAMPLE_TECHNIQUES
	float2 clampedPos = clamp( screenPos, 0, g_targetSize.xy-0.000001f );
	int2 tc = int2(clampedPos*HDAO_RESOLUTION_MUL);
	float fDepth = depthTexture.Load( tc, HDAO_SAMPLE_INDEX ).x;
#else
	float fDepth = depthTexture.SampleLevel( depthSampler, unitPos, 0 ).x;
	//float fDepth = depthTexture.Load( int3(screenPos,0) ).x;
#endif

	float linearDepth = getLinearGBufferDepth(fDepth,g_projParams.zw);

	return float3(projPos,1) * linearDepth;
}

float3 readNormal(float2 screenPos)
{
#if !HDAO_USE_NORMALS
	float3 raw = float3(0,0,0);
	return raw;
#endif
	float2 unitPos = screenPos * g_targetSize.zw;
#if __SHADERMODEL<40
	float3 raw = tex2D( normalSampler, unitPos ).xyz;
#elif MULTISAMPLE_TECHNIQUES
	float2 clampedPos = clamp( screenPos, 0, g_targetSize.xy-0.000001f );
	int2 tc = int2(clampedPos*HDAO_RESOLUTION_MUL);
	float3 raw = normalTexture.Load( tc, HDAO_SAMPLE_INDEX ).xyz;
#else
	float3 raw = normalTexture.SampleLevel( normalSampler, unitPos, 0 ).xyz;
	//float3 raw = normalTexture.Load( int3(screenPos.xy,0) ).xyz;
#endif
	float4 worldNormal = float4( raw*2 - 1, 0 );
	return mul(gViewInverse,worldNormal).xyz * float3(1,1,-1);
}

float3 getFinalPos(float2 screenPos)
{
	return getCameraSpacePos(screenPos) + readNormal(screenPos)*g_HDAONormalScale;
}

float4 getRotationMatrix(float3 viewPos)	{
#if HDAO_RANDOM_TAPS
	//const float3 fWorldPos = mul(gViewInverse, float4(viewPos,1)).xyz;
	const float3 fWorldPos = viewPos;
	const float fRot = 100000.0f * (fWorldPos.x * fWorldPos.y + fWorldPos.z);
	float fSin,fCos;
	sincos(fRot,fSin,fCos);
#else
	float fSin=0, fCos=1;
#endif
	return float4( fCos,fSin, -fSin,fCos );
}


float4 Compute(uint iStep, float2 screenPos)
{
	const float3 fCenterPos = getFinalPos(screenPos);
	const float fCenterDistance = length(fCenterPos);
	float fOcclusion = 0, fNumValleys = 0;
	const float4 rawRotation = getRotationMatrix(fCenterPos);
	const float2x2 fRotMatrix = float2x2( rawRotation.xy, rawRotation.zw );

	UNROLL(HDAO_NUM_VALLEYS)
	for( uint uValley = 0; uValley < HDAO_NUM_VALLEYS; uValley+=iStep )
	{
		const float2 fRandom = mul( fRotMatrix, g_SamplePattern[uValley] );
		const float3 fSampledPos[2] = {
			getFinalPos( screenPos + fRandom*HDAO_OFFSET_SCALE ),
			getFinalPos( screenPos - fRandom*HDAO_OFFSET_SCALE ),
			};

		// Compute distances
		float2 fSampledDistances = sqrt( float2(
			dot( fSampledPos[0], fSampledPos[0] ),
			dot( fSampledPos[1], fSampledPos[1] )
			));

		// Detect valleys 
		const float2 fDiff = fCenterDistance.xx - fSampledDistances;
		float2 fCompare = saturate( ( g_HDAORejectRadius.xx - fDiff ) * g_HDAORecipFadeOutDist );
		fCompare *= step( g_HDAOAcceptRadius.xx, fDiff );

		// Compute dot product, to scale occlusion
		const float3 fDir[2] = {
			normalize( fCenterPos - fSampledPos[0] ),
			normalize( fCenterPos - fSampledPos[1] )
			};
		const float fDot = saturate( dot(fDir[0],fDir[1]) + g_HDAODotOffset ) * g_HDAODotScale;
		        
		// Accumulate weighted occlusion
		fOcclusion += fCompare.x*fCompare.y * pow(fDot,g_HDAODotPower);

		fNumValleys += 1.0f;
	}

	// Finally calculate the HDAO occlusion value
	return fOcclusion / fNumValleys;
}

half4 PS_Compute_High(pixelInputHDAO IN) : COLOR
{
	return Compute( 1, IN.pos.xy );
}
half4 PS_Compute_Med(pixelInputHDAO IN) : COLOR
{
	return Compute( 2, IN.pos.xy );
}
half4 PS_Compute_Low(pixelInputHDAO IN) : COLOR
{
	return Compute( 4, IN.pos.xy );
}

// Alternative AO computation path, based on AMD HDAO, my ideas, and Angle Based SSAO:
// http://simonstechblog.blogspot.ca/2012/10/angle-based-ssao.html

float getValleyWeight(float2 lengths)
{
	float4 lenFactor = float4(lengths,g_HDAORejectRadius.xx) / float4(g_HDAOAcceptRadius.xx,lengths);
	float4 w = min(1,lenFactor);
	return pow( w.x*w.y*w.z*w.w, g_HDAORadiusScale );
}

float4 ComputeAlt(uint iStep, float2 screenPos)
{
	const float3 fNormal = normalize(readNormal(screenPos));
	const float3 fCenterPos = getCameraSpacePos(screenPos) + g_HDAONormalScale*fNormal;
	const float fPatternScaleWorld = (g_HDAOTargetRadius/fCenterPos.z) * g_targetSize.x / HDAO_PATTERN_RADIUS;
	const float fPatternScale = lerp( HDAO_OFFSET_SCALE, fPatternScaleWorld, g_HDAOWorldSpace );

	float fOcclusion = 0, fNumValleys = g_HDAOBaseWeight;
	const float4 rawRotation = getRotationMatrix(fCenterPos);
	const float2x2 fRotMatrix = float2x2( rawRotation.xy, rawRotation.zw );

	UNROLL(HDAO_NUM_VALLEYS)
	for( uint uValley = 0; uValley < HDAO_NUM_VALLEYS; uValley+=iStep )
	{
		const float2 fOffset = mul( fRotMatrix, fPatternScale * g_SamplePattern[uValley] );
		float3 fDeltaPos[2] = {
			getFinalPos( screenPos+fOffset ) - fCenterPos,
			getFinalPos( screenPos-fOffset ) - fCenterPos,
			};
		
		float normalCoeff = 1;
#if HDAO_USE_NORMALS
		UNROLL(2)
		for( uint i=0; i<2; ++i )
		{
			// Projecting onto the normal plane if behind it
			const float3 fixedNormal = float3(1,-1,1) * fNormal;
			const float fNormalDot = dot(fixedNormal,fDeltaPos[i]);
			if (fNormalDot < 0)
			{
				fDeltaPos[i] -= fNormalDot*fixedNormal;
				normalCoeff += fNormalDot / length(fDeltaPos[i]);
			}
		}
#endif

		// Compute ray lengths
		float2 fDeltaLengths = sqrt( float2(
			dot( fDeltaPos[0], fDeltaPos[0] ),
			dot( fDeltaPos[1], fDeltaPos[1] )
			));

		// Detect valleys 
		float cosAngle = dot(fDeltaPos[0],fDeltaPos[1]) / (fDeltaLengths.x*fDeltaLengths.y);
		//cosAngle = (cosAngle + g_HDAODotOffset) * g_HDAODotScale;
		float approxAngle = 0.5*PI*(1-cosAngle);
		float fAO = max(1-approxAngle/PI,0);

		// Compute weight
		const float fWeight = max(0,normalCoeff) * getValleyWeight( fDeltaLengths );
 
		// Accumulate weighted occlusion
		fOcclusion += fWeight*fAO;
		fNumValleys += fWeight;
	}

	// Finally calculate the HDAO occlusion value
	return fOcclusion / fNumValleys;
}

half4 PS_ComputeAlt_High(pixelInputHDAO IN) : COLOR
{
	return ComputeAlt( 1, IN.pos.xy );
}

half4 PS_ComputeAlt_Med(pixelInputHDAO IN) : COLOR
{
	return ComputeAlt( 2, IN.pos.xy );
}

half4 PS_ComputeAlt_Low(pixelInputHDAO IN) : COLOR
{
	return ComputeAlt( 4, IN.pos.xy );
}


#if __SHADERMODEL<40
	float sampleAO(float2 tc)	{
		return tex2D( occlusionSampler, tc );
	}
	float sampleDepth(float2 tc)	{
		return fixupGBufferDepth(tex2D( depthSampler, tc ));
	}
	float2 getAOPixelSize()	{
		return HDAO_RESOLUTION_MUL * g_targetSize.zw;
	}
#else	//__XENON
	float sampleAO(float2 tc)	{
		return occlusionTexture.SampleLevel( occlusionSampler, tc, 0 );
	}
	float2 getAOPixelSize()	{	
		return g_OcclusionTextureParams.xy;
	}
	#if MULTISAMPLE_TECHNIQUES
		float sampleDepth(float2 tc)	{
			return fixupGBufferDepth(depthTexture.Load( int2(tc*g_targetSize.xy*HDAO_RESOLUTION_MUL), HDAO_SAMPLE_INDEX ));
		}
	#else	//MULTISAMPLE_TECHNIQUES
		float sampleDepth(float2 tc)	{
			return fixupGBufferDepth(depthTexture.SampleLevel( depthSampler, tc, 0 ));
		}
	#endif	//MULTISAMPLE_TECHNIQUES
#endif	//__XENON

float2 sampleAODepth(float2 tc)	{
	float AO = sampleAO(tc), D = sampleDepth(tc);
	//D = getLinearDepth( D, g_projParams.zw );
	return float2(AO,D);
}


half4 PS_Blur_Fixed(pixelInputHDAO IN) : COLOR
{
#if __SHADERMODEL<40 || RSG_ORBIS
	// not implemented
	return sampleAO( IN.pos.xy*g_targetSize.zw );
#else
	// Orbis gives an internal compiler error here!
	// filter kernel: 0.18, 2*0.15, 2*0.12, 2*0.09, 2*0.05
	const int3 iCenter = int3( int2(IN.pos.xy), 0 );
	const int3 iOffset = int3( int2(g_HDAOBlurVector), 0 );
	return 0.18 * occlusionTexture.Load(iCenter)+
		0.15 * occlusionTexture.Load(iCenter+1*iOffset)+
		0.15 * occlusionTexture.Load(iCenter-1*iOffset)+
		0.12 * occlusionTexture.Load(iCenter+2*iOffset)+
		0.12 * occlusionTexture.Load(iCenter-2*iOffset)+
		0.09 * occlusionTexture.Load(iCenter+3*iOffset)+
		0.09 * occlusionTexture.Load(iCenter-3*iOffset)+
		0.05 * occlusionTexture.Load(iCenter+4*iOffset)+
		0.05 * occlusionTexture.Load(iCenter-4*iOffset);
#endif
}

half4 PS_Blur_Fixed_2D(pixelInputHDAO IN) : COLOR
{
	// Using bilinear sampling for the 5x5 Gaussian kernel:
	// http://www.cs.auckland.ac.nz/compsci373s1c/PatricesLectures/Gaussian%20Filtering_1up.pdf
	// Total: 8 samples + 1 load instruction
	const float2 pixelSize = getAOPixelSize();
	const float4 offsets = float4( 1.0f+7.0f/33.0f, 0.0f, 1.0f+1.0f/5.0f, -1.0f-1.0f/5.0f );
	const float2 tc	= IN.pos.xy * g_targetSize.zw;

	const float fAO = 41.0f/273.0f * sampleAO(tc)+
		33/273.0f * sampleAO( tc+offsets.xy*pixelSize )+
		33/273.0f * sampleAO( tc+offsets.yx*pixelSize )+
		33/273.0f * sampleAO( tc-offsets.xy*pixelSize )+
		33/273.0f * sampleAO( tc-offsets.yx*pixelSize )+
		25/273.0f * sampleAO( tc+offsets.zz*pixelSize )+
		25/273.0f * sampleAO( tc+offsets.zw*pixelSize )+
		25/273.0f * sampleAO( tc+offsets.ww*pixelSize )+
		25/273.0f * sampleAO( tc+offsets.wz*pixelSize );

	return pow( 1-fAO, g_HDAOStrength );
}


half4 PS_Blur_Variable(pixelInputHDAO IN) : COLOR
{
	float weights[HDAO_FILTER_RADIUS];
	const float w0 = computeGaussianWeight(0);
	float totalWeight = w0;
	
	const float2 pixelSize = getAOPixelSize();
	const float2 tc = IN.pos.xy * pixelSize;
	float fAO = w0 * sampleAO( tc );

	// Note: code assumes MAX_VALLEY_OFFSET is even
	UNROLL(HDAO_FILTER_RADIUS_DIV2)
	for (uint i=0; i<HDAO_FILTER_RADIUS; i+=2)
	{
		const float w1 = computeGaussianWeight( i+1.0f );
		const float w2 = computeGaussianWeight( i+2.0f );
		const float2 offset = (i + 1 + w2/(w1+w2)) * g_HDAOBlurVector * pixelSize;
		const float s1 = sampleAO( tc+offset );
		const float s2 = sampleAO( tc-offset );
		fAO += (w1+w2)*(s1+s2);
		totalWeight += 2*(w1+w2);
	}

	return fAO / totalWeight;
}


half4 PS_Blur_Smart(pixelInputHDAO IN) : COLOR
{
	const float2 pixelSize = getAOPixelSize();
	const float2 pixelOffset = g_HDAOBlurVector * pixelSize;
	const float2 tc = IN.pos.xy * pixelSize;

	float totalWeight = computeGaussianWeight(0);
	float2 fAOD = sampleAODepth(tc);
	fAOD.x *= totalWeight;

	float2 offset = (HDAO_FILTER_RADIUS+1.5)*pixelOffset;
#if HDAO_BLUR_TYPE == 0
	const float Dmax = g_HDAOBlurThreshold;
	const float oDmax = (Dmax>0.0001 ? 1/Dmax : 0);
#elif HDAO_BLUR_TYPE == 1
	float4 edgeDepth = float4( sampleDepth(tc+offset), sampleDepth(tc-offset),
		sampleDepth(tc+0.5*offset), sampleDepth(tc-0.5*offset) );
	float4 diff = abs( edgeDepth - fAOD.yyyy );
	const float Dmax = max( max(diff.x,diff.y), max(diff.z,diff.w) );
	const float oDmax = (Dmax>0.0001 ? 1/Dmax : 0);
#elif HDAO_BLUR_TYPE == 2
	const float POWER_DEPTH = 10, JUMP_THRESHOLD = 2.5;
	const float centerDepthPowed = pow( fAOD.y, POWER_DEPTH );
	float normalJump = 0;
	float2 sideStops = 1;
#endif
	
	UNROLL(HDAO_FILTER_RADIUS_DIV2)
	for (uint i=0; i<HDAO_FILTER_RADIUS; i+=2)
	{
		const float w1 = computeGaussianWeight( i+1.0f );
		const float w2 = computeGaussianWeight( i+2.0f );
		offset = (i + 1 + w2/(w1+w2)) * pixelOffset;
		const float4 aods = float4( sampleAODepth(tc+offset), sampleAODepth(tc-offset) );
#if HDAO_BLUR_TYPE==2
		const float2 depthDiff = abs( pow(aods.yw,POWER_DEPTH) - centerDepthPowed );
		if (i==0)
			normalJump = JUMP_THRESHOLD * min(depthDiff.x,depthDiff.y);
		sideStops *= step( depthDiff, normalJump );
		const float2 weight = float2(w1,w2) * sideStops;
#else
		const float2 depthDiff = abs( aods.yw - fAOD.yy );
		const float2 weight = float2(w1,w2) * saturate(1 - depthDiff*oDmax);
#endif
		totalWeight += weight.x + weight.y;
		fAOD.x += dot( weight, aods.xz );
	}

	return fAOD.x / totalWeight;
}


half4 PS_Apply(pixelInputHDAO IN) : COLOR
{
#if HDAO_HALF_RESOLUTION
	const float2 tc = IN.pos.xy * g_targetSize.zw;
#if HDAO_NICE_UPSAMPLE
	const float2 texturePos = trunc(IN.pos.xy*0.5 - 0.5);
	const float2 kCoord = 2 * g_targetSize.zw;
	const float4 fAO4 = float4(
		sampleAO( (texturePos+float2(0.5,0.5))*kCoord ),
		sampleAO( (texturePos+float2(1.5,0.5))*kCoord ),
		sampleAO( (texturePos+float2(0.5,1.5))*kCoord ),
		sampleAO( (texturePos+float2(1.5,1.5))*kCoord )
		);
	const float fAO = max( max(fAO4.x,fAO4.y), max(fAO4.z,fAO4.w) );
#else	//HDAO_NICE_UPSAMPLE
	const float fAO = sampleAO( tc );
#endif	//HDAO_NICE_UPSAMPLE
#else	//HDAO_HALF_RESOLUTION
	const float fAO = occlusionTexture.Load( int3(int2(IN.pos.xy),0) );
#endif	//HDAO_HALF_RESOLUTION
	return pow( 1-fAO, g_HDAOStrength );
}

#define APPLY_OPTIMIZED	(HDAO_NICE_UPSAMPLE && HDAO_HALF_RESOLUTION && __SHADERMODEL>=40)

#if APPLY_OPTIMIZED
half4 PS_Apply_sm41(pixelInputHDAO IN) : COLOR
{
	const float2 tc = IN.pos.xy * g_targetSize.zw;
	const float4 ao4 = occlusionTexture.Gather( occlusionSampler, tc );
	const float fAO = max( max(ao4.x,ao4.y), max(ao4.z,ao4.w) );
	return pow( 1-fAO, g_HDAOStrength );
}
#endif


technique MSAA_NAME(HDAO)
{
	pass MSAA_NAME(hdao_compute_high)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_Compute_High()		CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_compute_med)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_Compute_Med()		CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_compute_low)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_Compute_Low()		CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_alternative_high)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ComputeAlt_High()	CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_alternative_med)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ComputeAlt_Med()		CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_alternative_low)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_ComputeAlt_Low()		CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_blur_fixed)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_Blur_Fixed()			CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_blur_fixed_2d)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_Blur_Fixed_2D()		CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_blur_variable)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_Blur_Variable()		CGC_FLAGS(CGC_DEFAULTFLAGS);
	}

	pass MSAA_NAME(hdao_blur_smart)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_Blur_Smart()			CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}

technique MSAA_NAME(HDAO_Apply)
{
	pass MSAA_NAME(hdao_apply)
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile MSAA_PIXEL_SHADER	PS_Apply()				CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}

#if !MULTISAMPLE_TECHNIQUES && APPLY_OPTIMIZED
#if RSG_ORBIS
#define HDAO_PS	ps_5_0
#else
#define HDAO_PS	ps_4_1
#endif

technique HDAO_Apply_sm41
{
	pass hdao_apply_sm41
	{
		VertexShader = compile VERTEXSHADER	VS_Quad();
		PixelShader  = compile HDAO_PS	PS_Apply_sm41()						CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
#endif
