Shader "Fxt/PBRLiquidInBottleTransparent"
{
    Properties
    {
        _BaseColor("BaseColor",Color)   = (1,1,1,1)
        _EdgeColor("EdgeColor",Color)   = (1,1,1,1)
        _Cutoff("_Cutoff",Range(0,1))   = 0
        _LiquidY("LiquidY",Range(-2,2)) = 0
        _NoiseMap("NoiseMap",2D)        = "white"{}
        
        _WobbleX("_WobbleX",Range(-1,1))      = 0
        _WobbleZ("_WobbleZ",Range(-1,1))      = 0
        
        [Space(30)]
        [Toggle(_MASKMAP)]_MaskmapHONG("开启mask",int) = 0
        _MaskMap("MaskMap",2D)="white"{}
        _BumpMap("法线贴图",2D)="bump"{}
        _NormalScale("法线贴图强度",Range(0,2))=1
        _Smoothness("光滑度",Range(0,1)) = 1
        _SmoothnessIN("内表面光滑度",Range(0,1)) = 1
        _SmoothnessOUT("外表面光滑度",Range(0,1)) = 1
        _Metallic("金属度",Range(0,1)) = 1
        
        _GlitterMap("闪烁贴图",2D) = "white"{}
        _GlitterColor("闪烁颜色",color) = (0,0,1,1)
        _PreIntegratedFGD("LUT",2D) = "white"{}
        [Space(30)]
        _Tiling("Tiling",Vector)        = (0,0,0,0)
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
        float4 _NoiseMap_ST;
        float4 _BaseColor;
        float4 _EdgeColor;
        float4 _TopColor;

        float _Cutoff;
        float _LiquidY;
        float _WobbleX;
        float _WobbleZ;
        float4 _Tiling;

        //pbr
        float _NormalScale; //法线贴图强度
        float _Metallic;
        float _Smoothness;
        float _SmoothnessIN;
        float _SmoothnessOUT;

        //flow
        float _Flow;
        float4 _GlitterColor;

        
        CBUFFER_END

        TEXTURE2D(_NoiseMap);       SAMPLER(sampler_NoiseMap);
        TEXTURE2D(_MaskMap);    SAMPLER(sampler_MaskMap);
        TEXTURE2D(_BumpMap);    SAMPLER(sampler_BumpMap);
        TEXTURE2D(_GlitterMap);    SAMPLER(sampler_GlitterMap);

        TEXTURE2D(_PreIntegratedFGD);    SAMPLER(sampler_PreIntegratedFGD);

        
        
        
        
        ENDHLSL
        
        Pass
        {
            Name"LitForward"
            Tags
            {
                    "LightMode"="UniversalForward"
            }
            Blend SrcAlpha OneminusSrcAlpha
            Zwrite off
            cull back
            HLSLPROGRAM
            #include "Assets/Sandbox/FanXingtong/PBR/Shaders/NewFXTPBRRefactor.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
           
             #pragma shader_feature _MASKMAP
            
            #pragma vertex FXTLitPassVertex
            #pragma fragment FXTLitPassFragment
     
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
                float fillEdge      : TEXCOORD7;
            };
            void Unity_RotateAboutAxis_Degrees_float(float3 In, float3 Axis, float Rotation, out float3 Out)
            {
                Rotation = radians(Rotation);
                float s = sin(Rotation);
                float c = cos(Rotation);
                float one_minus_c = 1.0 - c;

                Axis = normalize(Axis);
                float3x3 rot_mat = 
                {   one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s,
                    one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s,
                    one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c
                };
                Out = mul(rot_mat,  In);
            }

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

                //Tiling
                output.uv = input.texcoord * _Tiling.xy +_Tiling.zw;

                
                // already normalized from normal transform to WS.
                output.normalWS = normalInput.normalWS;
                output.viewDirWS = viewDirWS;
                real sign = input.tangentOS.w * GetOddNegativeScale();
                output.tangentWS = normalInput.tangentWS.xyz;
                output.bitangentWS = cross(output.normalWS,output.tangentWS) * sign;
                output.positionWS = vertexInput.positionWS;
                output.shadowCoord = GetShadowCoord(vertexInput);
                output.positionCS = vertexInput.positionCS;

                float3 worldPos = vertexInput.positionWS;
                float3 posWS0 = mul(unity_ObjectToWorld,float4(0,0,0,1)).xyz;
                float3 worldPosRelated = worldPos - posWS0 ;
                float3 worldPosX;
                float3 worldPosZ;
                Unity_RotateAboutAxis_Degrees_float(worldPosRelated,half3(0,0,1),-90,worldPosX);
                Unity_RotateAboutAxis_Degrees_float(worldPosRelated,half3(1,0,0),90,worldPosZ);
                
                //液体运动
                half wobbleX=clamp(_WobbleX,-0.5,0.5);

                
                half wobbleZ=clamp(_WobbleZ,-0.5,0.5);
                
                
                
                float3 worldPosAjustedX = wobbleX>0?
                                         lerp(worldPosRelated,worldPosX,abs(wobbleX))
                                             :lerp(worldPosRelated,-worldPosX,abs(wobbleX));

                float3 worldPosAjustedZ = wobbleZ>0?
                                         lerp(worldPosRelated,worldPosZ,abs(wobbleZ))
                                             :lerp(worldPosRelated,-worldPosZ,abs(wobbleZ));

                float proportion = abs(wobbleX)/(abs(wobbleX)+abs(wobbleZ)+0.001);
                float3 worldPosAjusted = proportion * worldPosAjustedX +(1 - proportion)*worldPosAjustedZ;
                
                output.fillEdge = worldPosAjusted.y +(- _LiquidY);
                return output;
            }
            
            
            
            half4 FXTLitPassFragment(Varyings input,bool faceing : SV_IsFrontFace) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half3 BaseColor = _BaseColor.rgb;

                half3 BackColor = half3(1.0,1.0,1.0);

                
                half flow = _Flow;
                
                
                half noise = SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,
                    input.uv* _NoiseMap_ST.xy + _NoiseMap_ST.zw * _Time.y * flow ).r;
                noise = pow(noise,0.5);
                //noise = step(0.5,noise);
                //noise = step(noise,0.5);
                
                
                //透明裁切
                // #ifdef _ALPHATEST_ON
                     //clip(alpha - _Cutoff);
                // #endif
                
                //half3 FinalColor = faceing > 0? BaseColor:BackColor;

                //法线贴图
                float4 normalRawData =  SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap,
                                    input.uv );
                
                float3 normalData = UnpackNormalScale(normalRawData,_NormalScale);

                float3 normalMapDir = mul(normalData,float3x3(input.tangentWS.xyz,
                    input.bitangentWS.xyz,input.normalWS));

                half fillData = saturate(input.fillEdge + 0.2 * noise);
                half fill = smoothstep(0.2,0.0,fillData);

                clip(fill - 0.001);
                half3 normalWS = input.normalWS;
                //half foam = fill - step(fillData,0.4);

                //half3 FinalColor = fill*_BaseColor + foam*_EdgeColor;

                half wobbleX=clamp(_WobbleX,-0.5,0.5);
                half wobbleZ=clamp(_WobbleZ,-0.5,0.5);

                float proportion = abs(wobbleX)/(abs(wobbleX)+abs(wobbleZ)+0.001);
                
                half3 topNormalDirX = wobbleX>0?
                                         lerp(half3(0,1,0),half3(-1,0,0),abs(wobbleX))
                                             :lerp(half3(0,1,0),half3(1,0,0),abs(wobbleX));
                half3 topNormalDirZ = wobbleZ>0?
                                         lerp(half3(0,1,0),half3(0,0,-1),abs(wobbleZ))
                                             :lerp(half3(0,1,0),half3(0,0,1),abs(wobbleZ));

                half3 topNormal = normalize(proportion * topNormalDirX + (1 - proportion) * topNormalDirZ);
                half3 nDirWS = faceing > 0?lerp(topNormal,normalize(normalWS),fill):topNormal;

                
                //nDirWS = normalize(nDirWS + normalMapDir);

                
                
                //pbr
                float3 albedoRGB =  _BaseColor.rgb;
                float alpha = _BaseColor.a;

                //采样MaskMap获取金属度粗糙度以及AO
                float metallic;
                float ao;
                float perceptualSmoothness;

                #ifdef  _MASKMAP

                float4 maskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap,
                                    input.uv);
                metallic = maskMap.r;
                ao = maskMap.g;
                perceptualSmoothness = maskMap.a;
                
                #else

                metallic = _Metallic;
                ao = 1.0;
                //perceptualSmoothness = _Smoothness * lerp(_SmoothnessIN,_SmoothnessOUT,fill);
                perceptualSmoothness =  faceing > 0? 1 * lerp(_SmoothnessIN,_SmoothnessOUT,fill) : _SmoothnessIN;
                
                #endif

                
                
                //PBR function
                InputDataNew inputData;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = nDirWS;
                inputData.viewDirectionWS = SafeNormalize(input.viewDirWS);
                inputData.shadowCoord=input.shadowCoord;

                //Fresnel
                float fresnel = 1 - saturate(dot(nDirWS,inputData.viewDirectionWS));
                fresnel = pow(fresnel,1.2);
                albedoRGB = lerp(albedoRGB,_EdgeColor.rgb,fresnel);
                alpha = lerp(0,alpha,fresnel);
                
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
                
               // float fresnel = 1 - saturate(dot(nDirWS,inputData.viewDirectionWS));
                half3 DirectTerm = direct_lighting.diffuse + direct_lighting.specular;
                half3 IndirectTerm = indirect_lighting.diffuse + indirect_lighting.specular;
                half3 DiffuseTerm = direct_lighting.diffuse + indirect_lighting.diffuse;
                half3 SpecularTerm = direct_lighting.specular + indirect_lighting.specular;
                half3 FinalColor = DirectTerm + IndirectTerm;
                //half3 FinalColor2 = DiffuseTerm  + IndirectTerm;
                //闪烁
                float3 posWS0 = mul(unity_ObjectToWorld,float4(0,0,0,1)).xyz;
                float distance = length(GetCameraPositionWS() - posWS0);
                float scalefactor = 1/distance;
                float2 transformfactor = half2(0.5,0.5) *(1 - scalefactor);
                float4 glitterTexture = SAMPLE_TEXTURE2D(_GlitterMap,sampler_GlitterMap,input.uv * 0.25);
                
               //  float3 glitter = saturate(dot(normalize(nDirWS + 0.5*glitterTexture.rgb),
               //      inputData.viewDirectionWS));
               // glitter = pow(glitter,50);

                float glitter2 = step(0.5,glitterTexture.rrr - 0.5);

                glitter2 = faceing>0? glitter2:0;

                
                return half4( albedoRGB ,alpha);
            }
            ENDHLSL
            
        }
        
        
        
    }

}