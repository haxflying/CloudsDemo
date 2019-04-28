Shader "Custom/Gilgamesh_Sword" {
	Properties {
		[HDR]skillColor("skill Color", Color) = (1,1,1,1)
		skillLightDistance("Skill Light Distance", Float) = 2
		cutout("Cut out", Float) = 0.02
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_MetallicGlossMap ("Metallic", 2D) = "white"{}
		_BumpMap("Normal", 2D) = "normal" {}
		_EmissionMap("EmissionMap", 2D) = "black" {}
		[HDR]_EmissionColor("EmissionColor", Color) = (1,1,1,1)
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard finalcolor:mycolor fullforwardshadows alphatest:cutout 

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
			float3 worldPos;
		};

		half _Glossiness;
		sampler2D _MetallicGlossMap;
		sampler2D _BumpMap;
		sampler2D _EmissionMap;
		fixed4 _Color;
		float4 _EmissionColor;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			UNITY_DEFINE_INSTANCED_PROP(float4, bornPos)
			UNITY_DEFINE_INSTANCED_PROP(float4, bornDir)
		UNITY_INSTANCING_BUFFER_END(Props)

		float dis;
		float4 skillColor;
		float skillLightDistance;

		void mycolor(Input IN, SurfaceOutputStandard o, inout fixed4 color)
		{
			color += saturate((skillLightDistance - dis)/skillLightDistance) * skillColor;
			//color += 1;
		}

		void surf (Input IN, inout SurfaceOutputStandard o) {
			float3 bpos = UNITY_ACCESS_INSTANCED_PROP(Props, bornPos);
		    float3 bdir = UNITY_ACCESS_INSTANCED_PROP(Props, bornDir);
		    float3 dir = IN.worldPos - bpos;
		    dis = dot(dir, bdir);


			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			fixed4 metallic = tex2D(_MetallicGlossMap, IN.uv_MainTex);

			o.Albedo = c;
			// Metallic and smoothness come from slider variables
			o.Metallic = metallic.r;
			o.Smoothness = _Glossiness * metallic.a;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			o.Alpha = saturate(dis);
			o.Emission = tex2D(_EmissionMap, IN.uv_MainTex) * _EmissionColor;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
