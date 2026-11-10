using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

// The rampage's vignette and colour fringe (scenes/vignette.gdshader, scenes/fringe.gdshader), one pass after AgX so
// both work on the display picture as Godot's canvas layer does. PostFxView writes the numbers each frame.
// HDRP only runs it when it is listed after AgxTonemap in the global settings (SliceBuild.RegisterAgx).
[Serializable, VolumeComponentMenu("Slice/PostFx")]
public sealed class PostFxPass : CustomPostProcessVolumeComponent, IPostProcessComponent
{
    // Frames this pass drew: 0 in the stats line means HDRP does not have it registered.
    public static int Draws;

    // The vignette's colour as written in the data (display values, not linear).
    public ColorParameter tint = new ColorParameter(Color.black);
    public FloatParameter strength = new FloatParameter(0f);
    public FloatParameter inner = new FloatParameter(0.5f);
    public FloatParameter outer = new FloatParameter(1f);
    public FloatParameter fringePx = new FloatParameter(0f);
    Material material;

    public bool IsActive() => material != null && (strength.value > 0f || fringePx.value > 0f);
    public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

    public override void Setup()
    {
        material = CoreUtils.CreateEngineMaterial(Resources.Load<Shader>("Shaders/PostFx"));
    }

    public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
        Draws++;
        material.SetVector("_PostTint", (Vector4)tint.value);
        material.SetFloat("_PostStrength", strength.value);
        material.SetFloat("_PostInner", inner.value);
        material.SetFloat("_PostOuter", outer.value);
        material.SetFloat("_PostFringePx", fringePx.value);
        material.SetTexture("_Source", source);
        HDUtils.DrawFullScreen(cmd, material, destination);
    }

    public override void Cleanup() => CoreUtils.Destroy(material);
}
