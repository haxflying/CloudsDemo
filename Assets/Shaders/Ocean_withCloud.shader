Shader "BrunetonsOcean/Ocean_widthCloud" 
{
	Properties
	{
		_NoiseTex("Noise Texture",2D) = "white"{}
		_LayerTex("Layer Texture", 2D) = "white"{}
		_SeaColor("Sea Color", Color) = (0.0039, 0.046, 0.09, 1)
		_FogColor("Fog Color", Color) = (1,1,1,1)
		_FogDensity("Fog Density", Range(0, 5)) = 1
		_FogDistance("Fog Distance",Float) = 5000

		_Coverage("Coverage",Range(0.0, 1.0)) = 1.0
		_CloudColor("Cloud Color", Color) = (1,1,1,1)
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
		Tags{ "RenderType"="ProjectedGrid" "IgnoreProjector"="True" "Queue"="Transparent-101" }

		zwrite on
		cull[_CullFace]
		//Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			Tags{"LightMode" = "ForwardBase"}
			CGPROGRAM
			#include "UnityCG.cginc"
			
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 4.0
			#pragma exclude_renderers d3d11_9x
			#pragma exclude_renderers d3d9
			#define PI 3.1415926
			#define EPSILON 1e-3
			#define vec2 float2
			#define vec3 float3
			#define vec4 float4
			#define mix lerp
			#define fract frac
			#define mat3 float3x3
			#define iTime _Time.y
			#define textureLod tex2Dlod
			#define SEA_TIME (1.0 + _Time.y * SEA_SPEED)
			#define EPSILON_NRM 0.01
			#define LOW_SCATTER vec3(1.0, 0.7, 0.5);
			#define EARTH_RADIUS 6300e3
			#define CLOUD_START 800.0
			#define CLOUD_HEIGHT 600.0

			int ITER_GEOMETRY = 3;
			int ITER_FRAGMENT = 5;
			float SEA_HEIGHT = 0.6;
			float SEA_CHOPPY = 4.0;
			float SEA_SPEED = 0.8;
		 	float SEA_FREQ = 0.16;
			vec3 SEA_BASE = vec3(0.1,0.19,0.22);
			vec3 SEA_WATER_COLOR = vec3(0.8,0.9,0.6);
			float BASE_SCALE;
			float4x4 _Interpolation;
			float4 _FogColor;
			float _FogDensity, _FogDistance;
			float4 _LightColor0;

			sampler2D _NoiseTex;
			float4 _NoiseTex_TexelSize;
			sampler2D _LayerTex;
			float _Coverage;
			float4 _CloudColor;
			
			struct v2f 
			{
    			float4  pos : SV_POSITION;
				float4 worldPos : TEXCOORD0;
				float4 screenPos : TEXCOORD1;
				float3 rayDir : TEXCOORD2;
			};


			float cnoise( in vec3 x )
			{
			    vec3 p = floor(x);
			    vec3 f = fract(x);
			    f = f*f*(3.0-2.0*f); 
			    vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
				vec2 rg = tex2Dlod( _NoiseTex, float4((uv+0.5)/_NoiseTex_TexelSize.zw, 0, 0)).yx;
				return mix( rg.x, rg.y, f.z );
			}

			float fbm( vec3 p )
			{
			    mat3 m = mat3( 0.00,  0.80,  0.60,
			              -0.80,  0.36, -0.48,
			              -0.60, -0.48,  0.64 );    
			    float f;
			    f  = 0.5000*cnoise( p ); p = mul(m,p)*2.02;
			    f += 0.2500*cnoise( p ); p = mul(m,p)*2.03;
			    f += 0.1250*cnoise( p );	
			    return f;
			}

			float clouds(vec3 p, out float cloudHeight, bool fast)
			{
			    float atmoHeight = length(p - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
			    cloudHeight = clamp((atmoHeight-CLOUD_START)/(CLOUD_HEIGHT), 0.0, 1.0);
			    p.z += iTime*10.3;
			    float largeWeather = clamp((textureLod(_LayerTex, float4(-0.00005*p.zx, 0,0)).g-0.18)*5.0, 0.0, 2.0);
			    p.x += iTime*8.3;
			    float weather = largeWeather*max(0.0, textureLod(_LayerTex, float4(0.0002*p.zx, 0,0)).r-0.18)/0.72;
			    weather *= smoothstep(0.0, 0.5, cloudHeight) * smoothstep(1.0, 0.5, cloudHeight);
			    float cloudShape = pow(weather, 0.3+1.5*smoothstep(0.2, 0.5, cloudHeight)) * _Coverage;
			    if(cloudShape <= 0.0)
			        return 0.0;    
			    
			    p.x += iTime*12.3;
				float den= max(0.0, cloudShape-0.7*fbm(p*.01));
			    if(den <= 0.0)
			        return 0.0;
			    
			    if(fast)
			    	return largeWeather*0.2*min(1.0, 5.0*den);

			    p.y += iTime*15.2;
			    den= max(0.0, den-0.2*fbm(p*0.05));
			    return largeWeather*0.2*min(1.0, 5.0*den);

			}

			float hash( vec2 p ) {
				float h = dot(p,vec2(127.1,311.7));	
			    return fract(sin(h)*43758.5453123);
			}

			float noise( in vec2 p ) {
			    vec2 i = floor( p );
			    vec2 f = fract( p );	
				vec2 u = f*f*(3.0-2.0*f);
			    return -1.0+2.0*mix( mix( hash( i + vec2(0.0,0.0) ), 
			                     hash( i + vec2(1.0,0.0) ), u.x),
			                mix( hash( i + vec2(0.0,1.0) ), 
			                     hash( i + vec2(1.0,1.0) ), u.x), u.y);
			}

			float sea_octave(vec2 uv, float choppy) {
			    uv += noise(uv);        
			    vec2 wv = 1.0-abs(sin(uv));
			    vec2 swv = abs(cos(uv));    
			    wv = mix(wv,swv,wv);
			    return pow(1.0-pow(wv.x * wv.y,0.65),choppy);
			}

			float map(vec3 p) {
			    float freq = SEA_FREQ;
			    float amp = SEA_HEIGHT;
			    float choppy = SEA_CHOPPY;
			    vec2 uv = p.xz; uv.x *= 0.75;			    
			    float d, h = 0.0;   
		    
			    const float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.6); 
			    for(int i = 0; i < ITER_GEOMETRY; i++) {        
			    	d = sea_octave((uv+SEA_TIME)*freq,choppy);
			    	d += sea_octave((uv-SEA_TIME)*freq,choppy);
			        h += d * amp;        
			    	uv = mul(octave_m, uv); 
			    	freq *= 1.9; 
			    	amp *= 0.22;
			        choppy = mix(choppy,1.0,0.2);
			    }
			    return h;
			}

			float map_detailed(vec3 p) {
			    float freq = SEA_FREQ;
			    float amp = SEA_HEIGHT;
			    float choppy = SEA_CHOPPY;
			    vec2 uv = p.xz; uv.x *= 0.75;
			    
			    float d, h = 0.0;    
			    const float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.6); 
			    for(int i = 0; i < ITER_FRAGMENT; i++) {        
			    	d = sea_octave((uv+SEA_TIME)*freq,choppy);
			    	d += sea_octave((uv-SEA_TIME)*freq,choppy);
			        h += d * amp;        
			    	uv = mul(octave_m, uv); 
			    	freq *= 1.9; 
			    	amp *= 0.22;
			        choppy = mix(choppy,1.0,0.2);
			    }
			    return h;
			}

			vec3 getNormal(vec3 p, float eps) {
			    vec3 n;
			    n.y = map_detailed(p);    
			    n.x = map_detailed(vec3(p.x+eps,p.y,p.z)) - n.y;
			    n.z = map_detailed(vec3(p.x,p.y,p.z+eps)) - n.y;
			    n.y = eps;
			    return normalize(n);
			}

			vec3 getSkyColor(vec3 e) {
			    e.y = max(e.y,0.0);
			    return vec3(pow(1.0-e.y,2.0), 1.0-e.y, 0.6+(1.0-e.y)*0.4);
			}

			float diffuse(vec3 n,vec3 l,float p) {
			    return pow(dot(n,l) * 0.4 + 0.6,p);
			}

			float specular(vec3 n,vec3 l,vec3 e,float s) {    
			    float nrm = (s + 8.0) / (PI * 8.0);
			    return pow(max(dot(reflect(e,n),l),0.0),s) * nrm;
			}

			float D_GGX(in float r, in float NoH, in vec3 h)
			{
			    float a = NoH * r;
			    float k = r / ((1.0 - NoH * NoH) + a * a);
			    return k * k * (1.0 / PI);
			}

			float Schlick (float f0, float VoH )
			{
				return f0+(1.-f0)*pow(1.0-VoH,5.0);
			}

			float HenyeyGreenstein(float mu, float inG)
			{
				return (1.-inG * inG)/(pow(1.+inG*inG - 2.0 * inG*mu, 1.5)*4.0* PI);
			}

			float ComputeFogFactor(float coord)
			{
				float fog = _FogDensity * coord;
        		fog = exp2(-fog);
        		return saturate(fog);
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

			float reflectFromCloud(float3 n, float3 p)
			{
				const float ATM_START = EARTH_RADIUS+CLOUD_START;
				const float ATM_END = ATM_START+CLOUD_HEIGHT;
				float distToAtmStart = intersectSphere(p, n, vec3(0.0, -EARTH_RADIUS, 0.0), ATM_START);
				float distToAtmEnd = intersectSphere(p, n, vec3(0.0, -EARTH_RADIUS, 0.0), ATM_END);
				p = p + distToAtmStart * n;
				int nbSample = 3;
				float stepS = (distToAtmEnd - distToAtmStart)/(float(nbSample));
				//p += n*stepS*hash(dot(n, vec3(12.256, 2.646, 6.356)) + _Time.y);
				float cloud = 0;
				[loop]
				for (int i = 0; i < nbSample; ++i)
				{
					float cloudHeight;
					float density = clouds(p, cloudHeight, true);
					if(density > 0)
					{
						cloud = density;
						break;
					}
					p += stepS * n;
				}
				return cloud;
			}


			vec3 getSeaColor(vec3 p, vec3 n, vec3 l, vec3 eye, vec3 dist) {  
				float NoV = clamp(abs(dot(n, eye))+1e-5,0.0, 1.0);
			    float fresnel = Schlick(0.02, NoV);

			    float3 sun_power = saturate(dot(vec3(0,1,0),l) + 0.05);
			    float3 sun_color = _LightColor0.rgb * sun_power;
			    float3 spec = specular(n, -l, eye, 70) * sun_color * 30;
			    //return reflectFromCloud(n, p);
			    vec3 reflected = (getSkyColor(reflect(eye,n)) + reflectFromCloud(n, p) * _CloudColor) * sun_power + spec; 
			    vec3 refracted = (SEA_BASE + diffuse(n, l, 80) * SEA_WATER_COLOR * 0.12) * sun_power; 
			    vec3 foam = 9.0*max(0.0, smoothstep(0.35, 0.6, p.y - SEA_HEIGHT / 3) * n.x);

			    //refracted += foam;
			    vec3 color = mix(refracted,reflected,fresnel);

			    float fog = ComputeFogFactor(length(dist)/_FogDistance);
				color = lerp(color, _FogColor.rgb * sun_power, 1 - fog);
			    
			    return color;
			}

			
			v2f vert(appdata_base v)
			{

				float2 uv = v.texcoord.xy;

				//Interpolate between frustums world space projection points. p is in world space.
				float4 p = lerp(lerp(_Interpolation[0], _Interpolation[1], uv.x), lerp(_Interpolation[3], _Interpolation[2], uv.x), uv.y);
				p = p / p.w;

				//displacement
				float4 dp = float4(0, 0, 0, 0);
				float height = map(p * BASE_SCALE);
				dp.y += height;

				v2f OUT;
    			OUT.pos = mul(UNITY_MATRIX_VP, p+dp);
				OUT.worldPos = p + dp;
			    OUT.screenPos = ComputeScreenPos(OUT.pos);
			    
			    OUT.rayDir = normalize(-OUT.worldPos);
    			return OUT;
			}
			

			float4 frag(v2f IN) : SV_Target
			{
				float3 p = IN.worldPos;
				float3 n = getNormal(p * BASE_SCALE, EPSILON_NRM);
				n.xz *= -1;
				float3 l = _WorldSpaceLightPos0.xyz;
				float3 v = normalize(_WorldSpaceCameraPos - p);
				float3 dist = p - _WorldSpaceCameraPos;
				float3 color = getSeaColor(p, n, l, v, dist);
				
				//return 1 - fog;
				return float4(color, 1.0);
			}
			
			ENDCG

    	}
	}
}



