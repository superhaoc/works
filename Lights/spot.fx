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
#define	SHADOW_CUBEMAP							   (1) // turn this off for spot lights, if we ever add a sperate hemisphere ligth shader (currently spot does both)

#include "../Shadows/localshadowglobals.fxh"
#include "../Shadows/cascadeshadows.fxh"
#include "../lighting.fxh"

#include "spot.fxh"
