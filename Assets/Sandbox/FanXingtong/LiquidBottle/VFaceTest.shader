Shader "Fxt/VFaceTest"
{
    Properties
    {
        _BaseColor("BaseColor",Color)   = (1,1,1,1)
        _Cutoff("_Cutoff",Range(0,1))   = 0
        
        _NoiseMap("NoiseMap",2D)        = "white"{}
        
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
        float4 _BaseColor;

        float _Cutoff;
        float4 _Tiling;
        CBUFFER_END

        TEXTURE2D(_NoiseMap);       SAMPLER(sampler_NoiseMap);
        
        ENDHLSL
        
        Pass
        {
            Name"LitForward"
            Tags
            {
                    "LightMode"="UniversalForward"
            }
            AlphaToMask on
            cull off
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           
            
            
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
            };


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
                
                return output;
            }
            

            half4 FXTLitPassFragment(Varyings input,bool faceing : SV_IsFrontFace) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half3 BaseColor = _BaseColor.rgb;

                half3 BackColor = half3(1.0,1.0,1.0);
                half alpha = _BaseColor.a;

                half noise = SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,input.uv).r;
                //noise = step(0.5,noise);
                noise = step(noise,0.5);

                alpha *= noise;
                //透明裁切
                // #ifdef _ALPHATEST_ON
                     //clip(alpha - _Cutoff);
                // #endif
                
                half3 FinalColor = faceing > 0? BaseColor:BackColor;
                return half4(FinalColor,alpha);
            }
            ENDHLSL
            
        }
        
        
        
    }

}