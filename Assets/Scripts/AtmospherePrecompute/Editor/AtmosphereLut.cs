using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

[CreateAssetMenu(fileName = "Atmosphere", menuName = "AtmosphereGenerator")]
public class AtmosphereLut : ScriptableObject {
    public ComputeShader compute;

    public int resolution;
    public string fileName = "lut_Tex";
    public enum bakeType
    {
        sun, sky
    }
    public bakeType btype;

    public void Bake()
    {
        resolution = Mathf.NextPowerOfTwo(resolution);

        Texture2D lut = new Texture2D(resolution, resolution, TextureFormat.RGBA32, false);

        Color[] pixelArray = lut.GetPixels(0);
        ComputeBuffer pixelBuffer = new ComputeBuffer(pixelArray.Length, sizeof(float) * 4);
        pixelBuffer.SetData(pixelArray);
        int kernel = -1;
        if(btype == bakeType.sky)
            kernel = compute.FindKernel("CSMain_sky");
        else
            kernel = compute.FindKernel("CSMain_sun");
        var skybox = RenderSettings.skybox;

        compute.SetBuffer(kernel, "pixelBuffer", pixelBuffer);
        compute.SetFloat("_Exposure", skybox.GetFloat("_Exposure"));
        compute.SetFloat("_SunSize", skybox.GetFloat("_SunSize"));
        compute.SetFloat("_SunSizeConvergence", skybox.GetFloat("_SunSizeConvergence"));
        compute.SetFloat("_AtmosphereThickness", skybox.GetFloat("_AtmosphereThickness"));
        compute.SetVector("_SkyTint", skybox.GetColor("_SkyTint"));
        compute.SetVector("_GroundColor", skybox.GetColor("_GroundColor"));
        compute.SetVector("_LightColor0", Color.white);
        compute.SetInt("textureSize", resolution);


        compute.Dispatch(kernel, pixelArray.Length / 256, 1, 1);

        pixelBuffer.GetData(pixelArray);
        pixelBuffer.Release();

        lut.SetPixels(pixelArray, 0);
        lut.Apply();

        //DestroyImmediate(compute);
        AssetDatabase.CreateAsset(lut, Path.GetDirectoryName(AssetDatabase.GetAssetPath(this)) + "/" + fileName + ".asset");
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        
        //Debug.Log(skybox.GetColor("_SkyTint"));
    }
}
