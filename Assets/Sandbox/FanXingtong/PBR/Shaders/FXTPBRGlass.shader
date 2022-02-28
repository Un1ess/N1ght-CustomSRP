Shader "Fxt/FXTPBRGlass"
{
    Properties
    {
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _BaseMap("MainTex",2D)="white"{}
        [Toggle(_MASKMAP)]_MaskmapHONG("开启mask",int) = 0
        _MaskMap("MaskMap",2D)="white"{}
        _BumpMap("法线贴图",2D)="bump"{}
        _NormalScale("法线贴图强度",Range(0,2))=1
        _Smoothness("光滑度",Range(0,1)) = 1
        _Metallic("金属度",Range(0,1)) = 1
        [Space(20)]
        [Toggle]_AlphaTest("透明裁切",int) = 0
        _Cutoff("透明裁切",Range(0,1)) = 0
        [Space(20)]
        [Toggle(_EMISSION)]_Emission("开启自发光",int) = 0
       
        _EmissionMap("发光贴图",2D)="white"{}
        [HDR]_EmissionColor("自发光颜色",color)=(1,1,1,1)
        
        [Space(20)]
        [Toggle(_ENVCUBE)]_EnvCubeOn("使用自定义环境贴图",int) = 0
        _EnvCUBESpec("EnvironmentSpec",Cube) = "white" {}
        _EnvCUBEDiff("EnvironmentDiffuse",Cube) = "white" {}
        
        [Space(20)]
        _FresnelPower("菲涅尔指数",float) = 1
        _TransmitColor("透射光颜色",color) = (1,1,1,1)
        _TransmitColorEgde("边缘颜色",color) = (1,1,1,1)
//        [Space(20)]
//        [Toggle(_SGSSS)]_Sgsss("开启球谐SSS",float) = 1 
//        _ScatterAmount("_ScatterAmount",color) = (1,1,1,1)
//        _AmbientSkinColor("环境补光",color) = (1,1,1,1)
//        
//        _RimPower("皮肤边缘光范围指数",range(0,5))=1
//        _RimColor("皮肤边缘光颜色",color)=(1,1,1,1)
        
        [Space(20)]
        _PreIntegratedFGD("LUT",2D) = "white"{}
    }
    SubShader
    {
        Tags
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Transparent"
            "Queue" = "Transparent"
        }
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        

        CBUFFER_START(UnityPerMaterial)
        
        float4 _BaseMap_ST;
        float4 _MaskMap_ST;
        float4 _BumpMap_ST;
        float4 _EmissionMap_ST;
        float4 _BaseColor;

        float _Cutoff;

        
        float _NormalScale; //法线贴图强度
        float _Metallic;
        float _Smoothness;
        float4 _EmissionColor;

        
        float4 _ScatterAmount;
        float4 _AmbientSkinColor;
        float _RimPower;
        float4 _RimColor;
        

        
        float4 _EnvCUBE_ST;
        float4 _EnvCUBESpec_HDR;
        float4 _EnvCUBEDiff_HDR;

        float4 _TransmitColor;
        float4 _TransmitColorEgde;
        float _FresnelPower;

        CBUFFER_END

        TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
        TEXTURE2D(_MaskMap);    SAMPLER(sampler_MaskMap);
        TEXTURE2D(_BumpMap);    SAMPLER(sampler_BumpMap);
        TEXTURE2D(_EmissionMap);    SAMPLER(sampler_EmissionMap);
        
        TEXTURE2D(_PreIntegratedFGD);    SAMPLER(sampler_PreIntegratedFGD);

        #ifdef _ENVCUBE
        TEXTURECUBE(_EnvCUBESpec);    SAMPLER(sampler_EnvCUBESpec);
        TEXTURECUBE(_EnvCUBEDiff);    SAMPLER(sampler_EnvCUBEDiff);
        #endif
        
        ENDHLSL
        
        Pass
        {
            Name"FXTPBRLitForward"
            Tags
            {
                    "LightMode"="UniversalForward"
            }
            
            Blend one OneminusSrcAlpha
            Zwrite off
            HLSLPROGRAM
            #include "NewFXTPBRRefactor.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
            #pragma shader_feature _EMISSION
            #pragma shader_feature _MASKMAP
            #pragma shader_feature _SGSSS
            #pragma shader_feature _ENVCUBE
           
            
            
            #pragma vertex FXTLitPassVertex
            #pragma fragment FXTLitPassFragment

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT       //若光影阴影设置为软阴影，则启用

            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            #pragma shader_feature _ALPHATEST_ON

            

            
            struct Attributes 
            {
                float4 positionOS       : POSITION;
                float2 texcoord         : TEXCOORD0;
                float3 normalOS         : NORMAL;               
                float4 tangentOS        : TANGENT;
                

            };

            struct Varyings
            {
                float2 uv               : TEXCOORD0;
                float4 positionCS       : SV_POSITION;
                float3 viewDirWS        : TEXCOORD1;
                float3 normalWS         : TEXCOORD2;
                float3 positionWS       : TEXCOORD3;          
                float3 tangentWS        : TEXCOORD4;
                float3 bitangentWS      : TEXCOORD5;
                float4 shadowCoord      : TEXCOORD6;
            };


            void InitializeInputDataNew(Varyings input, half3 normalTS, out InputDataNew inputData)
            {
                inputData = (InputDataNew)0;
                inputData.positionWS = input.positionWS;
                float3 normalWS = mul(normalTS,float3x3(input.tangentWS.xyz,
                                    input.bitangentWS.xyz,input.normalWS));
                inputData.normalWS = normalize(normalWS);
                inputData.viewDirectionWS = SafeNormalize(input.viewDirWS);;
                inputData.shadowCoord = input.shadowCoord;        
            }
            Varyings FXTLitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);  //???

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                
                // normalWS and tangentWS already normalize.
                // this is required to avoid skewing the direction during interpolation
                // also required for per-vertex lighting and SH evaluation
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                float3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                // already normalized from normal transform to WS.
                output.normalWS = normalInput.normalWS;
                output.viewDirWS = viewDirWS;
                real sign = input.tangentOS.w * GetOddNegativeScale();
                output.tangentWS = normalInput.tangentWS.xyz;
                output.bitangentWS = cross(output.normalWS,output.tangentWS) * sign;
                output.positionWS = vertexInput.positionWS;
                output.shadowCoord = GetShadowCoord(vertexInput);
                output.positionCS = vertexInput.positionCS;
                
                return output;
            }
            

            half4 FXTLitPassFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                //采样albedo — basecolor
                float4 albedoMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap,
                                    input.uv * _BaseMap_ST.xy + _BaseMap_ST.zw);
                float3 albedoRGB = albedoMap.rgb * _BaseColor.rgb;
                float alpha = albedoMap.a * _BaseColor.a;
                //采样法线数据
                float4 normalRawData =  SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap,
                                    input.uv * _BumpMap_ST.xy + _BumpMap_ST.zw);
                
                float3 normalData = UnpackNormalScale(normalRawData,_NormalScale);

                //采样MaskMap获取金属度粗糙度以及AO
                float metallic;
                float ao;
                float perceptualSmoothness;
                
                #ifdef  _MASKMAP

                float4 maskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap,
                                    input.uv * _MaskMap_ST.xy + _MaskMap_ST.zw);
                metallic = maskMap.r;
                ao = maskMap.g;
                perceptualSmoothness = maskMap.a;
               //eturn half4(1,1,0,1);
                
                #else

                metallic = _Metallic;
                ao = 1.0;
                perceptualSmoothness = _Smoothness;
                
                #endif

                
                //自发光
                float4 emissionMap = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap,
                                    input.uv * _EmissionMap_ST.xy + _EmissionMap_ST.zw);
                half3 emissionColor = emissionMap.rgb * _EmissionColor.rgb;

                //PBR function
                InputDataNew inputData;
                InitializeInputDataNew(input, normalData, inputData);
                
                BRDFDataNew brdfData;
                InitializeBRDFDataNew(albedoRGB, perceptualSmoothness,
                        metallic,brdfData);

                DirectLighting direct_lighting;
                IndirectLighting indirect_lighting;
                //get light
                Light mainLight = GetMainLight(inputData.shadowCoord);
                half3 lightColor = mainLight.color * mainLight.shadowAttenuation
                                    * mainLight.distanceAttenuation;
                half3 lightDirWS = mainLight.direction;
                
             
                
                ///FGD LUT
                half clampedNdotV = max(saturate(dot(inputData.normalWS,inputData.viewDirectionWS)),0.0001);

                float2 coordLUT = Remap01ToHalfTexelCoord(float2(sqrt(clampedNdotV), brdfData.perceptualRoughness), 64);
                float3 preFGD = SAMPLE_TEXTURE2D_LOD(_PreIntegratedFGD, sampler_PreIntegratedFGD, coordLUT, 0).xyz;
                half3 specularFGD = lerp(preFGD.xxx, preFGD.yyy, brdfData.F0);
                half diffuseFGD = preFGD.z + 0.5;
                float reflectivity = preFGD.y;

                //能量补偿
                float energyCompensation = 1.0 / reflectivity - 1.0;
                float3 energyCompensationTerm = 1.0 + brdfData.F0 * energyCompensation;


                direct_lighting = BSDFDirect(brdfData,inputData,lightDirWS,lightColor,energyCompensationTerm);
                indirect_lighting = BSDFIndirect(brdfData,inputData,ao,diffuseFGD,specularFGD,energyCompensationTerm);

                //多光源
                half3 addLightTerm;
                #ifdef _ADDITIONAL_LIGHTS
                    uint pixelLightCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                    {
                        Light addlight = GetAdditionalLight(lightIndex, inputData.positionWS);
                        float3 addLightDirWs = addlight.direction;
                        float3 addLightColor = addlight.color * addlight.distanceAttenuation * addlight.shadowAttenuation;
                        direct_lighting.diffuse += BSDFDirect(brdfData, inputData, addLightDirWs, addLightColor,energyCompensationTerm).diffuse;
                        direct_lighting.specular += BSDFDirect(brdfData, inputData, addLightDirWs, addLightColor,energyCompensationTerm).specular;
                     
                    }
                
                #endif

                float3 DirectTerm = direct_lighting.diffuse + direct_lighting.specular;
                float3 IndirectTerm = indirect_lighting.diffuse + indirect_lighting.specular;
                
                //是否使用自定义环境贴图
                #ifdef _ENVCUBE
                     
                    float3 viewWS = inputData.viewDirectionWS;
                    float3 normalWS = inputData.normalWS;
                    float roughness = brdfData.perceptualRoughness;
                    float3 reflectDirWS=reflect(-viewWS,normalWS);
                    //采用 采样高Lod下的Diffuse卷积环境图————球谐光照待完善
                    float4 InDirectDiffColor = SAMPLE_TEXTURECUBE_LOD(_EnvCUBEDiff,sampler_EnvCUBEDiff,reflectDirWS,10);
				    InDirectDiffColor.rgb = DecodeHDREnvironment(InDirectDiffColor,_EnvCUBEDiff_HDR).rgb;
            	    
                    //自定义环境贴图——高光IBL
                    roughness = roughness*(1.7-0.7*roughness);
                    float MidLevel=roughness*6;
                    float4 IndirectspecColor=SAMPLE_TEXTURECUBE_LOD(_EnvCUBESpec, sampler_EnvCUBESpec,
                    reflectDirWS,MidLevel);
                    IndirectspecColor.xyz  = DecodeHDREnvironment(IndirectspecColor,
                    _EnvCUBESpec_HDR) * ao;
                    
                    float3 IndirectDiffuse = InDirectDiffColor * diffuseFGD * ao *
                        (1 - brdfData.metallic) * brdfData.diffuse;
                    float3 IndirectSpec = IndirectspecColor * specularFGD * energyCompensationTerm;

                    IndirectTerm = IndirectDiffuse + IndirectSpec;
                    
                #endif


                
                // //SSS
                // SGSSSData sgsssData;
                // half3 SSSColor;
                // #ifdef _SGSSS
                // InitializeSGSSSData(_ScatterAmount,_AmbientSkinColor,_RimPower,_RimColor,sgsssData);
                // SSSColor = SGDiffuseLighting(inputData.normalWS,lightDirWS,sgsssData.ScatterAmount);
                // direct_lighting = BSDFDirect_SGSSS(brdfData,inputData,lightDirWS,lightColor,energyCompensationTerm,SSSColor);
                // IndirectTerm += _AmbientSkinColor;
                //
                //     //SSS条件下的多光源
                //     #ifdef _ADDITIONAL_LIGHTS
                //     
                //     for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                //     {
                //         Light addlight = GetAdditionalLight(lightIndex, inputData.positionWS);
                //         float3 addLightDirWs = addlight.direction;
                //         float3 addLightColor = addlight.color * addlight.distanceAttenuation * addlight.shadowAttenuation;
                //         direct_lighting += BSDFDirect_SGSSS(brdfData, inputData, addLightDirWs, addLightColor,energyCompensationTerm,SSSColor);
                //         
                //     }
                //     #endif
                //
                // #endif
                

                

                float3 FinalColor = DirectTerm + IndirectTerm;

                #ifdef _EMISSION
                FinalColor += emissionColor;
                #endif

                //透明裁切
                #ifdef _ALPHATEST_ON
                    clip(alpha - _Cutoff);
                #endif

                float3 DiffuseTerm  = (direct_lighting.diffuse+indirect_lighting.diffuse);
                float3 SpecularTerm  = (direct_lighting.specular + indirect_lighting.specular);

                float fresnel = 1 - saturate(dot(inputData.normalWS,inputData.viewDirectionWS));
                fresnel = pow(fresnel,_FresnelPower);

                float3 fresnelColor = lerp(_TransmitColor.rgb,_TransmitColorEgde.rgb,fresnel);
                SpecularTerm += lerp(_TransmitColor.rgb,_TransmitColorEgde.rgb,fresnel);
                return half4(DiffuseTerm*alpha +SpecularTerm + fresnelColor *0.3 ,alpha);
                //return half4(fresnelColor,alpha);
            }
            ENDHLSL
            
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull back   //不透明物体阴影透视 callback

            HLSLPROGRAM
            #include "NewFXTPBRRefactor.hlsl"
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 3.0
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
        
            
            float3 _LightDirection;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionCS   : SV_POSITION;
            };

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
            #endif

                return positionCS;
            }

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                half alpha = Alpha(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a, _BaseColor, _Cutoff);
                return 0;
            }
            ENDHLSL
        }
        
    }

}