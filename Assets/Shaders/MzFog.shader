// Upgrade NOTE: commented out 'float4x4 _WorldToCamera', a built-in variable
// Upgrade NOTE: replaced '_WorldToCamera' with 'unity_WorldToCamera'

// Upgrade NOTE: commented out 'float4x4 _WorldToCamera', a built-in variable
// Upgrade NOTE: replaced '_WorldToCamera' with 'unity_WorldToCamera'

Shader "Hidden/MzFog"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_VolumeNoise("Noise", 3D) = "white" {}
		_StartDistance("Start Distace", Float) = 500
		_FadeDistace("Fade Distance", Float) = 100
		_SkyFogFac("Sky Fog Fac", Range(0, 1)) = 0.5
		_SunFadeFac("Sun Fade Fac", Float) = 30
	}
	CGINCLUDE
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
	
		// x = fog height
	// y = FdotC (CameraY-FogHeight)
	// z = k (FdotC > 0.0)
	// w = a/2
	uniform float4 _HeightParams;
	
	// x = start distance
	uniform float4 _DistanceParams;
	
	int4 _SceneFogMode; // x = fog mode, y = use radial flag
	float4 _SceneFogParams;
	half _StartDistance, _FadeDistace, _SkyFogFac;
	half4 _FogColor;
	half _FogDensity;
	half _SunFadeFac;
	// float4x4 _WorldToCamera;
	sampler2D _MainTex;
	sampler3D _VolumeNoise;
	UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);


	half ComputeFogFactor (float coord)
	{
		/*
		float fogFac = 0.0;
		if (_SceneFogMode.x == 1) // linear
		{
			// factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
			fogFac = coord * _SceneFogParams.z + _SceneFogParams.w;
		}
		if (_SceneFogMode.x == 2) // exp
		{
			// factor = exp(-density*z)
			fogFac = _SceneFogParams.y * coord; fogFac = exp2(-fogFac);
		}
		if (_SceneFogMode.x == 3) // exp2
		{
			// factor = exp(-(density*z)^2)
			fogFac = _SceneFogParams.x * coord; fogFac = exp2(-fogFac*fogFac);
		}
		return saturate(fogFac);*/
		float fogFac = ((coord - _StartDistance)/(_FadeDistace * 100));
		return saturate(fogFac);
	}

	float ComputeDistance (float3 camDir, float zdepth)
	{
		float dist; 
		if (_SceneFogMode.y == 1)
			dist = length(camDir);
		else
			dist = zdepth * _ProjectionParams.z;
		// Built-in fog starts at near plane, so match that by
		// subtracting the near value. Not a perfect approximation
		// if near plane is very large, but good enough.
		dist -= _ProjectionParams.y;
		return dist;
	}


	float rayIntesectPlane(float3 p, float3 dir, float3 n, float d)
	{
		float temp = -(dot(n, p) + d);
		float temp1 = dot(n, dir);
		return temp / temp1;
	}

	fixed4 ComputeFog (v2f i, bool distance, bool height) : SV_Target
	{

		i.ray *= (_ProjectionParams.z / i.ray.z);
		float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
	    // 0..1 linear depth, 0 at camera, 1 at far plane.
	    float dpth = Linear01Depth(rawDepth);

		//return dpth;

	    float3 vsN = mul(unity_WorldToCamera, float4(0,1,0, 0));
		float t = rayIntesectPlane(0, normalize(i.ray), vsN, _WorldSpaceCameraPos.y); //海平面
		
		t /= _ProjectionParams.z;
		if(t <= 0)
			t = 1;
		//return t;
		if(dpth > t)
			dpth = t;

		//return dpth;
	    float3 vpos = i.ray * dpth;			
		float3 wsPos = mul(unity_CameraToWorld, float4(vpos, 1));
		float noise = tex3D(_VolumeNoise, wsPos / 1000);
		
		float3 wsDir = wsPos - _WorldSpaceCameraPos;
		//wsDir *= noise;
		fixed4 sceneColor = tex2D(_MainTex, i.uv);

		
		float3 wsPos1 = _WorldSpaceCameraPos + t * wsDir;

		//return float4(wsPos, 1);
		float g = 0;//_DistanceParams.x;
		if (distance)
			g += ComputeDistance (wsDir, dpth);
		//return g/100;

		// Compute fog amount
		half fogFac = ComputeFogFactor (max(0.0,g));
		// Do not fog skybox
		if (dpth >= 0.99)
		{
			fogFac = _SkyFogFac;		
			float disToHorizontal = (abs(normalize(wsDir).y));
			disToHorizontal = pow(saturate(1 - disToHorizontal), 10);
			fogFac = lerp(fogFac, 1, disToHorizontal);
		}
		//return disToHorizontal;
		//return fogFac; // for debugging
		float sunLerp = 1;

	 	sunLerp = saturate(dot(normalize(wsDir), _WorldSpaceLightPos0.xyz));		
		sunLerp = saturate(1 - pow(sunLerp, _SunFadeFac));
		float sunFallingLerp = saturate(1 - (_WorldSpaceLightPos0.y + 0.15));
		sunLerp = lerp(sunLerp, 1,  sunFallingLerp * sunFallingLerp);
		
		fogFac *= sunLerp;
		//return sunLerp;
		// Lerp between fog color & original scene color
		// by fog amount
		return lerp (sceneColor, _FogColor, fogFac * _FogColor.a);
	}
	ENDCG
	SubShader
	{
		// No culling or depth
		ZTest Always Cull Off ZWrite Off Fog { Mode Off }

		// 0: distance + height
		Pass
		{
			Tags{"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			half4 frag (v2f i) : SV_Target { return ComputeFog (i, true, true); }
			ENDCG
		}
		// 1: distance
		Pass
		{
			Tags{"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			half4 frag (v2f i) : SV_Target { return ComputeFog (i, true, false); }
			ENDCG
		}
		// 2: height
		Pass
		{
			Tags{"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			half4 frag (v2f i) : SV_Target { return ComputeFog (i, false, true); }
			ENDCG
		}
	}
}
