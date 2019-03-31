Shader "SignedDistanceField/Visualizer"
{
    Properties
    {
        [Header(SDF)]
        [Space(10)]
    	[NoScaleOffset]
        _Volume ("Volume", 3D) = "white" {}
        _Scale("Scale", Float) = 1
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _AmbientColor("Ambient Color", Color) = (0,0,0,0)
        _PositionTweak("Position tweak", Vector) = (0,0,0,0)
        _ObjScale("objScale", Float) = 80

        //[MaterialToggle]
        //_Shade ("Render As Solid", int) = 0
        _Density ("Density", float) = 1
        _MaxSteps ("Maximum Steps", int) = 30
        _MaxDistance("Max Distance", Float) = 10
        _Vortex("_Vortex", Float) = 0
        _Rotation("_Rotation", Float) = 0
        _RotationSpeed("_RotationSpeed", Float) = 0

        [Space(20)]
        [Header(Noise)]
        [Space(10)]
        _NoiseVolume("_NoiseVolume", 3D)= "white" {}
        Octaves("Octaves", Float) = 0
        Speed("Speed", Float) = 1
        NoiseFreq("Noise Freq", Float) = 1
    }
    SubShader
    {
        
        //Cull Back
        Pass
        {
            Tags { "RenderType"="Transparent -110" }
            ZWrite On
            ColorMask 0         
        }

        Pass
        {
            Tags { "RenderType"="Transparent -110" }
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #pragma target 4.0
            #pragma exclude_renderers d3d11_9x
            #pragma exclude_renderers d3d9

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 pos : TEXCOORD1;  // object space vertex position;
                float3 wpos : TEXCOORD2;
            };

            sampler3D _Volume, _NoiseVolume, _Volume1;
            float _Density;
            int _Shade;
            int _MaxSteps;
            float4 _BaseColor, _AmbientColor, _LightColor0;
            float _Scale;
            float _MaxDistance;
            float4 _PositionTweak;
            float objScale;
            //nnoise
            float Octaves, Speed, NoiseFreq;
            float _Vortex, _Rotation, _RotationSpeed;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                o.pos = v.vertex;
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            float hash( float2 p ) {
                return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453123);
            }

            bool intersectSphere(float3 origin, float3 dir, float3 spherePos, float sphereRad, out float t0, out float t1)
            {
                float3 oc = origin - spherePos;
                float b = 2.0 * dot(dir, oc);
                float c = dot(oc, oc) - sphereRad*sphereRad;
                float disc = b * b - 4.0 * c;
                if (disc < 0.0)
                    return -1.0;    
                float q = (-b + ((b < 0.0) ? -sqrt(disc) : sqrt(disc))) / 2.0;
                t0 = q;
                t1 = c / q;
                if (t0 > t1) {
                    return false;
                }
                if (t1 < 0.0)
                    return false;
                
                return true;
            }

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
                float4 expValues = exp(float4(bestParams[1] *costh+bestParams[2], bestParams[5] *p1*p1, bestParams[6] *costh, bestParams[9] *costh));
                float4 expValWeight= float4(bestParams[0], bestParams[4], bestParams[7], bestParams[8]);
                return dot(expValues, expValWeight);
            }

            float NoiseSample(float3 p)
            {
                float n = 0, iter = 1;
                n += tex3Dlod(_NoiseVolume, float4(p, 0));

                [loop]
                for(int i = 0; i < Octaves; i++)
                {
                    p /= 1 + i * .06;
                    p += Speed * (i * .15 - _Time.y);
                    n += tex3Dlod(_NoiseVolume, float4(p, 0));
                }
                n /= Octaves;
                return n;
            }

            float Noise(float3 pos)
            {
                float n = NoiseSample(pos);
                return n;
            }

            float3 rotate(float3 p, float rot)
            {
                float3 r = 0;
                float3x3 ry = float3x3(cos(rot), 0.0, -sin(rot), 0.0, 1.0, 0.0, sin(rot), 0.0, cos(rot));
                r = mul(p, ry);
                return r;
            }

            float scene(float3 pos, out float3 normal)
            {
                //float3 rotationDegree = length(float3(pos.x, 0, pos.z)) * _Vortex + _Rotation + _RotationSpeed * _Time.x;
                //pos = rotate(pos, rotationDegree);

                float noise = Noise(pos * NoiseFreq);
                float4 volume = tex3D(_Volume, pos);
                //volume += tex3D(_Volume1, pos).r;

                normal = normalize(volume.rgb) * noise;
                float dist = volume.a * noise;
                return dist;
            }

            /*
            float lightRay(float3 p, float3 dir, float phaseFunction, float dC, float mu, float lightDir, float height)
            {
                int samples = 15;
                float zMaxl = 2;
                float stepL = zMaxl / (float)(samples);
                float lightRayDen = 0;
                p += dir * hash(dot(p, float3(12.256, 2.646, 6.356)) + _Time.y) / 100;
                [loop]
                for (int i = 0; i < samples; i++) {
                    lightRayDen += scene(p + lightDir * float(i) * stepL);               
                }
                float scatterAmount = lerp(0.008, 1.0, smoothstep(0.96, 0.0, mu));
                float beersLaw = exp(-stepL*lightRayDen)+0.5*scatterAmount*exp(-0.1*stepL*lightRayDen)+scatterAmount*0.4*exp(-0.02*stepL*lightRayDen);
                return beersLaw * phaseFunction * lerp(0.05 + 1.5*pow(min(1.0, dC*8.5), 0.3+5.5*height), 1.0, clamp(lightRayDen*0.4, 0.0, 1.0));
            }*/

            /* Accumulate the distance from the object as a density and return it. */
            float raytraceDensity(float3 pos, float3 dir, float maxdist, float density, float4 objInfo, out float3 col) {
            	float uvwOffset = 0.5;
            	float accum = 1.0;
            	float stepSize = maxdist / (float)_MaxSteps;
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float mu = dot(lightDir, dir);
                float phaseFunction = numericalMieFit(mu);
                dir = normalize(dir);
                int hitYet = 0;

                float T = 1;
                float3 hitNormal;
                pos += dir * hash(dot(pos, float3(12.256, 2.646, 6.356)) + _Time.y) / 100;
                [loop]
            	for (int i = 0; i < _MaxSteps; i++) {
                    float dist = scene(pos + uvwOffset, hitNormal);
            		float dens = saturate(-dist) * density * 1;
                    if (dist <= 0.0 && hitYet == 0) {
                        hitYet = 1;
                        float diffuse = saturate(dot(lightDir, hitNormal)) * 0.3 + 0.7;
                        col = _BaseColor.rgb;
                    }

            		accum *= exp(-dens * stepSize);
                    if(accum < 0.01)
                        break;
            		pos += dir * stepSize;
            	}

            	return 1 - accum;
            }


            fixed4 frag (v2f i) : SV_Target
            {
            	float3 camPosWS = _WorldSpaceCameraPos;
            	float3 fragPosWS = i.wpos;//mul(unity_ObjectToWorld, i.pos).xyz;


                float4x4 m = unity_ObjectToWorld;
                float3 objectPos = float3(m._14, m._24, m._34) - _PositionTweak;
                float objScale = objScale;//m._11; //temp version
                
                float3 dir = normalize(fragPosWS - camPosWS);  // continue in the direction of the ray from cam to hit pos
                float tmin, tmax;
                bool visible = intersectSphere(camPosWS, dir, objectPos, objScale / 2.0, tmin, tmax);

                //return visible;
                float3 pos = /*camPosWS + dir * tmin - objectPos;*/fragPosWS - objectPos;  // start raymarching at the initial hit position
                pos /= max(1e-3,_Scale);
                

                fixed4 col;

                float density = _Density;// * (1 - (fragPosWS.y - objectPos.y + objScale/2.0)/objScale);
            	float d = saturate(raytraceDensity(pos, dir, _MaxDistance, density, float4(objectPos, objScale), col.rgb));

                d = sqrt(d);
            	col = fixed4(col.rgb , d);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }


            ENDCG
        }

        Pass
        {
            Tags {"LightMode" = "ShadowCaster" }
            ZWrite On
            ColorMask 0         
        }

        
    }

    //Fallback "VertexLit"
}
