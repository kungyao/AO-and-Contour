Shader "MyShader/SSAO"
{
	Properties
	{
		_MainTex("_MainTex", 2D) = "white" {}
		_RandomNoise("_RandomNoise", 2D) = "white" {}
		_Radius("_Radius", Float) = 1
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
		float3 scrPos : TEXCOORD1;
	};

	sampler2D _MainTex;
	sampler2D _RandomNoise;

	sampler2D _CameraDepthTexture;
	sampler2D _CameraDepthNormalsTexture;

	uniform float _SampleSize;
	uniform float4 _Samples[64];
	uniform float _Radius;
	sampler2D _AOTex;

	v2f vert(appdata v)
	{
		v2f o;
		// game view 的4個點
		o.vertex = UnityObjectToClipPos(v.vertex);
		// unity uv : 0 ~ 1
		o.uv = v.uv;
		o.scrPos = ComputeScreenPos(o.vertex);
		//o.scrPos = ComputeScreenPos(o.vertex);
		return o;
	}

	fixed4 frag(v2f i) : SV_Target
	{
		return tex2D(_MainTex, i.uv);
	}

	//https://learnopengl-cn.readthedocs.io/zh/latest/05%20Advanced%20Lighting/09%20SSAO/
	//http://john-chapman-graphics.blogspot.com/
	fixed4 frag_ao(v2f IN) : SV_Target
	{
		fixed4 depth_normal = tex2D(_CameraDepthNormalsTexture, IN.scrPos.xy);
		float depth;
		float3 normal;
		DecodeDepthNormal(depth_normal, depth, normal);

		//randomVec 影響結果 所以拿掉
		//float3 randomVec = float3(tex2D(_RandomNoise, IN.scrPos.xy).xy, 0);

		//normal = normal * 2 - 1;
		// Get the depth value for this pixel
		float z = depth;
		// Get x/w and y/w from the viewport position
		float x = IN.scrPos.x * 2 - 1;
		float y = (1 - IN.scrPos.y) * 2 - 1;
		float4 vProjectedPos = float4(x, y, z, 1.0f);
		// Transform by the inverse projection matrix
		float4 vPositionVS = mul(unity_CameraInvProjection, vProjectedPos);
		// Divide by w to get the view-space position
		float3 origin = vPositionVS.xyz / vPositionVS.w;

		//可以得到正確的screen space座標
		//float4 proj = mul(unity_CameraProjection, float4(origin, 1));
		//proj /= proj.w;
		//proj = (proj + 1) / 2;
		//proj.y = 1 - proj.y;
		//depth_normal = tex2D(_CameraDepthNormalsTexture, proj.xy);
		//return depth_normal;

		// create ntb matrix
		//float3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
		//float3 bitangent = cross(normal, tangent);
		//float3x3 TBN;
		//TBN[0] = tangent;
		//TBN[1] = bitangent;
		//TBN[2] = normal;

		float occlusion = 0.0;
		for (int i = 0; i < _SampleSize; ++i)
		{
			//float3 sp = mul(TBN, _Samples[i].xyz);
			float3 sp = _Samples[i].xyz;

			if (dot(sp, normal) < 0)
				continue;
			//sp = -sp;

			sp = origin + sp * _Radius;

			float4 rclipPos = mul(unity_CameraProjection, float4(sp, 1));
			rclipPos /= rclipPos.w;
			rclipPos = (rclipPos + 1) / 2;
			rclipPos.y = 1 - rclipPos.y;
			//rclipPos.xy = rclipPos.xy * 0.5 + 0.5;

			float sampleDepth;
			float3 sampleNormal;
			float4 rcdn = tex2D(_CameraDepthNormalsTexture, rclipPos.xy);
			DecodeDepthNormal(rcdn, sampleDepth, sampleNormal);

			//float range = abs(randomDepth - depth);
			//float ao = randomDepth;
			//occlusion += ao * range;
			float rangeCheck = abs(depth - sampleDepth) < _Radius ? 1.0 : 0.0;
			occlusion += (sampleDepth < depth ? 1.0 : 0.0) * rangeCheck;
		}

		occlusion = 1.0 - occlusion / _SampleSize;
		occlusion = max(0.0, occlusion);

		return occlusion;
	}

	float4 _MainTex_TexelSize;

	// https://blog.csdn.net/puppet_master/article/details/82929708
	float3 GetNormal(float2 uv)
	{
		float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);
		return DecodeViewNormalStereo(cdn);
	}

	half CompareNormal(float3 normal1, float3 normal2)
	{
		return smoothstep(0.8, 1.0, dot(normal1, normal2));
	}

	fixed4 frag_ao_blur(v2f i) : SV_Target
	{
		float2 delta = _MainTex_TexelSize.xy * 1;

		float2 uv = i.uv;
		float2 uv0a = i.uv - delta;
		float2 uv0b = i.uv + delta;
		float2 uv1a = i.uv - 2.0 * delta;
		float2 uv1b = i.uv + 2.0 * delta;
		float2 uv2a = i.uv - 3.0 * delta;
		float2 uv2b = i.uv + 3.0 * delta;

		float3 normal = GetNormal(uv);
		float3 normal0a = GetNormal(uv0a);
		float3 normal0b = GetNormal(uv0b);
		float3 normal1a = GetNormal(uv1a);
		float3 normal1b = GetNormal(uv1b);
		float3 normal2a = GetNormal(uv2a);
		float3 normal2b = GetNormal(uv2b);

		fixed4 col = tex2D(_MainTex, uv);
		fixed4 col0a = tex2D(_MainTex, uv0a);
		fixed4 col0b = tex2D(_MainTex, uv0b);
		fixed4 col1a = tex2D(_MainTex, uv1a);
		fixed4 col1b = tex2D(_MainTex, uv1b);
		fixed4 col2a = tex2D(_MainTex, uv2a);
		fixed4 col2b = tex2D(_MainTex, uv2b);

		half w = 0.37004405286;
		half w0a = CompareNormal(normal, normal0a) * 0.31718061674;
		half w0b = CompareNormal(normal, normal0b) * 0.31718061674;
		half w1a = CompareNormal(normal, normal1a) * 0.19823788546;
		half w1b = CompareNormal(normal, normal1b) * 0.19823788546;
		half w2a = CompareNormal(normal, normal2a) * 0.11453744493;
		half w2b = CompareNormal(normal, normal2b) * 0.11453744493;

		half3 result;
		result = w * col.rgb;
		result += w0a * col0a.rgb;
		result += w0b * col0b.rgb;
		result += w1a * col1a.rgb;
		result += w1b * col1b.rgb;
		result += w2a * col2a.rgb;
		result += w2b * col2b.rgb;

		result /= w + w0a + w0b + w1a + w1b + w2a + w2b;
		return fixed4(result, 1.0);
	}

	fixed4 frag_composite(v2f i) : SV_Target
	{
		fixed4 ori = tex2D(_MainTex, i.uv);
		fixed4 ao = tex2D(_AOTex, i.uv);
		ori.rgb *= ao.r;
		return ori;
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
			#pragma fragment frag
			ENDCG
		}
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_ao
			ENDCG
		}
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_ao_blur
			ENDCG
		}
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_composite
			ENDCG
		}
	}
}