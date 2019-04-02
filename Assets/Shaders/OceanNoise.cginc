#define PI 3.1415926
#define EPSILON 1e-3
#define vec2 float2
#define vec3 float3
#define vec4 float4
#define mix lerp
#define fract frac
#define SEA_TIME (1.0 + _ZTime * SEA_SPEED)
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
float _ZTime;

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