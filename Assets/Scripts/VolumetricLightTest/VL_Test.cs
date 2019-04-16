using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VL_Test : MonoBehaviour {

    public Texture2D mask;
    public Material mat;

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
            mat.SetTexture("_MaskTex", mask);
            mat.SetVector("_MieG", new Vector4(1 - (MieG * MieG), 1 + (MieG * MieG), 2 * MieG, 1.0f / (4.0f * Mathf.PI)));
            Graphics.Blit(src, dst, mat, 0);
        }
        else
        {
            Graphics.Blit(src, dst);
        }
    }
}
