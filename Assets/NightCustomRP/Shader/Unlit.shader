Shader "NightRP/Unlit"
{
    Properties
    {
//        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("Base Color",color) = (1,1,1,1)
    }
    SubShader
    {
        Tags {  
                "RenderType"="Opaque"
                "Queue" = "Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.core@7.5.2/ShaderLibrary/API/D3D11.hlsl"

        ENDHLSL
        

        Pass
        {
            HLSLPROGRAM
            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment
            #include "UnlitPass.hlsl"
            ENDHLSL
        }
        
    }
}