#ifndef __LIGHT_COMMON
#define __LIGHT_COMMON

#include "../../Util/macros.fxh"
#include "light_structs.fxh"

// ----------------------------------------------------------------------------------------------- //

#define SHAD_ON			true
#define FILL_ON			true
#define INT_ON			true
#define EXT_ON			true
#define TEX_ON			true
#define VEH_TWIN_ON		true
#define CAUS_ON         true
#define SOFTSHAD_ON		true

#define SHAD_OFF		false
#define FILL_OFF		false
#define INT_OFF			false
#define EXT_OFF			false
#define TEX_OFF			false
#define VEH_TWIN_OFF	false
#define CAUS_OFF        false
#define SOFTSHAD_OFF	false

#define LIGHT_ATTEN_THRESHOLD 1e-6

// this should match the #define in lights.h
#define USE_STENCIL_FOR_INTERIOR_EXTERIOR_CHECK (__PS3)  // xenon can't use interior exterior stencil due to it being cleared by the light stencils

// ----------------------------------------------------------------------------------------------- //

#define GEN_FUNCS(name, vInput, vOutput, pInput, pOutput, shadow, filler, interior, exterior, caustic, texture, vehicleTwin, softShadows) \
vOutput JOIN4(VS_,LTYPE,_,name)(vInput IN) \
{ \
	lightProperties light = PopulateLightPropertiesDeferred(); \
	vOutput OUT = JOIN(VS_,LTYPE)(IN, light, shadow, texture); \
	return(OUT); \
} \
\
pOutput JOIN4(PS_,LTYPE,_,name)(pInput IN) \
{ \
	pOutput OUT; \
	lightProperties light = PopulateLightPropertiesDeferred(); \
	OUT.col = JOIN(deferred_,LTYPE)(IN, light, shadow, filler, interior, exterior, caustic, texture, vehicleTwin, softShadows); \
	return OUT;	\
} 

// ----------------------------------------------------------------------------------------------- //

#define GEN_VOLUME_FUNCS(name, vInput, vOutput, pInput, pOutput, shadow, outside, numSteps) \
vOutput JOIN4(VS_,LTYPE,_vol_,name)(vInput IN) \
{ \
	lightProperties light = PopulateLightPropertiesDeferred(); \
	vOutput OUT = JOIN(VS_volume_,LTYPE)(IN, light, shadow, outside); \
	return(OUT); \
} \
\
pOutput JOIN4(PS_,LTYPE,_vol_,name)(pInput IN) \
{ \
	pOutput OUT; \
	lightProperties light = PopulateLightPropertiesDeferred(); \
	OUT.col = (half4)JOIN(PS_volume_,LTYPE)(IN, light, shadow, outside, numSteps); \
	return OUT; \
} 

// ----------------------------------------------------------------------------------------------- //

#endif
