Shader "Unlit/basicClouds"
{
	Properties
	{
		_NoiseVolume("_NoiseVolume", 3D)= "white" {}
	}
	CGINCLUDE	
	
	#include "UnityCG.cginc"
	#define vec2 float2
	#define vec3 float3
	#define vec4 float4
	#define mix lerp
	#define fract frac

	struct v2f
	{
		float4 pos         : SV_POSITION;
		float3 Wpos        : TEXCOORD0;
		float4 ScreenUVs   : TEXCOORD1;
		float3 LocalPos    : TEXCOORD2;
		float3 ViewPos     : TEXCOORD3;
		float3 LocalEyePos : TEXCOORD4;
		float3 LightLocalDir : TEXCOORD5;
		float3 WorldEyeDir  : TEXCOORD6;
		float2 uv0 : TEXCOORD7;
		float3 SliceNormal : TEXCOORD8;	
		float3 worldNormal : TEXCOORD9;
	};

	sampler2D _CameraDepthTexture;
	sampler3D _NoiseVolume;
	float4 _BoxMin, _BoxMax, _VolumePosition, Stretch, Speed;
	float4 _AmbientColor;

	float _Visibility, _jitter, _OptimizationFactor, _RayStep;
	float _3DNoiseScale, DetailDistance, FadeDistance, gain;
	float _Vortex, _Rotation, _RotationSpeed, Coverage, _DetailRelativeSpeed, _BaseRelativeSpeed,
			_Curl, _NoiseDetailRange, NoiseDensity, BaseTiling, DetailTiling, threshold, _DetailMaskingThreshold,
			Absorption;
	int STEP_COUNT, Octaves;


	half NoiseAtten = 1;
	half HeightAtten;

	v2f vert(appdata_full i)
	{
		v2f o;
		o.pos = UnityObjectToClipPos(i.vertex);
		o.Wpos = mul((float4x4)unity_ObjectToWorld, float4(i.vertex.xyz, 1)).xyz;
		o.ScreenUVs = ComputeScreenPos(o.pos);
		o.ViewPos = UnityObjectToViewPos( float4(i.vertex.xyz, 1)).xyz;
		o.LocalPos = i.vertex.xyz;
		o.LocalEyePos = mul((float4x4)unity_WorldToObject, (float4(_WorldSpaceCameraPos, 1))).xyz;
		o.LightLocalDir = mul((float4x4)unity_WorldToObject, (float4(-_WorldSpaceLightPos0.xyz, 1))).xyz;
		o.WorldEyeDir = (o.Wpos.xyz - _WorldSpaceCameraPos.xyz);
		o.uv0 = i.texcoord;
		o.SliceNormal = UNITY_MATRIX_IT_MV[2].xyz;
		o.worldNormal = float3(0, -1, 0);//upwards
		return o;

	}

	vec3 hash( vec3 p ) // replace this by something better
	{
		p = vec3( dot(p,vec3(127.1,311.7, 74.7)),
				  dot(p,vec3(269.5,183.3,246.1)),
				  dot(p,vec3(113.5,271.9,124.6)));

		return -1.0 + 2.0*fract(sin(p)*43758.5453123);
	}

	float pnoise( in vec3 p )
	{
	    vec3 i = floor( p );
	    vec3 f = fract( p );
		
		vec3 u = f*f*(3.0-2.0*f);

	    return mix( mix( mix( dot( hash( i + vec3(0.0,0.0,0.0) ), f - vec3(0.0,0.0,0.0) ), 
	                          dot( hash( i + vec3(1.0,0.0,0.0) ), f - vec3(1.0,0.0,0.0) ), u.x),
	                     mix( dot( hash( i + vec3(0.0,1.0,0.0) ), f - vec3(0.0,1.0,0.0) ), 
	                          dot( hash( i + vec3(1.0,1.0,0.0) ), f - vec3(1.0,1.0,0.0) ), u.x), u.y),
	                mix( mix( dot( hash( i + vec3(0.0,0.0,1.0) ), f - vec3(0.0,0.0,1.0) ), 
	                          dot( hash( i + vec3(1.0,0.0,1.0) ), f - vec3(1.0,0.0,1.0) ), u.x),
	                     mix( dot( hash( i + vec3(0.0,1.0,1.0) ), f - vec3(0.0,1.0,1.0) ), 
	                          dot( hash( i + vec3(1.0,1.0,1.0) ), f - vec3(1.0,1.0,1.0) ), u.x), u.y), u.z );
	}

	float vnoise(in vec3 x, float v) {
	    // adapted from IQ's 2d voronoise:
	    // http://www.iquilezles.org/www/articles/voronoise/voronoise.htm
	    vec3 p = floor(x);
	    vec3 f = fract(x);

	    float s = 1.0 + 31.0 * v;
	    float va = 0.0;
	    float wt = 0.0;
	    for (int k=-2; k<=1; k++)
	    for (int j=-2; j<=1; j++)
	    for (int i=-2; i<=1; i++) {
	        vec3 g = vec3(float(i), float(j), float(k));
	        vec3 o = hash(p + g);
	        vec3 r = g - f + o + 0.5;
	        float d = dot(r, r);
	        float w = pow(1.0 - smoothstep(0.0, 1.414, sqrt(d)), s);
	        va += o.z * w;
	        wt += w;
	     }
	     return va / wt;
	}

	float vfBm(in vec3 p, float v) {
	    float sum = 0.0;
	    float amp = 1.0;
	    for(int i = 0; i < 4; i++) {
	        sum += amp * vnoise(p, v);
	        amp *= 0.5;
	        p *= 2.0;
	    }
	    sum = smoothstep( -1, 1, sum );
	    return sum;
	}

	float pfbm(in vec3 pos)
	{
		float f = 0;
		float3x3 m = float3x3( 0.00,  0.80,  0.60,
                    -0.80,  0.36, -0.48,
                    -0.60, -0.48,  0.64 );
		vec3 q = 8.0*pos;
		f  = 0.5000*pnoise( q ); q = mul(m,q)*2.01;
        f += 0.2500*pnoise( q ); q = mul(m,q)*2.02;
        f += 0.1250*pnoise( q ); q = mul(m,q)*2.03;
        f += 0.0625*pnoise( q ); q = mul(m,q)*2.01;
        f = smoothstep( -0.7, 0.7, f );
        return f;
	}

	bool IntersectBox(float3 startpoint, float3 direction, float3 boxmin, float3 boxmax, out float tnear, out float tfar)
	{
		// compute intersection of ray with all six bbox planes
		float3 invR = 1.0 / direction;
		float3 tbot = invR * (boxmin.xyz - startpoint);
		float3 ttop = invR * (boxmax.xyz - startpoint);
		// re-order intersections to find smallest and largest on each axis
		float3 tmin = min(ttop, tbot);
		float3 tmax = max(ttop, tbot);
		// find the largest tmin and the smallest tmax
		float2 t0 = max(tmin.xx, tmin.yz);
		tnear = max(t0.x, t0.y);
		t0 = min(tmax.xx, tmax.yz);
		tfar = min(t0.x, t0.y);
		// check for hit
		bool hit;
		if ((tnear > tfar))
			hit = false;
		else
			hit = true;
		return hit;
	}

	float nrand(float2 ScreenUVs)
	{
		return frac(sin(ScreenUVs.x * 12.9898 + ScreenUVs.y * 78.233) * 43758.5453);
	}

	float remap_tri(float v)
	{
		float orig = v * 2.0 - 1.0;
		v = max(-1.0, orig / sqrt(abs(orig)));

		return v - sign(orig) + 0.5;
	}

	float3 rotate(float3 p, float rot)
	{
		float3 r = 0;
	#ifdef Twirl_X
		float3x3 rx = float3x3(1.0, 0.0, 0.0, 0.0, cos(rot), sin(rot), 0.0, -sin(rot), cos(rot));
		r = mul(p, rx);
	#endif 

	#ifdef Twirl_Y
		float3x3 ry = float3x3(cos(rot), 0.0, -sin(rot), 0.0, 1.0, 0.0, sin(rot), 0.0, cos(rot));
		r = mul(p, ry);
	#endif

	#ifdef Twirl_Z
		float3x3 rz = float3x3(cos(rot), -sin(rot), 0.0, sin(rot), cos(rot), 0.0, 0.0, 0.0, 1.0);
		r = mul(p, rz);
	#endif
		return r;
	}

	half3 ContrastF(half3 pixelColor, fixed contrast)
	{
		//调整对比度
		return saturate(((pixelColor.rgb - 0.5f) * max(contrast, 0)) + 0.5f);
	}

	half Threshold(float a, float Gain, float Contrast)
	{
		float input = a * Gain;
		//float thresh = input - Contrast;
		float thresh = ContrastF(input, Contrast);
		//调整对比度后小于0的则直接截断
		return saturate(lerp(0.0f, input, thresh));
	}

	float NoiseSamplerLoop(float3 p)
	{
		float n = 0, iter = 1;
		n += tex3Dlod(_NoiseVolume, float4(p, 0));
		//return n;
		
		for (int i = 0; i < Octaves; i++)
		{
			p /= 1 + i*.06;
			p += Speed.rgb *_BaseRelativeSpeed * (i*.15 + 1);

			/*
			#ifdef EARTH_CLOUD_STYLE
			n += tex3Dlod(_NoiseVolume, float4(p * float3(.5, 1, .5), 0));	
			n += tex3Dlod(_NoiseVolume, float4(p*.3, 0))*2+ (heightGradient.x);
			
			n = (n-1);	//n *= n*.57;

			#else*/
				n += tex3Dlod(_NoiseVolume, float4(p, 0));
			//#endif
		}
		
		n = n / Octaves;
		return n;
	}

	float noise(in float3 p, half DistanceFade)
	{
		float Volume = 0;
		float lowFreqScale = BaseTiling;


		half NoiseBaseLayers = 0;

		if (Coverage > 0.01)
			NoiseBaseLayers = NoiseSamplerLoop(p * lowFreqScale);
		
		NoiseBaseLayers = Threshold(NoiseBaseLayers, Coverage * NoiseAtten, threshold);//实现coverage
		//return NoiseBaseLayers;
		half NoiseDetail = 0;

		//将mainLayer放大后取补集来作为Detail的Mask
		half BaseMask = saturate((1 - NoiseBaseLayers * _DetailMaskingThreshold));

		//BaseMask = -1;
		//因为原始噪声是梯度的，因此，baselayer和basemask都>0的区域即是baselayer云彩外围intensity较低的区域
		//且threshold越大，则筛选出来的边界越窄
		if (DistanceFade > 0 && NoiseBaseLayers>0 && BaseMask>0)//no me samplees donde ya es opaco del tó
		{
			NoiseDetail += BaseMask*DistanceFade*(tex3Dlod(_NoiseVolume, float4(p*DetailTiling + Speed * _DetailRelativeSpeed, 0)).r);

			if (Octaves > 1 )
				NoiseDetail += DistanceFade*(tex3Dlod(_NoiseVolume,
					//size and offset
					float4(p * .5 * DetailTiling + .5
						//distortion
						+ NoiseDetail * _Curl * BaseMask * 2.0 - 1.0
						//animation
						+ Speed * _DetailRelativeSpeed, 0)).r) * 1.5 * BaseMask;

			NoiseDetail = Threshold(NoiseDetail, 1, 0);
		}
		//return NoiseDetail;
		//base layer (coverage)
		Volume += NoiseBaseLayers;

		//add detail layer
		//从表现上来看，range越大，低透明度区域越小
		//首先，detail > 0 的区域都是base半透明的区域，因此range越大，则base透明度越容易变成0
		Volume -= NoiseDetail * _NoiseDetailRange;
		//剩余的部分则放大，包括了前面basemask < 0的区域
		Volume *= 1 + _NoiseDetailRange;
		//Dentity取负值即可观察到Detail形状
		Volume *= NoiseDensity;
		//return NoiseDetail;


		return saturate(Volume);
	}
	
	float3 VolumeSpaceCoords = 0;
	float3 VolumeSpaceCoordsWorldSpace = 0;

	fixed4 frag (v2f i) : SV_Target
	{
		float3 ViewDir = normalize(i.LocalPos - i.LocalEyePos);

		float tmin = 0.0, tmax = 0.0;
		bool hit = IntersectBox(i.LocalEyePos, ViewDir, _BoxMin.xyz, _BoxMax.xyz, tmin, tmax);
		if (!hit)
			discard;
		if (tmin < 0)
			tmin = 0;

		float4 ScreenUVs = UNITY_PROJ_COORD(i.ScreenUVs);
		float2 screenUV = ScreenUVs.xy / ScreenUVs.w;

		float Depth = 0;
		Depth = tex2D(_CameraDepthTexture, screenUV).r;
		Depth = LinearEyeDepth(Depth);

		//return float4( Depth.xxx, 1);
		Depth = length(Depth / normalize(i.ViewPos).z);

		float thickness = tmax - tmin;//min(max(tmin, tmax), Depth) - min(min(tmin, tmax), Depth);
		float Fog = thickness / 25;

		Fog = 1.0 - exp(-Fog);
		//return Fog;

		float4 Final = 0;
		float3 Normalized_CameraWorldDir = normalize(i.Wpos - _WorldSpaceCameraPos);
		float3 CameraLocalDir = ViewDir;//(i.LocalPos - i.LocalEyePos);

		half jitter = 1;
		jitter = remap_tri(nrand(ScreenUVs + frac(_Time.x)));
		jitter = lerp(1, jitter, _jitter);

		Speed *= _Time.x;

		half DistanceFade = 0;
		half SphereDistance = 0;
		half DetailCascade0 = 0;
		half DetailCascade1 = 0;
		half DetailCascade2 = 0; 

		half absorption = 1;
		half3 AmbientColor = 1;
		half3 AmbientTerm = 1;
		half SelfShadows = 1;
		float OpacityTerms = 0;
		float4 FinalNoise = 0;

		float4 Noise = 1;
		float3 rayStart = i.LocalEyePos + ViewDir * tmin;
		float3 rayStop = i.LocalEyePos + ViewDir * tmax;
		float3 rayDir = rayStop - rayStart;
		float RayLength = length(rayDir);

		float t = 0;
		float dt = _RayStep;
		float3 r0 = rayStart;
		float3 rd = normalize(rayDir);

		t *= jitter;
		dt *= jitter;

		for(int s = 1; s < STEP_COUNT && RayLength > 0; s += 1, t += dt, RayLength -= dt)
		{

			dt *= 1 + s*s*s*_OptimizationFactor;
			float3 pos = r0 + rd * t;
			VolumeSpaceCoords = pos;
			VolumeSpaceCoordsWorldSpace = mul((float3x3)unity_ObjectToWorld, (float3)VolumeSpaceCoords + _VolumePosition.xyz);
			float3 NoiseCoordinates = VolumeSpaceCoords * (_3DNoiseScale * Stretch.rgb);

			DistanceFade = distance(VolumeSpaceCoordsWorldSpace, _WorldSpaceCameraPos);
			DetailCascade0 = 1 - saturate(DistanceFade / DetailDistance);
			//DetailCascade1 = 1 - saturate(DistanceFade / DirectLightingDistance);

			DistanceFade = saturate(DistanceFade / FadeDistance);
			DistanceFade = 1 - DistanceFade;
			if(DistanceFade < .001) break;

			NoiseAtten = gain; //noise intensity
			NoiseAtten *= DistanceFade;

			#if Twirl_X || Twirl_Y || Twirl_Z
			
			float3 rotationDegree = length(NoiseCoordinates) * _Vortex + _Rotation + _RotationSpeed * _Time.x;
			NoiseCoordinates = rotate(NoiseCoordinates , rotationDegree);
			#endif

			if(NoiseAtten > 0)
			{

				Noise = noise(NoiseCoordinates, DetailCascade0);
				//Debug
				//return float4(Noise.rgb, 1);
				if(Noise.a > 0)
					Noise *= DistanceFade;
			}
			else
			{
				Noise = 0;
			}

			half absorptionFactor = lerp(1, 200, Absorption);
			half d = Noise.a;
			//布格尔（朗伯）定律 
			//http://home.ustc.edu.cn/~rambo/kejian/gx/ch5-12.pdf
			half Beers = exp(-d* absorptionFactor) * absorptionFactor;
			half Powder = 1 - exp(-d * 2);
			absorption = lerp(1, saturate(Beers*Powder), Absorption);
			//absorption = exp(-absorptionFactor * d * dt);//TEST

			AmbientTerm.rgb = _AmbientColor.rgb;
			AmbientTerm *= absorption;

			//if(Noise.a > 0)
			//	SelfShadows = Shadow(NoiseCoordinates, i, DetailCascade0, LightVector* ShadowShift, NoiseAtten);
			HeightAtten = 1;
			SelfShadows *= HeightAtten;
			OpacityTerms = Noise.a;//*Contact

			half3 LightTerms = OpacityTerms * AmbientTerm.rgb;
			//LightTerms += AmbientTerm*Noise.a;
			LightTerms *= 2;//TODO

			//noise浓度越高，则该step对最后结果贡献越小
			FinalNoise = FinalNoise + float4(Noise.a * AmbientTerm.rgb - Noise.a * Noise.a * AmbientTerm.rgb,
			Noise.a);//float4(LightTerms, OpacityTerms)  * (1.0 - FinalNoise.a);
			if (FinalNoise.a > .999)break;

		}

		return FinalNoise;
	}
	ENDCG

	SubShader
	{
		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True"  "RenderType" = "None" }
		Blend SrcAlpha OneMinusSrcAlpha 
		LOD 600
		Fog{ Mode Off }
		Cull Front
		Lighting Off
		ZWrite Off
		ZTest Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _ Twirl_X Twirl_Y Twirl_Z
			#pragma exclude_renderers d3d9
			#pragma target 3.0
			ENDCG
		}
	}
}
