using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.SceneManagement;
using S = Kaiju.Sim;

// One rampage: a live RampageSim at its fixed tick; everything on screen reads it. Input goes in, events
// come out, and the views draw them (hard rule 3). scenes/rampage.gd's shape, built new (D-474).
public sealed class RampageGame : MonoBehaviour
{
    // The sim's tick: Godot's physics rate, what every replay and balance number runs at.
    const float TICK = 1f / 60f;
    const int MAX_STEPS = 4;
    const int WIDTH = 1920, HEIGHT = 1080;
    // scenes/run_input.gd autoplay: re-aim every 15 steps; the signature's duty cycle.
    const int AUTO_AIM_EVERY = 15;
    // No emerge intro yet: autoplay walks before its first signature, or the first frame is the blast.
    const float AUTO_SIGNATURE_AFTER = 5f;
    const int AUTOPLAY_GLIDE_CYCLE = 90, AUTOPLAY_GLIDE_HELD = 50;
    const int STATS_EVERY = 60;

    S.RampageSim sim;
    CityDraw city;
    Croc croc;
    CameraBubble bubble;
    Debris debris;
    Camera cam;
    FollowCam follow;
    Tuning tuning;
    VolumeProfile profile;
    Mesh cubeMesh, crocCube;
    CityGround ground;
    WaterView water;
    Vector3 feetFrom, feetTo;
    float accumulator, age, simMs;
    int steps;
    bool auto;
    S.Vector2 autoTarget;
    bool hasAutoTarget;
    string error;
    GUIStyle hud;
    float smoothDt = TICK;

    string clipDir;
    int clipFrames, clipFrame, clipSkip;
    RenderTexture clipTarget;
    Texture2D clipImage;
    string statsPath;
    float quitAfter;
    float[] fixedEye;  // capture only: eye and aim, Godot axes (x,y,z,x,y,z)

    static string Arg(string[] args, string name)
    {
        int i = Array.IndexOf(args, name);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }

    static int ArgInt(string[] args, string name, int fallback)
    {
        string v = Arg(args, name);
        return v != null ? int.Parse(v, System.Globalization.CultureInfo.InvariantCulture) : fallback;
    }

    void Awake()
    {
        Application.targetFrameRate = -1;
        QualitySettings.vSyncCount = 0;
        string[] args = Environment.GetCommandLineArgs();
        auto = args.Contains("-rampage-auto");
        clipDir = Arg(args, "-rampage-clip");
        clipFrames = ArgInt(args, "-rampage-frames", 300);
        clipSkip = ArgInt(args, "-rampage-skip", 0);
        statsPath = Arg(args, "-rampage-stats");
        quitAfter = ArgInt(args, "-rampage-seconds", 0);
        string eye = Arg(args, "-rampage-eye");
        if (eye != null) fixedEye = eye.Split(',').Select(v => float.Parse(v, System.Globalization.CultureInfo.InvariantCulture)).ToArray();
        try
        {
            Load(ArgInt(args, "-rampage-stage", 3), ArgInt(args, "-rampage-seed", 0));
        }
        catch (Exception e)
        {
            error = e.ToString();
            Debug.LogException(e);
        }
    }

    static string DataRoot()
    {
        string bundled = Path.Combine(Application.streamingAssetsPath, "res");
        return Directory.Exists(Path.Combine(bundled, "data")) ? bundled : Path.GetFullPath(Path.Combine(Application.dataPath, "..", ".."));
    }

    // tools/capture/capture_kit.gd STAGE_LEVELS: the upgrades that reach each stage, for a run started here.
    static S.GDict Levels(int stage)
    {
        var d = new S.GDict();
        if (stage == 1)
        {
            d["claws"] = 2;
            d["hide"] = 2;
            return d;
        }
        d["claws"] = 5;
        d["hide"] = 5;
        d["rage"] = stage == 2 ? 3 : 5;
        d["evolve1"] = 1;
        if (stage >= 3)
        {
            d["tail"] = 3;
            d["sig_power"] = 3;
            d["evolve2"] = 1;
        }
        return d;
    }

    void Load(int stage, int seed)
    {
        S.FileAccess.Root = DataRoot();
        tuning = SliceData.LoadTuning();
        var slice = SliceData.LoadJson("slice.json");
        var look = MiniJson.Obj(slice["look"]);
        profile = SliceGame.ApplyLook(tuning, slice, look);

        S.GDict stats = S.UpgradeTree.RunStats(S.Content.Section("kaiju"), S.Content.SpeciesDef("reptilian"), new S.UpgradeTree(S.Content.Upgrades(), Levels(stage)));
        S.GArray<S.GDict> layout = S.CityGrowth.Layout(S.Content.Tuning(), stage, S.Seeds.Make("city", seed));
        S.Content.SetTime("dusk");
        sim = new S.RampageSim(stats, S.CityGrowth.ForStats(stats), layout, S.Seeds.Make("army", seed));

        Shader lit = Resources.Load<Shader>("Shaders/SliceLit");
        cubeMesh = SliceGame.CubeMesh(tuning.debris_size, false);
        var centre = new Vector3((float)(double)sim.kaijuPos.x, 0, -(float)(double)sim.kaijuPos.y);
        debris = new Debris(tuning, Resources.Load<ComputeShader>("Shaders/Debris"), lit, cubeMesh, centre);
        var root = new GameObject("city");
        city = new CityDraw(sim, lit, debris, root.transform);
        crocCube = SliceGame.CubeMesh(1f, true);
        croc = new Croc(tuning, slice, lit, crocCube, SliceData.F(look, "voxel_inset", 0.99f));
        feetFrom = feetTo = Feet();
        croc.position = feetTo;
        croc.yaw = Mathf.Atan2(-Facing().x, -Facing().y);
        ground = new CityGround(sim.city, lit, root.transform);
        water = new WaterView(sim, ground.Sheets, Resources.Load<Shader>("Shaders/SliceWater"), Resources.Load<ComputeShader>("Shaders/OceanWaves"), sim.city, root.transform);
        Debug.Log($"rampage: ground {ground.SlabCount} slabs, {ground.VertexCount} verts; water {ground.Sheets.Count} sheets, {water.VertexCount} verts");
        BuildCamera();
        bubble = new CameraBubble(sim, city);
        if (clipDir != null) BeginClip();
        Debug.Log($"rampage: stage {stage} seed {seed}, body scale {sim.BodyScale():F2}, kaiju at {sim.kaijuPos.x:F1},{sim.kaijuPos.y:F1}");
    }

    Vector3 Feet() => new Vector3((float)(double)sim.kaijuPos.x, (float)(double)sim.standY, (float)(double)sim.kaijuPos.y);

    void BuildCamera()
    {
        float scale = (float)sim.BodyScale();
        follow = new FollowCam(Feet(), scale);
        var go = new GameObject("camera");
        cam = go.AddComponent<Camera>();
        cam.fieldOfView = follow.fov;
        cam.nearClipPlane = 0.5f;
        cam.farClipPlane = 3000;
        HDAdditionalCameraData data = go.AddComponent<HDAdditionalCameraData>();
        data.antialiasing = HDAdditionalCameraData.AntialiasingMode.SubpixelMorphologicalAntiAliasing;
        follow.Step(Feet(), Facing(), Feet(), scale, false, TICK);
        PlaceCamera(scale);
    }

    Vector2 Facing() => new Vector2((float)(double)sim.facing.x, (float)(double)sim.facing.y);

    void PlaceCamera(float scale)
    {
        if (fixedEye != null)
        {
            cam.transform.position = new Vector3(fixedEye[0], fixedEye[1], -fixedEye[2]);
            cam.transform.LookAt(new Vector3(fixedEye[3], fixedEye[4], -fixedEye[5]));
            return;
        }
        Vector3 eye = follow.Eye(), aim = follow.LookAt(scale);
        cam.transform.position = new Vector3(eye.x, eye.y, -eye.z);
        cam.transform.LookAt(new Vector3(aim.x, aim.y, -aim.z));
    }

    // The stick is the camera's: up walks where the camera looks (scenes/run_input.gd).
    S.Vector2 ReadMove()
    {
        if (auto)
        {
            if (steps % AUTO_AIM_EVERY == 0 || !hasAutoTarget)
            {
                autoTarget = sim.NearestStanding(sim.kaijuPos);
                hasAutoTarget = true;
            }
            if (double.IsInfinity((double)autoTarget.x) || autoTarget == sim.kaijuPos) return S.Vector2.ZERO;
            return (autoTarget - sim.kaijuPos).Normalized();
        }
        float x = (Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0);
        float y = (Input.GetKey(KeyCode.S) ? 1 : 0) - (Input.GetKey(KeyCode.W) ? 1 : 0);
        var m = new Vector2(x, y);
        if (m.sqrMagnitude > 1) m.Normalize();
        float a = -follow.Yaw;
        float s = Mathf.Sin(a), c = Mathf.Cos(a);
        return new S.Vector2(m.x * c - m.y * s, m.x * s + m.y * c);
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Escape)) { Application.Quit(); return; }
        if (error != null) return;
        if (Input.GetKeyDown(KeyCode.R)) { SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex); return; }
        float dt = Time.deltaTime;
        age += dt;
        smoothDt = Mathf.Lerp(smoothDt, Time.unscaledDeltaTime, 0.05f);
        accumulator += dt;
        var watch = System.Diagnostics.Stopwatch.StartNew();
        int ran = 0;
        bool signature = Input.GetKeyDown(KeyCode.Space) || Input.GetMouseButtonDown(0);
        bool held = Input.GetKey(KeyCode.Space) || Input.GetMouseButton(0);
        bool ultimate = Input.GetKeyDown(KeyCode.Q), breath = Input.GetKeyDown(KeyCode.E), dash = Input.GetKeyDown(KeyCode.LeftShift);
        while (accumulator >= TICK && ran < MAX_STEPS)
        {
            accumulator -= TICK;
            ran++;
            steps++;
            feetFrom = feetTo;
            bool first = ran == 1;
            bool sign = signature && first, hold = held, ult = ultimate && first, br = breath && first, da = dash && first;
            if (auto && age > AUTO_SIGNATURE_AFTER)
            {
                sign = sim.abilityReadyIn <= 0.0;
                hold = steps % AUTOPLAY_GLIDE_CYCLE < AUTOPLAY_GLIDE_HELD;
                ult = true;
                br = sim.breathReadyIn <= 0.0;
            }
            long buttons = (da ? S.Dash.BUTTON : 0) | (hold ? S.RampageSim.HELD : 0) | (br ? S.RampageSim.BREATH : 0) | (ult ? S.RampageSim.ULTIMATE : 0);
            S.GArray<S.GDict> events = sim.Step(TICK, ReadMove(), sign, buttons);
            feetTo = Feet();
            foreach (S.GDict e in events)
            {
                city.OnEvent(e);
                string kind = S.Gd.Str(e["type"]);
                if (kind == "tail_sweep" || kind == "tail_auto") croc.StartSweep();
            }
        }
        if (ran == MAX_STEPS) accumulator = 0f;
        simMs = (float)watch.Elapsed.TotalMilliseconds;
        if (statsPath != null && Time.frameCount % STATS_EVERY == 0)
            File.AppendAllText(statsPath, $"frame {Time.frameCount} dt {Time.unscaledDeltaTime * 1000f:F1} ms sim {simMs:F1} mesh {city.lastMeshMs:F1} regions {city.lastRegions} promoted {city.promoted} falling {city.Falling} debris {debris.Live} feet {sim.kaijuPos.x:F1},{sim.kaijuPos.y:F1} y {sim.standY:F2} facing {sim.facing.x:F2},{sim.facing.y:F2} cam {cam.transform.position} gc {GC.GetTotalMemory(false) / (1 << 20)} MB\n");
        city.Animate(dt);
        city.Remesh();
        debris.Step(dt);
        debris.Draw();
        water.Step(dt);
        // The body between the last two ticks, so it moves every frame at any frame rate.
        Vector3 feet = Vector3.Lerp(feetFrom, feetTo, accumulator / TICK);
        float scale = (float)sim.BodyScale();
        croc.Drive(feet, Facing(), scale, dt);
        croc.Draw();
        follow.Step(feet, Facing(), feet, scale, sim.body.dash.On(), dt);
        PlaceCamera(scale);
        bubble.Step(cam, feet, dt);
        if (quitAfter > 0f && age >= quitAfter) Application.Quit();
    }

    void BeginClip()
    {
        Directory.CreateDirectory(clipDir);
        clipTarget = new RenderTexture(WIDTH, HEIGHT, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        clipImage = new Texture2D(WIDTH, HEIGHT, TextureFormat.RGB24, false);
        Time.captureFramerate = 30;
    }

    void LateUpdate()
    {
        if (clipDir == null || error != null || clipTarget == null) return;
        if (clipSkip > 0) { clipSkip--; return; }
        cam.targetTexture = clipTarget;
        cam.Render();
        RenderTexture.active = clipTarget;
        clipImage.ReadPixels(new Rect(0, 0, WIDTH, HEIGHT), 0, 0);
        clipImage.Apply();
        RenderTexture.active = null;
        cam.targetTexture = null;
        File.WriteAllBytes(Path.Combine(clipDir, $"f{clipFrame:D4}.png"), clipImage.EncodeToPNG());
        clipFrame++;
        if (clipFrame < clipFrames) return;
        Debug.Log($"rampage: clip done, {clipFrames} frames, promoted {city.promoted}, debris {debris.Spawned}");
        Application.Quit();
    }

    void OnGUI()
    {
        if (clipDir != null) return;
        if (hud == null) hud = new GUIStyle(GUI.skin.label) { fontSize = 16, normal = { textColor = Color.white } };
        if (error != null) { GUI.Label(new Rect(10, 10, Screen.width - 20, Screen.height - 20), error, hud); return; }
        string text = $"{1f / smoothDt:F0} fps  sim {simMs:F1} ms  mesh {city.lastMeshMs:F1} ms ({city.lastRegions})\npromoted {city.promoted}  falling {city.Falling}  debris {debris.Live:N0}\nWASD walk  Space signature (hold)  Q ultimate  E breath  Shift dash  R restart  Esc quit";
        GUI.Label(new Rect(10, 10, 620, 80), text, hud);
    }

    void OnDestroy()
    {
        city?.Dispose();
        debris?.Dispose();
        croc?.Dispose();
        if (crocCube != null) Destroy(crocCube);
        ground?.Dispose();
        water?.Dispose();
        if (cubeMesh != null) Destroy(cubeMesh);
        if (profile != null) Destroy(profile);
        if (clipTarget != null) Destroy(clipTarget);
        if (clipImage != null) Destroy(clipImage);
    }
}
