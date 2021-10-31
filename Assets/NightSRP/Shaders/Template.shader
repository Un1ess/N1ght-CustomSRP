Shader "HLSLStudy/Template"
{
    Properties
    {
        _BaseColor("Base Color",color) = (1,1,1,1)
    }
    SubShader
    {
        Tags {  
                "RenderType"="Opaque"
                "Queue" = "Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Assets/NightCustomRP/ShaderLibrary/NightRPCommon.hlsl"
        CBUFFER_START(UnityPerMaterial)
        half4 _BaseColor;
        CBUFFER_END

        
        ENDHLSL
        

        Pass
        {
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
               
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
   o.           posCS =  TransformWorldToHClip(positionWS);
                o.uv = v.uv;
                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
   
                half4 col = _BaseColor;
                return col;
            }
            ENDHLSL
        }
        
    }
}