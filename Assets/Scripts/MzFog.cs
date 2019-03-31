using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class MzFog : MonoBehaviour {

    public Material mat;
    public Light SunLight;
    public Gradient ColorWithSun;
    public AnimationCurve skyFogDensityCurve;

    public Color fogColor;
    [Range(0f, 1f)]
    public float fogDensity;
    public bool distanceFog = true;
    public bool useRadialDistance = false;
    [Range(0, 1)]
    public float skyFogDensity = 0;


    [HideInInspector]
    public bool heightFog = true;
    [HideInInspector]
    public float height = 1.0f;
    [HideInInspector]
    public float heightDensity = 2.0f;
    [HideInInspector]
    public float startDistance = 0.0f;




    private void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    private void Update()
    {
        float factor = -SunLight.transform.forward.y;
        factor = factor * 0.5f + 0.5f;

        fogColor = ColorWithSun.Evaluate(factor);
        skyFogDensity = skyFogDensityCurve.Evaluate(factor);
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if(mat == null)
        {
            Graphics.Blit(src, dst);
        }
        else
        {
            var camPos = transform.position;
            float FdotC = camPos.y - height;
            float paramK = (FdotC <= 0.0f ? 1.0f : 0.0f);
            mat.SetVector("_HeightParams", new Vector4(height, FdotC, paramK, heightDensity * 0.5f));
            mat.SetVector("_DistanceParams", new Vector4(-Mathf.Max(startDistance, 0.0f), 0, 0, 0));
            mat.SetColor("_FogColor", fogColor);
            mat.SetFloat("_FogDensity", fogDensity);
            mat.SetFloat("_SkyFogFac", skyFogDensity);

            var sceneMode = RenderSettings.fogMode;
            var sceneDensity = RenderSettings.fogDensity;
            var sceneStart = RenderSettings.fogStartDistance;
            var sceneEnd = RenderSettings.fogEndDistance;
            Vector4 sceneParams;
            bool linear = (sceneMode == FogMode.Linear);
            float diff = linear ? sceneEnd - sceneStart : 0.0f;
            float invDiff = Mathf.Abs(diff) > 0.0001f ? 1.0f / diff : 0.0f;
            sceneParams.x = sceneDensity * 1.2011224087f; // density / sqrt(ln(2)), used by Exp2 fog mode
            sceneParams.y = sceneDensity * 1.4426950408f; // density / ln(2), used by Exp fog mode
            sceneParams.z = linear ? -invDiff : 0.0f;
            sceneParams.w = linear ? sceneEnd * invDiff : 0.0f;
            mat.SetVector("_SceneFogParams", sceneParams);
            mat.SetVector("_SceneFogMode", new Vector4((int)sceneMode, useRadialDistance ? 1 : 0, 0, 0));
            mat.SetMatrix("_WorldToCamera", transform.worldToLocalMatrix);

            int pass = 0;
            if (distanceFog && heightFog)
                pass = 0; // distance + height
            else if (distanceFog)
                pass = 1; // distance only
            else
                pass = 2; // height only
            Graphics.Blit(src, dst, mat, pass);
        }
    }
}
