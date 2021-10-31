#ifndef NIGHTRP_UNLIT_PASS_INCLUDED
#define NIGHTRP_UNLIT_PASS_INCLUDED

#include "../ShaderLibrary/NightRPCommon.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseColor;
CBUFFER_END

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

//顶点着色器
v2f UnlitPassVertex (appdata v)
{
   v2f o;
   float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
   o.posCS =  TransformWorldToHClip(positionWS);
   o.uv = v.uv;
                
   return o;
}


//片元着色器
float4 UnlitPassFragment(v2f i) : SV_Target
{
   return _BaseColor;
}

#endif