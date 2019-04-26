using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(GodRaysRenderer), PostProcessEvent.BeforeStack, "Custom/GodRays")]
public class GodRays : PostProcessEffectSettings {

    public BoolParameter debugView = new BoolParameter { value = false };

    [Range(0f, 20f)]
    public FloatParameter sun_density = new FloatParameter { value = 8f };
    [Range(0f, 5f)]
    public FloatParameter light_density = new FloatParameter { value = 2f };
    [Range(1, 4)]
    public IntParameter downSample = new IntParameter { value = 4 };
    [Range(30, 150)]
    public IntParameter iteration = new IntParameter { value = 60 };
    [Min(300f)]
    public FloatParameter traceDistance = new FloatParameter { value = 1000f };

    [Header("Shading")]
    [Range(0f, 0.99f)]
    public FloatParameter MieG = new FloatParameter { value = 0.6f };
    [Range(0f, 1f)]
    public FloatParameter ScaterringCoef = new FloatParameter { value = 0.002f };
    [Range(0f, 1f)]
    public FloatParameter ExtinctionCoef = new FloatParameter { value = 0.003f };
    [Range(1f, 100f)]
    public FloatParameter bilateralBlurDiffScale = new FloatParameter { value = 100f };
    [Range(1, 10)]
    public IntParameter lightIteration = new IntParameter { value = 5 };
    [Range(5, 30)]
    public IntParameter shadowIteration = new IntParameter { value = 15 };   
}

public class GodRaysRenderer : PostProcessEffectRenderer<GodRays>
{
    private Shader gr_shader;
    private Shader blurShader;
    private int downSampleBuffer;
    private int prev_frame;
    private int taa_res;
    private int blur_res;
    private int temp_buffer;

    public override void Init()
    {
        base.Init();
        gr_shader = Shader.Find("Hidden/VolumetricGodRays");
        blurShader = Shader.Find("Hidden/BilateralBlur");

        downSampleBuffer = Shader.PropertyToID("vlight_Tex");
        prev_frame = Shader.PropertyToID("_prev_frame");
        taa_res = Shader.PropertyToID("vl_taa_res");
        blur_res = Shader.PropertyToID("_QuarterResColor");
        temp_buffer = Shader.PropertyToID("temp_buffer");
    }

    public override void Render(PostProcessRenderContext context)
    {
        PropertySheet vlSheet = context.propertySheets.Get(gr_shader);
        PropertySheet blurSheet = context.propertySheets.Get(blurShader);

        float MieG = settings.MieG;
        float thickness = RenderSettings.skybox.GetFloat("_AtmosphereThickness");

        vlSheet.properties.SetVector("_MieG", new Vector4(1 - (MieG * MieG), 1 + (MieG * MieG), 2 * MieG, 1.0f / (4.0f * Mathf.PI)));
        vlSheet.properties.SetFloat("sun_density", settings.sun_density);
        vlSheet.properties.SetFloat("light_density", settings.light_density);
        vlSheet.properties.SetFloat("_AtmosphereThickness", thickness);
        vlSheet.properties.SetFloat("_ScatteringCoef", settings.ScaterringCoef);
        vlSheet.properties.SetFloat("_ExtinctionCoef", settings.ExtinctionCoef);
        vlSheet.properties.SetFloat("_traceDistance", settings.traceDistance);
        vlSheet.properties.SetInt("_traceIteration", settings.iteration);
        vlSheet.properties.SetInt("_lightIteration", settings.lightIteration);
        vlSheet.properties.SetInt("_shadowIteration", settings.shadowIteration);
        blurSheet.properties.SetFloat("_BilateralBlurDiffScale", settings.bilateralBlurDiffScale);


        int width = context.camera.pixelWidth >> settings.downSample;
        int height = context.camera.pixelHeight >> settings.downSample;
        context.command.GetTemporaryRT(downSampleBuffer,    width, height, 0, FilterMode.Bilinear);
        context.command.GetTemporaryRT(prev_frame,          width, height, 0, FilterMode.Bilinear);
        context.command.GetTemporaryRT(taa_res,             width, height, 0, FilterMode.Bilinear);      
        context.command.GetTemporaryRT(temp_buffer,         width, height, 0, FilterMode.Bilinear);
        context.command.GetTemporaryRT(blur_res,            width, height, 0, FilterMode.Bilinear);


        context.command.BlitFullscreenTriangle(context.source, downSampleBuffer, vlSheet, 0); //vlight
        
        context.command.BlitFullscreenTriangle(downSampleBuffer, taa_res, vlSheet, 2); //taa

        context.command.BlitFullscreenTriangle(taa_res, temp_buffer, blurSheet, 13);
        context.command.BlitFullscreenTriangle(temp_buffer, blur_res, blurSheet, 14);//bilateraBlur

        context.command.BlitFullscreenTriangle(blur_res, taa_res, vlSheet, 2); //taa

        context.command.Blit(blur_res, downSampleBuffer);//Upsample

        if (settings.debugView)
        {                     
            context.command.BlitFullscreenTriangle(downSampleBuffer, context.destination);
        }
        else
        {           
            context.command.BlitFullscreenTriangle(context.source, context.destination, vlSheet, 1);
        }
        context.command.Blit(downSampleBuffer, prev_frame);
    }
}
