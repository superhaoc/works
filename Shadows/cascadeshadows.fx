// ======================
// cascadeshadows.fx
// (c) 2011 RockstarNorth
// ======================

#pragma dcl position

#include "../../common.fxh"

#if __XENON || (RSG_PC && __SHADERMODEL >= 40) || RSG_DURANGO || RSG_ORBIS

#define SHADOW_CASTING            (1)
#define SHADOW_CASTING_TECHNIQUES (1) // necessary for COMPILE_PIXELSHADER_CSM
#define SHADOW_RECEIVING          (0)
#define SHADOW_RECEIVING_VS       (0)

#include "cascadeshadows.fxh"

#if CASCADE_SHADOWS_ENTITY_ID_TARGET
	#include "../Debug/EntitySelect.fxh"
#endif // CASCADE_SHADOWS_ENTITY_ID_TARGET

//#if UNLIT_TECHNIQUES
technique unlit_draw
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_CascadeShadows_draw();
		COMPILE_PIXELSHADER_CSM()
	}
}

#if GS_INSTANCED_SHADOWS
technique unlit_drawinstanced
{
	pass p0
	{
		VertexShader = compile VSGS_SHADER VS_CascadeShadows_draw_instanced();
		SetGeometryShader(compileshader(gs_5_0, GS_ShadowInstPassThrough()));
		COMPILE_PIXELSHADER_CSM()
	}
}
#endif

//#endif // UNLIT_TECHNIQUES

//#if UNLIT_TECHNIQUES && DRAWSKINNED_TECHNIQUES
technique unlit_drawskinned
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_CascadeShadows_drawskinned();
		COMPILE_PIXELSHADER_CSM()
	}
}

#if GS_INSTANCED_SHADOWS
technique unlit_drawskinnedinstanced
{
	pass p0
	{
		VertexShader = compile VSGS_SHADER VS_CascadeShadows_drawskinned_instanced();
		SetGeometryShader(compileshader(gs_5_0, GS_ShadowInstPassThrough()));
		COMPILE_PIXELSHADER_CSM()
	}
}
#endif

//#endif // UNLIT_TECHNIQUES && DRAWSKINNED_TECHNIQUES
#else 
technique dummy{ pass dummy	{} }
#endif	// __XENON || (RSG_PC && __SHADERMODEL >= 40) || RSG_DURANGO || RSG_ORBIS
