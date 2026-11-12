using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.SceneManagement;
using S = Kaiju.Sim;
using Kaiju.Game;

// One rampage: a live RampageSim at its fixed tick; everything on screen reads it. Input goes in, events
// come out, and the views draw them (hard rule 3). scenes/rampage.gd's shape, built new (D-474).
public sealed partial class RampageGame : MonoBehaviour
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

    // The run the game flow starts (GameFlow sets it before the scene loads); null: the -rampage-* flags, as captures do.
    public static RunRequest Request;
    // Hosted only (GameFlow -flow-smoke): the auto input and a clock run out at this age, without the
    // -rampage-* flags, which would make the run a standalone one.
    public static bool HostAuto;
    public static int HostTimeUp;
    // Raised once when the sim is over, with the result (sim.Result() and the street's counts, as rampage_hud.gd result()).
    // With the HUD up, that is when its end beat is done (rampage.gd: _hud.beat_done.connect(finished.emit)).
    public Action<S.GDict> Finished;
    // Raised every frame after the sim stepped, with the frame's seconds (0 while paused): the HUD reads the sim then.
    public event Action<float> Ticked;
    // Hosted only: the player pressed pause (Esc) in a run that can pause; the host shows its menu and sets Paused.
    public Action PauseRequested;
    // Stops the sim, its clock and every view's time; Time.timeScale is left alone. Captures never set it.
    public bool Paused;
    public bool Hosted => request != null;
    // The run the host asked for (null alone): what the sound seeds itself from after the host let go of Request.
    public RunRequest Run => request;
    public bool Over => over;
    // The result the run ended with; null until it is over.
    public S.GDict Result { get; private set; }
    public S.RampageSim Sim => sim;
    public StreetPeople People => street?.people;
    public string Error => error;
    // The run's species row (data/species.json), for the HUD's colours.
    public S.GDict Species { get; private set; }
    public float ExposureUnit => SliceGame.ExposureUnit(tuning);
    // Photo mode (Game/PhotoMode.cs, D-259): set while it flies the camera; the run then neither places its camera
    // nor ticks the HUD (so the breath's aim wedge goes) nor draws the VIP headline.
    public PhotoMode Photo;
    public Camera GameCamera => cam;
    // The kaiju's feet in Unity's axes (photo mode's centre; rampage.gd _kaiju_at).
    public Vector3 KaijuAt { get { Vector3 f = Feet(); return new Vector3(f.x, f.y, -f.z); } }

    RunRequest request;
    bool over;
    // The game's HUD: hosted, or alone with -rampage-hud; never in a clip or a dry run.
    bool hudFlag, audioFlag;
    Hud hudView;
    // The rampage's sound: hosted, or alone with -rampage-audio; never in a clip or a dry run.
    RampageAudio audio;
    // scenes/run_input.gd: a tap made while he rises is kept for the first live tick; the held move as hold or toggle.
    HudLatch latch;
    readonly HudHeld heldButton = new HudHeld();
    readonly Dictionary<string, bool> taps = new Dictionary<string, bool>();
    S.RampageSim sim;
    CityDraw city;
    Croc croc;
    CameraBubble bubble;
    Debris debris;
    RubbleView rubble;
    float rubblePress, rubbleKeep;
    Camera cam;
    FollowCam follow;
    CameraShake shake;
    readonly List<Vector4> bodySpheres = new List<Vector4>();
    float stepDip;
    // scenes/rampage.gd: how far a footfall dips the camera and how it recovers.
    const float FOOTFALL_DIP = 0.35f, FOOTFALL_DIP_FLOOR = 1f, DIP_RECOVER = 4f, DIP_CREEP = 0.05f;
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
    bool KeyedRise() => sim.emerge.active && sim.emerge.Risen() < 1.0 && croc.HasClip(RISE_CLIP); // rampage_rise.gd rise: else it walks
    EventFx eventFx;
    ArmyView army;
    RooftopView rooftops;
    VipView vip;
    CityTrees trees;
    StreetView street;
    CitySkyline skyline;
    IntroWater introWater;
    BreathView breath;
    ThunderView thunder;
    LeapView leap;
    SlamView slam;
    // Capture only: autoplay presses the leap every this many steps (0: never).
    int leapEvery;
    AirstrikeView strike;
    Aircraft aircraft;
    // Dry run only (-rampage-timeup seconds): the clock is run out then, as tools/capture/capture_death.gd does.
    int timeUpAt;
    bool timeUpDone;
    PostFxView postFx;
    // The run's weather look (scenes/weather_view.gd); null when the weather has no layer (clear).
    WeatherView weather;
    RailView rail;
    // Capture only (-rampage-derail step): the first running train is derailed at that sim step.
    int derailAt;
    bool derailDone;
    const float TAIL_AUTO_CRUSH = 0.5f;
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
    string ownExtra;
    int clipFrames, clipFrame, clipSkip;
    RenderTexture clipTarget;
    Texture2D clipImage;
    string statsPath;
    float quitAfter;
    float[] fixedEye;  // capture only: eye and aim, Godot axes (x,y,z,x,y,z)
    string scoutPath;  // capture only: dry run, see CaptureScout
    CaptureScout scout;

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
        request = Request;
        auto = args.Contains("-rampage-auto") || (request != null && HostAuto);
        hudFlag = args.Contains("-rampage-hud");
        audioFlag = args.Contains("-rampage-audio");
        clipDir = Arg(args, "-rampage-clip");
        ownExtra = Arg(args, "-rampage-own");
        scoutPath = Arg(args, "-rampage-scout");
        clipFrames = ArgInt(args, "-rampage-frames", 300);
        clipSkip = ArgInt(args, "-rampage-skip", 0);
        blastEvery = ArgInt(args, "-rampage-blasts", 0);
        leapEvery = ArgInt(args, "-rampage-leap", 0);
        statsPath = Arg(args, "-rampage-stats");
        quitAfter = ArgInt(args, "-rampage-seconds", 0);
        timeUpAt = request != null && HostTimeUp > 0 ? HostTimeUp : ArgInt(args, "-rampage-timeup", 0);
        derailAt = ArgInt(args, "-rampage-derail", 0);
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
    // ownExtra (-rampage-own id): one more upgrade owned, to film a power the stage's build leaves out.
    S.GDict Levels(int stage)
    {
        var d = new S.GDict();
        if (ownExtra != null) d[ownExtra] = 1;
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
        profile = GraphicsView.StartRun(SliceGame.ApplyLook(tuning, slice, look), SliceGame.Sun);  // counts frozen for this run

        // A hosted run is the save's: its species, stats and city (scenes/main.gd, globe_missions.gd); else the flags'.
        string speciesId = request != null ? S.Gd.Str(S.Content.SpeciesDef(request.species)["id"]) : SPECIES;
        S.GDict species = S.Content.SpeciesDef(speciesId);
        Species = species;
        S.GDict stats;
        S.GArray<S.GDict> layout;
        if (request != null)
        {
            // Rampage.setup_later seeds the army and the views by the run number.
            seed = request.runIndex;
            stats = RunStart.Stats(request);
            S.Content.SetTime(request.time != "" ? request.time : "dusk");
            if (request.weather != "") S.Content.SetWeather(request.weather);
            layout = RunStart.Layout(request);
        }
        else
        {
            stats = S.UpgradeTree.RunStats(S.Content.Section("kaiju"), species, new S.UpgradeTree(S.Content.Upgrades(), Levels(stage), SPECIES));
            layout = S.CityGrowth.Layout(S.Content.Tuning(), stage, S.Seeds.Make("city", seed));
            S.Content.SetTime("dusk");
            // Capture/dry-run only: -rampage-weather <id> plays that weather (data/looks.json weather order); time stays dusk.
            string weatherArg = Arg(Environment.GetCommandLineArgs(), "-rampage-weather");
            if (weatherArg != null) S.Content.SetWeather(weatherArg);
        }
        sim =new S.RampageSim(stats, S.CityGrowth.ForStats(stats), layout, S.Seeds.Make("army", seed));

        Shader lit = Resources.Load<Shader>("Shaders/SliceLit");
        crocCube = SliceGame.CubeMesh(1f, true);
        croc = new Croc(tuning, slice, lit, crocCube, SliceData.F(look, "voxel_inset", 0.99f), Croc.BodyStage(sim.SizeTier()));
        // scenes/rampage.gd _take_sim: the species' attack and body first, since the rise is placed by the body's length.
        S.GDict ability = species["ability"];
        sim.abilityType = S.Gd.Str(ability["type"]);
        if (request != null)
        {
            sim.armyUnits.taskforce.carried = request.citySeconds;  // rampage time in this city so far (D-160)
            if (request.endless) sim.endless = new S.Endless();  // the demo's Endless mode (D-156)
        }
        sim.body.UseSpecies(speciesId);
        // Rises from the bay, D-270 (scenes/rampage.gd); before the city, which it prepares a way through.
        sim.emerge.Start(sim, croc.ClipSeconds(RISE_CLIP));
        intro = new RunIntro(sim, request != null ? request.fullIntro : !auto);
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
        var fires = new Fires(fireTuning, Resources.Load<Shader>("Shaders/Flame"), SliceGame.ExposureUnit(tuning), false, new LightPool());
        fx = new CityFx(Resources.Load<Shader>("Shaders/Burst"), fires, SliceData.F(look, "sun_energy", 1), SliceGame.ExposureUnit(tuning), fireTuning.light_match_m, seed);
        eventFx = new EventFx(sim, fx, seed);
        // The rubble look: heaps and strips laid on the debris field, the crumble's dust, the landing puff's
        // place, and the foot's press (data/tuning.json street.rubble_press, rubble_keep; D-245).
        rubble = new RubbleView(sim, tuning, city, debris);
        city.crumbleFx = fx;
        eventFx.City = city;
        rubblePress = (float)S.Num.F(S.Content.Section("street")["rubble_press"]);
        rubbleKeep = (float)S.Num.F(S.Content.Section("street")["rubble_keep"]);
        army = new ArmyView(sim, fx, lit, root.transform, seed);
        vip = new VipView(sim, army, SliceGame.ExposureUnit(tuning), fireTuning.light_match_m);
        trees = new CityTrees(sim, fx, army, lit, root.transform, seed);
        street = new StreetView(sim, fx, lit, root.transform, SliceGame.ExposureUnit(tuning), fireTuning.light_match_m, seed);
        Debug.Log($"street: {street.people.Civilians()} people ({street.people.beachPeople} on the beach), {street.Props} props");
        rail = new RailView(sim, fx, army, lit, root.transform, WreckKick);
        skyline = new CitySkyline(sim.city, lit, root.transform, seed);
        Debug.Log($"skyline: {skyline.Boxes} boxes");
        strike = new AirstrikeView(sim, lit, root.transform);
        aircraft = new Aircraft(tuning, lit, root.transform, seed);
        breath = new BreathView(sim, fx, croc, trees, seed, SliceGame.ExposureUnit(tuning), fireTuning.light_match_m);
        thunder = new ThunderView(sim, fx, croc, seed, SliceGame.ExposureUnit(tuning), fireTuning.light_match_m, BoltKick);
        breath.Stroked = BoltKick;
        rooftops = new RooftopView(sim, fx, croc, lit, seed);
        leap = new LeapView(sim, croc, trees);
        slam = new SlamView(sim, city, fx, shake, croc, tuning);
        postFx = new PostFxView(sim, profile);
        weather = WeatherView.Attach(profile, Resources.Load<Shader>("Shaders/Rain"), fireTuning.wind, SliceGame.ExposureUnit(tuning));
        walked = sim.kaijuPos;
        if (clipDir != null) BeginClip();
        if (scoutPath != null)
        {
            scout = new CaptureScout(scoutPath, clipFrames, sim, croc, WIDTH, HEIGHT);
            Time.captureFramerate = 30;
        }
        if (request == null)
            Debug.Log($"rampage: stage {stage} seed {seed}, body {croc.Stage}, body scale {sim.BodyScale():F2}, kaiju at {sim.kaijuPos.x:F1},{sim.kaijuPos.y:F1}");
        else
            Debug.Log(FormattableString.Invariant($"rampage: request species={speciesId} tier={request.tier} seed={request.seed} run={request.runIndex} continent={(request.continent != "" ? request.continent : "none")} time={S.Content._timeId} weather={S.Content.WeatherId()} endless={request.endless} full_intro={request.fullIntro} city_seconds={request.citySeconds:F1} buildings={sim.buildings.Size()} run_seconds={sim.timeLeft:F1} body={croc.Stage} body_scale={sim.BodyScale():F2}"));
        // Only the croc is drawn so far: another species plays its own sim under the croc's body.
        if (speciesId != SPECIES) Debug.LogWarning($"rampage: species {speciesId} has no Unity body yet; the croc is drawn");
        latch = new HudLatch(S.Num.F(S.Content.Section("emerge")["input_latch_seconds"]));
        if ((Hosted || hudFlag) && clipDir == null && scoutPath == null) hudView = Hud.Attach(this);
        if ((Hosted || audioFlag) && clipDir == null && scoutPath == null) audio = RampageAudio.Attach(this);
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
                street.Trample(at, (float)(double)S.Num.F(disc[1]) * bs);
            }
        }
        walked = sim.kaijuPos;
        trees.Tick();
    }

    // scenes/rampage_ability.gd: the body rides the leap's arc and sinks through its settle (Dash.height).
    Vector3 Feet() => new Vector3((float)(double)sim.kaijuPos.x, (float)(double)sim.standY + (sim.body.dash.On() ? (float)sim.body.dash.Height() : 0f), (float)(double)sim.kaijuPos.y);

    // The feet on the street, whatever the leap lifts the body to.
    Vector3 Street() => new Vector3((float)(double)sim.kaijuPos.x, (float)(double)sim.standY, (float)(double)sim.kaijuPos.y);

    void BuildCamera()
    {
        float scale = (float)sim.BodyScale();
        follow = new FollowCam(Feet(), scale);
        shake = new CameraShake();
        var go = new GameObject("camera");
        cam = go.AddComponent<Camera>();
        cam.fieldOfView = follow.fov;
        cam.nearClipPlane = 0.5f;
        cam.farClipPlane = 3000;
        GraphicsView.UseCamera(go.AddComponent<HDAdditionalCameraData>());
        follow.Step(Feet(), Facing(), Feet(), scale, false, 0f, 0f, TICK);
        PlaceCamera(scale);
    }

    // KaijuModel.focus: the body as drawn, its root bone over the feet.
    Vector3 Focus(Vector3 feet)
    {
        Vector3 root = croc.BoneAt(croc.RootBone);
        return new Vector3(root.x, feet.y, root.z);
    }

    Vector2 Facing() => new Vector2((float)(double)sim.facing.x, (float)(double)sim.facing.y);

    void PlaceCamera(float scale, float dt = 0f)
    {
        if (fixedEye != null)
        {
            cam.transform.position = new Vector3(fixedEye[0], fixedEye[1], -fixedEye[2]);
            cam.transform.LookAt(new Vector3(fixedEye[3], fixedEye[4], -fixedEye[5]));
            return;
        }
        Vector3 eye = follow.Eye(), aim = follow.LookAt(scale);
        if (dt > 0f)
        {
            croc.BodySpheres(bodySpheres);
            aim = follow.Aim(eye, aim, follow.fov, shake.Turn(scale).y, bodySpheres, dt);
        }
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
        shake.Apply(cam.transform, scale);
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
        Vector2 m = pressed.stick;
        if (m.sqrMagnitude > 1) m.Normalize();
        float a = -follow.Yaw;
        float s = Mathf.Sin(a), c = Mathf.Cos(a);
        return new S.Vector2(m.x * c - m.y * s, m.x * s + m.y * c);
    }

    // This frame's presses. stick: x right, y down the screen (S is +1), before the camera turns it.
    struct Presses
    {
        public Vector2 stick;
        public bool signature, held, ultimate, breath, dash, pause, restart, any;
    }

    Presses pressed;

    // INPUT SEAM: the only place the rampage reads its input. Hosted, the player's bindings and the pad (Inputs,
    // as scenes/run_input.gd reads its actions); alone, the fixed keys the captures and dry runs were made with.
    Presses ReadPresses()
    {
        var p = new Presses();
        if (Hosted)
        {
            Inputs.Poll();
            Vector2 m = Inputs.Move();
            p.stick = new Vector2(m.x, -m.y);
            p.signature = Inputs.Down("signature");
            // Not while paused: run_input.gd reads it in _physics_process, which a paused tree skips, and the
            // menu's confirm (Space / pad A) is the signature key, so a menu press must not flip the toggle latch.
            if (!Paused) p.held = heldButton.Read(Inputs.Held("signature"), p.signature, PlayerSettings.HoldToggle);
            p.breath = Inputs.Down("breath");
            p.ultimate = Inputs.Down("ultimate");
            p.dash = Inputs.Down("dash");
            p.pause = Inputs.Down("pause");
            p.any = Inputs.AnyDown();
            return p;
        }
        p.stick = new Vector2((Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0), (Input.GetKey(KeyCode.S) ? 1 : 0) - (Input.GetKey(KeyCode.W) ? 1 : 0));
        p.signature = Input.GetKeyDown(KeyCode.Space) || Input.GetMouseButtonDown(0);
        p.held = Input.GetKey(KeyCode.Space) || Input.GetMouseButton(0);
        p.breath = Input.GetKeyDown(KeyCode.Q);
        p.ultimate = Input.GetKeyDown(KeyCode.E);
        p.dash = Input.GetKeyDown(KeyCode.LeftShift);
        p.pause = Input.GetKeyDown(KeyCode.Escape);
        p.restart = Input.GetKeyDown(KeyCode.R);
        p.any = Input.anyKeyDown;
        return p;
    }

    // What the run did: the sim's result and what only the view counts, the civilians crushed (the tanks' run-overs
    // too, as street_life.gd civilians_killed; shell kills are counted apart) and those who fled
    // (scenes/rampage_hud.gd result(), hud_counts.gd). Read after run_over: the death pays biomass too.
    public S.GDict ResultNow()
    {
        S.GDict result = sim.Result();
        result.Merge(new S.GDict { { "civilians", (long)street.CiviliansKilled }, { "fled", (long)street.people.fled } });
        return result;
    }

    // The sim ended (its run_over): the result is read once and the host told. Alone, only an unattended run with
    // no end of its own quits here: -rampage-seconds, a clip and a dry run end themselves, and a run played by
    // hand stays up for R.
    void EndRun()
    {
        over = true;
        Result = ResultNow();
        Debug.Log(FormattableString.Invariant($"rampage: over reason={sim.endReason} biomass={S.Num.I(Result["rubble"])} destruction={S.Num.F(Result["destruction"]):F3} buildings={S.Num.I(Result["buildings"])} seconds={S.Num.F(Result["seconds"]):F1} city_seconds={S.Num.F(Result["city_seconds"]):F1} civilians={S.Num.I(Result["civilians"])} fled={S.Num.I(Result["fled"])} step={steps} frame={Time.frameCount}"));
        if (hudView != null)
        {
            hudView.BeatDone = r => Finished?.Invoke(r);
            hudView.RunOver(sim.endReason);
        }
        else Finished?.Invoke(Result);
        if (!Hosted && clipDir == null && scoutPath == null && quitAfter <= 0f && (auto || timeUpAt > 0)) Application.Quit();
    }

    void Update()
    {
        pressed = ReadPresses();
        if (pressed.pause)
        {
            if (!Hosted) { Application.Quit(); return; }
            // rampage_hud.gd pause(): refused once the run is over or he is dying.
            if (error == null && !Paused && !over && !sim.death.Active()) PauseRequested?.Invoke();
        }
        if (error != null) return;
        if (pressed.restart && !Hosted) { SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex); return; }
        // Paused: no time passes for the sim or any view, and no press reaches the run.
        if (Paused) pressed = new Presses();
        float dt = Paused ? 0f : Time.deltaTime;
        age += dt;
        smoothDt = Mathf.Lerp(smoothDt, Time.unscaledDeltaTime, 0.05f);
        // Hosted, the sim is not stepped again once it is over (scenes/rampage.gd _physics_process).
        bool stopped = Hosted && over;
        if (!stopped) accumulator += dt;
        var watch = System.Diagnostics.Stopwatch.StartNew();
        int ran = 0;
        bool signature = pressed.signature, held = pressed.held;
        bool ultimate = pressed.ultimate, breathKey = pressed.breath, dash = pressed.dash;
        if (pressed.any && !auto) intro.Skip();
        if (timeUpAt > 0 && !timeUpDone && age >= timeUpAt && !sim.emerge.active)
        {
            timeUpDone = true;
            sim.timeLeft = 0.0;
            Debug.Log($"rampage: -rampage-timeup ran the clock out at age {age:F2} s, frame {Time.frameCount}");
        }
        while (!stopped && accumulator >= TICK && ran < MAX_STEPS)
        {
            accumulator -= TICK;
            ran++;
            feetFrom = feetTo;
            bool first = ran == 1;
            // One read a physics frame, however many ticks the intro runs on it (scenes/rampage.gd _step).
            S.Vector2 move = ReadMove();
            bool sign = signature && first, hold = held, ult = ultimate && first, br = breathKey && first, da = dash && first;
            if (Hosted && !auto)
            {
                taps["signature"] = sign;
                taps["ultimate"] = ult;
                taps["breath"] = br;
                taps["dash"] = da;
                Dictionary<string, bool> now = latch.Through(sim.emerge.active, taps, TICK);
                sign = now["signature"];
                ult = now["ultimate"];
                br = now["breath"];
                da = now["dash"];
            }
            if (auto)
            {
                sign = sim.abilityReadyIn <= 0.0;
                hold = steps % AUTOPLAY_GLIDE_CYCLE < AUTOPLAY_GLIDE_HELD;
                ult = true;
                br = sim.breathReadyIn <= 0.0;
                da = leapEvery > 0 && steps % leapEvery == 0;
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
                rubble.OnEvent(e);
                eventFx.OnEvent(e, Feet());
                ShakeFor(e);
                army.OnEvent(e, Feet());
                vip.OnEvent(e);
                breath.OnEvent(e);
                thunder.OnEvent(e, Feet());
                rooftops.OnEvent(e, Feet());
                leap.OnEvent(e);
                slam.OnEvent(e, Focus(Feet()));
                rail.OnEvent(e);
                strike.OnEvent(e);
                postFx.OnEvent(e);
                if (S.Gd.Str(e["type"]) == "stomp") trees.Crush(Feet(), (float)(double)S.Num.F(e["radius"]));
                TailCue(e);
                street.OnEvent(e);
                audio?.OnEvent(e);
                hudView?.OnEvent(e);
                if (Hosted) HudRumble.OnEvent(e);
            }
            }
            rooftops.Tick(TICK, cam);  // once a physics frame, as rooftop_view.gd _physics_process
        }
        if (ran == MAX_STEPS) accumulator = 0f;
        if (sim.over && !over) EndRun();
        if (derailAt > 0 && !derailDone && steps >= derailAt) DerailFirst();
        if (blastEvery > 0 && !sim.emerge.active && ++blastWait >= blastEvery)
        {
            blastWait = 0;
            S.GDict blast = TestBlast(blastsFired++);
            eventFx.OnEvent(blast, Feet());
            audio?.OnEvent(blast);
        }
        simMs = (float)watch.Elapsed.TotalMilliseconds;
        if (statsPath != null && Time.frameCount % STATS_EVERY == 0)
            File.AppendAllText(statsPath, $"frame {Time.frameCount} dt {Time.unscaledDeltaTime * 1000f:F1} ms sim {simMs:F1} mesh {city.lastMeshMs:F1} regions {city.lastRegions} promoted {city.promoted} falling {city.Falling} alive {AliveBuildings()} debris {debris.Live} ruins {rubble.Heaps} strips {rubble.Strips} grains {rubble.Grains} presses {debris.Presses} crumbles {city.Crumbles} bursts {fx.LiveBursts} fires {fx.LiveFires} stomps {sim.body.stomps} breaths {breath.Breaths} trees {trees.Count} people {street.people.Civilians()} people_drawn {street.Drawn} fled {street.people.fled} panicking {street.Panicking} people_killed {street.CiviliansKilled} stadium {street.StadiumStats()} run_over {street.people.runOver} army_killed {street.people.armyKilled} beach_held {street.people.Held()} props {street.Props} street_props {street.StreetProps} props_crushed {street.PropsCrushed} traffic_cars {street.traffic.cars.Count} traffic_fled {street.traffic.fled} traffic_crushed {street.traffic.Crushed()} blockades {street.police.blockadesMade} police_shots {street.police.shots} cops {street.people.Officers()} lights {fx.Lights.Live()}/{fx.Lights.Count} tanks {sim.tanks.Size()} helis {sim.air.helis.Size()} trains {rail.Trains} cars {rail.Cars} derailed {sim.rail.derailed} jets {strike.Flown} jets_live {strike.Live} planes_lit {aircraft.Lit} target {autoTarget.x:F1},{autoTarget.y:F1} reach {sim.body.StompReaches(autoTarget)} walking {sim.body.Walking()} steps {steps} feet {sim.kaijuPos.x:F1},{sim.kaijuPos.y:F1} y {sim.standY:F2} facing {sim.facing.x:F2},{sim.facing.y:F2} leaps {sim.body.dash.landings} slams {sim.powers.run.slams} momentum {sim.powers.run.value:F2} air {sim.body.dash.Height():F2} cam {cam.transform.position}fringes {postFx.Fringes} fringe_px {postFx.FringePx:F2} vignette {postFx.VignetteAlpha:F2} post_draws {postFx.Draws} vip {sim.vip.state} {sim.vip.pos.x:F1},{sim.vip.pos.y:F1} alt {sim.vip.Altitude():F1} vips {vip.Spawned} vip_down {vip.Downed} vip_out {vip.Escaped} squads {sim.armyUnits.squads.Size()} volleys {sim.armyUnits.volleys} roofshots {rooftops.Shots} roofdrawn {rooftops.Drawn} rooflanded {rooftops.Landed} death {sim.death.phase} {DeathStats()} gc {GC.GetTotalMemory(false) / (1 << 20)} MB\n");
        city.Animate(dt);
        city.Remesh();
        rubble.Tick();
        debris.Step(dt);
        debris.Draw();
        water.Step(dt);
        // The body between the last two ticks, so it moves every frame at any frame rate.
        Vector3 feet = Vector3.Lerp(feetFrom, feetTo, accumulator / TICK);
        float scale = (float)sim.BodyScale();
        DriveCroc(feet, scale, dt);
        if (!crownKnown)
        {
            crownKnown = true;
            crown = croc.RestCrown(HEAD_BONE, scale);
            introWater = new IntroWater(sim, fx, Resources.Load<Shader>("Shaders/Bolt"), crown.x);
        }
        croc.Draw();
        breath.Step(dt);
        thunder.Step(Feet(), dt);
        slam.Step(dt, Street(), Facing());
        fx.Tick(age, dt);
        eventFx.Step(dt);
        introWater.Step(dt);
        army.Update(dt, Feet());
        rooftops.Draw();
        rail.Update();
        vip.Step(dt);
        strike.Step(dt);
        aircraft.Step(dt);
        Trample();
        street.Step(dt, steps);
        if (croc.TakeFootfall(out string side, out Vector3 footAt))
        {
            float strength = Mathf.Clamp01(FOOT_STRENGTH_BASE + croc.SpeedShare);
            // The foot flattens the rubble under it for good (scenes/rampage.gd _on_footfall, D-245). footAt is Godot axes.
            debris.Press(new Vector3(footAt.x, 0f, -footAt.z), rubblePress * scale, rubbleKeep);
            if (Hosted) HudRumble.Footfall(side, sim);
            bool stomped = eventFx.Footfall(side, strength, footAt);
            audio?.Footfall(strength, stomped);
            if (stomped)
            {
                shake.Kick(StompKick() * Mathf.Deg2Rad);
                postFx.Stomp();
                if (Hosted) HudRumble.Stomp(sim);
            }
            stepDip = Mathf.Max(stepDip, FOOTFALL_DIP * Mathf.Max(FOOTFALL_DIP_FLOOR, scale) * strength);
        }
        shake.Update(dt);
        postFx.Step(dt, shake.motion);
        stepDip = Mathf.MoveTowards(stepDip, 0f, dt * DIP_RECOVER * stepDip + dt * DIP_CREEP);
        // Photo mode flies the camera itself (PhotoMode); the follow waits where it was.
        if (Photo == null)
        {
            follow.Step(Focus(feet), Facing(), feet, scale, sim.body.dash.On() || sim.emerge.active, stepDip * shake.motion,
                auto || sim.emerge.active || Paused ? 0f : follow.PlayerTurn() + PadTurn(dt), dt);
            PlaceCamera(scale, dt);
        }
        bubble.Step(cam, feet, dt);
        street.Draw(cam);
        fx.SetFocus(Vector3.Dot(new Vector3(feet.x, feet.y, -feet.z) - cam.transform.position, cam.transform.forward));
        fx.Draw(age);
        weather?.Step(dt, cam);
        // Not under photo mode: the HUD's tick draws the breath's aim wedge (Godot hides _aim there).
        if (Photo == null) Ticked?.Invoke(dt);
        if (quitAfter > 0f && age >= quitAfter) Application.Quit();
    }

    // scenes/camera_follow.gd: the pad's right stick swings the camera (tuning camera.swing_deg_per_s). Hosted only.
    float PadTurn(float dt)
    {
        if (!Hosted) return 0f;
        return -Inputs.Look().x * (float)S.Num.F(S.Content.Section("camera")["swing_deg_per_s"]) * Mathf.Deg2Rad * dt;
    }

    // scenes/powers_view.gd _acted: the sim's tail events cue the keyed clips; the automatic sweep crushes behind him.
    void TailCue(S.GDict e)
    {
        string kind = S.Gd.Str(e["type"]);
        string limb = kind == "tail_windup" ? "tail_windup" : kind == "tail_auto_windup" ? "tail_sweep_windup" : kind == "tail_sweep" ? "tail" : kind == "tail_auto" ? "tail_sweep" : null;
        if (limb == null) return;
        Debug.Log($"tail {kind} at frame {Time.frameCount}: side {S.Num.F(e["side"])}");
        float windup = (float)(double)S.Num.F(sim.powersCfg[limb == "tail_sweep_windup" ? "sweep_windup" : "lash_windup"]);
        croc.Cue(limb, (float)(double)S.Num.F(e["side"]), windup);
        if (kind != "tail_auto") return;
        float reach = (float)(double)S.Num.F(e["reach"]);
        trees.Crush(Feet() - new Vector3((float)(double)sim.facing.x, 0f, (float)(double)sim.facing.y) * reach * TAIL_AUTO_CRUSH, reach * TAIL_AUTO_CRUSH);
    }

    // scenes/thunder_beam.gd wire: a kick on every stroke of the beam's bolt and the breath's.
    void BoltKick(Vector3 at) => shake.AddAt("bolt_stroke", at, Focus(Feet()), (float)sim.BodyScale());

    // scenes/rail_view.gd _derailed: a derailment shakes like a toppling building, by its distance.
    void WreckKick(Vector3 at) => shake.AddAt("topple", at, Focus(Feet()), (float)sim.BodyScale());

    // Capture only: the first running train leaves its rail where it is; the track under it stays whole.
    void DerailFirst()
    {
        foreach (S.Rail.Train train in sim.rail.trains)
        {
            if (train.state != S.Rail.RUN) continue;
            derailDone = true;
            long had = sim.events.Size();
            sim.rail.Derail(train, 0, S.Vector2.ZERO);
            for (long i = had; i < sim.events.Size(); i++) rail.OnEvent(sim.events[i]);
            Debug.Log($"rampage: -rampage-derail derailed train {train.id} at step {steps}, frame {Time.frameCount}");
            return;
        }
    }

    static float StompKick() => (float)S.Num.F(S.Content.Section("clip_stomp")["kick_deg"]);

    // scenes/rampage.gd add_trauma's sources, for the events the port draws so far.
    void ShakeFor(S.GDict e)
    {
        switch (S.Gd.Str(e["type"]))
        {
            case "stomp": shake.Add("stomp"); break;
            case "ability": shake.Add("ability"); break;
            case "leap_land": shake.Add("leap_land"); break;
            case "tank_fired": shake.Add("tank_fire"); break;
            case "fall_land":
                S.RampageSim.Building b = sim.buildings[S.Num.I(e["building"])];
                shake.AddAt(S.Gd.Str(e["kind"]) == "topple" ? "topple" : "drop", new Vector3((float)(double)b.x, 0f, (float)(double)b.z), Focus(Feet()), (float)sim.BodyScale());
                break;
        }
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
        if (scout != null && error == null && scout.Step(cam, bubble)) Application.Quit();
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
        if (Photo == null) vip?.DrawHeadline();
        if (error != null) { GUI.Label(new Rect(10, 10, Screen.width - 20, Screen.height - 20), error, hud); return; }
        if (Hosted) return;  // the game's own HUD is the host's
        string text = $"{1f / smoothDt:F0} fps  sim {simMs:F1} ms  mesh {city.lastMeshMs:F1} ms ({city.lastRegions})\npromoted {city.promoted}  falling {city.Falling}  debris {debris.Live:N0}\nWASD walk  Space signature (hold)  Q breath  E ultimate  Shift dash  R restart  Esc quit";
        GUI.Label(new Rect(10, 10, 620, 80), text, hud);
    }

    void OnDestroy()
    {
        if (hudView != null) Destroy(hudView.gameObject);
        city?.Dispose();
        debris?.Dispose();
        croc?.Dispose();
        if (crocCube != null) Destroy(crocCube);
        ground?.Dispose();
        water?.Dispose();
        fx?.Dispose();
        breath?.Dispose();
        thunder?.Dispose();
        rooftops?.Dispose();
        street?.Dispose();
        death?.Dispose();
        death?.Dispose();
        rail?.Dispose();
        strike?.Dispose();
        aircraft?.Dispose();
        weather?.Dispose();
        if (cubeMesh != null) Destroy(cubeMesh);
        GraphicsView.EndRun(profile);
        if (clipTarget != null) Destroy(clipTarget);
        if (clipImage != null) Destroy(clipImage);
    }
}
