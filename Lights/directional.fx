#pragma dcl position

#define DEFERRED_UNPACK_LIGHT                      
#define DEFINE_DEFERRED_LIGHT_TECHNIQUES_AND_FUNCS (1)
#define SPECULAR								   (1)
#define REFLECT									   (1)
#define REFLECT_DYNAMIC					   (1)

#include "../../common.fxh"
#pragma constant 130

#define SHADOW_CASTING							   (0)
#define SHADOW_CASTING_TECHNIQUES				   (0)
#define SHADOW_RECEIVING						   (1)
#define SHADOW_RECEIVING_VS						   (0)
#include "../Shadows/cascadeshadows.fxh"
#include "../lighting.fxh"

#if !defined(SHADER_FINAL)
float4  gDebugLightingParams : DebugLightingParams;
#define gDebugLighting_DiffuseLight gDebugLightingParams.y
#endif // !defined(SHADER_FINAL)

#include "dir.fxh"
