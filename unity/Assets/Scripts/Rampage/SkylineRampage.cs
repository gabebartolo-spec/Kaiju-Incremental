using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The far rampage across the bay (scenes/skyline_rampage.gd, D-484): its beast (FarBeast) paces the skyline, the
// towers in its way drop, fires and smoke columns rise where they fell and on towers nearby, and faint booms
// and its footfalls arrive late, as from that far; a tower it smashes makes it stomp. A pure function of the elapsed time and the run's seeded stream (JumpTo), so a
// capture can show any moment. Presentation only: the towers fall in CitySkyline's mesh (its Falls buffer, read by
// SliceSurface.hlsl), the fires and smoke are camera-facing quads (HorizonFx.shader).
public sealed class SkylineRampage : IDisposable
{
    const long SKYLINE_SALT = 16;  // the far rampage's stream, drawn from the run's fx seed
    const string BOOM = "assets/sfx/collapse.ogg", THUD = "assets/sfx/stomp_0.ogg";
    const string BUS = "SFX";
    const float TILT = 0.5f;  // a falling tower's lean at the end of its fall (radians)
    const int VOICES = 4;
    const double REF_DIST = 100.0;  // sounds play at their dB this far away
    const float WASH_W = 5f, WASH_H = 3f;  // a fire's warm wash on the haze, in fire sizes
    const float FLAME_TALL = 1.3f;
    const float FLAME_POWER = 1.6f, WASH_POWER = 0.5f;
    public const double PUFF = 9.0;  // a smoke puff's size at the foot of its column
    const float KIND_FLAME = 0f, KIND_WASH = 1f, KIND_DUST = 1f;
    const float STANDING = -1f, GONE = 2f;
    const int QUAD_VERTS = 6, QUAD_STRIDE = 3;
    // horizon_smoke.gdshaderinc: a puff's trip up its column (s), its sideways drift (share of the column), how long
    // a dust cloud lasts (s); horizon_fire.gdshader's default haze start (m), which FarHaze leaves alone.
    const float RISE_S = 14f, DRIFT = 0.35f, DUST_S = 7f, FIRE_HAZE_START = 120f;
    const float EMBER_ENERGY = 1.2f;
    static readonly Color DUST = new Color(0.42f, 0.38f, 0.33f);  // horizon_smoke.gdshaderinc dust_color
    const double DB_PER_DECADE = 20.0;
    const float ALPHA_SRC = (float)BlendMode.SrcAlpha, ALPHA_DST = (float)BlendMode.OneMinusSrcAlpha;
    const float BOUNDS = 4000f;

    // Seconds into the far rampage (it began before the player's run did: cfg "start_s").
    public double Elapsed { get; private set; }
    public readonly SkylineRampagePlan plan;
    readonly S.GDict cfg;
    readonly CitySkyline skyline;
    readonly float[] drawn;
    readonly Vector4[] falls;
    readonly ComputeBuffer fireQuads, smokeQuads;
    readonly Material fireMat, smokeMat;
    readonly Bounds bounds = new Bounds(Vector3.zero, Vector3.one * BOUNDS);
    readonly List<(double at, string file, double db)> pending = new List<(double at, string file, double db)>();
    readonly FarBeast beast;
    public FarBeast Beast => beast;
    Vector3 ear;  // the player's camera, Godot axes (_ear)
    readonly AudioChannel[] voices = new AudioChannel[VOICES];
    int nextVoice, nextFall;

    double F(string key) => S.Num.F(cfg[key]);

    // `city` tuning city (its far haze), `seed` the run's (its fx stream).
    // `beast` null: the far rampage without its beast (its bake missing).
    public SkylineRampage(CitySkyline skyline, S.GDict city, long seed, FarBeast beast)
    {
        this.skyline = skyline;
        this.beast = beast;
        if (beast != null) beast.walk.FootPlanted += Footfall;
        cfg = S.Content.Section("skyline_rampage");
        S.RandomNumberGenerator rng = S.Seeds.Derive(S.Seeds.Make("fx", seed), SKYLINE_SALT);
        plan = new SkylineRampagePlan(cfg, skyline.Far, skyline.Shore, rng, PUFF);
        drawn = new float[plan.falls.Count];
        falls = new Vector4[skyline.Falls.count];
        for (int i = 1; i < falls.Length; i += CitySkyline.FALL_STRIDE) falls[i] = new Vector4(STANDING, 0f, 0f, 0f);
        Shader shader = Resources.Load<Shader>("Shaders/HorizonFx");
        fireQuads = FireQuads();
        smokeQuads = SmokeQuads();
        fireMat = Make(shader, "FAR_FIRE", fireQuads, (float)BlendMode.One, (float)BlendMode.One);
        smokeMat = Make(shader, "FAR_SMOKE", smokeQuads, ALPHA_SRC, ALPHA_DST);
        Color fire = Hex(S.Gd.Str(cfg["fire"]));
        fireMat.SetVector("_FarColor", fire);  // Godot's instance colour: raw
        fireMat.SetVector("_FarHazeShape", new Vector4((float)S.Num.F(city["far_haze"]), FIRE_HAZE_START, 0f, 0f));
        S.GDict fog = city["far_fog"];
        bool on = fog["on"];  // FarHaze tracks the smoke: the far towers' own air
        float haze = (float)(S.Num.F(city["far_haze"]) * (on ? S.Num.F(fog["own_haze"]) : 1.0));
        smokeMat.SetVector("_FarHazeShape", new Vector4(haze, (float)S.Num.F(fog["start"]), 0f, 0f));
        smokeMat.SetVector("_FarHazeTint", Hex(S.Gd.Str(S.Content.Look()["fog_color"])).linear);
        smokeMat.SetVector("_SmokeShape", new Vector4(RISE_S, (float)F("smoke_height"), DRIFT, DUST_S));
        smokeMat.SetVector("_SmokeColor", Hex(S.Gd.Str(cfg["smoke"])).linear);
        smokeMat.SetVector("_DustColor", DUST.linear);
        Color ember = fire.linear;
        smokeMat.SetVector("_EmberColor", new Vector4(ember.r, ember.g, ember.b, EMBER_ENERGY));
        Shader.SetGlobalFloat("_FarTilt", TILT);
        if (AudioHost.I != null)
            for (int i = 0; i < VOICES; i++) voices[i] = AudioHost.I.NewChannel(true);
        for (int i = 0; i < drawn.Length; i++) drawn[i] = float.NaN;
        JumpTo(F("start_s"));
    }

    static Color Hex(string s) => ColorUtility.TryParseHtmlString("#" + s.TrimStart('#'), out Color c) ? c : Color.magenta;

    static Material Make(Shader shader, string keyword, ComputeBuffer quads, float src, float dst)
    {
        var mat = new Material(shader);
        mat.EnableKeyword(keyword);
        mat.SetFloat("_SrcBlend", src);
        mat.SetFloat("_DstBlend", dst);
        mat.SetBuffer("_FarQuads", quads);
        return mat;
    }

    // A flame and its wash per fire (skyline_rampage.gd _build_lights): (centre, width), custom, (height).
    ComputeBuffer FireQuads()
    {
        var data = new List<Vector4>();
        foreach (SkylineRampagePlan.Fire spot in plan.fires)
        {
            float w = (float)spot.size, start = (float)spot.start, seed = (float)spot.seed;
            Vector3 pos = Godot(spot.pos);
            data.Add(new Vector4(pos.x, pos.y, pos.z, w));
            data.Add(new Vector4(seed, start, KIND_FLAME, FLAME_POWER));
            data.Add(new Vector4(w * FLAME_TALL, 0f, 0f, 0f));
            data.Add(new Vector4(pos.x, pos.y + w, pos.z, w * WASH_W));
            data.Add(new Vector4(seed, start, KIND_WASH, WASH_POWER));
            data.Add(new Vector4(w * WASH_H, 0f, 0f, 0f));
        }
        return Upload(data);
    }

    // Every fire's smoke column and each ruin's dust (skyline_rampage.gd _build_smoke): (base, size), custom.
    ComputeBuffer SmokeQuads()
    {
        var data = new List<Vector4>();
        foreach (SkylineRampagePlan.Puff puff in plan.puffs)
        {
            Vector3 pos = Godot(puff.pos);
            data.Add(new Vector4(pos.x, pos.y, pos.z, (float)puff.size));
            data.Add(new Vector4((float)puff.slot, (float)puff.start, puff.dust ? KIND_DUST : 0f, (float)puff.seed));
            data.Add(Vector4.zero);
        }
        return Upload(data);
    }

    static ComputeBuffer Upload(List<Vector4> data)
    {
        var buffer = new ComputeBuffer(Mathf.Max(1, data.Count), sizeof(float) * 4);
        if (data.Count > 0) buffer.SetData(data);
        return buffer;
    }

    static Vector3 Godot(S.Vector3 v) => new Vector3((float)v.x, (float)v.y, (float)v.z);

    // One frame: `dt` seconds on (0 while paused), the camera at `ear` (Godot axes).
    public void Step(float dt, Vector3 ear)
    {
        this.ear = ear;
        Elapsed += dt;
        Apply();
        Walk(dt);
        Hear();
        if (plan.fires.Count > 0)
            Graphics.DrawProcedural(fireMat, bounds, MeshTopology.Triangles, QUAD_VERTS, plan.fires.Count * 2, null, null, ShadowCastingMode.Off, false, 0);
        if (plan.puffs.Count > 0)
            Graphics.DrawProcedural(smokeMat, bounds, MeshTopology.Triangles, QUAD_VERTS, plan.puffs.Count, null, null, ShadowCastingMode.Off, false, 0);
    }

    // Shows the far rampage `seconds` in, silently (captures; the run's start).
    public void JumpTo(double seconds)
    {
        Elapsed = seconds;
        nextFall = 0;
        while (nextFall < plan.falls.Count && plan.falls[nextFall].at <= Elapsed) nextFall++;
        pending.Clear();
        Apply();
        Walk(0f);
    }

    // The beast's feet where the plan has it now (_walk): side-on while it walks, turning to the bay as it slows.
    void Walk(float dt)
    {
        if (beast == null) return;
        double yaw = FarBeastWalk.Yaw(plan.Velocity(Elapsed), F("speed"));
        beast.Walk(dt, new BV(plan.BeastX(Elapsed), SkylineRampagePlan.GROUND_Y, plan.pathZ), yaw, ear);
    }

    void Footfall(string side, double strength, BV at) => Send(THUD, new Vector3((float)at.x, (float)at.y, (float)at.z), F("step_db"));

    // How many towers have dropped by now (captures and tests).
    public int Fallen()
    {
        int n = 0;
        foreach (SkylineRampagePlan.Fall fall in plan.falls)
            if (fall.at + F("fall_s") <= Elapsed) n++;
        return n;
    }

    void Apply()
    {
        bool moved = false;
        for (int n = 0; n < plan.falls.Count; n++) moved |= DrawTower(n);
        if (moved) skyline.Falls.SetData(falls);
        fireMat.SetFloat("_FarNow", (float)Elapsed);
        smokeMat.SetFloat("_FarNow", (float)Elapsed);
    }

    // A tower in its fall (_draw_tower): it sinks into its own footprint, leaning away from the blow; its crowns
    // with it. False when nothing moved (standing or gone, as last drawn).
    bool DrawTower(int n)
    {
        SkylineRampagePlan.Fall fall = plan.falls[n];
        float p = Mathf.Clamp((float)((Elapsed - fall.at) / F("fall_s")), STANDING, GONE);
        if (p < 0f) p = STANDING;
        else if (p >= 1f) p = GONE;
        if (p == drawn[n] && (p < 0f || p > 1f)) return false;
        drawn[n] = p;
        SkylineRampagePlan.Box box = skyline.Far[fall.index];
        var head = new Vector4((float)box.at.x, (float)(box.at.y - box.size.y * 0.5), (float)box.at.z, (float)box.size.y);
        var state = new Vector4(p, (float)fall.dir, p > 1f ? 1f : 0f, 0f);
        Set(fall.index, head, state);
        foreach (int crown in fall.crowns) Set(crown, head, state);
        return true;
    }

    void Set(int index, Vector4 head, Vector4 state)
    {
        falls[index * CitySkyline.FALL_STRIDE] = head;
        falls[index * CitySkyline.FALL_STRIDE + 1] = state;
    }

    // Footfalls and collapses reach the camera at the speed of sound, faint with distance (_hear); a tower the
    // beast smashes makes it stomp.
    void Hear()
    {
        while (nextFall < plan.falls.Count && plan.falls[nextFall].at <= Elapsed)
        {
            Send(BOOM, Godot(skyline.Far[plan.falls[nextFall].index].at), F("boom_db"));
            if (plan.falls[nextFall].smash) beast?.Stomp();
            nextFall++;
        }
        while (pending.Count > 0 && pending[0].at <= Elapsed)
        {
            (double _, string file, double db) = pending[0];
            pending.RemoveAt(0);
            AudioChannel voice = voices[nextVoice];
            nextVoice = (nextVoice + 1) % VOICES;
            if (voice != null) AudioHost.I.Begin(voice, "far_boom", file, BUS, db, F("boom_pitch"), 0.0, false);
        }
    }

    void Send(string file, Vector3 from, double db)
    {
        double dist = Math.Max(Vector3.Distance(from, ear), REF_DIST);
        pending.Add((Elapsed + dist / F("sound_speed"), file, db - DB_PER_DECADE * Math.Log10(dist / REF_DIST)));
        pending.Sort((a, b) => a.at.CompareTo(b.at));
    }

    public void Dispose()
    {
        if (beast != null) beast.walk.FootPlanted -= Footfall;
        beast?.Dispose();
        fireQuads?.Release();
        smokeQuads?.Release();
        if (fireMat != null) UnityEngine.Object.Destroy(fireMat);
        if (smokeMat != null) UnityEngine.Object.Destroy(smokeMat);
    }
}
