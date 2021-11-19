Shader "distortion/DistortionHeightFetchCopyDepth"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "" {}
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        ZWrite Off
        ZTest Always
        Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        SAMPLER(sampler_LinearClamp);
        float4 _MainTex_TexelSize;

        struct appdata
        {
            float4 vertex : POSITION;
            float4 texcoord : TEXCOORD0;
        };

        struct v2f
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        v2f vert(appdata v)
        {
            VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
            v2f o;
            o.pos = vertexInput.positionCS;
            o.uv = v.texcoord.xy;
            return o;
        }

        float4 frag(v2f i) : SV_Target
        {
            float depth = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).r;
            float2 coordClamp = step(abs(i.uv.x - 0.5),0.49) * step(abs(i.uv.y - 0.5),0.49);
            depth = lerp(0,depth,coordClamp);
            return float4(depth, 0, 0, 1);
        }

        // void Extend()
        // {
        //     int upExtend = 10;
        //     int downExtend = 10;
        //     int leftRightExtend = 10;
        //
        //     float depthMax = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).r;
        //     for (int i = 0; i < upExtend; i++)
        //     {
        //         float depth = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + float2(0, i + 1)).r;
        //         depthMax = max(depth, depthMax);
        //     }
        // }

        float4 ExtendH(v2f input) : SV_Target
        {
            float texelSize = _MainTex_TexelSize.x;
            float2 uv = input.uv;
            float d3 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv - float2(texelSize * 1.0, 0.0)).r);
            float d4 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv).r);
            float d5 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv + float2(texelSize * 1.0, 0.0)).r);

            float depth = max(d3, d4);
            depth = max(depth, d5);
            return float4(depth, 0, 0, 1);
        }
        
        float4 BlurH(v2f input) : SV_Target
        {
            float texelSize = _MainTex_TexelSize.x;
            float2 uv = input.uv;

            // 9-tap gaussian blur on the downsampled source
            float d0 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv - float2(texelSize * 4.0, 0.0)).r);
            float d1 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv - float2(texelSize * 3.0, 0.0)).r);
            float d2 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv - float2(texelSize * 2.0, 0.0)).r);
            float d3 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv - float2(texelSize * 1.0, 0.0)).r);
            float d4 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv).r);
            float d5 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv + float2(texelSize * 1.0, 0.0)).r);
            float d6 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv + float2(texelSize * 2.0, 0.0)).r);
            float d7 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv + float2(texelSize * 3.0, 0.0)).r);
            float d8 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv + float2(texelSize * 4.0, 0.0)).r);

            // float depth = max(d3, d4);
            // depth = max(depth, d5);

            float depth = d0 * 0.01621622 + d1 * 0.05405405 + d2 * 0.12162162 + d3 * 0.19459459
                + d4 * 0.22702703
                + d5 * 0.19459459 + d6 * 0.12162162 + d7 * 0.05405405 + d8 * 0.01621622;

            return float4(depth, 0, 0, 1);
        }

        float4 EntendV(v2f input) : SV_Target
        {
            float texelSize = _MainTex_TexelSize.y;
            float2 uv = input.uv;

            // Optimized bilinear 5-tap gaussian on the same-sized source (9-tap equivalent)
            float d2 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv).r);
            float d3 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv + float2(0.0, texelSize * 1)).r);
            float d4 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv - float2(0.0, texelSize * 1)).r);

            
            float depth = max(d3, d4);
            depth = max(depth, d2);

            return float4(depth, 0, 0, 1);
        }

        float4 BlurV(v2f input) : SV_Target
        {
            float texelSize = _MainTex_TexelSize.y;
            float2 uv = input.uv;

            // Optimized bilinear 5-tap gaussian on the same-sized source (9-tap equivalent)
            float d0 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv - float2(0.0, texelSize * 3.23076923)).r);
            float d1 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv - float2(0.0, texelSize * 1.38461538)).r);
             float d2 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv).r);
            float d3 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv + float2(0.0, texelSize * 1.38461538)).r);
            float d4 = (SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp,
                                         uv + float2(0.0, texelSize * 3.23076923)).r);

            
            float depth = d0 * 0.07027027 + d1 * 0.31621622
                + d2 * 0.22702703
                + d3 * 0.31621622 + d4 * 0.07027027;

            return float4(depth, 0, 0, 1);
        }

        float4 ExtendHeightMask(v2f input):SV_Target
        {
            float2 uv = input.uv;
            float maskTex = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).r);
            for(int i = 1;i<= 5;i++)
                 {
                      half p1Down = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv +half2(0, 1* i * _MainTex_TexelSize.y)).r;
                     maskTex = max(p1Down,maskTex);
                 }
                
                // return maskTex;
                for(int i = 1;i<= 10;i++)
                {
                     half p1Up = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv -half2(0, 2* i * _MainTex_TexelSize.y)).r;
                    maskTex = max(p1Up,maskTex );
                }
               //maskTex *= 1 -screenUV.y;
                
                for(int j = 1;j<=5;j++)
                {
                    half pLeft = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv - half2(j * _MainTex_TexelSize.x,0)).r;
                    maskTex = max(pLeft,maskTex);
                }
                
                for(int j = 1;j<=5;j++)
                {
                    half pRight = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv + half2(j * _MainTex_TexelSize.x,0)).r;
                    maskTex = max(pRight,maskTex);
                }
            return  float4(maskTex, 0, 0, 1);
        }
        ENDHLSL

        Pass
        {
            Name "Copy"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }

        Pass
        {
            Name "Extend Horizontal"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment ExtendH
            ENDHLSL
        }

        Pass
        {
            Name "Extend Vertical"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment EntendV
            ENDHLSL
        }
        
         Pass
        {
            Name "Blur Horizontal"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment BlurH
            ENDHLSL
        }

        Pass
        {
            Name "Blur Vertical"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment BlurV
            ENDHLSL
        }
        Pass
        {
            Name "ExtendHeightMask"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment ExtendHeightMask
            ENDHLSL
        }
    }
    

    FallBack Off
}