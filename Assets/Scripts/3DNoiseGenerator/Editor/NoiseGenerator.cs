using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using System.IO;

[CreateAssetMenu(fileName = "3DNoiseGenerator", menuName = "3D Noise")]
public class NoiseGenerator : ScriptableObject {
    public ComputeShader compute;
    public Texture2D baseNoiseTex;
    public int resolution = 128;
    public float scale = 10f;
    public string fileName = "Noise_Tex";
    private Texture3D noise;

    public void Bake()
    {
        if(compute == null)
        {
            Debug.LogError("compute shader is empty!");
            return;
        }

        resolution = Mathf.NextPowerOfTwo(resolution);

        noise = new Texture3D(resolution, resolution, resolution, TextureFormat.RGBA32, false);
        noise.name = "Noise3D";
        noise.anisoLevel = 1;
        noise.filterMode = FilterMode.Bilinear;
        noise.wrapMode = TextureWrapMode.Mirror;

        Color[] pixelArray = noise.GetPixels(0);
        ComputeBuffer pixelBuffer = new ComputeBuffer(pixelArray.Length, sizeof(float) * 4);
        pixelBuffer.SetData(pixelArray);

        //ComputeShader compute = (ComputeShader)Instantiate(Resources.Load("NoiseCompute"));
        int kernel = compute.FindKernel("CSMain");

        compute.SetBuffer(kernel, "pixelBuffer", pixelBuffer);
        compute.SetInt("pixelBufferSize", pixelArray.Length);
        compute.SetInt("textureSize", resolution);
        compute.SetFloat("scale", scale);
        compute.SetTexture(kernel, "_NoiseTex", baseNoiseTex);
        compute.SetVector("_NoiseTex_TexelSize", new Vector4(1f/ baseNoiseTex.width, 1f/ baseNoiseTex.height, 0, 0));

        compute.Dispatch(kernel, pixelArray.Length / 256, 1, 1);
        //compute.Dispatch(kernel, resolution, resolution, resolution);

        pixelBuffer.GetData(pixelArray);
        pixelBuffer.Release();
        noise.SetPixels(pixelArray, 0);
        noise.Apply();

        DestroyImmediate(compute);
        AssetDatabase.CreateAsset(noise, Path.GetDirectoryName(AssetDatabase.GetAssetPath(this)) + "/" + fileName + ".asset");
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
    }
}
