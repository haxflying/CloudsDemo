Shader "Custom/Gear" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NormalMap("Normal Map", 2D) = "normal" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Transparent" }
		LOD 200

		ZWrite Off

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows alpha:blend

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;
		sampler2D _NormalMap;
		sampler2D _clouds_frame;
		sampler2D _SpecialDepth;

		struct Input {
			float2 uv_MainTex;
			float4 screenPos;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		void mycolor (Input IN, SurfaceOutputStandard o, inout fixed4 color)
        {
          //color = float4(IN.screenPos.xy / IN.screenPos.w, 0, 1);
        	float2 uv = IN.screenPos.xy / IN.screenPos.w;
      		float distToClouds = tex2D(_clouds_frame, uv).a;
			float distToMe = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_SpecialDepth, uv));
			//color = distToClouds;
			//color = distToMe;
			distToClouds = distToClouds > 0.99 ? 0 : distToClouds;
			color = distToClouds > distToMe ? 0 : 1;
			//color = distToClouds;
        }

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_MainTex));

			float2 uv = IN.screenPos.xy / IN.screenPos.w;
			float distToClouds = tex2D(_clouds_frame, uv).a;
			//distToClouds = distToClouds > 0.99 ? 0 : distToClouds;
			float distToMe = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_SpecialDepth, uv));
			o.Alpha = saturate(saturate(distToClouds - distToMe) * 100);
		}
		ENDCG
	}
	FallBack "Diffuse"
}
