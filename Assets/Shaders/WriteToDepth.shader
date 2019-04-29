Shader "Unlit/WriteToDepth"
{
	Properties
	{
		
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{
			Tags {"LightMode" = "ShadowCaster"}
			ZWrite On
			ColorMask 0	

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing			
			#include "UnityCG.cginc"
			struct appdata
			{
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return 0;
			}
			ENDCG	
		}
	}
}
