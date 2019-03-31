using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class CloudTAA : MonoBehaviour {

    public Material mat;
    [Range(1f, 4f)]
    public float downSample = 1f;

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

    private CommandBuffer cb;
    private Camera cam;
    private int currentCamera;
    private int currentFrame;
    private int prev_frame;

    private void OnEnable()
    {
        //prev_frame = new RenderTexture(Screen.width, Screen.height, 0);
        //buffer = new RenderTexture(Screen.width, Screen.height, 0);

        cam = GetComponent<Camera>();

        cb = new CommandBuffer();
        cb.name = "MzCloud!!!";

        cam.AddCommandBuffer(CameraEvent.BeforeForwardAlpha, cb);

        int width = (int)((float)Screen.width / downSample);
        int height = (int)((float)Screen.width / downSample);
        currentCamera   = Shader.PropertyToID("_CameraRender");
        currentFrame    = Shader.PropertyToID("_currentFrame");
        prev_frame      = Shader.PropertyToID("_prev_frame");
        cb.GetTemporaryRT(currentCamera, width, height);
        cb.GetTemporaryRT(currentFrame , width, height);
        cb.GetTemporaryRT(prev_frame   , width, height);

        cb.Blit(BuiltinRenderTextureType.CurrentActive, currentCamera);

        cb.SetRenderTarget(currentFrame);
        cb.DrawMesh(quad, Matrix4x4.identity, mat, 0, 0);

        cb.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
        cb.DrawMesh(quad, Matrix4x4.identity, mat, 0, 1);

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
        mat.SetFloat("_LayerBlend", blendFactor);
        mat.SetFloat("_Coverage", coverage);
        mat.SetFloat("_TextureDensity", textureDensity);
    }


    //[ImageEffectOpaque]
    //private void OnRenderImage(RenderTexture src, RenderTexture dst)
    //{
    //    if (mat != null)
    //    {
    //        mat.SetTexture("_prev_frame", prev_frame);
    //        Graphics.Blit(src, buffer, mat, 0);
    //        Graphics.Blit(buffer, dst, mat, 1);
    //        Graphics.Blit(dst, prev_frame);
    //    }
    //    else
    //    {
    //        Graphics.Blit(src, dst);
    //    }
    //}
}
