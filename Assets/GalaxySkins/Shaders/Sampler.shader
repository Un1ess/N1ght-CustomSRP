Shader "Unlit/Sampler"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MainTexA ("Texture", 2D) = "white" {}
        _MainTexB ("Texture", 2D) = "white" {}
        _MainTexC ("Texture", 2D) = "white" {}
        _MainTexD ("Texture", 2D) = "white" {}
        _MainTexE ("Texture", 2D) = "white" {}
        _MainTexF ("Texture", 2D) = "white" {}
        _MainTexG ("Texture", 2D) = "white" {}
        _MainTexH ("Texture", 2D) = "white" {}
        _MainTexI ("Texture", 2D) = "white" {}
        _MainTexJ ("Texture", 2D) = "white" {}
        _MainTexK ("Texture", 2D) = "white" {}
        _MainTexL ("Texture", 2D) = "white" {}
        _MainTexM ("Texture", 2D) = "white" {}
        _MainTexN ("Texture", 2D) = "white" {}
        _MainTexO ("Texture", 2D) = "white" {}
        _MainTexP ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _MainTexA;
            sampler2D _MainTexB;
            sampler2D _MainTexC;
            sampler2D _MainTexD;
            sampler2D _MainTexE;
            sampler2D _MainTexF;
            sampler2D _MainTexG;
            sampler2D _MainTexH;
            sampler2D _MainTexI;
            sampler2D _MainTexJ;
            sampler2D _MainTexK;
            sampler2D _MainTexL;
            sampler2D _MainTexM;
            sampler2D _MainTexN;
            sampler2D _MainTexO;
            sampler2D _MainTexP;
            sampler2D _MainTexR;
            sampler2D _MainTexS;
            sampler2D _MainTexT;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                 col = tex2D(_MainTexA, i.uv);
                 col = tex2D(_MainTexB, i.uv);
                 col = tex2D(_MainTexC, i.uv);
                 col = tex2D(_MainTexD, i.uv);
                 col = tex2D(_MainTexE, i.uv);
                 col = tex2D(_MainTexF, i.uv);
                 col = tex2D(_MainTexG, i.uv);
                 col = tex2D(_MainTexH, i.uv);
                 col = tex2D(_MainTexI, i.uv);
                 col = tex2D(_MainTexJ, i.uv);
                  col = tex2D(_MainTexK, i.uv);
                  col = tex2D(_MainTexL, i.uv);
                  col = tex2D(_MainTexM, i.uv);
                  col = tex2D(_MainTexN, i.uv);
                  col = tex2D(_MainTexO, i.uv);
                  col = tex2D(_MainTexP, i.uv);
                  col = tex2D(_MainTexR, i.uv);
                  col = tex2D(_MainTexS, i.uv);
                  col = tex2D(_MainTexT, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
