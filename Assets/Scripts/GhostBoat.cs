using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class GhostBoat : MonoBehaviour {
    public float density;
    private Camera cam;
    private CommandBuffer cb_depth;
    private Mesh mesh;
    public Material mat;

    //public ProjectedOceanGrid Ocean;
    //public Transform EffectOceanTrans;
    //public CustomRenderTexture crt;

    private void OnEnable()
    {
        cam = Camera.main;
        mesh = GetComponent<MeshFilter>().sharedMesh;
       
        cb_depth = new CommandBuffer();
        cb_depth.name = "GhostBoatDepth";

        cam.AddCommandBuffer(CameraEvent.AfterForwardAlpha, cb_depth);

        
    }


    private void Update()
    {
        mat.SetFloat("_Density", density);
        if (cb_depth != null)
        {
            cb_depth.Clear();
            cb_depth.DrawMesh(mesh, transform.localToWorldMatrix, mat, 0, 0);
            cb_depth.DrawMesh(mesh, transform.localToWorldMatrix, mat, 0, 1);
        }

        //Vector2 zoneCenter = Ocean.WorldToUV(EffectOceanTrans.position);

        //crt.ClearUpdateZones();
        //var zone = new CustomRenderTextureUpdateZone();
        //zone.needSwap = true;
        //zone.passIndex = 0;
        //zone.rotation = 0f;
        //zone.updateZoneCenter = zoneCenter;
        //zone.updateZoneSize = new Vector2(1f, 1f);
        //crt.SetUpdateZones(new CustomRenderTextureUpdateZone[] { zone });
        //crt.Update(5);
    }
}
