Shader "Hidden/VL_Test_Shader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_ScatteringCoef("Scattering Coef", Range(0, 1)) = 0.002
		_ExtinctionCoef("Extinction Coef", Range(0, 1)) = 0.003
		_MaskHeight("Mask Height", Range(1500, 2000)) = 800
	}
	CGINCLUDE
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

	sampler3D _NoiseVolume;
	sampler2D _LayerTex, _LayerTex1;

	float4 _LayerTex_ST, _LayerTex1_ST;			
	float _LayerBlend;

	float _CloudThickness;
	float _Speed;
	float _ScatteringCoef, _ExtinctionCoef, _MaskHeight;
	float4 _MieG;
	float4 _LightColor0;

	UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

	float4 _Detail0, _Detail1;
	float _Coverage, _TextureDensity;


	float MieScattering(float cosAngle, float4 g)
	{
        return g.w * (g.x / (pow(g.y - g.z * cosAngle, 1.5)));			
	}

	float hash( float2 p ) {
	    return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453123);
	}

	#define vec2 float2
	#define vec3 float3
	#define vec4 float4
	#define ivec2 fixed2
	#define mix lerp
	#define fract frac
	#define PI 3.141592
	#define mat3 float3x3
	#define iTime _Time.y * _Speed
	#define textureLod tex2Dlod	
	#define EARTH_RADIUS 6300e3
	#define CLOUD_START 1200.0
	#define CLOUD_HEIGHT _CloudThickness

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


	float fbm( vec3 p )
	{
		p /=  180;
		float n = 0, iter = 1;
		n += tex3Dlod(_NoiseVolume, float4(p, 0));
		return n;
	}

	float layerBlend(float2 uv)
	{
		float2 uv0 = uv * _LayerTex_ST.xy + _LayerTex_ST.zw;
	    float layer0 = textureLod(_LayerTex, float4(uv0, 0,0)).g;
	    float2 uv1 = uv * _LayerTex1_ST.xy + _LayerTex1_ST.zw;
	    float layer1 = textureLod(_LayerTex1, float4(uv1, 0,0)).g;
	   	float layer = lerp(layer0, layer1, _LayerBlend);
	   	return layer;
	}

	float clouds(vec3 p, out float cloudHeight, bool fast)
	{
	    float atmoHeight = length(p - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
	    cloudHeight = clamp((atmoHeight-CLOUD_START)/(CLOUD_HEIGHT), 0.0, 1.0);
	    p.z += iTime*10.3;
	    float2 uv = -0.00005*p.zx;
	    float layer = layerBlend(uv);
	    float largeWeather = clamp((layer-0.18)*5.0 * _TextureDensity, 0.0, 2.0);

	    p.x += iTime*8.3;
	    uv = -0.00002*p.zx;
	    layer = textureLod(_LayerTex, float4(uv, 0,0)).g;
	    float weather = largeWeather*max(0.0, layer-0.18)/0.72;
	    weather *= smoothstep(0.0, 0.5, cloudHeight) * smoothstep(1.0, 0.5, cloudHeight);
	    float cloudShape = pow(weather, 0.3+1.5*smoothstep(0.2, 0.5, cloudHeight)) * _Coverage;
	    if(cloudShape <= 0.0)
	        return 0.0;    
	    
	    p.x += iTime*12.3;
		float den= max(0.0, cloudShape-0.7*fbm(p*.01*_Detail0.xyz*_Detail0.w));
	    if(den <= 0.0)
	        return 0.0;
	    
	    if(fast)
	    	return largeWeather*0.2*min(1.0, 5.0*den);

	    p.y += iTime*15.2;
	    den= max(0.0, den-0.2*fbm(p*0.05*_Detail1.xyz*_Detail1.w));
	    return largeWeather*0.2*min(1.0, 5.0*den);

	}

	float _AtmosphereThickness;
	float sun_density;
	float light_density;

	#define kRAYLEIGH (lerp(0.0, 0.0025, pow(_AtmosphereThickness,2.5)))      // Rayleigh constant
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

	float4 getSunColor()
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

	float getAttenuation(float3 p, float3 lightDir)
	{
		const float START = EARTH_RADIUS + CLOUD_START;	
		float END = START + _CloudThickness;	

		int nlSample = 6;
		float distToStart = intersectSphere(p, lightDir, float3(0, -EARTH_RADIUS, 0), START);
		float distToEnd = intersectSphere(p, lightDir, float3(0, -EARTH_RADIUS, 0), END);
		float stepSize = (distToEnd - distToStart) / (float)nlSample;
		p += lightDir * distToStart;
		p += lightDir * stepSize * hash(dot(p, float3(12.256, 2.646, 6.356)) + _Time.y) * 0.01;

		float cloudHeight = 0;
		float atten = 0;
		
		[loop]
		for (int i = 0; i < nlSample; ++i)
		{
			float density = clouds(p, cloudHeight, false);
			
			//density = 0;
			atten = max(atten, density);
			p += stepSize * lightDir;
		}
		//atten /= (float)nlSample;
		//atten *= tex2D(_MaskTex, p.xz * 0.0005);
		return min(0.6, saturate(1 - atten * 20));
		return min(0.8, 1 - saturate(atten));
	}

	float4 rayTrace(float3 o, float3 dir, float len)
	{
				

		float3 lightDir = _WorldSpaceLightPos0.xyz;
		int nbSample = 90;
		
		float stepSize = len / nbSample;

		float extinction = 0;
		float cosAngle = dot(lightDir, -dir);
		float4 vlight = 0;
		float3 p = o;
		p += dir * stepSize * hash(dot(p, float3(12.256, 2.646, 6.356)) + _Time.y);
		float density = light_density;

		[loop]
		for (int i = 0; i < nbSample; ++i)
		{					
			float atten = getAttenuation(p, lightDir);
						
			float scattering = _ScatteringCoef * stepSize * density;
			extinction += _ExtinctionCoef * stepSize * density;
			float4 light = atten * scattering * exp(-extinction);
			vlight += light;

			p += stepSize * dir;						
		}

		//vlight *= MieScattering(cosAngle, _MieG);
		
		vlight = max(0, vlight);
		vlight *= getSunColor() * _LightColor0;
		return vlight;
	}

	fixed4 frag_vlight (v2f i) : SV_Target
	{
		
		float3 ray = mul(unity_CameraToWorld, float4(i.ray, 0));

		i.ray *= (_ProjectionParams.z / i.ray.z);
		float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
	    float dpth = Linear01Depth(rawDepth);
	    float3 vpos = i.ray * dpth;
	   	float dist = length(vpos);
	    float4 vlight = rayTrace(_WorldSpaceCameraPos, normalize(ray), _ProjectionParams.z);
	    return vlight;
	   	return float4(vlight.rgb, dpth);
	}

	sampler2D vlight_Tex;
	fixed4 frag_combine (v2f i) : SV_Target
	{
		float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
	    float dpth = Linear01Depth(rawDepth);

		fixed4 col = tex2D(_MainTex, i.uv);
		fixed4 vlight = tex2D(vlight_Tex, i.uv);
		vlight *= pow(dpth, 0.7);
		col = vlight + (1 - Luminance(vlight.rgb)) * col;
		//return vlight.r;
		return col;
	}
	ENDCG
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			Name "vlight"
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_vlight
			
			
			ENDCG
		}

		Pass
		{
			Name "combine"
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_combine
			
			
			ENDCG
		}
	}
}
