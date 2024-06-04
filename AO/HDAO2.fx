#pragma strip off
#pragma dcl position

#define NO_SKINNING
#include "../../common.fxh"
#include "../../../renderer/SSAO_shared.h"

#if __SHADERMODEL>=40

#define USE_COMPUTE_SHADER	(1)
#define USE_GATHER			(!RSG_ORBIS)
#define USE_RANDOM_TAPS		(1)
#define USE_NORMALS			(1)
#define USE_PARAMETERS		(1)

#if RSG_PC || RSG_DURANGO
// "ps_5_0 does not support groupshared, groupshared ignored"
#pragma warning( disable: 3579 )
#endif

#if MULTISAMPLE_TECHNIQUES && HDAO2_MULTISAMPLE_FILTER
#define MSAA_FLOAT		float4
#else
#define MSAA_FLOAT		float
#endif

BeginDX10Sampler(sampler, TEXTURE2D_TYPE<float4>, depthOrigTexture, depthOrigSampler, depthOrigTexture)
ContinueSampler(sampler, depthOrigTexture, depthOrigSampler, depthOrigTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;

BeginDX10Sampler(sampler, TEXTURE2D_TYPE<float4>, normalOrigTexture, normalOrigSampler, normalOrigTexture)
ContinueSampler(sampler, normalOrigTexture, normalOrigSampler, normalOrigTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;


BeginDX10Sampler(sampler, Texture2D<float>, depthTexture, depthSampler, depthTexture)
ContinueSampler(sampler, depthTexture, depthSampler, depthTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;

BeginDX10Sampler(sampler, Texture2D<float4>, normalTexture, normalSampler, normalTexture)
ContinueSampler(sampler, normalTexture, normalSampler, normalTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;

BeginDX10Sampler(sampler, Texture2D<MSAA_FLOAT>, occlusionTexture, occlusionSampler, occlusionTexture)
ContinueSampler(sampler, occlusionTexture, occlusionSampler, occlusionTexture)
	AddressU	= CLAMP;
	AddressV	= CLAMP;
	MINFILTER	= LINEAR;
	MAGFILTER	= LINEAR;
EndSampler;


BEGIN_RAGE_CONSTANT_BUFFER(hdao_locals,b0)
float4	g_projParams		: projectionParams;		// sx, sy, dscale, doffset 
float4	g_projShear			: projectionShear;		// shearX, shearY
float4	g_targetSize		: targetSize;			// Width, Height, 1/Width, 1/Height
float4	g_HDAO_Params1		: HDAO_Params1	= float4(0.5f,0.05f,1.0f,1.0f);	// Strength, Normal scale, Radius scale XY
float4	g_HDAO_Params2		: HDAO_Params2	= float4(0.8f,0.003f,1.66f,0);	// Reject radius, Accept radius, Recipe of the fade-out distance, null
float4  g_DepthTexParams	: origDepthTexParams; // GBuffer Depth: Width, Height, 1/Width, 1/Height
EndConstantBufferDX10(hdao_locals)

#if USE_COMPUTE_SHADER
RWTexture2D<MSAA_FLOAT>		g_ResultTexture		REGISTER2( cs_5_0, u0 );
#endif	//USE_COMPUTE_SHADER

#if USE_PARAMETERS
#define	g_fHDAOIntensity		(g_HDAO_Params1.x)
#define	g_fHDAONormalScale		(g_HDAO_Params1.y)
#define	g_fHDAORadiusScale		(g_HDAO_Params1.zw)
#define	g_fHDAORejectRadius		(g_HDAO_Params2.x)
#define	g_fHDAOAcceptRadius		(g_HDAO_Params2.y)
#define	g_fHDAORecipFadeOutDist	(g_HDAO_Params2.z)
#define g_fDepthFallOff			(g_fHDAORejectRadius / 7.0f)
#else
const static float g_fHDAORejectRadius		= 0.8f;	    // Camera Z values must fall within the reject and accept radius to be 
const static float g_fHDAOAcceptRadius		= 0.003f;   // considered as a valley
const static float g_fHDAORecipFadeOutDist	= 1.0f / 0.6f;
const static float g_fHDAOIntensity			= 0.5f;	    // Simple scaling factor to control the intensity of the occlusion
const static float g_fHDAONormalScale		= 0.05f;	// Scaling factor to control the effect the normals have 
const static float g_fDepthFallOff          = g_fHDAORejectRadius / 7.0f; // Used by the bilateral filter to stop bleeding over steps in depth
#endif	//USE_PARAMETERS

#define PI                              ( 3.1415927f )
#define ROT_ANGLE                       ( PI / 180.f )


#if USE_COMPUTE_SHADER
    // ALU Op Defines
    #define ALU_DIM					32

	// Filtering settings (16 or 32)
	#define FILTER_LDS_PRECISION	( 16 )
	// Must be an even number
	#define KERNEL_RADIUS           ( 16 )
	#define GAUSSIAN_DEVIATION      ( KERNEL_RADIUS * 0.5f )
	#define USE_APPROXIMATE_FILTER  ( !(MULTISAMPLE_TECHNIQUES && HDAO2_MULTISAMPLE_FILTER) )

	// Defines that control the CS logic of the kernel 
	#define KERNEL_DIAMETER             ( KERNEL_RADIUS * 2 + 1 )  
	#define KERNEL_DIAMETER_MINUS_ONE	( KERNEL_DIAMETER - 1 )
	#define RUN_SIZE_PLUS_KERNEL	    ( HDAO2_RUN_SIZE + KERNEL_DIAMETER_MINUS_ONE )
	#define PIXELS_PER_THREAD           ( HDAO2_RUN_SIZE / HDAO2_NUM_THREADS )  
	#define SAMPLES_PER_THREAD          ( RUN_SIZE_PLUS_KERNEL / HDAO2_NUM_THREADS )
	#define EXTRA_SAMPLES               ( RUN_SIZE_PLUS_KERNEL - ( HDAO2_NUM_THREADS * SAMPLES_PER_THREAD ) )

    //=============================================================================================================================
    // Group shared memory (LDS)
    //=============================================================================================================================
    
    struct LDS_Compute
    {
        uint    uXY;
        float   fZ;
    };
    
    GROUPSHARED LDS_Compute g_LDS_Compute[HDAO2_GROUP_TEXEL_DIM*HDAO2_GROUP_TEXEL_DIM];

	// Adjusts the sampling step size if using approximate filtering
	#if USE_APPROXIMATE_FILTER
		#define STEP_SIZE ( 2 )
	#else
		#define STEP_SIZE ( 1 )
	#endif

    //=============================================================================================================================
    // Packs a float2 to a unit
    //=============================================================================================================================
    uint Float2ToUint( float2 f2Value )
    {
        uint uRet = 0;
                                  
        uRet = ( f32tof16( f2Value.x ) ) + ( f32tof16( f2Value.y ) << 16 );
        
        return uRet;
    }

    //=============================================================================================================================
    // Unpacks a uint to a float2
    //=============================================================================================================================
    float2 UintToFloat2( uint uValue )
    {
        return float2( f16tof32( uValue ), f16tof32( uValue >> 16 ) );
    }

    //=============================================================================================================================
    // Helper function to load data from the LDS, given texel coord
    // NOTE: X and Y are swapped around to ensure horizonatal reading across threads, this avoids
    // LDS memory bank conflicts
    //=============================================================================================================================
    float3 LoadFromLDS( uint2 u2Texel )
    {
        float2 f2XY = UintToFloat2( g_LDS_Compute[u2Texel.y*HDAO2_GROUP_TEXEL_DIM+u2Texel.x].uXY );
        float fZ = g_LDS_Compute[u2Texel.y*HDAO2_GROUP_TEXEL_DIM+u2Texel.x].fZ;

        return float3( f2XY.x, f2XY.y, fZ );
    }

    //=============================================================================================================================
    // Helper function to store data to the LDS, given texel coord
    // NOTE: X and Y are swapped around to ensure horizonatal wrting across threads, this avoids
    // LDS memory bank conflicts
    //=============================================================================================================================
    void StoreToLDS( float3 f3Position, uint2 u2Texel )
    {
        g_LDS_Compute[u2Texel.y*HDAO2_GROUP_TEXEL_DIM+u2Texel.x].uXY = Float2ToUint( f3Position.xy );
        g_LDS_Compute[u2Texel.y*HDAO2_GROUP_TEXEL_DIM+u2Texel.x].fZ = f3Position.z;
    }
    
#endif	//USE_COMPUTE_SHADER


static const uint	HDAO_NUM_VALLEYS	= 16;

static const float2 g_SamplePattern[HDAO_NUM_VALLEYS] =
{
	{ 0, -9 },
	{ 4, -9 },
	{ 2, -6 },
	{ 6, -6 },
	{ 0, -3 },
	{ 4, -3 },
	{ 8, -3 },
	{ 2, 0 },
	{ 6, 0 },
	{ 10, 0 },
	{ 4, 3 },
	{ 8, 3 },
	{ 2, 6 },
	{ 6, 6 },
	{ 10, 6 },
	{ 4, 9 },
};


float3 GetCameraSpaceXY(float depth, int2 iCoords)
{
	float2 unitPos = iCoords * g_targetSize.zw;
	float2 projPos = (2*unitPos - 1 + g_projShear.xy) * g_projParams.xy;
	return float3(projPos,1) * depth;
}


#if USE_COMPUTE_SHADER
    //=============================================================================================================================
    // HDAO : Performs valley detection in Camera space, and uses the valley angle to scale occlusion. 
    //=============================================================================================================================
    float ComputeHDAO( uint2 u2CenterTexel, uint3 u3DTid, uint step )
    {
	    // Locals
        float3 f3CenterPos;
        float fCenterDistance;
        float3 f3SampledPos[2];
        float fSampledDistance[2];
	    float fOcclusion = 0.0f;
	    float2 f2Diff;
	    float2 f2Compare;
	    float fDot;
        uint uValley;
        float3 f3Dir1;
        float3 f3Dir2;

        // Sample center texel
		f3CenterPos = LoadFromLDS( u2CenterTexel );
        
        // Loop through each valley
        [unroll]
        for( uValley = 0; uValley < HDAO_NUM_VALLEYS; uValley+=step )
		{
            // Optionally _random_ rotate sample pattern
            float2 f2SP;
            #if USE_RANDOM_TAPS
                float fRot = ROT_ANGLE * float( u2CenterTexel.x * u2CenterTexel.y );
                f2SP.x = g_SamplePattern[uValley].x * cos( fRot ) + g_SamplePattern[uValley].y * -sin( fRot );
                f2SP.y = g_SamplePattern[uValley].x * sin( fRot ) + g_SamplePattern[uValley].y * cos( fRot );
            #else
                f2SP = g_SamplePattern[uValley];
            #endif	//USE_RANDOM_TAPS
            f2SP = int2( f2SP * g_fHDAORadiusScale );

			// Sample
			f3SampledPos[0] = LoadFromLDS( u2CenterTexel + f2SP );
        	f3SampledPos[1] = LoadFromLDS( u2CenterTexel - f2SP );
            							
			// Compute distances
			fCenterDistance = sqrt( dot( f3CenterPos, f3CenterPos ) );
			fSampledDistance[0] = sqrt( dot( f3SampledPos[0], f3SampledPos[0] ) );
			fSampledDistance[1] = sqrt( dot( f3SampledPos[1], f3SampledPos[1] ) );
                                
			// Detect valleys 
			f2Diff = fCenterDistance.xx - float2( fSampledDistance[0], fSampledDistance[1] );
			f2Compare = saturate( ( g_fHDAORejectRadius.xx - f2Diff ) * ( g_fHDAORecipFadeOutDist ) );
			f2Compare = ( f2Diff > g_fHDAOAcceptRadius.xx ) ? ( f2Compare ) : ( 0.0f );
									            
            // Compute dot product, to scale occlusion
            f3Dir1 = normalize( f3CenterPos - f3SampledPos[0] );
            f3Dir2 = normalize( f3CenterPos - f3SampledPos[1] );
            fDot = saturate( dot( f3Dir1, f3Dir2 ) + 0.9f ) * 1.2f;
                        
		    // Accumulate weighted occlusion
		    fOcclusion += f2Compare.x * f2Compare.y * fDot * fDot * fDot;
        }
    	
		// Finally calculate the HDAO occlusion value
		fOcclusion /= (HDAO_NUM_VALLEYS/step);
		fOcclusion *= g_fHDAOIntensity;
		fOcclusion = 1.0f - saturate( fOcclusion );
		    	
	    return fOcclusion;
    }

#endif	//USE_COMPUTE_SHADER

#if USE_COMPUTE_SHADER

	void ComputeStore(uint3 Gid, uint GI)
	{
		if( GI >= HDAO2_GATHER_THREADS )
			return;
		// Get the screen position for this threads TEX ops
        uint uColumn = ( GI % HDAO2_GATHER_THREADS_PER_ROW )  * 2;
        uint uRow = ( GI / HDAO2_GATHER_THREADS_PER_ROW ) * 2;
		const int2 base = int2( uColumn, uRow );
        int2 i2ScreenCoord = Gid.xy * ALU_DIM - HDAO2_GROUP_TEXEL_OVERLAP + base;
		const int4x2 offsets = { 0,1, 1,1, 1,0, 0,0 };	//gather offsets
	        		
        // Gather/Load from input textures and lay down in the LDS
		#if USE_GATHER
			float2 f2TexCoord = float2( i2ScreenCoord + 1 ) * g_targetSize.zw;
			float4 fRawDepth = depthTexture.GatherRed( depthSampler, f2TexCoord );
		#else	//USE_GATHER
			float4 fRawDepth = float4(
				depthTexture.Load( int3(i2ScreenCoord + offsets[0],0) ).x,
				depthTexture.Load( int3(i2ScreenCoord + offsets[1],0) ).x,
				depthTexture.Load( int3(i2ScreenCoord + offsets[2],0) ).x,
				depthTexture.Load( int3(i2ScreenCoord + offsets[3],0) ).x
				);
		#endif	//USE_GATHER
        
		float4 f4Depth = getLinearDepth4(fRawDepth,g_projParams.zw);
		float4x3 mPositions = float4x3(
			GetCameraSpaceXY( f4Depth.x, i2ScreenCoord + offsets[0] ),
			GetCameraSpaceXY( f4Depth.y, i2ScreenCoord + offsets[1] ),
			GetCameraSpaceXY( f4Depth.z, i2ScreenCoord + offsets[2] ),
			GetCameraSpaceXY( f4Depth.w, i2ScreenCoord + offsets[3] )
			);

        #if USE_NORMALS
			#if USE_GATHER
				float4x3 mNormals = transpose(float3x4(
					normalTexture.GatherRed(	normalSampler, f2TexCoord ),
					normalTexture.GatherGreen(	normalSampler, f2TexCoord ),
					normalTexture.GatherBlue(	normalSampler, f2TexCoord )
					));
			#else	//USE_GATHER
				float4x3 mNormals = float4x3(
					normalTexture.Load( int3(i2ScreenCoord + offsets[0],0) ).xyz,
					normalTexture.Load( int3(i2ScreenCoord + offsets[1],0) ).xyz,
					normalTexture.Load( int3(i2ScreenCoord + offsets[2],0) ).xyz,
					normalTexture.Load( int3(i2ScreenCoord + offsets[3],0) ).xyz
					);
			#endif	//USE_GATHER
			mPositions += (mNormals*2-1) * g_fHDAONormalScale.x;
        #endif	//USE_NORMALS

        StoreToLDS( mPositions[0], base + offsets[0] );
        StoreToLDS( mPositions[1], base + offsets[1] );
        StoreToLDS( mPositions[2], base + offsets[2] );
        StoreToLDS( mPositions[3], base + offsets[3] );
	}

	//=============================================================================================================================
    // HDAO CS: Loads an overlapping tile of texels from the depth buffer (and optionally the normals buffer). It then converts
    // depth into camera XYZ and optionally offsets by the camera space normal XYZ.
    //=============================================================================================================================
	void ComputeHelp( uint3 Gid, uint3 GTid, uint GI, uint3 u3DTid, uint step )
	{
		ComputeStore(Gid,GI);
    	    
        // Enforce a group barrier with sync
		GroupMemoryBarrierWithGroupSync();
    	
        // Calculate the screen pos
        uint2 u2ScreenPos = Gid.xy * ALU_DIM + GTid.xy;
            		
        // Make sure we don't write outside the target buffer
        if( ( (float)u2ScreenPos.x < g_targetSize.x ) && ( (float)u2ScreenPos.y < g_targetSize.y ) )
        {
            // Write the data directly to an AO texture:
            float fHDAO = ComputeHDAO( GTid.xy + HDAO2_GROUP_TEXEL_OVERLAP, u3DTid, step );
            g_ResultTexture[u2ScreenPos.xy] = fHDAO;
        }
	}
    
#define HDAO2_COMPUTE(quality,step)	\
    [numthreads( HDAO2_GROUP_THREAD_DIM, HDAO2_GROUP_THREAD_DIM, 1 )]	\
	void CS_HDAO_##quality( uint3 Gid : SV_GroupID, uint3 GTid : SV_GroupThreadID, uint GI : SV_GroupIndex, uint3 u3DTid : SV_DispatchThreadID )	\
    { ComputeHelp(Gid,GTid,GI,u3DTid,step); }

	HDAO2_COMPUTE(High,1)
	HDAO2_COMPUTE(Medium,2)
	HDAO2_COMPUTE(Low,4)
#endif	//USE_COMPUTE_SHADER


// Uncompressed data as sampled from inputs
struct RAWDataItem
{
	MSAA_FLOAT	fHDAO;
	MSAA_FLOAT	fDepth;
};

// Data stored for the kernel
struct KernelData
{
	MSAA_FLOAT	fWeight;
	MSAA_FLOAT	fWeightSum;
	MSAA_FLOAT	fCenterHDAO;
	MSAA_FLOAT	fCenterDepth;
};

#if USE_COMPUTE_SHADER
	#if FILTER_LDS_PRECISION == 32
		struct LDS_Filter
		{
			MSAA_FLOAT fHDAO;
			MSAA_FLOAT fDepth;
		};
		#define WRITE_TO_LDS( _RAWDataItem, _iLineOffset, _iPixelOffset ) \
			g_LDS_Filter[_iLineOffset*RUN_SIZE_PLUS_KERNEL+_iPixelOffset].fHDAO		= _RAWDataItem.fHDAO; \
			g_LDS_Filter[_iLineOffset*RUN_SIZE_PLUS_KERNEL+_iPixelOffset].fDepth	= _RAWDataItem.fDepth;
            
		#define READ_FROM_LDS( _iLineOffset, _iPixelOffset, _RAWDataItem ) \
			_RAWDataItem.fHDAO	= g_LDS_Filter[_iLineOffset*RUN_SIZE_PLUS_KERNEL+_iPixelOffset].fHDAO; \
			_RAWDataItem.fDepth	= g_LDS_Filter[_iLineOffset*RUN_SIZE_PLUS_KERNEL+_iPixelOffset].fDepth;
	#elif FILTER_LDS_PRECISION == 16
		#if MULTISAMPLE_TECHNIQUES && HDAO2_MULTISAMPLE_FILTER
		struct LDS_Filter
		{
			uint4	uBoth;
		};
		#define WRITE_TO_LDS( _RAWDataItem, _iLineOffset, _iPixelOffset ) \
			g_LDS_Filter[_iLineOffset*RUN_SIZE_PLUS_KERNEL+_iPixelOffset].uBoth = f32tof16(_RAWDataItem.fHDAO) + (f32tof16(_RAWDataItem.fDepth)<<16);
		#define READ_FROM_LDS( _iLineOffset, _iPixelOffset, _RAWDataItem ) \
			uint4 both = g_LDS_Filter[_iLineOffset*RUN_SIZE_PLUS_KERNEL+_iPixelOffset].uBoth; \
			_RAWDataItem.fHDAO	= f16tof32(both); \
			_RAWDataItem.fDepth	= f16tof32(both>>16);
		#else	//MULTISAMPLE_TECHNIQUES
		struct LDS_Filter
		{
			uint	uBoth;
		};
		#define WRITE_TO_LDS( _RAWDataItem, _iLineOffset, _iPixelOffset ) \
			g_LDS_Filter[_iLineOffset*RUN_SIZE_PLUS_KERNEL+_iPixelOffset].uBoth = Float2ToUint( float2( _RAWDataItem.fHDAO, _RAWDataItem.fDepth ) );
		#define READ_FROM_LDS( _iLineOffset, _iPixelOffset, _RAWDataItem ) \
			float2 f2A = UintToFloat2( g_LDS_Filter[_iLineOffset*RUN_SIZE_PLUS_KERNEL+_iPixelOffset].uBoth ); \
			_RAWDataItem.fHDAO = f2A.x; \
			_RAWDataItem.fDepth = f2A.y;
		#endif	//MULTISAMPLE_TECHNIQUES
	#endif	//FILTER_LDS_PRECISION
	
	GROUPSHARED LDS_Filter g_LDS_Filter[HDAO2_RUN_LINES*RUN_SIZE_PLUS_KERNEL];
#endif	//USE_COMPUTE_SHADER

//--------------------------------------------------------------------------------------
// Samples from inputs defined by the SampleFromInput macro
//--------------------------------------------------------------------------------------
RAWDataItem Sample( int2 i2Position, float2 f2Offset )
{
    float2 f2SamplePosition = float2( i2Position ) + float2( 0.5f, 0.5f );
    #if USE_APPROXIMATE_FILTER
        f2SamplePosition += f2Offset;
    #endif
  
	RAWDataItem RDI;
	f2SamplePosition *= g_targetSize.zw;

	#if MULTISAMPLE_TECHNIQUES && HDAO2_MULTISAMPLE_FILTER
		uint uStep = gMSAANumSamples > 4 ? (uint)gMSAANumSamples/4 : 1;
		float4 rawDepth = float4(0,0,0,0);
		#if !RSG_ORBIS
			[unroll(4)]
		#endif
		for(int uSample=0,uIndex=0; uSample<gMSAANumSamples; uSample+=uStep,++uIndex )
		{
			rawDepth[uIndex] = depthOrigTexture.Load( i2Position, uSample ).x;
		}
		RDI.fDepth = getLinearDepth4( fixupGBufferDepth(rawDepth), g_projParams.zw );
	#else
		float rawDepth	= depthTexture.SampleLevel( depthSampler, f2SamplePosition, 0 ).x;
		RDI.fDepth = getLinearDepth( fixupGBufferDepth(rawDepth), g_projParams.zw );
	#endif	//MULTISAMPLE_TECHNIQUES

	RDI.fHDAO = occlusionTexture.SampleLevel( occlusionSampler, f2SamplePosition, 0 );
	
    return RDI;
}

#if USE_COMPUTE_SHADER
	//--------------------------------------------------------------------------------------
	// Get a Gaussian weight
	//--------------------------------------------------------------------------------------
	#define GAUSSIAN_WEIGHT( _fX, _fDeviation, _fWeight ) \
		_fWeight = 1.0f / sqrt( 2.0f * PI * _fDeviation * _fDeviation ); \
		_fWeight *= exp( -( _fX * _fX ) / ( 2.0f * _fDeviation * _fDeviation ) ); 
	   
	//--------------------------------------------------------------------------------------
	// Compute what happens at the kernels center 
	//--------------------------------------------------------------------------------------
	#define KERNEL_CENTER( _KernelData, _iPixel, _iNumPixels, _O, _RAWDataItem ) \
		[unroll] for( _iPixel = 0; _iPixel < _iNumPixels; ++_iPixel ) { \
			_KernelData[_iPixel].fCenterHDAO = _RAWDataItem[_iPixel].fHDAO; \
			_KernelData[_iPixel].fCenterDepth = _RAWDataItem[_iPixel].fDepth; \
			GAUSSIAN_WEIGHT( 0, GAUSSIAN_DEVIATION, _KernelData[_iPixel].fWeight ) \
			_KernelData[_iPixel].fWeightSum = _KernelData[_iPixel].fWeight; \
			_O.fColor[_iPixel] = _KernelData[_iPixel].fCenterHDAO * _KernelData[_iPixel].fWeight; }     


	//--------------------------------------------------------------------------------------
	// Compute what happens for each iteration of the kernel 
	//--------------------------------------------------------------------------------------
	#define KERNEL_ITERATION( _iIteration, _KernelData, _iPixel, _iNumPixels, _O, _RAWDataItem ) \
		[unroll] for( _iPixel = 0; _iPixel < _iNumPixels; ++_iPixel ) { \
			GAUSSIAN_WEIGHT( ( _iIteration - KERNEL_RADIUS + ( 1.0f - 1.0f / float( STEP_SIZE ) ) ), GAUSSIAN_DEVIATION, _KernelData[_iPixel].fWeight ) \
			_KernelData[_iPixel].fWeight *= step( abs( _RAWDataItem[_iPixel].fDepth - _KernelData[_iPixel].fCenterDepth ), g_fDepthFallOff ); \
			_O.fColor[_iPixel] += _RAWDataItem[_iPixel].fHDAO * _KernelData[_iPixel].fWeight; \
			_KernelData[_iPixel].fWeightSum += _KernelData[_iPixel].fWeight; }
	      

	//--------------------------------------------------------------------------------------
	// Perform final weighting operation 
	//--------------------------------------------------------------------------------------
	//#define KERNEL_FINAL_WEIGHT( _KernelData, _iPixel, _iNumPixels, _O ) \
		[unroll] for( _iPixel = 0; _iPixel < _iNumPixels; ++_iPixel ) { \
			_O.fColor[_iPixel] = ( _KernelData[_iPixel].fWeightSum > 0.00001f ) ? ( _O.fColor[_iPixel] / _KernelData[_iPixel].fWeightSum ) : ( _KernelData[_iPixel].fCenterHDAO ); }              
	#define KERNEL_FINAL_WEIGHT( _KernelData, _iPixel, _iNumPixels, _O ) \
		[unroll] for( _iPixel = 0; _iPixel < _iNumPixels; ++_iPixel ) { \
			_O.fColor[_iPixel] = lerp( _KernelData[_iPixel].fCenterHDAO,  _O.fColor[_iPixel] / _KernelData[_iPixel].fWeightSum, step(0.00001f,_KernelData[_iPixel].fWeightSum) ); }              
	        

	//--------------------------------------------------------------------------------------
	// Output to chosen UAV 
	//--------------------------------------------------------------------------------------
	#define KERNEL_OUTPUT( _i2Center, _i2Inc, _iPixel, _iNumPixels, _O, _KernelData ) \
		[unroll] for( _iPixel = 0; _iPixel < _iNumPixels; ++_iPixel ) \
		  g_ResultTexture[_i2Center + _iPixel * _i2Inc] = _O.fColor[_iPixel];


    //--------------------------------------------------------------------------------------
    // Macro for caching LDS reads, this has the effect of drastically reducing reads from the 
    // LDS by up to 4x
    //--------------------------------------------------------------------------------------
    #define CACHE_LDS_READS( _iIteration, _iLineOffset, _iPixelOffset, _RDI ) \
        /* Trickle LDS values down within the GPRs*/ \
        [unroll] for( iPixel = 0; iPixel < PIXELS_PER_THREAD - STEP_SIZE; ++iPixel ) { \
            _RDI[iPixel] = _RDI[iPixel + STEP_SIZE]; } \
        /* Load new LDS value(s) */ \
        [unroll] for( iPixel = 0; iPixel < STEP_SIZE; ++iPixel ) { \
            READ_FROM_LDS( _iLineOffset, ( _iPixelOffset + _iIteration + iPixel ), _RDI[(PIXELS_PER_THREAD - STEP_SIZE + iPixel)] ) }


	// CS output structure
	struct CS_Output
	{
		MSAA_FLOAT	fColor[PIXELS_PER_THREAD]; 
	};

	//--------------------------------------------------------------------------------------
    // Defines the filter kernel logic. User supplies macro's for custom filter
    //--------------------------------------------------------------------------------------
    void ComputeFilterKernel( int iPixelOffset, int iLineOffset, int2 i2Center, int2 i2Inc )
    {
        CS_Output O = (CS_Output)0;
        KernelData KD[PIXELS_PER_THREAD];
        int iPixel, iIteration;
        RAWDataItem RDI[PIXELS_PER_THREAD];
       
		#if USE_APPROXIMATE_FILTER
            // Read the kernel center values in directly from the input surface(s), as the LDS
            // values are pre-filtered, and therefore do not represent the kernel center
            [unroll] 
            for( iPixel = 0; iPixel < PIXELS_PER_THREAD; ++iPixel )  
            {
				int2 iCoords = i2Center + iPixel * i2Inc;
				RDI[iPixel] = Sample( iCoords, float2(0,0) );
            }
        #else
            // Read the kernel center values in from the LDS
            [unroll] 
            for( iPixel = 0; iPixel < PIXELS_PER_THREAD; ++iPixel ) 
            {
                READ_FROM_LDS( iLineOffset, ( iPixelOffset + KERNEL_RADIUS + iPixel ), RDI[iPixel] )
            }
        #endif	//USE_APPROXIMATE_FILTER

        // Macro defines what happens at the kernel center
        KERNEL_CENTER( KD, iPixel, PIXELS_PER_THREAD, O, RDI )
            
        // Prime the GPRs for the first half of the kernel
        [unroll]
        for( iPixel = 0; iPixel < PIXELS_PER_THREAD; ++iPixel )
        {
            READ_FROM_LDS( iLineOffset, ( iPixelOffset + iPixel ), RDI[iPixel] )
        }

        // Increment the LDS offset by PIXELS_PER_THREAD
        iPixelOffset += PIXELS_PER_THREAD;

        // First half of the kernel
        [unroll]
        for( iIteration = 0; iIteration < KERNEL_RADIUS; iIteration += STEP_SIZE )
        {
            // Macro defines what happens for each kernel iteration  
            KERNEL_ITERATION( iIteration, KD, iPixel, PIXELS_PER_THREAD, O, RDI )

            // Macro to cache LDS reads in GPRs
            CACHE_LDS_READS( iIteration, iLineOffset, iPixelOffset, RDI ) 
        }

        // Prime the GPRs for the second half of the kernel
        [unroll]
        for( iPixel = 0; iPixel < PIXELS_PER_THREAD; ++iPixel )
        {
            READ_FROM_LDS( iLineOffset, ( iPixelOffset - PIXELS_PER_THREAD + iIteration + 1 + iPixel ), RDI[iPixel] )
        }
        
        // Second half of the kernel
        [unroll]
        for( iIteration = KERNEL_RADIUS + 1; iIteration < KERNEL_DIAMETER; iIteration += STEP_SIZE )
        {
            // Macro defines what happens for each kernel iteration  
            KERNEL_ITERATION( iIteration, KD, iPixel, PIXELS_PER_THREAD, O, RDI )

            // Macro to cache LDS reads in GPRs
            CACHE_LDS_READS( iIteration, iLineOffset, iPixelOffset, RDI )
        }
        
        // Macros define final weighting and output 
        KERNEL_FINAL_WEIGHT( KD, iPixel, PIXELS_PER_THREAD, O )
        KERNEL_OUTPUT( i2Center, i2Inc, iPixel, PIXELS_PER_THREAD, O, KD )
    }

	//--------------------------------------------------------------------------------------
    // Compute shader implementing the horizontal pass of a separable filter
    //--------------------------------------------------------------------------------------    
	[numthreads( HDAO2_NUM_THREADS, HDAO2_RUN_LINES, 1 )]
	void CSFilterX( uint3 Gid : SV_GroupID, uint3 GTid : SV_GroupThreadID )
    {
        // Sampling and line offsets from group thread IDs
        int iSampleOffset = GTid.x * SAMPLES_PER_THREAD;
        int iLineOffset = GTid.y;
                
        // Group and pixel coords from group IDs
        int2 i2GroupCoord = int2( ( Gid.x * HDAO2_RUN_SIZE ) - KERNEL_RADIUS, ( Gid.y * HDAO2_RUN_LINES ) );
        int2 i2Coord = int2( i2GroupCoord.x + iSampleOffset, i2GroupCoord.y );

		// Sample and store to LDS
		[unroll]
		for( int i = 0; i < SAMPLES_PER_THREAD; ++i )
		{
			WRITE_TO_LDS( Sample( i2Coord + int2( i, GTid.y ), float2( 0.5f, 0.0f ) ), iLineOffset, iSampleOffset + i )
		}

		// Optionally load some extra texels as required by the exact kernel size
		if( GTid.x < EXTRA_SAMPLES )
		{
			WRITE_TO_LDS( Sample( i2GroupCoord + int2( RUN_SIZE_PLUS_KERNEL - 1 - GTid.x, GTid.y ), float2( 0.5f, 0.0f ) ), iLineOffset, RUN_SIZE_PLUS_KERNEL - 1 - GTid.x )
		}
           	
		// Sync threads
		GroupMemoryBarrierWithGroupSync();

		// Adjust pixel offset for computing at PIXELS_PER_THREAD
		int iPixelOffset = GTid.x * PIXELS_PER_THREAD;
		i2Coord = int2( i2GroupCoord.x + iPixelOffset, i2GroupCoord.y );

		// Since we start with the first thread position, we need to increment the coord by KERNEL_RADIUS 
		i2Coord.x += KERNEL_RADIUS;

		// Ensure we don't compute pixels off screen
		if( i2Coord.x < g_targetSize.x )
		{
			int2 i2Center = i2Coord + int2( 0, GTid.y );
			int2 i2Inc = int2( 1, 0 );
            
			// Compute the filter kernel using LDS values
			ComputeFilterKernel( iPixelOffset, iLineOffset, i2Center, i2Inc );
		}
    }

    //--------------------------------------------------------------------------------------
    // Compute shader implementing the vertical pass of a separable filter
    //--------------------------------------------------------------------------------------
	[numthreads( HDAO2_NUM_THREADS, HDAO2_RUN_LINES, 1 )]
    void CSFilterY( uint3 Gid : SV_GroupID, uint3 GTid : SV_GroupThreadID )
    {
        // Sampling and line offsets from group thread IDs
        int iSampleOffset = GTid.x * SAMPLES_PER_THREAD;
        int iLineOffset = GTid.y;
        
        // Group and pixel coords from group IDs
        int2 i2GroupCoord = int2( ( Gid.x * HDAO2_RUN_LINES ), ( Gid.y * HDAO2_RUN_SIZE ) - KERNEL_RADIUS );
        int2 i2Coord = int2( i2GroupCoord.x, i2GroupCoord.y + iSampleOffset );

		// Sample and store to LDS
		[unroll]
		for( int i = 0; i < SAMPLES_PER_THREAD; ++i )
		{
			WRITE_TO_LDS( Sample( i2Coord + int2( GTid.y, i ), float2( 0.0f, 0.5f ) ), iLineOffset, iSampleOffset + i )
		}
                       
		// Optionally load some extra texels as required by the exact kernel size 
		if( GTid.x < EXTRA_SAMPLES )
		{
			WRITE_TO_LDS( Sample( i2GroupCoord + int2( GTid.y, RUN_SIZE_PLUS_KERNEL - 1 - GTid.x ), float2( 0.0f, 0.5f ) ), iLineOffset, RUN_SIZE_PLUS_KERNEL - 1 - GTid.x )
		}
        
		// Sync threads
		GroupMemoryBarrierWithGroupSync();

		// Adjust pixel offset for computing at PIXELS_PER_THREAD
		int iPixelOffset = GTid.x * PIXELS_PER_THREAD;
		i2Coord = int2( i2GroupCoord.x, i2GroupCoord.y + iPixelOffset );

		// Since we start with the first thread position, we need to increment the coord by KERNEL_RADIUS 
		i2Coord.y += KERNEL_RADIUS;

		// Ensure we don't compute pixels off screen
		if( i2Coord.y < g_targetSize.y  )
		{
			int2 i2Center = i2Coord + int2( GTid.y, 0 );
			int2 i2Inc = int2( 0, 1 );
            
			// Compute the filter kernel using LDS values
			ComputeFilterKernel( iPixelOffset, iLineOffset, i2Center, i2Inc );
		}
    }
#endif	//USE_COMPUTE_SHADER

//=================================================================================================================================
// Pixel shader input/output structures
//=================================================================================================================================

struct PS_RenderQuadInput
{
    float4 f4Position : SV_Position; 
    float2 f2TexCoord : TEXCOORD0;
};

struct PS_RenderQuadInput_Sample
{
    float4	f4Position	: SV_Position; 
    float2	f2TexCoord	: TEXCOORD0;
	uint	uSampleIndex: SV_SampleIndex;
};


struct PS_RenderOutput
{
	float4	f4Normal	: SV_Target0;
#if SSAO_OUTPUT_DEPTH
	float	fDepth      : SV_Depth;
#else
	float	fDepth      : SV_Target1;
#endif	//SSAO_OUTPUT_DEPTH
};

//=================================================================================================================================
// This pixel shader implements a down sample of the depth and normal surfaces
//=================================================================================================================================

PS_RenderQuadInput VS_Quad( float2 Position : POSITION )
{
	PS_RenderQuadInput O;

	O.f4Position = float4(Position * 2 - 1, 0, 1);
	O.f2TexCoord = float2(Position.x, 1-Position.y);

	return O;
}

PS_RenderOutput PS_DownSampleSceneDepthNormal( PS_RenderQuadInput I )
{
    PS_RenderOutput O;

	O.fDepth	= fixupGBufferDepth(depthTexture	.SampleLevel( depthSampler,	I.f2TexCoord, 0 ).x);
	O.f4Normal	= normalTexture	.SampleLevel( normalSampler,I.f2TexCoord, 0 ).xyzw;

    return O;
}

float4 PS_Apply( PS_RenderQuadInput I ) : SV_Target0
{
    return occlusionTexture.SampleLevel( occlusionSampler,	I.f2TexCoord, 0 );
}

float4 PS_Apply_Dark( PS_RenderQuadInput I ) : SV_Target0
{
	float4 AO = occlusionTexture.GatherRed( occlusionSampler,	I.f2TexCoord );
	const float bias = 0.001;
    return 1.0 / dot(0.25,1/(AO+bias)) - bias;
}

#if MULTISAMPLE_TECHNIQUES
float4 PS_Apply_MSAA( PS_RenderQuadInput_Sample I ) : SV_Target0
{	
	float2 offPixelCenter = depthOrigTexture.GetSamplePosition( I.uSampleIndex );
	float2 tc = I.f2TexCoord + offPixelCenter * g_DepthTexParams.zw;
	return occlusionTexture.SampleLevel( occlusionSampler,	tc, 0 );
}
float4 PS_Apply2_MSAA( PS_RenderQuadInput_Sample I ) : SV_Target0
{
	const float2 texCoordsNear = I.f2TexCoord;
	const float fDepthAvg = depthTexture.SampleLevel( depthSampler, texCoordsNear, 0 ).x;
//	const float fDepthCur = depthOrigTexture.Load( int2(I.f4TexCoord.xy), I.uSampleIndex ).x; // don't use SV_Position in pixel shaders
	const float fDepthCur = fixupGBufferDepth(depthOrigTexture.Load( int2(I.f2TexCoord.xy*g_DepthTexParams.xy), I.uSampleIndex ).x);
	float2 offPixelCenter = depthOrigTexture.GetSamplePosition( I.uSampleIndex );
	float2 texCoordsFar = I.f2TexCoord + 2*offPixelCenter * g_DepthTexParams.zw;
	const float fDepthFar = depthTexture.SampleLevel( depthSampler, texCoordsFar, 0 ).x;
	float2 tc;
	if (abs(fDepthFar-fDepthCur) < abs(fDepthAvg-fDepthCur))
	{
		tc = texCoordsFar;
	}else
	{
		tc = texCoordsNear;
	}
	return occlusionTexture.SampleLevel( occlusionSampler,	tc, 0 );
}
float4 PS_Apply3_MSAA( PS_RenderQuadInput_Sample I ) : SV_Target0
{
	float4 val = occlusionTexture.SampleLevel( occlusionSampler, I.f2TexCoord, 0 );
	const uint uStep = gMSAANumSamples>4 ? (uint)gMSAANumSamples/4 : 1;
	return val[ I.uSampleIndex / uStep ];
}
#endif	//MULTISAMPLE_TECHNIQUES

#if __PSSL
	#define HDAO_VS	vs_5_0
	#define HDAO_PS	ps_5_0
#else
	#define HDAO_VS	vs_4_1
	#define HDAO_PS	ps_4_1
#endif	//__PSSL

technique11 HDAO
{
	pass hdao_downsample
	{
		SetVertexShader(	compileshader( HDAO_VS, VS_Quad() ));
		SetPixelShader(		compileShader( HDAO_PS, PS_DownSampleSceneDepthNormal() ));
	}

	pass hdao_compute_high_sm50
	{
		SetComputeShader(	compileshader( cs_5_0, CS_HDAO_High() ));
	}
	pass hdao_compute_medium_sm50
	{
		SetComputeShader(	compileshader( cs_5_0, CS_HDAO_Medium() ));
	}
	pass hdao_compute_low_sm50
	{
		SetComputeShader(	compileshader( cs_5_0, CS_HDAO_Low() ));
	}

	pass hdao_filterX_sm50
	{
		SetComputeShader(	compileshader( cs_5_0, CSFilterX() ));
	}

	pass hdao_filterY_sm50
	{
		SetComputeShader(	compileshader( cs_5_0, CSFilterY() ));
	}

#if MULTISAMPLE_TECHNIQUES
	pass hdao_apply_sm41
	{
		SetVertexShader(	compileshader( HDAO_VS, VS_Quad() ));
		SetPixelShader(		compileShader( HDAO_PS, PS_Apply3_MSAA() ));
	}
#else
	pass hdao_apply
	{
		SetVertexShader(	compileshader( HDAO_VS, VS_Quad() ));
		SetPixelShader(		compileShader( HDAO_PS, PS_Apply() ));
	}
#endif	//MULTISAMPLE_TECHNIQUES
	pass hdao_apply_dark
	{
		SetVertexShader(	compileshader( HDAO_VS, VS_Quad() ));
		SetPixelShader(		compileShader( ps_5_0, PS_Apply_Dark() ));
	}
}

#else
technique dummy{ pass dummy	{} }
#endif	//__SHADERMODEL
