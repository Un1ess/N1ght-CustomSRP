Shader "distortion/HeightMask"
{
    Properties
    {
        _MainTex("_MainTex",2D) = "white"{}
        _BaseColor("Base Color",color) = (1,1,1,1)

        _DepthZoomFactor("深度缩放",range(0.001,2)) = 0.1
//        _HeightMap("HeightMap",2D) = "white"{}
        _HeightMinRange("_HeightMinRange",range(0,1)) = 0.2
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

        float _DepthZoomFactor;
        float _HeightMinRange;
        float _HeightMaxRange;

        float4 _HeightMapCenterRange;
        float _HeightMapDepth;

        float _HeightClampRange;
        CBUFFER_END

        
        

        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        
        TEXTURE2D(_MaskTex);
        SAMPLER(sampler_MaskTex);

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D_FLOAT(_HeightMap);
        SAMPLER(sampler_HeightMap);
        
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
                
                //sample depth
                float depthTex = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                float depthValue = Linear01Depth(depthTex,_ZBufferParams*_DepthZoomFactor);
                //高度处理
                float3 screenPosToWS = ReconstructWorldPos(screenUV ,depthTex);
                //screenPosToWS.y += 5.0;
                //float2 heightUV = (screenPosToWS.xz - half2(531.0,626.0)) / 500.0 * 0.5 + 0.5;
                float2 heightUV = (screenPosToWS.xz - _HeightMapCenterRange.xz) / _HeightMapCenterRange.w * 0.5 + 0.5;
                float heightSample = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, heightUV, 0).r;
                
                float minHeight = _HeightMapCenterRange.y - _HeightMapDepth;
               // float maxHeight = minHeight + heightSample * 50.0;
                float remapScreenPosWSY = (screenPosToWS.y - minHeight) / _HeightMapDepth;
                float distantBuildingDepth = step(0.55 ,depthValue);
                //return distantBuildingDepth;
                float heightRange = _HeightClampRange * (distantBuildingDepth * 3 + 1.0) / _HeightMapDepth;
               
                float heightMask =  heightRange - length(heightSample  - remapScreenPosWSY );
                heightMask = saturate(heightMask);
                // return heightMask;
                float heightRangePlus = (_HeightClampRange +1.2) * (distantBuildingDepth * 3 + 1.0) / _HeightMapDepth;
                float heightMaskPlus =  heightRangePlus - length(heightSample  - remapScreenPosWSY );
             
                //heightMask = saturate(heightMask + heightMaskPlus);
                //heightMask -= remapScreenPosWSY;
                // return heightMask;
                
                //很远处 没有烘焙高度的 建筑物
                float distantBuilding = smoothstep(0.10,0.20,depthValue);
                float skyMask = step(depthValue,0.9);//sky的部分为0
                float highBuilidngRange = smoothstep(_HeightMaxRange,_HeightMaxRange +(2.5/_HeightMapDepth),remapScreenPosWSY);
                float distantBuildingHeightMask =  distantBuildingDepth * highBuilidngRange * skyMask ;
               
                //return  distantBuildingHeightMask ;
                heightMask = saturate(heightMask + distantBuildingHeightMask);
                //return heightMask;
                float excludeFloor = smoothstep(_HeightMinRange,_HeightMinRange+(2.5/_HeightMapDepth),remapScreenPosWSY);
                heightMask = heightMask * excludeFloor;
                heightMaskPlus *=excludeFloor;
                float heightMaskPlusSmoothstep =  saturate(smoothstep(0.001,0.0450,heightMaskPlus));
                //heightMask的结果必须要接近1 否则扭曲的形状会很糊 这也是为何heightMask在经过各种模糊算法后 扭曲形状变模糊的原因
                float heightMaskSmoothStep  = saturate(smoothstep(0.001,0.012,heightMask));
                float heightMaskTemp =  saturate(smoothstep(0.001,0.09,heightMask));
                float heightMaskInverse  = saturate(smoothstep(1,0.001,heightMaskTemp));
                float newHeightMaskTest = heightMaskInverse *heightMaskSmoothStep;
                //return heightMaskInverse *heightMaskSmoothStep ;
                // return heightMaskPlusSmoothstep;
                return saturate(newHeightMaskTest + heightMaskPlusSmoothstep);
                
                
                
            }
            ENDHLSL
        }
        
    }
}