using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(GodRaysRenderer), PostProcessEvent.BeforeStack, "Custom/GodRays")]
public class GodRays : PostProcessEffectSettings {

    [Range(0f, 20f)]
    public FloatParameter sun_density = new FloatParameter { value = 8f };
    [Range(0f, 5f)]
    public FloatParameter light_density = new FloatParameter { value = 2f };
    [Range(1, 4)]
    public IntParameter downSample = new IntParameter { value = 4 };
    [Range(0f, 0.99f)]
    public FloatParameter MieG = new FloatParameter { value = 0.6f };
}

public class GodRaysRenderer : PostProcessEffectRenderer<GodRays>
{
    private Shader gr_shader;
    private int downSampleBuffer;

    public override void Init()
    {
        base.Init();
        gr_shader = Shader.Find("Hidden/VL_Test_Shader");
        downSampleBuffer = Shader.PropertyToID("vlight_Tex");
    }

    public override void Render(PostProcessRenderContext context)
    {
        PropertySheet sheet = context.propertySheets.Get(gr_shader);

        float MieG = settings.MieG;
        float thickness = RenderSettings.skybox.GetFloat("_AtmosphereThickness");

        sheet.properties.SetVector("_MieG", new Vector4(1 - (MieG * MieG), 1 + (MieG * MieG), 2 * MieG, 1.0f / (4.0f * Mathf.PI)));
        sheet.properties.SetFloat("sun_density", settings.sun_density);
        sheet.properties.SetFloat("light_density", settings.light_density);
        sheet.properties.SetFloat("_AtmosphereThickness", thickness);
        

        int width = context.camera.pixelWidth >> settings.downSample;
        int height = context.camera.pixelHeight >> settings.downSample;
        context.command.GetTemporaryRT(downSampleBuffer, width, height, 0, FilterMode.Bilinear);

        context.command.BlitFullscreenTriangle(context.source, downSampleBuffer, sheet, 0);
        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 1);
    }
}
