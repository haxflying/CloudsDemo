using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ImageEffectAllowedInSceneView]
public class DDX_Test : MonoBehaviour {

    public Shader ddx_image;
    private Material mat;

    private void Start()
    {
        mat = new Material(ddx_image);
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if(mat == null)
        {
            Graphics.Blit(src, dst);
        }
        else
        {
            Graphics.Blit(src, dst, mat);
        }
    }
}
