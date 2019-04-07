Shader "Custom/Snow" {
	Properties {
		_ColorLight ("Color Light", Color) = (1,1,1,1)
		_ColorDark ("Color Dark", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_NormalMap("NormalMap", 2D) = "white" {}
		_Roughness("Roughness", Vector) = (0.6, 0.6, 0, 0)
		_MicroRoughness("MicroRoughness", Vector) = (0.0144, 0.0144, 0, 0)
		_SearchConeAngle("Search Cone Angle", Float) = 0.01
		_Variation("Variation", Float) = 100
		_DynamicRange("Dynamic Range", Float) = 50000
		_TexScale("TexScale", Float) = 1
		_ShadowLightPercent("Shadow Light Percent", Range(0, 100)) = 2
		//_Density("Density", Float) = 5e8
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Snow fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0
		#define vec2 float2
		#define vec3 float3
		#define vec4 float4
		#define ivec2 half2
		#define mix lerp
		#define fract frac
		#define mat3 float3x3
		#define mat2 float2x2
		#define mod fmod
		#include "UnityPBSLighting.cginc"

		sampler2D _MainTex, _NormalMap;

		struct Input {
			float2 uv_MainTex;
			float2 uv_NormalMap;
			float3 worldPos;
			float3 worldNormal; INTERNAL_DATA
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _ColorLight, _ColorDark;
		float4 _Roughness, _MicroRoughness;
		float _SearchConeAngle, _Variation, _DynamicRange, _TexScale, _ShadowLightPercent;

		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		float hash( float n ) { return fract(sin(mod(n, 3.14))*753.5453123); }
		vec2 hash2( float n ) { return vec2(hash(n), hash(1.1 + n)); }
		float compMax(vec2 v) { return max(v.x, v.y); }
		float maxNrm(vec2 v) { return compMax(abs(v)); }
		mat2 inverse2(mat2 m) {
		    return mat2(m[1][1], -m[0][1], -m[1][0], m[0][0]) / (m[0][0] * m[1][1] - m[0][1] * m[1][0]);
		}

		float erfinv(float x) {
		    float w, p;
		    w = -log((1.0-x)*(1.0+x));
		    if(w < 5.000000) {
		        w = w - 2.500000;
		        p = 2.81022636e-08;
		        p = 3.43273939e-07 + p*w;
		        p = -3.5233877e-06 + p*w;
		        p = -4.39150654e-06 + p*w;
		        p = 0.00021858087 + p*w;
		        p = -0.00125372503 + p*w;
		        p = -0.00417768164 + p*w;
		        p = 0.246640727 + p*w;
		        p = 1.50140941 + p*w;
		    }
		    else {
		        w = sqrt(w) - 3.000000;
		        p = -0.000200214257;
		        p = 0.000100950558 + p*w;
		        p = 0.00134934322 + p*w;
		        p = -0.00367342844 + p*w;
		        p = 0.00573950773 + p*w;
		        p = -0.0076224613 + p*w;
		        p = 0.00943887047 + p*w;
		        p = 1.00167406 + p*w;
		        p = 2.83297682 + p*w;
		    }
		    return p*x;
		}

		float geometryFactor(float NoL, float NoV, vec2 roughness) {
		    float a2 = roughness.x * roughness.y;
		    NoL = abs(NoL);
		    NoV = abs(NoV);

		    float G_V = NoV + sqrt((NoV - NoV * a2) * NoV + a2);
		    float G_L = NoL + sqrt((NoL - NoL * a2) * NoL + a2);
		    return 1. / (G_V * G_L);
		}

		int multilevelGridIdx1(inout int idx) {
		    for (int i = 0; i < 32; ++i) {
		        if (idx / 2 == (idx + 1) / 2)
		          idx /= 2;
		        else
		            break;
		    }
		    return idx;
		}

		ivec2 multilevelGridIdx(ivec2 idx) {
		//  return idx >> findLSB(idx); // findLSB not supported by Shadertoy WebGL version
		    return ivec2(multilevelGridIdx1(idx.x), multilevelGridIdx1(idx.y));
		}

		// stable binomial 'random' numbers: interpolate between result for
		// two closest binomial distributions where log_{.9}(p_i) integers
		float binomial_interp(float u, float N, float p) {
		    if(p >= 1.)
		        return N;
		    else if(p <= 1e-10)
		        return 0.;

		    // convert to distribution on ints while retaining expected value
		    float cN = ceil(N);
		    int iN = int(cN);
		    p = p * (N / cN);
		    N = cN;

		    // round p to nearest powers of .9 (more stability)
		    float pQ = .9;
		    float pQef = log2(p) / log2(pQ);
		    float p2 = exp2(floor(pQef) * log2(pQ));
		    float p1 = p2 * pQ;
		    vec2 ps = vec2(p1, p2);

		    // compute the two corresponding binomials in parallel
		    vec2 pm = pow(1. - ps, (N));
		    vec2 cp = pm;
		    vec2 r = (N);

		    float i = 0.0;
		    // this should actually be < N, no dynamic loops in ShaderToy right now
		    for(int ii = 0; ii <= 17; ++ii)
		    {
		        if(u < cp.x)
		            r.x = min(i, r.x);
		        if(u < cp.y) {
		            r.y = i;
		            break;
		        }
		        // fast path
		        if(ii > 16)
		        {
		            float C = 1. / (1. - pow(p, N - i - 1.));
		            vec2 U = (u - cp) / (1. - cp);
		            vec2 A = (i + 1. + log2(1. - U / C) / log2(p));
		            r = min(A, r);
		            break;
		        }

		        i += 1.;
		        pm /= 1. - ps;
		        pm *= (N + 1. - i) / i;
		        pm *= ps;
		        cp += pm;
		    }

		    // interpolate between the two binomials according to log p (akin to mip interpolation)
		    return mix(r.y, r.x, fract(pQef));
		}

		// resort to gaussian distribution for larger N*p
		float approx_binomial(float u, float N, float p) {
		    if (p * N > 5.)
		    {
		        float e = N * p;
		        float v = N * p * max(1. - p, 0.0);
		        float std = sqrt(v);
		        float k = e + erfinv(mix(-.999999, .999999, u)) * std;
		        return min(max(k, 0.), N);
		    }
		    else
		        return binomial_interp(u, N, p);
		}


		vec3 glints(vec2 texCO, vec2 duvdx, vec2 duvdy, mat3 ctf
		  , vec3 lig, vec3 nor, vec3 view
		  , vec2 roughness, vec2 microRoughness, float searchConeAngle, float variation, float dynamicRange, float density)
		{
		   vec3 col = (0.);

		    // Compute pixel footprint in texture space, step size w.r.t. anisotropy of the footprint
		    mat2 uvToPx = inverse2(mat2(duvdx, duvdy));
		    vec2 uvPP = 1. / vec2(maxNrm(uvToPx[0]), maxNrm(uvToPx[1]));

		    // material
		    vec2 mesoRoughness = sqrt(max(roughness * roughness - microRoughness * microRoughness, (1.e-12))); // optimizer fail, max 0 removed

		    // Anisotropic compression of the grid
		    vec2 texAnisotropy = vec2( min(mesoRoughness.x / mesoRoughness.y, 1.)
		                             , min(mesoRoughness.y / mesoRoughness.x, 1.) );

		    // Compute half vector (w.r.t. dir light)
		    vec3 hvW = normalize(lig + view);
		    vec3 hv = normalize(mul(ctf, hvW));
		    vec2 h = hv.xy / hv.z;
		    vec2 h2 = 0.75 * hv.xy / (hv.z + 1.);
		    // Anisotropic compression of the slope-domain grid
		    h2 *= texAnisotropy;

		    // Compute the Gaussian probability of encountering a glint within a given finite cone
		    vec2 hppRScaled = h / roughness;
		    float pmf = (microRoughness.x * microRoughness.y) / (roughness.x * roughness.y)
		        * exp(-dot(hppRScaled, hppRScaled)); // planeplane h
		    pmf /= hv.z * hv.z * hv.z * hv.z; // projected h
		//  pmf /= dot(lig, nor) * dot(view, nor); // projected area, cancelled out by parts of G, ...
		    float pmfToBRDF = 1. / (3.14159 * microRoughness.x * microRoughness.y);
		    pmfToBRDF /= 4.; // solid angle o
		    pmfToBRDF *= geometryFactor(dot(lig, nor), dot(view, nor), roughness); // ... see "geometryFactor"
		    // phenomenological: larger cones flatten distribution
		    float searchAreaProj = searchConeAngle * searchConeAngle / (4. * dot(lig, hvW) * hv.z); // * PI
		    pmf = mix(pmf, 1., clamp(searchAreaProj, 0.0, 1.0)); // searchAreaProj / PI
		    pmf = min(pmf, 1.);
		    
		    // noise coordinate (decorrelate interleaved grid)
		    texCO += (100.);
		    // apply anisotropy _after_ footprint estimation
		    texCO *= texAnisotropy;

		    // Compute AABB of pixel in texture space
		    vec2 uvAACB = max(abs(duvdx), abs(duvdy)) * texAnisotropy; // border center box
		    vec2 uvb = texCO - 0.5 * uvAACB;
		    vec2 uve = texCO + 0.5 * uvAACB;

		    vec2 uvLongAxis = uvAACB.x > uvAACB.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
		    vec2 uvShortAxis = 1.0 - uvLongAxis;

		    // Compute skew correction to snap axis-aligned line sampling back to longer anisotropic pixel axis in texture space
		    vec2 skewCorr2 = -mul(uvToPx, uvLongAxis) / mul(uvToPx, uvShortAxis);
		    float skewCorr = abs(mul(uvToPx, uvShortAxis).x) > abs(mul(uvToPx, uvShortAxis).y) ? skewCorr2.x : skewCorr2.y;
		    skewCorr *= dot(texAnisotropy, uvShortAxis) / dot(texAnisotropy, uvLongAxis);

		    float isoUVPP = dot(uvPP, uvShortAxis);
		    // limit anisotropy
		    isoUVPP = max(isoUVPP, dot(uvAACB, uvLongAxis) / 16.0);

		     // Two virtual grid mips: current and next
		    float fracMip = log2(isoUVPP);
		    float lowerMip = floor(fracMip);
		    float uvPerLowerC = exp2(lowerMip);

		    // Current mip level and cell size
		    float uvPC = uvPerLowerC;
		    float mip = lowerMip;

		    int iter = 0;
		    int iterThreshold = 60;

		    for (int i = 0; i < 2; ++i)
		    {
		        float mipWeight = 1.0 - abs(mip - fracMip);

		        vec2 uvbg = min(uvb + 0.5 * uvPC, texCO);
		        vec2 uveg = max(uve - 0.5 * uvPC, texCO);

		        // Snapped uvs of the cell centers
		        vec2 uvbi = floor(uvbg / uvPC);
		        vec2 uvbs = uvbi * uvPC;
		        vec2 uveo = uveg + uvPC - uvbs;

		        // Resulting compositing values for a current layer
		        float weight = 0.0;
		        vec3 reflection = (0.0);

		        // March along the long axis
		        vec2 uvo = (0.0), uv = uvbs, uvio = (0.0), uvi = uvbi;
		        for (int iter1 = 0; iter1 < 18; ++iter1) // horrible WebGL-compatible static for loop
		        {
		            // for cond:
		            if (dot(uvo, uvLongAxis) < dot(uveo, uvLongAxis) && iter < iterThreshold);
		            else break;

		            // Snap samples to long anisotropic pixel axis
		            float uvShortCenter = dot(texCO, uvShortAxis) + skewCorr * dot(uv - texCO, uvLongAxis);

		            // Snapped uvs of the cell center
		            uvi += (floor(uvShortCenter / uvPC) - dot(uvi, uvShortAxis)) * uvShortAxis;
		            uv = uvi * uvPC;
		            float uvShortEnd = uvShortCenter + uvPC;

		            vec2 uvb2 = uvbg * uvLongAxis + uvShortCenter * uvShortAxis;
		            vec2 uve2 = uveg * uvLongAxis + uvShortCenter * uvShortAxis;

		            // March along the shorter axis
		            for (int iter2 = 0; iter2 < 4; ++iter2) // horrible WebGL-compatible static for loop
		            {
		                // for cond:
		                if (dot(uv, uvShortAxis) < uvShortEnd && iter < iterThreshold);
		                else break;

		                // Compute interleaved cell index
		                ivec2 cellIdx = ivec2(uvi + (.5));
		                cellIdx = multilevelGridIdx(cellIdx);

		                // Randomize a glint based on a texture-space id of current grid cell
		                vec2 u2 = hash2(float( (cellIdx.x + 1549 * cellIdx.y) ));
		                // Compute index of the cone
		                vec2 hg = h2 / (microRoughness + searchConeAngle);
		                vec2 hs = floor(hg + u2) + u2 * 533.;    // discrete cone index in paraboloid hv grid
		                ivec2 coneIdx = ivec2(hs);

		                // Randomize glint sizes within this layer
		                float var_u = hash(float( (cellIdx.x + cellIdx.y * 763 + coneIdx.x + coneIdx.y * 577) ));
		                float mls = 1. + variation * erfinv(mix(-.999, .999, var_u));
		                if (mls <= 0.0) mls = fract(mls) / (1. - mls);
		                mls = max(mls, 1.e-12);

		                // Bilinear interpolation using coverage made by areas of two rects
		                vec2 mino = max(1.0 - max((uvb2 - uv) / uvPC, 0.0), 0.0);
		                vec2 maxo = max(1.0 - max((uv - uve2) / uvPC, 0.0), 0.0);
		                vec2 multo = mino * maxo;
		                float coverageWeight = multo.x * multo.y;

		                float cellArea = uvPC * uvPC;
		                // Expected number of glints 
		                float eN = density * cellArea;
		                float sN = max(eN * mls, min(1.0, eN));
		                eN = eN * mls;

		                // Sample actually found number of glints
		                float u = hash(float(coneIdx.x + coneIdx.y * 697));
		                float lN = approx_binomial(u, sN, pmf);

		                // Ratio of glinting vs. expected number of microfacets
		                float ratio = lN / eN;
		                
		                // limit dynamic range (snow more or less unlimited)
		                ratio = min(ratio, dynamicRange * pmf);
		                
		                // convert to reflectance
		                ratio *= pmfToBRDF;

		                // Accumulate results
		                reflection += coverageWeight * ratio;
		                weight += coverageWeight;

		                // for incr:
		                uv += uvPC * uvShortAxis, uvi += uvShortAxis, ++iter;
		            }

		            // for incr:
		              uvo += uvPC * uvLongAxis, uv = uvbs + uvo
		            , uvio += uvLongAxis, uvi = uvbi + uvio;
		        }

		        reflection = reflection / weight;

		        // Compositing of two layers
		        col += mipWeight * reflection;

		        // for incr:
		        uvPC *= 2., mip += 1.;
		    }

		    return col;
		}



		float3 worldPos;
		float3 worldNormal;


		inline half4 LightingSnow(SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
        {
        	float3 lig = _WorldSpaceLightPos0.xyz;// normalize(float3(0.6, 0.9, 0.5));
        	float3 lightPower = _LightColor0.xyz;
        	float3 pos = worldPos;
        	float3 nor = s.Normal;
        	float3 rd = normalize(pos - _WorldSpaceCameraPos);

        	float3x3 texProjFrame = float3x3(float3(1,0,0), float3(0,0,1), float3(0,1,0));
        	if(abs(nor.x) > abs(nor.y) && abs(nor.x) > abs(nor.z)){
	    		texProjFrame = float3x3(float3(0,0,1), float3(0,1,0), float3(1,0,0));
	    	}
	    	else if(abs(nor.z) > abs(nor.x) && abs(nor.z) > abs(nor.y)){
	    		texProjFrame = float3x3(float3(1,0,0), float3(0,1,0), float3(0,0,1));
	    	}

        	float3 bitang = normalize(cross(nor, texProjFrame[0]));
        	float3 tang = cross(bitang, nor);
        	float3x3 ctf = float3x3(tang, bitang, nor);

        	//textureing
        	float3 dposdx, dposdy;
        	float texScaling = _TexScale;
        	float2 texCO = texScaling * mul(texProjFrame, pos).xy;
        	float2 duvdx = ddx(texCO);
        	float2 duvdy = ddy(texCO);

        	float dif = saturate(dot(lig, nor));
        	float fre = 1 - pow(1 - dif, 2.5);
        	float dfr = 1 - pow(1 - saturate(dot(nor, -rd)), 2.5);
        	dfr *= fre;

        	float2 roughness = _Roughness;// 0.6;
        	float2 microRoughness= _MicroRoughness * 0.01;// roughness * 0.024;
        	float searchConeAngle = _SearchConeAngle; //0.01;
        	float variation = _Variation;// 100;
        	float dynamicRange = _DynamicRange;// 50000;
        	float density = 5.e8;

        	float3 col = lerp(_ColorDark, _ColorLight, (1 - abs(rd.y)) * dif);
        	col *= lightPower * lerp(_ShadowLightPercent * 0.01, 1, dif);

        	//if(dif > 0 && dot(-rd, nor) > 0)
        	{
        		col += glints(texCO, duvdx, duvdy, ctf, lig, nor, -rd, roughness, 
        			microRoughness, searchConeAngle, variation, dynamicRange, density) * lightPower * dif;
        	}
        	//col = ddx(pos);
        	//tonemap, gamma
        	col *= 1 / (max(max(col.r, col.g), col.b) + 1);
        	col = pow(col, 0.4545);
        	//col = nor;
        	return half4(col, 1);
        }

        
        inline void LightingSnow_GI(
                SurfaceOutputStandard s,
                UnityGIInput data,
                inout UnityGI gi)
        {
            //LightingStandard_GI(s, data, gi);
        }

		void surf (Input IN, inout SurfaceOutputStandard o) {
			
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
			o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));

			worldPos = IN.worldPos;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
