using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VL_Test : MonoBehaviour {

    public Material mat;

    [Range(0, 10f)]
    public float sun_density = 1f;
    [Range(0, 5f)]
    public float light_density = 2f;
    public bool debugVlight = false;

    [Range(1f, 4f)]
    public float downSample = 2f;

    [Range(0, 0.99f)]
    public float MieG = 0.6f;

    private void Start()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if(mat != null)
        {
            float thickness = RenderSettings.skybox.GetFloat("_AtmosphereThickness");
            mat.SetVector("_MieG", new Vector4(1 - (MieG * MieG), 1 + (MieG * MieG), 2 * MieG, 1.0f / (4.0f * Mathf.PI)));
            mat.SetFloat("sun_density", sun_density);
            mat.SetFloat("_AtmosphereThickness", thickness);
            mat.SetFloat("light_density", light_density);

            int width = Mathf.FloorToInt((Screen.width / downSample));
            int height = Mathf.FloorToInt((Screen.height / downSample));
            RenderTexture down_buffer = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBHalf);

            if (debugVlight)
            {
                Graphics.Blit(src, dst, mat, 0);
            }
            else
            {
                Graphics.Blit(src, down_buffer, mat, 0);
                mat.SetTexture("vlight_Tex", down_buffer);
                Graphics.Blit(src, dst, mat, 1);
            }

            RenderTexture.ReleaseTemporary(down_buffer);
        }
        else
        {
            Graphics.Blit(src, dst);
        }
    }
}
