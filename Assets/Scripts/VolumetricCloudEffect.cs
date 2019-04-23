using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(VolumetricCloudEffectRender), PostProcessEvent.BeforeTransparent, "Custom/Clouds")]
public class VolumetricCloudEffect : PostProcessEffectSettings
{
    public BoolParameter debugClouds = new BoolParameter { value = true };
    public BoolParameter useBlur = new BoolParameter { value = true };

    [Range(30, 150)]
    public IntParameter cloudIteration = new IntParameter { value = 90 };
    [Range(1f, 100f)]
    public FloatParameter bilateralBlurDiffScale = new FloatParameter { value = 20f };
    [Range(1f, 4f)]
    public FloatParameter downScale = new FloatParameter { value = 2f };


    [Header("Material Property")]
    [Header("Light")]
    public ColorParameter AmbientColor = new ColorParameter { value = Color.white };
    [Range(0f, 1f)]
    public FloatParameter Absorption = new FloatParameter { value = 0.6f };
    [Range(0.1f, 3f)]
    public FloatParameter atmosphereThickness = new FloatParameter { value = 1f };
    [Range(0f, 10f)]
    public FloatParameter sun_density = new FloatParameter { value = 5f };

    [Header("Shape")]
    [Range(0f, 1f)]
    public FloatParameter blendFactor = new FloatParameter { value = 1 };

    [Range(0f, 1f)]
    public FloatParameter coverage = new FloatParameter { value = 1 };
   
    [Range(0f, 1f)]
    public FloatParameter textureDensity = new FloatParameter { value = 1 };

    [Range(0f, 10f)]
    public FloatParameter speed = new FloatParameter { value = 1 };

    [Range(100f, 2000f)]
    public FloatParameter cloudStartHeight = new FloatParameter { value = 500f };

    [Range(300f, 3000f)]
    public FloatParameter cloudThickness = new FloatParameter { value = 1 };

    public Vector4Parameter detail0 = new Vector4Parameter { value = Vector4.one};
    public Vector4Parameter detail1 = new Vector4Parameter { value = Vector4.one};

    public TextureParameter layerTex0 = new TextureParameter { };
    public TextureParameter layerTex1 = new TextureParameter { };
    public TextureParameter noiseVolume = new TextureParameter { };
}

public class VolumetricCloudEffectRender : PostProcessEffectRenderer<VolumetricCloudEffect>
{
    private int currentCamera;
    private int currentFrame;
    private int prev_frame;
    private int cloudsFrame;
    private int blurRes;
    private int temp_buffer;

    private Shader cloudsShader, blurShader;

    public override void Init()
    {
        base.Init();
        currentCamera = Shader.PropertyToID("_CameraRender");
        currentFrame = Shader.PropertyToID("_currentFrame");
        prev_frame = Shader.PropertyToID("_prev_frame");
        cloudsFrame = Shader.PropertyToID("_clouds_frame");
        blurRes = Shader.PropertyToID("_QuarterResColor");
        temp_buffer = Shader.PropertyToID("temp_buffer");

        cloudsShader = Shader.Find("Hidden/VolumetricClouds");
        blurShader = Shader.Find("Hidden/BilateralBlur");
    }

    public override void Render(PostProcessRenderContext context)
    {
        int width = (int)((float)context.camera.pixelWidth / settings.downScale);
        int height = (int)((float)context.camera.pixelHeight / settings.downScale);

        context.command.GetTemporaryRT(currentFrame,    width, height);
        context.command.GetTemporaryRT(blurRes,         width, height);
        context.command.GetTemporaryRT(temp_buffer,     width, height);
        context.command.GetTemporaryRT(cloudsFrame,     context.camera.pixelWidth, context.camera.pixelHeight);
        context.command.GetTemporaryRT(currentCamera,   context.camera.pixelWidth, context.camera.pixelHeight);
        context.command.GetTemporaryRT(prev_frame,      context.camera.pixelWidth, context.camera.pixelHeight);

        /***********common properties**************/
        context.command.SetGlobalTexture("_LayerTex", settings.layerTex0.value);
        context.command.SetGlobalTexture("_LayerTex1", settings.layerTex1.value);
        context.command.SetGlobalTexture("_NoiseVolume", settings.noiseVolume.value);

        context.command.SetGlobalFloat("_LayerBlend", settings.blendFactor);
        context.command.SetGlobalFloat("_Coverage", settings.coverage);
        context.command.SetGlobalFloat("_TextureDensity", settings.textureDensity);
        context.command.SetGlobalFloat("_Speed", settings.speed);
        context.command.SetGlobalFloat("_CloudThickness", settings.cloudThickness);
        context.command.SetGlobalVector("_Detail0", settings.detail0);
        context.command.SetGlobalVector("_Detail1", settings.detail1);
        /***********common properties**************/

        context.command.SetGlobalFloat("_BilateralBlurDiffScale", settings.bilateralBlurDiffScale);      
        context.command.SetGlobalInt("_cloudIteration", settings.cloudIteration);

        var cloudsSheet = context.propertySheets.Get(cloudsShader);
        var blurSheet = context.propertySheets.Get(blurShader);

        cloudsSheet.properties.SetFloat("_cloudIteration", settings.cloudIteration);
        cloudsSheet.properties.SetFloat("_AtmosphereThickness", settings.atmosphereThickness);
        cloudsSheet.properties.SetFloat("_AborbAmount", settings.Absorption);
        cloudsSheet.properties.SetFloat("sun_density", settings.sun_density);
        cloudsSheet.properties.SetColor("_AmbientColor", settings.AmbientColor);

        //blurSheet.properties.set

        context.command.Blit(context.source, currentCamera);

        if (settings.debugClouds)
        {
            context.command.BlitFullscreenTriangle(context.source, context.destination, cloudsSheet, 0); //Clouds
        }
        else
        {
            context.command.BlitFullscreenTriangle(context.source, currentFrame, cloudsSheet, 0); //Clouds

            if (settings.useBlur)
            {
                context.command.BlitFullscreenTriangle(context.source, blurRes, cloudsSheet, 1); //TAA
                context.command.BlitFullscreenTriangle(blurRes, temp_buffer, blurSheet, 13);
                context.command.BlitFullscreenTriangle(temp_buffer, blurRes, blurSheet, 14); //Blur

                context.command.BlitFullscreenTriangle(blurRes, cloudsFrame, blurSheet, 12); //upsample
            }
            else
            {
                context.command.BlitFullscreenTriangle(context.source, cloudsFrame, cloudsSheet, 1); //TAA
            }

            context.command.BlitFullscreenTriangle(context.source, context.destination, cloudsSheet, 2);//combine
        }
        context.command.Blit(BuiltinRenderTextureType.CurrentActive, prev_frame);
    }
}
