using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class SpecialDepthObjects : MonoBehaviour {

    public Shader writeDepthShader;
    public bool debugView;
    public Shader depthViewerShader;

    private Camera cam;
    private CommandBuffer cb;
    private CommandBuffer cb_debug;

    private Material viewMat, depthWriterMat;
    private int specialDepth;

    void Start () {
        cam = Camera.main;

        cb = new CommandBuffer();
        cb.name = "Specual Depth Objects";

        cb_debug = new CommandBuffer();
        cb_debug.name = "Specual Depth Objects Debug";

        cam.AddCommandBuffer(CameraEvent.AfterForwardOpaque, cb);

        viewMat = new Material(depthViewerShader);
        cam.AddCommandBuffer(CameraEvent.AfterEverything, cb_debug);
       
        depthWriterMat = new Material(writeDepthShader);
        depthWriterMat.enableInstancing = true;
        specialDepth = Shader.PropertyToID("_SpecialDepth");
        

	}

    private void Update()
    {
        if(cb != null)
        {
            cb.Clear();
            cb.GetTemporaryRT(specialDepth, cam.pixelWidth, cam.pixelHeight, 32, FilterMode.Bilinear, RenderTextureFormat.Depth);
            cb.SetRenderTarget(specialDepth);
            cb.ClearRenderTarget(true, true, Color.black);

            for (int i = 0; i < transform.childCount; i++)
            {
                var c = transform.GetChild(i);
                var mesh = c.GetComponent<MeshFilter>().sharedMesh;
                cb.DrawMesh(mesh, c.localToWorldMatrix, depthWriterMat);
            }

            cb.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
        }

        if(cb_debug != null)
        {          
            cb_debug.Clear();
            if (debugView)
                cb_debug.Blit(null, BuiltinRenderTextureType.CameraTarget, viewMat);
        }
    }

}
