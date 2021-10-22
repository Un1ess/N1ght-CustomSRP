Shader "RTstudy/ShowRippleWSRT"
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
        float3 _MainTriggerPosWS;
        float _Size;
        CBUFFER_END
        
        TEXTURE2D(_MainTex);    //sampler2D _MainTex;
        SAMPLER(sampler_MainTex);
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
                float3 posWS : TEXCOORD1;
            };

            

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs position_inputs = GetVertexPositionInputs(v.vertex.xyz);
                o.posCS = position_inputs.positionCS;
                o.posWS = position_inputs.positionWS;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float2 center = float2(10,10);
                //float2 rippleUV = (i.posWS.xz -  _MainTriggerPosWS.xz)/ 25 *0.5 +0.5;
                float2 rippleUV = (i.posWS.xz -  0)/ _Size *0.5 +0.5;
                half4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, rippleUV);
                //half4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, i.uv);
                col *= _BaseColor;
                return col;
            }
            ENDHLSL
        }
        
    }
}