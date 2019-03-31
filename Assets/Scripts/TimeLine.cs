using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;
public class TimeLine : MonoBehaviour {

    public float timeScale = 0.3f;

    private void Start()
    {
        Time.timeScale = timeScale;
    }


}
