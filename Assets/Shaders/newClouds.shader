Shader "Unlit/newClouds"
{
	Properties
	{
		_MaskTex("MaskTex", 2D) = "white" {}
		//_MainTex ("Texture", 2D) = "white" {}
		[HDR]_AmbientColor("Ambient Color", Color) = (0.2, 0.5, 1.0, 1.0)
		_AborbAmount("Absorption Amount", Range(0.0, 1.0)) = 1.0
		_SunLut("Sun Lut", 2D) = "white" {}
		//_NoiseTex("Noise Texture",2D) = "white"{}
		_NoiseVolume("_NoiseVolume", 3D)= "white" {}
		_LayerTex("Layer Texture", 2D) = "white"{} 
		_LayerTex1("Layer Texture 1", 2D) = "white" {}
		_LayerBlend("Layer Blend Factor", Range(0.0, 1.0)) = 0.0
		_CloudThickness("Cloud Thickness", Range(300, 3000)) = 600
		_Coverage("Coverage",Range(0.0, 1.0)) = 1.0
		_TextureDensity("Texture Density", Range(0.0, 1.0)) = 1.0
		_OptimizationFactor("OptimizationFactor",Range(0.0, 1.0)) = 0.0
		_Detail0("Detail0", Vector) = (1,1,1,1)
		_Detail1("Detail1", Vector) = (1,1,1,1)
		_Speed("Speed",Range(0.0, 10.0)) = 2.0
		_FadeDistance("Fade Distance", Float) = 1000
		_FadeRange("Fade Range", Float) = 1200
		_BackCloudDensity("Background Cloud Density", Range(0, 1)) = 0.5

		_FogColor("Fog Color", Color) = (1,1,1,1)
		_FogDensity("Fog Density", Range(0, 5)) = 1
		_FogDistance("Fog Distance",Range(0, 20)) = 15

		_SunSize ("Sun Size", Range(0,1)) = 0.04
	    _SunSizeConvergence("Sun Size Convergence", Range(1,10)) = 5
	    _AtmosphereThickness ("Atmosphere Thickness", Range(0,5)) = 1.0
	    _SkyTint ("Sky Tint", Color) = (.5, .5, .5, 1)
	    _Exposure("Exposure", Range(0, 8)) = 1.3

		[Toggle]_TAA("TAA", Float) = 1
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 0
	}
	CGINCLUDE
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
	#define SUN_POWER 750.0
	#define LOW_SCATTER vec3(1.0, 0.7, 0.5)

	#include "UnityCG.cginc"
	#include "Lighting.cginc"
	#include "Atmosphere.cginc"

	sampler2D _MainTex;
	sampler2D _MaskTex;
	sampler2D _CameraRender;
	sampler2D _currentFrame;
	sampler2D _prev_frame;
	sampler2D _NoiseTex;
	sampler3D _NoiseVolume;
	float _LayerBlend;
	float4 _currentFrame_TexelSize;				
	float4 _NoiseTex_TexelSize;

	sampler2D _LayerTex, _LayerTex1, _SunLut;
	float4 _LayerTex_ST, _LayerTex1_ST;
	float4  _AmbientColor;
	float4 _Detail0, _Detail1;
	float _Coverage, _OptimizationFactor, _TextureDensity;
	float _FadeDistance, _FadeRange;
	float _BackCloudDensity;
	float _Speed;
	float4 _FogColor;
	float _FogDensity, _FogDistance;
	float _CloudThickness, _AborbAmount;
	 
	struct FragmentOutput
    {
        half4 dest0 : SV_Target0;
        half4 dest1 : SV_Target1;
    };


	UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
	
	v2f vert_sky (appdata v)
	{
		v2f o;
		//o.vertex = UnityObjectToClipPos(v.vertex);
		o.pos = v.vertex * float4(2, 2, 0, 0) + float4(0, 0, 0, 1);
		o.uv = v.uv;
		o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
		o.screenUV = ComputeScreenPos(o.pos);
		o.ray = mul(unity_CameraInvProjection, float4((float2(v.uv.x, v.uv.y) - 0.5) * 2, -1, -1));

		
		return o;
	}


	float hash( vec2 p ) {
	    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);
	}

	float noise( in vec3 x )
	{
		x *= 1;
	    vec3 p = floor(x);
	    vec3 f = fract(x);
	    f = f*f*(3.0-2.0*f); 
	    vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
		vec2 rg = tex2Dlod( _NoiseTex, float4((uv+0.5)/_NoiseTex_TexelSize.zw, 0, 0)).yx;
		return mix( rg.x, rg.y, f.z );
	}


	float fbm( vec3 p )
	{
		p /=  180;
		float n = 0, iter = 1;
		n += tex3Dlod(_NoiseVolume, float4(p, 0));
		/*
		float Octaves = 1;
		for (int i = 0; i < Octaves; i++)
		{
			p /= 1 + i*.06;
			p += (i*.15 + 1);

			n += tex3Dlod(_NoiseVolume, float4(p, 0));
		}
		
		n = n / Octaves;*/
		return n;
	    mat3 m = mat3( 0.00,  0.80,  0.60,
	              -0.80,  0.36, -0.48,
	              -0.60, -0.48,  0.64 );    
	    float f;
	    f  = 0.5000*noise( p ); p = mul(m,p)*2.02;
	    f += 0.2500*noise( p ); p = mul(m,p)*2.03;
	    f += 0.1250*noise( p );	
	    return f;
	}

	float intersectSphere(vec3 origin, vec3 dir, vec3 spherePos, float sphereRad)
	{
		vec3 oc = origin - spherePos;
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

	// From https://www.shadertoy.com/view/4sjBDG
	float numericalMieFit(float costh)
	{
	    // This function was optimized to minimize (delta*delta)/reference in order to capture
	    // the low intensity behavior.
	    float bestParams[10];
	    bestParams[0]=9.805233e-06;
	    bestParams[1]=-6.500000e+01;
	    bestParams[2]=-5.500000e+01;
	    bestParams[3]=8.194068e-01;
	    bestParams[4]=1.388198e-01;
	    bestParams[5]=-8.370334e+01;
	    bestParams[6]=7.810083e+00;
	    bestParams[7]=2.054747e-03;
	    bestParams[8]=2.600563e-02;
	    bestParams[9]=-4.552125e-12;
	    
	    float p1 = costh + bestParams[3];
	    vec4 expValues = exp(vec4(bestParams[1] *costh+bestParams[2], bestParams[5] *p1*p1, bestParams[6] *costh, bestParams[9] *costh));
	    vec4 expValWeight= vec4(bestParams[0], bestParams[4], bestParams[7], bestParams[8]);
	    return dot(expValues, expValWeight);
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

	float lightRay(vec3 p, float phaseFunction, float dC, float mu, vec3 sun_direction, float cloudHeight, bool fast)
	{
	    int nbSampleLight = fast ? 7 : 20;
		float zMaxl         = 600.;
	    float stepL         = zMaxl/float(nbSampleLight);
	    
	    float lighRayDen = 0.0;    
	    p += sun_direction*stepL*hash(dot(p, vec3(12.256, 2.646, 6.356)) + iTime);//jitter
	    [loop]
	    for(int j=0; j<nbSampleLight; j++)
	    {
	        //float cloudHeight;
	        lighRayDen += clouds( p + sun_direction*float(j)*stepL, cloudHeight, fast);
	    }    
	    if(fast)
	    {
	        return (0.5*exp(-0.4*stepL*lighRayDen) + max(0.0, -mu*0.6+0.3)*exp(-0.02*stepL*lighRayDen))*phaseFunction;
	    }
	    //return 0;
	    float scatterAmount = mix(0.008, 1.0, smoothstep(0.96, 0.0, mu));
	    float beersLaw = exp(-stepL*lighRayDen)+0.5*scatterAmount*exp(-0.1*stepL*lighRayDen)+scatterAmount*0.4*exp(-0.02*stepL*lighRayDen);
	    return beersLaw * phaseFunction * mix(0.05 + 1.5*pow(min(1.0, dC*8.5), 0.3+5.5*cloudHeight), 1 - _AborbAmount, clamp(lighRayDen*0.4, 0.0, 1.0));
	}

	uniform int _cloudIteration; 
	vec3 skyRay(vec3 org, vec3 dir, vec3 sun_direction, vec3 sunCol, vec3 skyCol, vec4 bgCol, out float blendAlpha, bool fast)
	{
	    const float ATM_START = EARTH_RADIUS+CLOUD_START;
		const float ATM_END = ATM_START+CLOUD_HEIGHT;
	    
	    int nbSample = fast ? 13 : _cloudIteration;
	    vec3 color = 0;
		float distToAtmStart = intersectSphere(org, dir, vec3(0.0, -EARTH_RADIUS, 0.0), ATM_START);
	    float distToAtmEnd = intersectSphere(org, dir, vec3(0.0, -EARTH_RADIUS, 0.0), ATM_END);
	    vec3 p = org + distToAtmStart * dir;    
	    float stepS = (distToAtmEnd-distToAtmStart) / float(nbSample);    
	    float T = 1.;    
	    float mu = dot(sun_direction, dir);
	    float phaseFunction = numericalMieFit(mu);
	    p += dir*stepS*hash(dot(dir, vec3(12.256, 2.646, 6.356)) + iTime);
	    float thickness = 0;
	    [loop]
		for(int i=0; i<nbSample; i++)
		{        
	        float cloudHeight;
			float density = clouds(p, cloudHeight, fast);
			if(density>0.)
			{
				thickness += density;
				float intensity = lightRay(p, phaseFunction, density, mu, sun_direction, cloudHeight, fast);        
	            vec3 ambient = (0.5 + 0.6*cloudHeight)*_AmbientColor.rgb*6.5 + (0.8) * max(0.0, 1.0-2.0*cloudHeight);
	            vec3 radiance = ambient * sqrt(sunCol) + SUN_POWER*intensity*sunCol;
	            radiance*=density;			
	            color += T*(radiance - radiance * exp(-density * stepS)) / density;   // By Seb Hillaire                  
	            T *= exp(-density*stepS);            
				if( T <= 0.05)
				{
					T = 0;
					break;
				}
	        }
	        stepS *= 1 + i*i*i*_OptimizationFactor;
			p += dir*stepS;
		}	       
		vec3 background = bgCol * 6.0;//6.0*mix(vec3(0.2, 0.52, 1.0), vec3(0.8, 0.95, 1.0), pow(0.5+0.5*mu, 15.0))+mix((3.5), (0.0), min(1.0, 2.3*dir.y));
	    //if(!fast) 	background += T*(1e4*smoothstep(0.9998, 1.0, mu)); //Draw Sun
	    //color = color * sqrt(skyCol * 6) + background * T;
	   	//return noise(p);
	   	
	   	blendAlpha = Luminance(color);
	   	blendAlpha = max(blendAlpha, bgCol.a);
	   	//return blendAlpha;
	    return color * sqrt(skyCol * 6)  * (1 - bgCol.a) + background * T;
	}

	vec3 tonemapACES( vec3 x )
	{
	    float a = 2.51;
	    float b = 0.03;
	    float c = 2.43;
	    float d = 0.59;
	    float e = 0.14;
	    return (x*(a*x+b))/(x*(c*x+d)+e);
	}

	float ComputeFogFactor(float coord)
	{
		float fog = _FogDensity * coord;
		fog = exp2(-fog);
		return saturate(fog);
	}
	
	
	fixed4 frag_sky (v2f i) : SV_Target
	{
		FragmentOutput o;

		i.screenUV.xy /= i.screenUV.w;
		half3 col = 0;
		fixed4 frame = tex2D(_CameraRender, i.uv);

		float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
		float dpth = Linear01Depth(rawDepth);

		i.ray *= (_ProjectionParams.z /i.ray.z);
		float3 vpos = i.ray * dpth;
		float3 wpos = mul(unity_CameraToWorld, float4(vpos, 1));

		

		float3 org = _WorldSpaceCameraPos;
		float3 dir = normalize(wpos - _WorldSpaceCameraPos);
		float3 sun_direction = _WorldSpaceLightPos0.xyz;

		const float ATM_START = EARTH_RADIUS+CLOUD_START;
		float distToAtmStart = intersectSphere(org, dir, vec3(0.0, -EARTH_RADIUS, 0.0), ATM_START);


		//half alpha = cosLookat < cosTangent ? 1 : 0;//smoothstep(0, 1,(_FadeDistance - distToAtmStart)/_FadeRange);
		float3 fogCol = _FogColor.rgb;
		float blendAlpha = 1;
		if(dir.y < -0.1)
			col = 0;		
		else
		{
			//cloud render
			float lerpFactor = saturate(1 - saturate(sun_direction.y));

			float3 sunColor = tex2D(_SunLut, float2(lerpFactor * lerpFactor, 0.5));
			
			//if(sun_direction.y < -0.)
			//	sun_direction.y *= 5; //调整夜晚光线 temp version
			sun_direction = normalize(sun_direction);

			col = skyRay(org, dir, sun_direction, sunColor, frame, frame, blendAlpha, false);
			//tonemapping			 
			  col = tonemapACES(col / 6.0);
			//fogCol = tonemapACES(_FogColor.rgb * i.skyColor);
		}

		float4 finalCol = float4(col, blendAlpha);//alpha * col + (1 - alpha) * frame;

		//float fog = ComputeFogFactor((length(wpos - _WorldSpaceCameraPos) - distToAtmStart)/(-_FogDistance * 1000));		
		//finalCol = lerp(finalCol, fogCol, 1 - fog);	
		finalCol = lerp(float4(frame.rgb, 1), finalCol, saturate(dir.y * 10 - 0.3));
		//return blendAlpha;
		return float4(finalCol.rgb, blendAlpha);
	}
	
	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		Cull Off ZWrite Off ZTest [_ZTest]
		//Blend SrcAlpha OneMinusSrcAlpha
		Pass
		{
			Name "CloudRender"
			Tags{"LightMode" = "ForwardBase"}

			CGPROGRAM
			#pragma vertex vert_sky
			#pragma fragment frag_sky

			#pragma exclude_renderers d3d11_9x
			#pragma exclude_renderers d3d9
			#pragma multi_compile_fog
			ENDCG
		}

		Pass
		{
			Name "TAA"
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma  shader_feature _TAA_ON 

			#define ivec2 fixed2

			struct v2f_taa
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f_taa vert (appdata v)
			{
				v2f_taa o;
				//o.vertex = UnityObjectToClipPos(v.vertex);
				o.vertex = v.vertex * float4(2, 2, 0, 0) + float4(0, 0, 0, 1);
				o.uv = v.uv;
				return o;
			}
			
			

			

			vec3 RGBToYCoCg( vec3 RGB )
			{
				float Y = dot(RGB, vec3(  1, 2,  1 )) * 0.25;
				float Co= dot(RGB, vec3(  2, 0, -2 )) * 0.25 + ( 0.5 * 256.0/255.0 );
				float Cg= dot(RGB, vec3( -1, 2, -1 )) * 0.25 + ( 0.5 * 256.0/255.0 );
				return vec3(Y, Co, Cg);
			}

			vec3 YCoCgToRGB( vec3 YCoCg )
			{
				float Y= YCoCg.x;
				float Co= YCoCg.y - ( 0.5 * 256.0 / 255.0 );
				float Cg= YCoCg.z - ( 0.5 * 256.0 / 255.0 );
				float R= Y + Co-Cg;
				float G= Y + Cg;
				float B= Y - Co-Cg;
				return vec3(R,G,B);
			}

			
			fixed4 frag (v2f_taa i) : SV_Target
			{
				vec2 offsets[8] = { 
				vec2(-1,-1), vec2(-1, 1), 
				vec2(1, -1), vec2(1, 1), 
				vec2(1, 0),  vec2(0, -1), 
				vec2(0, 1),  vec2(-1, 0)};

				float4 currentFrame = tex2D(_currentFrame, i.uv);
				float3 current = RGBToYCoCg(currentFrame.rgb);
				float3 history = RGBToYCoCg(tex2D(_prev_frame, i.uv));

				float3 colorAvg = current;
				float3 colorVar = current * current;

				// Marco Salvi's Implementation (by Chris Wyman)
				for (int j = 0; j < 8; ++j)
				{
					float3 fetch = RGBToYCoCg(tex2D(_currentFrame, i.uv + offsets[j] * _currentFrame_TexelSize.xy).rgb);
					colorAvg += fetch;
					colorVar += fetch * fetch;
				}

				colorAvg /= 9.0;
				colorVar /= 9.0;
				float gColorBoxSigma = 0.75;
				float3 sigma = sqrt(max(0, colorVar - colorAvg * colorAvg));
				float3 colorMin = colorAvg - gColorBoxSigma * sigma;
				float3 colorMax = colorAvg + gColorBoxSigma * sigma;

				history = clamp(history, colorMin, colorMax);
				#if _TAA_ON
					return float4(YCoCgToRGB(lerp(current, history, 0.95)), currentFrame.a) ;
				#else
					return tex2D(_currentFrame, i.uv);
				#endif
			}
			ENDCG
		}

		Pass
		{
			Name "combine"
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			struct v2f_taa
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 ray : TEXCOORD1;
			};

			v2f_taa vert (appdata v)
			{
				v2f_taa o;
				//o.vertex = UnityObjectToClipPos(v.vertex);
				o.vertex = v.vertex * float4(2, 2, 0, 0) + float4(0, 0, 0, 1);
				o.uv = v.uv;
				o.ray = mul(unity_CameraInvProjection, float4((float2(v.uv.x, v.uv.y) - 0.5) * 2, -1, -1));
				return o;
			}

			sampler2D _clouds_frame, _QuarterResDepthBuffer;

			fixed4 frag (v2f_taa i) : SV_Target
			{
				fixed alpha = 1 - tex2D(_currentFrame, i.uv).a;
				i.uv.y = 1 - i.uv.y;
				fixed4 bg = tex2D(_CameraRender, i.uv);
				bg.rgb = tonemapACES(bg.rgb);
				fixed4 clouds = tex2D(_clouds_frame, i.uv);
				//clouds += (1 - alpha) * bg;
				return clouds;
				
			}
			ENDCG
		}

	}
}
