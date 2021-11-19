Shader "distortion/Distortion"
{
    Properties
    {
        _MainTex("_MainTex",2D) = "white"{}
        _PrevColorTex("_PrevColorTex",2D) = "white"{}
//        _PrevTexWeight("_PrevTexWeight",range(0,1)) = 0.965
//        _DistortionTex ("DistortionTex", 2D) = "bump" {}
//        _DistortionTexTiling ("_DistortionTexTiling", range(0.1,10)) = 1
//        _DistortionTexTiling2 ("全屏幕扭曲贴图采样Tiling值", range(0.1,10)) = 1
//        _BaseColor("Base Color",color) = (1,1,1,1)
//        _BlurDirection("_BlurDirection",vector) = (0,0,0,0)
//        _DistortNoiseWeight("_DistortNoiseWeight",range(0,1)) = 0.5
//        _DistortInt("扭曲强度",float) = 1
//        _MaskNoiseTex("_MaskNoiseTex",2D) = "white"{}
//        _MaskNoiseTexTiling ("_MaskNoiseTexTiling", range(0.1,10)) = 1
//        _DepthZoomFactor("深度缩放",range(0.001,2)) = 0.1
//        _DepthMin1("_DepthMin1",range(0,1)) = 0.4
//        _DepthMax1("_DepthMax1",range(0,1)) = 0.8
//        _DepthMin2("_DepthMin2",range(0,1)) = 0.4
//        _DepthMax2("_DepthMax2",range(0,1)) = 0.8
//        [HDR]_DistortRimColor("_DistortRimColor",color) = (1,0,0,1)
//        [HDR]_DistantColor("_DistantColor",color) = (0,0,1,1)
        
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
        float _DistortionTexTiling2;
        float _DistortionTexTiling_Mask;//针对HeightMask的扭曲Tiling
        float _PrevTexWeight;
        float _MaskNoiseTexTiling;
        float _DepthZoomFactor;
        //控制远处深度范围
        float _DepthMin1,_DepthMin2;
        float _DepthMax1,_DepthMax2;

        //控制近处深度范围
        float _NearbyDepthMin1;
        float _NearbyDepthMax;
        float _NearbyDepthMin2;
        
        float4 _DistortRimColor;
        float4 _DistortFloorColor;
        float4 _SkyRimColor;
        float4 _DistantColor;
        
        float _HeightMinRange;
        float4 _MaskTex_TexelSize;
        float _SpotsNoiseTilingWS;
        
        //bakeheight传入
        float4 _HeightMapCenterRange;
        float _HeightMapDepth;

        //FloorNoise smoothStepRange
        float _SpotsNoiseRangeMin;
        float _SpotsNoiseRangeMax;

        float _ColorNoiseTiling;
        float4 _BuildingColor;

        //修正鬼影问题
        float4x4 _ClipToLastClip;
        
        CBUFFER_END

        TEXTURE2D(_PrevColorTex);
        SAMPLER(sampler_PrevColorTex);

        TEXTURE2D(_LastRT);
        SAMPLER(sampler_LastRT);
        
        TEXTURE2D(_DistortionTex);    //sampler2D _MainTex;
        SAMPLER(sampler_DistortionTex);

        TEXTURE2D(_CameraOpaqueTexture);
        SAMPLER(sampler_CameraOpaqueTexture);

        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        
        TEXTURE2D(_HeightMaskTex);
        SAMPLER(sampler_HeightMaskTex);

        TEXTURE2D(_HeightMaskScatter);
        SAMPLER(sampler_HeightMaskScatter);

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_MaskNoiseTex);
        SAMPLER(sampler_MaskNoiseTex);

        TEXTURE2D(_SpotsNoiseTex);
        SAMPLER(sampler_SpotsNoiseTex);

        TEXTURE2D(_ColorNoiseTex);
        SAMPLER(sampler_ColorNoiseTex);
        
        TEXTURE2D(_GalaxyTex);
        SAMPLER(sampler_GalaxyTex);
        
        TEXTURE2D(_CameraNormalsTexture);
        SAMPLER(sampler_CameraNormalsTexture);

        
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

            
            float4 ComputeClipSpacePosition3(float2 positionNDC, float deviceDepth)
            {
                #if defined(SHADER_API_GLCORE) || defined (SHADER_API_GLES) || defined (SHADER_API_GLES3)
					deviceDepth = deviceDepth * 2 - 1;
                #endif

                float4 positionCS = float4(positionNDC * 2.0 - 1.0, deviceDepth, 1.0);
                return positionCS;
            }

            float2 GetHistoryUV(float2 uv, float depth, float volumetricDepth)
            {
                // depth = max(depth, volumetricDepth);
                float4 curClip = ComputeClipSpacePosition3(uv, depth);
                float4 lastClip = mul(_ClipToLastClip, curClip);
                // return float2(volumetricDepth, 0);
                return (lastClip.xy / lastClip.w + 1.0) * 0.5;
            }

            
            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs position_inputs = GetVertexPositionInputs(v.vertex.xyz);
                o.posCS = position_inputs.positionCS;
                o.uv = v.uv;
                o.screenPos =  ComputeScreenPos(o.posCS);
                
                return o;
            }

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

            half4 frag (v2f i) : SV_Target
            {
                //ScreenUV
                //posCS在进入的片元着色器后，xy分量代表的是视口像素的坐标位置
                //float2 screenUV = i.posCS.xy / _ScreenParams.xy;
                float2 screenUV = i.screenPos.xy / i.posCS.w;
                float aspectHdivideW = _ScreenParams.y / _ScreenParams.x;
                float2 screenUVAspect = float2(screenUV.x,screenUV.y * aspectHdivideW);

                
                
                //sample distort
                float2 distortTexUV =  screenUVAspect  + _Time.x * 0.01;
                float2 distortTexUV2 =  screenUVAspect   -_Time.x * 0.08;
                float2 distortTexUV_FullScreen =  screenUVAspect * _DistortionTexTiling2 -_Time.x * 0.08;
                float4 sampleDistortionTex =  SAMPLE_TEXTURE2D(_DistortionTex,sampler_DistortionTex,distortTexUV * _DistortionTexTiling);
                float4 sampleDistortionTex2 =  SAMPLE_TEXTURE2D(_DistortionTex,sampler_DistortionTex,distortTexUV2 *(_DistortionTexTiling_Mask) );
                float4 sampleDistortionTex_FullSreen = SAMPLE_TEXTURE2D(_DistortionTex,sampler_DistortionTex,distortTexUV_FullScreen);
                float4 sampleDistortionTex_ColorDistort = SAMPLE_TEXTURE2D(_ColorNoiseTex,sampler_ColorNoiseTex,screenUVAspect *_ColorNoiseTiling - _Time *0.02);
                float4 sampleDistortionTex_DistortRimColor = SAMPLE_TEXTURE2D(_ColorNoiseTex,sampler_ColorNoiseTex,screenUVAspect * 0.56 - _Time *0.005);
                //return half4(sampleDistortionTex_ColorDistort.xyz,1.0);
                float3 distortTex = UnpackNormalScale(sampleDistortionTex,1).xyz;
                float3 distortTex2 = UnpackNormalScale(sampleDistortionTex2,1).xyz;
                float3 distortTex_FullScreen = UnpackNormalScale(sampleDistortionTex_FullSreen,1).xyz;
                distortTex = normalize(distortTex);
                distortTex2 = normalize(distortTex2);
                distortTex_FullScreen = normalize(distortTex_FullScreen);
                float2 blurDirection = normalize(_BlurDirection);
                float2 distortDir_Prev = lerp(blurDirection,distortTex.xy,_DistortNoiseWeight) * length(_BlurDirection);
                float2 distortDir_Mask = lerp(blurDirection,distortTex2.xy,1) * length(_BlurDirection);
                float2 distortDir_FullScreen = lerp(blurDirection,distortTex_FullScreen.xy,_DistortNoiseWeight) * length(_BlurDirection);
                
                half2 maskTexDistortUV = screenUV + distortDir_Mask *0.001;
                half2 maskScatterDistortUV = screenUV + distortDir_Mask *0.0001;
                half maskTex = SAMPLE_TEXTURE2D(_HeightMaskTex,sampler_HeightMaskTex,maskTexDistortUV).r;
                half maskTex_Nodistort = SAMPLE_TEXTURE2D(_HeightMaskTex,sampler_HeightMaskTex,screenUV).r;
                half maskScatterText = SAMPLE_TEXTURE2D(_HeightMaskScatter,sampler_HeightMaskScatter,maskScatterDistortUV).r;
                // return maskTex_Nodistort;
                
                 //sample depth
                half2 depthDistortUV = screenUV + distortDir_Prev *0.0005;
                float depthTex = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                float depthValue = Linear01Depth(depthTex,_ZBufferParams * _DepthZoomFactor);
                
                //获取上一帧屏幕空间UV
                float2 lastScreenUV = GetHistoryUV(screenUV, depthTex, i.posCS.z);
                
                float depth1 = smoothstep(_DepthMin1,_DepthMax1,depthValue);
                float depth2 = smoothstep(_DepthMin2,_DepthMax2,depthValue);
                float distantValue = depth1 - depth2;
                // return distantValue;

                float nearbyDepth1 = smoothstep(_NearbyDepthMin1,_NearbyDepthMax,depthValue);
                float nearbyDepth2 = smoothstep(_NearbyDepthMax,_NearbyDepthMin2,depthValue);
                float nearbyDepth = nearbyDepth1 - nearbyDepth2;
                
                
                //ScreenPos --> WorldPos
                float3 screenPosToWS = ReconstructWorldPos(screenUV ,depthTex);
                float minHeight = _HeightMapCenterRange.y - _HeightMapDepth;
                float remapScreenPosWSY = (screenPosToWS.y - minHeight) /_HeightMapDepth;
                //之后或许可以加偏移值
                float2 noiseFloorUV = screenPosToWS.xz /_SpotsNoiseTilingWS  *0.5 +0.5;
                float noiseFloor = SAMPLE_TEXTURE2D(_SpotsNoiseTex,sampler_SpotsNoiseTex,noiseFloorUV).r;
                

                //Galaxy
                float3 galaxyTex = SAMPLE_TEXTURE2D(_GalaxyTex,sampler_GalaxyTex,screenUV * 0.8 ).rgb;
                // return half4(galaxyTex,1.0);
                
                // return  spotsNoiseScreen;
                float includeFloor = smoothstep(_HeightMinRange+(2.5/_HeightMapDepth),_HeightMinRange,remapScreenPosWSY);
                noiseFloor *= includeFloor;
                float testDepth = smoothstep(0.025,0.003,depthValue);
                noiseFloor *= testDepth;
                noiseFloor = smoothstep(_SpotsNoiseRangeMin,_SpotsNoiseRangeMax,noiseFloor);
                // return ( noiseFloor);
                maskTex += noiseFloor;//加上地面点噪声
                 // return maskTex;

                float galaxyMask = nearbyDepth * sampleDistortionTex_ColorDistort ;
                //return galaxyMask ;
              
                
                float2 maskNoiseUV = screenUVAspect - half2(_Time.x*0.02,_Time.x * 0.2) ;
                half maskNoiseTex = SAMPLE_TEXTURE2D(_MaskNoiseTex,sampler_MaskNoiseTex,maskNoiseUV * _MaskNoiseTexTiling).r;
                half maskWithNoise = maskTex * maskNoiseTex;
                
                half maskWithNoiseForDistort = maskTex * sampleDistortionTex_DistortRimColor;
               // return maskWithNoiseForDistort;
                half mainTexDistortDir = lerp(distortDir_FullScreen,half2(0.0,0.0),maskWithNoise);
                distortDir_Prev = lerp(half2(0.0,0.0),distortDir_Prev,maskWithNoise);

                //远处天空盒部分为1，其余部分为0
                float depthValueStep = smoothstep(0.65,1,depthValue);
                float rimSkyOffsetMask = depthValueStep * maskScatterText;
                // return rimSkyOffsetMask;
                
                distortDir_Prev *= 0.001 * _DistortInt;
                float2 prevTexUV = lastScreenUV + distortDir_Prev;
                float2 mainTexUV = screenUV + mainTexDistortDir *0.0005;
                //mainTexUV *= maskTex;
                
                half depthWithNoise = distantValue * maskWithNoise;
                 // return maskWithNoise;
                
                
                //half4 col = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture, prevTexUV);
                //采样当前帧贴图时 使用未扭曲的ScreenUV
                half3 main = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, mainTexUV).xyz;
                half3 gery = dot(main,half3(0.22,0.707,0.071));
                main = gery;
                // main += depthWithNoise * _DistortRimColor;
                float3 FloorDistortColorOverlay = maskWithNoise * includeFloor * _DistortFloorColor;
                // return half4(FloorDistortColorOverlay,1.0);
                main += FloorDistortColorOverlay;
                //depthWithNoise = saturate((maskWithNoise + depthWithNoise)/2.0);
                //depthWithNoise = lerp(maskWithNoiseForDistort *0.35,maskWithNoiseForDistort,depthValue);
                // return maskWithNoiseForDistort;
                // half3 distantView = lerp(0 ,depthWithNoise * _DistortRimColor,maskTex);
                half3 distantView = lerp(distantValue * _DistantColor ,maskWithNoiseForDistort * _DistortRimColor,maskTex);
                // half3 distantView = lerp(distantValue * _DistantColor ,0,maskTex);
                // return maskWithNoiseForDistort;
                main += distantView;
                // return half4(distantView,1.0);
                main += rimSkyOffsetMask * _SkyRimColor;
                // return rimSkyOffsetMask;
                main += galaxyMask * galaxyTex * 2.6;

                half3 prev = SAMPLE_TEXTURE2D(_PrevColorTex,sampler_PrevColorTex, prevTexUV).xyz;

                prev = lerp(main,prev,maskTex);
                half3 color_Prev = lerp(main,prev,_PrevTexWeight);
                
                return half4(color_Prev.xyz,1.0);
            }
            ENDHLSL
        }
        
    }
}