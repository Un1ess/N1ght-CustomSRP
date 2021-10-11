Shader "RTstudy/DrawRipple"
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
        float4 _Pos;
        
        CBUFFER_END
        
        TEXTURE2D(_SourceTex);
        SAMPLER(sampler_SourceTex);
        
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
                float2 uv = i.uv;
                float lastFrameRT  = SAMPLE_TEXTURE2D(_SourceTex,sampler_SourceTex,uv).x;
                //return half4(uv,0,1);
                float result = saturate(_Pos.z - (length(uv - _Pos.xy)/_Pos.z).xxx);
                result = result + lastFrameRT;
                return half4(result.xxx,1.0);
            }
            ENDHLSL
        }
        
    }
}