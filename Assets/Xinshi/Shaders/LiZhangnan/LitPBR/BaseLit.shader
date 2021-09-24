Shader "Lzn/Lit/BaseLit"
{
    Properties
    {
		_PBRValue("PBR Value",Range(0,1)) = 1.0
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _BaseMap("MainTex",2D)="white"{}
		_Cutoff("Alpha Cutoff",Range(0,1)) = 0.0
		_DitherAlpha("Alpha Dither",Range(0,1)) = 0.0
		_Metallic("Metallic",Range(0,1)) = 0.5
		_Smoothness("Smoothness",Range(0,1)) = 0.5
        [NoScaleOffset]_MaskMap("MaskMap",2D)="white"{}
        [NoScaleOffset][Normal]_NormalMap("NormalMap",2D)="bump"{}
        _BumpScale("NormalScale",Range(0,1))=1
		_EnvCUBE("Environment",Cube) = "white" {}
		_EmissionMap("EmissionMap",2D) = "black" {}
		[HDR]_EmissionColor("Emission Color",Color)=(0,0,0,0)
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

		HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "../Common.hlsl"
        //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        #pragma shader_feature _ADD_LIGHT_ON _ADD_LIGHT_OFF
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;float _PBRValue;
        real4 _BaseColor;
		float _Cutoff;float _DitherAlpha;
        float _BumpScale;
		float4 _NormalMap_ST;
		float4 _EnvCUBE_HDR;
		float _Metallic;
		float _Smoothness;
		float4 _EmissionColor;
        CBUFFER_END
        TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
        TEXTURE2D(_MaskMap);    SAMPLER(sampler_MaskMap);
        TEXTURE2D(_NormalMap);  SAMPLER(sampler_NormalMap);
		TEXTURECUBE(_EnvCUBE);SAMPLER(sampler_EnvCUBE); 
		TEXTURE2D(_EmissionMap);SAMPLER(sampler_EmissionMap); 

        ENDHLSL

		//Forward
        Pass
        {
			Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

			Blend One Zero
            ZWrite On
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

			struct a2v
			{
				float4 positionOS:POSITION;
				float4 normalOS:NORMAL;
				float2 texcoord:TEXCOORD;
				float4 tangentOS:TANGENT;
			};
			struct v2f
			{
				float4 positionCS   :SV_POSITION;
				float2 texcoord     :TEXCOORD0;
				float4 T2W0         : TEXCOORD1;
				float4 T2W1         : TEXCOORD2;
				float4 T2W2         : TEXCOORD3;
				float4 viewDirWS    : TEXCOORD4;
				float4 shadowcoord  : TEXCOORD5;
			};
			
			//D项 法线微表面分布函数 
			float D_Function(float NdH,float roughness)
			{
				float a2=roughness*roughness;
				float NdH2=NdH*NdH;
             
				//直接根据公式来
				float nom=a2;//分子
				float denom=NdH2*(a2-1)+1;//分母
				denom=denom*denom*PI;
				return nom/denom;
			}
			//G项子项
			float G_section(float dot,float k)
			{
				float nom=dot;
				float denom=lerp(dot,1,k);
				return nom/denom;
			}
			//G项
			float G_Function(float NdL,float NdV,float roughness)
			{
				float k=pow(1+roughness,2)/8;
				float Gnl=G_section(NdL,k);
				float Gnv=G_section(NdV,k);
				return Gnl*Gnv;
			}
			//F项 直接光
			real3 F_Function(float HdL,float3 F0)
			{
				float Fre=exp2((-5.55473*HdL-6.98316)*HdL);
				return lerp(Fre,1,F0);
			}
			//F项 间接光
			real3 IndirF_Function(float NdV,float3 F0,float roughness)
			{
				float Fre=exp2((-5.55473*NdV-6.98316)*NdV);
				return F0+Fre*saturate(1-roughness-F0);
			}
			//间接光高光 反射探针
			real3 IndirSpeCube(float3 normalWS,float3 viewWS,float roughness,float AO)
			{
				float3 reflectDirWS=reflect(-viewWS,normalWS);
				roughness=roughness*(1.7-0.7*roughness);//Unity内部不是线性 调整下拟合曲线求近似
				float MidLevel=roughness*6;//把粗糙度remap到0-6 7个阶级 然后进行lod采样
				float4 speColor=SAMPLE_TEXTURECUBE_LOD(_EnvCUBE, sampler_EnvCUBE,reflectDirWS,MidLevel);//根据不同的等级进行采样
				#if !defined(UNITY_USE_NATIVE_HDR)
				return DecodeHDREnvironment(speColor,_EnvCUBE_HDR)*AO;//用DecodeHDREnvironment将颜色从HDR编码下解码。可以看到采样出的rgbm是一个4通道的值，最后一个m存的是一个参数，解码时将前三个通道表示的颜色乘上xM^y，x和y都是由环境贴图定义的系数，存储在unity_SpecCube0_HDR这个结构中。
				#else
				return speColor.xyz*AO;
				#endif
			}
			//间接高光 曲线拟合 放弃LUT采样而使用曲线拟合
			real3 IndirSpeFactor(float roughness,float smoothness,float3 specular,float3 F0,float NdV)
			{
				#ifdef UNITY_COLORSPACE_GAMMA
					float SurReduction=1-0.28*roughness,roughness;
				#else
					float SurReduction=1/(roughness*roughness+1);
				#endif
				#if defined(SHADER_API_GLES)//Lighting.hlsl 261行
					float Reflectivity=specular.x;
				#else
					float Reflectivity=max(max(specular.x,specular.y),specular.z);
				#endif
				half GrazingTSection=saturate(Reflectivity+smoothness);
				float Fre=Pow4(1-NdV);//lighting.hlsl第501行 
				//float Fre=exp2((-5.55473*NdotV-6.98316)*NdotV);//lighting.hlsl第501行 它是4次方 我是5次方 
				return lerp(F0,GrazingTSection,Fre)*SurReduction;
			}

			real3 DirectBRDF(Light light,float3 viewDirWS,float3 normalWS,float NdV,float surf_Roughness,float3 surf_Metallic,float3 surf_Diffuse,float3 surf_Specular)
			{
				float3 lightDirWS = normalize(light.direction);
                float3 halfDirWS  = normalize(viewDirWS+lightDirWS);
				
                float NdL=max(saturate(dot(normalWS,lightDirWS)),0.000001);
                float HdV=max(saturate(dot(halfDirWS,viewDirWS)),0.000001);
                float NdH=max(saturate(dot(halfDirWS,normalWS)),0.000001);
                float LdH=max(saturate(dot(halfDirWS,lightDirWS)),0.000001);
				//直接光部分计算
				float D=D_Function(NdH,surf_Roughness);
				float G=G_Function(NdL,NdV,surf_Roughness);
				float3 F=F_Function(LdH,surf_Specular);
				float3 Specular = (D * G * F / (4 * NdL * NdV)) * light.color * NdL * UNITY_PI;
				float3 KS=F;
                float3 KD=(1-KS) * (1-surf_Metallic);
                float3 Diffuse = KD * surf_Diffuse * light.color * light.shadowAttenuation * NdL;//分母要除PI 但是积分后乘PI 就没写
				return Diffuse + Specular;
			}

            v2f vert (a2v v)
            {
                v2f o;
				o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.texcoord = TRANSFORM_TEX(v.texcoord, _BaseMap);

				float3 positionWS = TransformObjectToWorld(v.positionOS.xyz).xyz;
				//法线向量在顶点程序中为单位长，但跨三角形的线性插值会影响其长度。
				//可以通过abs(length(normalWS) - 1.0) * 10.0来检查
				float3 normalWS = normalize(TransformObjectToWorldNormal(v.normalOS.xyz));
				o.viewDirWS.w = length(GetCameraPositionWS().xyz - positionWS.xyz);
				o.viewDirWS.xyz = normalize(GetCameraPositionWS().xyz - positionWS.xyz);

				VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS.xyz, v.tangentOS);
				o.T2W0 = float4 (normalInput.tangentWS.x, normalInput.bitangentWS.x, normalInput.normalWS.x, positionWS.x);
				o.T2W1 = float4 (normalInput.tangentWS.y, normalInput.bitangentWS.y, normalInput.normalWS.y, positionWS.y);
				o.T2W2 = float4 (normalInput.tangentWS.z, normalInput.bitangentWS.z, normalInput.normalWS.z, positionWS.z);

				#ifdef _MAIN_LIGHT_SHADOWS
				o.shadowcoord = TransformWorldToShadowCoord(positionWS);
				#else
				o.shadowcoord = 0.0;
				#endif
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
				//采样所需的纹理
				real4 Albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, TRANSFORM_TEX(i.texcoord, _BaseMap)) * _BaseColor;
				clip(Albedo.a - _Cutoff);

				float4 dither = 0;//InterleavedGradientNoise(i.positionCS.xy * _Cutoff,0);
				Unity_Dither_float4(1, i.positionCS * _DitherAlpha, dither);
				clip((dither) - 0.5);


				//初始化顶点着色器传递过来的数据
				float3 normalWS = float3(0, 1, 0);
				float3 viewDirWS = SafeNormalize(i.viewDirWS.xyz);
				float3 positionWS = float3(i.T2W0.w, i.T2W1.w, i.T2W2.w);
				float3 tangentWS = float3(i.T2W0.x, i.T2W1.x, i.T2W2.x);
				float3 binormalWS = float3(i.T2W0.y, i.T2W1.y, i.T2W2.y);
				float3 interpolatedNormalWS = normalize(float3(i.T2W0.z, i.T2W1.z, i.T2W2.z));
				float2 positionSS = i.positionCS.xy /_ScreenParams.xy;
				//采样法线纹理
				float3x3 tangentTransform = float3x3(tangentWS.xyz, binormalWS.xyz, interpolatedNormalWS.xyz);
				real4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, TRANSFORM_TEX(i.texcoord, _NormalMap));
				float3 normalTS = UnpackNormalScale(normalMap, _BumpScale);
				normalTS.z = pow((1 - pow(normalTS.x, 2) - pow(normalTS.y, 2)), 0.5);//规范化法线
				normalWS = normalize(mul(normalTS, tangentTransform));
				
				float4 PBRMask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, i.texcoord);
				//处理从纹理得到的表面数据
				float surf_Metallic = PBRMask.r*_Metallic;
				float surf_AO = PBRMask.g;
				float surf_Smoothness = PBRMask.a * _Smoothness;
				float surf_Roughness = pow(1 - surf_Smoothness,2);
				float3 surf_Specular = lerp(0.04.xxx,Albedo.xyz,surf_Metallic.xxx);
				float3 surf_Diffuse = Albedo.rgb * (1 - surf_Specular);
				float3 surf_Emissive = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, i.texcoord).rgb * _EmissionColor.rgb;
				float NdV=max(saturate(dot(normalWS,viewDirWS)),0.000001);//不取0 避免除以0的计算错误

				#ifdef _MAIN_LIGHT_SHADOWS
					Light mainLight = GetMainLight(i.shadowcoord);
				#else
					Light mainLight = GetMainLight();
				#endif
                float3 directColor = DirectBRDF(mainLight,viewDirWS,normalWS,NdV, surf_Roughness, surf_Metallic, surf_Diffuse, surf_Specular);
				////多光源
				real3 multiLitColor = 0;
				//#ifdef _ADDITIONAL_LIGHTS
					uint pixelLightCount = GetAdditionalLightsCount();
					for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
					{
						Light light = GetAdditionalLight(lightIndex, positionWS);
						multiLitColor += DirectBRDF(light,viewDirWS,normalWS,NdV, surf_Roughness, surf_Metallic, surf_Diffuse, surf_Specular);
					}
				//#endif
				directColor += multiLitColor;

				//计算间接光BRDF
				//计算间接光漫反射https://blog.csdn.net/yangxuan0261/article/details/93653536/
				//首先获得使用利曼和预计算的cubemap，这里直接使用LOD7的cubemap
				float4 environment = SAMPLE_TEXTURECUBE_LOD(_EnvCUBE,sampler_EnvCUBE,reflect(-viewDirWS,normalWS),10);
				environment.rgb = DecodeHDREnvironment(environment,_EnvCUBE_HDR).rgb;
            	//return environment;
				float3 IndirKS=IndirF_Function(NdV,surf_Specular,surf_Roughness);
                float3 IndirKD=(1-IndirKS)*(1-surf_Metallic);
                float3 IndirDiffuse= environment.rgb *IndirKD*Albedo.rgb * UNITY_INV_PI;
				//间接光镜面反射
				float3 IndirSpecular = IndirSpeCube(normalWS,viewDirWS,surf_Roughness,surf_AO);
				IndirSpecular *= IndirSpeFactor(surf_Roughness,surf_Smoothness,surf_Specular,surf_Specular,NdV);
				float3 IndirectColor = IndirDiffuse + IndirSpecular;
                float4 col =1;
				col.rgb = lerp(Albedo.rgb,directColor + IndirectColor,_PBRValue.xxx) + surf_Emissive;
                return col;
            }
            ENDHLSL
        }

		//ShadowCaster
		Pass
		{

			Tags{"LightMode" = "ShadowCaster"}
			HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			half3 _LightDirection;
			struct a2v 
			{
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
				float3 normalOS     : NORMAL;
            };
			struct v2f 
			{
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };
			
			v2f vert(a2v v)
			{
				v2f o;
				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
				float3 positionWS = TransformObjectToWorld(v.positionOS.xyz).xyz;
				float3 normalWS = normalize(TransformObjectToWorldNormal(v.normalOS));
				o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS,normalWS,_LightDirection));
				#if UNITY_REVERSED_Z
				o.positionCS.z = min(o.positionCS.z,o.positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#else
				o.positionCS.z = max(o.positionCS.z,o.positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#endif
				return o;
			}

			half4 frag(v2f i) : SV_Target 
			{
				//#ifdef _ALPHATEST_ON
				real alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).a;
				clip(alpha - _Cutoff);
				//#endif
				float4 dither = 0;//InterleavedGradientNoise(i.positionCS.xy * _Cutoff,0);
				Unity_Dither_float4(1, i.positionCS * _DitherAlpha, dither);
				clip((dither) - 0.5);

                return 0;
            }
			ENDHLSL
		}

		//Depth
		Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
			
            #pragma vertex vert
            #pragma fragment frag

			struct a2v
			{
				float4 position     : POSITION;
				float2 uv     : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv           : TEXCOORD0;
				float4 positionCS   : SV_POSITION;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(a2v v)
			{
				v2f o = (v2f)0;
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
				o.positionCS = TransformObjectToHClip(v.position.xyz);
				return o;
			}
			float4 frag(v2f i) : SV_TARGET
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).a * _BaseColor.a - _Cutoff);
				float4 dither = 0;//InterleavedGradientNoise(i.positionCS.xy * _Cutoff,0);
				Unity_Dither_float4(1, i.positionCS * _DitherAlpha, dither);
				clip((dither) - 0.5);
				return 0;
			}

            ENDHLSL
        }

    }

}
