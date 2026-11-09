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
    const int AUTOPLAY_GLIDE_CYCLE = 90, AUTOPLAY_GLIDE_HELD = 50;
    const int STATS_EVERY = 60;
    const double TEST_BLAST_AHEAD = 8.0, TEST_BLAST_RADIUS = 5.0;
    // scenes/clip_feet.gd put_down: 0.2 + speed_k.
    const float FOOT_STRENGTH_BASE = 0.2f;
    const string HEAD_BONE = "head1";

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
    CityFx fx;
    // Capture only: every this many frames a bomb, a firework, a chem lab and a fuel silo go off by the kaiju.
    int blastEvery, blastsFired, blastWait;
    const string SPECIES = "reptilian";

    RunIntro intro;
    Vector2 crown;
    bool crownKnown;
    // scenes/kaiju_model.gd RISE_CLIP.
    const string RISE_CLIP = "rise_bay";
    EventFx eventFx;
    ArmyView army;
    CityTrees trees;
    CitySkyline skyline;
    IntroWater introWater;
    S.Vector2 walked;
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
        blastEvery = ArgInt(args, "-rampage-blasts", 0);
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

        S.GDict species = S.Content.SpeciesDef(SPECIES);
        S.GDict stats = S.UpgradeTree.RunStats(S.Content.Section("kaiju"), species, new S.UpgradeTree(S.Content.Upgrades(), Levels(stage), SPECIES));
        S.GArray<S.GDict> layout = S.CityGrowth.Layout(S.Content.Tuning(), stage, S.Seeds.Make("city", seed));
        S.Content.SetTime("dusk");
        sim = new S.RampageSim(stats, S.CityGrowth.ForStats(stats), layout, S.Seeds.Make("army", seed));

        Shader lit = Resources.Load<Shader>("Shaders/SliceLit");
        crocCube = SliceGame.CubeMesh(1f, true);
        croc = new Croc(tuning, slice, lit, crocCube, SliceData.F(look, "voxel_inset", 0.99f));
        // scenes/rampage.gd _take_sim: the species' attack and body first, since the rise is placed by the body's length.
        S.GDict ability = species["ability"];
        sim.abilityType = S.Gd.Str(ability["type"]);
        sim.body.UseSpecies(SPECIES);
        // Rises from the bay, D-270 (scenes/rampage.gd); before the city, which it prepares a way through.
        sim.emerge.Start(sim, croc.ClipSeconds(RISE_CLIP));
        intro = new RunIntro(sim, !auto);
        cubeMesh = SliceGame.CubeMesh(tuning.debris_size, false);
        debris = new Debris(tuning, Resources.Load<ComputeShader>("Shaders/Debris"), lit, cubeMesh, Vector3.zero);
        var root = new GameObject("city");
        city = new CityDraw(sim, lit, debris, root.transform);
        feetFrom = feetTo = Feet();
        croc.position = feetTo;
        croc.yaw = Mathf.Atan2(-Facing().x, -Facing().y);
        ground = new CityGround(sim.city, lit, root.transform);
        water = new WaterView(sim, ground.Sheets, Resources.Load<Shader>("Shaders/SliceWater"), Resources.Load<ComputeShader>("Shaders/OceanWaves"), sim.city, root.transform);
        Debug.Log($"rampage: ground {ground.SlabCount} slabs, {ground.VertexCount} verts; water {ground.Sheets.Count} sheets, {water.VertexCount} verts");
        BuildCamera();
        bubble = new CameraBubble(sim, city);
        FireTuning fireTuning = FireTuning.Load();
        var fires = new Fires(fireTuning, Resources.Load<Shader>("Shaders/Flame"), SliceGame.ExposureUnit(tuning), false);
        fx = new CityFx(Resources.Load<Shader>("Shaders/Burst"), fires, SliceData.F(look, "sun_energy", 1), SliceGame.ExposureUnit(tuning), fireTuning.light_match_m, seed);
        eventFx = new EventFx(sim, fx, seed);
        army = new ArmyView(sim, fx, lit, root.transform, seed);
        trees = new CityTrees(sim, fx, army, lit, root.transform, seed);
        skyline = new CitySkyline(sim.city, lit, root.transform, seed);
        Debug.Log($"skyline: {skyline.Boxes} boxes");
        walked = sim.kaijuPos;
        if (clipDir != null) BeginClip();
        Debug.Log($"rampage: stage {stage} seed {seed}, body scale {sim.BodyScale():F2}, kaiju at {sim.kaijuPos.x:F1},{sim.kaijuPos.y:F1}");
    }

    // Whatever the body walks over goes down on that frame (scenes/city_decor.gd, D-065).
    void Trample()
    {
        if (sim.kaijuPos != walked && !sim.airborne)
        {
            float bs = (float)sim.BodyScale();
            foreach (S.GArray<S.Variant> disc in sim.body.Discs())
            {
                float along = (float)(double)S.Num.F(disc[0]) * bs;
                var at = new Vector3((float)(double)sim.kaijuPos.x + (float)(double)sim.facing.x * along, 0f, (float)(double)sim.kaijuPos.y + (float)(double)sim.facing.y * along);
                trees.Crush(at, (float)(double)S.Num.F(disc[1]) * bs);
            }
        }
        walked = sim.kaijuPos;
        trees.Tick();
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
        cam.fieldOfView = follow.fov;
        if (sim.emerge.active)
        {
            var rest = new RunIntro.View { eye = eye, aim = aim, fov = follow.fov };
            RunIntro.View shot = intro.AboveWater(intro.Shot(Vector3.Lerp(feetFrom, feetTo, accumulator / TICK), rest, crown, croc.BoneAt(HEAD_BONE), accumulator / TICK));
            eye = shot.eye;
            aim = shot.aim;
            cam.fieldOfView = shot.fov;
        }
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
            if (double.IsInfinity((double)autoTarget.x) || sim.body.StompReaches(autoTarget)) return S.Vector2.ZERO;
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
        if (Input.anyKeyDown && !auto) intro.Skip();
        while (accumulator >= TICK && ran < MAX_STEPS)
        {
            accumulator -= TICK;
            ran++;
            feetFrom = feetTo;
            bool first = ran == 1;
            // One read a physics frame, however many ticks the intro runs on it (scenes/rampage.gd _step).
            S.Vector2 move = ReadMove();
            bool sign = signature && first, hold = held, ult = ultimate && first, br = breath && first, da = dash && first;
            if (auto)
            {
                sign = sim.abilityReadyIn <= 0.0;
                hold = steps % AUTOPLAY_GLIDE_CYCLE < AUTOPLAY_GLIDE_HELD;
                ult = true;
                br = sim.breathReadyIn <= 0.0;
            }
            long buttons = (da ? S.Dash.BUTTON : 0) | (hold ? S.RampageSim.HELD : 0) | (br ? S.RampageSim.BREATH : 0) | (ult ? S.RampageSim.ULTIMATE : 0);
            steps++;
            int ticks = intro.Ticks();
            for (int k = 0; k < ticks; k++)
            {
            if (k > 0 && !sim.emerge.active) break;
            S.GArray<S.GDict> events = sim.Step(TICK, move, sign, buttons);
            feetTo = Feet();
            foreach (S.GDict e in events)
            {
                city.OnEvent(e);
                eventFx.OnEvent(e, Feet());
                army.OnEvent(e, Feet());
                if (S.Gd.Str(e["type"]) == "stomp") trees.Crush(Feet(), (float)(double)S.Num.F(e["radius"]));
                string kind = S.Gd.Str(e["type"]);
                if (kind == "tail_sweep" || kind == "tail_auto") croc.StartSweep();
            }
            }
        }
        if (ran == MAX_STEPS) accumulator = 0f;
        if (blastEvery > 0 && !sim.emerge.active && ++blastWait >= blastEvery)
        {
            blastWait = 0;
            eventFx.OnEvent(TestBlast(blastsFired++), Feet());
        }
        simMs = (float)watch.Elapsed.TotalMilliseconds;
        if (statsPath != null && Time.frameCount % STATS_EVERY == 0)
            File.AppendAllText(statsPath, $"frame {Time.frameCount} dt {Time.unscaledDeltaTime * 1000f:F1} ms sim {simMs:F1} mesh {city.lastMeshMs:F1} regions {city.lastRegions} promoted {city.promoted} falling {city.Falling} alive {AliveBuildings()} debris {debris.Live} bursts {fx.LiveBursts} fires {fx.LiveFires} stomps {sim.body.stomps} trees {trees.Count} tanks {sim.tanks.Size()} helis {sim.air.helis.Size()} target {autoTarget.x:F1},{autoTarget.y:F1} reach {sim.body.StompReaches(autoTarget)} walking {sim.body.Walking()} steps {steps} feet {sim.kaijuPos.x:F1},{sim.kaijuPos.y:F1} y {sim.standY:F2} facing {sim.facing.x:F2},{sim.facing.y:F2} cam {cam.transform.position} gc {GC.GetTotalMemory(false) / (1 << 20)} MB\n");
        city.Animate(dt);
        city.Remesh();
        debris.Step(dt);
        debris.Draw();
        water.Step(dt);
        // The body between the last two ticks, so it moves every frame at any frame rate.
        Vector3 feet = Vector3.Lerp(feetFrom, feetTo, accumulator / TICK);
        float scale = (float)sim.BodyScale();
        if (sim.emerge.active && sim.emerge.Risen() < 1.0)
            croc.DriveClip(feet, Facing(), scale, RISE_CLIP, (float)(sim.emerge.Progress() * sim.emerge.Total()) + accumulator);
        else
            croc.Drive(feet, Facing(), scale, dt);
        if (!crownKnown)
        {
            crownKnown = true;
            crown = croc.RestCrown(HEAD_BONE, scale);
            introWater = new IntroWater(sim, fx, Resources.Load<Shader>("Shaders/Bolt"), crown.x);
        }
        croc.Draw();
        fx.Tick(age, dt);
        eventFx.Step(dt);
        introWater.Step(dt);
        army.Update(dt, Feet());
        Trample();
        if (croc.TakeFootfall(out string side, out Vector3 footAt))
            eventFx.Footfall(side, Mathf.Clamp01(FOOT_STRENGTH_BASE + croc.SpeedShare), footAt);
        follow.Step(feet, Facing(), feet, scale, sim.body.dash.On() || sim.emerge.active, dt);
        PlaceCamera(scale);
        bubble.Step(cam, feet, dt);
        fx.SetFocus(Vector3.Dot(new Vector3(feet.x, feet.y, -feet.z) - cam.transform.position, cam.transform.forward));
        fx.Draw(age);
        if (quitAfter > 0f && age >= quitAfter) Application.Quit();
    }

    int AliveBuildings()
    {
        int n = 0;
        for (int i = 0; i < sim.buildings.Size(); i++) if (sim.buildings[i].frame.aliveCount > 0) n++;
        return n;
    }

    S.GDict TestBlast(int n)
    {
        S.Vector2 ahead = sim.kaijuPos + sim.facing * (double)(TEST_BLAST_AHEAD * sim.BodyScale());
        var e = new S.GDict();
        e["x"] = (double)ahead.x;
        e["z"] = (double)ahead.y;
        e["radius"] = TEST_BLAST_RADIUS;
        string[] kinds = { "airstrike_bomb", "firework_burst", "explosion", "explosion" };
        e["type"] = kinds[n % kinds.Length];
        if (n % kinds.Length < 2) return e;
        int building = 0;
        double best = double.MaxValue;
        for (int i = 0; i < sim.buildings.Size(); i++)
        {
            S.RampageSim.Building b = sim.buildings[i];
            double far = (b.x - ahead.x) * (b.x - ahead.x) + (b.z - ahead.y) * (b.z - ahead.y);
            if (b.frame.aliveCount > 0 && far < best) { best = far; building = i; }
        }
        e["building"] = (long)building;
        e["kind"] = n % kinds.Length == 2 ? "chem_lab" : "fuel_silo";
        return e;
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
        fx?.Dispose();
        if (cubeMesh != null) Destroy(cubeMesh);
        if (profile != null) Destroy(profile);
        if (clipTarget != null) Destroy(clipTarget);
        if (clipImage != null) Destroy(clipImage);
    }
}
