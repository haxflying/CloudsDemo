using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class UBW_Gears : MonoBehaviour {

    public int nums;
    public List<GameObject> gears = new List<GameObject>();
    public GameObject currentRoot;
    
    public Vector2 scaleRange;
    public Vector2 heightRange;

    public float rotateSpeed = 1f;

    public void Generate()
    {
        int count = gears.Count;
        Bounds bd = Terrain.activeTerrain.terrainData.bounds;
        float padding = 10f;

        if (currentRoot == null)
            currentRoot = new GameObject("GearsRoot");

        print("generate");
        for (int i = 0; i < nums; i++)
        {
            int index = Mathf.FloorToInt(Random.Range(0, count - 1));
            Vector3 pos = new Vector3(Random.Range(bd.center.x - bd.size.x / 2f + padding, bd.center.x + bd.size.x / 2f - padding), 0,
                Random.Range(bd.center.z - bd.size.z / 2f + padding, bd.center.z + bd.size.z / 2f - padding));

            Quaternion rotation = Quaternion.Euler(new Vector3(0, Random.Range(0f, 180f), 90f));
            var gear = Instantiate(gears[index], pos, rotation, currentRoot.transform);
        }
    }

    public void refresh()
    {
        if(currentRoot == null)
        {
            Debug.LogError("current root is nil");
            return;
        }

        for (int i = 0; i < currentRoot.transform.childCount; i++)
        {
            var gear = currentRoot.transform.GetChild(i);
            gear.localScale = Vector3.one * Random.Range(scaleRange.x, scaleRange.y);
            gear.localPosition += Vector3.up * Random.Range(heightRange.x, heightRange.y);
        }
    }

    public void Clear()
    {
        if (currentRoot == null)
        {
            Debug.LogError("current root is nil");
            return;
        }

        DestroyImmediate(currentRoot);
    }

    private void Update()
    {
        if (currentRoot == null)
        {
            Debug.LogError("current root is nil");
            return;
        }

        for (int i = 0; i < currentRoot.transform.childCount; i++)
        {
            if (Random.Range(0f, 1f) < 0.5f)
            {
                var gear = currentRoot.transform.GetChild(i);
                float value = (1 + Mathf.Cos(3f * Time.time)) * Time.deltaTime * rotateSpeed;
                gear.localRotation *= Quaternion.Euler(Vector3.up * value);
            }
        }
    }
}
