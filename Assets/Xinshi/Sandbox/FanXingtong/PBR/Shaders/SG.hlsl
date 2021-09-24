#ifndef FXT_SG_SSS_INCLUDE
#define FXT_SG_SSS_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct FSphericalGaussian
{
    float3  Axis;       //u
    float   Sharpness;  //Lamda
    float   Amplitude;  //a
};

// Normalized SG
FSphericalGaussian MakeNormalizedSG(float3 LightDir, half Sharpness)
{
    // 归一化的SG
    FSphericalGaussian SG;
    SG.Axis = LightDir; // 任意方向
    SG.Sharpness = Sharpness; // (1 / ScatterAmt.element)
    SG.Amplitude = SG.Sharpness / ( 2 * PI * exp( 1 - 2 * SG.Sharpness)); // 归一化处理
    return SG;
}

//inner product with cosine lobe
//Assumes G is normalized
float DotCosineLobe(FSphericalGaussian G,float3 N)
{
    const float muDotN = dot(G.Axis,N);
    const float c0 = 0.36;
    const float c1 = 0.25/c0;

    float eml = exp(-G.Sharpness);
    float em2l = eml*eml;
    float r1 = rcp(G.Sharpness);    //计算快速的，近似的，按分量的倒数。
    
    float scale = 1.0 + 2.0*em2l-r1;
    float bias = (eml - em2l)*r1 -em2l;

    float x = sqrt(1.0 - scale);
    float x0 = c0*muDotN;
    float x1 = c1*x;

    float n = x0+x1;
    float y = (abs(x0)<=x1) ? n*n/x :saturate(muDotN);

    return scale*y +bias;
}

//SG diffuse lighting
half3 SGDiffuseLighting(float3 N,float3 L,half3 ScatterAmt)
{
    FSphericalGaussian RedKernel = MakeNormalizedSG(L,1/max(ScatterAmt.x,0.0001));
    FSphericalGaussian GreenKernel = MakeNormalizedSG(L,1/max(ScatterAmt.y,0.0001));
    FSphericalGaussian BlueKernel = MakeNormalizedSG(L,1/max(ScatterAmt.z,0.0001));

    half3 Diffuse = half3(  DotCosineLobe(RedKernel,N),
                            DotCosineLobe(GreenKernel,N),
                            DotCosineLobe(BlueKernel,N));

    //Filmic Tone Mapping
    half3 x = max(0,Diffuse - 0.004);
    Diffuse = (x * (6.2*x + 0.5))/(x*(6.2*x + 1.7)+0.06);
    
    return Diffuse;
}

#endif