using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SunColor_Test : MonoBehaviour {

    public Transform mainLight;
    [Range(0, 180)]
    public float angle = 0;

    public Material mat;
    public float thickness = 1f;
    public float density = 1f;

    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        mainLight.rotation = Quaternion.Euler(Vector3.right * angle);

        mat.SetFloat("_CloudThickness", thickness);
        mat.SetFloat("sun_density", density);
        Graphics.Blit(src, dst, mat);
    }
}
