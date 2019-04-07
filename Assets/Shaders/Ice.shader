// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Nature/Terrain/Ice" {
    Properties {
        // set by terrain engine
        _GILut("GI Lut", 2D) = "white" {}
        _GIScale("GI Scale", Range(0.0, 1.0)) = 1.0
        _SlopeOffet("Slope Offset", Range(-1.0, 1.0)) = 0

        [HideInInspector] _Control ("Control (RGBA)", 2D) = "red" {}
        [HideInInspector] _Splat3 ("Layer 3 (A)", 2D) = "white" {}
        [HideInInspector] _Splat2 ("Layer 2 (B)", 2D) = "white" {}
        [HideInInspector] _Splat1 ("Layer 1 (G)", 2D) = "white" {}
        [HideInInspector] _Splat0 ("Layer 0 (R)", 2D) = "white" {}
        [HideInInspector] _Normal3 ("Normal 3 (A)", 2D) = "bump" {}
        [HideInInspector] _Normal2 ("Normal 2 (B)", 2D) = "bump" {}
        [HideInInspector] _Normal1 ("Normal 1 (G)", 2D) = "bump" {}
        [HideInInspector] _Normal0 ("Normal 0 (R)", 2D) = "bump" {}
        [HideInInspector] [Gamma] _Metallic0 ("Metallic 0", Range(0.0, 1.0)) = 0.0
        [HideInInspector] [Gamma] _Metallic1 ("Metallic 1", Range(0.0, 1.0)) = 0.0
        [HideInInspector] [Gamma] _Metallic2 ("Metallic 2", Range(0.0, 1.0)) = 0.0
        [HideInInspector] [Gamma] _Metallic3 ("Metallic 3", Range(0.0, 1.0)) = 0.0
        [HideInInspector] _Smoothness0 ("Smoothness 0", Range(0.0, 1.0)) = 1.0
        [HideInInspector] _Smoothness1 ("Smoothness 1", Range(0.0, 1.0)) = 1.0
        [HideInInspector] _Smoothness2 ("Smoothness 2", Range(0.0, 1.0)) = 1.0
        [HideInInspector] _Smoothness3 ("Smoothness 3", Range(0.0, 1.0)) = 1.0

        // used in fallback on old cards & base map
        [HideInInspector] _MainTex ("BaseMap (RGB)", 2D) = "white" {}
        [HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)
    }

    SubShader {
        Tags {
            "Queue" = "Geometry-100"
            "RenderType" = "Opaque"
        }

        CGPROGRAM
        #pragma surface surf StandardLutGI vertex:SplatmapVert finalcolor:SplatmapFinalColor fullforwardshadows noinstancing
        #pragma multi_compile_fog
        #pragma target 3.0
        // needs more than 8 texcoords
        #pragma exclude_renderers gles psp2
        #include "UnityPBSLighting.cginc"

        #pragma multi_compile __ _TERRAIN_NORMAL_MAP

        #define TERRAIN_STANDARD_SHADER
        #define TERRAIN_SURFACE_OUTPUT SurfaceOutputStandard
        //#include "TerrainSplatmapCommon.cginc"

        half _Smoothness0;
        half _Smoothness1;
        half _Smoothness2;
        half _Smoothness3;

        half _SlopeOffet;

        half _GIScale;

        struct Input
		{
		    float2 uv_Splat0 : TEXCOORD0;
		    float2 uv_Splat1 : TEXCOORD1;
		    UNITY_FOG_COORDS(3)
		    float3 wnormal;
		};

        void SplatmapVert(inout appdata_full v, out Input data)
		{
		    UNITY_INITIALIZE_OUTPUT(Input, data);
		    float4 pos = UnityObjectToClipPos(v.vertex);
		    UNITY_TRANSFER_FOG(data, pos);

		    v.tangent.xyz = cross(v.normal, float3(0,0,1));
		    v.tangent.w = -1;
		    data.wnormal = UnityObjectToWorldNormal(v.normal);
		}

		sampler2D _Splat0,_Splat1;
	    sampler2D _Normal0, _Normal1;
	    sampler2D _GILut;

        void CustomMix(Input IN, half4 defaultAlpha, out half weight, out fixed4 mixedDiffuse, out fixed3 mixedNormal)
        {
        	weight = 1;
        	float slope = saturate(1 - IN.wnormal.y - _SlopeOffet);

        	mixedDiffuse = 0;
        	mixedDiffuse += slope * tex2D(_Splat0, IN.uv_Splat0) * half4(1.0, 1.0, 1.0, defaultAlpha.r);
        	mixedDiffuse += (1 - slope) * tex2D(_Splat1, IN.uv_Splat1) * half4(1.0, 1.0, 1.0, defaultAlpha.g);

	        fixed4 nrm = 0.0f;
	        nrm += slope * tex2D(_Normal0, IN.uv_Splat0);
	        nrm += (1 - slope) * tex2D(_Normal1, IN.uv_Splat1);
	        mixedNormal = UnpackNormal(nrm);
        }

        inline half4 LightingStandardLutGI(SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
        {
            return LightingStandard(s, viewDir, gi);
        }

        
        inline void LightingStandardLutGI_GI(
                SurfaceOutputStandard s,
                UnityGIInput data,
                inout UnityGI gi)
        {
            LightingStandard_GI(s, data, gi);
        }

        void SplatmapFinalColor(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 color)
		{
		    color *= o.Alpha;
		    color *= saturate(saturate(_WorldSpaceLightPos0.y) + 0.3);
		    float lerpFactor = saturate(1 - saturate(_WorldSpaceLightPos0.y));
            float3 gidiffuse = tex2D(_GILut, float2(lerpFactor, 0.5)) * _GIScale;
            color += fixed4(gidiffuse, 1);
	        UNITY_APPLY_FOG(IN.fogCoord, color);
		}

        void surf (Input IN, inout SurfaceOutputStandard o) {
            half4 splat_control;
            half weight;
            fixed4 mixedDiffuse;
            fixed3 mixedNormal;
            half4 defaultSmoothness = half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);
            //SplatmapMix(IN, defaultSmoothness, splat_control, weight, mixedDiffuse, o.Normal);
            CustomMix(IN, defaultSmoothness, weight, mixedDiffuse, mixedNormal);
            o.Albedo = mixedDiffuse.rgb;
            o.Alpha = weight;
            o.Normal = mixedNormal;
            o.Smoothness = mixedDiffuse.a;
            o.Metallic = 0;
        }
        ENDCG
    }

    //Dependency "AddPassShader" = "Hidden/TerrainEngine/Splatmap/Standard-AddPass"
    //Dependency "BaseMapShader" = "Hidden/TerrainEngine/Splatmap/Standard-Base"

    Fallback "Nature/Terrain/Diffuse"
}
