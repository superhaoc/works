#if !defined(LTYPE)
#error "Need to have LTYPE defined before including"
#endif

#define USE_CM_SHADOW_VOLUME_REJECT  // until we have stencil working

#include "../light_common.fxh"

// ----------------------------------------------------------------------------------------------- //

float4 calculateCaustics(surfaceProperties surface)
{
    // project to water surface
    float t = -(deferredLightWaterHeight + surface.position.z)/surface.lightDir.z;
    float3 waterSurfacePos = surface.position + surface.lightDir * t;

    // use projected position to sample caustic texture
    float4 caustTex = waterSurfacePos.xyyx * float4(1.0f, 1.0f, 0.74546f, 0.74546f);
    float4 texCoords = caustTex + float4(1,1,-1,-1)*deferredLightWaterTime*15;
    float3 causticIntensity = tex2D(gDeferredLightSampler1, texCoords.xy).rgb*tex2D(gDeferredLightSampler1, texCoords.zw).rgb*10.0f;

    // fading params - caustic effect intensity in x, depth attenuation in y
    const float fadeOutDist = 25.0f;
    float2 alpha = float2( 2.0f *(deferredLightWaterHeight-surface.position.z), (fadeOutDist - t) / fadeOutDist);
    alpha = saturate(alpha);

    return float4(causticIntensity.rgb * alpha.y, alpha.x);
}

half4 JOIN(deferred_,LTYPE)(lightPixelInput IN, 
							lightProperties light,
							bool useShadow, bool useFiller, 
						    bool useInterior, bool useExterior, bool useCaustic, bool useTexture, bool useVehicleTwin, bool softShadow)
{
#if MULTISAMPLE_EMULATE_INTERPOLATOR
	adjustPixelInputForSample(gbufferTextureDepthGlobal, 0, IN.screenPos.xyw);
#endif
	float2 screenPos = IN.screenPos.xy / IN.screenPos.w;
	float3 shadowTexCoords = 0;
	bool invalidPixel = false;

	float4 eyeRay = IN.eyeRay;

	/*
	When doing shadows we need extra precision for the world pos reconstruction, so we use vpos directly. The interpolated values are just not good enough
	NG: Interpolated view vector seems ok on Xbone and PS4 but breaks down PC in the V prologue area strobe lights, at least on my GTS 450.
	inside_sample/centroid does not seem to work on SV_Position but deriving view from interpolated screenpos seems to work pretty well on PC, 
	using that on all plats for now. See B* 1731676
	*/
	if (useShadow)
	{
		float2 screenRay = screenPos*float2(2,-2) + float2(-1,1);
		//float2 screenRay = IN.pos.xy*deferredLightScreenSize.zw*float2(2,-2) + float2(-1,1);
		float3 StereorizedCamera = 0;
		float depth = UnPackGBufferDepth( screenPos, SAMPLE_INDEX );
#ifdef NVSTEREO
		float fStereoScalar = StereoToMonoScalar(depth);
		fStereoScalar *= deferredProjectionParams.x;
		StereorizedCamera = gViewInverse[0].xyz * fStereoScalar * -1.0f;
		float4 t_eyeRay = GetEyeRay(screenRay);
		// shadow tex coords are just the rays from the eye to the camera local point now.
		shadowTexCoords = StereorizedCamera + t_eyeRay.xyz * depth;
#else
		eyeRay = GetEyeRay(screenRay);
		// shadow tex coords are just the rays from the eye to the camera local point now.
		shadowTexCoords = StereorizedCamera + eyeRay.xyz * depth;
#endif

	}

	DeferredSurfaceInfo surfaceInfo = UnPackGBuffer_S(screenPos, eyeRay, true, SAMPLE_INDEX);
	
	// Material properties
	materialProperties material = populateMaterialPropertiesDeferred(surfaceInfo); // Setup all the material properties
	
	// Surface properties

	// Setup all the view properties
	half4 OUT = float4(0,0,0,1);

#ifdef LTYPE_IS_SPOT // useVehicleTwin is only supported for spot lights
	if(useVehicleTwin)
	{
		lightProperties light1 = light;
		lightProperties light2 = light;
		light1.position = light.vehicleHeadTwinPos1;
		light2.position = light.vehicleHeadTwinPos2;

		light1.direction = light.vehicleHeadTwinDir1;
		light2.direction = light.vehicleHeadTwinDir2;

		//surfaceToLightDir1 = normalize(light.vehicleHeadTwinPos1 - surface.position);
		//surfaceToLightDir2 = normalize(light.vehicleHeadTwinPos2 - surface.position);
		
		float3 surfaceToLight1 = (light1.position - surfaceInfo.positionWorld);
		float distSq1 = dot(surfaceToLight1, surfaceToLight1);
		float3 surfaceToLightDir1 = surfaceToLight1 * rsqrt(distSq1);
		surfaceProperties surface1 = populateSurfaceProperties(
			surfaceInfo,
			surfaceToLightDir1,
			distSq1); // Setup all the surface properties

		float3 surfaceToLight2 = (light2.position - surfaceInfo.positionWorld);
		float distSq2 = dot(surfaceToLight2, surfaceToLight2);
		float3 surfaceToLightDir2 = surfaceToLight2 * rsqrt(distSq2);
		surfaceProperties surface2 = populateSurfaceProperties(
			surfaceInfo,
			surfaceToLightDir2,
			distSq2); // Setup all the surface properties

		float lightAttenuation1 = JOIN(LTYPE,CalcAttenuation)(
			surface1.lightDir,
			surface1.sqrDistToLight,
			light1.direction,
			light1.invSqrRadius,
			light1.spotOffset,
			light1.spotScale,
			light1.falloffExponent,
			surface1.position,
			light1.cullingPlane);

		float lightAttenuation2 = JOIN(LTYPE,CalcAttenuation)(
			surface2.lightDir,
			surface2.sqrDistToLight,
			light2.direction,
			light2.invSqrRadius,
			light2.spotOffset,
			light2.spotScale,
			light2.falloffExponent,
			surface2.position,
			light2.cullingPlane);

		rageDiscard( max(lightAttenuation1,lightAttenuation2) < LIGHT_ATTEN_THRESHOLD );
		
		// Calculate the lighting contribution
		LightingResult res1 = JOIN(LTYPE,CalculateDeferredLighting)(
			surface1
			, material
			, light1
			, useShadow
			, useFiller
			, useInterior
			, useExterior
			, useTexture
			, shadowTexCoords
			, screenPos
			, softShadow
			, false
			, true
			, lightAttenuation1
			);

		LightingResult res2 = JOIN(LTYPE,CalculateDeferredLighting)(
			surface2
			, material
			, light2
			, useShadow
			, useFiller
			, useInterior
			, useExterior
			, useTexture
			, shadowTexCoords
			, screenPos
			, softShadow
			, false
			, true
			, lightAttenuation2
			);

		Components components_NOT_USED;
		float3 lightDiffuse1 = 0.0f;
		float3 lightDiffuse2 = 0.0f;
		float3 lightSpecular1 = 0.0f;
		float3 lightSpecular2 = 0.0f;

		GetLightValues(res1, true, !useFiller, false, components_NOT_USED, lightDiffuse1, lightSpecular1);
		GetLightValues(res2, true, !useFiller, false, components_NOT_USED, lightDiffuse2, lightSpecular2);

		if (useCaustic)
		{
			float4 causticIntensity1 = calculateCaustics(surface1);
			float4 causticIntensity2 = calculateCaustics(surface2);
			lightSpecular1 = lerp(lightSpecular1, lightSpecular1 * causticIntensity1.rgb, causticIntensity1.a);
			lightSpecular2 = lerp(lightSpecular2, lightSpecular2 * causticIntensity2.rgb, causticIntensity2.a);
			lightDiffuse1  = lerp(lightDiffuse1,  lightDiffuse1  * causticIntensity1.rgb, causticIntensity1.a);
			lightDiffuse2  = lerp(lightDiffuse2,  lightDiffuse2  * causticIntensity2.rgb, causticIntensity2.a);
		}

		lightSpecular1 *= light1.specularFade;
		lightSpecular2 *= light2.specularFade;
		res1.shadowAmount = lerp(1.0f, res1.shadowAmount, light1.shadowFade);
		res2.shadowAmount = lerp(1.0f, res2.shadowAmount, light2.shadowFade);

		half4 OUT1 = ApplyLightToBRDF(lightDiffuse1, lightSpecular1, res1.material.diffuseColor, true, !useFiller);
		OUT1.rgb = OUT1.rgb * res1.lightColor * res1.lightAttenuation * res1.shadowAmount;
		half4 OUT2 = ApplyLightToBRDF(lightDiffuse2, lightSpecular2, res2.material.diffuseColor, true, !useFiller);
		OUT2.rgb = OUT2.rgb * res2.lightColor * res2.lightAttenuation * res2.shadowAmount;

		OUT.rgb = OUT1.rgb + OUT2.rgb;
		OUT.a = OUT1.a;
	}
	else
#endif // LTYPE_IS_SPOT
	{
		float3 surfaceToLight = (light.position - surfaceInfo.positionWorld);
		float distSq = dot(surfaceToLight, surfaceToLight);
		float3 surfaceToLightDir = surfaceToLight * rsqrt(distSq);
		surfaceProperties surface = populateSurfaceProperties(
			surfaceInfo,
			surfaceToLightDir,
			distSq); // Setup all the surface properties


		// Calculate the lighting contribution
		LightingResult res;
		res = JOIN(LTYPE,CalculateDeferredLighting)(
			surface
			, material
			, light
			, useShadow
			, useFiller
			, useInterior
			, useExterior
			, useTexture
			, shadowTexCoords
			, screenPos
			, softShadow
			, true
			, false
			, 0.0
			);

			Components components_NOT_USED;
			float3 lightDiffuse = 0.0f;
			float3 lightSpecular = 0.0f;

			GetLightValues(res, true, !useFiller, false, components_NOT_USED, lightDiffuse, lightSpecular);

			if (useCaustic)
			{
				float4 causticIntensity = calculateCaustics(surface);
				lightSpecular = lerp(lightSpecular, lightSpecular * causticIntensity.rgb, causticIntensity.a);
				lightDiffuse  = lerp(lightDiffuse,  lightDiffuse  * causticIntensity.rgb, causticIntensity.a);
			}

			lightSpecular *= light.specularFade;
			res.shadowAmount = lerp(1.0f, res.shadowAmount, light.shadowFade);

			OUT = ApplyLightToBRDF(lightDiffuse, lightSpecular, res.material.diffuseColor, true, !useFiller);
			OUT.rgb = OUT.rgb * res.lightColor * res.lightAttenuation * res.shadowAmount;
	}

	return PackHdr(OUT);
}

// ----------------------------------------------------------------------------------------------- //

lightVertexOutput JOIN(VS_,LTYPE)(lightVertexInput IN, lightProperties light, bool useShadow, bool useTexture)
{
	lightVertexOutput OUT;

	float3 vpos = JOIN(pos_,LTYPE)(IN.pos.xyz, light, useShadow, useTexture, false);

    OUT.pos	= mul(float4(vpos, 1), gWorldViewProj);
	OUT.screenPos = convertToVpos(MonoToStereoClipSpace(OUT.pos), deferredLightScreenSize);
	OUT.eyeRay = float4(vpos - (gViewInverse[3].xyz+StereoWorldCamOffSet()), OUT.pos.w);

	return(OUT); 
}

// ----------------------------------------------------------------------------------------------- //
// STENCIL FUNCTIONS
// ----------------------------------------------------------------------------------------------- //
stencilOutput JOIN(VS_stencil_,LTYPE)(lightVertexInput IN, bool useShadow)
{
	stencilOutput OUT;
	lightProperties light = PopulateLightPropertiesDeferred();
	float3 vpos = JOIN(pos_,LTYPE)(IN.pos.xyz, light, useShadow, false, false);
	OUT.pos = mul(float4(vpos, 1), gWorldViewProj);
	return(OUT);
}

stencilOutput JOIN(VS_stencil_cullplane_,LTYPE)(lightVertexInput IN)
{
	stencilOutput OUT;
	OUT.pos = mul(float4(IN.pos.xyz, 1), gWorldViewProj);
	return(OUT);
}

// ----------------------------------------------------------------------------------------------- //
// VOLUME FUNCTIONS
// ----------------------------------------------------------------------------------------------- //
float JOIN(CalcShadowSample_,LTYPE)(float3 eyeToCurrentPos)
{
	float fShadow;

#ifdef LTYPE_IS_SPOT // only LTYPE_IS_SPOT needs to check if it's a true spot shadow, or hemisphere shadow
	if(dShadowType==SHADOW_TYPE_SPOT) // TODO: make a separate shader for Hemisphere lights, to avoid the shader bloat and branch here
	{
		bool invalidPixel = false;
		float3 shadowTexCoord = CalcSpotShadowTexCoords(eyeToCurrentPos,dLocalShadowData);
		
		//Adding a bias term to remove z-fighting artifacts
		shadowTexCoord.z +=  ORBIS_ONLY(-)0.001;  // we should not need this now that we use radial depth
		fShadow = LocalShadowDepthCmp(shadowTexCoord);
	}
	else
#endif
	{
		float3 ray = CalcCubeMapShadowTexCoords(eyeToCurrentPos, dLocalShadowData);
		float radius = length(ray)*dShadowOneOverDepthRange;
		fShadow = LocalShadowCubeDepthCmp(float4(ray.xyz,radius));
	}

	return fShadow;
}



lightVertexVolumeOutput JOIN(VS_volume_,LTYPE)(lightVertexInput IN, lightProperties light, bool useShadow, bool outsideVolume)
{
	lightVertexVolumeOutput OUT;

	const float3 worldPos = JOIN(pos_,LTYPE)(IN.pos.xyz, light, useShadow, false, true);
	const float3 eyePos   = gViewInverse[3].xyz;
	const float3 eyeRay   = worldPos - eyePos;
	const float lengthEyeRay = length(eyeRay);

	lightVolumeData volumeData = (lightVolumeData)0.0f;
	const bool isValidEyeRay = lengthEyeRay > 0.0f;
	float3 normalizedEyeRay = 0.0f;
	if( isValidEyeRay )
	{
		JOIN(volume_,LTYPE)(volumeData, light, worldPos, IN.pos.xyz, outsideVolume);
		normalizedEyeRay = eyeRay/lengthEyeRay;
	}
		
	//Calculate hit positions in world Space
	float3 intersect0 = eyePos + eyeRay * volumeData.intersect.x;
	float3 intersect1 = eyePos + eyeRay * volumeData.intersect.y;

	const float lenIntersectPoints = length(intersect1 - intersect0);
	//Offset the points slightly so that it has lesser angular attenuation for 1st and last sample	
	
	const float posChangeForAngularFallOff = 0.005f * lenIntersectPoints;
	intersect0 += normalizedEyeRay * posChangeForAngularFallOff;
	intersect1 -= normalizedEyeRay * posChangeForAngularFallOff;	
	
	//Use fog data of first intersection point instead of second intersection point to get better results
	const float intensity = deferredLightVolumeParams_intensity*light.intensity  * max(1.0f, lenIntersectPoints) * (1 - CalcFogData(intersect0 - eyePos).w);

	OUT.pos						 = mul(float4(worldPos, 1), gWorldViewProj);
	OUT.worldPos				 = worldPos;
	OUT.screenPos				 = float4(convertToVpos(OUT.pos, deferredLightScreenSize).xy, intensity, OUT.pos.w);
#ifdef NVSTEREO
	OUT.screenPosStereo			 = float4(convertToVpos(MonoToStereoClipSpace(OUT.pos), deferredLightScreenSize).xy, intensity, OUT.pos.w);
#endif
	OUT.intersectAndPlaneDist    = float3(volumeData.intersect.xy,0); 
	OUT.gradient				 = volumeData.gradient;

	if ( !outsideVolume )
	{
		// When the back of the volume intersects the near plane, then we get a harsh lighting discontinuity (due to the fact that we're interpolating non-linear 
		// lighting terms). We compute a signed distance from the view plane here so we can fade out the volume when this situation occurs.
		//OUT.intersectAndPlaneDist.z  = -dot( float4(intersect1,1), float4(gWorldView[0].z, gWorldView[1].z, gWorldView[2].z, gWorldView[3].z) );
		OUT.intersectAndPlaneDist.z  = -dot( float4(intersect1,1), float4(gViewInverse[2].xyz, gWorldView[3].z) ); // same as commented line above but generates fewer swizzle/mov instructions.
		const float fNearDist = deferredProjectionParams.z/deferredProjectionParams.w;
		OUT.intersectAndPlaneDist.z -= fNearDist; 
	}

	
	return OUT;
}

// ----------------------------------------------------------------------------------------------- //
//Using 3*3 grid for interleaving samples
#define NUM_INTERLEAVE_SAMPLES 9.0f
float4 JOIN(PS_volume_,LTYPE)(lightPixelVolumeInput IN, lightProperties light, bool useShadow, bool outsideVolume, int nNumIntegrationSteps)
{
	const float3 worldPos = IN.worldPos; // world pos on backface
	const float2 screenPos = IN.screenPos.xy/IN.screenPos.w;

#ifdef NVSTEREO
	const float2 screenPosStereo = IN.screenPosStereo.xy/IN.screenPos.w;
	const float depth = getLinearGBufferDepth(tex2D(gDeferredLightSampler2, screenPosStereo).x, deferredProjectionParams.zw);//This has the resolved depth buffer.  Instead of MSAA buffer from UnPackGBufferDepth( screenPos, 0 );
#else
	const float depth = getLinearGBufferDepth(tex2D(gDeferredLightSampler2, screenPos).x, deferredProjectionParams.zw);//This has the resolved depth buffer.  Instead of MSAA buffer from UnPackGBufferDepth( screenPos, 0 );
#endif

	const float3 eyePos   = gViewInverse[3].xyz;
	const float3 eyeRay   = worldPos - eyePos;


	const float InvNumSteps = 1.0f / (float)nNumIntegrationSteps;

	//Get eye Ray from Screen Pos (used for unprojecting the depth correctly)
	float2 screenRay = screenPos*float2(2,-2) + float2(-1,1);
	float3 eyeRayFromScreenSpace = GetEyeRay(screenRay).xyz;

	//Calculate depth from GBuffer
	float3 GbufVec = eyeRayFromScreenSpace * depth;
	float GbufLength = dot(GbufVec, GbufVec);

	//Zero out intensity if something is covering the volume (depth test)
	float3 eyeToIntersect0 = eyeRay * IN.intersectAndPlaneDist.x;
	float3 eyeToIntersect1 = eyeRay * IN.intersectAndPlaneDist.y;
	float3 intersect0 = eyePos + eyeToIntersect0;
	float3 intensity = IN.gradient.xyz * IN.screenPos.z;
	if( !outsideVolume )
	{
		//Perform depth test here for backface technique as HW Depth test is disabled
		clip( GbufLength - dot(eyeToIntersect0, eyeToIntersect0)  ); // Clip here so that the reconstruction & up-sampler won't see stencil for these pixels
	}

	float3 currentPos = 0.0f;
	float3 deltaPosBetweenSteps = 0.0f;

	//If something is closer than back face, reduce the total intensity by amount 
	float intersect1LenSqr = dot(eyeToIntersect1, eyeToIntersect1);
	float isGbufDepthFurther = step(intersect1LenSqr, GbufLength);
	float3 intersect1 = isGbufDepthFurther ? (eyePos + eyeToIntersect1) : (eyePos + GbufVec);
	float distanceFactor = isGbufDepthFurther ? 1.0f : (GbufLength / intersect1LenSqr);

	if ( useShadow )
	{	
		//Find out what position on 3*3 grid
		float2 pixelPos = floor(IN.pos.xy);
		float2 gridPos = 0.0f;

		const float InvSizeInterval = 1.0f / 3.0f;
		gridPos.x = frac((float)pixelPos.x * InvSizeInterval) * 3.0f;
		gridPos.y = frac((float)pixelPos.y * InvSizeInterval) * 3.0f;
		//Using simple offset calculation in 3*3 grid
		// 0|1|2
		// 3|4|5
		// 6|7|8
		float offsetAdder = ((gridPos.x * 3.0) + gridPos.y);
		const float totalNumSteps = nNumIntegrationSteps * NUM_INTERLEAVE_SAMPLES;

		//Having the (totalNumSteps - 1.0f) is important as we are dividing the line into that many SEGMENTS (not steps)
		const float actualInterval = 1.0f / (totalNumSteps - 1.0f);

		const float3 deltaPos = (intersect1 - intersect0) * actualInterval;
		currentPos = intersect0 + offsetAdder * deltaPos;
		deltaPosBetweenSteps = deltaPos * NUM_INTERLEAVE_SAMPLES;
	}
	else
	{
		currentPos = intersect0;
		deltaPosBetweenSteps = (intersect1 - intersect0) * InvNumSteps;
	}

	float accumLight = 0;
	float lightAtThisStep = 0;
	[unroll] for( int j=0; j<nNumIntegrationSteps; j++)
	{
		float3 currentPosToLight = light.position.xyz - currentPos;
		float surfaceToLightSqrDist = dot( currentPosToLight, currentPosToLight );

		#if defined(LTYPE_IS_SPOT)
			if( surfaceToLightSqrDist > 0.0f )
			{
			    float oneOversurfaceToLightDist = 1.0f / sqrt(surfaceToLightSqrDist);
			    float3 surfaceToLightDir = currentPosToLight * oneOversurfaceToLightDist;
			    lightAtThisStep = JOIN(LTYPE,CalcAttenuation)(
				    surfaceToLightDir,
				    surfaceToLightSqrDist,
				    light.direction,
				    light.invSqrRadius,
				    light.spotOffset,
				    light.spotScale,
				    light.falloffExponent,
				    currentPos,
				    light.cullingPlane);
			}
		#else //defined(LTYPE_IS_SPOT)
			lightAtThisStep = JOIN(LTYPE,CalcAttenuation)(
				surfaceToLightSqrDist,
				light.invSqrRadius,
				light.falloffExponent,
				currentPos,
				light.cullingPlane);
		#endif //defined(LTYPE_IS_SPOT)

		float3 eyeToCurrentPos = currentPos - eyePos.xyz;
		float eyeTOCurrentDistancesSq = dot(eyeToCurrentPos,eyeToCurrentPos);

		if(useShadow)
		{
			float shadowSample = JOIN(CalcShadowSample_,LTYPE)(eyeToCurrentPos.xyz);
			lightAtThisStep *= shadowSample;
		}

		lightAtThisStep = (eyeTOCurrentDistancesSq <= GbufLength.x) ? lightAtThisStep : 0.0f;
		accumLight += lightAtThisStep;
		currentPos = currentPos + deltaPosBetweenSteps;
		
	}
	
	intensity *= accumLight * (InvNumSteps * distanceFactor);

	if ( !outsideVolume )
	{
		// When the far end of the volume intersects the near plane, then we get a harsh lighting discontinuity (due to the fact that we're interpolating non-linear 
		// lighting terms). We compute a per-vertex signed distance from the view plane so we can fade out the volume when this situation occurs.
		intensity *= saturate(IN.intersectAndPlaneDist.z / deferredLightVolumeParams_NearPlaneFadeRange); // Linear fade over the fade range in front of near plane
	}

	float4 finalColor = PackHdr(float4(intensity, 1.0f));
	return finalColor;
}


// =============================================================================================== //
// STANDARD
// =============================================================================================== //
GEN_FUNCS(standard, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_interior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_ON, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_exterior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_ON, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_interior_filler, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_ON, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_exterior_filler, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_ON, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_filler, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_ON, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(interior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_OFF, INT_ON, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(exterior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_OFF, INT_OFF, EXT_ON, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(texture_basic, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(texture_interior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_OFF, INT_ON, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(texture_exterior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_OFF, INT_OFF, EXT_ON, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_filler, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_exterior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_ON, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_exterior_filler,
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_ON, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_interior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_ON, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_interior_filler, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_ON, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_interior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_ON, INT_ON, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_exterior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_ON, INT_OFF, EXT_ON, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_texture, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_ON, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_texture_interior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_ON, INT_ON, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_texture_exterior, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_ON, INT_OFF, EXT_ON, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
//SOFT SHADOWS
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_interior_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_ON, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_exterior_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_ON, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_interior_filler_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_ON, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_exterior_filler_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_ON, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_filler_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_filler_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_exterior_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_ON, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_exterior_filler_soft,
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_ON, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_interior_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_ON, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_interior_filler_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_ON, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
// spot light specific
// ----------------------------------------------------------------------------------------------- //
#if defined(LTYPE_IS_SPOT)
GEN_FUNCS(standard_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_OFF, FILL_OFF, INT_OFF, EXT_OFF, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_exterior_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_OFF, INT_OFF, EXT_ON, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_exterior_filler_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_ON, INT_OFF, EXT_ON, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_filler_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_ON, INT_OFF, EXT_OFF, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_OFF, FILL_ON, INT_OFF, EXT_OFF, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(exterior_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_OFF, FILL_OFF, INT_OFF, EXT_ON, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(texture_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_OFF, FILL_OFF, INT_OFF, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(texture_exterior_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_OFF, FILL_OFF, INT_OFF, EXT_ON, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_filler_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_ON, INT_OFF, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_exterior_caustic, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_ON, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_exterior_filler_caustic, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_ON, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_interior_caustic, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_ON, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_interior_filler_caustic, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_ON, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_exterior_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_OFF, FILL_ON, INT_OFF, EXT_ON, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_texture_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_OFF, FILL_ON, INT_OFF, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(filler_texture_exterior_caustic, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_OFF, FILL_ON, INT_OFF, EXT_ON, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(vehicle_twin_standard, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_ON, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(vehicle_twin_shadow, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_ON, SOFTSHAD_OFF);

// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(vehicle_twin_texture, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_OFF, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_ON, SOFTSHAD_OFF);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(vehicle_twin_shadow_texture, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_ON, SOFTSHAD_OFF);

//SOFT SHADOWS - SPOTS
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_caustic_soft, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_exterior_caustic_soft, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_OFF, INT_OFF, EXT_ON, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_exterior_filler_caustic_soft, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_ON, INT_OFF, EXT_ON, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_filler_caustic_soft, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_ON, INT_OFF, EXT_OFF, CAUS_ON, TEX_OFF, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_caustic_soft, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_filler_caustic_soft, 
          lightVertexInput, lightVertexOutput, 
          lightPixelInput, lightPixelOutput, 
          SHAD_ON, FILL_ON, INT_OFF, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_exterior_caustic_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_ON, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_exterior_filler_caustic_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_OFF, EXT_ON, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_interior_caustic_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_ON, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(shadow_texture_interior_filler_caustic_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_ON, INT_ON, EXT_OFF, CAUS_ON, TEX_ON, VEH_TWIN_OFF, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(vehicle_twin_shadow_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_OFF, VEH_TWIN_ON, SOFTSHAD_ON);
// ----------------------------------------------------------------------------------------------- //
GEN_FUNCS(vehicle_twin_shadow_texture_soft, 
		  lightVertexInput, lightVertexOutput, 
		  lightPixelInput, lightPixelOutput, 
		  SHAD_ON, FILL_OFF, INT_OFF, EXT_OFF, CAUS_OFF, TEX_ON, VEH_TWIN_ON, SOFTSHAD_ON);

#endif //LTYPE_IS_SPOT

// =============================================================================================== //
// STENCIL
// =============================================================================================== //

stencilOutput JOIN4(VS_,LTYPE,_stencil_,standard)(lightVertexInput IN) 
{ 
	stencilOutput OUT = JOIN(VS_stencil_,LTYPE)(IN, false); 
	return(OUT); 
} 

stencilOutput JOIN4(VS_,LTYPE,_stencil_,shadow)(lightVertexInput IN) 
{ 
	stencilOutput OUT = JOIN(VS_stencil_,LTYPE)(IN, true); 
	return(OUT); 
} 

stencilOutput JOIN4(VS_,LTYPE,_stencil_cullplane_,standard)(lightVertexInput IN) 
{ 
	stencilOutput OUT = JOIN(VS_stencil_cullplane_,LTYPE)(IN); 
	return(OUT); 
} 

// =============================================================================================== //
// INSTANCE
// =============================================================================================== //

JOIN(LTYPE,InstancedVertexOutput) JOIN3(VS_,LTYPE,_instanced)(JOIN(LTYPE,InstancedVertexInput) IN) 
{ 
	lightProperties light = JOIN(PopulateLightPropertiesInstanced,LTYPE)(IN);
	float3 vpos = JOIN(pos_,LTYPE)(IN.pos.xyz, light, false, false, false);

	JOIN(LTYPE,InstancedVertexOutput) OUT = JOIN(VS_instanced_,LTYPE)(IN);
	OUT.pos	= mul(float4(vpos, 1), gWorldViewProj);
	OUT.screenPos = convertToVpos(MonoToStereoClipSpace(OUT.pos), deferredLightScreenSize);
	OUT.eyeRay = float4(vpos - (gViewInverse[3].xyz+StereoWorldCamOffSet()), OUT.pos.w);

	return(OUT); 
} 

lightPixelOutput JOIN3(PS_,LTYPE,_instanced)(JOIN(LTYPE,InstancedVertexOutput) IN
											#if SAMPLE_FREQUENCY
												 , uint sampleIndex : SV_SampleIndex
											#endif
											) 
{ 
	lightPixelInput lightIN;
	lightIN.pos = IN.pos;
	lightIN.screenPos = IN.screenPos;
	lightIN.eyeRay = IN.eyeRay;
	#if SAMPLE_FREQUENCY
		lightIN.sampleIndex = sampleIndex;
	#endif

	lightProperties light = JOIN(PopulateLightPropertiesInstanced,LTYPE)(IN);

	lightPixelOutput OUT;
	OUT.col = JOIN(deferred_,LTYPE)(lightIN, light, false, true, false, true, false, false, false, false);
	return(OUT); 
} 

// =============================================================================================== //
// VOLUME
// =============================================================================================== //
#define VOL_OUTSIDE	true
#define VOL_INSIDE  false
#define NUM_VOLUME_INTEGRATION_STEPS 8
#define NUM_VOLUME_HQ_INTEGRATION_STEPS 48
#define SUPPORT_HQ_VOLUMETRIC_LIGHTS (RSG_PC) // Please keep this in sync with SUPPORT_HQ_VOLUMETRIC_LIGHTS in DeferredConfig.h

// ----------------------------------------------------------------------------------------------- //
GEN_VOLUME_FUNCS(standard_PixelAtten,
				 lightVertexInput, lightVertexVolumeOutput,
				 lightPixelVolumeInput, lightPixelOutput,
				 SHAD_OFF, VOL_INSIDE, NUM_VOLUME_INTEGRATION_STEPS);
// ----------------------------------------------------------------------------------------------- //
GEN_VOLUME_FUNCS(shadow_PixelAtten,
				 lightVertexInput, lightVertexVolumeOutput,
				 lightPixelVolumeInput, lightPixelOutput,
				 SHAD_ON, VOL_INSIDE, NUM_VOLUME_INTEGRATION_STEPS);
// ----------------------------------------------------------------------------------------------- //
GEN_VOLUME_FUNCS(outside_PixelAtten,
				 lightVertexInput, lightVertexVolumeOutput,
				 lightPixelVolumeInput, lightPixelOutput,
				 SHAD_OFF, VOL_OUTSIDE, NUM_VOLUME_INTEGRATION_STEPS);
// ----------------------------------------------------------------------------------------------- //
GEN_VOLUME_FUNCS(outsideshadow_PixelAtten,
				 lightVertexInput, lightVertexVolumeOutput,
				 lightPixelVolumeInput, lightPixelOutput,
				 SHAD_ON, VOL_OUTSIDE, NUM_VOLUME_INTEGRATION_STEPS);
// ----------------------------------------------------------------------------------------------- //

#if SUPPORT_HQ_VOLUMETRIC_LIGHTS
// ----------------------------------------------------------------------------------------------- //
GEN_VOLUME_FUNCS(standard_PixelAtten_HQ,
				 lightVertexInput, lightVertexVolumeOutput,
				 lightPixelVolumeInput, lightPixelOutput,
				 SHAD_OFF, VOL_INSIDE, NUM_VOLUME_HQ_INTEGRATION_STEPS);
// ----------------------------------------------------------------------------------------------- //
GEN_VOLUME_FUNCS(shadow_PixelAtten_HQ,
				 lightVertexInput, lightVertexVolumeOutput,
				 lightPixelVolumeInput, lightPixelOutput,
				 SHAD_ON, VOL_INSIDE, NUM_VOLUME_HQ_INTEGRATION_STEPS);
// ----------------------------------------------------------------------------------------------- //
GEN_VOLUME_FUNCS(outside_PixelAtten_HQ,
				 lightVertexInput, lightVertexVolumeOutput,
				 lightPixelVolumeInput, lightPixelOutput,
				 SHAD_OFF, VOL_OUTSIDE, NUM_VOLUME_HQ_INTEGRATION_STEPS);
// ----------------------------------------------------------------------------------------------- //
GEN_VOLUME_FUNCS(outsideshadow_PixelAtten_HQ,
				 lightVertexInput, lightVertexVolumeOutput,
				 lightPixelVolumeInput, lightPixelOutput,
				 SHAD_ON, VOL_OUTSIDE, NUM_VOLUME_HQ_INTEGRATION_STEPS);
// ----------------------------------------------------------------------------------------------- //
#endif // SUPPORT_HQ_VOLUMETRIC_LIGHTS

// =============================================================================================== //
// TECHNIQUES
// =============================================================================================== //

technique MSAA_NAME(LTYPE)
{
	#define DEF_PASS(type) \
		pass MSAA_NAME(type) \
		{ \
			VertexShader = compile VERTEXSHADER			JOIN4(VS_,LTYPE,_,type)(); \
			PixelShader  = compile MSAA_PIXEL_SHADER	JOIN4(PS_,LTYPE,_,type)() CGC_FLAGS(CGC_DEFAULTFLAGS); \
		}

	DEF_PASS(standard)
	DEF_PASS(shadow)
	DEF_PASS(shadow_interior)
	DEF_PASS(shadow_exterior)
	DEF_PASS(shadow_interior_filler)
	DEF_PASS(shadow_exterior_filler)
	DEF_PASS(shadow_filler)
	DEF_PASS(filler)
	DEF_PASS(interior)
	DEF_PASS(exterior)
	DEF_PASS(texture_basic)
	DEF_PASS(texture_interior)
	DEF_PASS(texture_exterior)
	DEF_PASS(shadow_texture)
	DEF_PASS(shadow_texture_filler)
	DEF_PASS(shadow_texture_exterior)
	DEF_PASS(shadow_texture_exterior_filler)
	DEF_PASS(shadow_texture_interior)
	DEF_PASS(shadow_texture_interior_filler)
	DEF_PASS(filler_interior)
	DEF_PASS(filler_exterior)
	DEF_PASS(filler_texture)
	DEF_PASS(filler_texture_interior)
	DEF_PASS(filler_texture_exterior)

    pass stencil_standard   // special case, since we need a null pixel shader
	{
		VertexShader = compile VERTEXSHADER JOIN4(VS_,LTYPE,_stencil_,standard)();
		COMPILE_PIXELSHADER_NULL()
	}

	pass stencil_shadow   // special case, since we need a null pixel shader
	{
		VertexShader = compile VERTEXSHADER JOIN4(VS_,LTYPE,_stencil_,shadow)();
		COMPILE_PIXELSHADER_NULL()
	}

	pass stencil_cullplane // for stenciling out pixels on the wrong side of the cull plane
	{
		VertexShader = compile VERTEXSHADER JOIN4(VS_,LTYPE,_stencil_cullplane_,standard)();
		COMPILE_PIXELSHADER_NULL()
	}

	pass instanced // for stenciling out pixels on the wrong side of the cull plane
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_instanced)();
		PixelShader  = compile MSAA_PIXEL_SHADER	JOIN3(PS_,LTYPE,_instanced)();
	}

	//Soft shadows
	DEF_PASS(shadow_soft)
	DEF_PASS(shadow_interior_soft)
	DEF_PASS(shadow_exterior_soft)
	DEF_PASS(shadow_interior_filler_soft)
	DEF_PASS(shadow_exterior_filler_soft)
	DEF_PASS(shadow_filler_soft)
	DEF_PASS(shadow_texture_soft)
	DEF_PASS(shadow_texture_filler_soft)
	DEF_PASS(shadow_texture_exterior_soft)
	DEF_PASS(shadow_texture_exterior_filler_soft)
	DEF_PASS(shadow_texture_interior_soft)
	DEF_PASS(shadow_texture_interior_filler_soft)

	//spot specific
	#if defined(LTYPE_IS_SPOT)
    DEF_PASS(standard_caustic)
    DEF_PASS(shadow_caustic)
    DEF_PASS(shadow_exterior_caustic)
    DEF_PASS(shadow_exterior_filler_caustic)
    DEF_PASS(shadow_filler_caustic)
    DEF_PASS(filler_caustic)
    DEF_PASS(exterior_caustic)
    DEF_PASS(texture_caustic)
    DEF_PASS(texture_exterior_caustic)
    DEF_PASS(shadow_texture_caustic)
    DEF_PASS(shadow_texture_filler_caustic)
	DEF_PASS(shadow_texture_exterior_caustic)
	DEF_PASS(shadow_texture_exterior_filler_caustic)
	DEF_PASS(shadow_texture_interior_caustic)
	DEF_PASS(shadow_texture_interior_filler_caustic)
    DEF_PASS(filler_exterior_caustic)
    DEF_PASS(filler_texture_caustic)
    DEF_PASS(filler_texture_exterior_caustic)

	DEF_PASS(vehicle_twin_standard)
	DEF_PASS(vehicle_twin_shadow)
	DEF_PASS(vehicle_twin_texture)
	DEF_PASS(vehicle_twin_shadow_texture)
	
	//Soft shadows - spot
    DEF_PASS(shadow_caustic_soft)
    DEF_PASS(shadow_exterior_caustic_soft)
    DEF_PASS(shadow_exterior_filler_caustic_soft)
    DEF_PASS(shadow_filler_caustic_soft)
    DEF_PASS(shadow_texture_caustic_soft)
    DEF_PASS(shadow_texture_filler_caustic_soft)
	DEF_PASS(shadow_texture_exterior_caustic_soft)
	DEF_PASS(shadow_texture_exterior_filler_caustic_soft)
	DEF_PASS(shadow_texture_interior_caustic_soft)
	DEF_PASS(shadow_texture_interior_filler_caustic_soft)
	DEF_PASS(vehicle_twin_shadow_soft)
	DEF_PASS(vehicle_twin_shadow_texture_soft)
	#endif // defined(LTYPE_IS_SPOT)
	#undef DEF_PASS
}

// =============================================================================================== //
// TECHNIQUES - VOLUME
// =============================================================================================== //

technique JOIN(LTYPE,_volume)
{
	// ----------------------------------------------------------------------------------------------- //
	pass standard_PixelAtten
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_vol_standard_PixelAtten)();
		PixelShader  = compile PIXELSHADER			JOIN3(PS_,LTYPE,_vol_standard_PixelAtten)();
	}
	// ----------------------------------------------------------------------------------------------- //
	pass shadow_PixelAtten
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_vol_shadow_PixelAtten)();
		PixelShader  = compile PIXELSHADER			JOIN3(PS_,LTYPE,_vol_shadow_PixelAtten)();
	}
	// ----------------------------------------------------------------------------------------------- //
	pass outside_PixelAtten
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_vol_outside_PixelAtten)();
		PixelShader  = compile PIXELSHADER			JOIN3(PS_,LTYPE,_vol_outside_PixelAtten)();
	}
	// ----------------------------------------------------------------------------------------------- //
	pass outsideShadow_PixelAtten
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_vol_outsideshadow_PixelAtten)();
		PixelShader  = compile PIXELSHADER			JOIN3(PS_,LTYPE,_vol_outsideshadow_PixelAtten)();
	}
	// ----------------------------------------------------------------------------------------------- //

#if SUPPORT_HQ_VOLUMETRIC_LIGHTS

	// ----------------------------------------------------------------------------------------------- //
	pass standard_PixelAtten_HQ
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_vol_standard_PixelAtten)();
		PixelShader  = compile PIXELSHADER			JOIN3(PS_,LTYPE,_vol_standard_PixelAtten_HQ)();
	}
	// ----------------------------------------------------------------------------------------------- //
	pass shadow_PixelAtten_HQ
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_vol_shadow_PixelAtten)();
		PixelShader  = compile PIXELSHADER			JOIN3(PS_,LTYPE,_vol_shadow_PixelAtten_HQ)();
	}
	// ----------------------------------------------------------------------------------------------- //
	pass outside_PixelAtten_HQ
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_vol_outside_PixelAtten)();
		PixelShader  = compile PIXELSHADER			JOIN3(PS_,LTYPE,_vol_outside_PixelAtten_HQ)();
	}
	// ----------------------------------------------------------------------------------------------- //
	pass outsideShadow_PixelAtten_HQ
	{
		VertexShader = compile VERTEXSHADER			JOIN3(VS_,LTYPE,_vol_outsideshadow_PixelAtten)();
		PixelShader  = compile PIXELSHADER			JOIN3(PS_,LTYPE,_vol_outsideshadow_PixelAtten_HQ)();
	}
	// ----------------------------------------------------------------------------------------------- //

#endif // SUPPORT_HQ_VOLUMETRIC_LIGHTS
}
