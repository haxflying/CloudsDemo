using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class CloudTAA : MonoBehaviour {

    public Material cloudsMat, blurMat, lightMat;
    public bool renderClouds = true;
    public bool useBlur;
    [Range(30, 150)]
    public int cloudIteration = 90;
    [Range(1f, 100f)]
    public float bilateralBlurDiffScale = 20;
    [Range(1f, 4f)]
    public float downSample = 2f;



    public bool enableTimeLine = true;

    [Header("Material Property")]
    [Range(0f, 1f)]
    public float coverage = 1;
    [Range(0f, 1f)]
    public float blendFactor = 1f;
    [Range(0f, 1f)]
    public float textureDensity = 1;

    static Mesh s_Quad;
    public static Mesh quad
    {
        get
        {
            if (s_Quad != null)
                return s_Quad;

            var vertices = new[]
            {
                new Vector3(-0.5f, -0.5f, 0f),
                new Vector3(0.5f,  0.5f, 0f),
                new Vector3(0.5f, -0.5f, 0f),
                new Vector3(-0.5f,  0.5f, 0f)
            };

            var uvs = new[]
            {
                new Vector2(0f, 0f),
                new Vector2(1f, 1f),
                new Vector2(1f, 0f),
                new Vector2(0f, 1f)
            };

            var indices = new[] { 0, 1, 2, 1, 0, 3 };

            s_Quad = new Mesh
            {
                vertices = vertices,
                uv = uvs,
                triangles = indices
            };
            s_Quad.RecalculateNormals();
            s_Quad.RecalculateBounds();

            return s_Quad;
        }
    } 
    //private RenderTexture prev_frame, buffer;

    public enum debugMode
    {
        cloudsPass, TAAPass, BlurPass, CombinePass, None
    }

    private CommandBuffer cb;
    private Camera cam;
    private int currentCamera;
    private int currentFrame;
    private int prev_frame;
    private int cloudsFrame;
    private int blurRes;

    private void OnEnable()
    {
        //prev_frame = new RenderTexture(Screen.width, Screen.height, 0);
        //buffer = new RenderTexture(Screen.width, Screen.height, 0);

        cam = GetComponent<Camera>();

        cb = new CommandBuffer();
        cb.name = "MzCloud!!!";

        cam.AddCommandBuffer(CameraEvent.BeforeForwardAlpha, cb);

       
    }

    private void OnPreRender()
    {
        if (cb == null)
            return;

        cb.Clear();

        if (!renderClouds)
            return;

        int width = (int)((float)Screen.width / downSample);
        int height = (int)((float)Screen.height / downSample);

        currentCamera = Shader.PropertyToID("_CameraRender");
        currentFrame = Shader.PropertyToID("_currentFrame");
        prev_frame = Shader.PropertyToID("_prev_frame");
        cloudsFrame = Shader.PropertyToID("_clouds_frame");
        blurRes = Shader.PropertyToID("_QuarterResColor");


        cb.GetTemporaryRT(currentFrame, width, height);
        cb.GetTemporaryRT(blurRes, width, height);

        cb.GetTemporaryRT(cloudsFrame, Screen.width, Screen.height);
        cb.GetTemporaryRT(currentCamera, Screen.width, Screen.height);
        cb.GetTemporaryRT(prev_frame, Screen.width, Screen.height);


        cb.Blit(BuiltinRenderTextureType.CurrentActive, currentCamera);

        cb.SetRenderTarget(currentFrame);
        cb.DrawMesh(quad, Matrix4x4.identity, cloudsMat, 0, 0); //draw clouds
        //cb.Blit(null, currentFrame, cloudsMat, 0);

        
        if (useBlur)
        {
            cb.SetGlobalInt("_cloudIteration", cloudIteration);
            cb.SetGlobalFloat("_BilateralBlurDiffScale", bilateralBlurDiffScale);

            cb.SetRenderTarget(blurRes);
            cb.DrawMesh(quad, Matrix4x4.identity, cloudsMat, 0, 1); //TAA

            {
                int temp_buffer = Shader.PropertyToID("temp_buffer");
                cb.GetTemporaryRT(temp_buffer, width, height);

                cb.Blit(blurRes, temp_buffer, blurMat, 8);
                cb.Blit(temp_buffer, blurRes, blurMat, 9);

                cb.Blit(blurRes, cloudsFrame, blurMat, 7);
                cb.ReleaseTemporaryRT(temp_buffer);
            }
        }
        else
        {
            cb.SetRenderTarget(cloudsFrame);
            cb.DrawMesh(quad, Matrix4x4.identity, cloudsMat, 0, 1); //TAA     
        }

        //combine
        cb.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
        cb.DrawMesh(quad, Matrix4x4.identity, cloudsMat, 0, 2);

        cb.Blit(BuiltinRenderTextureType.CurrentActive, prev_frame);
        cb.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
    }

    private void OnDisable()
    {
        //prev_frame.Release();
        //buffer.Release();

        cb.ReleaseTemporaryRT(currentCamera);
        cb.ReleaseTemporaryRT(currentFrame);
        cb.ReleaseTemporaryRT(prev_frame);
        cb.Release();
    }

    private void Update()
    {
        if (enableTimeLine)
        {
            cloudsMat.SetFloat("_LayerBlend", blendFactor);
            cloudsMat.SetFloat("_Coverage", coverage);
            cloudsMat.SetFloat("_TextureDensity", textureDensity);
        }

        {
            //lightMat.SetTexture("_LayerTex", cloudsMat.GetTexture("_LayerTex"));
            //lightMat.SetTexture("_LayerTex1", cloudsMat.GetTexture("_LayerTex1"));
            //lightMat.SetTexture("_NoiseVolume", cloudsMat.GetTexture("_NoiseVolume"));
            //lightMat.SetFloat("_LayerBlend", cloudsMat.GetFloat("_LayerBlend"));
            //lightMat.SetFloat("_CloudThickness", cloudsMat.GetFloat("_CloudThickness"));
            //lightMat.SetFloat("_Coverage", cloudsMat.GetFloat("_Coverage"));
            //lightMat.SetFloat("_Speed", cloudsMat.GetFloat("_Speed"));
            //lightMat.SetFloat("_TextureDensity", cloudsMat.GetFloat("_TextureDensity"));
            //lightMat.SetVector("_Detail0", cloudsMat.GetVector("_Detail0"));
            //lightMat.SetVector("_Detail1", cloudsMat.GetVector("_Detail1"));

        }
    }
}
