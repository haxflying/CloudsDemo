Shader "Custom/Snow_bynoise" {
	Properties {
		_ColorLight ("Color Light", Color) = (1,1,1,1)
		_ColorDark ("Color Dark", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_NormalMap("NormalMap", 2D) = "white" {}
		_TexScale("TexScale", Float) = 1
		_GlintPower("Glint Power", Float) = 1
		_GlintThreshold("Glint Threshold", Range(0.0, 1.5)) = 0.5
		_FadeDistace("Fade Distance", Float) = 10

	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Snow fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0
		#define vec2 float2
		#define vec3 float3
		#define vec4 float4
		#define ivec2 half2
		#define mix lerp
		#define fract frac
		#define mat3 float3x3
		#define mat2 float2x2
		#define mod fmod
		#include "UnityPBSLighting.cginc"

		sampler2D _MainTex, _NormalMap;

		struct Input {
			float2 uv_MainTex;
			float2 uv_NormalMap;
			float3 worldPos;
			float3 worldNormal;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _ColorLight, _ColorDark;
		float _TexScale, _GlintPower, _GlintThreshold, _FadeDistace;

		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)		

		float3 worldPos;
		float3 worldNormal;

		float hash(vec3 p)  // replace this by something better
		{
		    p  = fract( p*0.3183099+.1 );
			p *= 17.0;
		    return fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
		}

		vec3 hash3( vec3 p ) // replace this by something better
		{
			p = vec3( dot(p,vec3(127.1,311.7, 74.7)),
					  dot(p,vec3(269.5,183.3,246.1)),
					  dot(p,vec3(113.5,271.9,124.6)));

			return -1.0 + 2.0*fract(sin(p)*43758.5453123);
		}

		float noised( in vec3 x )
		{
		    vec3 p = floor(x);
		    vec3 f = fract(x);
		    f = f*f*(3.0-2.0*f);
			
		    return mix(mix(mix( hash(p+vec3(0,0,0)), 
		                        hash(p+vec3(1,0,0)),f.x),
		                   mix( hash(p+vec3(0,1,0)), 
		                        hash(p+vec3(1,1,0)),f.x),f.y),
		               mix(mix( hash(p+vec3(0,0,1)), 
		                        hash(p+vec3(1,0,1)),f.x),
		                   mix( hash(p+vec3(0,1,1)), 
		                        hash(p+vec3(1,1,1)),f.x),f.y),f.z);
		}

		inline half4 LightingSnow(SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
        {
        	float3 lig = _WorldSpaceLightPos0.xyz;// normalize(float3(0.6, 0.9, 0.5));
        	float3 lightPower = _LightColor0.xyz;
        	float3 pos = worldPos;
        	float3 nor = worldNormal;
        	float3 rd = normalize(pos - _WorldSpaceCameraPos);

        	float dif = saturate(dot(lig, nor));
        	float fre = 1 - pow(1 - dif, 2.5);
        	float dfr = 1 - pow(1 - saturate(dot(nor, -rd)), 2.5);
        	dfr *= fre;
        	float3 col = lerp(_ColorDark, _ColorLight, (1 - abs(rd.y)) * dif);
			//glint
        	float value = noised(hash3(floor(pos * _TexScale)));
        	float value1 = noised(hash3(pos));
        	col *= lightPower * lerp(0.01, 1, dif);
        	float dis  = saturate(length(pos - _WorldSpaceCameraPos) / _FadeDistace);
        	float glint = saturate(abs(value) - _GlintThreshold + 0.5 * value1) 
        	* _GlintPower * saturate(1 - sqrt(dis));
        	glint *= 1 - fre;
        	col += glint;
        	//tonemap, gamma
        	col *= 1 / (max(max(col.r, col.g), col.b) + 1);
        	col = pow(col, 0.4545);
        	return half4(col, 1);
        }

        
        inline void LightingSnow_GI(
                SurfaceOutputStandard s,
                UnityGIInput data,
                inout UnityGI gi)
        {
            //LightingStandard_GI(s, data, gi);
        }

		void surf (Input IN, inout SurfaceOutputStandard o) {
			worldPos = IN.worldPos;
			worldNormal = normalize(IN.worldNormal);
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
