// The title's live city at night (scenes/title_backdrop.gd): the far shore across the bay from the play area's
// quay, seen by a still camera into a picture behind the menu. The plan and the sim build on a worker while the
// sky and the menu draw; then the ground, the bay, the skyline with its far rampage, the boats, the night look
// with the far windows' power cut, the burning district (TitleCity.Light), the shore (TitleShoreView), the sky's
// smoke, the flashes and the colossus with its glow and eye (TitleFxView). The picture fades in over the sky
// (tuning "fade_s"). TitleClock times the gunfire, booms and stomps from the first frame; their sounds play here
// and, once the city stands, their flashes. Steps and RevealAmount drive the colossus.
using System.Collections.Generic;
using System.Threading.Tasks;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.UI;
using S = Kaiju.Sim;

public sealed class TitleCityView : MonoBehaviour
{
    // Godot's Camera3D far default (title_backdrop.gd leaves it); the picture's depth buffer.
    const float CAMERA_FAR = 4000f;
    const int DEPTH_BITS = 24;
    // title_backdrop.gd _boom_flashes: the burst grows 1.6, the core 1.4 over 0.8 of the life, the smoke 2.
    const float BURST_GROW = 1.6f, CORE_GROW = 1.4f, CORE_LIFE = 0.8f, SMOKE_GROW = 2f;
    // The title variant's env keys laid over the run's look (title_backdrop.gd _apply_look).
    static readonly string[] ENV_COLOURS = { "ambient_color", "fog_color", "sun_color" };
    static readonly string[] ENV_NUMBERS = { "ambient", "fog_density", "sun_energy" };
    // Resources/Shaders/TitleSky's SKY_MAX: the explosions' lights the picture carries at once (the newest kept).
    const int SKY_MAX = 8;

    // An explosion's light on the picture (title_backdrop.gd _light_sky): centre (u, v), radius (share of the
    // height), its colour in display units, its alpha at the start, its life and its age.
    sealed class SkyLight
    {
        public Vector2 at;
        public float radius, alpha, life, age;
        public Color colour;
    }

    RawImage image;
    S.GDict title, colossusCfg;
    TitleClock clock;
    Task<S.RampageSim> build;
    S.RampageSim sim;
    GameObject root;
    Camera cam;
    RenderTexture target;
    VolumeProfile profile;
    readonly List<Object> made = new List<Object>();
    readonly List<System.IDisposable> views = new List<System.IDisposable>();
    SkylineRampage farRampage;
    BoatView boats;
    WaterView water;
    TitleShoreView shore;
    TitleFxView fx;
    double revealLeft;
    float eyeTime;
    Material skyMat;
    readonly List<SkyLight> skyLights = new List<SkyLight>();
    readonly Vector4[] skyAt = new Vector4[SKY_MAX], skyColour = new Vector4[SKY_MAX];

    // The colossus's baked silhouette (TitleBackdrop loads it; null draws none).
    public Texture2D colossusArt;

    // The picture's fade (0 .. 1); 1 when no city is drawn, so the card stands as before.
    public float Fade => build == null && sim == null ? 1f : (float)clock.Fade;
    public bool Loaded => clock.Loaded;
    // The colossus's footsteps so far and how lit it is now (title_colossus.gd _steps, _show amount).
    public long Steps { get; private set; }
    public double RevealAmount { get; private set; }
    // The city stands and has faded in, or none is drawn: what the title's still waits for (capture_title.gd
    // waits for TitleBackdrop.is_loaded).
    public static bool Settled { get; private set; }

    public static TitleCityView Create(Transform parent)
    {
        RectTransform rt = UiKit.Box(parent, "TitleCity");
        UiKit.FullRect(rt);
        RawImage image = rt.gameObject.AddComponent<RawImage>();
        image.raycastTarget = false;
        image.enabled = false;
        TitleCityView v = rt.gameObject.AddComponent<TitleCityView>();
        v.image = image;
        v.skyMat = new Material(Resources.Load<Shader>("Shaders/TitleSky"));
        image.material = v.skyMat;
        v.Begin();
        return v;
    }

    // title_backdrop.gd _build: night, the title's tier and haze; the plan and the sim on a worker.
    void Begin()
    {
        Settled = false;
        title = S.Content.Section("title");
        colossusCfg = title["colossus"];
        S.Content.SetTime("night");
        long tier = S.Num.I(title["city_tier"]);
        S.GDict all = S.Content.Tuning();
        S.GDict tuning = S.CityGrowth.TuningFor(all, tier);
        S.GDict city = tuning["city"];
        city["far_tower_cap"] = S.Num.F(title["tower_cap"]);
        S.GDict fog = ((S.GDict)city["far_fog"]).Duplicate();
        S.GDict titleFog = title["far_fog"];
        foreach (S.Variant key in titleFog.Keys()) fog[key] = titleFog[key];
        city["far_fog"] = fog;
        clock = new TitleClock(title, S.Num.F(city["coast_z"]) - S.Num.F(city["bay_width"]), Siren());
        Settled = SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null;
        if (Settled) return;  // headless: the sounds only
        S.Content.Look();
        build = Task.Run(() => new S.RampageSim(new S.GDict(), tuning, S.CityGrowth.Layout(all, tier, S.Seeds.Make("city", 0)), S.Seeds.Make("army", 0)));
    }

    // title_ambience.gd _ready: the siren's random start only when its sound is there.
    static bool Siren()
    {
        S.GDict cfg = S.Content.Section("title")["ambience"];
        return AudioHost.Ensure().Table.Get(S.Gd.Str(cfg["siren"])) != null;
    }

    void Update()
    {
        float dt = Time.unscaledDeltaTime;
        if (build != null && build.IsCompleted) Stand();
        clock.Step(dt);
        if (clock.Loaded) Reveal(dt);
        foreach (TitleClock.Event e in clock.events) Play(e);
        if (!clock.Loaded) return;
        image.color = new Color(1f, 1f, 1f, Fade);
        if (!Settled && Fade >= 1f) Debug.Log($"title: city stands and faded in at {Time.realtimeSinceStartup:F1} s");
        Settled = Fade >= 1f;
        Frame(dt);
    }

    // title_colossus.gd _process: the reveal's rise and fall.
    void Reveal(float dt)
    {
        revealLeft = System.Math.Max(0.0, revealLeft - dt);
        RevealAmount = TitleCity.RevealAmount(colossusCfg, revealLeft);
    }

    void Play(TitleClock.Event e)
    {
        S.GDict ambience = title["ambience"];
        if (e.kind == TitleClock.Kind.Shot)
        {
            Sfx.Direct("rifle", e.db, e.pitch);
            if (e.flash) Shot(e.at);
        }
        else if (e.kind == TitleClock.Kind.Boom)
        {
            Sfx.Direct(S.Gd.Str(((S.GDict)ambience["boom"])["sound"]), e.db, e.pitch);
            if (e.flash) Boom(e);
        }
        else
        {
            Sfx.Direct(S.Gd.Str(((S.GDict)ambience["stomp"])["sound"]), e.db, e.pitch);
            if (clock.Loaded) Steps++;
        }
    }

    // title_backdrop.gd shot(): a small bright flash in a far street.
    void Shot(S.Vector3 at)
    {
        S.GDict cfg = ((S.GDict)title["flashes"])["shot"];
        var spot = new Vector3((float)at.x, (float)S.Num.F(cfg["height"]), (float)at.z);
        fx.Add(spot, Hex(cfg["color"]), (float)S.Num.F(cfg["size"]), (float)S.Num.F(cfg["life_s"]));
    }

    // title_backdrop.gd boom(): the burst, its core, its smoke and its light on the sky; the big one goes off
    // behind the colossus and lights it, a longer flash.
    void Boom(TitleClock.Event e)
    {
        S.GDict cfg = ((S.GDict)title["flashes"])["boom"], sky = cfg;
        var at = new Vector3((float)e.at.x, (float)e.at.y, (float)e.at.z);
        float life = (float)S.Num.F(cfg["life_s"]);
        if (e.reveal)
        {
            at = Godot(TitleCity.BurstPoint(colossusCfg, Steps));
            life = (float)S.Num.F(colossusCfg["flash_life_s"]);
            revealLeft = S.Num.F(colossusCfg["reveal_s"]);
            sky = colossusCfg;
        }
        Color colour = Hex(cfg["color"]);
        fx.Add(at, colour, (float)S.Num.F(cfg["size"]), life, BURST_GROW);
        fx.Add(at, Hex(cfg["core_color"]), (float)S.Num.F(cfg["core_size"]), life * CORE_LIFE, CORE_GROW);
        fx.Add(at, Hex(cfg["smoke_color"]), (float)S.Num.F(cfg["smoke_size"]), (float)S.Num.F(cfg["smoke_s"]),
            SMOKE_GROW, (float)S.Num.F(cfg["smoke_rise"]), false);
        LightSky(at, colour, (float)S.Num.F(sky["glow_share"]), (float)S.Num.F(sky["glow_alpha"]), life);
    }

    // title_backdrop.gd _light_sky: a soft disc `share` of the picture's height across, added over the picture
    // where the burst is seen (none when it is behind the camera), its alpha going to nothing over `life` (a
    // tween, so linear). TitleSky adds it in display units, as Godot's canvas does.
    void LightSky(Vector3 at, Color colour, float share, float alpha, float life)
    {
        Vector3 seen = cam.WorldToViewportPoint(new Vector3(at.x, at.y, -at.z));
        if (seen.z < cam.nearClipPlane) return;
        if (skyLights.Count == SKY_MAX) skyLights.RemoveAt(0);
        skyLights.Add(new SkyLight { at = seen, radius = share * 0.5f, colour = colour, alpha = alpha, life = life });
    }

    // The lights' ages, and what TitleSky draws this frame.
    void StepSky(float dt)
    {
        for (int i = skyLights.Count - 1; i >= 0; i--)
        {
            skyLights[i].age += dt;
            if (skyLights[i].age >= skyLights[i].life) skyLights.RemoveAt(i);
        }
        for (int i = 0; i < skyLights.Count; i++)
        {
            SkyLight l = skyLights[i];
            skyAt[i] = new Vector4(l.at.x, l.at.y, l.radius, 0f);
            skyColour[i] = new Vector4(l.colour.r, l.colour.g, l.colour.b, l.alpha * (1f - l.age / l.life));
        }
        skyMat.SetVectorArray("_SkyAt", skyAt);
        skyMat.SetVectorArray("_SkyColour", skyColour);
        skyMat.SetFloat("_SkyCount", skyLights.Count);
        skyMat.SetFloat("_Aspect", (float)target.width / target.height);
    }

    // One drawn frame: the picture's size, the far rampage, boats, bay, shore and the soft lights.
    void Frame(float dt)
    {
        Fit();
        farRampage?.Step(dt, Godot(cam.transform.position));
        boats.Step(dt);
        water.Step(dt);
        shore.Step(dt, (float)clock.Shiver);
        S.GDict cfg = colossusCfg;
        Color glow = Hex(cfg["glow_color"]).linear;
        glow.a = Mathf.Lerp((float)S.Num.F(cfg["glow_idle"]), (float)S.Num.F(cfg["glow_peak"]), (float)RevealAmount);
        fx.colossusAt = Godot(TitleCity.BurstPoint(cfg, Steps));
        fx.colossusSize = (float)S.Num.F(cfg["glow_size"]);
        fx.colossusColor = glow;
        Colossus(dt);
        fx.Step(dt);
        StepSky(dt);
    }

    // title_colossus.gd _place and _show: the card's feet a step along its path per stomp, the body at least its
    // idle faintness, the eye from its slow pulse to its peak as the reveal lights it, on the picture's eye.
    void Colossus(float dt)
    {
        if (colossusArt == null) return;
        eyeTime += dt;
        S.GDict cfg = colossusCfg, eyeCfg = cfg["eye"];
        S.GArray<S.Variant> uv = eyeCfg["uv"];
        float height = (float)S.Num.F(cfg["height"]), width = (float)TitleMenu.ColossusWidth(cfg, colossusArt.width, colossusArt.height);
        Vector3 feet = Godot(TitleCity.ColossusFeet(cfg, Steps));
        fx.colossusFeet = feet;
        fx.colossusCard = new Vector2(width, height);
        fx.colossusAmount = Mathf.Max((float)S.Num.F(cfg["idle_alpha"]), (float)RevealAmount);
        fx.eyeAt = feet + new Vector3(((float)S.Num.F(uv[0]) - 0.5f) * width, (1f - (float)S.Num.F(uv[1])) * height, (float)S.Num.F(eyeCfg["forward"]));
        fx.eyeSize = (float)S.Num.F(eyeCfg["size"]);
        Color eye = Hex(eyeCfg["colour"]).linear;
        eye.a = Mathf.Lerp(TitleMenu.EyeAlpha(eyeCfg, eyeTime), (float)S.Num.F(eyeCfg["peak"]), (float)RevealAmount);
        fx.eyeColor = eye;
    }

    // title_backdrop.gd _make_city and _dress, in one frame once the sim stands.
    void Stand()
    {
        sim = build.Result;
        build = null;
        root = new GameObject("title city");
        Shader lit = Resources.Load<Shader>("Shaders/SliceLit");
        Tuning tuning = SliceData.LoadTuning();
        ApplyLook(tuning);
        var ground = new CityGround(sim.city, lit, root.transform);
        views.Add(ground);
        // No open sea here: Godot adds OceanWaves to the run only (rampage_rise.gd), so the title's bay rolls its swell.
        water = new WaterView(sim, ground.Sheets, Resources.Load<Shader>("Shaders/SliceWater"), null, sim.city, root.transform);
        views.Add(water);
        boats = new BoatView(sim, lit, root.transform);
        views.Add(new Releaser(boats.Dispose));
        var skyline = new CitySkyline(sim.city, lit, root.transform);
        views.Add(new Releaser(skyline.Dispose));
        if (S.Content.Section("skyline_rampage")["on"]) farRampage = new SkylineRampage(skyline, sim.city, 0, FarBeastFor(tuning, lit));
        if (farRampage != null) views.Add(farRampage);
        MakeCamera();
        Dress(skyline);
        clock.Begin();
        image.enabled = true;
        image.color = new Color(1f, 1f, 1f, 0f);
    }

    FarBeast FarBeastFor(Tuning tuning, Shader lit)
    {
        var look = MiniJson.Obj(SliceData.LoadJson("slice.json")["look"]);
        Mesh cube = SliceGame.CubeMesh(1f, true);
        made.Add(cube);
        return FarBeast.Load(S.Content.Section("skyline_rampage"), lit, cube, SliceData.F(look, "voxel_inset", 1f),
            MiniJson.F(look["color_noise"]), tuning.seam_dark, SliceGame.ExposureUnit(tuning));
    }

    // title_backdrop.gd _apply_look and _dim_windows: the night variant's env over the run's look; the far
    // windows' power cut (Facade.hlsl _FacadeCut, every facade here: the play area is behind the camera).
    void ApplyLook(Tuning tuning)
    {
        Dictionary<string, object> slice = SliceData.LoadJson("slice.json");
        var look = new Dictionary<string, object>(MiniJson.Obj(slice["look"]));
        S.GDict variant = ((S.GDict)title["variants"])[S.Gd.Str(title["variant"])];
        S.GDict env = variant["env"];
        foreach (string key in ENV_COLOURS) look[key] = S.Gd.Str(env[key]);
        foreach (string key in ENV_NUMBERS) look[key] = S.Num.F(env[key]);
        profile = SliceGame.ApplyLook(tuning, slice, look);
        made.Add(profile);
        made.Add(SliceGame.Sun.gameObject);
        foreach (Volume v in FindObjectsByType<Volume>(FindObjectsSortMode.None))
            if (v.sharedProfile == profile) made.Add(v.gameObject);
        S.GDict cut = title["windows_lit"];
        Shader.SetGlobalVector("_FacadeCut", new Vector4((float)S.Num.F(cut["blackout"]), (float)S.Num.F(cut["glow"]), 0f, 0f));
        Shader.SetGlobalVector("_FacadeCutColor", Hex(cut["lit_color"]).linear);
    }

    // title_backdrop.gd _make_city: the still camera (tuning "camera"), Godot's axes with z turned.
    void MakeCamera()
    {
        S.GDict cfg = title["camera"];
        var go = new GameObject("title camera");
        go.transform.SetParent(root.transform, false);
        cam = go.AddComponent<Camera>();
        cam.fieldOfView = (float)S.Num.F(cfg["fov"]);
        cam.nearClipPlane = (float)S.Num.F(cfg["near"]);
        cam.farClipPlane = CAMERA_FAR;
        // Godot's title SubViewport takes no graphics preset: full scale, no screen-space AA.
        var hd = go.AddComponent<HDAdditionalCameraData>();
        hd.antialiasing = HDAdditionalCameraData.AntialiasingMode.None;
        hd.allowDynamicResolution = false;
        go.transform.position = Unity(cfg["position"]);
        go.transform.LookAt(Unity(cfg["look"]));
        Fit();
    }

    // The picture is the window's size (Godot's stretched SubViewport).
    void Fit()
    {
        int w = Mathf.Max(1, Screen.width), h = Mathf.Max(1, Screen.height);
        if (target != null && target.width == w && target.height == h) return;
        if (target != null) target.Release();
        if (target != null) Destroy(target);
        target = new RenderTexture(w, h, DEPTH_BITS, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        cam.targetTexture = target;
        image.texture = target;
    }

    // title_backdrop.gd _dress: the burning district, the shore, the sky's smoke, the flashes' layer.
    void Dress(CitySkyline skyline)
    {
        var stands = new List<TitleCity.Stand>();
        foreach (SkylineRampagePlan.Box box in skyline.Far) stands.Add(new TitleCity.Stand { at = box.at, size = box.size });
        double farZ = S.Num.F(sim.city["coast_z"]) - S.Num.F(sim.city["bay_width"]);
        TitleCity.District district = TitleCity.Light(title["fires"], farZ, stands);
        S.GDict variant = ((S.GDict)title["variants"])[S.Gd.Str(title["variant"])];
        Shader shader = Resources.Load<Shader>("Shaders/TitleFx");
        shore = new TitleShoreView(title["shore"], (float)farZ, (float)S.Num.F(sim.city["coast_z"]), Godot(cam.transform.position),
            district.lit, title["ripple"], variant["water"], shader, root.transform);
        views.Add(shore);
        fx = new TitleFxView(shader, shore, district, title, (float)S.Num.F(variant["sky_smoke"]));
        views.Add(fx);
        if (colossusArt != null) fx.Colossus(colossusArt, colossusCfg);
    }

    // title_backdrop.gd _exit_tree: the worker waited for, the sim let go, everything made here undone.
    void OnDestroy()
    {
        if (build != null) sim = build.Result;
        for (int i = views.Count - 1; i >= 0; i--) views[i].Dispose();
        sim?.Dispose();
        if (target != null) target.Release();
        foreach (Object o in made) if (o != null) Destroy(o);
        if (target != null) Destroy(target);
        if (root != null) Destroy(root);
        if (skyMat != null) Destroy(skyMat);
        Shader.SetGlobalVector("_FacadeCut", Vector4.zero);
        Shader.SetGlobalVector("_FacadeCutColor", Vector4.zero);
    }

    static Vector3 Godot(S.Vector3 v) => new Vector3((float)v.x, (float)v.y, (float)v.z);

    static Vector3 Godot(Vector3 unity) => new Vector3(unity.x, unity.y, -unity.z);

    static Vector3 Unity(S.GArray<S.Variant> a) => new Vector3((float)S.Num.F(a[0]), (float)S.Num.F(a[1]), -(float)S.Num.F(a[2]));

    static Color Hex(S.Variant v) => SliceData.Hex(S.Gd.Str(v));

    // A Dispose for what has one but is not IDisposable.
    sealed class Releaser : System.IDisposable
    {
        readonly System.Action release;
        public Releaser(System.Action release) => this.release = release;
        public void Dispose() => release();
    }
}
