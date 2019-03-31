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
		}
	}
}
