Shader "Hidden/SunColorTestShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		sun_density("sun_density", Float) = 1
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
			float sun_density;
			float _CloudThickness;

			#define kRAYLEIGH (lerp(0.0, 0.0025, pow(_CloudThickness,2.5)))      // Rayleigh constant
			#define kMIE 0.0010   
			#define kKrESun (kRAYLEIGH * sun_density)
			#define OUTER_RADIUS 1.025
			#define kMAX_SCATTER 50.0

			static const float3 kDefaultScatteringWavelength = float3(.65, .57, .475);
			static const float kInnerRadius = 1.0;
			static const float kInnerRadius2 = 1.0;
			static const float kOuterRadius = OUTER_RADIUS;
			static const float kOuterRadius2 = OUTER_RADIUS*OUTER_RADIUS;
			static const float kCameraHeight = 0.0001;
			static const float kScale = 1.0 / (OUTER_RADIUS - 1.0); //1 / H
			static const float kScaleOverScaleDepth = (1.0 / (OUTER_RADIUS - 1.0)) / 0.25; //4/H
			static const float kKm4PI = kMIE * 4.0 * 3.14159265;


			float scale(float inCos)
			{
				float x = 1.0 - inCos;
				return 0.25 * exp(-0.00287 + x*(0.459 + x*(3.83 + x*(-6.80 + x*5.25))));
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float3 eyeRay = _WorldSpaceLightPos0.xyz;
				float3 kInvWavelength = 1.0 / pow(kDefaultScatteringWavelength, 4);
				float kKr4PI = kRAYLEIGH * 4.0 * 3.14159265;

				float far = sqrt(kOuterRadius2 + kInnerRadius2 * eyeRay.y * eyeRay.y - kInnerRadius2) - kInnerRadius * eyeRay.y;
				float scaledLength = far * kScale;
				float3 cameraPos = float3(0,kInnerRadius + kCameraHeight,0);
				float height = kInnerRadius + kCameraHeight;
                float depth = exp(kScaleOverScaleDepth * (-kCameraHeight)); //归一化后的光学厚度 exp(-4 * h / H)
                float startAngle = dot(eyeRay, cameraPos) / height; //除以height用来给camerapos归一化
                float startOffset = depth*scale(startAngle);//通过scale复原归一化，得到原始光学厚度
                float3 attenuate = exp(-clamp(startOffset, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));
				fixed3 col = attenuate * (depth * scaledLength);
				col *= kInvWavelength * kKrESun;
				return fixed4(col, 1);
			}
			ENDCG
		}
	}
}
