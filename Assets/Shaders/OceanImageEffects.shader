Shader "Hidden/OceanImageEffects"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_EdgeColor("Edge Color", Color) = (1,1,1,1)
		_UnderWaterCol("Under Water Color", Color) = (0, 0, 0, 0)
		_UnderWaterBlend("Under Water Color Blend", Range(0.0, 1.0)) = 1.0
		ITER_GEOMETRY("ITER_GEOMETRY", Range(1,6)) = 3
		ITER_FRAGMENT("ITER_FRAGMENT", Range(1,9)) = 3
		SEA_HEIGHT("SEA_HEIGHT",Float) = 0.6
		SEA_CHOPPY("SEA_CHOPPY", Float) = 4.0
		SEA_SPEED("SEA_SPEED",Float) = 0.8
		SEA_FREQ("SEA_FREQ",Float) = 0.16
		SEA_BASE("SEA_BASE",Color) = (0.1, 0.19,0.22,1.0)
		SEA_WATER_COLOR("SEA_WATER_COLOR",Color) = (0.8, 0.9, 0.6, 1.0)
		BASE_SCALE("BASE_SCALE",Float) = 1.0
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
			#include "OceanNoise.cginc"

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
				float4 oceanWoldPos : TEXCOORD2;
			};

			float4x4 _Interpolation;
			float4 _EdgeColor, _UnderWaterCol; 
			fixed _UnderWaterBlend;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.ray = mul(unity_CameraInvProjection, float4((float2(v.uv.x, v.uv.y) - 0.5) * 2, -1, -1));
				o.oceanWoldPos = lerp(_Interpolation[0], _Interpolation[1], v.uv.x);
				return o;
			}
			
			sampler2D _MainTex;

			fixed4 frag (v2f i) : SV_Target
			{

				i.ray *= _ProjectionParams.y / i.ray.z;

				half3 vpos = i.ray;
				half3 wpos = mul(unity_CameraToWorld, float4(vpos, 1));
				i.oceanWoldPos = i.oceanWoldPos/ i.oceanWoldPos.w;
				half oceanHeight = map(i.oceanWoldPos * BASE_SCALE);
				oceanHeight += i.oceanWoldPos.y;
				half diff = (wpos.y - oceanHeight);
				float4 col = tex2D(_MainTex, i.uv);
				
				
				if(diff < 0)
				{
					col  = col * (1 - _UnderWaterBlend) + _UnderWaterCol * _UnderWaterBlend;
				}

				diff = lerp(-0.005, 12, abs(diff));
				//diff = diff < 0.1 ? 0 : 1;
				col = lerp(_EdgeColor * col, col, saturate(diff));
				return col;
			}
			ENDCG
		}
	}
}
