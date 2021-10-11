Shader "RTstudy/DrawHeight"
{
    Properties
    {
    }
    SubShader
    {
        Tags {  "RenderPipeline" = "UniversalPipeline"
                "RenderType"="Opaque"
                "Queue" = "Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _CurrTex_TexelSize;
        
        CBUFFER_END
        
        TEXTURE2D(_PrevTex);
        SAMPLER(sampler_PrevTex);
        TEXTURE2D(_CurrTex);
        SAMPLER(sampler_CurrTex);
        
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
            
            

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs position_inputs = GetVertexPositionInputs(v.vertex.xyz);
                o.posCS = position_inputs.positionCS;
                o.uv = v.uv;
                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //最小偏移单位
                float3 unit = float3(_CurrTex_TexelSize.xy,0);
                float2 uv = i.uv;
                float pUp = SAMPLE_TEXTURE2D(_CurrTex,sampler_CurrTex,uv + unit.zy).x;//上
                float pBottom = SAMPLE_TEXTURE2D(_CurrTex,sampler_CurrTex,uv - unit.zy).x;//下
                float pLeft = SAMPLE_TEXTURE2D(_CurrTex,sampler_CurrTex,uv - unit.xz).x;//左
                float pRight = SAMPLE_TEXTURE2D(_CurrTex,sampler_CurrTex,uv + unit.xz).x;//右
\
                float prevTex = SAMPLE_TEXTURE2D(_PrevTex,sampler_PrevTex,uv).x;
                float result = (pUp + pBottom + pLeft + pRight)/2 - prevTex;
                result *= 0.96;
                return half4(result.xxx,1.0);
            }
            ENDHLSL
        }
        
    }
}