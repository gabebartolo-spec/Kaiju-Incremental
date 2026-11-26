using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using Kaiju.Game;
using S = Kaiju.Sim;

// RampageGame's load (scenes/rampage.gd _ready, rampage_load.gd, city_view.gd _ready): seven stages, the loading
// screen's meter moved after each. Behind the loading screen (a hosted run) each finished stage is drawn before the
// next starts, and the sim is made on a worker meanwhile (sim_on_worker.gd), so the screen never looks hung.
// Otherwise (captures, dry runs) the stages run back to back inside Awake, as before.
public sealed partial class RampageGame
{
    // data/slice.json and its look section.
    Dictionary<string, object> slice, look;
    Shader lit;
    Transform cityRoot;
    FireTuning fireTuning;
    string speciesId;
    Task<S.RampageSim> simTask;
    bool loaded;
    // The stage (dry runs) and the seed the run was built with.
    int loadStage, loadSeed;

    // True once all seven stages are built without an error.
    public bool Loaded => loaded;

    // The stages after the sim, in order; with the sim's they are LoadingCard.STAGES.
    Action[] Stages() => new Action[] { CrocStage, CityStage, GroundStage, FxStage, StreetStage, RestStage };

    // Every stage now, one after another (no frame drawn between them).
    void LoadNow(int stage, int seed)
    {
        if (!Try(() => SimStage(stage, seed, false))) return;
        foreach (Action s in Stages())
            if (!Try(s)) return;
        LoadDone();
    }

    // Each stage, then a frame drawn with the meter moved, until all seven are built. Meanwhile the rampage's own
    // Update, LateUpdate and OnGUI are off (the coroutine still runs); a failed stage turns them on, so its
    // error shows.
    IEnumerator LoadStaged(int stage, int seed)
    {
        enabled = false;
        if (!Try(() => SimStage(stage, seed, true))) yield break;
        while (!simTask.IsCompleted) yield return null;
        if (!Try(TakeSim)) yield break;
        Loading.Advance();
        yield return null;
        foreach (Action s in Stages())
        {
            if (!Try(s)) yield break;
            Loading.Advance();
            yield return null;
        }
        LoadDone();
    }

    bool Try(Action step)
    {
        try
        {
            step();
            return true;
        }
        catch (Exception e)
        {
            error = e.ToString();
            Debug.LogException(e);
            enabled = true;
            Loading.HideWhenDrawn();  // its error shows instead
            return false;
        }
    }

    void LoadDone()
    {
        loaded = true;
        enabled = true;
        Loading.HideWhenDrawn();
    }

    // Stage 1: the look, the run's species, stats and city plan, and the sim (on a worker when `worker`).
    void SimStage(int stage, int seed, bool worker)
    {
        S.FileAccess.Root = DataRoot();
        tuning = SliceData.LoadTuning();
        slice = SliceData.LoadJson("slice.json");
        look = MiniJson.Obj(slice["look"]);
        profile = GraphicsView.StartRun(SliceGame.ApplyLook(tuning, slice, look), SliceGame.Sun);  // counts frozen for this run

        // A hosted run is the save's: its species, stats and city (scenes/main.gd, globe_missions.gd); else the flags'.
        speciesId = request != null ? S.Gd.Str(S.Content.SpeciesDef(request.species)["id"]) : SPECIES;
        Species = S.Content.SpeciesDef(speciesId);
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
            stats = S.UpgradeTree.RunStats(S.Content.Section("kaiju"), Species, new S.UpgradeTree(S.Content.Upgrades(), Levels(stage), SPECIES));
            layout = S.CityGrowth.Layout(S.Content.Tuning(), stage, S.Seeds.Make("city", seed));
            S.Content.SetTime(Arg(Environment.GetCommandLineArgs(), "-rampage-time", "dusk"));
            // Capture/dry-run only: -rampage-time <id> and -rampage-weather <id> play that time (dusk without it) and weather.
            string weatherArg = Arg(Environment.GetCommandLineArgs(), "-rampage-weather");
            if (weatherArg != null) S.Content.SetWeather(weatherArg);
        }
        loadSeed = seed;
        Func<S.RampageSim> make = () => new S.RampageSim(stats, S.CityGrowth.ForStats(stats), layout, S.Seeds.Make("army", seed));
        simTask = worker ? Task.Run(make) : Task.FromResult(make());
        if (!worker) TakeSim();
    }

    // The worker's sim (its exception, if it threw).
    void TakeSim()
    {
        sim = simTask.GetAwaiter().GetResult();
        simTask = null;
    }

    // Stage 2: the croc, its rise from the bay, the intro and the debris field.
    void CrocStage()
    {
        lit = Resources.Load<Shader>("Shaders/SliceLit");
        crocCube = SliceGame.CubeMesh(1f, true);
        croc = new Croc(tuning, slice, lit, crocCube, SliceData.F(look, "voxel_inset", VOXEL_INSET), Croc.BodyStage(sim.SizeTier()));
        // scenes/rampage.gd _take_sim: the species' attack and body first, since the rise is placed by the body's length.
        S.GDict ability = Species["ability"];
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
    }

    // Stage 3: the buildings.
    void CityStage()
    {
        cityRoot = new GameObject("city").transform;
        city = new CityDraw(sim, lit, debris, cityRoot);
        feetFrom = feetTo = Feet();
        croc.position = feetTo;
        croc.yaw = Mathf.Atan2(-Facing().x, -Facing().y);
    }

    // Stage 4: the ground and the water.
    void GroundStage()
    {
        ground = new CityGround(sim.city, lit, cityRoot);
        water = new WaterView(sim, ground.Sheets, Resources.Load<Shader>("Shaders/SliceWater"), Resources.Load<ComputeShader>("Shaders/OceanWaves"), sim.city, cityRoot);
        Debug.Log($"rampage: ground {ground.SlabCount} slabs, {ground.VertexCount} verts; water {ground.Sheets.Count} sheets, {water.VertexCount} verts");
    }

    // Stage 5: the camera, the effects, the rubble and the army.
    void FxStage()
    {
        BuildCamera();
        bubble = new CameraBubble(sim, city);
        fireTuning = FireTuning.Load();
        var fires = new Fires(fireTuning, Resources.Load<Shader>("Shaders/Flame"), SliceGame.ExposureUnit(tuning), false, new LightPool());
        fx = HideHitFx(new CityFx(Resources.Load<Shader>("Shaders/Burst"), fires, SliceData.F(look, "sun_energy", 1), SliceGame.ExposureUnit(tuning), fireTuning.light_match_m, loadSeed));
        eventFx = new EventFx(sim, fx, loadSeed, Species);
        // The rubble look: heaps and strips laid on the debris field, the crumble's dust, the landing puff's
        // place, and the foot's press (data/tuning.json street.rubble_press, rubble_keep; D-245).
        rubble = new RubbleView(sim, tuning, city, debris);
        city.crumbleFx = fx;
        eventFx.City = city;
        rubblePress = (float)S.Num.F(S.Content.Section("street")["rubble_press"]);
        rubbleKeep = (float)S.Num.F(S.Content.Section("street")["rubble_keep"]);
        army = new ArmyView(sim, fx, lit, cityRoot, loadSeed);
        vip = new VipView(sim, army, SliceGame.ExposureUnit(tuning), fireTuning.light_match_m);
    }

    // Stage 6: the trees and the street (people, traffic, props).
    void StreetStage()
    {
        trees = new CityTrees(sim, fx, lit, cityRoot, loadSeed);
        street = new StreetView(sim, fx, lit, cityRoot, SliceGame.ExposureUnit(tuning), fireTuning.light_match_m, loadSeed);
        Debug.Log($"street: {street.people.Civilians()} people ({street.people.beachPeople} on the beach), {street.Props} props");
    }

    // Stage 7: the rail, the far city, the air, the powers, the weather, the HUD and the sound.
    void RestStage()
    {
        rail = new RailView(sim, fx, army, street.people, lit, cityRoot, WreckKick);
        BuildFarCity(lit, loadSeed, cityRoot);
        strike = new AirstrikeView(sim, lit, cityRoot);
        aircraft = new Aircraft(tuning, lit, cityRoot, loadSeed);
        breath = new BreathView(sim, fx, croc, trees, loadSeed, SliceGame.ExposureUnit(tuning), fireTuning.light_match_m);
        thunder = new ThunderView(sim, fx, croc, loadSeed, SliceGame.ExposureUnit(tuning), fireTuning.light_match_m, BoltKick);
        breath.Stroked = BoltKick;
        rooftops = new RooftopView(sim, fx, croc, lit, loadSeed);
        leap = new LeapView(sim, croc, trees);
        slam = new SlamView(sim, city, fx, shake, croc, tuning);
        postFx = new PostFxView(sim, profile);
        weather = WeatherView.Attach(profile, Resources.Load<Shader>("Shaders/Rain"), fireTuning.wind, SliceGame.ExposureUnit(tuning),
            ground, street, sim, Resources.Load<Shader>("Shaders/RainSmear"));
        walked = sim.kaijuPos;
        Hooks();
        Started();
    }
}
