Shader "Fxt/HoloGraphic"
{
    Properties
    {
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _BaseMap("MainTex",2D)="white"{}
        [Toggle(_MASKMAP)]_MaskmapHONG("开启mask",int) = 1
        _MaskMap("MaskMap",2D)="white"{}
        _BumpMap("法线贴图",2D)="bump"{}
        _NormalScale("法线贴图强度",Range(0,2))=1
        _Smoothness("光滑度",Range(0,1)) = 1
        _Metallic("金属度",Range(0,1)) = 1
        
        [Space(20)]
        [Toggle(_EMISSION)]_Emission("开启自发光",int) = 1
       
        _EmissionMap("发光贴图",2D)="white"{}
        [HDR]_EmissionColor("自发光颜色",color)=(1,1,1,1)
        
        [KeywordEnum(Fresnel,Aniso)]_Iridescent("Iridescent Mode",float) = 1
        _HoloGraphicInput("_HoloGraphicInput",color) = (0.5,0.5,1.0,1)
        _FresnelIridescentINT("_FresnelIridescentINT",Range(0,2)) =1
        
        _Distance("Distance",Range(0,10000)) = 1000 //nm
        _AnisoOffset("_AnisoOffset",Range(-1,1)) = 0
        _AnisoINT("AnisoINT",Range(0,2)) =1
        
        _PreIntegratedFGD("LUT",2D) = "white"{}
    }
    SubShader
    {
        Tags
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
            "Queue" = "Geometry"
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
        
        float _NormalScale; //法线贴图强度
        float _Metallic;
        float _Smoothness;
        float4 _EmissionColor;
        #ifdef _IRIDESCENT_FRESNEL
        float4 _HoloGraphicInput;
        float _FresnelIridescentINT;

        #elif defined (_IRIDESCENT_ANISO)
        float _Distance;
        float _AnisoOffset;
        float _AnisoINT;
        
        #endif


        CBUFFER_END

        TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
        TEXTURE2D(_MaskMap);    SAMPLER(sampler_MaskMap);
        TEXTURE2D(_BumpMap);    SAMPLER(sampler_BumpMap);
        TEXTURE2D(_EmissionMap);    SAMPLER(sampler_EmissionMap);
        
        TEXTURE2D(_PreIntegratedFGD);    SAMPLER(sampler_PreIntegratedFGD);
        
        ENDHLSL
        
        Pass
        {
            Name"FXTPBRLitForward"
            Tags
            {
                    "LightMode"="UniversalForward"
            }
            
            HLSLPROGRAM
            #include "NewFXTPBRRefactor.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
            #pragma shader_feature _EMISSION
            #pragma shader_feature _MASKMAP
            #pragma shader_feature _IRIDESCENT_FRESNEL
            #pragma shader_feature _IRIDESCENT_ANISO
           
            
            
            #pragma vertex FXTLitPassVertex
            #pragma fragment FXTLitPassFragment

            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT       //若光影阴影设置为软阴影，则启用

            

            
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


                //get light
                Light mainLight = GetMainLight(input.shadowCoord);
                half3 lightColor = mainLight.color * mainLight.shadowAttenuation
                                    * mainLight.distanceAttenuation;
                half3 lightDirWS = mainLight.direction;
                
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
                float3 DirectTerm;
                float3 IndirectTerm;
                
                //Holographic镭射
                #ifdef _IRIDESCENT_FRESNEL
                half3 holographic = iridescent(_HoloGraphicInput,inputData.normalWS,inputData.viewDirectionWS) * _FresnelIridescentINT;
                brdfData.diffuse += holographic;
                
                #elif defined (_IRIDESCENT_ANISO)
                float3 spectralCol = DiffractionGrating(input.bitangentWS,lightDirWS,
                    inputData.viewDirectionWS,_Distance,_AnisoOffset);
                spectralCol = spectralCol * pow(1 - saturate(dot(inputData.normalWS,inputData.viewDirectionWS)),0.8);
                brdfData.diffuse += spectralCol * _AnisoINT;
                //return half4(spectralCol,1);
                #endif
                
                
                
             
                
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
                DirectTerm = direct_lighting.diffuse + direct_lighting.specular;
                IndirectTerm = indirect_lighting.diffuse + indirect_lighting.specular;
                float3 FinalColor = DirectTerm + IndirectTerm;

                #ifdef _EMISSION
                FinalColor += emissionColor;
                #endif

                

                return half4(FinalColor,alpha);
            }
            ENDHLSL
            
        }
    }

}