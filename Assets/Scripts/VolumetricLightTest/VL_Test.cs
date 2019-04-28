using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

public class VL_Test : MonoBehaviour {

    public Material vl_mat;

    [Range(0, 30f)]
    public float sun_density = 1f;
    [Range(0, 5f)]
    public float light_density = 2f;
    public bool debugVlight = false;

    [Range(1f, 4f)]
    public float downSample = 2f;

    [Range(0, 0.99f)]
    public float MieG = 0.6f;

    private void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if(vl_mat != null)
        {
            float thickness = RenderSettings.skybox.GetFloat("_AtmosphereThickness");
            vl_mat.SetVector("_MieG", new Vector4(1 - (MieG * MieG), 1 + (MieG * MieG), 2 * MieG, 1.0f / (4.0f * Mathf.PI)));
            vl_mat.SetFloat("sun_density", sun_density);
            vl_mat.SetFloat("_AtmosphereThickness", thickness);
            vl_mat.SetFloat("light_density", light_density);

            int width = Mathf.FloorToInt((Screen.width / downSample));
            int height = Mathf.FloorToInt((Screen.height / downSample));
            RenderTexture down_buffer = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBHalf);

            if (debugVlight)
            {
                Graphics.Blit(src, dst, vl_mat, 0);
            }
            else
            {
                Graphics.Blit(src, down_buffer, vl_mat, 0);
                vl_mat.SetTexture("vlight_Tex", down_buffer);
                Graphics.Blit(src, dst, vl_mat, 1);
            }

            RenderTexture.ReleaseTemporary(down_buffer);
        }
        else
        {
            Graphics.Blit(src, dst);
        }
    }
}
