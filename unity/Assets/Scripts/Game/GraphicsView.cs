using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

// Puts the graphics preset (Kaiju.Game.GraphicsPreset; D-478) on HDRP, as graphics_presets.gd apply() and
// apply_to() did on Godot's viewport, sun and environment: render scale and upscaler, anti-aliasing, the sun's
// shadow size, distance and cascades, its angular size, SSAO and SSGI. SettingsApply calls Apply on a level
// change; RampageGame hands over its sun and look profile at StartRun, and each game camera joins by UseCamera.
// Not applied (HDRP has no runtime knob, see GraphicsPreset.Line in the log): MSAA, which needs forward shading
// (SliceLit is deferred), so SMAA stands in; the shadow filter, which is the HDRP asset's own (Medium).
public static class GraphicsView
{
    // FSR's sharpness in stops past which RCAS no longer shows: HDRP's FSRUtils.kMaxSharpnessStops is internal,
    // so it is rebuilt from the public default pair (stops and its linear value).
    const float MAX_SHARPNESS_STOPS = FSRUtils.kDefaultSharpnessStops / (1f - FSRUtils.kDefaultSharpnessLinear);

    static readonly List<HDAdditionalCameraData> cameras = new List<HDAdditionalCameraData>();
    static HDAdditionalLightData sun;
    static VolumeProfile profile;
    static float percent = 100f;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset()
    {
        cameras.Clear();
        sun = null;
        profile = null;
        percent = 100f;
        DynamicResolutionHandler.SetDynamicResScaler(() => percent, DynamicResScalePolicyType.ReturnsPercentage);
    }

    // The player's level onto every camera, the run's sun and its profile; logs one line.
    public static GraphicsPreset Apply()
    {
        GraphicsPreset p = GraphicsPreset.Current();
        percent = (float)(p.scale * 100.0);
        cameras.RemoveAll(c => c == null);
        foreach (HDAdditionalCameraData data in cameras) Camera(data, p);
        if (sun != null) Sun(sun, p);
        if (profile != null) Profile(profile, p);
        // dof_drawn: the far blur is not ported (looks ship far_blur_amount 0, D-360), so no depth of field is drawn.
        Debug.Log($"settings: graphics {p.level} applied: {p.Line()} dof_drawn off");
        return p;
    }

    // A rampage starts (graphics_presets.gd start_run): its sun and look take the preset and its counts freeze.
    public static VolumeProfile StartRun(VolumeProfile look, HDAdditionalLightData light)
    {
        profile = look;
        sun = light;
        GraphicsPreset.StartRun(Apply());
        Debug.Log("graphics: run caps " + GraphicsPreset.CapsLine());
        return look;
    }

    // The rampage is over: the counts read the level in use again; the look's profile is destroyed.
    public static void EndRun(VolumeProfile look)
    {
        GraphicsPreset.EndRun();
        sun = null;
        profile = null;
        if (look != null) Object.Destroy(look);
    }

    // A game camera takes the preset now and on every later change.
    public static void UseCamera(HDAdditionalCameraData data)
    {
        cameras.Add(data);
        Camera(data, GraphicsPreset.Current());
    }

    static void Camera(HDAdditionalCameraData data, GraphicsPreset p)
    {
        data.antialiasing = p.aa == CameraAa.Smaa ? HDAdditionalCameraData.AntialiasingMode.SubpixelMorphologicalAntiAliasing
            : p.aa == CameraAa.Fxaa ? HDAdditionalCameraData.AntialiasingMode.FastApproximateAntialiasing
            : HDAdditionalCameraData.AntialiasingMode.None;
        if (p.aa == CameraAa.Smaa) data.SMAAQuality = (HDAdditionalCameraData.SMAAQualityLevel)p.smaaTier;
        // Below full scale the camera renders smaller (the HDRP asset's software dynamic resolution) and upscales.
        data.allowDynamicResolution = p.scale < 1.0;
        DynamicResolutionHandler.SetUpscaleFilter(data.GetComponent<Camera>(), Filter(p.upscaler));
        data.fsrOverrideSharpness = true;
        data.fsrSharpness = Mathf.Clamp01(1f - (float)p.fsrSharpness / MAX_SHARPNESS_STOPS);
        FrameSetting(data, FrameSettingsField.SSAO, p.ssao);
        FrameSetting(data, FrameSettingsField.SSGI, p.ssgi);
    }

    // HDRP's Bilinear upscaler is obsolete (CatmullRom is its cheap one); FSR2 needs AMD's plugin, so FSR1.
    static DynamicResUpscaleFilter Filter(Upscaler u) =>
        u == Upscaler.Bilinear ? DynamicResUpscaleFilter.CatmullRom : DynamicResUpscaleFilter.EdgeAdaptiveScalingUpres;

    static void FrameSetting(HDAdditionalCameraData data, FrameSettingsField field, bool on)
    {
        data.customRenderingSettings = true;
        data.renderingPathCustomFrameSettingsOverrideMask.mask[(uint)field] = true;
        data.renderingPathCustomFrameSettings.SetEnabled(field, on);
    }

    static void Sun(HDAdditionalLightData light, GraphicsPreset p)
    {
        light.SetShadowResolutionOverride(true);
        light.SetShadowResolution(p.cascadeSize);
        light.angularDiameter = (float)p.sunAngular;
    }

    static void Profile(VolumeProfile look, GraphicsPreset p)
    {
        HDShadowSettings shadows = Get<HDShadowSettings>(look);
        shadows.maxShadowDistance.Override((float)p.shadowDistance);
        shadows.cascadeShadowSplitCount.Override(p.cascades);
        Get<ScreenSpaceAmbientOcclusion>(look).active = p.ssao;
        Get<GlobalIllumination>(look).enable.Override(p.ssgi);
        if (p.farBlur != GraphicsPreset.OFF && LookFarBlur() > 0.0)
            Debug.LogWarning("graphics: the look sets far_blur_amount but the far blur (scenes/far_depth.gd) is not ported");
    }

    // The look's far blur (looks.json far_blur_amount; D-360 ships it at 0, so no camera carries one).
    static double LookFarBlur() => S.Num.F(S.Content.Look().Get("far_blur_amount", 0.0));

    static T Get<T>(VolumeProfile look) where T : VolumeComponent => look.TryGet(out T found) ? found : look.Add<T>(true);
}
