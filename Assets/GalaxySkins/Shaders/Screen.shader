Shader "GalaxySkins/Screen"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MainTexA ("Texture", 2D) = "white" {}
        _MainTexB ("Texture", 2D) = "white" {}
        _MainTexC ("Texture", 2D) = "white" {}
        _MainTexD ("Texture", 2D) = "white" {}
        _MainTexE ("Texture", 2D) = "white" {}
        _MainTexF ("Texture", 2D) = "white" {}
        _MainTexG ("Texture", 2D) = "white" {}
        _MainTexH ("Texture", 2D) = "white" {}
        _MainTexI ("Texture", 2D) = "white" {}
        _MainTexJ ("Texture", 2D) = "white" {}
        _MainTexK ("Texture", 2D) = "white" {}
        _MainTexL ("Texture", 2D) = "white" {}
        _MainTexM ("Texture", 2D) = "white" {}
        _MainTexN ("Texture", 2D) = "white" {}
        _MainTexO ("Texture", 2D) = "white" {}
        _MainTexP ("Texture", 2D) = "white" {}
        _BaseColor("Base Color",color) = (1,1,1,1)
        _BumpMap("法线贴图",2D)="bump"{}
    }
    SubShader
    {
        Tags {  "RenderPipeline" = "UniversalPipeline"
                "RenderType"="Opaque"
                "Queue" = "Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _BumpMap_ST;
        half4 _BaseColor;
        CBUFFER_END
        
        TEXTURE2D(_MainTex);    //sampler2D _MainTex;
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_BumpMap);    SAMPLER(sampler_BumpMap);

        
        TEXTURE2D(_MainTexA);    SAMPLER(sampler_MainTexA);
        TEXTURE2D(_MainTexB);    SAMPLER(sampler_MainTexB);
        TEXTURE2D(_MainTexC);    SAMPLER(sampler_MainTexC);
        TEXTURE2D(_MainTexD);    SAMPLER(sampler_MainTexD);
        TEXTURE2D(_MainTexE);    SAMPLER(sampler_MainTexE);
        TEXTURE2D(_MainTexF);    SAMPLER(sampler_MainTexF);
        TEXTURE2D(_MainTexG);    SAMPLER(sampler_MainTexG);
        TEXTURE2D(_MainTexH);    SAMPLER(sampler_MainTexH);
        TEXTURE2D(_MainTexI);    SAMPLER(sampler_MainTexI);
        TEXTURE2D(_MainTexJ);    SAMPLER(sampler_MainTexJ);
        TEXTURE2D(_MainTexK);    SAMPLER(sampler_MainTexK);
        TEXTURE2D(_MainTexL);    SAMPLER(sampler_MainTexL);
        TEXTURE2D(_MainTexM);    SAMPLER(sampler_MainTexM);
        TEXTURE2D(_MainTexN);    SAMPLER(sampler_MainTexN);
        TEXTURE2D(_MainTexO);    SAMPLER(sampler_MainTexO);
        TEXTURE2D(_MainTexP);    SAMPLER(sampler_MainTexP);

        

        SAMPLER(sampler_linear_repeat);
        ENDHLSL
        

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS         : NORMAL;               
                float4 tangentOS        : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 posCS : SV_POSITION;
                float4 screenPos : TEXCOORD1;
                float3 viewDirWS        : TEXCOORD2;
                float3 normalWS         : TEXCOORD3;
                float3 positionWS       : TEXCOORD4;          
                float3 tangentWS        : TEXCOORD5;
                float3 bitangentWS      : TEXCOORD6;
            };

            

            v2f vert (appdata v)
            {
                v2f o;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                VertexPositionInputs position_inputs = GetVertexPositionInputs(v.vertex.xyz);
                o.posCS = position_inputs.positionCS;
                o.positionWS = position_inputs.positionWS;
                float3 viewDirWS = GetCameraPositionWS() - position_inputs.positionWS;
                o.viewDirWS = viewDirWS;
                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = normalInput.normalWS;
                o.tangentWS = normalInput.tangentWS.xyz;
                real sign = v.tangentOS.w * GetOddNegativeScale();
                o.bitangentWS = cross(o.normalWS,o.tangentWS) * sign;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPos =  ComputeScreenPos(o.posCS);
                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float2 screenUV = i.screenPos.xy / i.posCS.w;
                
         
             

                float4 normalRawData =  SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap,
                                    i.uv * _BumpMap_ST.xy + _BumpMap_ST.zw);
                float3 normalData = UnpackNormalScale(normalRawData,1);
                float3 normalWS = mul(normalData,float3x3(i.tangentWS.xyz,
                                    i.bitangentWS.xyz,i.normalWS));
                normalWS = normalize(normalWS);
                float3 normalSS = TransformWorldToHClipDir(normalWS,true);
                float3 normalVS = TransformWorldToViewDir(normalWS,true);
                float2 DistortDir = normalSS.rg * 0.5 + 0.5;

                float2 distortUV = screenUV + DistortDir * 0.02;
                half4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, distortUV);
                col *= _BaseColor;

                half4 colTest = SAMPLE_TEXTURE2D(_MainTexP,sampler_MainTexP, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexA,sampler_MainTexA, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexB,sampler_MainTexB, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexC,sampler_MainTexC, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexD,sampler_MainTexD, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexE,sampler_MainTexE, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexF,sampler_MainTexF, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexG,sampler_MainTexG, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexH,sampler_MainTexH, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexI,sampler_MainTexI, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexJ,sampler_MainTexJ, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexK,sampler_MainTexK, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexL,sampler_MainTexL, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexM,sampler_MainTexM, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexN,sampler_MainTexN, distortUV);
                    colTest = SAMPLE_TEXTURE2D(_MainTexO,sampler_MainTexO, distortUV);
                
                return colTest;
            }
            ENDHLSL
        }
        
    }
}