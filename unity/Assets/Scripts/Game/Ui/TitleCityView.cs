// The title's live city at night (scenes/title_backdrop.gd): the far shore across the bay from the play area's
// quay, seen by a still camera into a picture behind the menu. The plan and the sim build on a worker while the
// sky and the menu draw; then the ground, the bay, the skyline with its far rampage, the boats, the night look
// with the far windows' power cut, the burning district (TitleCity.Light), the shore (TitleShoreView), the sky's
// smoke, the flashes and the colossus's glow (TitleFxView). The picture fades in over the sky (tuning "fade_s").
// TitleClock times the gunfire, booms and stomps from the first frame; their sounds play here and, once the city
// stands, their flashes. The colossus itself is TitleBackdrop's card: Steps and RevealAmount drive it.
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

    // The picture's fade (0 .. 1); 1 when no city is drawn, so the card stands as before.
    public float Fade => build == null && sim == null ? 1f : (float)clock.Fade;
    public bool Loaded => clock.Loaded;
    // The colossus's footsteps so far and how lit it is now (title_colossus.gd _steps, _show amount).
    public long Steps { get; private set; }
    public double RevealAmount { get; private set; }

    public static TitleCityView Create(Transform parent)
    {
        RectTransform rt = UiKit.Box(parent, "TitleCity");
        UiKit.FullRect(rt);
        RawImage image = rt.gameObject.AddComponent<RawImage>();
        image.raycastTarget = false;
        image.enabled = false;
        TitleCityView v = rt.gameObject.AddComponent<TitleCityView>();
        v.image = image;
        v.Begin();
        return v;
    }

    // title_backdrop.gd _build: night, the title's tier and haze; the plan and the sim on a worker.
    void Begin()
    {
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
        if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null) return;  // headless: the sounds only
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

    // title_backdrop.gd _light_sky: `share` of the picture's height across where the burst is seen (none when it
    // is behind the camera), as wide in the world at the burst's depth.
    void LightSky(Vector3 at, Color colour, float share, float alpha, float life)
    {
        Vector3 seen = new Vector3(at.x, at.y, -at.z) - cam.transform.position;
        float depth = Vector3.Dot(seen, cam.transform.forward);
        if (depth < cam.nearClipPlane) return;
        float size = share * 2f * depth * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);
        fx.Sky(at, new Color(colour.r, colour.g, colour.b, alpha), size, life);
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
        fx.Step(dt);
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
        water = new WaterView(sim, ground.Sheets, Resources.Load<Shader>("Shaders/SliceWater"), Resources.Load<ComputeShader>("Shaders/OceanWaves"), sim.city, root.transform);
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
        GraphicsView.UseCamera(go.AddComponent<HDAdditionalCameraData>());
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
