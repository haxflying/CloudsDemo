Shader "UBW/UBW_Terrain"{
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_Splat0 ("Albedo (RGB)", 2D) = "white" {}
		_Smoothness0 ("Smoothness", Range(0,1)) = 0.5
		_Metallic0 ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard vertex:SplatmapVert fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0 

		#define UNITY_LIGHT_ATTENUATION(destName, input, wpos) fixed destName = max(0.6, UNITY_SHADOW_ATTENUATION(input, worldPos));

		sampler2D _Splat0, _Normal0;

		struct Input {
			float2 uv_Splat0;
			float4 screenPos;
		};

		half _Smoothness0;
		half _Metallic0;
		fixed4 _Color;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)


		float sum(float3 v)
		{
			return v.x + v.y + v.z;
		}

		void SplatmapVert(inout appdata_full v, out Input data)
		{
		    UNITY_INITIALIZE_OUTPUT(Input, data);
		    float4 pos = UnityObjectToClipPos(v.vertex);
		    UNITY_TRANSFER_FOG(data, pos);
		    v.tangent.xyz = cross(v.normal, float3(0,0,1));
		    v.tangent.w = -1;
		}


		float4 hash4(float2 p)
		{
			return frac(sin(float4( 1.0+dot(p,float2(37.0,17.0)), 
                                              2.0+dot(p,float2(11.0,47.0)),
                                              3.0+dot(p,float2(41.0,29.0)),
                                              4.0+dot(p,float2(23.0,31.0))))*103.0);
		}

		float4 variationSample(sampler2D tex, float2 x, float v)
		{
			float k = tex2D(tex, 0.5 * x).x;

			float index = k * 8.0;
			float i = floor(index);
			float f = frac(index);

			float2 offa = sin(float2(3, 7) * (i + 0));
			float2 offb = sin(float2(3, 7) * (i + 1));

			float2 dx = ddx(x), dy = ddy(x);

			float4 cola = tex2D(tex, x + v * offa, dx, dy);
			float4 colb = tex2D(tex, x + v * offb, dx, dy);

			return lerp(cola, colb, smoothstep(0.2, 0.8, f - 0.1 * sum(cola - colb)));
		}

		float4 variationSample1(sampler2D tex, float2 uv, float v)
		{
			half2 iuv = floor(uv);
			half2 fuv = frac(uv);

			float4 ofa = hash4( iuv + float2(0,0) );
		    float4 ofb = hash4( iuv + float2(1,0) );
		    float4 ofc = hash4( iuv + float2(0,1) );
		    float4 ofd = hash4( iuv + float2(1,1) );
		    
		    float2 dx = ddx( uv );
		    float2 dy = ddy( uv );

		    // transform per-tile uvs
		    ofa.zw = sign( ofa.zw-0.5 );
		    ofb.zw = sign( ofb.zw-0.5 );
		    ofc.zw = sign( ofc.zw-0.5 );
		    ofd.zw = sign( ofd.zw-0.5 );
		    
		    // uv's, and derivatives (for correct mipmapping)
		    float2 uva = uv*ofa.zw + ofa.xy, ddxa = dx*ofa.zw, ddya = dy*ofa.zw;
		    float2 uvb = uv*ofb.zw + ofb.xy, ddxb = dx*ofb.zw, ddyb = dy*ofb.zw;
		    float2 uvc = uv*ofc.zw + ofc.xy, ddxc = dx*ofc.zw, ddyc = dy*ofc.zw;
		    float2 uvd = uv*ofd.zw + ofd.xy, ddxd = dx*ofd.zw, ddyd = dy*ofd.zw;
		        
		    // fetch and blend
		    float2 b = smoothstep( 0.25,0.75, fuv );
		    
		    return lerp( lerp( tex2D( tex, uva, ddxa, ddya ), 
		                     tex2D( tex, uvb, ddxb, ddyb ), b.x ), 
		                lerp( tex2D( tex, uvc, ddxc, ddyc ),
		                     tex2D( tex, uvd, ddxd, ddyd ), b.x), b.y );
		}
		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			float f = smoothstep(0.4, 0.6, sin(_Time.y));
			fixed4 c = variationSample1(_Splat0, IN.uv_Splat0, f) * _Color;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = 0;
			o.Smoothness = _Smoothness0;
			o.Normal = UnpackNormal(variationSample1(_Normal0, IN.uv_Splat0, f));
			o.Alpha = c.a;
		}
		ENDCG
	}
	Dependency "AddPassShader" = "Hidden/TerrainEngine/Splatmap/Standard-AddPass"
    Dependency "BaseMapShader" = "Hidden/TerrainEngine/Splatmap/Standard-Base"

	FallBack "Nature/Terrain/Specular"
}
