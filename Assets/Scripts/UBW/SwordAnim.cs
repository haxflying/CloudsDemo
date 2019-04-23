using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SwordAnim : MonoBehaviour {

    public List<GameObject> normalSwords = new List<GameObject>();
    public List<GameObject> finalSword = new List<GameObject>();

    public Vector2 size;
    public Vector3 rotationRange;
    public int num;
    public float height;

    public float speedDiff = 10f;
    public AnimationCurve curve;
    [Range(0f, 1f)]
    public float process = 0f;
    private float m_process = 0f;

    public SwordAnimData data;

    public void Init()
    {
        Bounds bd = new Bounds(new Vector3(0, 0, size.y / 2), new Vector3(size.x, 1, size.y));
        float padding = 0f;
        int count = normalSwords.Count;
        for (int i = 0; i < num; i++)
        {
            int index = Random.Range(0, count - 1);
            var sword = normalSwords[index];
            Vector3 pos = new Vector3(Random.Range(bd.center.x - bd.size.x / 2f + padding, bd.center.x + bd.size.x / 2f - padding), 0,
                Random.Range(bd.center.z - bd.size.z / 2f + padding, bd.center.z + bd.size.z / 2f - padding));
            pos = transform.localToWorldMatrix.MultiplyPoint(pos);
            float height = Terrain.activeTerrain.SampleHeight(pos);
            pos.y = height;
            pos.y += 1f;
            Quaternion rotation = Quaternion.Euler(new Vector3(Random.Range(-rotationRange.x, rotationRange.x), Random.Range(-rotationRange.y, rotationRange.y), Random.Range(-rotationRange.z, rotationRange.z)));
            var s = Instantiate(sword, pos, rotation, transform);
        }

        foreach(var s in finalSword)
        {
            Quaternion rotation = Quaternion.Euler(new Vector3(Random.Range(-rotationRange.x, rotationRange.x), Random.Range(-rotationRange.y, rotationRange.y), Random.Range(-rotationRange.z, rotationRange.z)));
            Vector3 pos = transform.position + Random.insideUnitSphere * 0.3f;
            float height = Terrain.activeTerrain.SampleHeight(pos);
            pos.y = height + 0.3f;
            Instantiate(s, pos, rotation, transform);
        }
    }

    public void Clear()
    {
        List<GameObject> list = new List<GameObject>();

        for (int i = 0; i < transform.childCount; i++)
        {
            list.Add(transform.GetChild(i).gameObject);
            
        }

        foreach(var g in list)
        {
            DestroyImmediate(g);
        }
    }

    

    public void SetHeight()
    {
        data.targets.Clear();
        data.originals.Clear();
        for (int i = 0; i < transform.childCount; i++)
        {
            var s = transform.GetChild(i);
            Vector3 targetPos = s.position + s.up * (height / Vector3.Dot(s.up, Vector3.up));
            data.targets.Add(targetPos);
            data.originals.Add(s.position);
            s.position = targetPos;
        }
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.cyan;
        Gizmos.matrix = transform.localToWorldMatrix;
        Gizmos.DrawWireCube(Vector3.forward * size.y / 2f, new Vector3(size.x, 1f,  size.y));
    }


    private void Update()
    {
        if(m_process != process)
        {
            
            m_process = process;
            for (int i = 0; i < transform.childCount; i++)
            {
                var s = transform.GetChild(i);
                float dist = Mathf.Min(1f,  (data.originals[i] - transform.position).magnitude / size.magnitude);
                //m_process = Mathf.Lerp(m_process, process, dist / speedDiff);
                //dist = Mathf.Pow(dist, speedDiff);
                //print(dist);
                float value = curve.Evaluate(m_process);
                s.position = Vector3.Lerp(data.targets[i], data.originals[i], value + dist * speedDiff);
            }
        }
    }
}
