using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class OceanImageEffect : MonoBehaviour {

    public Material mat;
    public ProjectedOceanGrid ocean;

    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if(mat == null)
        {
            Graphics.Blit(src, dst);
        }
        else
        {
            mat.SetMatrix("_Interpolation", ocean.Interpolation);
            mat.SetFloat("_ZTime", Time.time);
            ocean.SetTime(Time.time);
            Graphics.Blit(src, dst, mat, 0);
        }
    }
}
