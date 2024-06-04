// ======================
// shadowSmartBlit.fx
// (c) 2010 RockstarNorth
// ======================

#pragma dcl position

#include "../../common.fxh"

#define SHADOW_SMART_BLIT_FX

#define SHADOW_CASTING            (0)
#define SHADOW_CASTING_TECHNIQUES (0)
#define SHADOW_RECEIVING          (0)
#define SHADOW_RECEIVING_VS       (0)
#include "localshadowglobals.fxh"

#if USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
	#define CUBEMAP_TEXCOORDS(xyz,index)	float4(xyz,index)
	#define TEXCOORDS(xy,index)				float3(xy,index)
#else
	#define CUBEMAP_TEXCOORDS(xyz,index)	float3(xyz)
	#define TEXCOORDS(xy,index)				float2(xy)
#endif

//------------------------------------

struct vertexInput
{
	float3 pos : POSITION;
	float2 tex : TEXCOORD0;
};

struct vertexOutput
{
	DECLARE_POSITION(pos)
	float4 tex : TEXCOORD0;
};


//------------------------------------
#if USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
BeginDX10Sampler(sampler, Texture2DArray, SmartBlitTexture, SmartBlitSampler, SmartBlitTexture)
#else
BeginDX10Sampler(sampler, Texture2D,	  SmartBlitTexture, SmartBlitSampler, SmartBlitTexture)
#endif
ContinueSampler(sampler,				  SmartBlitTexture, SmartBlitSampler, SmartBlitTexture)
	AddressU  = WRAP;
	AddressV  = WRAP;
	AddressW  = WRAP;
	MIPFILTER = POINT;
	MINFILTER = POINT;
	MAGFILTER = POINT;
EndSampler;

#if USE_LOCAL_LIGHT_SHADOW_TEXTURE_ARRAYS
BeginDX10Sampler(sampler,  TextureCubeArray, SmartBlitCubeMapTexture, SmartBlitCubeMapSampler, SmartBlitCubeMapTexture)
#else
BeginDX10Sampler(sampler,  TextureCube,		 SmartBlitCubeMapTexture, SmartBlitCubeMapSampler, SmartBlitCubeMapTexture)
#endif
ContinueSampler( sampler,					 SmartBlitCubeMapTexture, SmartBlitCubeMapSampler, SmartBlitCubeMapTexture)
	AddressU  = WRAP;
	AddressV  = WRAP;
	MIPFILTER = POINT;
	MINFILTER = POINT;
	MAGFILTER = POINT;
EndSampler;


BeginConstantBufferDX10(shadowSmartBlit_locals)
float  cubeFace : CubeMapFace;
EndConstantBufferDX10(shadowSmartBlit_locals)


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ******************************
//	DRAW METHODS
// ******************************

vertexOutput VS_blit(vertexInput IN)
{
	vertexOutput OUT;
	OUT.pos = float4(IN.pos.xy,0,1);
	OUT.tex.xy = IN.tex.xy;
	OUT.tex.z = 0;
	OUT.tex.w = IN.pos.z;  // the texture array index (if needed)
	return OUT;
}

vertexOutput VS_blitCM(vertexInput IN)
{
	vertexOutput OUT;
	OUT.pos = float4(IN.pos.xy,0,1);
	
	// find a cubemap ray based on the 2d coords and a face
	float x = 2*IN.tex.x-1; // center the coords
	float y = 2*IN.tex.y-1;
	if (cubeFace==0)
		OUT.tex.xyz = float3(1,-y,-x);
	else if (cubeFace == 1)
		OUT.tex.xyz = float3(-1,-y,x);
	else if (cubeFace == 2)
		OUT.tex.xyz = float3(x,1,y);
	else if (cubeFace == 3)
		OUT.tex.xyz = float3(x,-1,-y);
	else if (cubeFace == 4)
		OUT.tex.xyz = float3(x,-y,1);
	else if (cubeFace == 5)		
		OUT.tex.xyz = float3(-x,-y,-1);
	else
		OUT.tex.xyz = float3(0,0,0);

	OUT.tex.w = IN.pos.z;  // the texture array index (if needed)
	return OUT;
}

/* ====== PIXEL SHADERS =========== */
//-----------------------------------

struct pixelOutputDepth
{
#if (__SHADERMODEL <40)
	float4 colour : COLOR;
#endif
	float  depth  : DEPTH;
};



#if !defined(SHADER_FINAL)
float4 PS_copyDebugColorDepth_BANK_ONLY(vertexOutput IN) : COLOR
{
#if __SHADERMODEL >= 40
	float depthChannel = 1 - SmartBlitTexture.Sample(SmartBlitSampler, TEXCOORDS(IN.tex.xy,IN.tex.w)).x;
#else
	float depthChannel = 1 - tex2D(SmartBlitSampler, TEXCOORDS(IN.tex.xy,IN.tex.w)).x; 
#endif
	return float4(1 - pow(depthChannel.rrr,2),1.0);
}

float4 PS_copyDebugColorCMDepth_BANK_ONLY(vertexOutput IN) : COLOR
{
 #if __SHADERMODEL >= 40
	float depthChannel = 1 - SmartBlitCubeMapTexture.Sample(SmartBlitCubeMapSampler, CUBEMAP_TEXCOORDS(IN.tex.xyz,IN.tex.w)).x;
 #else
 	float depthChannel = 1 - texCUBE(SmartBlitCubeMapSampler, CUBEMAP_TEXCOORDS(IN.tex.xyz,IN.tex.w)).x; 
 #endif

	return float4(1 - pow(depthChannel.rrr,2),1.0);
}
#endif // !defined(SHADER_FINAL)

float4 PS_copyDepth(vertexOutput IN, out float depth : DEPTH) : COLOR
{
#if __SHADERMODEL >= 40
	depth = SmartBlitTexture.Sample(SmartBlitSampler, TEXCOORDS(IN.tex.xy,IN.tex.z)).x;
#else
	depth = tex2D(SmartBlitSampler, TEXCOORDS(IN.tex.xy,IN.tex.z)).x; 
#endif

	return float4(1,1,1,1);
}

float4 PS_copyCMDepth(vertexOutput IN, out float depth : DEPTH) : COLOR
{
 #if __SHADERMODEL >= 40
	depth = SmartBlitCubeMapTexture.Sample(SmartBlitCubeMapSampler, CUBEMAP_TEXCOORDS(IN.tex.xyz,IN.tex.w)).x;
 #else
 	depth = texCUBE(SmartBlitCubeMapSampler, CUBEMAP_TEXCOORDS(IN.tex.xyz,IN.tex.w)).x; 
 #endif

	return float4(1,1,1,1);
}

// ===============================
// technique
// ===============================


#if !defined(SHADER_FINAL)
technique copyColorDepthDebugBlit // non linear dispay so depth shows better in debug view.
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_blit();
		PixelShader  = compile PIXELSHADER  PS_copyDebugColorDepth_BANK_ONLY() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}

technique copyColorDepthCubeMapDebugBlit  // non linear dispay so depth shows better in debug view.
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_blitCM();
		PixelShader  = compile PIXELSHADER  PS_copyDebugColorCMDepth_BANK_ONLY() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
#endif // !defined(SHADER_FINAL)

#if RSG_PC || 1   // some low end PC cannot use CopySubresourceRegion() for depth targets.
technique copyDepthBlit
{
	pass p0
	{
		VertexShader = compile VERTEXSHADER VS_blit();
		PixelShader  = compile PIXELSHADER  PS_copyDepth() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass p1 // CUBEMAP version
	{
		VertexShader = compile VERTEXSHADER VS_blitCM();
		PixelShader  = compile PIXELSHADER  PS_copyCMDepth() CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
#endif //RSG_PC

