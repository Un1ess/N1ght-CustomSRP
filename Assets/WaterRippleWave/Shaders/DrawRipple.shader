Shader "RTstudy/DrawRipple"
{
    Properties
    {
        _MainTex("_MainTex",2D) = "white"
    }
    SubShader
    {
        Tags {  "RenderPipeline" = "UniversalPipeline"
                "RenderType"="Opaque"
                "Queue" = "Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _PosUV;
        float4 _PosWS;
        float3 _DeltaPosWS;
        float _ScaleMapping;
        float _Size;
        CBUFFER_END

        #define _PosCoord _PosUV.xy
        #define _Radius   _PosUV.z
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex_linear_clamp);
        
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
                float3 posWS2 : TEXCOORD2;
            };
            
            

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs position_inputs = GetVertexPositionInputs(v.vertex.xyz);
                o.posWS.xz = (v.uv * 2 - 1) * 25;
                o.posWS.y = position_inputs.positionWS.y;
                o.posCS = position_inputs.positionCS;
                o.posWS2 = position_inputs.positionWS;
                
                o.uv = v.uv;
                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float2 uv = i.uv;
                float lastFrameRT  = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex_linear_clamp,uv).x;
                //return half4(uv,0,1);
                float result = saturate(0.2 - (length(uv - _PosCoord)).xxx);
                //result = max(result,lastFrameRT);
                result = max(result,lastFrameRT);
                result*= 0.96;
                

                //=================================
                float distance = length(i.uv - 0.5);
                float lastFrameRT2 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex_linear_clamp,
                    uv + _DeltaPosWS.xz * _ScaleMapping).x;
                float centerDraw = saturate(_Radius - distance);
                centerDraw  = max(centerDraw,lastFrameRT2);
                //防止边缘采样出错 
				float cond = step(abs(i.uv.x - 0.5), 0.499) * step(abs(i.uv.y - 0.5), 0.499);
                centerDraw = lerp(0,centerDraw,cond);
                //每次绘制都有一定的衰减 变为计算结果centerDraw的多少倍
                //这样原本被多次绘制的像素会 变为衰减倍数的指数幂
                centerDraw *= 0.9;

                //===============
                //testUV是错误的算法
                float2 testUV = (i.posWS2.xz + _DeltaPosWS.xz)*0.5 + 0.5;
                //mappingTerm才是正确的 因为此时uv范围被放缩至[-25,25]
                //所以 DeltaPosWS的值应该被缩小至原来的1/50
                //推导：DeltaPosWS = currentPos - lastPos;
                //currentPos对应到此时放缩过的uv空间下 应为currentPos /25 *0.5 + 0.5;
                //同理可得 lastPos‘ = lastPos /25 *0.5 + 0.5;
                //so, DeltaPosWS' = currentPos' - lastPos'
                //                = currentPos /25 *0.5 + 0.5 -(lastPos /25 *0.5 + 0.5)
                //                = currentPos/50+0.5 -lastPos/50 -0.5
                // 0.5相消        = (currentPos - lastPos)/50 = DeltaPosWS/50
                float3 offsetTerm = _DeltaPosWS.xyz/25.0 *0.5 ;
                //-----偏移变体
                // float height = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex_linear_clamp,
                //     i.uv + offsetTerm.xz).r;
                // float JunyuDis = max(0,_Radius - length(i.posWS.xz - 0));
                //-----WorldSpace变体
                float height = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex_linear_clamp,
                    i.uv).r;
                float JunyuDis = max(0,_Radius - length(i.posWS.xz - _PosWS.xz));
                if(JunyuDis > 0)
                {
                    height = max(JunyuDis, height);
                }
                //防止边缘采样出错 
                height = lerp(0,height,cond);
                //====================
                
                
                //return half4(result.xxx,1);
                return half4(height.xxx,1);
            }
            ENDHLSL
        }
        
    }
}