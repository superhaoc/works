// ======================
// shadowZCM.fx
// (c) 2010 RockstarNorth
// ======================

//#if !__PS3 -- but it needs to compile for tools ..

#pragma dcl position

#include "../../common.fxh"
#include "../../Util/skin.fxh"

#define SHADOW_CASTING            (1)
#define SHADOW_CASTING_TECHNIQUES (0)
#define SHADOW_RECEIVING          (0)
#define SHADOW_RECEIVING_VS       (0)
#include "../Shadows/localshadowglobals.fxh"


struct VS_Shadows_IN
{
	float3 pos : POSITION;
};

struct VS_Shadows_IN_skinned
{
	float3 pos : POSITION;
	float4 blendweights : BLENDWEIGHT;
	index4 blendindices : BLENDINDICES;
};


vertexOutputLD VS_Depth(VS_Shadows_IN IN)
{
	vertexOutputLD OUT;
	OUT.pos = TransformCMShadowVert(IN.pos.xyz, SHADOW_NEEDS_DEPTHINFO_OUT(OUT));
	return OUT;
}

#if __XENON || __WIN32PC || RSG_ORBIS || RSG_DURANGO
vertexOutputLD VS_DepthSkin(VS_Shadows_IN_skinned IN)
{
	vertexOutputLD OUT;
	float3 inPos = rageSkinTransform(IN.pos.xyz, ComputeSkinMtx(IN.blendindices, IN.blendweights)); 
	OUT.pos = TransformCMShadowVert(inPos, SHADOW_NEEDS_DEPTHINFO_OUT(OUT));
	return OUT;
}
#else
vertexOutputLD VS_DepthSkin(VS_Shadows_IN IN)
{
	vertexOutputLD OUT;
	OUT.pos = TransformCMShadowVert(IN.pos.xyz, SHADOW_NEEDS_DEPTHINFO_OUT(OUT));
	return OUT;
}
#endif


//#if UNLIT_TECHNIQUES
technique unlit_draw
{
	pass p0
	{
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;

		VertexShader = compile VERTEXSHADER VS_Depth();
		PixelShader  = compile PIXELSHADER PS_LinearDepthOpaque();
	}
}

#if DRAWSKINNED_TECHNIQUES
technique unlit_drawskinned
{
	pass p0
	{
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;

		VertexShader = compile VERTEXSHADER VS_DepthSkin();
		PixelShader  = compile PIXELSHADER PS_LinearDepthOpaque();
	}
}
#endif // DRAWSKINNED_TECHNIQUES
//#endif // UNLIT_TECHNIQUES

//#endif // !__PS3
