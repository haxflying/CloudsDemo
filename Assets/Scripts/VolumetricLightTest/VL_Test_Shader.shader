Shader "Hidden/VL_Test_Shader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_ScatteringCoef("Scattering Coef", Range(0, 1)) = 0.002
		_ExtinctionCoef("Extinction Coef", Range(0, 1)) = 0.003
		_MaskHeight("Mask Height", Range(1500, 2000)) = 800
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			#define EARTH_RADIUS 6300e3

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 ray : TEXCOORD1;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.ray = mul(unity_CameraInvProjection, float4((float2(v.uv.x, v.uv.y) - 0.5) * 2, -1, -1));
				return o;
			}
			
			sampler2D _MainTex;
			sampler2D _MaskTex;
			float _ScatteringCoef, _ExtinctionCoef, _MaskHeight;
			float4 _MieG;
			float4 _LightColor0;

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			float MieScattering(float cosAngle, float4 g)
			{
	            return g.w * (g.x / (pow(g.y - g.z * cosAngle, 1.5)));			
			}

			float hash( float2 p ) {
			    return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453123);
			}

			float intersectSphere(float3 origin, float3 dir, float3 spherePos, float sphereRad)
			{
				float3 oc = origin - spherePos;
				float b = 2.0 * dot(dir, oc);
				float c = dot(oc, oc) - sphereRad*sphereRad;
				float disc = b * b - 4.0 * c;
				if (disc < 0.0)
					return -1.0;    
			    float q = (-b + ((b < 0.0) ? -sqrt(disc) : sqrt(disc))) / 2.0;
				float t0 = q;
				float t1 = c / q;
				if (t0 > t1) {
					float temp = t0;
					t0 = t1;
					t1 = temp;
				}
				if (t1 < 0.0)
					return -1.0;
			    
			    return (t0 < 0.0) ? t1 : t0;
			}

			float4 rayTrace(float3 o, float3 dir, float len)
			{
				const float START = EARTH_RADIUS + _MaskHeight;				

				float3 lightDir = _WorldSpaceLightPos0.xyz;
				int nbSample = 100;
				float stepSize = len / nbSample;

				float extinction = 0;
				float cosAngle = dot(lightDir, -dir);
				float4 vlight = 0;
				float3 p = o;
				p += dir * stepSize * hash(dot(p, float3(12.256, 2.646, 6.356)) + _Time.y);

				[loop]
				for (int i = 0; i < nbSample; ++i)
				{
					float distToStart = intersectSphere(p, lightDir, float3(0, -EARTH_RADIUS, 0), START);
					float3 samplerPos = p + lightDir * distToStart;
					float atten = tex2D(_MaskTex, samplerPos.xz * 0.0005);
					float density = 1;
					float scattering = _ScatteringCoef * stepSize * density;
					extinction += _ExtinctionCoef * stepSize * density;
					float4 light = atten * scattering * exp(-extinction);
					vlight += light;
					p += stepSize * dir;						
				}

				//vlight *= MieScattering(cosAngle, _MieG);
				vlight *= _LightColor0;
				vlight = max(0, vlight);
				vlight.w *= exp(-extinction);
				return vlight;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				float3 ray = mul(unity_CameraToWorld, float4(i.ray, 0));

				i.ray *= (_ProjectionParams.z / i.ray.z);
				float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
			    float dpth = Linear01Depth(rawDepth);
			    float3 vpos = i.ray * dpth;
			   	float dist = length(vpos);
			    col += rayTrace(_WorldSpaceCameraPos, normalize(ray), dist) * 2;
				return col;
			}
			ENDCG
		}
	}
}
