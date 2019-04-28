using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

[ExecuteInEditMode]
public class CloudsAnimation : MonoBehaviour {

    [Range(0f, 1f)]
    public float coverage = 1f;
    [Range(0f, 10f)]
    public float speed = 1f;
    [Range(100f, 2000f)]
    public float height = 1000f;

    [Range(0f, 3f)]
    public float skyBox_atmospereThickness = 2f;

    public Vector4 detail0, detail1;

    VolumetricCloudEffect cloudsEffect;
    PostProcessVolume volume;

    private void Start()
    {
        volume = GetComponent<PostProcessVolume>();
        volume.profile.TryGetSettings(out cloudsEffect);        
    }

    private void Update()
    {
        cloudsEffect.coverage.value = coverage;
        cloudsEffect.speed.value = speed;
        cloudsEffect.cloudStartHeight.value = height;
        cloudsEffect.detail0.value = detail0;
        cloudsEffect.detail1.value = detail1;

        Material skybox = RenderSettings.skybox;
        skybox.SetFloat("_AtmosphereThickness", skyBox_atmospereThickness);
    }
}
