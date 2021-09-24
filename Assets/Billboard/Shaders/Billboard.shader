Shader "FXT/Billboard"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("Base Color",color) = (1,1,1,1)
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
        half4 _BaseColor;
        CBUFFER_END
        
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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 posCS : SV_POSITION;
            };

            TEXTURE2D(_MainTex);    //sampler2D _MainTex;
            SAMPLER(sampler_MainTex);

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs position_inputs = GetVertexPositionInputs(v.vertex.xyz);
                //o.posCS = position_inputs.positionCS;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                float4 pivotVS = mul(UNITY_MATRIX_MV,float4(0,0,0,1));
                float4 positionVS = pivotVS + float4(v.vertex.xy,0,1);
                o.posCS = mul(UNITY_MATRIX_P,positionVS);
                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                half4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, i.uv);
                col *= _BaseColor;
                return col;
            }
            ENDHLSL
        }
        
    }
}
