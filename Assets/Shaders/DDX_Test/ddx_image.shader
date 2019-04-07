Shader "Hidden/ddx_image"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
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
			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			fixed4 frag (v2f i) : SV_Target
			{
				i.ray *= _ProjectionParams.z / i.ray.z;
				float zdepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
				zdepth = Linear01Depth(zdepth);
				//return zdepth;
				float3 vpos = i.ray * zdepth;
				half3 wpos = mul(unity_CameraToWorld, float4(vpos, 1));
				float4 col = float4(abs(ddx(wpos.y)) * 10, 0, 0, 1);
				return col;
			}
			ENDCG
		}
	}
}
