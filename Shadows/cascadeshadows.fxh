// ======================
// cascadeshadows.fxh
// (c) 2011 RockstarNorth
// ======================

#ifndef _CASCADESHADOWS_FXH_
#define _CASCADESHADOWS_FXH_

#include "cascadeshadows_common.fxh"

#if PED_CLOTH && (RSG_PC || RSG_ORBIS || RSG_DURANGO)
void ClothTransform(int idx0, int idx1, int idx2, float4 weight, out float3 pos, out float3 normal);
#endif // PED_CLOTH && (RSG_PC || RSG_ORBIS || RSG_DURANGO)

#if (SHADOW_RECEIVING || SHADOW_RECEIVING_VS) && !DEFERRED_LOCAL_SHADOW_SAMPLING

#include "cascadeshadows_receiving.fxh"

#if SHADOW_RECEIVING

float CalcCascadeShadows(float3 eyePos, float3 worldPos, float3 worldNormal, float2 screenPos)
{
#if defined(DEFERRED_UNPACK_LIGHT)
	return 1; // assume shadow is in GBuffer self-shadow
#elif DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS
	return tex2D(gCSMAuxRenderTargetSamp, screenPos).x;
#else
	const float linearDepth = dot(eyePos - worldPos, gViewInverse[2].xyz);
	const float shadow = CalcCascadeShadows_internal(CascadeShadowsParams_setup(CSM_ST_DEFAULT), linearDepth, eyePos, worldPos, worldNormal, screenPos,
		true, // applyOpacity
		true, // useFourCascades
		true, // useSimpleNormalOffset
		true, // useIrregularFade
		true  // combineParticleShadow
	);

	return lerp(shadow, 0, CalcFogShadowDensity(worldPos)); // forward rendered shaders need fog shadows too
#endif
}

float CalcCascadeShadowsSSS(float3 eyePos, float3 worldPos, float3 worldNormal, float2 screenPos)
							// surfaceProperties surface)
{
	float2 ditherRadius = 0, lastPos = 0;
	int cascadeIndex = 0;
	const float3 shrinkedPos = worldPos;
	const CascadeShadowsParams params = CascadeShadowsParams_setup(CSM_ST_LINEAR);
	
	const float edgeDither = 0.0f;
	const float linearDepth = 1.0f;		

	const float4 texCoords = float4(ComputeCascadeShadowsTexCoord(params, shrinkedPos, 0, true, false, 
		                                                          ditherRadius, lastPos, cascadeIndex, 
																  edgeDither, linearDepth));	

	//const float4 depth = __tex2DPCF(SHADOWSAMPLER_TEXSAMP, texCoords);
	const float4 depth = SampleShadowDepth4(texCoords.xyw);
	return (texCoords.z - dot(0.25,depth));
}

float CalcCascadeShadowsHighQuality(float3 eyePos, float3 worldPos, float3 worldNormal, float2 screenPos)
{
	const float linearDepth = dot(eyePos - worldPos, gViewInverse[2].xyz);
	const float shadow = CalcCascadeShadows_internal(CascadeShadowsParams_setup(CSM_ST_BOX4x4), linearDepth, eyePos, worldPos, worldNormal, screenPos,
		true, // applyOpacity
		true, // useFourCascades
		true, // useSimpleNormalOffset
		true, // useIrregularFade
		true  // combineParticleShadow
	);

	return lerp(shadow, 0, CalcFogShadowDensity(worldPos)); // forward rendered shaders need fog shadows too
}

float CalcCascadeShadowsFast(float3 eyePos, float3 worldPos, float3 worldNormal, float2 screenPos)
{
	const float linearDepth = dot(eyePos - worldPos, gViewInverse[2].xyz);
	float shadow = CalcCascadeShadows_internal(CascadeShadowsParams_setup(CSM_ST_LINEAR), linearDepth, eyePos, worldPos, worldNormal, screenPos,
		true,  // applyOpacity
		true,  // useFourCascades
		false, // useSimpleNormalOffset
		true,  // useIrregularFade
		true   // combineParticleShadow
	);

	// TODO -- we might be able to get away with precalculating the fog shadows for the current water height
	return lerp(shadow, 0, CalcFogShadowDensity(worldPos)); // forward rendered shaders need fog shadows too
}

float CalcCascadeShadowsFastNoFade(float3 eyePos, float3 worldPos, float3 worldNormal, float2 screenPos)
{
	const float linearDepth = dot(eyePos - worldPos, gViewInverse[2].xyz);
	return CalcCascadeShadows_internal(CascadeShadowsParams_setup(CSM_ST_LINEAR), linearDepth, eyePos, worldPos, worldNormal, screenPos,
		false, // applyOpacity
		true,  // useFourCascades
		false, // useSimpleNormalOffset
		false, // useIrregularFade
		true   // combineParticleShadow
	);
}

float CalcCascadeShadowSample(SHADOWSAMPLER samp, bool bGlobal, float3 worldPos, int cascadeIndex)
{
	float4 tex = float4(CalcCascadeShadowCoord_internal(CascadeShadowsParams_setup(-1), worldPos, cascadeIndex),0);

	if (bGlobal)
	{
		tex.y = (tex.y + (float)cascadeIndex)/(float)CASCADE_SHADOWS_COUNT;
	}

	return __tex2DPCF(samp, tex);
}

half CalcCascadeShadowAccumAll(SHADOWSAMPLER samp, bool bGlobal, float3 worldP, float3 worldD, int numSamples)
{
	const CascadeShadowsParams params = CascadeShadowsParams_setup(-1);

	half accum = 0;
	float filterSizeTexels = CASCADE_SHADOW_TEXARRAY ? 0 : ((params.sampleType == CSM_ST_BOX4x4  || params.sampleType == CSM_ST_DITHER2_LINEAR) ? 3 : 1.5);
	const float range = (1.0 - filterSizeTexels * (float)CASCADE_SHADOWS_RES_INV_X)*0.5; // have to allow for filtering

	float4 texP = float4(mul(worldP - gViewInverse[3].xyz, params.worldToShadow33),0);
	float4 texD = float4(mul(worldD, params.worldToShadow33),0);

	float4 posP0 = texP*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 0] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 0]; // transform into texture space
	float4 posP1 = texP*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 1] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 1];
	float4 posP2 = texP*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 2] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 2];
	float4 posP3 = texP*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 3] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 3];

	float4 posD0 = texD*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 0];
	float4 posD1 = texD*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 1];
	float4 posD2 = texD*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 2];
	float4 posD3 = texD*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 3];

	[unroll] for (int i = 0; i < numSamples; i++)
	{
		float4 pos;

		pos =
			max(abs(posP0.x), abs(posP0.y)) < range ? float4(posP0.xyz, (0.0 + 0.5)/CASCADE_SHADOWS_COUNT) :
			max(abs(posP1.x), abs(posP1.y)) < range ? float4(posP1.xyz, (1.0 + 0.5)/CASCADE_SHADOWS_COUNT) :
			max(abs(posP2.x), abs(posP2.y)) < range ? float4(posP2.xyz, (2.0 + 0.5)/CASCADE_SHADOWS_COUNT) :
			max(abs(posP3.x), abs(posP3.y)) < range ? float4(posP3.xyz, (3.0 + 0.5)/CASCADE_SHADOWS_COUNT) :
													float4(0,0,0,CASCADE_SHADOWS_COUNT+1) ;

		float r = 1.0f;
		if (pos.w != CASCADE_SHADOWS_COUNT+1)
		{
			float num = 0.0f;
#if CASCADE_SHADOW_TEXARRAY
			num = pos.w * CASCADE_SHADOWS_COUNT - 0.5f;
#endif
			float4 texcoord = float4(pos.xyz, num);
			texcoord.x += 0.5f;
			texcoord.y *= (params.sampleType == CSM_ST_HIGHRES_BOX4x4) ? 1 : 1.0/CASCADE_SHADOWS_COUNT;
			texcoord.y += pos.w;
#if CASCADE_SHADOW_TEXARRAY
			texcoord.y = (texcoord.y - (1.0/CASCADE_SHADOWS_COUNT * num)) * CASCADE_SHADOWS_COUNT;
#endif
			r = __tex2DPCF(samp, texcoord);
		}

		accum += r;//__tex2DPCF(samp, texcoord);

		posP0 += posD0;
		posP1 += posD1;
		posP2 += posD2;
		posP3 += posD3;
	}

	return accum/(half)numSamples;
}

// This function accumulates shadow values over the first three cascades ... used for fogray
half CalcCascadeShadowAccumAll3(SHADOWSAMPLER samp, bool bGlobal, float3 worldP, float3 worldD, int numSamples)
{
	const float cascade_count = 3.0f;
	const float cascade_shadow_res_inv_x = 1.0f / 512.0f;

	const CascadeShadowsParams params = CascadeShadowsParams_setup(-1);

	half accum = 0;
	float filterSizeTexels = ((params.sampleType == CSM_ST_BOX4x4  || params.sampleType == CSM_ST_DITHER2_LINEAR) ? 3 : 1.5);
	const float range = (1.0 - filterSizeTexels * (float)(cascade_shadow_res_inv_x))*0.5; // have to allow for filtering

	float4 texP = float4(mul(worldP - gViewInverse[3].xyz, params.worldToShadow33),0);
	float4 texD = float4(mul(worldD, params.worldToShadow33),0);

	float4 posP0 = texP*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 0] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 0]; // transform into texture space
	float4 posP1 = texP*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 1] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 1];
	float4 posP2 = texP*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 2] + gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + 2];

	float4 posD0 = texD*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 0];
	float4 posD1 = texD*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 1];
	float4 posD2 = texD*gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + 2];

	[unroll] for (int i = 0; i < numSamples; i++)
	{
		float4 pos;

		pos =
			max(abs(posP0.x), abs(posP0.y)) < range ? float4(posP0.xyz, (0.0 + 0.5)/cascade_count) :
			max(abs(posP1.x), abs(posP1.y)) < range ? float4(posP1.xyz, (1.0 + 0.5)/cascade_count) :
			max(abs(posP2.x), abs(posP2.y)) < range ? float4(posP2.xyz, (2.0 + 0.5)/cascade_count) :
													float4(0,0,0,CASCADE_SHADOWS_COUNT+1) ;

		float r = 1.0f;
		if (pos.w != CASCADE_SHADOWS_COUNT+1)
		{
			float num = 0.0f;

			float4 texcoord = float4(pos.xyz, num);
			texcoord.x += 0.5f;
			texcoord.y *= (params.sampleType == CSM_ST_HIGHRES_BOX4x4) ? 1 : 1.0/cascade_count;
			texcoord.y += pos.w;

			r = __tex2DPCF(samp, texcoord);
		}

		accum += r;

		posP0 += posD0;
		posP1 += posD1;
		posP2 += posD2;
	}

	return accum/(half)numSamples;
}

half CalcCascadeShadowAccum(SHADOWSAMPLER samp, bool bGlobal, float3 worldP, float3 worldD, int numSamples, int cascadeIndex)
{
	const float3 a = gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + cascadeIndex].xyz;
	const float3 b = gCSMShaderVars_shared[_cascadeBoundsConstB_packed_start + cascadeIndex].xyz;

	const CascadeShadowsParams params = CascadeShadowsParams_setup(-1);

	float4 texP = float4(mul(worldP - gViewInverse[3].xyz, params.worldToShadow33)*a + b + float3(0.5, 0.5, 0),0);
	float4 texD = float4(mul(worldD, params.worldToShadow33)*a,0);

	if (bGlobal)
	{
		texP.y = (texP.y + (float)cascadeIndex)/(float)CASCADE_SHADOWS_COUNT;
		texD.y = (texD.y                      )/(float)CASCADE_SHADOWS_COUNT;
	}

	half accum = 0;

	for (int i = 0; i < numSamples; i++)
	{
		accum += __tex2DPCF(samp, texP);
		texP += texD;	
	}

	return accum/(half)numSamples;
}

#endif // SHADOW_RECEIVING

// ================================================================================================

#if SHADOW_RECEIVING_VS

float CalcCascadeShadowSampleVS(float3 worldPos, bool bFilter, bool bStep)
{
	const float3 tex = CalcCascadeShadowCoord_internal(CascadeShadowsParams_setup(-1), worldPos, CASCADE_SHADOWS_VS_CASCADE_INDEX);
	float result;

	if (bFilter)
	{
		float4 temp;
		temp.x = tex2Dlod(gCSMShadowTextureVSSamp, float4(tex.xy + float2(-0.5/CASCADE_SHADOWS_RES_VS_X, -0.5/CASCADE_SHADOWS_RES_VS_Y), 0, 0)).x;
		temp.y = tex2Dlod(gCSMShadowTextureVSSamp, float4(tex.xy + float2(+0.5/CASCADE_SHADOWS_RES_VS_X, -0.5/CASCADE_SHADOWS_RES_VS_Y), 0, 0)).x;
		temp.z = tex2Dlod(gCSMShadowTextureVSSamp, float4(tex.xy + float2(-0.5/CASCADE_SHADOWS_RES_VS_X, +0.5/CASCADE_SHADOWS_RES_VS_Y), 0, 0)).x;
		temp.w = tex2Dlod(gCSMShadowTextureVSSamp, float4(tex.xy + float2(+0.5/CASCADE_SHADOWS_RES_VS_X, +0.5/CASCADE_SHADOWS_RES_VS_Y), 0, 0)).x;

		if (bStep)
		{
			temp = step(tex.zzzz, XENON_ONLY(1-)temp);
		}

		const float2 f = frac(tex.xy*float2(CASCADE_SHADOWS_RES_VS_X, CASCADE_SHADOWS_RES_VS_Y) + 0.5);

		temp.xz = lerp(temp.xz, temp.yw, f.xx);
		result  = lerp(temp.x , temp.z , f.y );
	}
	else
	{
		float temp = tex2Dlod(gCSMShadowTextureVSSamp, float4(tex.xy, 0, 0)).x;

		if (bStep)
		{
			temp = step(tex.z, XENON_ONLY(1-)temp);
		}

		result = temp;
	}

	if (bStep)
	{
		// TODO -- support fog shadows if necessary
	}
	else
	{
		const float cascadeRangeZ_VS = gCSMShaderVars_shared[2].w; // could also use 1.0/gCSMShaderVars_shared[_cascadeBoundsConstA_packed_start + CASCADE_SHADOWS_VS_CASCADE_INDEX].z;

		result = max(0, XENON_ONLY(1-)result - tex.z)*cascadeRangeZ_VS;
	}

	return result;
}

#endif // SHADOW_RECEIVING_VS

#endif // SHADOW_RECEIVING || SHADOW_RECEIVING_VS

// ================================================================================================

#if SHADOW_CASTING

#if (__XENON || RSG_PC || RSG_ORBIS || RSG_DURANGO) && !defined(NO_SKINNING)
#include "../../Util/skin.fxh"
#endif // (__XENON || RSG_PC || RSG_ORBIS || RSG_DURANGO) && !defined(NO_SKINNING)

struct VS_CascadeShadows_IN
{
	float3 pos : POSITION;
#if USE_PN_TRIANGLES
	float3 normal : NORMAL;
#endif // USE_PN_TRIANGLES
#ifdef SHADOW_USE_TEXTURE
	float2 tex : TEXCOORD0;
#endif // SHADOW_USE_TEXTURE

#ifdef USE_VEHICLE_DAMAGE
	float4 diffuse : COLOR0;
#endif

#if PED_CPV_WIND 
	float4 cpvWind		: COLOR1;
#endif
};

DeclareInstancedStuct(VS_InstancedCascadeShadows_IN, VS_CascadeShadows_IN);

//Instancing support
#if INSTANCED && !defined(NUM_CONSTS_PER_INSTANCE)
	#error ERROR! Instanced shaders must define NUM_CONSTS_PER_INSTANCE!
#endif

struct CsmVertInstanceData
{
	float4x4 worldMtx;
};

void FetchInstanceVertexData(VS_InstancedCascadeShadows_IN instIN, out VS_CascadeShadows_IN vertData, out int nInstIndex)
{
#if INSTANCED && __XENON
	int nIndex = instIN.nIndex;
	int nNumIndicesPerInstance = gInstancingParams.x;				//# of verts [indexed] in a single instance
	nInstIndex = ( nIndex + 0.5 ) / nNumIndicesPerInstance;			//index of the current instanced model								[0, <Num Models Instanced>]
	int nMeshIndex = nIndex - nInstIndex * nNumIndicesPerInstance;	//offset/index of the current vert in the current instanced model.	[0, <Max Num Verts Per Instance>]

	//Do custom vfetch of vertex components
	float3 inPos;
#if USE_PN_TRIANGLES
	float3 inNrm;
#endif
#ifdef SHADOW_USE_TEXTURE
	float2 inTex;
#endif
	asm
	{
		vfetch inPos.xyz,	nMeshIndex, position0;
#if USE_PN_TRIANGLES
		vfetch inNrm.xyz,	nMeshIndex, normal0;
#endif
#ifdef SHADOW_USE_TEXTURE
		vfetch inTex.xy,		nMeshIndex, texcoord0;
#endif
	};

	vertData.pos.xyz = inPos;
#if USE_PN_TRIANGLES
	vertData.normal.xyz = inNrm;
#endif
#ifdef SHADOW_USE_TEXTURE
	vertData.tex = inTex;
#endif
#else //INSTANCED && __XENON
	vertData = instIN.baseVertIn;
#if INSTANCED && (__SHADERMODEL >= 40)
	nInstIndex = instIN.nInstIndex;
#else
	nInstIndex = 0;
#endif
#endif //INSTANCED && __XENON
}

void GetInstanceData(int nInstIndex, out CsmVertInstanceData inst)
{
#if INSTANCED
	int nInstRegBase = nInstIndex * NUM_CONSTS_PER_INSTANCE;
	float3x4 worldMat;
	// TODO: a vertex buffer may be more efficient
	worldMat[0] = gInstanceVars[nInstRegBase];
	worldMat[1] = gInstanceVars[nInstRegBase+1];
	worldMat[2] = gInstanceVars[nInstRegBase+2];
	inst.worldMtx[0] = float4(worldMat[0].xyz, 0);
	inst.worldMtx[1] = float4(worldMat[1].xyz, 0);
	inst.worldMtx[2] = float4(worldMat[2].xyz, 0);
	inst.worldMtx[3] = float4(worldMat[0].w, worldMat[1].w, worldMat[2].w, 1);
#else
	inst.worldMtx =					gWorld;
#endif
}

struct VS_CascadeShadows_IN_skinned
{
	float3 pos : POSITION;
#if USE_PN_TRIANGLES
	float3 normal : NORMAL;
#endif // USE_PN_TRIANGLES
#ifdef SHADOW_USE_TEXTURE
	float2 tex : TEXCOORD0;
#endif // SHADOW_USE_TEXTURE
	float4 blendweights : BLENDWEIGHT;
	index4 blendindices : BLENDINDICES;

#ifdef USE_VEHICLE_DAMAGE
	float4 diffuse : COLOR0;
#endif

#if PED_CPV_WIND 
	float4 cpvWind		: COLOR1;
#endif
};


#if GS_INSTANCED_SHADOWS
struct VS_CascadeShadows_OUT_instanced
{
	float4 pos : PASSPOS;
#ifdef SHADOW_USE_TEXTURE
	float2 tex : TEXCOORD0;
#endif // SHADOW_USE_TEXTURE
	uint InstID : TEXCOORD1;
};
#endif	//GS_INSTANCED_SHADOWS

struct VS_CascadeShadows_OUT
{
	DECLARE_POSITION(pos)
#ifdef SHADOW_USE_TEXTURE
	float2 tex : TEXCOORD0;
#endif // SHADOW_USE_TEXTURE
};

// ================================================================================================
// Model space vertex functions.								
// ================================================================================================

float3 ComputeModelSpaceVertex(VS_CascadeShadows_IN IN)
{
	float3 inPos    = IN.pos;
#ifdef USE_VEHICLE_DAMAGE
	float3 inNrm    = float3(0,0,1);
	float3 inDmgPos = inPos;
	float3 inDmgNrm = inNrm;
	float4 inCpv = IN.diffuse;
	ApplyVehicleDamage(inDmgPos, inDmgNrm, inCpv.g, inPos, inNrm);
#endif // USE_VEHICLE_DAMAGE

#ifdef VEHICLE_TYRE_DEFORM
	float3 inputPos		= inPos;
	float3 fakeWorldPos	= float4(0,0,0,0);
	float4 fakeColor	= float4(0,0,0,0);
	ApplyTyreDeform(inputPos, fakeWorldPos, fakeColor, inPos, fakeColor, false);
#endif //VEHICLE_TYRE_DEFORM...

#if PED_CPV_WIND
	inPos.xyz = VS_PedApplyMicromovements(inPos.xyz, IN.cpvWind.rgb);
#endif

#ifdef USE_VEHICLE_INSTANCED_WHEEL_SHADER
	inPos = mul(float4(inPos, 1), matWheelWorld).xyz;	
#endif // USE_VEHICLE_INSTANCED_WHEEL_SHADER

	return inPos;
}

#ifndef NO_SKINNING

float3 ComputeModelSpaceVertexSkinned(VS_CascadeShadows_IN_skinned IN, out float3 normal)
{
	float3 inPos    = IN.pos;
#ifdef USE_VEHICLE_DAMAGE
	float3 inNrm    = float3(0,0,1);
	float3 inDmgPos = inPos;
	float3 inDmgNrm = inNrm;
	float4 inCpv = IN.diffuse;
	ApplyVehicleDamage(inDmgPos, inDmgNrm, inCpv.g, inPos, inNrm);
#endif // USE_VEHICLE_DAMAGE

#if PED_CLOTH && (__XENON || /*RSG_ORBIS ||*/ (RSG_PC && __SHADERMODEL >= 40) || RSG_DURANGO)
	const int4 indices = D3DCOLORtoUBYTE4(IN.blendindices);

	if (rageSkinGetBone0(indices) > 254)
	{
		const int idx0 = rageSkinGetBone1(indices);
		const int idx1 = rageSkinGetBone2(indices);
		const int idx2 = rageSkinGetBone3(indices);
		ClothTransform(idx0, idx1, idx2, IN.blendweights, inPos, normal);
	}
	else
#endif // PED_CLOTH && (__XENON || RSG_ORBIS || (RSG_PC && __SHADERMODEL >= 40) || RSG_DURANGO)
	{
		rageSkinMtx skinMtx = ComputeSkinMtx(IN.blendindices, IN.blendweights);
		inPos = rageSkinTransform(inPos, skinMtx);
	#if USE_PN_TRIANGLES
		normal = rageSkinRotate(IN.normal, skinMtx);
	#else
		normal = float3(0.0f, 0.0f, 0.0f);
	#endif
	}
#if PED_CPV_WIND
	inPos.xyz = VS_PedApplyMicromovements(inPos.xyz, IN.cpvWind.rgb);
#endif
	return inPos;
}

#endif // NO_SKINNING

// ================================================================================================
// Non-skinned vertex functions.
// ================================================================================================

#if GS_INSTANCED_SHADOWS
struct GS_CascadeShadows_OUT
{
	DECLARE_POSITION(pos)
#ifdef SHADOW_USE_TEXTURE
	float2 tex : TEXCOORD0;
#endif // SHADOW_USE_TEXTURE
	//float temp : TEXCOORD1;

#if CASCADE_SHADOW_TEXARRAY
	uint rt_index : SV_RenderTargetArrayIndex;
#else
	uint viewport : SV_ViewportArrayIndex;
#endif
};

[maxvertexcount(3)]
void GS_ShadowInstPassThrough(triangle VS_CascadeShadows_OUT_instanced input[3], inout TriangleStream<GS_CascadeShadows_OUT> OutputStream)
{
	GS_CascadeShadows_OUT output;

	for(int i = 0; i < 3; i++)
	{
		output.pos = input[i].pos;
#ifdef SHADOW_USE_TEXTURE
		output.tex = input[i].tex.xy;
#endif
		//output.temp = input[i].InstID.x;

#if CASCADE_SHADOW_TEXARRAY
		output.rt_index = input[i].InstID.x;
#else
		output.viewport = input[i].InstID.x;
#endif
		OutputStream.Append(output);
	}
	OutputStream.RestartStrip();
}
#endif	//GS_INSTANCED_SHADOWS

// scale inPos by float3(.8,.8,1) to observe EDGE culling
VS_CascadeShadows_OUT VS_CascadeShadows_draw(VS_InstancedCascadeShadows_IN instIN)
{
	int nInstIndex;
	VS_CascadeShadows_IN IN;
	FetchInstanceVertexData(instIN, IN, nInstIndex);

	CsmVertInstanceData inst;
	GetInstanceData(nInstIndex, inst);

	VS_CascadeShadows_OUT OUT;

	float3 inPos = ComputeModelSpaceVertex(IN);

	OUT.pos = ApplyCompositeWorldTransform(float4(inPos,1), INSTANCING_ONLY_ARG(inst.worldMtx) gWorldViewProj);
#ifdef SHADOW_USE_TEXTURE
	OUT.tex.xy = IN.tex.xy;
#endif // SHADOW_USE_TEXTURE
	return OUT;
}

#if GS_INSTANCED_SHADOWS
VS_CascadeShadows_OUT_instanced VS_CascadeShadows_draw_instanced(VS_InstancedCascadeShadows_IN instIN
#if !INSTANCED
, uint instID : SV_InstanceID
#endif
)
{
	VS_CascadeShadows_IN IN;
	VS_CascadeShadows_OUT_instanced OUT;
#if INSTANCED
	int nInstIndex;
	FetchInstanceVertexData(instIN, IN, nInstIndex);

	CsmVertInstanceData inst;
	GetInstanceData(nInstIndex % INST_NUM, inst);

	float3 inPos = ComputeModelSpaceVertex(IN);

	OUT.pos = ApplyCompositeWorldTransform(float4(inPos,1), INSTANCING_ONLY_ARG(inst.worldMtx) gInstWorldViewProj[INSTOPT_INDEX(nInstIndex / INST_NUM)]);
	OUT.InstID = INSTOPT_INDEX(nInstIndex / INST_NUM);
#else
	IN = instIN.baseVertIn;
	float3 inPos = ComputeModelSpaceVertex(IN);
	
	OUT.pos = mul(float4(inPos, 1),mul(gInstWorld,gInstWorldViewProj[INSTOPT_INDEX(instID)]));
	OUT.InstID = INSTOPT_INDEX(instID);
#endif
#ifdef SHADOW_USE_TEXTURE
	OUT.tex.xy = IN.tex.xy;
#endif // SHADOW_USE_TEXTURE
	return OUT;
}
#endif	//GS_INSTANCED_SHADOWS

// ================================================================================================
// Skinned vertex functions.
// ================================================================================================

#if __XENON || RSG_PC || RSG_ORBIS || RSG_DURANGO // only these platforms do skinning on GPU for shadows
#ifdef NO_SKINNING

VS_CascadeShadows_OUT VS_CascadeShadows_drawskinned(VS_CascadeShadows_IN_skinned IN)
{
	VS_CascadeShadows_OUT OUT;

	OUT.pos = 0;
#ifdef SHADOW_USE_TEXTURE
	OUT.tex = 0;
#endif // SHADOW_USE_TEXTURE
	return OUT;
}

#else // not NO_SKINNING

VS_CascadeShadows_OUT VS_CascadeShadows_drawskinned(VS_CascadeShadows_IN_skinned IN)
{
	VS_CascadeShadows_OUT OUT;

	float3 normal;
	float3 inPos = ComputeModelSpaceVertexSkinned(IN, normal);
	OUT.pos = mul(float4(inPos, 1), gWorldViewProj);

#ifdef SHADOW_USE_TEXTURE
	OUT.tex.xy = IN.tex.xy;
#endif // SHADOW_USE_TEXTURE
	return OUT;
}

#if GS_INSTANCED_SHADOWS
VS_CascadeShadows_OUT_instanced VS_CascadeShadows_drawskinned_instanced(VS_CascadeShadows_IN_skinned IN, uint instID : SV_InstanceID)
{
	VS_CascadeShadows_OUT_instanced OUT;

	float3 normal;
	float3 inPos = ComputeModelSpaceVertexSkinned(IN, normal);
	OUT.pos = mul(float4(inPos, 1),mul(gInstWorld,gInstWorldViewProj[INSTOPT_INDEX(instID)]));
	OUT.InstID = INSTOPT_INDEX(instID);

#ifdef SHADOW_USE_TEXTURE
	OUT.tex.xy = IN.tex.xy;
#endif // SHADOW_USE_TEXTURE
	return OUT;
}
#endif	//GS_INSTANCED_SHADOWS
#endif // not NO_SKINNING
#endif // platforms

// ================================================================================================
// PN triangle functions.						
// ================================================================================================

#if USE_PN_TRIANGLES
#define SHADOW_TESSELLATION_MULTIPLIER		(1.0)

struct VS_CascadeShadows_IN_CtrlPoint
{
	float3 pos : CTRL_POSITION;
	float3 normal : CTRL_NORMAL;
#ifdef SHADOW_USE_TEXTURE
	float2 tex : CTRL_TEXCOORD0;
#endif // SHADOW_USE_TEXTURE
};

struct VS_CascadeShadows_IN_CtrlPoint_Instance
{
	float3 pos : CTRL_POSITION;
	float3 normal : CTRL_NORMAL;
#ifdef SHADOW_USE_TEXTURE
	float2 tex : CTRL_TEXCOORD0;
#endif // SHADOW_USE_TEXTURE
#if GS_INSTANCED_SHADOWS
	uint InstID : CTRL_INSTANCEID;
#endif // GS_INSTANCED_SHADOWS
};


// Vertex shader which outputs a control point.
VS_CascadeShadows_IN_CtrlPoint VS_CascadeShadows_draw_PNTri(VS_CascadeShadows_IN IN)
{
	// Output a control point. 
	VS_CascadeShadows_IN_CtrlPoint OUT;
	
	OUT.pos = ComputeModelSpaceVertex(IN);
	OUT.normal = IN.normal;
#ifdef SHADOW_USE_TEXTURE
	OUT.tex = IN.tex;
#endif // SHADOW_USE_TEXTURE
	return OUT;
}

#if GS_INSTANCED_SHADOWS
	VS_CascadeShadows_IN_CtrlPoint_Instance 
#else
	VS_CascadeShadows_IN_CtrlPoint 
#endif
	VS_CascadeShadows_draw_PNTri_instanced(VS_CascadeShadows_IN IN
#if GS_INSTANCED_SHADOWS																	  
																	  , uint instID : SV_InstanceID
#endif // GS_INSTANCED_SHADOWS																	  
																	  )
{
	// Output a control point. 
	VS_CascadeShadows_IN_CtrlPoint_Instance OUT;
	
	OUT.pos = ComputeModelSpaceVertex(IN);
	OUT.normal = IN.normal;
#ifdef SHADOW_USE_TEXTURE
	OUT.tex = IN.tex;
#endif // SHADOW_USE_TEXTURE
#if GS_INSTANCED_SHADOWS
	OUT.InstID = instID;
#endif
	return OUT;
}

// As above, but applies damage then skinning etc.
VS_CascadeShadows_IN_CtrlPoint VS_CascadeShadows_drawskinned_PNTri(VS_CascadeShadows_IN_skinned IN)
{
	VS_CascadeShadows_IN_CtrlPoint OUT;

	OUT.pos = ComputeModelSpaceVertexSkinned(IN, OUT.normal);
#ifdef SHADOW_USE_TEXTURE
	OUT.tex = IN.tex;
#endif // SHADOW_USE_TEXTURE
	return OUT;
}
#if GS_INSTANCED_SHADOWS
	VS_CascadeShadows_IN_CtrlPoint_Instance 
#else
	VS_CascadeShadows_IN_CtrlPoint 
#endif
	VS_CascadeShadows_drawskinned_PNTri_instanced(VS_CascadeShadows_IN_skinned IN
#if GS_INSTANCED_SHADOWS																			 
																			 , uint instID : SV_InstanceID
#endif // GS_INSTANCED_SHADOWS																			 
																			 )
{
	VS_CascadeShadows_IN_CtrlPoint_Instance OUT;

	OUT.pos = ComputeModelSpaceVertexSkinned(IN, OUT.normal);
#ifdef SHADOW_USE_TEXTURE
	OUT.tex = IN.tex;
#endif // SHADOW_USE_TEXTURE
#if GS_INSTANCED_SHADOWS
	OUT.InstID = instID;
#endif
	return OUT;
}

// Patch Constant Function.
rage_PNTri_PatchInfo PF_CascadeShadows_PNTri(InputPatch<VS_CascadeShadows_IN_CtrlPoint, 3> PatchPoints,  uint PatchID : SV_PrimitiveID)
{	
	rage_PNTri_PatchInfo Output;
	rage_PNTri_Vertex Points[3];

	Points[0].Position = PatchPoints[0].pos;
	Points[0].Normal = PatchPoints[0].normal;
	Points[1].Position = PatchPoints[1].pos;
	Points[1].Normal = PatchPoints[1].normal;
	Points[2].Position = PatchPoints[2].pos;
	Points[2].Normal = PatchPoints[2].normal;

	rage_ComputePNTrianglePatchInfo(Points[0], Points[1], Points[2], Output, SHADOW_TESSELLATION_MULTIPLIER);

	return Output;
}

rage_PNTri_PatchInfo PF_CascadeShadows_PNTri_instanced(InputPatch<VS_CascadeShadows_IN_CtrlPoint_Instance, 3> PatchPoints,  uint PatchID : SV_PrimitiveID)
{	
	rage_PNTri_PatchInfo Output;
	rage_PNTri_Vertex Points[3];

	Points[0].Position = PatchPoints[0].pos;
	Points[0].Normal = PatchPoints[0].normal;
	Points[1].Position = PatchPoints[1].pos;
	Points[1].Normal = PatchPoints[1].normal;
	Points[2].Position = PatchPoints[2].pos;
	Points[2].Normal = PatchPoints[2].normal;

	rage_ComputePNTrianglePatchInfo(Points[0], Points[1], Points[2], Output, SHADOW_TESSELLATION_MULTIPLIER);

	return Output;
}

// Hull shader.
[domain("tri")]
[partitioning("fractional_odd")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("PF_CascadeShadows_PNTri")]
[maxtessfactor(15.0)]
VS_CascadeShadows_IN_CtrlPoint HS_CascadeShadows_PNTri(InputPatch<VS_CascadeShadows_IN_CtrlPoint, 3> PatchPoints, uint i : SV_OutputControlPointID, uint PatchID : SV_PrimitiveID)
{
	VS_CascadeShadows_IN_CtrlPoint Output;

	// Our control points match the vertex shader output.
	Output = PatchPoints[i];

	return Output;
}

// Hull shader.
[domain("tri")]
[partitioning("fractional_odd")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("PF_CascadeShadows_PNTri_instanced")]
[maxtessfactor(15.0)]
VS_CascadeShadows_IN_CtrlPoint_Instance HS_CascadeShadows_PNTri_instanced(InputPatch<VS_CascadeShadows_IN_CtrlPoint_Instance, 3> PatchPoints, uint i : SV_OutputControlPointID, uint PatchID : SV_PrimitiveID)
{
	VS_CascadeShadows_IN_CtrlPoint_Instance Output;

	// Our control points match the vertex shader output.
	Output = PatchPoints[i];

	return Output;
}


[domain("tri")]
VS_CascadeShadows_OUT DS_CascadeShadows_PNTri(rage_PNTri_PatchInfo PatchInfo, float3 WUV : SV_DomainLocation, const OutputPatch<VS_CascadeShadows_IN_CtrlPoint, 3> PatchPoints)
{
	VS_CascadeShadows_OUT OUT;

	// Evaluate the position.
	float3 inPos = rage_EvaluatePatchAt(PatchInfo, WUV);
	// Transform into worldspace.
 	OUT.pos = mul(float4(inPos, 1), gWorldViewProj);
#ifdef SHADOW_USE_TEXTURE
	OUT.tex = RAGE_COMPUTE_BARYCENTRIC(WUV, PatchPoints, tex);
#endif // SHADOW_USE_TEXTURE

	return OUT;
}

#if GS_INSTANCED_SHADOWS
[domain("tri")]
VS_CascadeShadows_OUT_instanced DS_CascadeShadows_PNTri_instanced(rage_PNTri_PatchInfo PatchInfo, float3 WUV : SV_DomainLocation, const OutputPatch<VS_CascadeShadows_IN_CtrlPoint_Instance, 3> PatchPoints)
{
	VS_CascadeShadows_OUT_instanced OUT;

	// This will be contant over the triangle.
	uint instID = PatchPoints[0].InstID;

	// Evaluate the position.
	float3 inPos = rage_EvaluatePatchAt(PatchInfo, WUV);
	// Transform into worldspace.
	OUT.pos = mul(float4(inPos, 1),mul(gInstWorld,gInstWorldViewProj[INSTOPT_INDEX(instID)]));
	OUT.InstID = INSTOPT_INDEX(instID);
#ifdef SHADOW_USE_TEXTURE
	OUT.tex = RAGE_COMPUTE_BARYCENTRIC(WUV, PatchPoints, tex);
#endif // SHADOW_USE_TEXTURE

	return OUT;
}
#endif // GS_INSTANCED_SHADOWS
#endif // USE_PN_TRIANGLES

// ================================================================================================
// Pixel shaders.	
// ================================================================================================

#if USE_PN_TRIANGLES
#define PN_TRIANGLES_CSM_ONLY(x) x
#else // USE_PN_TRIANGLES
#define PN_TRIANGLES_CSM_ONLY(x)
#endif // USE_PN_TRIANGLES

#if SHADOW_CASTING_TECHNIQUES

#define USE_TRANSPARENT_SHADOWS (0) // use screendoor to simulate 50% transparent shadows, only works with certain filter modes

#if CASCADE_SHADOWS_ENTITY_ID_TARGET
float4 GetEntitySelectID();
#endif // CASCADE_SHADOWS_ENTITY_ID_TARGET

#if CASCADE_SHADOWS_ENTITY_ID_TARGET
	float4 PS_CascadeShadows_entityIDs(VS_CascadeShadows_OUT IN) : COLOR
	{
		return GetEntitySelectID();
	}
	#define COMPILE_PIXELSHADER_CSM() compile PIXELSHADER PS_CascadeShadows_entityIDs() CGC_FLAGS(CGC_DEFAULTFLAGS);
#else
// 	#if __SHADERMODEL >= 40
// 		float4 PS_CascadeShadows_Test(VS_CascadeShadows_OUT IN) : COLOR
// 		{
// 			return IN.pos.z;
// 		}
// 		#define COMPILE_PIXELSHADER_CSM()	ColorWriteEnable = RED; \
// 											PixelShader = compile PIXELSHADER PS_CascadeShadows_Test();\
// 											DEF_TERMINATOR
// 	#else
		#define COMPILE_PIXELSHADER_CSM() COMPILE_PIXELSHADER_NULL()
//	#endif
#endif


#if defined(SHADOW_USE_TEXTURE)


#define SHADOW_USE_TEXTURE_ONLY(x) x

// copied from PS_WarpDepthFoliage
float4 PS_CascadeShadows_texture(VS_CascadeShadows_OUT IN
#if USE_TRANSPARENT_SHADOWS
	, float2 vPos:VPOS
#endif // USE_TRANSPARENT_SHADOWS
	) : COLOR
{
	float alphaScale = globalAlpha;
#ifdef TREE_DRAW //tree boost
	alphaScale = alphaScale*2;
#endif

	float a = tex2D(DiffuseSampler, IN.tex).a*alphaScale - 90.f/255.f;
#if USE_TRANSPARENT_SHADOWS
	a = SSAIsOpaquePixel(vPos) ? 0 : a;
#endif // USE_TRANSPARENT_SHADOWS

#if __SHADERMODEL >= 40
	rageDiscard(a < gAlphaTestRef);
#endif

#if CASCADE_SHADOWS_ENTITY_ID_TARGET
	return GetEntitySelectID();
#else
	return float4(1,1,1,a);
#endif
}

float4 PS_CascadeShadows_texture_alpha(VS_CascadeShadows_OUT IN
#if USE_TRANSPARENT_SHADOWS
	, float2 vPos:VPOS
#endif // USE_TRANSPARENT_SHADOWS
	) : COLOR
{
	float a = tex2D(DiffuseSampler, IN.tex).a*globalAlpha - 90.f/255.f;

	return a.xxxx;
}

//#if GS_INSTANCED_SHADOWS
//float4 PS_CascadeShadows_texture_instanced(GS_CascadeShadows_OUT IN
//#if USE_TRANSPARENT_SHADOWS
//	, float2 vPos:VPOS
//#endif // USE_TRANSPARENT_SHADOWS
//	) : COLOR
//{
//	float a = tex2D(DiffuseSampler, IN.tex).a*globalAlpha - 90.f/255.f;
//#if USE_TRANSPARENT_SHADOWS
//	a = SSAIsOpaquePixel(vPos) ? 0 : a;
//#endif // USE_TRANSPARENT_SHADOWS
//
//#if __SHADERMODEL >= 40
//	rageDiscard(a < gAlphaTestRef);
//#endif
//
//#if CASCADE_SHADOWS_ENTITY_ID_TARGET
//	return GetEntitySelectID();
//#else
//	return float4(1,1,1,a);
//#endif
//}
//#endif	//GS_INSTANCED_SHADOWS

#else //not defined(SHADOW_USE_TEXTURE)

#define SHADOW_USE_TEXTURE_ONLY(x)

#endif //not defined(SHADOW_USE_TEXTURE)

#ifndef SHADOW_USE_DOUBLE_SIDED
#define SHADOW_CULL_MODE()
#else
#define SHADOW_CULL_MODE()		CullMode =none; 
#endif

#if ALPHA_SHADOWS
#define SHADOW_PIXEL_SHADER PS_CascadeShadows_texture_alpha
#else
#define SHADOW_PIXEL_SHADER PS_CascadeShadows_texture
#endif // ALPHA_SHADOW

#define DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(techname,vsname) \
	technique techname { pass p0 \
	{ \
		VertexShader = compile VERTEXSHADER vsname(); \
		COMPILE_PIXELSHADER_CSM() \
	}} \
	PN_TRIANGLES_CSM_ONLY(SHADER_MODEL_50_OVERRIDE_TECHNIQUES(technique techname##tessellated { pass p0 \
	{ \
		VertexShader = compile VERTEXSHADER vsname(); \
		COMPILE_PIXELSHADER_CSM() \
	}}, \
	technique SHADER_MODEL_50_OVERRIDE(techname##tessellated) { pass p0 \
	{ \
		VertexShader = compile VSDS_SHADER vsname##_PNTri(); \
		SetHullShader(compileshader(hs_5_0, HS_CascadeShadows_PNTri())); \
		SetDomainShader(compileshader(ds_5_0, DS_CascadeShadows_PNTri())); \
		COMPILE_PIXELSHADER_CSM() \
	}})) \
	SHADOW_USE_TEXTURE_ONLY(technique shadtexture_##techname { pass p0 \
	{ \
		SHADOW_CULL_MODE() \
		VertexShader = compile VERTEXSHADER vsname(); \
		PixelShader  = compile PIXELSHADER SHADOW_PIXEL_SHADER() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	}} \
	PN_TRIANGLES_CSM_ONLY(SHADER_MODEL_50_OVERRIDE_TECHNIQUES(technique shadtexture_##techname##tessellated { pass p0 \
	{ \
		SHADOW_CULL_MODE() \
		VertexShader = compile VERTEXSHADER vsname(); \
		PixelShader  = compile PIXELSHADER SHADOW_PIXEL_SHADER() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	}}, \
	technique SHADER_MODEL_50_OVERRIDE(shadtexture_##techname##tessellated) { pass p0 \
	{ \
		VertexShader = compile VSDS_SHADER vsname##_PNTri(); \
		SetHullShader(compileshader(hs_5_0, HS_CascadeShadows_PNTri())); \
		SetDomainShader(compileshader(ds_5_0, DS_CascadeShadows_PNTri())); \
		PixelShader  = compile PIXELSHADER SHADOW_PIXEL_SHADER() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	}}))) \

// =================================

#define DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_INSTANCED(techname,vsname) \
	technique techname { pass p0 \
	{ \
		VertexShader = compile VSGS_SHADER vsname##_instanced(); \
		SetGeometryShader(compileshader(gs_5_0, GS_ShadowInstPassThrough())); \
		COMPILE_PIXELSHADER_CSM() \
	}} \
	PN_TRIANGLES_CSM_ONLY(SHADER_MODEL_50_OVERRIDE_TECHNIQUES(technique techname##tessellated { pass p0 \
	{ \
		VertexShader = compile VSGS_SHADER vsname##_instanced(); \
		SetGeometryShader(compileshader(gs_5_0, GS_ShadowInstPassThrough())); \
		COMPILE_PIXELSHADER_CSM() \
	}}, \
	technique SHADER_MODEL_50_OVERRIDE(techname##tessellated) { pass p0 \
	{ \
		VertexShader = compile VSDS_SHADER vsname##_PNTri_instanced(); \
		SetHullShader(compileshader(hs_5_0, HS_CascadeShadows_PNTri_instanced())); \
		SetDomainShader(compileshader(DSGS_SHADER, DS_CascadeShadows_PNTri_instanced())); \
		SetGeometryShader(compileshader(gs_5_0, GS_ShadowInstPassThrough())); \
		COMPILE_PIXELSHADER_CSM() \
	}})) \
	SHADOW_USE_TEXTURE_ONLY(technique shadtexture_##techname { pass p0 \
	{ \
		VertexShader = compile VSGS_SHADER vsname##_instanced(); \
		SetGeometryShader(compileshader(gs_5_0, GS_ShadowInstPassThrough())); \
		PixelShader  = compile PIXELSHADER PS_CascadeShadows_texture/*_instanced*/() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	}} \
	PN_TRIANGLES_CSM_ONLY(SHADER_MODEL_50_OVERRIDE_TECHNIQUES(technique shadtexture_##techname##tessellated { pass p0 \
	{ \
		VertexShader = compile VSGS_SHADER vsname##_instanced(); \
		SetGeometryShader(compileshader(gs_5_0, GS_ShadowInstPassThrough())); \
		PixelShader  = compile PIXELSHADER PS_CascadeShadows_texture/*_instanced*/() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	}}, \
	technique SHADER_MODEL_50_OVERRIDE(shadtexture_##techname##tessellated) { pass p0 \
	{ \
		VertexShader = compile VSDS_SHADER vsname##_PNTri_instanced(); \
		SetHullShader(compileshader(hs_5_0, HS_CascadeShadows_PNTri_instanced())); \
		SetDomainShader(compileshader(DSGS_SHADER, DS_CascadeShadows_PNTri_instanced())); \
		SetGeometryShader(compileshader(gs_5_0, GS_ShadowInstPassThrough())); \
		PixelShader  = compile PIXELSHADER PS_CascadeShadows_texture/*_instanced*/() CGC_FLAGS(CGC_DEFAULTFLAGS); \
	}}))) \

// =================================

#if GS_INSTANCED_SHADOWS
	#define SHADERTECHNIQUE_CASCADE_SHADOWS() \
		DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_draw, VS_CascadeShadows_draw) \
		DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_INSTANCED(wdcascade_drawinstanced, VS_CascadeShadows_draw) \
		DRAWSKINNED_TECHNIQUES_ONLY(DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_drawskinned, VS_CascadeShadows_drawskinned)) \
		DRAWSKINNED_TECHNIQUES_ONLY(DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_INSTANCED(wdcascade_drawskinnedinstanced, VS_CascadeShadows_drawskinned)) \
		DEF_TERMINATOR
	#define SHADERTECHNIQUE_CASCADE_SHADOWS_SKINNED_ONLY() \
		DRAWSKINNED_TECHNIQUES_ONLY(DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_drawskinned, VS_CascadeShadows_drawskinned)) \
		DRAWSKINNED_TECHNIQUES_ONLY(DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_INSTANCED(wdcascade_drawskinnedinstanced, VS_CascadeShadows_drawskinned)) \
		DEF_TERMINATOR
#elif __XENON || RSG_PC || RSG_ORBIS || RSG_DURANGO
	#define SHADERTECHNIQUE_CASCADE_SHADOWS() \
		DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_draw, VS_CascadeShadows_draw) \
		DRAWSKINNED_TECHNIQUES_ONLY(DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_drawskinned, VS_CascadeShadows_drawskinned)) \
		DEF_TERMINATOR
	#define SHADERTECHNIQUE_CASCADE_SHADOWS_SKINNED_ONLY() \
		DRAWSKINNED_TECHNIQUES_ONLY(DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_drawskinned, VS_CascadeShadows_drawskinned)) \
		DEF_TERMINATOR
#elif __PS3
	#define SHADERTECHNIQUE_CASCADE_SHADOWS() \
		DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascadeedge_draw, VS_CascadeShadows_draw) \
		DEF_TERMINATOR
	#define SHADERTECHNIQUE_CASCADE_SHADOWS_SKINNED_ONLY() \
		DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascadeedge_draw, VS_CascadeShadows_draw) \
		DEF_TERMINATOR
#endif // __PS3

#if defined(TREE_DRAW)
	#if (!CASCADE_SHADOWS_TREE_MICROMOVEMENTS) || defined(USE_TREE_LOD)
		#define SHADERTECHNIQUE_CASCADE_SHADOWS_TREE(_vs) SHADERTECHNIQUE_CASCADE_SHADOWS() // same as non-tree
	#else
		#if __XENON || RSG_PC || RSG_ORBIS || RSG_DURANGO
			#define SHADERTECHNIQUE_CASCADE_SHADOWS_TREE(_vs) \
				DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_draw, _vs) \
				DRAWSKINNED_TECHNIQUES_ONLY(DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_drawskinned, _vs)) \
				DEF_TERMINATOR
		#else
			#define SHADERTECHNIQUE_CASCADE_SHADOWS_TREE(_vs) \
				DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascadeedge_draw, _vs) \
				DEF_TERMINATOR
		#endif // __PS3
	#endif

#endif // defined(TREE_DRAW)

#if defined(GRASS_BATCH_SHADER)
	#define SHADERTECHNIQUE_CASCADE_SHADOWS_GRASS() \
		DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_draw, VS_Cascade_Transform) \
	DEF_TERMINATOR
#endif // defined(GRASS_BATCH_SHADER)


#if GS_INSTANCED_SHADOWS
#if defined(PRAGMA_CONSTANT_ROPE)
	#define DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE() \
		VS_CascadeShadows_OUT VS_CascadeShadows_ROPE_draw(VS_CascadeShadows_IN IN) \
		{ \
			VS_CascadeShadows_OUT OUT; \
			float3 pos = GenerateRopePos(IN.pos.xyz); \
			OUT.pos = mul(float4(pos, 1), gWorldViewProj); \
			SHADOW_USE_TEXTURE_ONLY(OUT.tex = IN.tex.xy); \
			return OUT; \
		} \
		VS_CascadeShadows_OUT_instanced VS_CascadeShadows_ROPE_draw_instanced(VS_CascadeShadows_IN IN, uint instID : SV_InstanceID) \
		{ \
			VS_CascadeShadows_OUT_instanced OUT; \
			float3 pos = GenerateRopePos(IN.pos.xyz); \
			OUT.pos = mul(float4(pos, 1),mul(gInstWorld,gInstWorldViewProj[INSTOPT_INDEX(instID)])); \
			OUT.InstID = INSTOPT_INDEX(instID); \
			SHADOW_USE_TEXTURE_ONLY(OUT.tex = IN.tex.xy); \
			return OUT; \
		} 
		#define SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE() \
			DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE() \
			DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_draw, VS_CascadeShadows_ROPE_draw) \
			DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_INSTANCED(wdcascade_drawinstanced, VS_CascadeShadows_ROPE_draw) \
			DEF_TERMINATOR
#endif // defined(PRAGMA_CONSTANT_ROPE)
#else	//GS_INSTANCED_SHADOWS
#if defined(PRAGMA_CONSTANT_ROPE)
	#define DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE() \
		VS_CascadeShadows_OUT VS_CascadeShadows_ROPE_draw(VS_CascadeShadows_IN IN) \
		{ \
			VS_CascadeShadows_OUT OUT; \
			float3 pos = GenerateRopePos(IN.pos.xyz); \
			OUT.pos = mul(float4(pos, 1), gWorldViewProj); \
			SHADOW_USE_TEXTURE_ONLY(OUT.tex = IN.tex.xy); \
			return OUT; \
		}
		#if __XENON || RSG_PC || RSG_ORBIS || RSG_DURANGO
			#define SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE() \
				DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE() \
				DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_draw, VS_CascadeShadows_ROPE_draw) \
				DEF_TERMINATOR
		#elif __PS3
			#define SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE() \
				DEF_SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE() \
				DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascadeedge_draw, VS_CascadeShadows_ROPE_draw) \
				DEF_TERMINATOR
		#endif // __PS3
#endif // defined(PRAGMA_CONSTANT_ROPE)
#endif	//GS_INSTANCED_SHADOWS

#if defined( USE_UMOVEMENTS_TEX )


#define SHADERTECHNIQUE_CASCADE_SHADOWS_UMOVEMENTS_SHADER() 
	#if __XENON || RSG_PC || RSG_ORBIS || RSG_DURANGO
			#define SHADERTECHNIQUE_CASCADE_SHADOWS_UMOVEMENTS() 	
				DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascade_draw, VS_CascadeShadowsUMovements ) \
				DEF_TERMINATOR
		#elif __PS3
			#define SHADERTECHNIQUE_CASCADE_SHADOWS_UMOVEMENTS() \
				DEF_SHADERTECHNIQUE_CASCADE_SHADOWS(wdcascadeedge_draw, VS_CascadeShadowsUMovements) \
				DEF_TERMINATOR
		#endif // __PS3

#endif // defined( USE_UMOVEMENTS_TEX )

#endif // SHADOW_CASTING_TECHNIQUES
#endif // SHADOW_CASTING

#ifndef SHADERTECHNIQUE_CASCADE_SHADOWS
#define SHADERTECHNIQUE_CASCADE_SHADOWS()
#endif

#ifndef SHADERTECHNIQUE_CASCADE_SHADOWS_SKINNED_ONLY
#define SHADERTECHNIQUE_CASCADE_SHADOWS_SKINNED_ONLY()
#endif

#ifndef SHADERTECHNIQUE_CASCADE_SHADOWS_TREE
#define SHADERTECHNIQUE_CASCADE_SHADOWS_TREE(_vs)
#endif

#ifndef SHADERTECHNIQUE_CASCADE_SHADOWS_GRASS
#define SHADERTECHNIQUE_CASCADE_SHADOWS_GRASS()
#endif

#ifndef SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE
#define SHADERTECHNIQUE_CASCADE_SHADOWS_ROPE()
#endif

#ifndef SHADERTECHNIQUE_CASCADE_SHADOWS_UMOVEMENTS
#define SHADERTECHNIQUE_CASCADE_SHADOWS_UMOVEMENTS()
#endif

#endif // _CASCADESHADOWS_FXH_
