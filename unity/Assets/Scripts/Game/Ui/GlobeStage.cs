// The hologram globe's 3D set (scenes/globe_view.gd _ready, D-418): the camera on the globe's axis with Godot's field
// of view, the near-black background, the tilt and spin pivots, the hologram shell and, just outside it, the land
// sphere that reads the Tellus Nova mask (Shaders/Globe, from globe_hologram.gdshader and globe_land.gdshader). The
// camera runs no post-processing and no exposure: Godot's globe draws with the linear tonemapper, so the additive
// colours show as written. Unity's axes are Godot's with z mirrored: the camera sits on -z looking +z and a turn
// about x or y runs the other way.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

public sealed class GlobeStage
{
    // globe_hologram.gdshader's uniforms.
    const float RIM_POWER = 2.6f, RIM_STRENGTH = 1.4f, BASE_GLOW = 0.06f, SHELL_SCAN = 0.35f;
    const float GRID_LINES = 12f, GRID_WIDTH = 0.035f, GRID_STRENGTH = 0.18f;
    // Both shaders: lines over the sphere's height, sphere heights per second.
    const float SCAN_COUNT = 90f, SCAN_SPEED = 0.12f;
    // globe_land.gdshader's uniforms.
    const float PULSE_HZ = 0.5f, PULSE_DEPTH = 0.3f, FILL = 0.22f, AVAILABLE_FILL = 0.45f, HOVER_FILL = 0.6f;
    const float COAST = 1f, COAST_TEXELS = 2f, LAND_SCAN = 0.25f;
    // Godot's Camera3D near and far planes.
    const float NEAR = 0.05f, FAR = 4000f;
    // Drawn over any camera left in the scene (the lab's own depth).
    const float CAMERA_DEPTH = 10f;
    const int STATE_SLOTS = 8;  // globe_land.gdshader `states[8]`

    static readonly int TimeId = Shader.PropertyToID("_GlobeTime"), HoverId = Shader.PropertyToID("_HoverId");
    static readonly int StatesId = Shader.PropertyToID("_States");

    GameObject root;
    Transform tilt, spin, cam;
    Material shell, land;
    readonly List<UnityEngine.Object> owned = new List<UnityEngine.Object>();
    readonly float[] states = new float[STATE_SLOTS];

    // The set, or null (said in the log) when the shader is missing: the screen then shows its flat backdrop.
    public static GlobeStage Build(byte[] mask, int width, int height)
    {
        Shader shader = Resources.Load<Shader>("Shaders/Globe");
        if (shader == null)
        {
            Debug.LogWarning("globe: Shaders/Globe is missing, a flat backdrop instead");
            return null;
        }
        var stage = new GlobeStage();
        stage.Make(shader, mask, width, height);
        return stage;
    }

    void Make(Shader shader, byte[] mask, int width, int height)
    {
        root = new GameObject("globe_stage");
        Camera();
        tilt = new GameObject("tilt").transform;
        tilt.SetParent(root.transform, false);
        spin = new GameObject("globe").transform;
        spin.SetParent(tilt, false);
        shell = Owned(new Material(shader));
        shell.EnableKeyword("GLOBE_SHELL");
        shell.SetFloat("_RimPower", RIM_POWER);
        shell.SetFloat("_RimStrength", RIM_STRENGTH);
        shell.SetFloat("_BaseGlow", BASE_GLOW);
        shell.SetFloat("_ShellScan", SHELL_SCAN);
        shell.SetFloat("_GridLines", GRID_LINES);
        shell.SetFloat("_GridWidth", GRID_WIDTH);
        shell.SetFloat("_GridStrength", GRID_STRENGTH);
        Shared(shell);
        land = Owned(new Material(shader));
        land.EnableKeyword("GLOBE_LAND");
        land.SetColor("_GlobeLocked", UiKit.LOCKED.linear);
        land.SetColor("_GlobeConquered", UiKit.GOOD.linear);
        land.SetFloat("_PulseHz", PULSE_HZ);
        land.SetFloat("_PulseDepth", PULSE_DEPTH);
        land.SetFloat("_Fill", FILL);
        land.SetFloat("_AvailableFill", AVAILABLE_FILL);
        land.SetFloat("_HoverFill", HOVER_FILL);
        land.SetFloat("_Coast", COAST);
        land.SetFloat("_CoastTexels", COAST_TEXELS);
        land.SetFloat("_LandScan", LAND_SCAN);
        land.SetTexture("_GlobeMask", MaskTexture(mask, width, height));
        land.SetFloatArray(StatesId, states);
        Shared(land);
        Sphere("shell", (float)GlobeOrbit.RADIUS, shell);
        if (mask != null) Sphere("land", (float)(GlobeOrbit.RADIUS * GlobeOrbit.LAND_LIFT), land);
    }

    void Shared(Material m)
    {
        m.SetColor("_GlobeTint", UiKit.ACCENT.linear);
        m.SetFloat("_ScanCount", SCAN_COUNT);
        m.SetFloat("_ScanSpeed", SCAN_SPEED);
    }

    T Owned<T>(T o) where T : UnityEngine.Object
    {
        owned.Add(o);
        return o;
    }

    void Camera()
    {
        var go = new GameObject("camera");
        go.transform.SetParent(root.transform, false);
        cam = go.transform;
        Camera c = go.AddComponent<Camera>();
        c.fieldOfView = (float)GlobeOrbit.CAMERA_FOV;
        c.nearClipPlane = NEAR;
        c.farClipPlane = FAR;
        c.depth = CAMERA_DEPTH;
        HDAdditionalCameraData data = go.AddComponent<HDAdditionalCameraData>();
        GraphicsView.UseCamera(data);
        // globe_view.gd: the environment's background is UiKit BG, drawn through the linear tonemapper.
        data.clearColorMode = HDAdditionalCameraData.ClearColorMode.Color;
        data.backgroundColorHDR = UiKit.BG.linear;
        data.customRenderingSettings = true;
        foreach (FrameSettingsField off in new[] { FrameSettingsField.Postprocess, FrameSettingsField.ExposureControl })
        {
            data.renderingPathCustomFrameSettingsOverrideMask.mask[(uint)off] = true;
            data.renderingPathCustomFrameSettings.SetEnabled(off, false);
        }
    }

    // The mask as Godot's shader reads it (filter_nearest, repeat_enable): one byte per texel, linear, row 0 the north
    // at v 0 as SphereMesh's uv has it.
    Texture2D MaskTexture(byte[] mask, int width, int height)
    {
        if (mask == null) return null;
        var t = Owned(new Texture2D(width, height, TextureFormat.R8, false, true));
        t.filterMode = FilterMode.Point;
        t.wrapMode = TextureWrapMode.Repeat;
        t.SetPixelData(mask, 0);
        t.Apply(false, true);
        return t;
    }

    void Sphere(string name, float radius, Material m)
    {
        var go = new GameObject(name);
        go.transform.SetParent(spin, false);
        go.AddComponent<MeshFilter>().sharedMesh = Owned(GlobeSphere.Make(radius));
        MeshRenderer r = go.AddComponent<MeshRenderer>();
        r.sharedMaterial = m;
        r.shadowCastingMode = ShadowCastingMode.Off;
        r.receiveShadows = false;
    }

    // The pose from the orbit (globe_view.gd _process): the tilt about x, the spin about y, the camera's distance.
    public void Pose(GlobeOrbit orbit, float time)
    {
        tilt.localRotation = Quaternion.Euler(-(float)(orbit.Tilt * Mathf.Rad2Deg), 0f, 0f);
        spin.localRotation = Quaternion.Euler(0f, -(float)(orbit.Yaw * Mathf.Rad2Deg), 0f);
        cam.localPosition = new Vector3(0f, 0f, -(float)orbit.Distance);
        shell.SetFloat(TimeId, time);
        land.SetFloat(TimeId, time);
    }

    // Each mask value's Campaign.State (globe_view.gd set_states).
    public void SetStates(long[] perValue)
    {
        Array.Clear(states, 0, states.Length);
        for (int v = 0; v < perValue.Length && v < STATE_SLOTS; v++) states[v] = perValue[v];
        land.SetFloatArray(StatesId, states);
    }

    // The continent under the pointer, by mask value (0 none).
    public void SetHover(int value) => land.SetFloat(HoverId, value);

    public void Show(bool on)
    {
        if (root != null) root.SetActive(on);
    }

    public void Close()
    {
        if (root != null) UnityEngine.Object.Destroy(root);
        foreach (UnityEngine.Object o in owned)
            if (o != null) UnityEngine.Object.Destroy(o);
        owned.Clear();
    }
}
