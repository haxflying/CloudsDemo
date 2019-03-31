using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Clouds : MonoBehaviour {

    public float visiblity = 25f;
    public Vector3 size = new Vector3(50f, 20f, 50f);
    [Range(0f, 1f)]
    public float Absorption = .5f;
    public Color _AmbientColor = Color.white;
    [Range(0, .1f)]
    public float _jitter = 0.0045f;
    public float IterationStep = 500;
    public float OptimizationFactor = 0;
    public float _3DNoiseScale = 1;
    public Vector3 stretch = Vector3.zero;
    [Range(0, 20)]
    public float Vortex = 0;
    public enum VortexAxis
    {
        X = 0,
        Y = 1,
        Z = 2
    }
    public VortexAxis _VortexAxis = (VortexAxis)2;

    [Range(0, 360)]
    public float rotation = 0;
    [Range(0, 10)]
    public float RotationSpeed = 0;
    
    public Vector4 Speed = new Vector4(0, 0, 0, 0);
    public float _DetailRelativeSpeed = 10;
    public float _BaseRelativeSpeed = 1;
    public float Coverage = 1.5f;
    public int Octaves = 1;
    public float _NoiseDetailRange = .5f, _Curl = .5f;
    public float NoiseDensity = 1;
    public float BaseTiling = 8, DetailTiling = 1;
    public float _DetailMaskingThreshold = 18;

    public float DetailDistance = 500;
    public float FadeDistance = 5000;
    [Range(0f, 10)]
    public float NoiseIntensity = 0.3f;
    [Range(0f, 15f)]
    public float NoiseContrast = 12;

    private Vector3 currentSize;

    [SerializeField]
    Material cloudsMat;

    private BoxCollider boxCollider;
    private Mesh mesh;
    private MeshFilter filter;
    private bool m_isVisible;

    Camera cam;
    private void OnEnable()
    {
        cam = Camera.main;
        cam.depthTextureMode |= DepthTextureMode.Depth;

        boxCollider = GetComponent<BoxCollider>();
    }

    private void Update()
    {
        cloudsMat.SetVector("_BoxMin", size * -0.5f);
        cloudsMat.SetVector("_BoxMax", size * 0.5f);
        cloudsMat.SetFloat("_Visibility", visiblity);
        cloudsMat.SetInt("STEP_COUNT", (int)IterationStep);
        cloudsMat.SetFloat("_jitter", _jitter);
        cloudsMat.SetFloat("_RayStep", IterationStep * 0.001f);
        cloudsMat.SetFloat("_OptimizationFactor", OptimizationFactor);
        cloudsMat.SetVector("_VolumePosition", transform.position);
        cloudsMat.SetFloat("_3DNoiseScale", _3DNoiseScale * 0.001f);
        cloudsMat.SetVector("Stretch", stretch * 0.01f + Vector3.one);

        DetailDistance = Mathf.Max(1, DetailDistance);
        cloudsMat.SetFloat("DetailDistance", DetailDistance);
        FadeDistance = Mathf.Max(1, FadeDistance);
        cloudsMat.SetFloat("FadeDistance", FadeDistance);
        cloudsMat.SetFloat("gain", NoiseIntensity);

        if (Vortex > 0)
        {
            cloudsMat.SetFloat("_Vortex", Vortex);
            cloudsMat.SetFloat("_Rotation", Mathf.Deg2Rad * rotation);
            cloudsMat.SetFloat("_RotationSpeed", -RotationSpeed);
        }

        cloudsMat.SetVector("Speed", Speed * .1f);
        cloudsMat.SetFloat("Coverage", Coverage);
        cloudsMat.SetFloat("_DetailRelativeSpeed", _DetailRelativeSpeed);
        cloudsMat.SetFloat("_BaseRelativeSpeed", _BaseRelativeSpeed);
        cloudsMat.SetFloat("_NoiseDetailRange", _NoiseDetailRange);
        cloudsMat.SetFloat("_Curl", _Curl);
        cloudsMat.SetFloat("NoiseDensity", NoiseDensity);
        cloudsMat.SetFloat("BaseTiling", BaseTiling);
        cloudsMat.SetFloat("DetailTiling", DetailTiling);
        cloudsMat.SetFloat("threshold", NoiseContrast * 0.5f - 5);
        cloudsMat.SetFloat("_DetailMaskingThreshold", _DetailMaskingThreshold);
        cloudsMat.SetInt("Octaves", Octaves);

        cloudsMat.SetFloat("Absorption", Absorption);
        cloudsMat.SetColor("_AmbientColor", _AmbientColor);
        UpdateBoxMesh();

        if (Vortex > 0)
        {
            switch (_VortexAxis)
            {
                case VortexAxis.X:
                    cloudsMat.EnableKeyword("Twirl_X");
                    cloudsMat.DisableKeyword("Twirl_Y");
                    cloudsMat.DisableKeyword("Twirl_Z");
                    break;

                case VortexAxis.Y:
                    cloudsMat.DisableKeyword("Twirl_X");
                    cloudsMat.EnableKeyword("Twirl_Y");
                    cloudsMat.DisableKeyword("Twirl_Z");
                    break;

                case VortexAxis.Z:
                    cloudsMat.DisableKeyword("Twirl_X");
                    cloudsMat.DisableKeyword("Twirl_Y");
                    cloudsMat.EnableKeyword("Twirl_Z");
                    break;
            }
        }
        else
        {
            cloudsMat.DisableKeyword("Twirl_X");
            cloudsMat.DisableKeyword("Twirl_Y");
            cloudsMat.DisableKeyword("Twirl_Z");
        }
    }

    private void OnBecameVisible()
    {
        m_isVisible = true;
    }

    private void OnBecameInvisible()
    {
        m_isVisible = false;
    }

    private void OnWillRenderObject()
    {
        if(m_isVisible)
        {
           // print("ISVISILBLE");
            
        }
       
    }

    void ToggleKeyword()
    {

    }

    public void UpdateBoxMesh()
    {
        if(currentSize != size)
        {
            CreateBoxMesh(size);
        }
    }

    private void CreateBoxMesh(Vector3 scale)
    {
        //print("Update Box " + scale);
        size = scale;

        filter = gameObject.GetComponent<MeshFilter>();

        if (mesh == null)
        {
            mesh = new Mesh();
            mesh.name = gameObject.name;
            filter.sharedMesh = mesh;
        }
        mesh.Clear();



        float width = scale.y;
        float height = scale.z;
        float length = scale.x;

        #region Vertices
        Vector3 p0 = new Vector3(-length * .5f, -width * .5f, height * .5f);
        Vector3 p1 = new Vector3(length * .5f, -width * .5f, height * .5f);
        Vector3 p2 = new Vector3(length * .5f, -width * .5f, -height * .5f);
        Vector3 p3 = new Vector3(-length * .5f, -width * .5f, -height * .5f);

        Vector3 p4 = new Vector3(-length * .5f, width * .5f, height * .5f);
        Vector3 p5 = new Vector3(length * .5f, width * .5f, height * .5f);
        Vector3 p6 = new Vector3(length * .5f, width * .5f, -height * .5f);
        Vector3 p7 = new Vector3(-length * .5f, width * .5f, -height * .5f);

        Vector3[] vertices = new Vector3[]
                {
		// Bottom
				p0, p1, p2, p3,
				
		// Left
				p7, p4, p0, p3,
				
		// Front
				p4, p5, p1, p0,
				
		// Back
				p6, p7, p3, p2,
				
		// Right
				p5, p6, p2, p1,
				
		// Top
				p7, p6, p5, p4
                };
        #endregion

        #region Normales
        Vector3 up = Vector3.up;
        Vector3 down = Vector3.down;
        Vector3 front = Vector3.forward;
        Vector3 back = Vector3.back;
        Vector3 left = Vector3.left;
        Vector3 right = Vector3.right;

        Vector3[] normales = new Vector3[]
        {
	// Bottom
	down, down, down, down,
 
	// Left
	left, left, left, left,
 
	// Front
	front, front, front, front,
 
	// Back
	back, back, back, back,
 
	// Right
	right, right, right, right,
 
	// Top
	up, up, up, up
        };
        #endregion

        #region UVs
        Vector2 _00 = new Vector2(0f, 0f);
        Vector2 _10 = new Vector2(1f, 0f);
        Vector2 _01 = new Vector2(0f, 1f);
        Vector2 _11 = new Vector2(1f, 1f);

        Vector2[] uvs = new Vector2[]
        {
	// Bottom
	_11, _01, _00, _10,
 
	// Left
	_11, _01, _00, _10,
 
	// Front
	_11, _01, _00, _10,
 
	// Back
	_11, _01, _00, _10,
 
	// Right
	_11, _01, _00, _10,
 
	// Top
	_11, _01, _00, _10,
        };
        #endregion

        #region Triangles
        int[] triangles = new int[]
                {
		// Bottom
				3, 1, 0,
                                3, 2, 1,			
				
		// Left
				3 + 4 * 1, 1 + 4 * 1, 0 + 4 * 1,
                                3 + 4 * 1, 2 + 4 * 1, 1 + 4 * 1,
				
		// Front
				3 + 4 * 2, 1 + 4 * 2, 0 + 4 * 2,
                                3 + 4 * 2, 2 + 4 * 2, 1 + 4 * 2,
				
		// Back
				3 + 4 * 3, 1 + 4 * 3, 0 + 4 * 3,
                                3 + 4 * 3, 2 + 4 * 3, 1 + 4 * 3,
				
		// Right
				3 + 4 * 4, 1 + 4 * 4, 0 + 4 * 4,
                                3 + 4 * 4, 2 + 4 * 4, 1 + 4 * 4,
				
		// Top
				3 + 4 * 5, 1 + 4 * 5, 0 + 4 * 5,
                                3 + 4 * 5, 2 + 4 * 5, 1 + 4 * 5,

                };
        #endregion

        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.normals = normales;
        mesh.uv = uvs;
        mesh.RecalculateBounds();
    }
}
