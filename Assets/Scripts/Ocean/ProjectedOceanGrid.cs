using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class ProjectedOceanGrid : MonoBehaviour {

    public Material oceanMat;
    [Range(0f, 1f)]
    public float extra;
    private GameObject m_grid;
    private Projection m_projection;


    public Vector2 WorldToUV(Vector3 pos)
    {

        Matrix4x4 inte = m_projection.Interpolation;

        Vector2 uv = Vector2.zero;
        Vector4 vv0 = inte.GetRow(0);
        Vector4 vv1 = inte.GetRow(1);
        Vector4 vv2 = inte.GetRow(2);
        Vector4 vv3 = inte.GetRow(3);
        Vector3 v0 = vv0 / vv0.w;
        Vector3 v1 = vv1 / vv1.w;
        Vector3 v2 = vv2 / vv2.w;
        Vector3 v3 = vv3 / vv3.w;
        Debug.Log(v0 + " " + v1 + " " + v2 + " " + v3 + " " + pos);
        float t0 = (Mathf.Abs(Vector3.Dot(pos - v0, v1 - v0)) / (v1 - v0).magnitude);
        float t1 = (Mathf.Abs(Vector3.Dot(pos - v3, v2 - v3)) / (v2 - v3).magnitude);
        Debug.Log(t0 + " " +  t1);
        return uv;
    }

    public Matrix4x4 Interpolation
    {
        get
        {
            return m_projection.Interpolation;
        }
    }

    public void SetTime(float t)
    {
        oceanMat.SetFloat("_ZTime", t);
    }

    private void Start()
    {
        for (int i = 0; i < transform.childCount; i++)
        {
            DestroyImmediate(transform.GetChild(0).gameObject);
        }

        m_projection = new Projection();
        m_projection.OceanLevel = transform.position.y;
        m_projection.MaxHeight = 10.0f;

        CreateGrid(8);
    }

    private void Update()
    {

        Camera cam = Camera.main;
        if (cam == null || oceanMat == null || m_projection == null) return;

        m_projection.OceanLevel = transform.position.y;
        m_projection.MaxHeight = 10.0f;
        m_projection.extra = extra;

        m_projection.UpdateProjection(cam);

        oceanMat.SetMatrix("_Interpolation", m_projection.Interpolation);

        //Once the camera goes below the projection plane (the ocean level) the projected
        //grid will flip the triangle winding order. 
        //Need to flip culling so the top remains the top.
        //bool isFlipped = m_projection.IsFlipped;
        oceanMat.SetInt("_CullFace", (int)m_projection.IsFlipped);

    }


    void CreateGrid(int resolusion)
    {
        int width = Screen.width;
        int height = Screen.height;
        int numVertsX = width / resolusion;
        int numVertsY = height / resolusion;

        Mesh mesh = CreateQuad(numVertsX, numVertsY);

        if (mesh == null) return;

        float bigNumber = 1e6f;
        mesh.bounds = new Bounds(Vector3.zero, new Vector3(bigNumber, 20f, bigNumber));

        m_grid = new GameObject("OceanMesh");
        m_grid.transform.parent = transform;

        MeshFilter filter = m_grid.AddComponent<MeshFilter>();
        MeshRenderer renderer = m_grid.AddComponent<MeshRenderer>();

        filter.sharedMesh = mesh;
        renderer.shadowCastingMode = ShadowCastingMode.Off;
        renderer.receiveShadows = false;
        renderer.motionVectorGenerationMode = MotionVectorGenerationMode.ForceNoMotion;
        renderer.sharedMaterial = oceanMat;
    }

    public Mesh CreateQuad(int numVertsX, int numVertsY)
    {
        Vector3[] vertices = new Vector3[numVertsX * numVertsY];
        Vector2[] texcoords = new Vector2[numVertsX * numVertsY];
        int[] indices = new int[numVertsX * numVertsY * 6];

        if (vertices.Length > 65000)
        {
            return null;
        }

        for (int x = 0; x < numVertsX; x++)
        {

            for (int y = 1; y < numVertsY; y++)
            {
                int yy = y - 1;
                Vector2 uv = new Vector2(x / (numVertsX - 1f), yy / (numVertsY - 1f));
                texcoords[x + yy * numVertsX] = uv;
                vertices[x + yy * numVertsX] = new Vector3(uv.x, uv.y, 0f);
            }
        }

        int num = 0;
        for (int x = 0; x < numVertsX - 1; x++)
        {
            for (int y = 0; y < numVertsY - 1; y++)
            {
                indices[num++] = x + y * numVertsX;
                indices[num++] = x + (y + 1) * numVertsX;
                indices[num++] = x + 1 + y * numVertsX;

                indices[num++] = x + (y + 1) * numVertsX;
                indices[num++] = x + 1 + (y + 1) * numVertsX;
                indices[num++] = x + 1 + y * numVertsX;
            }
        }

        
        {
            Mesh mesh = new Mesh();
            mesh.vertices = vertices;
            mesh.uv = texcoords;
            mesh.triangles = indices;

            return mesh;
        }
    }
}
