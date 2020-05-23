Shader "MyShader/SSAO"
{
	Properties
	{
		_MainTex("_MainTex", 2D) = "white" {}
		_RandomNoise("_RandomNoise", 2D) = "white" {}
	}

	CGINCLUDE
	#include "UnityCG.cginc"

	struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
		float3 normal : NORMAL;
	};

	struct v2f
	{
		float4 vertex : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 viewRay : TEXCOORD1;
		float3 scrPos : TEXCOORD2;
	};

	sampler2D _MainTex;
	uniform sampler2D _RandomNoise;

	sampler2D _CameraDepthTexture;
	sampler2D _CameraDepthNormalsTexture;

	v2f vert(appdata v)
	{
		v2f o;
		//o.vertex = UnityObjectToClipPos(v.vertex);
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		// unity uv : 0 ~ 1
		// turn to ndc format
		float4 clipPos = float4(v.uv * 2 - 1.0, 1.0, 1.0);
		// to 3d view
		float4 viewRay = mul(unity_CameraInvProjection, clipPos);
		o.viewRay = viewRay.xyz / viewRay.w;

		o.scrPos = ComputeScreenPos(o.vertex);
		//o.scrPos = ComputeScreenPos(o.vertex);
		return o;
	}

	ENDCG

	SubShader
	{
		//Cull Front ZWrite On ZTest Always
		Tags{ "RenderType" = "Opaque" }
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_ao

			uniform float _SampleSize;
			uniform float4 _Samples[64];
			uniform float _Radius;

			fixed4 frag_ao(v2f IN) : SV_Target
			{
				//fixed4 col = tex2D(_MainTex, IN.uv);
				fixed4 depth_normal = tex2D(_CameraDepthNormalsTexture, IN.scrPos.xy);
				float depth;
				float3 normal;
				DecodeDepthNormal(depth_normal, depth, normal);

				float3 randomVec = tex2D(_RandomNoise, IN.scrPos.xy).xyz;

				//normal = normal * 2 - 1;
				float3 origin = IN.vertex;

				float3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
				float3 bitangent = cross(normal, tangent);
				float3x3 TBN;
				TBN[0] = tangent;
				TBN[1] = bitangent;
				TBN[2] = normal;

				float occlusion = 0.0;
				for (int i = 0; i < _SampleSize; ++i)
				{
					float3 sp = mul(TBN, _Samples[i]);
					sp = origin/*IN.vertex*/ + sp * _Radius;

					float4 offset = float4(sp, 1.0);

					float4 rclipPos = mul(unity_CameraProjection, offset);
					rclipPos /= rclipPos.w;
					rclipPos.xy = rclipPos.xy * 0.5 + 0.5;

					float sampleDepth;
					float3 sampleNormal;
					float4 rcdn = tex2D(_CameraDepthNormalsTexture, rclipPos.xy);
					DecodeDepthNormal(rcdn, sampleDepth, sampleNormal);

	/*				float range = abs(randomDepth - depth);
					float ao = randomDepth;
					occlusion += ao * range;*/
					float rangeCheck = lerp(0.0, 1.0, _Radius / abs(depth - sampleDepth));
					occlusion += (sampleDepth > depth ? 1.0 : 0.0)/* * rangeCheck*/;
				}

				occlusion = 1.0 - occlusion / _SampleSize;

				return fixed4(occlusion, occlusion, occlusion, 1);
			}
			ENDCG
		}
	}
}