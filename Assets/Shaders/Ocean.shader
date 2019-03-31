Shader "BrunetonsOcean/Ocean" 
{
	Properties
	{
		_SeaColor("Sea Color", Color) = (0.0039, 0.046, 0.09, 1)
		_FoamColor("Foam Color", Color) = (1,1,1,1)
		_FogColor("Fog Color", Color) = (1,1,1,1)
		_FogDensity("Fog Density", Range(0, 5)) = 1
		_FogDistance("Fog Distance",Float) = 5000
		ITER_GEOMETRY("ITER_GEOMETRY", Range(1,6)) = 3
		ITER_FRAGMENT("ITER_FRAGMENT", Range(1,9)) = 3
		SEA_HEIGHT("SEA_HEIGHT",Float) = 0.6
		SEA_CHOPPY("SEA_CHOPPY", Float) = 4.0
		SEA_SPEED("SEA_SPEED",Float) = 0.8
		SEA_FREQ("SEA_FREQ",Float) = 0.16
		SEA_BASE("SEA_BASE",Color) = (0.1, 0.19,0.22,1.0)
		SEA_WATER_COLOR("SEA_WATER_COLOR",Color) = (0.8, 0.9, 0.6, 1.0)
		BASE_SCALE("BASE_SCALE",Float) = 1.0

		_SunSize ("Sun Size", Range(0,1)) = 0.04
	    _SunSizeConvergence("Sun Size Convergence", Range(1,10)) = 5

	    _AtmosphereThickness ("Atmosphere Thickness", Range(0,5)) = 1.0
	    _NightColor("NightSkyColor", Color) = (0,0,0,0)
	    _SkyTint ("Sky Tint", Color) = (.5, .5, .5, 1)
	    _GroundColor ("Ground", Color) = (.369, .349, .341, 1)

	    _Exposure("Exposure", Range(0, 8)) = 1.3
	}
	SubShader
	{
		Tags{ "RenderType"="ProjectedGrid" "IgnoreProjector"="True" "Queue"="Transparent-101" }

		zwrite on
		cull[_CullFace]
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			Tags{"LightMode" = "ForwardBase"}
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "Atmosphere.cginc"

			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			#define PI 3.1415926
			#define EPSILON 1e-3
			#define vec2 float2
			#define vec3 float3
			#define vec4 float4
			#define mix lerp
			#define fract frac
			#define SEA_TIME (1.0 + _Time.y * SEA_SPEED)
			#define EPSILON_NRM 0.01
			#define LOW_SCATTER vec3(1.0, 0.7, 0.5);
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
			float4 _FoamColor;
			float _FogDensity, _FogDistance;
			float4 _NightColor;
			
			/*
			struct v2f 
			{
    			float4  pos : SV_POSITION;
				float4 worldPos : TEXCOORD0;
				float4 screenUV : TEXCOORD1;
				float3 rayDir : TEXCOORD2;
			};*/

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
        		fog = exp(-fog);
        		return saturate(fog);
			}


			vec3 getSeaColor(vec3 p, vec3 n, vec3 l, vec3 eye, vec3 dist, vec3 skyCol, vec3 sunCol) {  
				float NoV = clamp(abs(dot(n, eye))+1e-5,0.0, 1.0);
			    float fresnel = Schlick(0.02, NoV);

			    float3 sun_power = saturate(dot(vec3(0,1,0),l) + 0.05);
			    float3 sun_color = _LightColor0.rgb * sun_power;
			    float3 spec = specular(n, -l, eye, 70) * sunCol * 500;
			    
			    vec3 reflected = skyCol + spec; 
			    vec3 refracted = (SEA_BASE + diffuse(n, l, 80) * SEA_WATER_COLOR * 0.12) * sun_power; 
			    vec3 foam = 9.0*max(0.0, smoothstep(0.35, 0.6, p.y - SEA_HEIGHT / 3) * n.x);

			    //refracted += foam;
			    vec3 color = mix(refracted,reflected,fresnel);

			    float fog = ComputeFogFactor(length(dist)/_FogDistance);
				color = lerp(color, _FogColor.rgb * skyCol, 1 - fog);
			    
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
				OUT.wpos = p + dp;
				OUT.screenUV = ComputeScreenPos(OUT.pos);
				OUT.ray = mul(UNITY_MATRIX_V, OUT.wpos);
    			return OUT;
			}
			
			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			float4 frag(v2f IN) : SV_Target
			{	
				float2 uv = IN.screenUV.xy / IN.screenUV.w;	
				float zdepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv.xy);
				zdepth = Linear01Depth(zdepth);
				float3 p = IN.wpos;
				float3 n = getNormal(p * BASE_SCALE, EPSILON_NRM);
				n.xz *= -1;
				float3 l = _WorldSpaceLightPos0.xyz;
				float3 v = normalize(_WorldSpaceCameraPos - p);
				float3 dist = p - _WorldSpaceCameraPos;			
				
				float3 dir = -v;//reflect(v, n);
				dir.y *= -1;
				//dir.y = 1 - dir.y;
				//dir = normalize(dir);
				vert_bg(dir, IN);

				float grayScle = (IN.skyColor.r + IN.skyColor.g + IN.skyColor.b)/1.0;
				float3 sky = lerp(_NightColor, IN.skyColor, saturate(grayScle));

				//return float4(sky, 1);
				//return float4(dir.y, 0, 0, 1);
				float3 color = getSeaColor(p, n, l, v, dist, sky, IN.sunColor * saturate(l.y + 0.1));

				float3 ray = mul(unity_CameraInvProjection, float4((float2(uv.x, uv.y) - 0.5) * 2, -1, -1));
				ray *= _ProjectionParams.z / ray.z;
				float3 vpos = ray * zdepth;
				float3 wpos = mul(unity_CameraToWorld, float4(vpos, 1));
				float diff = length(vpos) - length(IN.ray);
				diff = length(wpos - p);
				//return float4(diff / _ProjectionParams.z, 0, 0, 1);
				float alpha = saturate(pow(diff, 0.2) / 2.2);
				color = lerp(color, _FoamColor * saturate(sky + 0.3), 1 - saturate(diff));
				return float4(color, alpha);
			}
			
			ENDCG

    	}
	}
}



