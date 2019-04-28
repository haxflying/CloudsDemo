Shader "Unlit/UBW_Effect"
{
	Properties
	{
		[HDR]_Color("Main Color", Color) = (1,1,1,1)
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" }
		LOD 100
		ZWrite Off
		Cull Off
		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;
			
			v2f vert (appdata v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float noise = tex2D(_MainTex, i.uv).r;
				float2 uv = i.uv - 0.5;
				float u = length(uv);
				float v = dot(normalize(uv), float2(0, 1));
				float alpha = saturate(u * 5);
				alpha *= saturate(pow((0.5 - u), 5) * 200);
				v = acos(v) * lerp(0.3, 0.6, noise * (sin(_Time.y * 0.3)));
				u = 1 / u ;//* lerp(0.7, 0.9, noise);
				float4 col = tex2D(_MainTex, float2(u, v)).r * _Color;

				return float4(col.rgb, col.a * alpha);
			}
			ENDCG
		}
	}
}
