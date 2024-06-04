#define SAMPLE_FREQUENCY	0
#include "../commonMS.fxh"
#include "deferred_lighting.fx"

#if (RSG_PC && __SHADERMODEL >=40) || MULTISAMPLE_TECHNIQUES
#define SUPPORT_FADING_EDGE	1
#define DECODE_TWIDDLE		1
// we can't use it since we are also writing to stencil
#define COMPARE_STENCIL		0
// diffuse has a lot of noise
#define COMPARE_DIFFUSE		0
#define COMPARE_NORMAL		1
#define COMPARE_SPECULAR	1

BeginConstantBufferDX10(edge_mark)
float4 EdgeMarkParams;
EndConstantBufferDX10(edge_mark)


#if SUPPORT_FADING_EDGE
Texture2D<float> StencilCopy;

bool IsFadingEdge(int2 iPos)
{
	uint mask = uint(StencilCopy.Load(int3(iPos, 0)) * 256.0);
	return (mask & DEFERRED_MATERIAL_SPAREOR1) != 0;
}
#else
bool IsFadingEdge(int2 iPos)
{
	return false;
}
#endif //SUPPORT_FADING_EDGE

half4 PS_EdgeEmpty(float4 absolutePos: SV_Position) : COLOR
{
	return half4(1,1,1,1);
}

uint ReadStencil(uint2 iPos, uint sampleIndex)
{
#if SHADER_STENCIL_ACCESS_AS_UINT2
	return gbufferStencilTextureGlobal.Load(iPos, sampleIndex).g;
#else
	return gbufferStencilTextureGlobal.Load(iPos, sampleIndex);
#endif
}

half4 PS_EdgeMarkShow(float4 absolutePos: SV_Position) : COLOR
{
	uint stencil = ReadStencil(absolutePos.xy, 0);
	return (stencil & DEFERRED_MATERIAL_SPAREOR1) != 0;
}

struct PixelInfo {
	float Depth;
#if COMPARE_DIFFUSE
	float4 Diffuse;
#endif
#if COMPARE_NORMAL
	float4 Normal;
#endif
#if COMPARE_STENCIL
	uint Stencil;
#endif
#if COMPARE_SPECULAR
	float4 specIntExpAmb;
#endif
};

PixelInfo ReadPixel(uint2 iPos, uint sampleIndex) {
	float depth = gbufferTextureDepthGlobal.Load(iPos, sampleIndex).x;

#if COMPARE_NORMAL
	float4 normal = gbufferTexture1Global.Load(iPos, sampleIndex);
# if DECODE_TWIDDLE
	float3 twiddle = frac(normal.w * float3(0.998046875f,7.984375f,63.875f));
	twiddle.xy -= twiddle.yx * 0.125f;
	normal.xyz = normalize(normal.xyz*256.0f + twiddle.xyz - 128.0f);
# else
	normal.xyz = normalize((normal.xyz*2.0f) - 1.0f);
# endif
#endif //COMPARE_NORMAL
	
	PixelInfo info = {
		depth
#if COMPARE_DIFFUSE
		,gbufferTexture0Global.Load(iPos, sampleIndex)
#endif
#if COMPARE_NORMAL
		,normal
#endif
#if COMPARE_STENCIL
		,ReadStencil(iPos, sampleIndex)
#endif
#if COMPARE_SPECULAR
		,gbufferTexture2Global.Load(iPos, sampleIndex)
#endif
	};
	return info;
}

void PS_EdgeMarkDerivatives(float4 absolutePos: SV_Position)
{
	PixelInfo pix = ReadPixel(absolutePos.xy, 0);
	
	float2 depth_derivative = float2(ddx(pix.Depth), ddy(pix.Depth));
	float depth_diff = dot(depth_derivative, depth_derivative);
	if (depth_diff == 0.0)
		discard;

#if COMPARE_DIFFUSE
	float4 c = pix.Diffuse;
	float diffuse_corr = dot(ddx(c), ddx(c)) + dot(ddy(c), ddy(c));
#endif //COMPARE_DIFFUSE
#if COMPARE_NORMAL
	float3 n = pix.Normal.xyz;
	float normal_corr = dot(ddx(n), ddx(n)) + dot(ddy(n), ddy(n));
#endif //COMPARE_NORMAL
#if COMPARE_STENCIL
	float stencil_diff = abs(ddx(pix.Stencil)) + abs(ddy(pix.Stencil));
#endif //COMPARE_STENCIL
#if COMPARE_SPECULAR
	float spec = pix.specIntExpAmb.x;
	float2 spec_derivative = float2(ddx(spec), ddy(spec));
	float spec_diff = dot(spec_derivative, spec_derivative);
#endif //COMPARE_SPECULAR

	if (depth_diff < EdgeMarkParams.w
#if COMPARE_DIFFUSE
		&& diffuse_corr > EdgeMarkParams.x
#endif
#if COMPARE_NORMAL
		&& normal_corr > EdgeMarkParams.y
#endif
#if COMPARE_STENCIL
		&& stencil_diff == 0.0
#endif
#if COMPARE_SPECULAR
		&& spec_diff < EdgeMarkParams.z
#endif
		) discard;
}

bool AreDifferentPixels(PixelInfo pix0, PixelInfo pix1)
{
	float depth_diff = abs(pix0.Depth - pix1.Depth);
	if (depth_diff == 0.0)
		return false;
	if (depth_diff > EdgeMarkParams.w)
		return true;
#if COMPARE_DIFFUSE
	if (dot(pix0.Diffuse, pix1.Diffuse) < EdgeMarkParams.x)
		return true;
#endif //COMPARE_NORMAL
#if COMPARE_NORMAL
	if (dot(pix0.Normal.xyz, pix1.Normal.xyz) < EdgeMarkParams.y)
		return true;
#endif //COMPARE_NORMAL
#if COMPARE_STENCIL
	if (pix0.Stencil != pix1.Stencil)
		return true;
#endif //COMPARE_STENCIL
#if COMPARE_SPECULAR
	// both normal twiddle and specularity should be different
# if COMPARE_NORMAL
	if (abs(pix0.Normal.w - pix1.Normal.w) > EdgeMarkParams.z)
# endif
	if (abs(pix0.specIntExpAmb.x - pix1.specIntExpAmb.x) > EdgeMarkParams.z)
		return true;
#endif //COMPARE_SPECULAR
	
	return false;
}

bool AreDifferentSamples2(uint2 iPos, uint sa, uint sb)
{
	return AreDifferentPixels(ReadPixel(iPos, sa), ReadPixel(iPos, sb));
}

bool AreDifferentSamples4(uint2 iPos, uint4 s)
{
	PixelInfo p[4] = {
		ReadPixel(iPos, s.x),
		ReadPixel(iPos, s.y),
		ReadPixel(iPos, s.z),
		ReadPixel(iPos, s.w)
	};

	return
		AreDifferentPixels(p[0], p[1]) ||
		AreDifferentPixels(p[1], p[2]) ||
		AreDifferentPixels(p[2], p[3]);
}

// Using distance samples from standard patterns:
// http://msdn.microsoft.com/en-us/library/windows/desktop/ff476218%28v=vs.85%29.aspx

void PS_EdgeMarkSamples1(float4 absolutePos: SV_Position)
{
	if (!IsFadingEdge(absolutePos.xy))
		discard;
}

void PS_EdgeMarkSamples2(float4 absolutePos: SV_Position)
{
	if (!IsFadingEdge(absolutePos.xy) &&
		!AreDifferentSamples2(absolutePos.xy, 0, 1))
		discard;
}

void PS_EdgeMarkSamples4(float4 absolutePos: SV_Position)
{
	if (!IsFadingEdge(absolutePos.xy) &&
		!AreDifferentSamples4(absolutePos.xy, uint4(0,3,1,2)))
		discard;
}

void PS_EdgeMarkSamples8(float4 absolutePos: SV_Position)
{
	if (!IsFadingEdge(absolutePos.xy) &&
		!AreDifferentSamples4(absolutePos.xy, uint4(7,5,6,0)))
		discard;
}

void PS_EdgeMarkSamples16(float4 absolutePos: SV_Position)
{
	if (!IsFadingEdge(absolutePos.xy) &&
		!AreDifferentSamples2(absolutePos.xy, 8, 9) &&
		!AreDifferentSamples2(absolutePos.xy, 11, 14) &&
		!AreDifferentSamples2(absolutePos.xy, 13, 15))
		discard;
}

void PS_EdgeMarkSamples4_Old(float4 absolutePos: SV_Position)
{
	if (!IsFadingEdge(absolutePos.xy) &&
		!AreDifferentSamples2(absolutePos.xy, 0, 3) &&
		!AreDifferentSamples2(absolutePos.xy, 1, 2))
		discard;
}

void PS_EdgeMarkSamples8_Old(float4 absolutePos: SV_Position)
{
	if (!IsFadingEdge(absolutePos.xy) &&
		!AreDifferentSamples2(absolutePos.xy, 3, 4) &&
		!AreDifferentSamples2(absolutePos.xy, 6, 7) &&
		!AreDifferentSamples2(absolutePos.xy, 2, 5))
		discard;
}

void PS_EdgeMarkSamplesHeavy(float4 pos: SV_Position)
{
	PixelInfo p0 = ReadPixel(pos.xy, 0);
	PixelInfo p1 = ReadPixel(pos.xy + float2(1,0), 1);
	PixelInfo p2 = ReadPixel(pos.xy + float2(-1,0), 1);
	PixelInfo p3 = ReadPixel(pos.xy + float2(0,1), 0);
	PixelInfo p4 = ReadPixel(pos.xy + float2(0,-1), 0);
	
	if (!IsFadingEdge(pos.xy) &&
		!AreDifferentPixels(p0, p1) &&
		!AreDifferentPixels(p0, p2) &&
		!AreDifferentPixels(p0, p3) &&
		!AreDifferentPixels(p0, p4))
		discard;
}

// Collecting edge flags over all the samples

float PS_EdgeCollect2(float4 pos: SV_Position): COLOR
{
	uint mask = ReadStencil(pos.xy, 0) | ReadStencil(pos.xy, 1);
	return float(mask / 256.0);
}

float PS_EdgeCollect4(float4 pos: SV_Position): COLOR
{
	uint mask =
		ReadStencil(pos.xy, 0) | ReadStencil(pos.xy, 1) |
		ReadStencil(pos.xy, 2) | ReadStencil(pos.xy, 3) ;
	return float(mask / 256.0);
}

float PS_EdgeCollect8(float4 pos: SV_Position): COLOR
{
	uint mask =
		ReadStencil(pos.xy, 0) | ReadStencil(pos.xy, 1) |
		ReadStencil(pos.xy, 2) | ReadStencil(pos.xy, 3) |
		ReadStencil(pos.xy, 4) | ReadStencil(pos.xy, 5) |
		ReadStencil(pos.xy, 6) | ReadStencil(pos.xy, 7) ;
	return float(mask / 256.0);
}

technique EdgeMark
{
	// a pass that does nothing
	pass edge_empty
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeEmpty()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	// output the edge flag into color
	pass edge_show
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkShow()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	// use screen-space derivatives to mark edges, doesn't take into account higher samples
	pass edge_derivatives
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkDerivatives()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	// use the variation of samples inside the pixel
	pass edge_samples_1
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkSamples1()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_samples_2
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkSamples2()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_samples_4
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkSamples4()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_samples_8
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkSamples8()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_samples_16
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkSamples16()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	// previous generations, for comparison
	pass edge_samples_4_old
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkSamples4_Old()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_samples_8_old
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkSamples8_Old()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_samples_heavy
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeMarkSamplesHeavy()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_collect_2
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeCollect2()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_collect_4
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeCollect4()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
	pass edge_collect_8
	{
		VertexShader = compile VERTEXSHADER VS_screenTransformS();
		PixelShader  = compile MSAA_PIXEL_SHADER PS_EdgeCollect8()  CGC_FLAGS(CGC_DEFAULTFLAGS);
	}
}
#endif // RSG_PC
