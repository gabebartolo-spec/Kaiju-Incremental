using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

// The game's tonemapper, after HDRP's bloom and with its own tonemapping off.
[Serializable, VolumeComponentMenu("Slice/AgX")]
public sealed class AgxTonemap : CustomPostProcessVolumeComponent, IPostProcessComponent
{
    public FloatParameter exposure = new FloatParameter(1f);
    public FloatParameter contrast = new FloatParameter(1f);
    public FloatParameter white = new FloatParameter(1f);
    public FloatParameter saturation = new FloatParameter(1f);
    public FloatParameter postContrast = new FloatParameter(1f);
    Material material;

    public bool IsActive() => material != null;
    public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

    public override void Setup()
    {
        material = CoreUtils.CreateEngineMaterial(Resources.Load<Shader>("Shaders/Agx"));
    }

    public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
        material.SetFloat("_AgxExposure", exposure.value);
        material.SetFloat("_AgxContrast", contrast.value);
        material.SetFloat("_AgxWhite", white.value);
        material.SetFloat("_AgxSaturation", saturation.value);
        material.SetFloat("_AgxPostContrast", postContrast.value);
        material.SetTexture("_Source", source);
        HDUtils.DrawFullScreen(cmd, material, destination);
    }

    public override void Cleanup() => CoreUtils.Destroy(material);
}
