using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class UBW_Sword : MonoBehaviour {

    public GameObject test;
    public List<GameObject> swords = new List<GameObject>();
    public Vector3 rotationRange;
    public int num = 1000;

    public void scatter()
    {
        Bounds bd = Terrain.activeTerrain.terrainData.bounds;
        Debug.Log(bd);

        GameObject scatterRoot = new GameObject("scatterRoot");

        float padding = 10f;
        float count_sword = swords.Count;
        for (int i = 0; i < num; i++)
        {
            int index_sword = Mathf.FloorToInt(Random.Range(0f, count_sword));
            
            Vector3 pos = new Vector3(Random.Range(bd.center.x - bd.size.x / 2f + padding, bd.center.x + bd.size.x / 2f - padding), 0,
                Random.Range(bd.center.z - bd.size.z / 2f + padding, bd.center.z + bd.size.z / 2f - padding));
            float height = Terrain.activeTerrain.SampleHeight(pos);
            pos.y = height;
            float sword_height = swords[index_sword].GetComponentInChildren<Renderer>().bounds.size.y;
            pos.y += 1f ;

            Quaternion rotation = Quaternion.Euler(new Vector3(Random.Range(-rotationRange.x, rotationRange.x), Random.Range(-rotationRange.y, rotationRange.y),  Random.Range(-rotationRange.z, rotationRange.z)));

            var sword = Instantiate(swords[index_sword], pos, rotation, scatterRoot.transform);
        }
        
    }
}
