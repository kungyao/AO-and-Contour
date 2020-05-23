Shader "MyShader/countour"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _MyCameraPosition("Camera Potition", Vector) = (0, 0, 0, 0)
        _Threshold("Contour Threshold", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 contourParam : TEXCOORD1;
            };

            sampler2D _MainTex;
            float _Threshold;
            float4 _MainTex_ST;
            float4 _MyCameraPosition;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // inverse view direction
                float3 viewDir = normalize(_MyCameraPosition - v.vertex);
                // world normal
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);

                o.contourParam = float3(1, 1, 1);
                // x : normal_dot_view
                // y : t_kr
                // z : t_dwkr
                float normal_dot_view = dot(worldNormal, viewDir);
                o.contourParam.x = abs(normal_dot_view);
                //if (normal_dot_view >= 0)
                //{
                //    o.contourParam.x = normal_dot_view;
                //    if (normal_dot_view > _Threshold)
                //    {
                //        // calculate
                //        ;
                //    }
                //}

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = fixed4(0,0,0,0);
                if (i.contourParam.x < _Threshold)
                    col = fixed4(1, 0, 0, 1);
                else
                    col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
        }
    }
}