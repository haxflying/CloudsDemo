using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class UBW_KingsTreasure : MonoBehaviour {

    public List<GameObject> swords = new List<GameObject>();
    public List<Transform> children = new List<Transform>();
    public Vector3 size;
    public AnimationCurve horizontal;
    public AnimationCurve vertical;

    public float gridSize = 1;
    public float activeTimeDuration = 5f;

    [Range(0f, 1f)]
    public float process = 0f;
    private float m_process = 0.5f;

    public float delayGap = 20;

    private void Update()
    {
        if(m_process != process)
        {
            m_process = process;
            SetProcess(m_process);
        }
    }

    private void OnEnable()
    {
        StopCoroutine(ActiveAnime0());
        StopCoroutine(ActiveAnime1());
        StopCoroutine(ActiveAnime2());
        Hide();
    }

    private void SetProcess(float p)
    {
        for (int i = 0; i < children.Count; i++)
        {
            var s = children[i];
            var pos = s.GetChild(0).localPosition;
            s.GetChild(0).localPosition = new Vector3(pos.x, pos.y, Mathf.Lerp(-1f, 1f, p));
        }
    }

    public void Init()
    {
        float x = Mathf.Floor(size.x / gridSize);
        float y = Mathf.Floor(size.y / gridSize);
        int count = swords.Count;
        for (int i = 0; i < x; i++)
        {
            for (int j = 0; j < y; j++)
            {
                float xx = i / x;
                float yy = j / y;
                float px = horizontal.Evaluate(xx);
                float py = vertical.Evaluate(yy);
                float probability = px * py;

                if (Random.Range(0f, 1f) < probability)
                {
                    Vector3 random = Random.insideUnitSphere * gridSize * 0.5f;
                    Vector3 pos = new Vector3(i * gridSize, j * gridSize, 0) + random;
                    int index = Random.Range(0, count - 1);
                    var s = Instantiate(swords[index], transform.position + pos, transform.rotation, transform);
                    s.name = x + "_" + y;
                    children.Add(s.transform);
                }
            }
        }
    }

    public void Clear()
    {
        children.Clear();
        List<GameObject> list = new List<GameObject>();

        for (int i = 0; i < transform.childCount; i++)
        {
            list.Add(transform.GetChild(i).gameObject);
        }

        foreach (var g in list)
        {
            DestroyImmediate(g);
        }
    }

    public void Hide()
    {
        foreach(var s in children)
        {
            s.gameObject.SetActive(false);
        }
    }

    public void Active()
    {
        foreach (var s in children)
        {
            s.gameObject.SetActive(true);
        }
    }

    public void ActiveAnim()
    {
        StartCoroutine(ActiveAnime0());
        //StartCoroutine(ActiveAnime1());
        StartCoroutine(ActiveAnime2());
    }

    IEnumerator ActiveAnime0()
    {
        int count = 0;
        foreach (var s in children)
        {
            if (Random.Range(0f, 1f) < 0.3f && s.gameObject.activeInHierarchy == false)
            {
                s.gameObject.SetActive(true);
                if (count++ > delayGap)
                {
                    count = 0;
                    yield return new WaitForEndOfFrame();
                }
            }
        }

        yield return null;
    }

    IEnumerator ActiveAnime1()
    {
        int count = 0;
        yield return new WaitForSeconds(0.2f);
        foreach (var s in children)
        {
            if (Random.Range(0f, 1f) > 0.7f && s.gameObject.activeInHierarchy == false)
            {
                s.gameObject.SetActive(true);
                if (count++ > delayGap)
                {
                    count = 0;
                    yield return new WaitForEndOfFrame();
                }
            }
        }

        yield return null;
    }

    IEnumerator ActiveAnime2()
    {
        int count = 0;
        yield return new WaitForEndOfFrame();
        foreach (var s in children)
        {
            if (s.gameObject.activeInHierarchy == false)
            {
                s.gameObject.SetActive(true);
                if (count++ > delayGap)
                {
                    count = 0;
                    yield return new WaitForEndOfFrame();
                }
            }
        }  

        yield return null;
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.yellow;
        //size *= transform.lossyScale.x;
        Gizmos.DrawWireCube(transform.position + size / 2f, size);
    }
}
