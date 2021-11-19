Shader "SoulVisual/KawaseBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        ZWrite Off
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _KawaseOffset_Mask;  //Radius
        float _KawaseOffset_Scatter;  //Radius
        float4 _MainTex_ST;
        float4 _MainTex_TexelSize;

        //DirectionalBlur
        float3 _DirectionBlurParams;
        
        CBUFFER_END
        TEXTURE2D(_MainTex);    //sampler2D _MainTex;
        SAMPLER(sampler_MainTex);
            
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
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

         half4 applyBlur(const half4 color, const half2 uv, const half2 texelResolution, const half offset)
            {
                half4 result = color;
                
                result += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, uv + half2( offset,  offset) * texelResolution);
                result += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv + half2(-offset,  offset) * texelResolution);
                result += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv + half2(-offset, -offset) * texelResolution);
                result += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv + half2( offset, -offset) * texelResolution);
                result /= 5.0h;

                return result;
            }

        float4 BlurH(v2f input) : SV_Target
        {
            float texelSize = _MainTex_TexelSize.x;
            float2 uv = input.uv;

            // 9-tap gaussian blur on the downsampled source
            float d0 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv - float2(texelSize * 4.0, 0.0)).r);
            float d1 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv - float2(texelSize * 3.0, 0.0)).r);
            float d2 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv - float2(texelSize * 2.0, 0.0)).r);
            float d3 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv - float2(texelSize * 1.0, 0.0)).r);
            float d4 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).r);
            float d5 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv + float2(texelSize * 1.0, 0.0)).r);
            float d6 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv + float2(texelSize * 2.0, 0.0)).r);
            float d7 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv + float2(texelSize * 3.0, 0.0)).r);
            float d8 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv + float2(texelSize * 4.0, 0.0)).r);

            // float depth = max(d3, d4);
            // depth = max(depth, d5);

            float depth = d0 * 0.01621622 + d1 * 0.05405405 + d2 * 0.12162162 + d3 * 0.19459459
                + d4 * 0.22702703
                + d5 * 0.19459459 + d6 * 0.12162162 + d7 * 0.05405405 + d8 * 0.01621622;

            return float4(depth, 0, 0, 1);
        }
        
        float4 BlurV(v2f input) : SV_Target
        {
            float texelSize = _MainTex_TexelSize.y;
            float2 uv = input.uv;

            // Optimized bilinear 5-tap gaussian on the same-sized source (9-tap equivalent)
            float d0 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv - float2(0.0, texelSize * 3.23076923)).r);
            float d1 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv - float2(0.0, texelSize * 1.38461538)).r);
             float d2 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).r);
            float d3 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv + float2(0.0, texelSize * 1.38461538)).r);
            float d4 = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                         uv + float2(0.0, texelSize * 3.23076923)).r);

            
            float depth = d0 * 0.07027027 + d1 * 0.31621622
                + d2 * 0.22702703
                + d3 * 0.31621622 + d4 * 0.07027027;

            return float4(depth, 0, 0, 1);
        }
        
        ENDHLSL
         Pass
        {
            Name "Extend"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment ExtendHeightMask
            float4 ExtendHeightMask(v2f input):SV_Target
            {
                float2 uv = input.uv;
                float maskTex = (SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).r);
                for(int i = 1;i<= 3;i++)
                 {
                      half p1Down = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv +half2(0, 1* i * _MainTex_TexelSize.y)).r;
                     maskTex = max(p1Down,maskTex);
                 }
                
                // return maskTex;
                for(int i = 1;i<= 6;i++)
                {
                     half p1Up = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv -half2(0, 2* i * _MainTex_TexelSize.y)).r;
                    
                    maskTex = max(p1Up,maskTex );
                    //maskTex -= 0.5;
                }
               //maskTex *= 1 -screenUV.y;
                
                for(int j = 1;j<=3;j++)
                {
                    half pLeft = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv - half2(j * _MainTex_TexelSize.x,0)).r;
                    maskTex = max(pLeft,maskTex);
                }
                
                for(int j = 1;j<=3;j++)
                {
                    half pRight = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv + half2(j * _MainTex_TexelSize.x,0)).r;
                    maskTex = max(pRight,maskTex);
                }
            return  float4(maskTex, 0, 0, 1);
            }
            
            ENDHLSL
        }
        
        Pass
        {
            Name "kawaseBlurMask"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


           

            half4 frag (const v2f input) : SV_Target
            {
                const half2 texelResolution = _MainTex_TexelSize.xy;    //_TexelSize:纹素大小
                const half2 uv = input.uv;
                half4 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, uv);
                color = applyBlur(color, uv, texelResolution, _KawaseOffset_Mask);
                return color;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "kawaseBlurScatter"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


           

            half4 frag (const v2f input) : SV_Target
            {
                const half2 texelResolution = _MainTex_TexelSize.xy;    //_TexelSize:纹素大小
                const half2 uv = input.uv;
                half4 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, uv);
                color = applyBlur(color, uv, texelResolution, _KawaseOffset_Scatter);
                return color;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "DirectionalBlur"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            #define _Iteration _DirectionBlurParams.x
	        #define _Direction _DirectionBlurParams.yz
            
            half4 DirectionalBlur(float2 uv)
	        {
		        half4 color = half4(0.0, 0.0, 0.0, 0.0);

		        for (int k = -_Iteration; k < _Iteration; k++)
		        {
			        color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - _Direction * k);
		        }
		        half4 finalColor = color / (_Iteration * 2.0);

		        return finalColor;
	        }

            half4 frag (const v2f input) : SV_Target
            {
                return DirectionalBlur(input.uv);
            }
            
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
        
       
    }
}