using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class SunFlareCtrl : MonoBehaviour {

    [SerializeField]
    Light sunLight;
    FlareLayer flare;

	// Use this for initialization
	void Start () {
        flare = GetComponent<FlareLayer>();
	}
	
	// Update is called once per frame
	void Update () {
        Vector3 look = sunLight.transform.forward;
        flare.enabled = look.y < -0.3f;
	}
}
