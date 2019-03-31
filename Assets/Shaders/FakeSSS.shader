Shader "Unlit/FakeSSS"
{
	Properties
	{
		_BaseMap("Base Map", 2D) = "white" {}
		_BaseColor("Tint", Color) = (0.2, 0.5, 0.9, 1.0)
		_BaseScale("Base Scale", Float) = 1
		_Shininess("Shininess", Range(0.03, 1)) = 0.5
		_SSS_Scale("SSS Scale", Range(0, 2)) = 1
		_Wrap_Scale("Wrap Scale", Range(0, 2)) = 1
		_Ambient_Absorption("Ambient Absorption", Range(0, 1)) = 0.5
		_Ambient_Offset("Ambient Offset", Range(-1, 1)) = 0
		_SpecularSthrength("Specular Strength", Range(0, 1)) = 1
		_ReflectStrength("ReflectStrenth", Range(0, 1)) = 1
		_ThicknessTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase"}
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			#pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"	
			#include "UnityStandardBRDF.cginc"	
			#include "AutoLight.cginc"	
			#include "UnityGlobalIllumination.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				float4 uv1 : TEXCOORD1;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float3 worldPos : TEXCOORD2;
				float3 worldNormal : TEXCOORD3;
				UNITY_LIGHTING_COORDS(4,5)
			    #if UNITY_SHOULD_SAMPLE_SH
			    	half3 sh : TEXCOORD6; // SH
			    #endif			    
				float4 pos : SV_POSITION;
			};

			sampler2D _ThicknessTex;
			sampler2D _BaseMap;
			float4 _ThicknessTex_ST;
			float4 _BaseColor;
			float _Shininess;
			float _SSS_Scale;
			float _Wrap_Scale;
			float _Ambient_Absorption;
			float _Ambient_Offset;
			float _ReflectStrength;
			float _SpecularSthrength;
			float _BaseScale;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _ThicknessTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				UNITY_TRANSFER_FOG(o,o.pos);
				UNITY_TRANSFER_LIGHTING(o, v.uv1);
				#ifndef LIGHTMAP_ON
					#if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
						o.sh = 0;
						o.sh = ShadeSHPerVertex (o.worldNormal, o.sh);
					#endif
				#endif
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
			    #ifndef USING_DIRECTIONAL_LIGHT
			  		fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
			    #else
			  		fixed3 lightDir = _WorldSpaceLightPos0.xyz;
			    #endif
				i.worldNormal = normalize(i.worldNormal);
				float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				float3 halfDir = normalize(lightDir + viewDir);

				half nl = saturate(dot(lightDir, i.worldNormal));
				float nh = saturate(dot(halfDir, i.worldNormal));
				half nv = saturate(dot(viewDir, i.worldNormal));
				float lh = saturate(dot(halfDir, lightDir));

				float thickness = tex2D(_ThicknessTex, i.uv);
				float wrap_diffuse = saturate(dot(lightDir, i.worldNormal) + _Wrap_Scale)/ ((1 + _Wrap_Scale) * (1 + _Wrap_Scale));

				float perceptualRoughness = 1 - _Shininess;
				float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

				half V = SmithBeckmannVisibilityTerm(nl, nv, roughness);
				half D = NDFBlinnPhongNormalizedTerm(nh, PerceptualRoughnessToSpecPower(roughness));
				float spec = V * D * UNITY_PI;
				#ifdef UNITY_COLORSPACE_GAMMA
			        spec = sqrt(max(1e-4h, spec));
				#endif
		        spec = max(0, spec * nl);
			
				float3 albedo = tex2D(_BaseMap, i.uv).rgb;
				float3 sss = _BaseColor * albedo * (1 - thickness) * _SSS_Scale;

				//metallic is always 0
				half3 specColor = unity_ColorSpaceDielectricSpec.rgb;
				half oneMinusReflectivity = unity_ColorSpaceDielectricSpec.a;
				_BaseColor *= oneMinusReflectivity;

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				//gi				
				UnityGI gi;
				UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
				UnityGIInput giInput;
				UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);	
				giInput.worldViewDir = viewDir;
				giInput.probeHDR[0] = unity_SpecCube0_HDR;
				giInput.probeHDR[1] = unity_SpecCube1_HDR;
				#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
					giInput.boxMin[0] = unity_SpecCube0_BoxMin;
				#endif			

				fixed3 ambient = ShadeSH9(half4(i.worldNormal, 1.0));
				//f0 doesn't make any sence
				Unity_GlossyEnvironmentData glossy = UnityGlossyEnvironmentSetup(_Shininess, viewDir, i.worldNormal, 1); 
				gi = UnityGlobalIllumination(giInput, 1, i.worldNormal, glossy);
				//return fixed4(gi.indirect.diffuse, 1);
				#ifdef UNITY_COLORSPACE_GAMMA
		            ambient = LinearToGammaSpace(ambient);
		        #endif
		        ambient *= 1 - saturate(_Ambient_Absorption * (thickness - _Ambient_Offset));
		        atten = saturate((atten + _Wrap_Scale)/ (1 + _Wrap_Scale));

		        half surfaceReduction;
		        #ifdef UNITY_COLORSPACE_GAMMA
		        	surfaceReduction = 1.0 - 0.28 * roughness * perceptualRoughness;
		        #else
		        	surfaceReduction = 1.0 / (roughness * roughness + 1.0);
		        #endif
		        half grazingTerm = saturate(_Shininess + (1-oneMinusReflectivity));
		        
		        //todo: gi.indirect.diffuse doesn't work
				half4 color = half4(sss * max(_LightColor0, ambient) + (wrap_diffuse * max(_LightColor0.rgb, ambient) + ambient) * _BaseColor * albedo * _BaseScale
					+ _SpecularSthrength * spec * _LightColor0 * FresnelTerm(specColor, lh) 
					+ _ReflectStrength * FresnelLerp(specColor, grazingTerm, nv) * gi.indirect.specular * surfaceReduction, 1);				
				UNITY_APPLY_FOG(i.fogCoord, col);
				return color * atten;
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
