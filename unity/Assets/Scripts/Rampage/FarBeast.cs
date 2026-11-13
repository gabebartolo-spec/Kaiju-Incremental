using System;
using System.Collections.Generic;
using System.IO;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

// The far kaiju of SkylineRampage as an impostor (scenes/far_beast.gd): its model (FarBeastWalk, the insectoid's rig
// and walk) walks in a little world of its own, far under the city on its own layer, filmed side-on from the
// player's view direction by an orthographic lens into a picture; the picture stands in the skyline on one quad
// facing the player, shaded, rimmed with the fires' light and hazed as the far towers are (HorizonFx FAR_BEAST).
// The little world has its own sun and the fire rims fixed to the lens, lit only while the lens renders.
// Godot axes throughout; Unity's negate z. Presentation only.
public sealed class FarBeast : IDisposable
{
    const float FRAME = 1.4f;  // the picture's height in model heights (room for a raised limb)
    const float FRAME_FOOT = 0.08f;  // share of the picture below the feet
    const float LENS_BACK = 60f;  // the lens's distance from the model (orthographic)
    const float LENS_NEAR = 0.05f;
    const float LITTLE_Y = -4000f;  // the little world's floor, far under the city
    const int LAYER = 30;  // the little world's layer: only the lens sees it, only its lights light it
    const float DRAW_BOUNDS = 20000f;  // the instanced call offsets by the bounds' centre: keep it at the origin
    const int HEADER = 26, CELL_BYTES = 15, CUBE_BYTES = 52, BONE_BYTES = 64, FILL_VERT_BYTES = 20, INDEX_BYTES = 4;
    const int VOXEL_AT = 18, COUNT_AT = 22, BYTE_MAX = 255, SHIFT_THIRD = 16;  // .vskin header; a cube's third bone
    const uint COLOR_SALT = 7;
    const int CELL_BONE2 = 11, CELL_BONE3 = 12, CELL_W0 = 13, CELL_W1 = 14;  // a .vskin cell's second/third bone, weights
    const float LENS_DEPTH = -100f;  // before the player's camera, which shows its picture
    const float RIM_WIDTH = 3f;  // far_impostor.gdshaderinc rim_width, picture pixels
    const int QUAD_VERTS = 6, RT_DEPTH = 24;
    const float SUN_TURN = -35f, MODEL_RIM_ENERGY = 2.4f;  // far_beast.gd sun yaw; kaiju_model.gd's cool rim
    const string MODEL_RIM_COLOR = "9fc4ff";
    static readonly Vector3[] RIMS = { new Vector3(25f, 145f, 0f), new Vector3(25f, 215f, 0f) };  // energy rim_energy
    static readonly Vector3 RIM_FILL = new Vector3(30f, 0f, 0f), MODEL_RIM = new Vector3(-35f, 160f, 0f);

    public readonly FarBeastWalk walk;
    readonly int cubeCount;
    readonly float frame;
    readonly GraphicsBuffer cubeBuffer, boneBuffer;
    readonly Matrix4x4[] pose;
    readonly Mesh cube, fill;
    readonly Material cubeMat, fillMat, quadMat;
    readonly MaterialPropertyBlock cubeBlock = new MaterialPropertyBlock(), fillBlock = new MaterialPropertyBlock();
    readonly RenderTexture view;
    readonly Camera lens;
    readonly List<Light> lights = new List<Light>();
    readonly Light[] rims = new Light[RIMS.Length + 1];
    Light modelRim;
    double yaw;
    // Where it has walked (x, skyline): the run's log line.
    public double MinX { get; private set; } = double.MaxValue;
    public double MaxX { get; private set; } = double.MinValue;

    // Missing bake (tools/unity/bake_slice.sh writes far_beast.*): null, and the far rampage walks without it.
    public static FarBeast Load(S.GDict cfg, Shader lit, Mesh cubeMesh, float inset, float noise, float seamDark, float unit)
    {
        string rig = Path.Combine(SliceData.Dir, "far_beast.rig.json"), skin = Path.Combine(SliceData.Dir, "far_beast.vskin");
        if (File.Exists(rig) && File.Exists(skin))
            return new FarBeast(cfg, File.ReadAllText(rig), File.ReadAllBytes(skin), lit, cubeMesh, inset, noise, seamDark, unit);
        Debug.LogWarning("far beast: no " + rig + " or " + skin + " (tools/unity/bake_slice.sh); the far rampage has no beast");
        return null;
    }

    FarBeast(S.GDict cfg, string rigJson, byte[] skin, Shader lit, Mesh cubeMesh, float inset, float noise, float seamDark, float unit)
    {
        walk = new FarBeastWalk(rigJson, S.Num.F(cfg["height"]));
        frame = (float)(walk.height * FRAME);
        cube = cubeMesh;
        float voxel = BitConverter.ToSingle(skin, VOXEL_AT);
        cubeCount = BitConverter.ToInt32(skin, COUNT_AT);
        cubeBuffer = Cubes(skin, voxel, noise, seamDark);
        pose = new Matrix4x4[walk.rig.Count];
        boneBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, pose.Length, BONE_BYTES);
        int at = HEADER + cubeCount * CELL_BYTES;
        int verts = BitConverter.ToInt32(skin, at);
        int indexAt = at + 4 + verts * FILL_VERT_BYTES;
        fill = Croc.BuildFill(skin, at + 4, verts, indexAt + 4, BitConverter.ToInt32(skin, indexAt));
        cubeMat = new Material(lit) { enableInstancing = true };
        cubeMat.EnableKeyword("SLICE_CUBE");
        cubeMat.SetFloat("_CubeSize", voxel * inset);
        fillMat = new Material(lit);
        fillMat.EnableKeyword("SLICE_FILL");
        SkinLook(voxel);
        int px = (int)S.Num.I(cfg["picture_px"]);
        view = new RenderTexture(px, px, RT_DEPTH, RenderTextureFormat.ARGBHalf) { name = "far beast" };
        lens = Lens(view);
        Lights(cfg, unit);
        quadMat = Quad(cfg, px);
        RenderPipelineManager.beginCameraRendering += OnCamera;
    }

    GraphicsBuffer Cubes(byte[] skin, float voxel, float noise, float seamDark)
    {
        var data = new NativeArray<Croc.Cube>(cubeCount, Allocator.Temp, NativeArrayOptions.ClearMemory);
        for (int i = 0; i < cubeCount; i++)
        {
            int k = HEADER + i * CELL_BYTES;
            short sx = BitConverter.ToInt16(skin, k), sy = BitConverter.ToInt16(skin, k + 2), sz = BitConverter.ToInt16(skin, k + 4);
            float factor = 1f + Croc.JitterT(sx, sy, sz, COLOR_SALT) * noise;
            float dark = skin[k + 9] != 0 ? seamDark : 1f;
            data[i] = new Croc.Cube
            {
                cx = sx * voxel,
                cy = (sy + 0.5f) * voxel,
                cz = sz * voxel,
                w0 = skin[k + CELL_W0] / (float)BYTE_MAX,
                r = Mathf.Clamp01(skin[k + 6] / (float)BYTE_MAX * factor) * dark,
                g = Mathf.Clamp01(skin[k + 7] / (float)BYTE_MAX * factor) * dark,
                b = Mathf.Clamp01(skin[k + 8] / (float)BYTE_MAX * factor) * dark,
                w1 = skin[k + CELL_W1] / (float)BYTE_MAX,
                bones = (uint)(skin[k + 10] | skin[k + CELL_BONE2] << 8 | skin[k + CELL_BONE3] << SHIFT_THIRD),
            };
        }
        var buffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, Mathf.Max(1, cubeCount), CUBE_BYTES);
        buffer.SetData(data);
        data.Dispose();
        return buffer;
    }

    // The hide pattern's cell is the beast's own voxel's (Croc sets the croc's as a global).
    void SkinLook(float voxel)
    {
        S.GDict look = S.Content.Look();
        float cell = voxel * (float)S.Num.F(look["kaiju_hide_cell_voxels"]);
        cubeBlock.SetFloat("_HideCell", cell);
        fillBlock.SetFloat("_HideCell", cell);
        cubeBlock.SetBuffer("_Cubes", cubeBuffer);
        cubeBlock.SetBuffer("_Bones", boneBuffer);
        fillBlock.SetBuffer("_Bones", boneBuffer);
    }

    // The little camera: orthographic, KaijuModel.MODEL_HEIGHT x FRAME tall, the little world only, no fog.
    static Camera Lens(RenderTexture target)
    {
        var go = new GameObject("far beast lens");
        var cam = go.AddComponent<Camera>();
        cam.orthographic = true;
        cam.nearClipPlane = LENS_NEAR;
        cam.farClipPlane = LENS_BACK * 2f;
        cam.cullingMask = 1 << LAYER;
        cam.targetTexture = target;
        cam.depth = LENS_DEPTH;
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = Color.clear;
        var data = go.AddComponent<HDAdditionalCameraData>();
        data.clearColorMode = HDAdditionalCameraData.ClearColorMode.Color;
        data.backgroundColorHDR = Color.clear;
        data.allowDynamicResolution = false;
        foreach (FrameSettingsField off in new[] { FrameSettingsField.AtmosphericScattering, FrameSettingsField.Volumetrics,
                     FrameSettingsField.ShadowMaps, FrameSettingsField.ContactShadows, FrameSettingsField.SSAO, FrameSettingsField.SSR,
                     FrameSettingsField.SSGI, FrameSettingsField.MotionVectors, FrameSettingsField.Decals })
        {
            data.customRenderingSettings = true;
            data.renderingPathCustomFrameSettingsOverrideMask.mask[(uint)off] = true;
            data.renderingPathCustomFrameSettings.SetEnabled(off, false);
        }
        return cam;
    }

    // far_beast.gd _add_lighting and _rim_light: the city's sun, the fires' rims on the lens, the model's cool rim.
    void Lights(S.GDict cfg, float unit)
    {
        S.GDict look = S.Content.Look();
        Light sun = Lamp("far beast sun", Hex(S.Gd.Str(look["sun_color"])), S.Num.F(look["sun_energy"]), unit);
        sun.transform.rotation = Toward(BB.Euler(Rad(new Vector3((float)S.Num.F(look["sun_pitch"]), SUN_TURN, 0f))));
        Color fire = Hex(S.Gd.Str(cfg["fire"]));
        for (int i = 0; i < RIMS.Length; i++) rims[i] = Lamp("far beast rim", fire, S.Num.F(cfg["rim_energy"]), unit);
        rims[RIMS.Length] = Lamp("far beast rim fill", fire, S.Num.F(cfg["rim_fill"]), unit);
        modelRim = Lamp("far beast cool rim", Hex(MODEL_RIM_COLOR), MODEL_RIM_ENERGY, unit);
    }

    Light Lamp(string name, Color color, double energy, float unit)
    {
        var go = new GameObject(name) { layer = LAYER };
        Light light = go.AddComponent<Light>();
        light.type = LightType.Directional;
        light.lightUnit = LightUnit.Lux;
        light.color = color;
        light.intensity = (float)energy * Mathf.PI * unit;
        light.shadows = LightShadows.None;
        light.cullingMask = 1 << LAYER;
        go.AddComponent<HDAdditionalLightData>();
        light.enabled = false;
        lights.Add(light);
        return light;
    }

    Material Quad(S.GDict cfg, int px)
    {
        var mat = new Material(Resources.Load<Shader>("Shaders/HorizonFx")) { renderQueue = (int)RenderQueue.Transparent };
        mat.EnableKeyword("FAR_BEAST");
        mat.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
        mat.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
        mat.SetFloat("_ZWrite", 1f);  // its body hides what stands behind it (far_impostor's depth pre-pass)
        mat.SetTexture("_BeastView", view);
        mat.SetVector("_BeastShape", new Vector4((float)S.Num.F(cfg["shade"]), (float)S.Num.F(cfg["rim_edge"]), px, RIM_WIDTH));
        mat.SetVector("_BeastRim", Hex(S.Gd.Str(cfg["fire"])).linear);
        return mat;
    }

    // Only the lens lights the little world, and the little world's lights light nothing else.
    void OnCamera(ScriptableRenderContext context, Camera camera)
    {
        bool mine = camera == lens;
        foreach (Light light in lights) light.enabled = mine;
    }

    // One frame (far_beast.gd walk): `at` its feet in the skyline, `yaw` its facing, `eye` the player's camera.
    public void Walk(float delta, BV at, double facing, Vector3 eye)
    {
        yaw = facing;
        MinX = Math.Min(MinX, at.x);
        MaxX = Math.Max(MaxX, at.x);
        walk.Walk(delta, at, facing);
        var look = new BV(at.x - eye.x, 0.0, at.z - eye.z).Normalized();
        if (look == BV.ZERO) look = BV.FORWARD;
        double size = walk.Size;
        float lift = (float)(walk.modelHeight * FRAME * (0.5 - FRAME_FOOT));
        var mid = new BV(at.x / size, LITTLE_Y + lift, at.z / size);
        lens.orthographicSize = (float)(walk.modelHeight * FRAME * 0.5);
        lens.transform.SetPositionAndRotation(U(mid - look * LENS_BACK), Quaternion.LookRotation(U(look), Vector3.up));
        BB facingBasis = BB.LookingAt(look);  // seen as the little camera sees it: front to the player
        for (int i = 0; i < RIMS.Length; i++) rims[i].transform.rotation = Toward(facingBasis * BB.Euler(Rad(RIMS[i])));
        rims[RIMS.Length].transform.rotation = Toward(facingBasis * BB.Euler(Rad(RIM_FILL)));
        modelRim.transform.rotation = Toward(BB.Axis(BV.UP, yaw) * BB.Euler(Rad(MODEL_RIM)));
        var centre = new BV(at.x, at.y + frame * (0.5 - FRAME_FOOT), at.z);
        quadMat.SetVector("_BeastCentre", U(centre));
        quadMat.SetVector("_BeastRight", U(facingBasis.X) * frame);
        quadMat.SetVector("_BeastUp", U(facingBasis.Y) * frame);
        Draw();
    }

    public void Stomp() => walk.Stomp();

    void Draw()
    {
        for (int i = 0; i < pose.Length; i++) pose[i] = M(walk.rig.SkinPose(i));
        boneBuffer.SetData(pose);
        Matrix4x4 world = Matrix4x4.Translate(new Vector3(0f, LITTLE_Y, 0f)) * M(walk.rig.RigGlobal);
        cubeBlock.SetMatrix("_CrocWorld", world);
        fillBlock.SetMatrix("_CrocWorld", world);
        var bounds = new Bounds(Vector3.zero, Vector3.one * DRAW_BOUNDS);
        Graphics.DrawMeshInstancedProcedural(cube, 0, cubeMat, bounds, cubeCount, cubeBlock, ShadowCastingMode.Off, false, LAYER, lens);
        var rf = new RenderParams(fillMat) { matProps = fillBlock, worldBounds = bounds, layer = LAYER, camera = lens, shadowCastingMode = ShadowCastingMode.Off };
        Graphics.RenderMesh(rf, fill, 0, Matrix4x4.identity);
        Graphics.DrawProcedural(quadMat, bounds, MeshTopology.Triangles, QUAD_VERTS, 1, null, null, ShadowCastingMode.Off, false, 0);
    }

    // A Godot transform as a matrix in Godot axes (the skin shader mirrors z last).
    static Matrix4x4 M(BT t)
    {
        var m = Matrix4x4.identity;
        m.SetRow(0, new Vector4((float)t.basis.r0.x, (float)t.basis.r0.y, (float)t.basis.r0.z, (float)t.origin.x));
        m.SetRow(1, new Vector4((float)t.basis.r1.x, (float)t.basis.r1.y, (float)t.basis.r1.z, (float)t.origin.y));
        m.SetRow(2, new Vector4((float)t.basis.r2.x, (float)t.basis.r2.y, (float)t.basis.r2.z, (float)t.origin.z));
        return m;
    }

    static Vector3 U(BV v) => new Vector3((float)v.x, (float)v.y, (float)-v.z);

    static BV Rad(Vector3 degrees) => new BV(degrees.x * Mathf.Deg2Rad, degrees.y * Mathf.Deg2Rad, degrees.z * Mathf.Deg2Rad);

    // A Godot light's basis (it shines along its -z) as a Unity rotation.
    static Quaternion Toward(BB basis) => Quaternion.LookRotation(U(-basis.Z));

    static Color Hex(string s) => ColorUtility.TryParseHtmlString("#" + s.TrimStart('#'), out Color c) ? c : Color.magenta;

    public void Dispose()
    {
        RenderPipelineManager.beginCameraRendering -= OnCamera;
        cubeBuffer.Dispose();
        boneBuffer.Dispose();
        // At quit Unity may have torn the scene down first.
        foreach (Light light in lights)
            if (light != null) UnityEngine.Object.Destroy(light.gameObject);
        if (lens != null) UnityEngine.Object.Destroy(lens.gameObject);
        view.Release();
        UnityEngine.Object.Destroy(view);
        UnityEngine.Object.Destroy(cubeMat);
        UnityEngine.Object.Destroy(fillMat);
        UnityEngine.Object.Destroy(quadMat);
        UnityEngine.Object.Destroy(fill);
    }
}
