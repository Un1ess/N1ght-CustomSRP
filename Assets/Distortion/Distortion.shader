Shader "distortion/Distortion"
{
    Properties
    {
        _MainTex("_MainTex",2D) = "white"{}
        _PrevColorTex("_PrevColorTex",2D) = "white"{}
        _PrevTexWeight("_PrevTexWeight",range(0,1)) = 0.965
        _DistortionTex ("DistortionTex", 2D) = "bump" {}
        _DistortionTexTiling ("_DistortionTexTiling", range(0.1,10)) = 1
        _BaseColor("Base Color",color) = (1,1,1,1)
        _BlurDirection("_BlurDirection",vector) = (0,0,0,0)
        _DistortNoiseWeight("_DistortNoiseWeight",range(0,1)) = 0.5
        _DistortInt("扭曲强度",float) = 1
        _MaskTex("_MaskTex",2D) = "white"{}
        _MaskNoiseTex("_MaskNoiseTex",2D) = "white"{}
        _MaskNoiseTexTiling ("_MaskNoiseTexTiling", range(0.1,10)) = 1
        _DepthZoomFactor("深度缩放",range(0.001,1)) = 0.1
    }
    SubShader
    {
        Tags {  "RenderPipeline" = "UniversalPipeline"
                "RenderType"="Transparent"
                "Queue" = "Transparent" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float2 _BlurDirection;
        float _DistortNoiseWeight;
        float _DistortInt;
        float _DistortionTexTiling;
        float _PrevTexWeight;
        float _MaskNoiseTexTiling;
        float _DepthZoomFactor;
        CBUFFER_END

        TEXTURE2D(_PrevColorTex);
        SAMPLER(sampler_PrevColorTex);
        
        TEXTURE2D(_DistortionTex);    //sampler2D _MainTex;
        SAMPLER(sampler_DistortionTex);

        TEXTURE2D(_CameraOpaqueTexture);
        SAMPLER(sampler_CameraOpaqueTexture);

        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        
        TEXTURE2D(_MaskTex);
        SAMPLER(sampler_MaskTex);

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_MaskNoiseTex);
        SAMPLER(sampler_MaskNoiseTex);
        
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
                float4 screenPos : TEXCOORD1;
            };

            

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs position_inputs = GetVertexPositionInputs(v.vertex.xyz);
                o.posCS = position_inputs.positionCS;
                o.uv = v.uv;
                o.screenPos =  ComputeScreenPos(o.posCS);
                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                //posCS在进入的片元着色器后，xy分量代表的是视口像素的坐标位置
                //float2 screenUV = i.posCS.xy / _ScreenParams.xy;
                float2 screenUV = i.screenPos.xy / i.posCS.w;
                float aspectHdivideW = _ScreenParams.y / _ScreenParams.x;
                float2 screenUVAspect = float2(screenUV.x,screenUV.y * aspectHdivideW);
                float2 distortTexUV =  screenUVAspect + _Time.x * 0.1;
                float4 sampleDistortionTex =  SAMPLE_TEXTURE2D(_DistortionTex,sampler_DistortionTex,distortTexUV * _DistortionTexTiling);
                float3 distortTex = UnpackNormalScale(sampleDistortionTex,1).xyz;
                distortTex = normalize(distortTex);
                float2 blurDirection = normalize(_BlurDirection);
                float2 distortDir = lerp(blurDirection,distortTex.xy,_DistortNoiseWeight) * length(_BlurDirection);
                half maskTex = SAMPLE_TEXTURE2D(_MaskTex,sampler_MaskTex,screenUV).r;
                float2 maskNoiseUV = screenUVAspect + _Time.x * 0.2;
                half maskNoiseTex = SAMPLE_TEXTURE2D(_MaskNoiseTex,sampler_MaskNoiseTex,maskNoiseUV * _MaskNoiseTexTiling).r;
                maskTex *= maskNoiseTex;
                distortDir = lerp(half2(0.0,0.0),distortDir,maskTex);
                //trick xy分量的影响程度不同
                //distortDir *= rcp(_ScreenParams.xy);
                //其实与一个暴露float值相乘区别也不大
                distortDir *= 0.001 * _DistortInt;
                
                float2 mainTexUV = screenUV + distortDir;
                //mainTexUV *= maskTex;
                //sample depth
                float depthTex = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                float depth = Linear01Depth(depthTex,_ZBufferParams*_DepthZoomFactor);
                
                
                half4 col = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture, mainTexUV);
                half3 main = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, screenUV).xyz;
                half3 prev = SAMPLE_TEXTURE2D(_PrevColorTex,sampler_PrevColorTex, mainTexUV).xyz;

                half3 color = lerp(main,prev,_PrevTexWeight);
                
                
                //col *= _BaseColor;
                //return half4(i.posCS.xxx/1920.0 ,1);
                //return half4(screenUV.xxx ,1);
                //return half4(maskTex.xxx,1);
                return half4(depth.xxx,1);
                //return half4(distortTex,1.0);
                return half4(color.xyz,1.0);
            }
            ENDHLSL
        }
        
    }
}