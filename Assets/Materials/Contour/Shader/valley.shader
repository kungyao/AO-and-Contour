Shader "MyShader/valley"
{
    Properties
    {
        //_ValleyTexture("Valley Texture", 2D) = "white" {}
        _MyCameraPosition("Camera Potition", Vector) = (0, 0, 0, 0)
        _Threshold("Contour Threshold", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                // 輸出位置 一定要
                float4 vertex : SV_POSITION;
                float normal_dot_view : TEXCOORD0;
            };

            float4 _MyCameraPosition;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                // o.normal = UnityObjectToWorldNormal(v.normal);
                float3 viewDir = normalize(_MyCameraPosition - v.vertex);
                // world normal
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                o.normal_dot_view = dot(worldNormal, viewDir);
                return o;
            }

            float4  frag (v2f i) : SV_Target
            {
                return float4(i.normal_dot_view, 0, 0, 1);
                //if(i.normal_dot_view < 0.2)
                //    return float4(1, 0, 0, 1);
                //else 
                //    return float4(0, 0, 0, 1);
            }
            ENDCG
        }

        Pass
        {
            //Cull Back
            //ZWrite On
            //ZTest Less

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                //float2 depth : TEXCOORD2;
            };

            sampler2D _ValleyTexture;
            sampler2D _DepthTexture;
            float4 _ValleyTexture_ST;
            float _Threshold;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _ValleyTexture);
                //
                o.screenPos = ComputeScreenPos(o.vertex);
                //UNITY_TRANSFER_DEPTH(o.depth);
                //o.screenPos = UnityObjectToViewPos(o.vertex);
                return o;
            }

            float intensity(float4 color)
            {
                return sqrt((color.x * color.x) + (color.y * color.y) + (color.z * color.z));
            }

            fixed4 radial_edge_detection(float step, float2 center)
            {
                // let's learn more about our center pixel
                float center_intensity = intensity(tex2D(_ValleyTexture, center));
                // counters we need
                int darker_count = 0;
                float max_intensity = center_intensity;
                int radius = 5;
                // let's look at our neighbouring points
                for (int i = -radius; i <= radius; i++)
                {
                    for (int j = -radius; j <= radius; j++)
                    {
                        float2 current_location = center + float2(i * step, j * step);
                        float current_intensity = intensity(tex2D(_ValleyTexture, current_location));
                        if (current_intensity < center_intensity)
                        {
                            darker_count++;
                        }
                        if (current_intensity > max_intensity)
                        {
                            max_intensity = current_intensity;
                        }
                    }
                }
                // do we have a valley pixel?
                if ((max_intensity - center_intensity) > 0.01f * radius)
                {
                    //if (darker_count / (radius * radius) < (1 - (1 / radius)))
                    if (darker_count < (1 - (1 / radius)) * radius)
                    {
                        return fixed4(0.0, 1.0, 0.0, 1.0); // yep, it's a valley pixel.
                    }
                }
                return fixed4(1.0, 1.0, 1.0, 1.0); // no, it's not.
            }

            fixed4 frag(v2f i) : SV_Target
            {
                //if(tex2D(i.depth, uv) < o.depth)
                //    
                //clip(length(i.uv - 0.5) > 0.5 ? -1 : 1);
                //float2 toCenter = (i.uv - 0.5) * 2;
                // sample the texture
                float2 uv = i.screenPos.xy / i.screenPos.w;
                float ndv = tex2D(_ValleyTexture, uv).x;
                fixed4 col;
                //fixed4 col = tex2D(_ValleyTexture, i.uv);
                if (ndv < _Threshold)
                    col = fixed4(1, 0, 0, 1);
                else
                    col = radial_edge_detection(1 / 512, uv);
                return col;
            }
            ENDCG
        }
    }
}
