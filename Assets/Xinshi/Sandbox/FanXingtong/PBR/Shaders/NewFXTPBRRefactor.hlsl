#ifndef FXT_PBR_ONEPASS_LIGHTING_INCLUDE
#define FXT_PBR_ONEPASS_LIGHTING_INCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

float Alpha(float AlbedoAplha,float4 basecolor,float cutoff)        //包含裁切情况
{
    float alpha = AlbedoAplha * basecolor.a;
    #ifdef _ALPHATEST_ON
    clip(alpha - cutoff);
    #endif

    return  alpha;
}

struct InputDataNew
{
    float3  positionWS;
    half3   normalWS;
    half3   viewDirectionWS;
    float4  shadowCoord;  
};



struct BRDFDataNew
{
    float3 diffuse;
    float3 F0;
    float perceptualRoughness;       //roughness
    float roughness;                 //roughness^2
    float3 DirectDiffuseFactor;
    float metallic;
    float grazingTerm;



};

struct DirectLighting
{
    float3 diffuse;
    float3 specular;
};

struct IndirectLighting
{
    float3 diffuse;
    float3 specular;
};


#include "SG.hlsl"
struct SGSSSData
{
    float3 ScatterAmount;
    float3 AmbientSkinColor;
    float RimPower;
    float3 RimColor;
};

inline void InitializeSGSSSData(float3 inScatterAmount,float3 inAmbientSkinColor,
        float inRimPower,float3 inRimColor,out SGSSSData outSGSSSData)
{
    outSGSSSData.ScatterAmount = inScatterAmount.rgb;
    outSGSSSData.AmbientSkinColor = inAmbientSkinColor.rgb;
    outSGSSSData.RimPower = inRimPower;
    outSGSSSData.RimColor = inRimColor.rgb;
}



inline void InitializeBRDFDataNew(float3 albedo,float perceptualSmoothness,
    float metallic,out BRDFDataNew outBRDFData)
{


    half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
    half reflectivity = 1.0 - oneMinusReflectivity;
    outBRDFData.grazingTerm = saturate(reflectivity + perceptualSmoothness);
    
    outBRDFData.diffuse = albedo ;
    outBRDFData.F0 = lerp(kDieletricSpec.rgb, albedo, metallic);
    outBRDFData.metallic = metallic;
       
    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(perceptualSmoothness);
    outBRDFData.roughness = max(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness), HALF_MIN);
    outBRDFData.DirectDiffuseFactor = (1 - outBRDFData.F0) * (1 - metallic);
}

float NDF_GGX(float3 normal,float3 halfVec,float a)         //参数a代表roughness的平方
{
    float a2 = a*a;
    float nDoth = max(saturate(dot(normal,halfVec)),0.001); //将点积结果限定在0-1不会产生影响
    float nDoth2 = pow(nDoth,2);

    float numerator = a2;
    float denominator = pow(nDoth2 * (a2 - 1.0) + 1,2) * PI; //这里分母并没有除以PI

    return numerator / denominator;
}

float3 Fresnel_Schlick(float3 hDir,float3 viewDir,float3 F0)
{
    float nDotv = max(saturate(dot(hDir,viewDir)),0.0001);
    
    return F0 + (1-F0) * pow(1 - nDotv,5);
}


//F项 间接光
real3 IndirF_Function(float NdotV,float3 F0,float roughness)

{
    float Fre=exp2((-5.55473*NdotV-6.98316)*NdotV);
    return F0+Fre*saturate(1-roughness-F0);
}

float G_section(float dot,float k)
{
    float numerator = dot;
    float denominator = lerp(dot,1,k);
    return numerator / denominator;
}

float G_function(float3 nDirWS,float3 lDirWS,float3 vDirWS,float roughness)
{
    float k = pow(1 + roughness,2)/8;   //直射光的k系数
    float nDotv = max(saturate(dot(nDirWS,vDirWS)),0.0001);
    float nDotl = max(saturate(dot(nDirWS,lDirWS)),0.0001);

    float Gnv = G_section(nDotv,k);
    float Gnl = G_section(nDotl,k);
    
    return Gnv * Gnl;
}


//间接光的高光项 — — 反射探针
real3 IndirSpeCube(BRDFDataNew brdfData,InputDataNew inputdata,float AO)

{
    float3 viewWS = inputdata.viewDirectionWS;
    float3 normalWS = inputdata.normalWS;
    float roughness = brdfData.perceptualRoughness;
    
    float3 reflectDirWS=reflect(-viewWS,normalWS);

    roughness = roughness*(1.7-0.7*roughness);//Unity内部不是线性 调整下拟合曲线求近似

    float MidLevel=roughness*6;//把粗糙度remap到0-6 7个阶级 然后进行lod采样

    float4 speColor=SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0,
        reflectDirWS,MidLevel);//根据不同的等级进行采样

    #if !defined(UNITY_USE_NATIVE_HDR)

    return DecodeHDREnvironment(speColor,
        unity_SpecCube0_HDR)*AO;
    //用DecodeHDREnvironment将颜色从HDR编码下解码。
    // 可以看到采样出的rgbm是一个4通道的值，最后一个m存的是一个参数
    // ，解码时将前三个通道表示的颜色乘上xM^y，x和y都是由环境贴图定义的系数，
    // 存储在unity_SpecCube0_HDR这个结构中。

    #else

    return speColor.xyz*AO;

    #endif

}
//间接光的高光项 — — 自定义环境贴图
real3 IndirSpeCube_Custom(BRDFDataNew brdfData,InputDataNew inputdata,float AO)

{
    float3 viewWS = inputdata.viewDirectionWS;
    float3 normalWS = inputdata.normalWS;
    float roughness = brdfData.perceptualRoughness;
    
    float3 reflectDirWS=reflect(-viewWS,normalWS);

    roughness = roughness*(1.7-0.7*roughness);//Unity内部不是线性 调整下拟合曲线求近似

    float MidLevel=roughness*6;//把粗糙度remap到0-6 7个阶级 然后进行lod采样

    float4 speColor=SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0,
        reflectDirWS,MidLevel);//根据不同的等级进行采样

    #if !defined(UNITY_USE_NATIVE_HDR)

    return DecodeHDREnvironment(speColor,
        unity_SpecCube0_HDR)*AO;
    //用DecodeHDREnvironment将颜色从HDR编码下解码。
    // 可以看到采样出的rgbm是一个4通道的值，最后一个m存的是一个参数
    // ，解码时将前三个通道表示的颜色乘上xM^y，x和y都是由环境贴图定义的系数，
    // 存储在unity_SpecCube0_HDR这个结构中。

    #else

    return speColor.xyz*AO;

    #endif

}

//间接高光 曲线拟合 放弃LUT采样而使用曲线拟合
real3 IndirSpeFactor(BRDFDataNew brdfData,float NdotV)

{       

    #ifdef UNITY_COLORSPACE_GAMMA
    float SurReduction=1-0.28*brdfData.roughness*brdfData.roughness;

    #else
    float SurReduction=1/(brdfData.roughness*brdfData.roughness+1);

    #endif

    float Fre=Pow4(1-NdotV);//lighting.hlsl第501行 
    //float Fre=exp2((-5.55473*NdotV-6.98316)*NdotV);//lighting.hlsl第501行 它是4次方 我是5次方 
    return lerp(brdfData.F0,brdfData.grazingTerm,Fre) * SurReduction;

}

half3 DirectBDRFSpecNew(BRDFDataNew brdfData, InputDataNew inputData, half3 lightDirectionWS)
{

    half3 lDirWS = normalize(lightDirectionWS);
    half3 hDirWS = normalize(lDirWS + inputData.viewDirectionWS);
    
    float nDotl = max(saturate(dot(inputData.normalWS,lDirWS)),0.0001);
    float nDotv = max(saturate(dot(inputData.normalWS,inputData.viewDirectionWS)),0.0001);

    //GGX roughness test
    float D = NDF_GGX(inputData.normalWS,hDirWS,brdfData.roughness);
    
    //Fresnel
    float3 F0 = brdfData.F0;
    float3 F_direct = Fresnel_Schlick(hDirWS,lDirWS,F0);  //直接光优化

    //G项
    float G  = G_function(inputData.normalWS,lDirWS ,inputData.viewDirectionWS,brdfData.roughness);
    return D * G * F_direct / (4 * nDotl * nDotv);
    //return D * G  / (4 * nDotl * nDotv);
    //return  F_direct;
}

//已弃用
float3 PBRLightingDirect(BRDFDataNew brdfData, half3 lightColor, half3 lightDirectionWS, InputDataNew inputData
    )
{
    half NdotL = saturate(dot(inputData.normalWS, lightDirectionWS));
    half3 radiance = lightColor * NdotL;
    float3 DirectSpecCol = DirectBDRFSpecNew(brdfData, inputData, lightDirectionWS) * PI;
    
    float3 DirectDiffCol = brdfData.DirectDiffuseFactor * brdfData.diffuse;
    return (DirectSpecCol+DirectDiffCol)* radiance;

}

float3 PBRLightingDirect_SGSSS(BRDFDataNew brdfData, half3 lightColor, half3 lightDirectionWS, InputDataNew inputData,
    SGSSSData sgsssData)
{
    half NdotL = saturate(dot(inputData.normalWS, lightDirectionWS));
    half NdotInvertL = saturate(dot(inputData.normalWS, -lightDirectionWS));
    half3 radiance = lightColor * NdotL;
    float3 DirectSpecCol = DirectBDRFSpecNew(brdfData, inputData, lightDirectionWS) * PI;
    
    float3 DirectDiffCol = brdfData.DirectDiffuseFactor * brdfData.diffuse;

    float3 SGSSSColor =  SGDiffuseLighting(inputData.normalWS,lightDirectionWS,sgsssData.ScatterAmount);
    half NdotV = saturate(dot(inputData.viewDirectionWS,inputData.normalWS));
    half Fresnel = pow(saturate(1- NdotV),sgsssData.RimPower);
    //half RimStepRange = step(0.5,Fresnel);
    half RimStepRange = smoothstep(0.4,0.6,Fresnel);
    half3 rimColor =  RimStepRange * sgsssData.RimColor;

    return (DirectSpecCol + DirectDiffCol) * lightColor * SGSSSColor +rimColor * NdotInvertL;
    

}

//已弃用
half3 PBRLightingINdirect(BRDFDataNew brdfData,InputDataNew inputData,half occlusion)
{
    float nDotv = max(saturate(dot(inputData.normalWS,inputData.viewDirectionWS)),0.0001);
    
    float3 SHCol = SampleSH(normalize(inputData.normalWS));    //获取光照探针的结果
    float3 KS_indirect = IndirF_Function(nDotv,brdfData.F0,brdfData.roughness);
    float3 KD_indirect = (1 - KS_indirect) * (1 - brdfData.metallic);
    float3 IndirectDiffCol = SHCol * KD_indirect * brdfData.diffuse * occlusion;

    float3 IndirectSpecCol = IndirSpeCube(brdfData,inputData,occlusion);
    float3 IndirectSpecFactor = IndirSpeFactor(brdfData,nDotv);
    return IndirectDiffCol + IndirectSpecFactor * IndirectSpecCol;
}


//DisneyDiffuse + SmithJoint +GGX BSDF
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
DirectLighting BSDFDirect(BRDFDataNew brdfData, InputDataNew inputData, float3 lightDirWS,
                 float3 LightColor, float3 energyCompensationTerm)
{
    DirectLighting direct_lighting;
    
    half clampedNdotV = max(saturate(dot(inputData.normalWS,inputData.viewDirectionWS)),0.001);
    half NdotL = (dot(inputData.normalWS,lightDirWS));
    half absNdotL = abs(NdotL);
    half clampedNdotL = max(saturate(dot(inputData.normalWS,lightDirWS)),0.001);
    half LdotV = (dot(lightDirWS,inputData.viewDirectionWS));
    half3 hDir = normalize(lightDirWS + inputData.viewDirectionWS);
    half NDotH = max(saturate(dot(inputData.normalWS,hDir)),0.001);
    half LDotH = max(saturate(dot(lightDirWS,hDir)),0.0001);

    
    half DisneyColor = DisneyDiffuse(clampedNdotV,absNdotL,
        LdotV,brdfData.perceptualRoughness);
    half3 DirectDiffuse = DisneyColor * PI * clampedNdotL *
        brdfData.diffuse * (1 - brdfData.metallic);
    
    half3 F = F_Schlick(brdfData.F0,LDotH);
    half DV = DV_SmithJointGGX((NDotH),absNdotL,clampedNdotV,brdfData.roughness);
    half3 FDV = F *DV;

    half3 Directspec;
    if(NdotL > 0)
    {
        Directspec = FDV * clampedNdotL * PI;
    }
    //Directspec = saturate(Directspec);//防止过曝
    Directspec *= energyCompensationTerm;

    //最后都受到灯光的影响
    DirectDiffuse *=LightColor;
    Directspec *=LightColor;
    
    direct_lighting.diffuse = DirectDiffuse;
    direct_lighting.specular = Directspec;

    return direct_lighting;
    //return  Directspec * LightColor;
}

DirectLighting BSDFDirect_SGSSS(BRDFDataNew brdfData, InputDataNew inputData, float3 lightDirWS,
                 float3 LightColor, float3 energyCompensationTerm,float3 SSSColor)
{
    DirectLighting direct_lighting;
    
    half clampedNdotV = max(saturate(dot(inputData.normalWS,inputData.viewDirectionWS)),0.0001);
    half NdotL = abs(dot(inputData.normalWS,lightDirWS));
    half absNdotL = abs(NdotL);
    half clampedNdotL = max(saturate(dot(inputData.normalWS,lightDirWS)),0.0001);
    half LdotV = (dot(lightDirWS,inputData.viewDirectionWS));
    half3 hDir = normalize(lightDirWS + inputData.viewDirectionWS);
    half NDotH = max(saturate(dot(inputData.normalWS,hDir)),0.0001);
    half LDotH = max(saturate(dot(lightDirWS,hDir)),0.0001);

    
    half DisneyColor = DisneyDiffuse(clampedNdotV,absNdotL,
        LdotV,brdfData.perceptualRoughness);
    half3 DirectDiffuse = SSSColor   *
        brdfData.diffuse * (1 - brdfData.metallic);
    
    half3 F = F_Schlick(brdfData.F0,LDotH);
    half DV = DV_SmithJointGGX((NDotH),absNdotL,clampedNdotV,brdfData.roughness);
    half3 FDV = F *DV;

    half3 Directspec;
    if(NdotL > 0)
    {
        Directspec = FDV * clampedNdotL * PI;
    }

    Directspec *= energyCompensationTerm;
    
    //最后都受到灯光的影响
    DirectDiffuse *=LightColor;
    Directspec *=LightColor;
    
    direct_lighting.diffuse = DirectDiffuse;
    direct_lighting.specular = Directspec;

    return direct_lighting;
    //return (DirectDiffuse + Directspec) * LightColor;
}

IndirectLighting BSDFIndirect(BRDFDataNew brdfData,InputDataNew inputData,float ao
    ,half diffuseFGD,half3 speclurFGD,float3 energyCompensationTerm)
{
    IndirectLighting indirect_lighting;
    
    float3 SHCol = SampleSH(normalize(inputData.normalWS));
    float3 IndirectSpecCol = IndirSpeCube(brdfData,inputData,ao);

    float3 IndirectDiffuse = SHCol * diffuseFGD * ao *
        (1 - brdfData.metallic) * brdfData.diffuse;
    float3 IndirectSpec = IndirectSpecCol * speclurFGD * energyCompensationTerm;

    indirect_lighting.diffuse = IndirectDiffuse;
    indirect_lighting.specular = IndirectSpec;
    return indirect_lighting;
    //return IndirectDiffuse + IndirectSpec;
    //return  IndirectSpec;
}

////////////////////////////////////////////////////////////////////////
float3 iridescent(float3 c, float3 nDirWS , float3 vDirWS)
{
    float k = normalize(float3(1.0,1.0,1.0));
    float t = max(dot(nDirWS,vDirWS),0) * PI *6;
    float3 v = c;
    c = v * cos(t) + cross(k,v)*sin(t) + k*dot(k,v) * (1-cos(t));

    return c;
}


// Based on GPU Gems
// Optimised by Alan Zucconi

inline float3 bump3y (float3 x, float3 yoffset)
{
    float3 y = 1 - x * x;
    y = saturate(y-yoffset);
    return y;
}
float3 spectral_zucconi6 (float w)
{
    // w: [400, 700]    纳米
    // x: [0,   1]
    float3 x = saturate((w - 400.0)/ 300.0);

    const float3 c1 = float3(3.54585104, 2.93225262, 2.41593945);
    const float3 x1 = float3(0.69549072, 0.49228336, 0.27699880);
    const float3 y1 = float3(0.02312639, 0.15225084, 0.52607955);

    const float3 c2 = float3(3.90307140, 3.21182957, 3.96587128);
    const float3 x2 = float3(0.11748627, 0.86755042, 0.66077860);
    const float3 y2 = float3(0.84897130, 0.88445281, 0.73949448);

    return
        bump3y(c1 * (x - x1), y1) +
        bump3y(c2 * (x - x2), y2) ;
}

float3 DiffractionGrating(float3 tangentWS,float3 lDirWS,float3 vDirWS,float d,float offset)
{
    float cos_thetaL = dot(lDirWS,tangentWS);
    float cos_thetaV = dot(vDirWS,tangentWS);
    float u = abs(cos_thetaL - cos_thetaV) + offset;
    if (u == 0)
    {
        return 0;
    }

    float3 color;
    for(int n=1;n<=8;n++)
    {
        float wavelength = u*d/n;
        color += spectral_zucconi6(wavelength);
    }

    color = saturate(color);

    return color;
}
////////////////////////////////////////////////////////////////////////

#endif