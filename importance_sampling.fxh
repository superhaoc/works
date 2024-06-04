#pragma strip off
//
// Filtered importance sampling
//
// Copyright (C) 1999-2013 Rockstar Games.  All Rights Reserved.
//
#ifndef __RSG_FILTERED_IMPORTANCE_SAMPLING_FXH
#define __RSG_FILTERED_IMPORTANCE_SAMPLING_FXH

#define PARAB_REFLECTION_TARGET_WIDTH		(512)
#define PARAB_REFLECTION_TARGET_HEIGHT		(256)
#define CUBE_REFLECTION_TARGET_SIZE			(256)
#if REFLECTION_CUBEMAP_SAMPLING
	#define REFLECTIONS_MAX_MIP				(8)
#else
	#define REFLECTIONS_MAX_MIP				(3)
#endif // REFLECTIONS_SAMPLE_CUBEMAP


#define USE_FILTERED_IMPORTANCE_SAMPLING		(1 && (__SHADERMODEL >= 40) && (RSG_PC  || RSG_ORBIS || RSG_DURANGO)) 
#if USE_FILTERED_IMPORTANCE_SAMPLING

#if USE_FILTERED_IMPORTANCE_SAMPLING
#define FIS_ONLY(x)	x
#define FIS_SWITCH(__if,__else)	(__if)
#else
#define FIS_ONLY(x) 
#define FIS_SWITCH(__if,__else)	(__else)
#endif

// ----------------------------------------------------------------------------------------------- //

#define NUM_PRECOMPUTED_FIS_SAMPLES				(8)
#define NUM_FIS_SAMPLES							(8)

#define FIS_PI									(3.1415926535897932384626433832795)

// ----------------------------------------------------------------------------------------------- //

#define FIS_BRDF_USE_SMITH_SHLICK_VIS 0

// Non-precomputed path doesn't work on SM3 hardware (due to lack true of integer ops)
#if (RSG_XENON||RSG_PS3) && (NUM_FIS_SAMPLES != NUM_PRECOMPUTED_FIS_SAMPLES)
#error "NUM_FIS_SAMPLES must equal NUM_PRECOMPUTED_FIS_SAMPLES on this platform so that we can use the precomputed table look up!"
#endif // (RSG_XENON||RSG_PS3) && (NUM_FIS_SAMPLES != NUM_PRECOMPUTED_FIS_SAMPLES)

#if REFLECTION_CUBEMAP_SAMPLING
#define REFLECTION_MAP_SIZE PARAB_REFLECTION_TARGET_HEIGHT
#define FISSamplerType samplerCUBE
#else
#define REFLECTION_MAP_SIZE CUBE_REFLECTION_TARGET_SIZE
#define FISSamplerType sampler2D
#endif



// ----------------------------------------------------------------------------------------------- //
float RadicalInverseVdC(uint bits) 
{
	bits = (bits << 16u) | (bits >> 16u);
	bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
	bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
	bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
	bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
	return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}

// ----------------------------------------------------------------------------------------------- //
float3 PreComputedHammersley3(uint i) 
{
	// rand = [0,1]
	// Xi   = <rand, cosRand, sinRand>
#if NUM_PRECOMPUTED_FIS_SAMPLES == 8
	float3 g_Hammersley3[NUM_PRECOMPUTED_FIS_SAMPLES] = 
	{
		float3(0.000001,1.000000, 0.000000),
		float3(0.125000,-1.000000, 0.000000),
		float3(0.250000,0.000000, 1.000000),
		float3(0.375000,-0.000000, -1.000000),
		float3(0.500000,0.707107, 0.707107),
		float3(0.625000,-0.707107, -0.707107),
		float3(0.750000,-0.707107, 0.707107),
		float3(0.875000,0.707107, -0.707107) 
	};
#else  // of 3 
	float3 g_Hammersley3[NUM_PRECOMPUTED_FIS_SAMPLES] = 
	{
			float3(0.000001,1.000000, 0.000000),
			float3(0.3333333,-1.000000, 0.000000),
			float3(0.6666666,0.000000, 1.000000)
	};
#endif

	return g_Hammersley3[i];
}


// ----------------------------------------------------------------------------------------------- //
float3 NonPreComputedHammersley3(uint i, uint N) 
{
	// i : sample index
	// N : sample count

	const float fMinRand = 0.000001f;
	const float fMaxRand = 1-fMinRand;

	float fRandNum = ((float) i)/((float) N);
	fRandNum = fRandNum < fMinRand ? fMinRand : fRandNum;
	fRandNum = fRandNum > fMaxRand ? fMaxRand : fRandNum;
	float fE2 = 2.0 * FIS_PI * RadicalInverseVdC(i);
	return float3( fRandNum, cos(fE2), sin(fE2) );
}

// ----------------------------------------------------------------------------------------------- //
float3 Hammersley3(uint i, uint N) 
{
	// i : sample index
	// N : sample count

	/*
	#if NUM_FIS_SAMPLES == NUM_PRECOMPUTED_FIS_SAMPLES
		return PreComputedHammersley3(i);
	#else
		return NonPreComputedHammersley3(i, N);
	#endif
	*/

	if ( NUM_PRECOMPUTED_FIS_SAMPLES == N ) // The compiler *should* strip this...
	{
		return PreComputedHammersley3(i);
	}
	else
	{
		return NonPreComputedHammersley3(i, N);
	}
}

// ----------------------------------------------------------------------------------------------- //
float FISPreComputeLODFactor( float nNumSamples, float nMapWidth, float fSpecExponent )
{
	// A 1-mip bias ensures some sample overlap which reduces aliasing due to under-sampling
	// See section 20.4 of http://http.developer.nvidia.com/GPUGems3/gpugems3_ch20.html
	//const float fMIPBias = (RSG_XENON || RSG_PS3) ? 1.0 : 0.0; 
	const float fMIPBias = saturate(1-(fSpecExponent/96.0)); 
	float fLODPreComp = log2((nMapWidth*nMapWidth*6)/nNumSamples/(4.f*FIS_PI))*0.5f + fMIPBias;
	return fLODPreComp;
}

float3 ImportanceSampleDiffuse(float3 Xi, float3 N, float fLODPreComp, out float fSampleLOD, out float fSampleScale )
{
	float r = sqrt(Xi.x);     
      float3 vSampleDirection;
      vSampleDirection.x = Xi.y * r;
      vSampleDirection.y = Xi.z * r;
      vSampleDirection.z = sqrt( 1.-dot(vSampleDirection.xy,vSampleDirection.xy));

	float fPDF = vSampleDirection.z/FIS_PI;
	fSampleLOD = max(0.f, fLODPreComp - log2(fPDF)*0.25f);
	fSampleScale = 1;

	// Tangent to world space
	float3 UpVector = abs(N.z) < 0.999 ? float3(0,0,1) : float3(1,0,0);
	float3 TangentX = normalize( cross( UpVector, N ) );
	float3 TangentY = cross( N, TangentX );
	float3 L = TangentX * vSampleDirection.x + TangentY * vSampleDirection.y + N * vSampleDirection.z;
	
	return L;
}

// ----------------------------------------------------------------------------------------------- //
float3 ImportanceSampleLambertion(float3 Xi, float3 N )
{

	float r = sqrt(Xi.x);     
      float3 vSampleDirection;
      vSampleDirection.x = Xi.y * r;
      vSampleDirection.y = Xi.z * r;
      vSampleDirection.z = sqrt( 1.-dot(vSampleDirection.xy,vSampleDirection.xy));

	  // Tangent to world space  could be computed once
	float3 UpVector = abs(N.z) < 0.999 ? float3(0,0,1) : float3(1,0,0);
	float3 TangentX = normalize( cross( UpVector, N ) );
	float3 TangentY = cross( N, TangentX );
	float3 L = TangentX * vSampleDirection.x + TangentY * vSampleDirection.y + N * vSampleDirection.z;

	return L;
}

// ----------------------------------------------------------------------------------------------- //
float3 ImportanceSamplePhong( float3 Xi, float fSpecExponent, float3 R, float fLODPreComp, out float fSampleLOD, out float fSampleScale )
{
	float fCosTheta = pow(Xi.x, 1.f/(fSpecExponent+1.f));
	float fSinTheta = sqrt(1.f - fCosTheta*fCosTheta);

	float3 vSampleDirection;
	vSampleDirection.x = Xi.y * fSinTheta;
	vSampleDirection.y = Xi.z * fSinTheta;
	vSampleDirection.z = fCosTheta;

	// Here's the full equation. As you can see, the PDF cancels out much of the BRDF terms. Find simplified version below.
	//float fPDF = (fSpecExponent+1)/(FIS_PI*2.f) * pow(fCosTheta, fSpecExponent);
	//fSampleLOD = max(0.f, fLODPreComp - log2(fPDF)*0.5f);
	//fSampleScale = (fSpecExponent+1)/(FIS_PI*2.f) * pow(fCosTheta, fSpecExponent) * fCosTheta / fPDF;

	// Simplified version of the above
	float fPDF = (fSpecExponent+1)/(FIS_PI*2.f) * pow(fCosTheta, fSpecExponent);
	fSampleLOD = max(0.f, fLODPreComp - log2(fPDF)*0.5f);
	fSampleScale = fCosTheta;

	// Tangent to world space
	float3 UpVector = abs(R.z) < 0.999 ? float3(0,0,1) : float3(1,0,0);
	float3 TangentX = normalize( cross( UpVector, R ) );
	float3 TangentY = cross( R, TangentX );
	float3 L = TangentX * vSampleDirection.x + TangentY * vSampleDirection.y + R * vSampleDirection.z;
	
	return L;
}

// ----------------------------------------------------------------------------------------------- //
float3 ImportanceSamplePhong( float3 Xi, float fSpecExponent, float3 N )
{
	float fLODPreComp=0;
	float fSampleLOD=0;
	float fSampleScale=0;
	return ImportanceSamplePhong(Xi, fSpecExponent, N, fLODPreComp, fSampleLOD, fSampleScale);
}

// ----------------------------------------------------------------------------------------------- //
float3 ImportanceSampleBlinnPhong( float3 Xi, float fSpecExponent, float fFresnelCoef, float3 N, float3 V, float fLODPreComp, out float fSampleLOD, out float fSampleScale  )
{
	float fCosTheta = pow(Xi.x, 1.f/(fSpecExponent+1.f));
	float fSinTheta = sqrt(1.f - fCosTheta*fCosTheta);

	float3 vSampleDirection;
	vSampleDirection.x = Xi.y * fSinTheta;
	vSampleDirection.y = Xi.z * fSinTheta;
	vSampleDirection.z = fCosTheta;

	// Tangent to world space
	float3 UpVector = abs(N.z) < 0.999 ? float3(0,0,1) : float3(1,0,0);
	float3 TangentX = normalize( cross( UpVector, N ) );
	float3 TangentY = cross( N, TangentX );
	float3 H = TangentX * vSampleDirection.x + TangentY * vSampleDirection.y + N * vSampleDirection.z;
	//H = dot( N, H ) < 0.0f ? -H : H; // Flip sample if it's below the horizon
	H = dot( V, H ) < 0.0f ? -H : H; // Flip sample if it's below the horizon

	// Reflect V about H to get the sampling direction L
	float3 L = 2 * dot( V, H ) * H - V; // reflect( -V, N );

	float HoV = dot(H, V);
	float HoL = saturate( dot(H, L) );
	float NoH = dot(N, H);
	float NoV = dot(N, V);
	float NoL = dot(N, L);

	float fPDF = ((fSpecExponent+2) * pow(NoH, fSpecExponent)) / (2.0 * FIS_PI * 4.f * HoV);
	fSampleLOD = max(0.f, fLODPreComp - log2(fPDF)*0.5f);

	// F = Fresnel
	// G = Geometric attenuation term
	// D = Normal distribution
	// BRDF = D * F * G / ( 4 * NoL * NoV )

	// Original
	float F = fresnelSlick( fFresnelCoef, HoL); 
	float D = pow(NoH, fSpecExponent) * ((fSpecExponent+2)/(2.0*FIS_PI));
	
#if FIS_BRDF_USE_SMITH_SHLICK_VIS
	float k=2./sqrt(FIS_PI*(fSpecExponent+2.));
	float Vi = 1./(4.* (NoL*(1.-k)+k)* (NoV*(1.-k)+k) );
	float fBRDF = (Vi * D * F); 
#else
	float G = min(1.f, min((2.f * NoH * NoV / HoV),(2.f * NoH * NoL / HoV)));
	float fBRDF = (G * D * F) / (4.0 * NoV * NoL ); 
#endif
	fSampleScale = fPDF > 0.0 ? fBRDF * NoL / fPDF : 0;

#if 0
	float SheenColor = 0.;//float3(1.f,.5,0.2);
	fSampleScale += SheenColor * F*.1;	
#endif
	fSampleScale = fSampleScale / FIS_PI; // TODO: Move this out of the inner-loop
	
	
	// WRONG! This is incorrect, I haven't gotten around to refactoring it yet.
	// Simplified version of the original (a bunch of terms cancel out!)
	//float F = fresnelSlick(fFresnelCoef, HoL); 
	//fSampleScale = F * 2.0 * FIS_PI * HoV;
	//fSampleScale = F * 2.0 * HoV;
	//fSampleScale = F * HoV;
	//fSampleScale = F;
	
	//fSampleScale = dot(N, L)<0 ? 0 : fSampleScale; // This shouldn't be necessary... and yet it is. There must be a problem with flipping H up above.

	return L;
}

// ----------------------------------------------------------------------------------------------- //

#if !defined(SHADER_FINAL)
// Useful for visualizing the BRDF and Sample overlap on a unit sphere of constant specularity... such as in the testbed
// Visualize: BRDF support region, BRDF value, Importance sample locations
float4 FISVisualizeSampleDistribution ( float3 vNormal, float3 vView, float fSpecExponent, uint nNumSamples )
{
	// Approximate solid angle of texel (assume no projection distortion)
	float fLODPreComp = FISPreComputeLODFactor( nNumSamples, REFLECTION_MAP_SIZE, fSpecExponent );

	float3 vReflectionVec = reflect(-vView, vNormal);

	float fSampleLocationAccum = 0;
	float fSamplePDFScaleAccum = 0;
	for( uint i = 0; i < nNumSamples; i++ )
	{
		float3 Xi = Hammersley3( i, nNumSamples );
		float fSampleLOD = 0, fSamplePDFScale = 1;
		float3 H = ImportanceSamplePhong( Xi, fSpecExponent, float3(0,0,1), fLODPreComp, fSampleLOD, fSamplePDFScale );
		fSampleLocationAccum += pow( saturate(dot(H,vNormal)), 8192.0) * fSamplePDFScale; // Super high exponent to "light" sample directions on sphere
		fSamplePDFScaleAccum += fSamplePDFScale;

	}

	float fBlinnPhong = pow( saturate(dot(vNormal,float3(0,0,1))), fSpecExponent );
	//float fBRDFSupport = (fBlinnPhong>0.0 && fBlinnPhong<1e-30) ? 0.125 : 0;
	float fBRDFSupport = fBlinnPhong>0.0 ? 0.05 : 0;
	float fBRDFFalloff = fBlinnPhong * 1.0;
	float fSampleLocation = fSampleLocationAccum/fSamplePDFScaleAccum * 10;
	return fSampleLocation.xxxx + fBRDFSupport.xxxx + fBRDFFalloff.xxxx; 
}
#endif // !defined(SHADER_FINAL)

// ----------------------------------------------------------------------------------------------- //
float3 FISPhong(FISSamplerType sSampler, float3 vNormal, float3 vView, float fSpecExponent, uint nNumSamples )
{
	// Useful for visualizing the sample distribution on a sphere with contant spec exponent (such as in the test levels)
	//return FISVisualizeSampleDistribution( vNormal, vView, fSpecExponent, nNumSamples ).rgb;

	// Approximate solid angle of texel (assume no projection distortion)
	float fLODPreComp = FISPreComputeLODFactor( nNumSamples, REFLECTION_MAP_SIZE, fSpecExponent );

	//fSpecExponent = max(1, fSpecExponent*0.25);

	float4 vSampleAccumulator = 0;
	float3 R = reflect( -vView, vNormal );
	for( uint i = 0; i < nNumSamples; i++ )
	{
		float3 Xi = Hammersley3( i, nNumSamples );
		float fSampleLOD = 0, fSamplePDFScale = 1;
		float3 L = ImportanceSamplePhong( Xi, fSpecExponent, R, fLODPreComp, fSampleLOD, fSamplePDFScale );
		//float NoL = saturate( dot( vNormal, L ) );

		[branch] if( fSamplePDFScale > 0 )
		{
			float3 vSampleColor = texCUBElod(sSampler,float4(-L,fSampleLOD)).rgb;
			float3 vSample = vSampleColor * fSamplePDFScale;
			vSampleAccumulator += float4(vSample,1);

		}
	}
	return (vSampleAccumulator.rgb/max(vSampleAccumulator.a,1));
}
// ----------------------------------------------------------------------------------------------- //
// This is not mathematically correct Blinn-Phong... use at your own risk
float3 FISBlinnPhong(FISSamplerType sSampler, float3 vNormal, float3 vView, float fSpecExponent, float fFresnelCoef, uint nNumSamples)
{
	// Useful for visualizing the sample distribution on a sphere with contant spec exponent (such as in the test levels)
	// return FISVisualizeSampleDistribution( vNormal, vView, fSpecExponent, nNumSamples ).rgb;

	// Approximate solid angle of texel (assume no projection distortion)
	float fLODPreComp = FISPreComputeLODFactor( nNumSamples, REFLECTION_MAP_SIZE, fSpecExponent );
	//fSpecExponent = max(fSpecExponent,1);

	float3 vReflect = reflect( -vView, vNormal );

	float4 vSampleAccumulator = 0;
	for( uint i = 0; i < nNumSamples; i++ )
	{
		float3 Xi = Hammersley3( i, nNumSamples );

		float fSampleLOD = 0;
		float fSamplePDFScale = 1;

		float3 L = ImportanceSampleBlinnPhong( Xi, fSpecExponent, fFresnelCoef, vNormal, vView, fLODPreComp, fSampleLOD, fSamplePDFScale );

		[branch] if( all(fSamplePDFScale > 0 )) 
		{
			float3 vSampleColor = texCUBElod(sSampler, float4(L, 0)).rgb;
			vSampleAccumulator += float4(vSampleColor.rgb * fSamplePDFScale, 1);
		}
	}

	return (vSampleAccumulator.rgb/max(vSampleAccumulator.a,1));
}

float3 FISDiffuse(FISSamplerType sSampler, float3 vNormal, uint nNumSamples )
{	
	// Approximate solid angle of texel (assume no projection distortion)
	float fLODPreComp = FISPreComputeLODFactor( nNumSamples, REFLECTION_MAP_SIZE, 512 );

	float4 vSampleAccumulator = 0;
	for( uint i = 0; i < nNumSamples; i++ )
	{
		float3 Xi = Hammersley3( i, nNumSamples );
		float fSampleLOD = 0, fSamplePDFScale = 1;
		float3 L = ImportanceSampleDiffuse( Xi,  vNormal, fLODPreComp, fSampleLOD, fSamplePDFScale );
		{
			float3 vSampleColor = texCUBElod(sSampler, float4(-L, fSampleLOD)).rgb;
			float3 vSample = vSampleColor * fSamplePDFScale;
			vSampleAccumulator += float4(vSample,1);
		}
	}
	return (vSampleAccumulator.rgb/nNumSamples);
}

#endif		// USE_FILTERED_IMPORTANCE_SAMPLING
#endif		// __RSG_FILTERED_IMPORTANCE_SAMPLING_FXH
