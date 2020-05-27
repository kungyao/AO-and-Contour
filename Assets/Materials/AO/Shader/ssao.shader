Shader "MyShader/SSAO"
{
	Properties
	{
		_MainTex("_MainTex", 2D) = "white" {}
		_RandomNoise("_RandomNoise", 2D) = "white" {}
		_Radius("_Radius", Float) = 1.0
		_BlurSize("_BlurSize", Float) = 1.0
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
	};

	float4 _MainTex_TexelSize;
	sampler2D _MainTex;
	sampler2D _RandomNoise;

	sampler2D _CameraDepthTexture;
	sampler2D _CameraDepthNormalsTexture;

	uniform float _SampleSize;
	uniform float4 _Samples[64];

	float _Radius;
	float _BlurSize;
	sampler2D _AOTex;

	v2f vert(appdata v)
	{
		v2f o;
		// game view 的4個點
		o.vertex = UnityObjectToClipPos(v.vertex);
		// unity uv : 0 ~ 1
		o.uv = v.uv;
		float4 clipPos = float4(v.uv * 2 - 1.0, 1.0, 1.0);
		float4 viewRay = mul(unity_CameraInvProjection, clipPos);
		o.viewRay = viewRay.xyz / viewRay.w;
		return o;
	}

	fixed4 frag(v2f i) : SV_Target
	{
		return tex2D(_MainTex, i.uv);
	}

	//https://learnopengl-cn.readthedocs.io/zh/latest/05%20Advanced%20Lighting/09%20SSAO/
	//http://john-chapman-graphics.blogspot.com/
	fixed4 frag_ao(v2f i) : SV_Target
	{
		float4 depth_normal = tex2D(_CameraDepthNormalsTexture, i.uv);
		float depth;
		float3 normal;
		//采样获得深度值和法线值
		DecodeDepthNormal(depth_normal, depth, normal);

		// Get the depth value for this pixel
		float z = 1.0;
		// Get x/w and y/w from the viewport position
		float x = i.uv.x * 2 - 1;
		float y = i.uv.y * 2 - 1;
		float4 vProjectedPos = float4(x, y, z, 1.0f);
		// Transform by the inverse projection matrix
		float4 vPositionVS = mul(unity_CameraInvProjection, vProjectedPos);
		// Divide by w to get the view-space position
		float3 origin = vPositionVS.xyz / vPositionVS.w;

		//float3 viewPos = depth * i.viewRay;
		float3 viewPos = origin * depth;
		normal = normalize(normal) * float3(1, 1, -1);

		//采样噪声图
		float3 randvec = tex2D(_RandomNoise, i.uv * _MainTex_TexelSize.zw / 4).xyz;
		//Gramm-Schimidt处理创建正交基
		float3 tangent = normalize(randvec - normal * dot(randvec, normal));
		float3 bitangent = cross(normal,tangent);
		float3x3 TBN = float3x3(tangent, bitangent, normal);

		float occlusion = 0.0;
		for (int k = 0; k < _SampleSize; k++)
		{
			float3 sp = mul(_Samples[k].xyz, TBN);
			sp = viewPos + sp * _Radius;

			float4 rclipPos = mul(unity_CameraProjection, float4(sp, 1));
			rclipPos /= rclipPos.w;
			rclipPos = (rclipPos + 1) / 2;

			float sampleDepth;
			float3 sampleNormal;
			float4 rcdn = tex2D(_CameraDepthNormalsTexture, rclipPos.xy);
			DecodeDepthNormal(rcdn, sampleDepth, sampleNormal);

			//1.range check & accumulate
			float rangeCheck = smoothstep(0.0, 1.0, _Radius / abs(sampleDepth - depth));
			occlusion += (sampleDepth >= depth ? 1.0 : 0.0) * rangeCheck; //
		}

		occlusion = occlusion / _SampleSize;
		return occlusion;
	}

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

	static const float2 kernel[8] = {
		float2(1, 0),
		float2(1, 1),
		float2(0, 1),
		float2(-1, 1),
		float2(-1, 0),
		float2(-1, -1),
		float2(0, -1),
		float2(1, -1)
	};

	fixed4 frag_ao_blur(v2f i) : SV_Target
	{
		float2 delta = _MainTex_TexelSize.xy * _BlurSize;
		float4 blur = 0;
		//_BlurSize

		blur += tex2D(_MainTex, i.uv);
		blur += tex2D(_MainTex, i.uv + delta * kernel[0]);
		blur += tex2D(_MainTex, i.uv + delta * kernel[1]);
		blur += tex2D(_MainTex, i.uv + delta * kernel[2]);
		blur += tex2D(_MainTex, i.uv + delta * kernel[3]);
		blur += tex2D(_MainTex, i.uv + delta * kernel[4]);
		blur += tex2D(_MainTex, i.uv + delta * kernel[5]);
		blur += tex2D(_MainTex, i.uv + delta * kernel[6]);
		blur += tex2D(_MainTex, i.uv + delta * kernel[7]);

		return blur / 9;

		//float2 delta = _MainTex_TexelSize.xy * 1;

		//float2 uv = i.uv;
		//float2 uv0a = i.uv - delta;
		//float2 uv0b = i.uv + delta;
		//float2 uv1a = i.uv - 2.0 * delta;
		//float2 uv1b = i.uv + 2.0 * delta;
		//float2 uv2a = i.uv - 3.0 * delta;
		//float2 uv2b = i.uv + 3.0 * delta;

		//float3 normal = GetNormal(uv);
		//float3 normal0a = GetNormal(uv0a);
		//float3 normal0b = GetNormal(uv0b);
		//float3 normal1a = GetNormal(uv1a);
		//float3 normal1b = GetNormal(uv1b);
		//float3 normal2a = GetNormal(uv2a);
		//float3 normal2b = GetNormal(uv2b);

		//fixed4 col = tex2D(_MainTex, uv);
		//fixed4 col0a = tex2D(_MainTex, uv0a);
		//fixed4 col0b = tex2D(_MainTex, uv0b);
		//fixed4 col1a = tex2D(_MainTex, uv1a);
		//fixed4 col1b = tex2D(_MainTex, uv1b);
		//fixed4 col2a = tex2D(_MainTex, uv2a);
		//fixed4 col2b = tex2D(_MainTex, uv2b);

		//half w = 0.37004405286;
		//half w0a = CompareNormal(normal, normal0a) * 0.31718061674;
		//half w0b = CompareNormal(normal, normal0b) * 0.31718061674;
		//half w1a = CompareNormal(normal, normal1a) * 0.19823788546;
		//half w1b = CompareNormal(normal, normal1b) * 0.19823788546;
		//half w2a = CompareNormal(normal, normal2a) * 0.11453744493;
		//half w2b = CompareNormal(normal, normal2b) * 0.11453744493;

		//half3 result;
		//result = w * col.rgb;
		//result += w0a * col0a.rgb;
		//result += w0b * col0b.rgb;
		//result += w1a * col1a.rgb;
		//result += w1b * col1b.rgb;
		//result += w2a * col2a.rgb;
		//result += w2b * col2b.rgb;

		//result /= w + w0a + w0b + w1a + w1b + w2a + w2b;
		//return fixed4(result, 1.0);
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