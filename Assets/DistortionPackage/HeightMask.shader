Shader "PG/Effect/HeightMask"
{
    Properties
    {
        _MaskColor("Mask颜色", color) = (1,0,0,1)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            half4 _MaskColor;
            float4 _HeightMapCenterRange;
            float _HeightMapDepth;
            float4 _HeightParam;

            #define _HeightOffset _HeightParam.x

            TEXTURE2D_FLOAT(_HeightMap);
            SAMPLER(sampler_HeightMap);
            TEXTURE2D_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            float3 ReconstructWorldPos(half2 screenPos, float depth)
            {
                #if defined(SHADER_API_GLCORE) || defined (SHADER_API_GLES) || defined (SHADER_API_GLES3)        // OpenGL平台 //
                    depth = depth * 2 - 1;
                #endif
                #if UNITY_UV_STARTS_AT_TOP
                screenPos.y = 1 - screenPos.y;
                #endif

                float4 raw = mul(UNITY_MATRIX_I_VP, float4(screenPos * 2 - 1, depth, 1));
                float3 worldPos = raw.rgb / raw.a;
                return worldPos;
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            float4 frag(Varyings input): SV_Target
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv);
                if(depth < 0.001)
                    return half4(1,0,0,1);
                float3 posWS = ReconstructWorldPos(input.uv, depth);
                float2 heightUV = (posWS.xz - _HeightMapCenterRange.xz) / _HeightMapCenterRange.w * 0.5 + 0.5;
                float heightSample = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, heightUV, 0).r;
                float maxHeight = _HeightMapCenterRange.y - _HeightMapDepth + heightSample * _HeightMapDepth;
                // return maxHeight;
                // return half4(heightUV, 0, 1);
                return saturate(posWS.y - maxHeight + _HeightOffset) * _MaskColor;
            }
            ENDHLSL
        }
    }
}