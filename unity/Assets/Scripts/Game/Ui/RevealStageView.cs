// The set the evolution reveal plays on, shared with the demo end card (scenes/reveal_stage.gd RevealStage, the
// 3D frame of scenes/demo_end.gd): a dark backdrop, a sun, the ground, a real city tower beside the kaiju and a
// camera that frames them both, drawn into a picture on a RawImage (Godot's SubViewport with its own world).
// Godot's set has its own Environment.new(): a colour background (its ambient too), the sun below, and Godot's defaults
// for the rest (linear tonemap, no glow, no fog, no SSAO, no shadows on the sun); so the run's look is laid with
// those numbers and its AgX, bloom, fog, SSAO and contact shadows are switched off on this set's volume. The kaiju
// is the croc body (KaijuModel) turned 0.8 pi, idling, with its clip roar when asked (DemoEnd ROAR_EVERY). The
// tower is a one-building city drawn by the city's own CityDraw (Godot: the city's BuildingView, style 0).
// Everything is laid in Godot's axes; z is negated where it reaches Unity.
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.UI;
using S = Kaiju.Sim;

public sealed class RevealStageView : MonoBehaviour
{
    // reveal_stage.gd TOWER_SIDE: the comparison tower's footprint (chunks).
    const int TOWER_SIDE = 6;
    // reveal_stage.gd build: the camera's fov, the ground's side, the sun's turn and energy, the ambient's energy,
    // and the framing: the camera stands TALL_BACK x the tallest + PAD back, CAM_RISE x the tallest up.
    // The set never names an ambient source, so Godot's default (AMBIENT_SOURCE_BG) lights it with the background
    // colour at the background's energy (1): its ambient_light_color 6f86a8 x 0.6 is not used.
    const float FOV = 40f, GROUND_SIDE = 200f, SUN_PITCH = -35f, SUN_TURN = -40f, SUN_ENERGY = 1.2f, AMBIENT_ENERGY = 1f;
    const float TALL_BACK = 1.55f, PAD = 8f, CAM_RISE = 0.15f, HALF = 0.5f;
    const string BACKGROUND = "1b2433", AMBIENT = BACKGROUND, GROUND = "2c3036", SUN_COLOUR = "ffffff";
    // demo_end.gd: the kaiju's turn (rotation.y = PI * 0.8).
    const float KAIJU_TURN = Mathf.PI * 0.8f;
    // evolution_reveal.gd VIEW_MAX: the frame's widest picture (its aspect).
    public static readonly Vector2 VIEW_MAX = new Vector2(1200f, 760f);
    const float CAMERA_NEAR = 0.05f, CAMERA_FAR = 4000f;
    const int DEPTH_BITS = 24;
    // slice.json look voxel_inset's fallback, as the rampage reads it.
    const float VOXEL_INSET = 0.99f;

    RawImage image;
    RenderTexture target;
    Camera cam;
    GameObject root;
    Croc croc;
    CityDraw tower;
    S.RampageSim towerSim;
    Debris debris;
    Material groundMat;
    readonly List<Object> made = new List<Object>();
    float bodyScale;

    // How many roars were asked for (demo_end.gd roars), and every how many frames the kaiju roars on its own
    // (demo_end.gd ROAR_EVERY; 0: only when asked).
    public int Roars { get; private set; }
    public int RoarEvery;
    int frame;
    public string Stage => croc != null ? croc.Stage : "";

    // `holder`: the frame's inside, sized (px at 1080p) by the caller. stats: tuning "kaiju" with the size tier on
    // top (demo_end.gd setup); back and shift as RevealStage.build (the demo card: 1.25 and 0.1).
    public static RevealStageView Create(RectTransform holder, S.GDict stats, float back, float shift)
    {
        RawImage image = holder.gameObject.AddComponent<RawImage>();
        image.raycastTarget = false;
        RevealStageView v = holder.gameObject.AddComponent<RevealStageView>();
        v.image = image;
        v.Build(stats, back, shift);
        return v;
    }

    void Build(S.GDict stats, float back, float shift)
    {
        S.GDict cfg = S.CityGrowth.ForStats(stats);
        S.GDict city = cfg["city"];
        long size = S.Num.I(stats["size"]);
        bodyScale = (float)S.Growth.BodyScale(stats, city);
        long floors = TowerFloors(size, city);
        root = new GameObject("reveal stage");
        made.Add(root);
        Tuning tuning = SliceData.LoadTuning();
        Dictionary<string, object> slice = SliceData.LoadJson("slice.json");
        Look(tuning, slice);
        Shader lit = Resources.Load<Shader>("Shaders/SliceLit");
        Ground();
        var lookCfg = MiniJson.Obj(slice["look"]);
        float height = (float)TreeText.MODEL_HEIGHT * bodyScale;
        float tallest = Mathf.Max(height, floors);
        float towerX = height * HALF + TOWER_SIDE;
        Tower(towerX, floors, stats, cfg, lit, tuning);
        Mesh cube = SliceGame.CubeMesh(1f, true);
        made.Add(cube);
        croc = new Croc(tuning, slice, lit, cube, SliceData.F(lookCfg, "voxel_inset", VOXEL_INSET), Croc.BodyStage(size));
        croc.position = Vector3.zero;
        croc.yaw = KAIJU_TURN;
        Camera(towerX, tallest, back, shift);
        Debug.Log($"reveal stage: body {croc.Stage} scale {bodyScale:F2} ({height:F1} m), tower {floors} floors at x {towerX:F1}");
    }

    // reveal_stage.gd tower_floors: the tallest tower a body of this tier topples without undermining it.
    public static long TowerFloors(long sizeTier, S.GDict city) =>
        System.Math.Min(sizeTier * S.Num.I(city["tier_height"]), S.Num.I(city["max_height"]));

    // The set's Environment and sun, through the run's look so the croc and the tower take them as in a run.
    void Look(Tuning tuning, Dictionary<string, object> slice)
    {
        var look = new Dictionary<string, object>(MiniJson.Obj(slice["look"]));
        look["ambient_color"] = AMBIENT;
        look["ambient"] = AMBIENT_ENERGY;
        look["sun_color"] = SUN_COLOUR;
        look["sun_energy"] = SUN_ENERGY;
        look["sun_pitch"] = SUN_PITCH;
        look["fog_color"] = BACKGROUND;
        VolumeProfile profile = SliceGame.ApplyLook(tuning, slice, look);
        made.Add(profile);
        foreach (Volume vol in FindObjectsByType<Volume>(FindObjectsSortMode.None))
            if (vol.sharedProfile == profile) made.Add(vol.gameObject);
        // Godot's Environment.new() defaults: linear tonemap, no glow, no fog, no SSAO. Glow and SSAO are set to
        // nothing rather than left out: left out, HDRP's default profile's bloom (0.2 from threshold 0) shows.
        if (profile.TryGet(out AgxTonemap agx)) agx.active = false;
        if (profile.TryGet(out Bloom bloom)) bloom.intensity.Override(0f);
        if (profile.TryGet(out Fog fog)) fog.enabled.Override(false);
        if (profile.TryGet(out ScreenSpaceAmbientOcclusion ssao)) ssao.intensity.Override(0f);
        if (profile.TryGet(out ContactShadows contact)) contact.enable.Override(false);
        // The sun at (-35, -40, 0) degrees (ApplyLook turns it -35); DirectionalLight3D casts no shadow by default.
        HDAdditionalLightData sun = SliceGame.Sun;
        made.Add(sun.gameObject);
        sun.transform.rotation = SunTurn();
        sun.GetComponent<Light>().shadows = LightShadows.None;
        Shader.SetGlobalVector("_FireSunDir", -sun.transform.forward);
    }

    // SliceGame.ApplyLook's sun formula with the set's turn: Godot euler (pitch, turn, 0), light along its -z.
    static Quaternion SunTurn()
    {
        float pitch = SUN_PITCH * Mathf.Deg2Rad, turn = SUN_TURN * Mathf.Deg2Rad;
        var dir = new Vector3(-Mathf.Sin(turn) * Mathf.Cos(pitch), Mathf.Sin(pitch), -Mathf.Cos(turn) * Mathf.Cos(pitch));
        return Quaternion.LookRotation(new Vector3(dir.x, dir.y, -dir.z));
    }

    // A 200 m plane in the ground's colour, lit as a StandardMaterial3D (TitleFx TITLE_SOLID: ambient + sun).
    void Ground()
    {
        float h = GROUND_SIDE * HALF;
        var mesh = new Mesh { name = "reveal ground" };
        mesh.vertices = new[] { new Vector3(-h, 0, -h), new Vector3(-h, 0, h), new Vector3(h, 0, h), new Vector3(h, 0, -h) };
        mesh.normals = new[] { Vector3.up, Vector3.up, Vector3.up, Vector3.up };
        mesh.uv = new[] { Vector2.zero, Vector2.up, Vector2.one, Vector2.right };
        mesh.triangles = new[] { 0, 1, 2, 0, 2, 3 };
        made.Add(mesh);
        groundMat = new Material(Resources.Load<Shader>("Shaders/TitleFx")) { renderQueue = (int)RenderQueue.Geometry };
        groundMat.EnableKeyword("TITLE_SOLID");
        groundMat.SetFloat("_SrcBlend", (float)BlendMode.One);
        groundMat.SetFloat("_DstBlend", (float)BlendMode.Zero);
        groundMat.SetFloat("_ZWrite", 1f);
        groundMat.SetVector("_SolidColor", SliceData.Hex(GROUND).linear);
        groundMat.SetVector("_SolidEmit", Color.black);
        made.Add(groundMat);
        var go = new GameObject("ground");
        go.transform.SetParent(root.transform, false);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var r = go.AddComponent<MeshRenderer>();
        r.sharedMaterial = groundMat;
        r.shadowCastingMode = ShadowCastingMode.Off;
    }

    // reveal_stage.gd _tower: a real city building of `floors` floors, TOWER_SIDE square, style 0, on the ground
    // at x; the city's tier for its height. A one-building sim carries it to CityDraw.
    void Tower(float x, long floors, S.GDict stats, S.GDict cfg, Shader lit, Tuning tuning)
    {
        var entry = new S.GDict();
        entry["x"] = (double)x;
        entry["z"] = 0.0;
        entry["w"] = (long)TOWER_SIDE;
        entry["d"] = (long)TOWER_SIDE;
        entry["h"] = floors;
        entry["tier"] = S.CityGen.TierForHeight(floors, S.Content.Section("city"));
        entry["style"] = 0L;
        var layout = new S.GArray<S.GDict>();
        layout.Append(entry);
        towerSim = new S.RampageSim(stats, cfg, layout, S.Seeds.Make("army", 0));
        S.RampageSim.Building b = towerSim.buildings[0];
        towerSim.buildings = new S.GArray<S.RampageSim.Building>();
        towerSim.buildings.Append(b);
        Mesh cube = SliceGame.CubeMesh(tuning.debris_size, false);
        made.Add(cube);
        debris = new Debris(tuning, Resources.Load<ComputeShader>("Shaders/Debris"), lit, cube, Vector3.zero);
        tower = new CityDraw(towerSim, lit, debris, root.transform);
    }

    // reveal_stage.gd build: fov 40, aimed at the middle of the pair, `back` further off and the aim moved
    // `shift` x the picture's width left (so the kaiju sits right of centre).
    void Camera(float towerX, float tallest, float back, float shift)
    {
        var go = new GameObject("reveal camera");
        go.transform.SetParent(root.transform, false);
        cam = go.AddComponent<Camera>();
        cam.fieldOfView = FOV;
        cam.nearClipPlane = CAMERA_NEAR;
        cam.farClipPlane = CAMERA_FAR;
        var hd = go.AddComponent<HDAdditionalCameraData>();
        hd.antialiasing = HDAdditionalCameraData.AntialiasingMode.None;
        hd.allowDynamicResolution = false;
        var aim = new Vector3(towerX * HALF, tallest * HALF, 0f);
        float dist = (tallest * TALL_BACK + PAD) * back;
        float wide = 2f * dist * Mathf.Tan(FOV * Mathf.Deg2Rad * HALF) * VIEW_MAX.x / VIEW_MAX.y;
        aim.x -= shift * wide;
        Vector3 eye = aim + new Vector3(0f, tallest * CAM_RISE * back, dist);
        go.transform.position = new Vector3(eye.x, eye.y, -eye.z);
        go.transform.LookAt(new Vector3(aim.x, aim.y, -aim.z));
        Fit();
    }

    // The picture is the frame's size in screen pixels (Godot's stretched SubViewport).
    void Fit()
    {
        Rect r = image.rectTransform.rect;
        Canvas canvas = image.canvas;
        float scale = canvas != null && canvas.scaleFactor > 0f ? canvas.scaleFactor : 1f;
        int w = Mathf.Max(1, Mathf.RoundToInt(r.width * scale)), h = Mathf.Max(1, Mathf.RoundToInt(r.height * scale));
        if (target != null && target.width == w && target.height == h) return;
        if (target != null)
        {
            target.Release();
            Destroy(target);
        }
        target = new RenderTexture(w, h, DEPTH_BITS, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        cam.targetTexture = target;
        image.texture = target;
    }

    // demo_end.gd _process: the clip roar (its sound with it, Sfx.roar).
    public void Roar()
    {
        if (croc == null || !croc.HasClip("roar")) return;
        croc.Roar();
        Sfx.Roar();
        Roars++;
    }

    void Update()
    {
        if (croc == null) return;
        Fit();
        if (RoarEvery > 0 && frame % RoarEvery == 0) Roar();
        frame++;
        float dt = Time.deltaTime;
        croc.Drive(Vector3.zero, Vector2.zero, bodyScale, dt);
        croc.yaw = KAIJU_TURN;
        croc.Draw();
        tower.Animate(dt);
    }

    void OnDestroy()
    {
        croc?.Dispose();
        tower?.Dispose();
        debris?.Dispose();
        towerSim?.Dispose();
        if (target != null) target.Release();
        if (target != null) Destroy(target);
        foreach (Object o in made) if (o != null) Destroy(o);
    }
}
