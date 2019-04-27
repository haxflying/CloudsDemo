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


    [Header("Light")]
    [Range(0f, 0.99f)]
    public FloatParameter MieG = new FloatParameter { value = 0.6f };
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

    [Header("Alpha Mask")]
    public BoolParameter exportAlpha = new BoolParameter { value = true };
    [Range(1f, 4f)]
    public FloatParameter alphaDownScale = new FloatParameter { value = 2f };
    [Range(0, 4)]
    public IntParameter alphaBlurIteration = new IntParameter { value = 3 };
    [Range(0.2f, 3.0f)]
    public FloatParameter alphaBlurSpread = new FloatParameter { value = 0.6f };
    public BoolParameter useTAA = new BoolParameter { value = true };
}

public class VolumetricCloudEffectRender : PostProcessEffectRenderer<VolumetricCloudEffect>
{
    private int currentCamera;
    private int currentFrame;
    private int prev_frame;
    private int cloudsFrame;
    private int blurRes;
    private int temp_buffer;
    private int alpha_mask;
    private int alpha_buffer0;
    private int alpha_buffer1;
    private int prev_alpha_mask;

    private Shader cloudsShader, b_blurShader, g_blurShader;

    public override void Init()
    {
        base.Init();
        currentCamera = Shader.PropertyToID("_CameraRender");
        currentFrame = Shader.PropertyToID("_currentFrame");
        prev_frame = Shader.PropertyToID("_prev_frame");
        cloudsFrame = Shader.PropertyToID("_clouds_frame");
        blurRes = Shader.PropertyToID("_QuarterResColor");
        temp_buffer = Shader.PropertyToID("temp_buffer");
        alpha_mask = Shader.PropertyToID("alpha_mask");
        alpha_buffer0 = Shader.PropertyToID("alpha_buffer0");
        alpha_buffer1 = Shader.PropertyToID("alpha_buffer1");
        prev_alpha_mask = Shader.PropertyToID("prev_alpha_mask");

        cloudsShader = Shader.Find("Hidden/VolumetricClouds");
        b_blurShader = Shader.Find("Hidden/BilateralBlur");
        g_blurShader = Shader.Find("Hidden/GaussianBlur");
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
        context.command.GetTemporaryRT(alpha_mask, context.camera.pixelWidth, context.camera.pixelHeight, 0, FilterMode.Bilinear, RenderTextureFormat.RG16);

        /***********common properties**************/
        context.command.SetGlobalTexture("_LayerTex", settings.layerTex0.value);
        context.command.SetGlobalTexture("_LayerTex1", settings.layerTex1.value);
        context.command.SetGlobalTexture("_NoiseVolume", settings.noiseVolume.value);

        context.command.SetGlobalFloat("_LayerBlend", settings.blendFactor);
        context.command.SetGlobalFloat("_Coverage", settings.coverage);
        context.command.SetGlobalFloat("_TextureDensity", settings.textureDensity);
        context.command.SetGlobalFloat("_Speed", settings.speed); 
        context.command.SetGlobalFloat("_CloudThickness", settings.cloudThickness);
        context.command.SetGlobalFloat("_CloudStartHeight", settings.cloudStartHeight);
        context.command.SetGlobalVector("_Detail0", settings.detail0);
        context.command.SetGlobalVector("_Detail1", settings.detail1);
        /***********common properties**************/      

        var cloudsSheet = context.propertySheets.Get(cloudsShader);
        var b_blurSheet = context.propertySheets.Get(b_blurShader);
        var g_blurSheet = context.propertySheets.Get(g_blurShader);

        b_blurSheet.properties.SetFloat("_BilateralBlurDiffScale", settings.bilateralBlurDiffScale);

        float MieG = settings.MieG;
        cloudsSheet.properties.SetVector("_MieG", new Vector4(1 - (MieG * MieG), 1 + (MieG * MieG), 2 * MieG, 1.0f / (4.0f * Mathf.PI)));
        cloudsSheet.properties.SetInt("_cloudIteration", settings.cloudIteration);
        cloudsSheet.properties.SetFloat("_cloudIteration", settings.cloudIteration);
        cloudsSheet.properties.SetFloat("_AtmosphereThickness", settings.atmosphereThickness);
        cloudsSheet.properties.SetFloat("_AborbAmount", settings.Absorption);
        cloudsSheet.properties.SetFloat("sun_density", settings.sun_density);
        cloudsSheet.properties.SetColor("_AmbientColor", settings.AmbientColor);


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

                context.command.BlitFullscreenTriangle(blurRes, currentFrame, b_blurSheet, 13);
                context.command.BlitFullscreenTriangle(currentFrame, blurRes, b_blurSheet, 14); //Blur

                context.command.Blit(blurRes, cloudsFrame); //upsample
            }
            else
            {
                context.command.BlitFullscreenTriangle(context.source, cloudsFrame, cloudsSheet, 1); //TAA
            }

            if (settings.exportAlpha)
            {
                width = (int)((float)context.camera.pixelWidth / settings.alphaDownScale);
                height = (int)((float)context.camera.pixelHeight / settings.alphaDownScale);
                context.command.GetTemporaryRT(alpha_buffer0, width, height);
                context.command.GetTemporaryRT(alpha_buffer1, width, height);

                if (settings.useTAA)
                {
                    context.command.BlitFullscreenTriangle(cloudsFrame, alpha_buffer1, cloudsSheet, 3); //get alpha
                    context.command.BlitFullscreenTriangle(alpha_buffer1, alpha_buffer0, cloudsSheet, 4); //taa
                }
                else
                {
                    context.command.BlitFullscreenTriangle(cloudsFrame, alpha_buffer0, cloudsSheet, 3); //get alpha
                }
                for (int i = 0; i < settings.alphaBlurIteration; i++)
                {                 
                    g_blurSheet.properties.SetFloat("_BlurSize", settings.alphaBlurSpread * i + 1f);

                    context.command.BlitFullscreenTriangle(alpha_buffer0, alpha_buffer1, g_blurSheet, 0);
                    context.command.BlitFullscreenTriangle(alpha_buffer1, alpha_buffer0, g_blurSheet, 1);
                }

                if (settings.useTAA)
                {
                    context.command.BlitFullscreenTriangle(alpha_buffer0, alpha_buffer1, cloudsSheet, 4); //taa
                    context.command.Blit(alpha_buffer1, alpha_mask);
                }
                else
                {
                    context.command.Blit(alpha_buffer0, alpha_mask);
                }
            }

            context.command.BlitFullscreenTriangle(context.source, context.destination, cloudsSheet, 2);//combine
        }
        context.command.Blit(BuiltinRenderTextureType.CurrentActive, prev_frame);
    }
}
