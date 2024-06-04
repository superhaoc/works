// ============================================
// Lighting/Shadows/cascadeshadows_sampling.fxh
// (c) 2011 RockstarNorth
// ============================================

#ifndef _CASCADESHADOWS_SAMPLING_FXH_
#define _CASCADESHADOWS_SAMPLING_FXH_

#if !DEFERRED_LOCAL_SHADOW_SAMPLING

#if CASCADE_SHADOWS_USE_HW_PCF_DX10
	#if CASCADE_SHADOW_TEXARRAY
	BeginDX10SamplerShared(SamplerComparisonState, Texture2DArray, gCSMShadowTexture, gCSMShadowTextureSamp, gCSMShadowTexture, s15)
	#else
	BeginDX10SamplerShared(SamplerComparisonState, Texture2D, gCSMShadowTexture, gCSMShadowTextureSamp, gCSMShadowTexture, s15)
	#endif
	ContinueSharedSampler( SamplerComparisonState,                 gCSMShadowTexture, gCSMShadowTextureSamp, gCSMShadowTexture, s15)
		AddressU  = CLAMP;
		AddressV  = CLAMP;
		AddressW  = CLAMP;
		MIPFILTER = MIPLINEAR;
		MINFILTER = LINEAR;
		MAGFILTER = LINEAR;
#if SUPPORT_INVERTED_VIEWPORT
	COMPARISONFUNC = COMPARISON_GREATER;
#else
	COMPARISONFUNC = COMPARISON_LESS_EQUAL;
#endif		
	EndSharedSampler;

	#define SHADOWSAMPLER_TEXSAMP	gCSMShadowTextureSamp
	#define SHADOWSAMPLER_TEXTURE	gCSMShadowTexture
#else //CASCADE_SHADOWS_USE_HW_PCF_DX10
	DECLARE_SHARED_SAMPLER(sampler2D, gCSMShadowTexture, gCSMShadowTextureSamp, s15, // overlap with ShadowZTextureDir
		AddressU  = CLAMP;
		AddressV  = CLAMP;
		AddressW  = CLAMP;
		MIPFILTER = NONE;
		MINFILTER = PS3_SWITCH(LINEAR, POINT);
		MAGFILTER = PS3_SWITCH(LINEAR, POINT);
		PS3_ONLY(TEXTUREZFUNC = TEXTUREZFUNC_GREATER;)
	);

	#define SHADOWSAMPLER_TEXSAMP	gCSMShadowTextureSamp
	#define SHADOWSAMPLER_TEXTURE	gCSMShadowTexture
#endif //CASCADE_SHADOWS_USE_HW_PCF_DX10


#if CASCADE_SHADOWS_USE_HW_PCF_DX10
		#define SHADOWSAMPLER			SamplerComparisonState
#else
	#if __SHADERMODEL >= 40
		#define SHADOWSAMPLER			SamplerState
	#else
		#define SHADOWSAMPLER			sampler2D
	#endif
#endif

float __texDepth2D_rage(sampler2D samp, float2 texcoord)
{
	const float4 depthSamp = tex2D(samp, texcoord);
	const float3 intValues = floor(255.0*depthSamp.xyz + 0.5);
	const float3 xyzFactor = float3(
		1.0/(256.0            ),
		1.0/(256.0*256.0      ),
		1.0/(256.0*256.0*256.0)
	);
	return dot(intValues, xyzFactor);
}

float __texDepth2D_precise(sampler2D samp, float2 texcoord)
{
	const float4 depthSamp = tex2D(samp, texcoord);
	const float3 intValues = floor(255.0*depthSamp.xyz + 0.5);
	const float3 xyzFactor = float3(
		(1.0*256.0*256.0)/(256.0*256.0*256.0 - 1.0),
		(1.0*256.0      )/(256.0*256.0*256.0 - 1.0),
		(1.0            )/(256.0*256.0*256.0 - 1.0)
	);
	return dot(intValues, xyzFactor);
}

float __texDepth2D_imprecise(sampler2D samp, float2 texcoord)
{
	const float4 depthSamp = tex2D(samp, texcoord);
	const float3 intValues = depthSamp.xyz;
	const float3 xyzFactor = float3(
		(255.0)/(256.0            ),
		(255.0)/(256.0*256.0      ),
		(255.0)/(256.0*256.0*256.0)
	);
	return dot(intValues, xyzFactor);
}

float __tex2DPCF(SHADOWSAMPLER samp, float4 texcoord)
{
	texcoord.z = fixupDepth(texcoord.z);
#if CASCADE_SHADOWS_USE_HW_PCF_DX10
	float shadow = SHADOWSAMPLER_TEXTURE.SampleCmpLevelZero(samp,float3(texcoord.xy, texcoord.w), texcoord.z);
	return shadow;
#else
	#if __SHADERMODEL >= 40
		return step(texcoord.z, SHADOWSAMPLER_TEXTURE.Sample(samp, texcoord.xy).x); // not actually PCF
	#else
		return 0;
	#endif
#endif
}

float4 SampleShadowDepth4(float3 texcoord)
{
#if CASCADE_SHADOWS_USE_HW_PCF_DX10
	#if 0 // Can not use sample comparison
		return SHADOWSAMPLER_TEXTURE.GatherRed(SHADOWSAMPLER_TEXSAMP, texcoord);
	#else
		float4 depths;

#if CASCADE_SHADOW_TEXARRAY
		depths = float4(
			SHADOWSAMPLER_TEXTURE.Load( int4( texcoord*gShadowRes.xy, 0,texcoord.z ) , int2(-1,0) ).x,
			SHADOWSAMPLER_TEXTURE.Load( int4( texcoord*gShadowRes.xy, 0,texcoord.z ) , int2(+1,0) ).x,
			SHADOWSAMPLER_TEXTURE.Load( int4( texcoord*gShadowRes.xy, 0,texcoord.z ) , int2(0,-1) ).x,
			SHADOWSAMPLER_TEXTURE.Load( int4( texcoord*gShadowRes.xy, 0,texcoord.z ) , int2(0,+1) ).x
			);
#else
		depths = float4(
			SHADOWSAMPLER_TEXTURE.Load( int3( texcoord*gShadowRes.xy, 0 ) + int3(-1,0,0) ).x,
			SHADOWSAMPLER_TEXTURE.Load( int3( texcoord*gShadowRes.xy, 0 ) + int3(+1,0,0) ).x,
			SHADOWSAMPLER_TEXTURE.Load( int3( texcoord*gShadowRes.xy, 0 ) + int3(0,-1,0) ).x,
			SHADOWSAMPLER_TEXTURE.Load( int3( texcoord*gShadowRes.xy, 0 ) + int3(0,+1,0) ).x
			);
#endif
		return depths;
	#endif // 0
#else
	//TODO: use texture offset and 4 samples
	return tex2D(SHADOWSAMPLER_TEXSAMP, texcoord).xxxx;
#endif
}

float2 SampleDitherRotate(float2 v_, int rot)
{
	const float sqrt_1_2 = 0.70710678118654752440084436210485; // sqrt(1/2)

	float2 v = v_;

	// rotation in 45-degree increments (rot should be constant)
	if (0) {}
	else if (rot == 1) { v = float2(+v.x + v.y, +v.x - v.y)*sqrt_1_2; }
	else if (rot == 2) { v = float2(-v.y, +v.x); }
	else if (rot == 3) { v = float2(-v.x - v.y, +v.x - v.y)*sqrt_1_2; }
	else if (rot == 4) { v = float2(-v.x, -v.y); }
	else if (rot == 5) { v = float2(-v.x + v.y, -v.x - v.y)*sqrt_1_2; }
	else if (rot == 6) { v = float2(+v.y, -v.x); }
	else if (rot == 7) { v = float2(+v.x + v.y, -v.x + v.y)*sqrt_1_2; }

	return v;
}

#if __PS3 || (__SHADERMODEL >= 40)

float2 __interp2(float x) // interpolate between [y0,y1]
{
	return float2(1 - x, x);
}

float3 __interp3(float x) // interpolate between [(y0+y1)/2,(y1+y2)/2]
{
	return float3
	(
		(1 - 2*x + 1*x*x),
		(1 + 2*x - 2*x*x),
		(          1*x*x)
	)/2;
}

float4 __interp4(float x) // interpolate between [(y0+4*y1+y2)/6,(y1+4*y2+y3)/6]
{
	return float4
	(
		(1 - 3*x + 3*x*x - 1*x*x*x),
		(4       - 6*x*x + 3*x*x*x),
		(1 + 3*x + 3*x*x - 3*x*x*x),
		(                  1*x*x*x)
	)/6;
}

float tex2DDepthCubic(SHADOWSAMPLER samp, float4 texcoord, float4 res)
{
	float2 pixcoord = texcoord.xy*res.xy + 0.5; // [0..res]
	float2 texscale = 1.0*res.zw;
	float4 v0;

	float2 weights = frac(pixcoord);

	float4 cx = __interp4(weights.x);
	float4 cy = __interp4(weights.y);

	float x0 = cx.y/(cx.x + cx.y) - weights.x - 1;
	float y0 = cy.y/(cy.x + cy.y) - weights.y - 1;
	float x1 = cx.w/(cx.z + cx.w) - weights.x + 1;
	float y1 = cy.w/(cy.z + cy.w) - weights.y + 1;

	v0.x = __tex2DPCF(samp, texcoord + float4(float2(x0, y0)*texscale, 0, 0));
	v0.y = __tex2DPCF(samp, texcoord + float4(float2(x1, y0)*texscale, 0, 0));
	v0.z = __tex2DPCF(samp, texcoord + float4(float2(x0, y1)*texscale, 0, 0));
	v0.w = __tex2DPCF(samp, texcoord + float4(float2(x1, y1)*texscale, 0, 0));

	v0.x = (cx.x + cx.y)*v0.x + (cx.z + cx.w)*v0.y;
	v0.z = (cx.x + cx.y)*v0.z + (cx.z + cx.w)*v0.w;

	v0.x = (cy.x + cy.y)*v0.x + (cy.z + cy.w)*v0.z;

	return v0.x;
}

#endif // __PS3 || (__SHADERMODEL >= 40)

float __tex2DDepth1(SHADOWSAMPLER samp, float4 t0)
{
	float temp = 0;
#if __XENON 
	temp = tex2D(samp, t0.xy).x;
	temp = step(t0.z, XENON_ONLY(1-)temp);
#else
	temp = __tex2DPCF(samp, t0);
#endif
	return temp;
}

float2 __tex2DDepth2(SHADOWSAMPLER samp, float4 t0, float4 t1)
{
	float2 temp;
#if __XENON
	temp.x = tex2D(samp, t0.xy).x;
	temp.y = tex2D(samp, t1.xy).x;
	temp   = step(float2(t0.z, t1.z), XENON_ONLY(1-)temp);
#else
	temp.x = __tex2DPCF(samp, t0);
	temp.y = __tex2DPCF(samp, t1);
#endif
	return temp;
}

float3 __tex2DDepth3(SHADOWSAMPLER samp, float4 t0, float4 t1, float4 t2)
{
	float3 temp;
#if __XENON
	temp.x = tex2D(samp, t0.xy).x;
	temp.y = tex2D(samp, t1.xy).x;
	temp.z = tex2D(samp, t2.xy).x;
	temp   = step(float3(t0.z, t1.z, t2.z), XENON_ONLY(1-)temp);
#else
	temp.x = __tex2DPCF(samp, t0);
	temp.y = __tex2DPCF(samp, t1);
	temp.z = __tex2DPCF(samp, t2);
#endif
	return temp;
}

float4 __tex2DDepth4(SHADOWSAMPLER samp, float4 t0, float4 t1, float4 t2, float4 t3)
{
	float4 temp;
#if __XENON
	temp.x = tex2D(samp, t0.xy).x;
	temp.y = tex2D(samp, t1.xy).x;
	temp.z = tex2D(samp, t2.xy).x;
	temp.w = tex2D(samp, t3.xy).x;
	temp   = step(float4(t0.z, t1.z, t2.z, t3.z), XENON_ONLY(1-)temp);
#else
	temp.x = __tex2DPCF(samp, t0);
	temp.y = __tex2DPCF(samp, t1);
	temp.z = __tex2DPCF(samp, t2);
	temp.w = __tex2DPCF(samp, t3);
#endif
	return temp;
}

// receiver plane depth bias. (see GDC 06 paper "Shadow Mapping: GPU-based Tips and Techniques", http://developer.amd.com/wordpress/media/2012/10/Isidoro-ShadowMapping.pdf)
float2 ComputeRecieverPlaneDepthBias(float3 texcoord, float3 scale)
{
	//Packing derivatives of u,v, and distance to light source w.r.t. screen space x, and y
	float3 duvdist_dx = ddx(texcoord.xyz)*scale;
	float3 duvdist_dy = ddy(texcoord.xyz)*scale;

	//Invert texture Jacobian and use chain rule to compute ddist/du and ddist/dv
	// |ddist/du| = |du/dx du/dy|-T * |ddist/dx|
	// |ddist/dv|   |dv/dx dv/dy|     |ddist/dy|
	float2 ddist_duv;

	//Multiply ddist/dx and ddist/dy by inverse transpose of Jacobian
	float invDet = 1 / ((duvdist_dx.x * duvdist_dy.y) - (duvdist_dx.y * duvdist_dy.x) );

	//Top row of 2x2
	ddist_duv.x = duvdist_dy.y * duvdist_dx.z;		// invJtrans[0][0] * ddist_dx
	ddist_duv.x -= duvdist_dx.y * duvdist_dy.z;		// invJtrans[0][1] * ddist_dy
	//Bottom row of 2x2
	ddist_duv.y = duvdist_dx.x * duvdist_dy.z;		// invJtrans[1][1] * ddist_dy
	ddist_duv.y -= duvdist_dy.x * duvdist_dx.z; 	// invJtrans[1][0] * ddist_dx
	ddist_duv *= invDet;

	return clamp(ddist_duv,-1,1); // add a clamp to avoid halos when ddx or ddy goes steep
}

struct ShadowSampleParams
{
	SHADOWSAMPLER samp;
	float4 texcoord;
	float4 res;
	float2 v;
	float2 scale;
	float2 ddist_duv;
};

#define DECLARE_SHADOWSAMPLEPARAMS \
	SHADOWSAMPLER samp = sampleParams.samp; \
	float4 texcoord    = sampleParams.texcoord; \
	float4 res         = sampleParams.res; \
	float2 v           = sampleParams.v; \
	float2 scale       = sampleParams.scale; \
	float2 ddist_duv   = sampleParams.ddist_duv; \

// ================================================================================================
float Sample_CSM_ST_POINT(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	return __tex2DDepth1(samp, texcoord);
}

float Sample_CSM_ST_BOX(ShadowSampleParams sampleParams, int n, bool bCubic, bool bPenumbra);
float Sample_CSM_ST_LINEAR(ShadowSampleParams sampleParams)
{
	sampleParams.scale = 0;
	return Sample_CSM_ST_BOX(sampleParams, 0, false, false); // maybe less efficient, but this is for debugging
}

float Sample_CSM_ST_CUBIC(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
#if __XENON || __MAX || (__WIN32PC && __SHADERMODEL < 40)
	return __tex2DDepth1(samp, texcoord); // not implemented
#else
	return tex2DDepthCubic(samp, texcoord, res);
#endif
}

float Sample_CSM_ST_TWOTAP(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	const float4 delta = float4(float2(0.375f, 0.375f)*res.zw, 0, 0);
	return (__tex2DPCF(samp, texcoord - delta) + __tex2DPCF(samp, texcoord + delta))/2;
}

float Sample_CSM_ST_BOX3x3(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	float4 temp0;

#if RSG_PC
	float4 t0 = float4(float2(-0.5, -0.5)*res.zw, texcoord.zw); t0.xyz += float3(texcoord.xy, dot(ddist_duv,t0.xy));
	float4 t1 = float4(float2(+0.5, -0.5)*res.zw, texcoord.zw); t1.xyz += float3(texcoord.xy, dot(ddist_duv,t1.xy));
	float4 t2 = float4(float2(-0.5, +0.5)*res.zw, texcoord.zw); t2.xyz += float3(texcoord.xy, dot(ddist_duv,t2.xy));
	float4 t3 = float4(float2(+0.5, +0.5)*res.zw, texcoord.zw); t3.xyz += float3(texcoord.xy, dot(ddist_duv,t3.xy));
#else
	float4 t0 = texcoord + float4(float2(-0.5, -0.5)*res.zw, 0,0);
	float4 t1 = texcoord + float4(float2(+0.5, -0.5)*res.zw, 0,0);
	float4 t2 = texcoord + float4(float2(-0.5, +0.5)*res.zw, 0,0);
	float4 t3 = texcoord + float4(float2(+0.5, +0.5)*res.zw, 0,0);
#endif

	temp0.x = __tex2DPCF(samp, t0);
	temp0.y = __tex2DPCF(samp, t1);
	temp0.z = __tex2DPCF(samp, t2);
	temp0.w = __tex2DPCF(samp, t3);

	return dot(temp0, 1)/4;
}

float Sample_CSM_ST_BOX4x4(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	float3 temp0;
	float3 temp1;
	float3 temp2;

	temp0.x = __tex2DPCF(samp, texcoord + float4(float2(-1, -1)*res.zw, 0,0));
	temp0.y = __tex2DPCF(samp, texcoord + float4(float2( 0, -1)*res.zw, 0,0));
	temp0.z = __tex2DPCF(samp, texcoord + float4(float2(+1, -1)*res.zw, 0,0));

	temp1.x = __tex2DPCF(samp, texcoord + float4(float2(-1,  0)*res.zw, 0,0));
	temp1.y = __tex2DPCF(samp, texcoord + float4(float2( 0,  0)*res.zw, 0,0));
	temp1.z = __tex2DPCF(samp, texcoord + float4(float2(+1,  0)*res.zw, 0,0));

	temp2.x = __tex2DPCF(samp, texcoord + float4(float2(-1, +1)*res.zw, 0,0));
	temp2.y = __tex2DPCF(samp, texcoord + float4(float2( 0, +1)*res.zw, 0,0));
	temp2.z = __tex2DPCF(samp, texcoord + float4(float2(+1, +1)*res.zw, 0,0));

	return dot(temp0 + temp1 + temp2, 1)/9;
}

float Sample_CSM_ST_BOX5x5(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
#if CASCADE_SHADOWS_USE_HW_PCF_DX10

	float4 temp0;
	float4 temp1;
	float4 temp2;
	float4 temp3;

	temp0.x = __tex2DPCF(samp, texcoord + float4(float2(-1.5, -1.5)*res.zw, 0,0));
	temp0.y = __tex2DPCF(samp, texcoord + float4(float2(-0.5, -1.5)*res.zw, 0,0));
	temp0.z = __tex2DPCF(samp, texcoord + float4(float2(+0.5, -1.5)*res.zw, 0,0));
	temp0.w = __tex2DPCF(samp, texcoord + float4(float2(+1.5, -1.5)*res.zw, 0,0));

	temp1.x = __tex2DPCF(samp, texcoord + float4(float2(-1.5, -0.5)*res.zw, 0,0));
	temp1.y = __tex2DPCF(samp, texcoord + float4(float2(-0.5, -0.5)*res.zw, 0,0));
	temp1.z = __tex2DPCF(samp, texcoord + float4(float2(+0.5, -0.5)*res.zw, 0,0));
	temp1.w = __tex2DPCF(samp, texcoord + float4(float2(+1.5, -0.5)*res.zw, 0,0));

	temp2.x = __tex2DPCF(samp, texcoord + float4(float2(-1.5, +0.5)*res.zw, 0,0));
	temp2.y = __tex2DPCF(samp, texcoord + float4(float2(-0.5, +0.5)*res.zw, 0,0));
	temp2.z = __tex2DPCF(samp, texcoord + float4(float2(+0.5, +0.5)*res.zw, 0,0));
	temp2.w = __tex2DPCF(samp, texcoord + float4(float2(+1.5, +0.5)*res.zw, 0,0));

	temp3.x = __tex2DPCF(samp, texcoord + float4(float2(-1.5, +1.5)*res.zw, 0,0));
	temp3.y = __tex2DPCF(samp, texcoord + float4(float2(-0.5, +1.5)*res.zw, 0,0));
	temp3.z = __tex2DPCF(samp, texcoord + float4(float2(+0.5, +1.5)*res.zw, 0,0));
	temp3.w = __tex2DPCF(samp, texcoord + float4(float2(+1.5, +1.5)*res.zw, 0,0));

	return dot(temp0 + temp1 + temp2 + temp3, 1)/16;

#else // CASCADE_SHADOWS_USE_HW_PCF_DX10

	float  tempA;
	float4 tempB;
	float4 tempC;
	float4 tempD;
	float4 tempE;
	float4 tempF;
	float4 tempG;
	float  tempH;

	// E.x---D.w---D.z---D.y---D.x
	//  |     |     |     |     |
	//  |     |     |     |     |
	//  |     |     |     |     |
	// E.y---G.z---G.y---G.x---C.w
	//  |     |     |     |     |
	//  |     |     |     |     |
	//  |     |     |     |     |
	// E.z---G.w---H.x---F.w---C.z
	//  |     |     |     |     |
	//  |     |     |     |     |
	//  |     |     |     |     |
	// E.w---F.x---F.y---F.z---C.y
	//  |     |     |     |     |
	//  |     |     |     |     |
	//  |     |     |     |     |
	// B.x---B.y---B.z---B.w---C.x
	// 
	// weights:
	//   F,G,H = 1
	//   B.x = (1-fx)*(1-fy), B.yzw = (1-fy)
	//   C.x = (  fx)*(1-fy), C.yzw = (  fx)
	//   D.x = (  fx)*(  fy), D.yzw = (  fy)
	//   E.x = (1-fx)*(  fy), E.yzw = (1-fx)
#if __SHADERMODEL >= 40
	int4 intCoords;
	intCoords.xy = float2(texcoord.xy*res.xy);
	intCoords.zw = 0;
	tempB.x = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-2, -2)).x;
	tempB.y = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-1, -2)).x;
	tempB.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 0, -2)).x;
	tempB.w = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 0, -2)).x;

	tempC.x = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 2, -2)).x;
	tempC.y = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 2, -1)).x;
	tempC.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 2,  0)).x;
	tempC.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 2,  1)).x;

	tempD.x = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 2,  2)).x;
	tempD.y = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 1,  2)).x;
	tempD.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 0,  2)).x;
	tempD.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-1,  2)).x;

	tempE.x = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-2,  2)).x;
	tempE.y = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-2,  1)).x;
	tempE.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-2,  0)).x;
	tempE.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-2, -1)).x;

	tempF.x = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-1, -1)).x;
	tempF.y = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 0, -1)).x;
	tempF.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 1, -1)).x;
	tempF.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 1,  0)).x;

	tempG.x = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 1,  1)).x;
	tempG.y = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2( 0,  1)).x;
	tempG.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-1,  1)).x;
	tempG.z = SHADOWSAMPLER_TEXTURE.Load(intCoords, int2(-1,  0)).x;

	tempH   = SHADOWSAMPLER_TEXTURE.Load(intCoords, 0).x;
#else
	tempB.x = tex2D(samp, texcoord.xy + float2(-2.0, -2.0)*res.zw).x;
	tempB.y = tex2D(samp, texcoord.xy + float2(-1.0, -2.0)*res.zw).x;
	tempB.z = tex2D(samp, texcoord.xy + float2( 0.0, -2.0)*res.zw).x;
	tempB.w = tex2D(samp, texcoord.xy + float2(+1.0, -2.0)*res.zw).x;

	tempC.x = tex2D(samp, texcoord.xy + float2(+2.0, -2.0)*res.zw).x;
	tempC.y = tex2D(samp, texcoord.xy + float2(+2.0, -1.0)*res.zw).x;
	tempC.z = tex2D(samp, texcoord.xy + float2(+2.0,  0.0)*res.zw).x;
	tempC.w = tex2D(samp, texcoord.xy + float2(+2.0, +1.0)*res.zw).x;

	tempD.x = tex2D(samp, texcoord.xy + float2(+2.0, +2.0)*res.zw).x;
	tempD.y = tex2D(samp, texcoord.xy + float2(+1.0, +2.0)*res.zw).x;
	tempD.z = tex2D(samp, texcoord.xy + float2( 0.0, +2.0)*res.zw).x;
	tempD.w = tex2D(samp, texcoord.xy + float2(-1.0, +2.0)*res.zw).x;

	tempE.x = tex2D(samp, texcoord.xy + float2(-2.0, +2.0)*res.zw).x;
	tempE.y = tex2D(samp, texcoord.xy + float2(-2.0, +1.0)*res.zw).x;
	tempE.z = tex2D(samp, texcoord.xy + float2(-2.0,  0.0)*res.zw).x;
	tempE.w = tex2D(samp, texcoord.xy + float2(-2.0, -1.0)*res.zw).x;

	tempF.x = tex2D(samp, texcoord.xy + float2(-1.0, -1.0)*res.zw).x;
	tempF.y = tex2D(samp, texcoord.xy + float2( 0.0, -1.0)*res.zw).x;
	tempF.z = tex2D(samp, texcoord.xy + float2(+1.0, -1.0)*res.zw).x;
	tempF.w = tex2D(samp, texcoord.xy + float2(+1.0,  0.0)*res.zw).x;

	tempG.x = tex2D(samp, texcoord.xy + float2(+1.0, +1.0)*res.zw).x;
	tempG.y = tex2D(samp, texcoord.xy + float2( 0.0, +1.0)*res.zw).x;
	tempG.z = tex2D(samp, texcoord.xy + float2(-1.0, +1.0)*res.zw).x;
	tempG.w = tex2D(samp, texcoord.xy + float2(-1.0,  0.0)*res.zw).x;

	tempH   = tex2D(samp, texcoord.xy + float2( 0.0,  0.0)*res.zw).x;
#endif

	tempB = step(texcoord.z, tempB);
	tempC = step(texcoord.z, tempC);
	tempD = step(texcoord.z, tempD);
	tempE = step(texcoord.z, tempE);
	tempF = step(texcoord.z, tempF);
	tempG = step(texcoord.z, tempG);
	tempH = step(texcoord.z, tempH);

	float4 f;
	f.zw = frac(texcoord.xy*res.xy);
	f.xy = 1 - f.zw;

	tempB.x *= f.x; // 1-fx
	tempC.x *= f.y; // 1-fy
	tempD.x *= f.z; //   fx
	tempE.x *= f.w; //   fy

	tempA  = dot(tempB, f.y); // 1-fy
	tempA += dot(tempC, f.z); //   fx
	tempA += dot(tempD, f.w); //   fy
	tempA += dot(tempE, f.x); // 1-fx
	tempA += dot(tempF + tempG, 1) + tempH;

	return tempA/16;
#endif // not __PS3
}

float Sample_CSM_ST_BOX(ShadowSampleParams sampleParams, int n, bool bCubic, bool bPenumbra)
{
	float acc = 0;
	float acc_penumbra0 = 0;
	float acc_penumbra1 = 0;

	DECLARE_SHADOWSAMPLEPARAMS

#if (n > 1)
	for (int j = 0; j < n - 1; j++)
	{
		for (int i = 0; i < n - 1; i++)
		{
			const float dx = i + 1 - n/2.0;
			const float dy = j + 1 - n/2.0;
#else
	int j = 0; 
	{
		int i = 0;
		{
			const float dx = 0;
			const float dy = 0;
#endif // (n > 1)

			if (bPenumbra)
			{
				const float s = __tex2DDepth1(samp, texcoord + float4(float2(dx, dy)*res.zw, 0,0));

				if      (s == 0) { acc_penumbra0 += 1; }
				else if (s == 1) { acc_penumbra1 += 1; }
				else             { acc_penumbra0 += 1; acc_penumbra1 += 1; }
			}
			else if (bCubic)
			{
				sampleParams.texcoord = texcoord + float4(float2(dx, dy)*res.zw, 0,0);
				sampleParams.v        = 0;
				sampleParams.scale    = 0;
				acc += Sample_CSM_ST_CUBIC(sampleParams);
			}
			else
			{
				acc += __tex2DDepth1(samp, texcoord + float4(float2(dx, dy)*res.zw, 0,0));
			}
		}
	}

	if (bPenumbra)
	{
		acc = (acc_penumbra0*acc_penumbra1 == 0) ? 1 : 0;
	}
	else
	{
		acc /= (float)((n - 1)*(n - 1));
	}

	return acc;
}

//float Sample_CSM_ST_BOX6x6(sampler2D samp, float3 texcoord, float4 res, float2 v, float2 scale) { return Sample_CSM_ST_BOX(samp, texcoord, res, v, scale, 6, false, false); }
//float Sample_CSM_ST_BOX7x7(sampler2D samp, float3 texcoord, float4 res, float2 v, float2 scale) { return Sample_CSM_ST_BOX(samp, texcoord, res, v, scale, 7, false, false); }
//float Sample_CSM_ST_BOX8x8(sampler2D samp, float3 texcoord, float4 res, float2 v, float2 scale) { return Sample_CSM_ST_BOX(samp, texcoord, res, v, scale, 8, false, false); }
//float Sample_CSM_ST_BOX9x9(sampler2D samp, float3 texcoord, float4 res, float2 v, float2 scale) { return Sample_CSM_ST_BOX(samp, texcoord, res, v, scale, 9, false, false); }

//float Sample_CSM_ST_BOX2x2P(sampler2D samp, float3 texcoord, float4 res, float2 v, float2 scale) { return Sample_CSM_ST_BOX(samp, texcoord, res, v, scale, 2, false, true); }
//float Sample_CSM_ST_BOX3x3P(sampler2D samp, float3 texcoord, float4 res, float2 v, float2 scale) { return Sample_CSM_ST_BOX(samp, texcoord, res, v, scale, 3, false, true); }
//float Sample_CSM_ST_BOX4x4P(sampler2D samp, float3 texcoord, float4 res, float2 v, float2 scale) { return Sample_CSM_ST_BOX(samp, texcoord, res, v, scale, 4, false, true); }

float Sample_CSM_ST_DITHER1(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	const float2 v_a = v;

	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);

	return __tex2DDepth1(samp, t0_a);
}

float Sample_CSM_ST_DITHER2(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	const float2 v_a = v;

	const float4 t0_a = texcoord + float4(float2(+v_a.x, +v_a.y)*(1.00)*scale, 0,0);
	const float4 t1_a = texcoord + float4(float2(-v_a.y, +v_a.x)*(0.50)*scale, 0,0);

	const float2 temp_a = __tex2DDepth2(samp, t0_a, t1_a);

	return dot(temp_a, 1)/2;
}

float Sample_CSM_ST_DITHER3(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	const float2 v_a = v;

	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);
	const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0);
	const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0);

	const float3 temp_a = __tex2DDepth3(samp, t0_a, t1_a, t2_a);

	return dot(temp_a, 1)/3;
}

float Sample_CSM_ST_DITHER4(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	const float2 v_a = v;

	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);
	const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0);
	const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0);
	const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0);

	const float4 temp_a = __tex2DDepth4(samp, t0_a, t1_a, t2_a, t3_a);

	return dot(temp_a, 1)/4;
}

float Sample_CSM_ST_DITHER6(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	const float2 v_a = v;
	const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; // rotate by 90 degrees

	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);
	const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0);
	const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0);
	const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0);

	const float4 t0_b = texcoord + float4(scale*float2(+v_b.x, +v_b.y)*(1.00), 0,0);
	const float4 t1_b = texcoord + float4(scale*float2(-v_b.y, +v_b.x)*(0.50), 0,0);

	const float4 temp_a = __tex2DDepth4(samp, t0_a, t1_a, t2_a, t3_a);
	const float2 temp_b = __tex2DDepth2(samp, t0_b, t1_b);

	return dot(temp_a + float4(temp_b, 0, 0), 1)/6;
}

float Sample_CSM_ST_DITHER8(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	const float2 v_a = v;
	const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; // rotate by 90 degrees

	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);
	const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0);
	const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0);
	const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0);

	const float4 t0_b = texcoord + float4(scale*float2(+v_b.x, +v_b.y)*(1.00), 0,0);
	const float4 t1_b = texcoord + float4(scale*float2(-v_b.y, +v_b.x)*(0.50), 0,0);
	const float4 t2_b = texcoord + float4(scale*float2(-v_b.x, -v_b.y)*(0.75), 0,0);
	const float4 t3_b = texcoord + float4(scale*float2(+v_b.y, -v_b.x)*(0.25), 0,0);

	const float4 temp_a = __tex2DDepth4(samp, t0_a, t1_a, t2_a, t3_a);
	const float4 temp_b = __tex2DDepth4(samp, t0_b, t1_b, t2_b, t3_b);

	return dot(temp_a + temp_b, 1)/8;
}

float Sample_CSM_ST_DITHER2_LINEAR(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	sampleParams.texcoord = texcoord + float4(scale*v.xy, 0, 0);
	sampleParams.v        = 0;
	sampleParams.scale    = 0;
	const float a = Sample_CSM_ST_LINEAR(sampleParams);
	sampleParams.texcoord = texcoord + float4(scale*v.yx*float2(-.5f,.5f), 0, 0);
	const float b = Sample_CSM_ST_LINEAR(sampleParams);
	return (a+b)/2;
}

float Sample_CSM_ST_DITHER16(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS
	const float2 v_a = v;
	const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; // rotate by 90 degrees
	const float2 v_c = SampleDitherRotate(v_a, 4)*0.777; // rotate by 180 degrees
	const float2 v_d = SampleDitherRotate(v_a, 6)*0.666; // rotate by 270 degrees

	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);
	const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0);
	const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0);
	const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0);

	const float4 t0_b = texcoord + float4(scale*float2(+v_b.x, +v_b.y)*(1.00), 0,0);
	const float4 t1_b = texcoord + float4(scale*float2(-v_b.y, +v_b.x)*(0.50), 0,0);
	const float4 t2_b = texcoord + float4(scale*float2(-v_b.x, -v_b.y)*(0.75), 0,0);
	const float4 t3_b = texcoord + float4(scale*float2(+v_b.y, -v_b.x)*(0.25), 0,0);

	const float4 t0_c = texcoord + float4(scale*float2(+v_c.x, +v_c.y)*(1.00), 0,0);
	const float4 t1_c = texcoord + float4(scale*float2(-v_c.y, +v_c.x)*(0.50), 0,0);
	const float4 t2_c = texcoord + float4(scale*float2(-v_c.x, -v_c.y)*(0.75), 0,0);
	const float4 t3_c = texcoord + float4(scale*float2(+v_c.y, -v_c.x)*(0.25), 0,0);

	const float4 t0_d = texcoord + float4(scale*float2(+v_d.x, +v_d.y)*(1.00), 0,0);
	const float4 t1_d = texcoord + float4(scale*float2(-v_d.y, +v_d.x)*(0.50), 0,0);
	const float4 t2_d = texcoord + float4(scale*float2(-v_d.x, -v_d.y)*(0.75), 0,0);
	const float4 t3_d = texcoord + float4(scale*float2(+v_d.y, -v_d.x)*(0.25), 0,0);

	const float4 temp_a = __tex2DDepth4(samp, t0_a, t1_a, t2_a, t3_a);
	const float4 temp_b = __tex2DDepth4(samp, t0_b, t1_b, t2_b, t3_b);
	const float4 temp_c = __tex2DDepth4(samp, t0_c, t1_c, t2_c, t3_c);
	const float4 temp_d = __tex2DDepth4(samp, t0_d, t1_d, t2_d, t3_d);

	return dot(temp_a + temp_b + temp_c + temp_d, 1)/16;
}

float Sample_CSM_ST_DITHER16_RPDB(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS;

	const float2 v_a = v;
	const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; // rotate by 90 degrees
	const float2 v_c = SampleDitherRotate(v_a, 4)*0.777; // rotate by 180 degrees
	const float2 v_d = SampleDitherRotate(v_a, 6)*0.666; // rotate by 270 degrees

	float4 t0_a = float4(scale*float2(+v_a.x, +v_a.y)*(1.00), texcoord.zw); t0_a.xyz += float3(texcoord.xy, dot(ddist_duv,t0_a.xy));
	float4 t1_a = float4(scale*float2(-v_a.y, +v_a.x)*(0.50), texcoord.zw); t1_a.xyz += float3(texcoord.xy, dot(ddist_duv,t1_a.xy));
	float4 t2_a = float4(scale*float2(-v_a.x, -v_a.y)*(0.75), texcoord.zw); t2_a.xyz += float3(texcoord.xy, dot(ddist_duv,t2_a.xy));
	float4 t3_a = float4(scale*float2(+v_a.y, -v_a.x)*(0.25), texcoord.zw); t3_a.xyz += float3(texcoord.xy, dot(ddist_duv,t3_a.xy));

	float4 t0_b = float4(scale*float2(+v_b.x, +v_b.y)*(1.00), texcoord.zw); t0_b.xyz += float3(texcoord.xy, dot(ddist_duv,t0_b.xy));
	float4 t1_b = float4(scale*float2(-v_b.y, +v_b.x)*(0.50), texcoord.zw); t1_b.xyz += float3(texcoord.xy, dot(ddist_duv,t1_b.xy));
	float4 t2_b = float4(scale*float2(-v_b.x, -v_b.y)*(0.75), texcoord.zw); t2_b.xyz += float3(texcoord.xy, dot(ddist_duv,t2_b.xy));
	float4 t3_b = float4(scale*float2(+v_b.y, -v_b.x)*(0.25), texcoord.zw); t3_b.xyz += float3(texcoord.xy, dot(ddist_duv,t3_b.xy));

	float4 t0_c = float4(scale*float2(+v_c.x, +v_c.y)*(1.00), texcoord.zw); t0_c.xyz += float3(texcoord.xy, dot(ddist_duv,t0_c.xy));
	float4 t1_c = float4(scale*float2(-v_c.y, +v_c.x)*(0.50), texcoord.zw); t1_c.xyz += float3(texcoord.xy, dot(ddist_duv,t1_c.xy));
	float4 t2_c = float4(scale*float2(-v_c.x, -v_c.y)*(0.75), texcoord.zw); t2_c.xyz += float3(texcoord.xy, dot(ddist_duv,t2_c.xy));
	float4 t3_c = float4(scale*float2(+v_c.y, -v_c.x)*(0.25), texcoord.zw); t3_c.xyz += float3(texcoord.xy, dot(ddist_duv,t3_c.xy));

	float4 t0_d = float4(scale*float2(+v_d.x, +v_d.y)*(1.00), texcoord.zw); t0_d.xyz += float3(texcoord.xy, dot(ddist_duv,t0_d.xy));
	float4 t1_d = float4(scale*float2(-v_d.y, +v_d.x)*(0.50), texcoord.zw); t1_d.xyz += float3(texcoord.xy, dot(ddist_duv,t1_d.xy));
	float4 t2_d = float4(scale*float2(-v_d.x, -v_d.y)*(0.75), texcoord.zw); t2_d.xyz += float3(texcoord.xy, dot(ddist_duv,t2_d.xy));
	float4 t3_d = float4(scale*float2(+v_d.y, -v_d.x)*(0.25), texcoord.zw); t3_d.xyz += float3(texcoord.xy, dot(ddist_duv,t3_d.xy));

	const float4 temp_a = __tex2DDepth4(samp, t0_a, t1_a, t2_a, t3_a);
	const float4 temp_b = __tex2DDepth4(samp, t0_b, t1_b, t2_b, t3_b);
	const float4 temp_c = __tex2DDepth4(samp, t0_c, t1_c, t2_c, t3_c);
	const float4 temp_d = __tex2DDepth4(samp, t0_d, t1_d, t2_d, t3_d);

	return dot(temp_a + temp_b + temp_c + temp_d, 1)/16;
}

float Sample_CSM_ST_POISSON16_RPDB(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS;

	//http://www.coderhaus.com/?p=11
	const float2 poisson16[16] =
	{
		float2(-0.2472118f, 0.9385423f),
		float2(-0.5709225f, 0.5764017f),
		float2(-0.02226822f, 0.5123936f),
		float2(0.3676782f, 0.7242927f),
		float2(-0.0520498f, 0.02313526f),
		float2(-0.6927009f, 0.09863317f),
		float2(0.3896762f, 0.06893869f),
		float2(-0.02064722f, -0.3908131f),
		float2(-0.3425082f, -0.6995225f),
		float2(0.5419917f, -0.320312f),
		float2(0.2423947f, -0.7123652f),
		float2(0.7647126f, 0.594636f),
		float2(0.924313f, -0.0516505f),
		float2(-0.5339736f, -0.325641f),
		float2(0.6769441f, -0.710753f),
		float2(-0.9593949f, -0.2530973f)
	};

	float4 t0_a = float4(poisson16[ 0]*scale, texcoord.zw); t0_a.xyz += float3(texcoord.xy, dot(ddist_duv,t0_a.xy));
	float4 t1_a = float4(poisson16[ 1]*scale, texcoord.zw); t1_a.xyz += float3(texcoord.xy, dot(ddist_duv,t1_a.xy));
	float4 t2_a = float4(poisson16[ 2]*scale, texcoord.zw); t2_a.xyz += float3(texcoord.xy, dot(ddist_duv,t2_a.xy));
	float4 t3_a = float4(poisson16[ 3]*scale, texcoord.zw); t3_a.xyz += float3(texcoord.xy, dot(ddist_duv,t3_a.xy));

	float4 t0_b = float4(poisson16[ 4]*scale, texcoord.zw); t0_b.xyz += float3(texcoord.xy, dot(ddist_duv,t0_b.xy));
	float4 t1_b = float4(poisson16[ 5]*scale, texcoord.zw); t1_b.xyz += float3(texcoord.xy, dot(ddist_duv,t1_b.xy));
	float4 t2_b = float4(poisson16[ 6]*scale, texcoord.zw); t2_b.xyz += float3(texcoord.xy, dot(ddist_duv,t2_b.xy));
	float4 t3_b = float4(poisson16[ 7]*scale, texcoord.zw); t3_b.xyz += float3(texcoord.xy, dot(ddist_duv,t3_b.xy));

	float4 t0_c = float4(poisson16[ 8]*scale, texcoord.zw); t0_c.xyz += float3(texcoord.xy, dot(ddist_duv,t0_c.xy));
	float4 t1_c = float4(poisson16[ 9]*scale, texcoord.zw); t1_c.xyz += float3(texcoord.xy, dot(ddist_duv,t1_c.xy));
	float4 t2_c = float4(poisson16[10]*scale, texcoord.zw); t2_c.xyz += float3(texcoord.xy, dot(ddist_duv,t2_c.xy));
	float4 t3_c = float4(poisson16[11]*scale, texcoord.zw); t3_c.xyz += float3(texcoord.xy, dot(ddist_duv,t3_c.xy));

	float4 t0_d = float4(poisson16[12]*scale, texcoord.zw); t0_d.xyz += float3(texcoord.xy, dot(ddist_duv,t0_d.xy));
	float4 t1_d = float4(poisson16[13]*scale, texcoord.zw); t1_d.xyz += float3(texcoord.xy, dot(ddist_duv,t1_d.xy));
	float4 t2_d = float4(poisson16[14]*scale, texcoord.zw); t2_d.xyz += float3(texcoord.xy, dot(ddist_duv,t2_d.xy));
	float4 t3_d = float4(poisson16[15]*scale, texcoord.zw); t3_d.xyz += float3(texcoord.xy, dot(ddist_duv,t3_d.xy));

	const float4 temp_a = __tex2DDepth4(samp, t0_a, t1_a, t2_a, t3_a);
	const float4 temp_b = __tex2DDepth4(samp, t0_b, t1_b, t2_b, t3_b);
	const float4 temp_c = __tex2DDepth4(samp, t0_c, t1_c, t2_c, t3_c);
	const float4 temp_d = __tex2DDepth4(samp, t0_d, t1_d, t2_d, t3_d);

	return dot(temp_a + temp_b + temp_c + temp_d, 1)/16;
}

float Sample_CSM_ST_POISSON16_RPDB_GNORM(ShadowSampleParams sampleParams)
{
	return Sample_CSM_ST_POISSON16_RPDB(sampleParams);
}

float Sample_CSM_ST_DITHER12_RPDB(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS;

	const float2 v_a = v;
	const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; // rotate by 90 degrees
	const float2 v_c = SampleDitherRotate(v_a, 4)*0.777; // rotate by 180 degrees
	const float2 v_d = SampleDitherRotate(v_a, 6)*0.666; // rotate by 270 degrees

	float4 t0_a = float4(scale*float2(+v_a.x, +v_a.y)*(1.000), texcoord.zw); t0_a.xyz += float3(texcoord.xy, dot(ddist_duv,t0_a.xy));
	float4 t1_a = float4(scale*float2(-v_a.y, +v_a.x)*(0.666), texcoord.zw); t1_a.xyz += float3(texcoord.xy, dot(ddist_duv,t1_a.xy));
	float4 t2_a = float4(scale*float2(-v_a.x, -v_a.y)*(0.333), texcoord.zw); t2_a.xyz += float3(texcoord.xy, dot(ddist_duv,t2_a.xy));

	float4 t0_b = float4(scale*float2(+v_b.x, +v_b.y)*(1.000), texcoord.zw); t0_b.xyz += float3(texcoord.xy, dot(ddist_duv,t0_b.xy));
	float4 t1_b = float4(scale*float2(-v_b.y, +v_b.x)*(0.666), texcoord.zw); t1_b.xyz += float3(texcoord.xy, dot(ddist_duv,t1_b.xy));
	float4 t2_b = float4(scale*float2(-v_b.x, -v_b.y)*(0.333), texcoord.zw); t2_b.xyz += float3(texcoord.xy, dot(ddist_duv,t2_b.xy));

	float4 t0_c = float4(scale*float2(+v_c.x, +v_c.y)*(1.000), texcoord.zw); t0_c.xyz += float3(texcoord.xy, dot(ddist_duv,t0_c.xy));
	float4 t1_c = float4(scale*float2(-v_c.y, +v_c.x)*(0.666), texcoord.zw); t1_c.xyz += float3(texcoord.xy, dot(ddist_duv,t1_c.xy));
	float4 t2_c = float4(scale*float2(-v_c.x, -v_c.y)*(0.333), texcoord.zw); t2_c.xyz += float3(texcoord.xy, dot(ddist_duv,t2_c.xy));

	float4 t0_d = float4(scale*float2(+v_d.x, +v_d.y)*(1.000), texcoord.zw); t0_d.xyz += float3(texcoord.xy, dot(ddist_duv,t0_d.xy));
	float4 t1_d = float4(scale*float2(-v_d.y, +v_d.x)*(0.666), texcoord.zw); t1_d.xyz += float3(texcoord.xy, dot(ddist_duv,t1_d.xy));
	float4 t2_d = float4(scale*float2(-v_d.x, -v_d.y)*(0.333), texcoord.zw); t2_d.xyz += float3(texcoord.xy, dot(ddist_duv,t2_d.xy));

	const float3 temp_a = __tex2DDepth3(samp, t0_a, t1_a, t2_a);
	const float3 temp_b = __tex2DDepth3(samp, t0_b, t1_b, t2_b);
	const float3 temp_c = __tex2DDepth3(samp, t0_c, t1_c, t2_c);
	const float3 temp_d = __tex2DDepth3(samp, t0_d, t1_d, t2_d);
	
	return dot(temp_a + temp_b + temp_c + temp_d, 1)/12;
}


#define DEF_Sample_CSM_ST_DITHER_filter(filter) \
	float Sample_CSM_ST_DITHER1##filter(ShadowSampleParams sampleParams) \
	{ \
		DECLARE_SHADOWSAMPLEPARAMS \
		sampleParams.v     = 0; \
		sampleParams.scale = 0; \
		const float2 v_a = v; \
		\
		const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0); \
		sampleParams.texcoord = t0_a; \
		return Sample_CSM_ST_##filter(sampleParams); \
	} \
	\
	float Sample_CSM_ST_DITHER2##filter(ShadowSampleParams sampleParams) \
	{ \
		DECLARE_SHADOWSAMPLEPARAMS \
		sampleParams.v     = 0; \
		sampleParams.scale = 0; \
		const float2 v_a = v; \
		\
		const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0); \
		const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0); \
		\
		float2 temp_a; \
		\
		sampleParams.texcoord = t0_a; \
		temp_a.x = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t1_a; \
		temp_a.y = Sample_CSM_ST_##filter(sampleParams); \
		\
		return dot(temp_a, 1)/2; \
	} \
	\
	float Sample_CSM_ST_DITHER3##filter(ShadowSampleParams sampleParams) \
	{ \
		DECLARE_SHADOWSAMPLEPARAMS \
		sampleParams.v     = 0; \
		sampleParams.scale = 0; \
		const float2 v_a = v; \
		\
		const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0); \
		const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0); \
		const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0); \
		\
		float3 temp_a; \
		\
		sampleParams.texcoord = t0_a; \
		temp_a.x = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t1_a; \
		temp_a.y = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t2_a; \
		temp_a.z = Sample_CSM_ST_##filter(sampleParams); \
		\
		return dot(temp_a, 1)/3; \
	} \
	\
	float Sample_CSM_ST_DITHER4##filter(ShadowSampleParams sampleParams) \
	{ \
		DECLARE_SHADOWSAMPLEPARAMS \
		sampleParams.v     = 0; \
		sampleParams.scale = 0; \
		const float2 v_a = v; \
		\
		const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0); \
		const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0); \
		const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0); \
		const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0); \
		\
		float4 temp_a; \
		\
		sampleParams.texcoord = t0_a; \
		temp_a.x = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t1_a; \
		temp_a.y = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t2_a; \
		temp_a.z = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t3_a; \
		temp_a.w = Sample_CSM_ST_##filter(sampleParams); \
		\
		return dot(temp_a, 1)/4; \
	} \
	\
	float Sample_CSM_ST_DITHER6##filter(ShadowSampleParams sampleParams) \
	{ \
		DECLARE_SHADOWSAMPLEPARAMS \
		sampleParams.v     = 0; \
		sampleParams.scale = 0; \
		const float2 v_a = v; \
		const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; \
		\
		const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0); \
		const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0); \
		const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0); \
		const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0); \
		\
		const float4 t0_b = texcoord + float4(scale*float2(+v_b.x, +v_b.y)*(1.00), 0,0); \
		const float4 t1_b = texcoord + float4(scale*float2(-v_b.y, +v_b.x)*(0.50), 0,0); \
		\
		float4 temp_a; \
		float2 temp_b; \
		\
		sampleParams.texcoord = t0_a; \
		temp_a.x = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t1_a; \
		temp_a.y = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t2_a; \
		temp_a.z = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t3_a; \
		temp_a.w = Sample_CSM_ST_##filter(sampleParams); \
		\
		sampleParams.texcoord = t0_b; \
		temp_b.x = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t1_b; \
		temp_b.y = Sample_CSM_ST_##filter(sampleParams); \
		\
		return dot(temp_a + float4(temp_b, 0, 0), 1)/6; \
	} \
	\
	float Sample_CSM_ST_DITHER8##filter(ShadowSampleParams sampleParams) \
	{ \
		DECLARE_SHADOWSAMPLEPARAMS \
		sampleParams.v     = 0; \
		sampleParams.scale = 0; \
		const float2 v_a = v; \
		const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; \
		\
		const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0); \
		const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0); \
		const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0); \
		const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0); \
		\
		const float4 t0_b = texcoord + float4(scale*float2(+v_b.x, +v_b.y)*(1.00), 0,0); \
		const float4 t1_b = texcoord + float4(scale*float2(-v_b.y, +v_b.x)*(0.50), 0,0); \
		const float4 t2_b = texcoord + float4(scale*float2(-v_b.x, -v_b.y)*(0.75), 0,0); \
		const float4 t3_b = texcoord + float4(scale*float2(+v_b.y, -v_b.x)*(0.25), 0,0); \
		\
		float4 temp_a; \
		float4 temp_b; \
		\
		sampleParams.texcoord = t0_a; \
		temp_a.x = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t1_a; \
		temp_a.y = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t2_a; \
		temp_a.z = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t3_a; \
		temp_a.w = Sample_CSM_ST_##filter(sampleParams); \
		\
		sampleParams.texcoord = t0_b; \
		temp_b.x = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t1_b; \
		temp_b.y = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t2_b; \
		temp_b.z = Sample_CSM_ST_##filter(sampleParams); \
		sampleParams.texcoord = t3_b; \
		temp_b.w = Sample_CSM_ST_##filter(sampleParams); \
		\
		return dot(temp_a + temp_b, 1)/8; \
	}

DEF_Sample_CSM_ST_DITHER_filter(BOX3x3)
DEF_Sample_CSM_ST_DITHER_filter(CUBIC)

#undef DEF_Sample_CSM_ST_DITHER_filter

float Sample_CSM_ST_DITHER4P(SHADOWSAMPLER samp, float4 texcoord, float4 res, float2 v, float2 scale)
{
	const float2 v_a = v;

	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);
	const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0);
	const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0);
	const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0);

	const float4 temp_a = __tex2DDepth4(samp, t0_a, t1_a, t2_a, t3_a);

	const float any_notequal_0 = dot(    temp_a, 1);
	const float any_notequal_1 = dot(1 - temp_a, 1);

	return 1 - saturate(1000*any_notequal_0*any_notequal_1);
}

float Sample_CSM_ST_DITHER8P(SHADOWSAMPLER samp, float4 texcoord, float4 res, float2 v, float2 scale)
{
	const float2 v_a = v;
	const float2 v_b = SampleDitherRotate(v_a, 2)*0.888; // rotate by 90 degrees

	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);
	const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0);
	const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0);
	const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0);

	const float4 t0_b = texcoord + float4(scale*float2(+v_b.x, +v_b.y)*(1.00), 0,0);
	const float4 t1_b = texcoord + float4(scale*float2(-v_b.y, +v_b.x)*(0.50), 0,0);
	const float4 t2_b = texcoord + float4(scale*float2(-v_b.x, -v_b.y)*(0.75), 0,0);
	const float4 t3_b = texcoord + float4(scale*float2(+v_b.y, -v_b.x)*(0.25), 0,0);

	const float4 temp_a = __tex2DDepth4(samp, t0_a, t1_a, t2_a, t3_a);
	const float4 temp_b = __tex2DDepth4(samp, t0_b, t1_b, t2_b, t3_b);

	const float any_notequal_0 = dot(    temp_a, 1) + dot(    temp_b, 1);
	const float any_notequal_1 = dot(1 - temp_a, 1) + dot(1 - temp_b, 1);

	return 1 - saturate(1000*any_notequal_0*any_notequal_1);
}

float Sample_CSM_ST_SOFT16(ShadowSampleParams sampleParams)
{
	DECLARE_SHADOWSAMPLEPARAMS

	scale *= 4;

#if __WIN32
	const float2 v_a = v;
	const float4 t0_a = texcoord + float4(scale*float2(+v_a.x, +v_a.y)*(1.00), 0,0);
	const float4 t1_a = texcoord + float4(scale*float2(-v_a.y, +v_a.x)*(0.50), 0,0);
	const float4 t2_a = texcoord + float4(scale*float2(-v_a.x, -v_a.y)*(0.75), 0,0);
	const float4 t3_a = texcoord + float4(scale*float2(+v_a.y, -v_a.x)*(0.25), 0,0);

	//TODO: change to loads
	float4 depths;
	depths.x=tex2D(samp, t0_a.xy).x;
	depths.y=tex2D(samp, t1_a.xy).x;
	depths.z=tex2D(samp, t2_a.xy).x;
	depths.w=tex2D(samp, t3_a.xy).x;
#if __XENON
	depths=1-depths.xyzw;
#endif // __XENON
	float myDepth=texcoord.z;
	float4 weights=myDepth>depths.xyzw;
	float nw=dot(weights,1.0.xxxx);
	float avgD=dot(depths,weights)/nw;

	float LP=500.0;
	float Wpen=(myDepth-avgD)*LP;///avgD;  avgD removed due to directional light

	//if (Wpen>1)
	//	return 1;

	Wpen = (nw == 0) ? 1 : Wpen;

	scale*=saturate(max(Wpen,0.2));
#endif // __WIN32

	sampleParams.scale = scale;
	return Sample_CSM_ST_DITHER16(sampleParams);
}


float Sample_CSM_ST_SOFT16_RPDB(ShadowSampleParams sampleParams, uniform bool useRPDB)
{
	sampleParams.scale *= 4;
	return Sample_CSM_ST_DITHER16_RPDB(sampleParams);
}


#define Sample_CSM_ST_HIGHRES_BOX4x4 Sample_CSM_ST_BOX4x4

#if CASCADE_SHADOWS_CLOUD_SHADOWS
#if CSM_ST_DEFAULT == CSM_ST_POINT
	#define Sample_CSM_ST_CLOUDS_SIMPLE Sample_CSM_ST_POINT
#elif CSM_ST_DEFAULT == CSM_ST_LINEAR
	#define Sample_CSM_ST_CLOUDS_SIMPLE Sample_CSM_ST_LINEAR
#elif CSM_ST_DEFAULT == CSM_ST_TWOTAP
	#define Sample_CSM_ST_CLOUDS_SIMPLE Sample_CSM_ST_TWOTAP
#elif CSM_ST_DEFAULT == CSM_ST_BOX3x3
	#define Sample_CSM_ST_CLOUDS_SIMPLE Sample_CSM_ST_BOX3x3
#elif CSM_ST_DEFAULT == CSM_ST_BOX4x4
	#define Sample_CSM_ST_CLOUDS_SIMPLE Sample_CSM_ST_BOX4x4
#elif CSM_ST_DEFAULT == CSM_ST_DITHER2_LINEAR
	#define Sample_CSM_ST_CLOUDS_SIMPLE Sample_CSM_ST_DITHER2_LINEAR
#elif CSM_ST_DEFAULT == CSM_ST_SOFT16
	#define Sample_CSM_ST_CLOUDS_SIMPLE	Sample_CSM_ST_SOFT16
#elif CSM_ST_DEFAULT == CSM_ST_DITHER16_RPDB
	#define Sample_CSM_ST_CLOUDS_SIMPLE	Sample_CSM_ST_DITHER16_RPDB
#elif CSM_ST_DEFAULT == CSM_ST_POISSON16_RPDB_GNORM
	#define Sample_CSM_ST_CLOUDS_SIMPLE Sample_CSM_ST_POISSON16_RPDB_GNORM
#else
	.. need to handle default sample type here
#endif
#define Sample_CSM_ST_CLOUDS_POINT			     Sample_CSM_ST_POINT
#define Sample_CSM_ST_CLOUDS_LINEAR			     Sample_CSM_ST_LINEAR
#define Sample_CSM_ST_CLOUDS_TWOTAP			     Sample_CSM_ST_TWOTAP
#define Sample_CSM_ST_CLOUDS_BOX3x3			     Sample_CSM_ST_BOX3x3
#define Sample_CSM_ST_CLOUDS_BOX4x4			     Sample_CSM_ST_BOX4x4
#define Sample_CSM_ST_CLOUDS_DITHER2_LINEAR	     Sample_CSM_ST_DITHER2_LINEAR
#define Sample_CSM_ST_CLOUDS_SOFT16			     Sample_CSM_ST_SOFT16
#define Sample_CSM_ST_CLOUDS_DITHER16_RPDB	     Sample_CSM_ST_DITHER16_RPDB
#define Sample_CSM_ST_CLOUDS_POISSON16_RPDB_GNORM Sample_CSM_ST_POISSON16_RPDB_GNORM
#endif // CASCADE_SHADOWS_CLOUD_SHADOWS

#endif //DEFERRED_LOCAL_SHADOW_SAMPLING

#endif // _CASCADESHADOWS_SAMPLING_FXH_
