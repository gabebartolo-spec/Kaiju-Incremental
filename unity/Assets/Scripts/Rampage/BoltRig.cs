using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

// One branch off the main channel (scenes/bolt_branches.gd). `of` < 0: off the main bolt.
public sealed class BoltBranch
{
    public float t;
    public Vector3 end;
    public List<Vector3> shape;
    public int of;
}

// The game's one bolt (scenes/bolt_rig.gd): a dim feeler, then bright strokes down one channel with its
// branches, the lights and flares they throw. Every value comes from tuning fx.bolt and its row, so the
// Thunder Beam's row runs the same rig. Presentation only; Godot axes.
public sealed class BoltRig : IDisposable
{
    public const int SEEDS_PER_RUN = 4096;
    const float LIGHT_BACK = 1.5f, LIGHTEN = 0.3f;
    const int QUEUE_ARC = BoltView.QUEUE_BOLT, QUEUE_BRANCH = BoltView.QUEUE_BOLT + 1, QUEUE_MAIN = BoltView.QUEUE_BOLT + 2;
    const int QUEUE_FLARE = BoltView.QUEUE_BOLT + 3;
    const int HOP_ROUNDS = 3;
    const float DEFAULT_STRAND_SWAY = 0.2f;

    // How far along (from, from + span) the first standing thing is, 0..1.
    public Func<Vector3, Vector3, float> blocker;
    // The drawn lines cut short at what the sim left standing.
    public Func<List<List<Vector3>>, List<List<Vector3>>> wallCut;
    public BoltCone cone;
    // (rng, count): where this play's branches strike. Null: across the cone.
    public Func<S.RandomNumberGenerator, int, List<Vector3>> ends;
    // A stroke fired, and where the bolt lands.
    public Action<Vector3> stroked;
    public float power = 1f;

    public bool Live { get; private set; }

    readonly S.GDict cfg, row;
    readonly float scale, exposureUnit, lightMatch;
    readonly CityFx fx;
    readonly BoltView mainView, branchView, arcView;
    readonly Light mouthLight, hitLight;
    readonly Mesh quad;
    readonly Material flareMat;
    readonly MaterialPropertyBlock muzzleBlock = new MaterialPropertyBlock(), strikeBlock = new MaterialPropertyBlock();
    readonly List<BoltBranch> branches = new List<BoltBranch>();
    readonly List<List<Vector3>> arcs = new List<List<Vector3>>();
    readonly List<List<Vector3>> drawnBranches = new List<List<Vector3>>();
    readonly float mainTip, mouthShare, branchWidth, branchTip;

    S.RandomNumberGenerator rng;
    List<Vector3> mainShape = new List<Vector3>();
    Vector3 mouth, hit;
    float t, since, end, next, reveal, crackle, arcWait, mouthEnergy, hitEnergy, muzzleFade, strikeFade;
    int index;
    bool dirty;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static float At(S.GArray<S.Variant> a, int i) => (float)(double)S.Num.F(a[i]);

    // scenes/bolt_branches.gd _row.get: the Thunder Beam's row leaves these out.
    float Opt(string key, float fallback) => row.Has(key) ? F(row, key) : fallback;

    static int Roll(S.RandomNumberGenerator rng, S.GArray<S.Variant> range) => (int)rng.RandiRange(S.Num.I(range[0]), S.Num.I(range[1]));

    static float Range(S.RandomNumberGenerator rng, float a, float b) => (float)rng.RandfRange(a, b);

    // Godot's smoothstep: Mathf.SmoothStep interpolates between its first two arguments instead.
    static float Smooth(float a, float b, float x)
    {
        float k = Mathf.Clamp01((x - a) / (b - a));
        return k * k * (3f - 2f * k);
    }

    static Color Hex(S.Variant v)
    {
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(v), out Color c);
        return c;
    }

    public BoltRig(string rowName, Shader boltShader, Shader flareShader, CityFx fx, float scale, float exposureUnit, float lightMatch, S.GDict cfg)
    {
        this.cfg = cfg;
        row = cfg[rowName];
        this.fx = fx;
        this.scale = scale;
        this.exposureUnit = exposureUnit;
        this.lightMatch = lightMatch;
        mainTip = F(cfg, "main_tip");
        mouthShare = F(cfg, "mouth_share");
        branchWidth = F(row, "branch_width");
        branchTip = F(cfg, "branch_tip");
        float core = F(row, "core") * scale, minPx = F(cfg, "core_min_px"), soft = F(cfg, "bolt_soft");
        mainView = new BoltView(boltShader, core, minPx, 1f, cfg, QUEUE_MAIN, soft);
        branchView = new BoltView(boltShader, core, minPx, 1f, cfg, QUEUE_BRANCH, soft);
        arcView = new BoltView(boltShader, core, F(cfg, "arc_min_px"), F(cfg, "arc_alpha"), cfg, QUEUE_ARC, soft);

        S.GDict modes = cfg["halo_modes"];
        S.GDict mode = modes[S.Gd.Str(cfg["halo_mode"])];
        Color flare = Hex(mode["flare"]);
        mouthLight = MakeLight("bolt mouth", flare);
        hitLight = MakeLight("bolt hit", Color.Lerp(Hex(mode["inner"]), Color.white, LIGHTEN));

        quad = new Mesh { name = "flare" };
        quad.SetVertices(new[] { new Vector3(-1, -1, 0), new Vector3(1, -1, 0), new Vector3(1, 1, 0), new Vector3(-1, 1, 0) });
        quad.SetTriangles(new[] { 0, 1, 2, 0, 2, 3 }, 0, false);
        quad.bounds = new Bounds(Vector3.zero, Vector3.one * 1e6f);
        flareMat = new Material(flareShader) { renderQueue = QUEUE_FLARE };
        foreach (MaterialPropertyBlock b in new[] { muzzleBlock, strikeBlock })
        {
            b.SetVector("_FlareTint", flare.linear);
            b.SetFloat("_FlareEdge", F(cfg, "flare_edge"));
            b.SetFloat("_FlareSoft", F(cfg, "flare_soft") * scale);
            b.SetFloat("_FlareFade", 0f);
        }
        Cancel();
    }

    static Light MakeLight(string name, Color color)
    {
        var go = new GameObject(name);
        var light = go.AddComponent<Light>();
        light.type = LightType.Point;
        light.shadows = LightShadows.None;
        light.lightUnit = LightUnit.Candela;
        go.AddComponent<HDAdditionalLightData>();
        light.color = color;
        go.SetActive(false);
        return light;
    }

    public void Play(float seconds, S.RandomNumberGenerator stream)
    {
        rng = stream;
        Live = true;
        t = since = 0f;
        index = 0;
        end = seconds > 0f ? seconds : float.PositiveInfinity;
        next = F(cfg, "first_at");
        S.GArray<S.Variant> feeler = cfg["feeler_reach"];
        reveal = At(feeler, 0);
        mainShape = BoltShape.Channel(rng, (int)S.Num.I(cfg["depth"]), F(row, "sway"));
        branches.Clear();
        arcs.Clear();
        arcWait = 0f;
        crackle = 0f;
        float lift = Mathf.Lerp(1f, power, F(cfg, "power_share"));
        foreach (BoltView v in new[] { mainView, branchView, arcView })
            v.SetPower(F(cfg, "boost_core") * lift, F(cfg, "fringe_boost") * lift);
        mouthEnergy = hitEnergy = 0f;
        mouthLight.gameObject.SetActive(true);
        hitLight.gameObject.SetActive(true);
        dirty = true;
    }

    public void Aim(Vector3 from, Vector3 to)
    {
        float move = F(cfg, "rebuild_move") * scale;
        if ((from - mouth).sqrMagnitude > move * move || (to - hit).sqrMagnitude > move * move) dirty = true;
        mouth = from;
        hit = to;
    }

    public void Release() => end = Mathf.Min(end, t + F(cfg, "tail"));

    public void Cancel()
    {
        Live = false;
        mainView.Hide();
        branchView.Hide();
        arcView.Hide();
        mouthLight.gameObject.SetActive(false);
        hitLight.gameObject.SetActive(false);
        muzzleFade = strikeFade = 0f;
    }

    public void Step(float dt)
    {
        if (!Live) return;
        t += dt;
        since += dt;
        if (t >= end)
        {
            Cancel();
            return;
        }
        if (t >= next) Stroke();
        Recrackle(dt);
        Feel();
        StepArcs(dt);
        Shine(dt);
        if (dirty) Rebuild();
    }

    public void Draw()
    {
        if (!Live) return;
        mainView.Draw();
        branchView.Draw();
        arcView.Draw();
        DrawFlare(muzzleBlock, muzzleFade);
        DrawFlare(strikeBlock, strikeFade);
    }

    void DrawFlare(MaterialPropertyBlock block, float fade)
    {
        if (fade <= 0f) return;
        block.SetFloat("_FlareFade", fade * SettingsApply.FlashScale);  // Reduce flashing (bolt_rig.gd)
        Graphics.DrawMesh(quad, Matrix4x4.identity, flareMat, 0, null, 0, block, ShadowCastingMode.Off, false);
    }

    void Feel()
    {
        if (index > 0) return;
        float step = F(cfg, "feeler_step");
        float done = Mathf.Floor(t / step) * step / F(cfg, "first_at");
        S.GArray<S.Variant> feeler = cfg["feeler_reach"];
        float now = Mathf.Lerp(At(feeler, 0), At(feeler, 1), Mathf.Clamp01(done));
        if (!Mathf.Approximately(now, reveal))
        {
            reveal = now;
            dirty = true;
        }
    }

    void Recrackle(float dt)
    {
        float every = Opt("reroll", 0f);
        if (every <= 0f || index == 0) return;
        crackle -= dt;
        if (crackle > 0f) return;
        crackle = every;
        RollBranches();
        dirty = true;
    }

    float Env(float decay)
    {
        float attack = F(cfg, "attack");
        return since < attack ? since / attack : Mathf.Exp(-(since - attack) / decay);
    }

    void Shine(float dt)
    {
        float tail = F(cfg, "tail"), first = F(cfg, "first_at"), feeler = F(cfg, "feeler_level");
        float fade = float.IsInfinity(end) ? 1f : Smooth(0f, tail, end - t);
        float main = feeler, branch = 0f, flash = 0f;
        if (index > 0)
        {
            float hold = F(cfg, "hold_level"), attack = F(cfg, "attack");
            float from = index == 1 ? feeler : hold;
            main = hold + (1f - hold) * Env(F(cfg, "stroke_decay"));
            if (since < attack) main = Mathf.Lerp(from, 1f, since / attack);
            float branchHold = F(cfg, "branch_hold");
            branch = branchHold + (F(cfg, "branch_peak") - branchHold) * Env(F(cfg, "branch_decay"));
            flash = Env(F(cfg, "light_decay"));
        }
        mainView.SetLevel(main * fade);
        branchView.SetLevel(branch * fade);
        arcView.SetLevel(F(cfg, "arc_level") * fade);

        S.GDict lightRow = cfg["light"];
        float share = F(lightRow, "hold_share");
        float flood = (share + (1f - share) * flash) * fade * Mathf.Lerp(1f, power, F(cfg, "power_share"));
        if (index == 0) flood = share * Mathf.Clamp01(t / first) * fade;
        float follow = 1f - Mathf.Exp(-dt * F(cfg, "light_follow"));
        S.GArray<S.Variant> mouthRow = lightRow["mouth"], impactRow = lightRow["impact"];
        mouthEnergy = Mathf.Lerp(mouthEnergy, At(mouthRow, 0) * flood * SettingsApply.FlashScale, follow);
        hitEnergy = Mathf.Lerp(hitEnergy, At(impactRow, 0) * flood * SettingsApply.FlashScale, follow);
        Light(mouthLight, mouthEnergy, At(mouthRow, 1));
        Light(hitLight, hitEnergy, At(impactRow, 1));

        muzzleFade = flash * fade;
        float burst = index > 0 ? Env(F(cfg, "strike_decay")) : 0f;
        strikeFade = burst * fade * Mathf.Clamp01((reveal - 0.9f) * 10f);
    }

    void Light(Light light, float energy, float range)
    {
        light.intensity = energy * Mathf.PI * exposureUnit * lightMatch;
        light.range = range * scale;
    }

    void Stroke()
    {
        index++;
        since = 0f;
        reveal = 1f;
        RollBranches();
        crackle = Opt("reroll", 0f);
        dirty = true;
        next = t + F(cfg, "stroke_gap") + (float)rng.Randf() * F(cfg, "gap_jitter");
        if (next > end - F(cfg, "end_margin")) next = float.PositiveInfinity;
        Impact();
        stroked?.Invoke(hit);
    }

    // scenes/bolt_impact.gd: what each stroke throws where it lands.
    void Impact()
    {
        Vector3 up = Vector3.up * scale;
        int sparks = (int)S.Num.I(cfg["impact_sparks"]);
        for (int i = 0; i < sparks; i++) fx.Sparks(hit + up * i);
        int ends = (int)S.Num.I(cfg["branch_sparks"]);
        for (int i = 0; i < ends && i < branches.Count; i++) fx.Sparks(branches[i].end);
        float dust = F(row, "dust") * scale;
        fx.Dust(new Vector3(hit.x, 0.4f, hit.z), dust);
        float radius = F(row, "ring") * scale;
        fx.Shockwave(new Vector3(hit.x, 0f, hit.z), radius);
        int puffs = (int)S.Num.I(row["ring_puffs"]);
        for (int i = 0; i < puffs; i++)
        {
            float a = Mathf.PI * 2f * i / puffs;
            fx.Dust(new Vector3(hit.x + Mathf.Cos(a) * radius * 0.6f, 0.4f, hit.z + Mathf.Sin(a) * radius * 0.6f), dust * 0.5f);
        }
    }

    // scenes/bolt_arcs.gd: side arcs along the bolt's back; the breath's row has none.
    void StepArcs(float dt)
    {
        int count = (int)S.Num.I(row["arcs"]);
        arcWait -= dt;
        if (count == 0 || arcWait > 0f) return;
        arcWait = F(cfg, "arc_every");
        arcs.Clear();
        Vector3 flat = mouth - hit;
        flat.y = 0f;
        Vector3 back = flat.normalized, side = Vector3.Cross(back, Vector3.up);
        for (int i = 0; i < count; i++)
        {
            float along = Range(rng, 0.5f, F(row, "arc_reach")) * scale;
            Vector3 from = mouth + back * along + Vector3.up * (Range(rng, 0.2f, 1.8f) * scale);
            Vector3 way = (back + side * Range(rng, -0.8f, 0.8f) + Vector3.up * Range(rng, -0.3f, 0.6f)).normalized;
            Vector3 to = from + way * (Range(rng, 1.5f, 3f) * scale);
            arcs.Add(BoltShape.Place(BoltShape.Channel(rng, HOP_ROUNDS, 0.15f), from, to));
        }
        dirty = true;
    }

    // scenes/bolt_branches.gd roll.
    void RollBranches()
    {
        branches.Clear();
        if (cone == null && ends == null) return;
        List<Vector3> main = MainWorld();
        S.GArray<S.Variant> range = row["branches"];
        int n = Roll(rng, range);
        List<Vector3> targets = ends != null ? ends(rng, n) : BoltShape.FanEnds(rng, cone, n, F(row, "fan_spread"), F(row, "fan_near"));
        int branchDepth = (int)S.Num.I(cfg["branch_depth"]);
        float branchSway = F(row, "branch_sway");
        foreach (Vector3 target in targets)
        {
            float at = Anchor(target);
            branches.Add(new BoltBranch { t = at, end = Stopped(BoltShape.AtT(main, at), target), shape = BoltShape.Channel(rng, branchDepth, branchSway), of = -1 });
        }
        int subs = Mathf.Min((int)S.Num.I(row["sub_forks"]), branches.Count);
        for (int k = 0; k < subs; k++) SubFork(k, main, branchDepth, branchSway);
        Strands(main, branchDepth);
        Pool(branchDepth);
    }

    float Anchor(Vector3 target)
    {
        S.GArray<S.Variant> from = row["branch_from"];
        float lo = At(from, 0), hi = At(from, 1);
        if (!S.Gd.Str(row["anchor_near"]).Equals("true", StringComparison.OrdinalIgnoreCase)) return Range(rng, lo, hi);
        Vector3 axis = hit - mouth;
        float along = Vector3.Dot(target - mouth, axis) / Mathf.Max(axis.sqrMagnitude, 0.001f);
        return Mathf.Clamp(along - F(row, "anchor_back"), lo, hi);
    }

    Vector3 Stopped(Vector3 from, Vector3 to)
    {
        if (blocker == null) return to;
        Vector3 span = to - from;
        return from + span * blocker(from, span);
    }

    Vector3 Kept(Vector3 p) => cone != null ? BoltShape.ClampToCone(p, cone) : p;

    void SubFork(int k, List<Vector3> main, int depth, float sway)
    {
        const float AT = 0.55f, TURN = 0.7f, LENGTH = 0.9f;
        BoltBranch parent = branches[k];
        Vector3 mid = Vector3.Lerp(BoltShape.AtT(main, parent.t), parent.end, AT);
        float turn = (float)rng.Randf() < 0.5f ? TURN : -TURN;
        Vector3 end = Kept(mid + Turn(parent.end - mid, turn) * LENGTH);
        branches.Add(new BoltBranch { t = AT, end = Stopped(mid, end), shape = BoltShape.Channel(rng, depth, sway), of = k });
    }

    // Godot's Vector3.rotated(UP, angle).
    static Vector3 Turn(Vector3 v, float angle)
    {
        float c = Mathf.Cos(angle), s = Mathf.Sin(angle);
        return new Vector3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
    }

    void Strands(List<Vector3> main, int depth)
    {
        if (!row.Has("strands")) return;
        S.GArray<S.Variant> range = row["strands"];
        int count = Roll(rng, range);
        float reach = Opt("strand_spread", 0f) * scale, sway = Opt("strand_sway", DEFAULT_STRAND_SWAY);
        for (int i = 0; i < count; i++)
        {
            var off = new Vector3(Range(rng, -1f, 1f), Range(rng, -0.5f, 1f), Range(rng, -1f, 1f));
            Vector3 end = Kept(hit + Vector3.ClampMagnitude(off, 1f) * reach);
            branches.Add(new BoltBranch { t = 0f, end = Stopped(BoltShape.AtT(main, 0f), end), shape = BoltShape.Channel(rng, depth, sway), of = -1 });
        }
    }

    // The lightning spreading across the street where it lands, climbing what it meets.
    void Pool(int depth)
    {
        if (!row.Has("pool")) return;
        int count = (int)S.Num.I(row["pool"]);
        float radius = Opt("pool_radius", 0f) * scale, sway = Opt("strand_sway", DEFAULT_STRAND_SWAY);
        float y = cone != null ? cone.y : hit.y;
        int chain = (int)Opt("chain", 0f);
        float chainStep = Opt("chain_step", 0f) * scale;
        for (int i = 0; i < count; i++)
        {
            float ang = Mathf.PI * 2f * (i + (float)rng.Randf()) / count;
            float d = Range(rng, 0.35f, 1f) * radius;
            Vector3 end = Kept(new Vector3(hit.x + Mathf.Cos(ang) * d, y, hit.z + Mathf.Sin(ang) * d));
            branches.Add(new BoltBranch { t = 1f, end = end, shape = BoltShape.Channel(rng, depth, sway), of = -1 });
            Vector3 prev = end;
            bool climbing = false;
            for (int hop = 0; hop < chain; hop++)
            {
                float turn = ang + Range(rng, -1f, 1f);
                float step = Range(rng, 0.5f, 1f) * chainStep;
                Vector3 way = new Vector3(Mathf.Cos(turn), 0f, Mathf.Sin(turn)) * step;
                Vector3 nextAt = climbing ? prev + way * 0.4f + Vector3.up * step : Kept(prev + way);
                if (!climbing)
                {
                    Vector3 met = Stopped(prev, nextAt);
                    climbing = Vector3.Distance(met, nextAt) > 0.01f;
                    nextAt = met;
                }
                branches.Add(new BoltBranch { t = 1f, end = nextAt, shape = BoltShape.Channel(rng, depth, sway), of = branches.Count - 1 });
                prev = nextAt;
            }
        }
    }

    Vector3 ClearOfHead() => mouth + (hit - mouth).normalized * (F(row, "clear") * scale);

    List<Vector3> MainWorld()
    {
        List<Vector3> line = BoltShape.Place(mainShape, ClearOfHead(), hit);
        float bow = F(row, "bow") * Vector3.Distance(line[0], line[line.Count - 1]);
        for (int i = 1; i < line.Count - 1; i++)
        {
            Vector3 p = line[i] + Vector3.up * (bow * Mathf.Sin(Mathf.PI * i / (line.Count - 1)));
            line[i] = Kept(p);
        }
        return line;
    }

    void Rebuild()
    {
        dirty = false;
        List<Vector3> main = MainWorld();
        drawnBranches.Clear();
        foreach (BoltBranch b in branches)
        {
            List<Vector3> host = b.of < 0 ? main : drawnBranches[b.of];
            if (host.Count < 2 || (b.of < 0 && b.t > reveal))
            {
                drawnBranches.Add(new List<Vector3>());
                continue;
            }
            List<Vector3> placed = BoltShape.Place(b.shape, BoltShape.AtT(host, b.t), b.end);
            for (int i = 1; i < placed.Count - 1; i++) placed[i] = Kept(placed[i]);
            drawnBranches.Add(placed);
        }
        var all = new List<List<Vector3>>(drawnBranches.Count + 1) { BoltShape.Cut(main, reveal) };
        all.AddRange(drawnBranches);
        if (wallCut != null) all = wallCut(all);
        List<Vector3> drawn = all[0];
        all.RemoveAt(0);
        mainView.Rebuild(new List<List<Vector3>> { drawn }, 1f, mainTip, mouthShare, 1f);
        branchView.Rebuild(all, branchWidth, branchWidth * branchTip, 1f, branchTip);
        if (arcs.Count > 0) arcView.Rebuild(arcs);
        else arcView.Hide();

        Vector3 dir = (hit - mouth).normalized;
        Vector3 muzzle = ClearOfHead() + Vector3.up * (F(cfg, "muzzle_up") * scale);
        Vector3 strike = hit - dir * 0.6f + Vector3.up * (F(cfg, "strike_lift") * scale);
        float lift = scale * Mathf.Lerp(1f, power, F(cfg, "power_share"));
        Place(muzzleBlock, muzzle, F(cfg, "muzzle_flare") * lift);
        Place(strikeBlock, strike, F(cfg, "strike_flare") * F(row, "strike_scale") * lift);
        mouthLight.transform.position = new Vector3(mouth.x, mouth.y, -mouth.z);
        Vector3 back = hit - dir * (LIGHT_BACK * scale) + Vector3.up * (scale * 0.5f);
        hitLight.transform.position = new Vector3(back.x, back.y, -back.z);
    }

    static void Place(MaterialPropertyBlock block, Vector3 at, float size)
    {
        block.SetVector("_FlarePos", new Vector4(at.x, at.y, -at.z, size));
    }

    public void Dispose()
    {
        UnityEngine.Object.Destroy(flareMat);
        UnityEngine.Object.Destroy(quad);
    }
}

// scenes/standing_cut.gd: each line ends at the first chunk the sim left standing, so the bolt shows only
// where the city broke.
public sealed class StandingCut
{
    readonly S.RampageSim sim;
    readonly float step;
    readonly List<S.RampageSim.Building> near = new List<S.RampageSim.Building>();

    public StandingCut(S.RampageSim sim, float step)
    {
        this.sim = sim;
        this.step = step;
    }

    public List<List<Vector3>> Cut(List<List<Vector3>> lines)
    {
        float x0 = float.MaxValue, z0 = float.MaxValue, x1 = float.MinValue, z1 = float.MinValue;
        foreach (List<Vector3> line in lines)
            foreach (Vector3 p in line)
            {
                x0 = Mathf.Min(x0, p.x);
                z0 = Mathf.Min(z0, p.z);
                x1 = Mathf.Max(x1, p.x);
                z1 = Mathf.Max(z1, p.z);
            }
        near.Clear();
        for (int i = 0; i < sim.buildings.Size(); i++)
        {
            S.RampageSim.Building b = sim.buildings[i];
            if (b.frame.aliveCount <= 0) continue;
            float hw = (float)(double)b.w * 0.5f, hd = (float)(double)b.d * 0.5f, bx = (float)(double)b.x, bz = (float)(double)b.z;
            if (bx + hw >= x0 && bx - hw <= x1 && bz + hd >= z0 && bz - hd <= z1) near.Add(b);
        }
        var o = new List<List<Vector3>>(lines.Count);
        foreach (List<Vector3> line in lines) o.Add(CutLine(line));
        return o;
    }

    List<Vector3> CutLine(List<Vector3> line)
    {
        if (line.Count < 2) return line;
        var o = new List<Vector3>(line.Count);
        if (Standing(line[0])) return o;
        o.Add(line[0]);
        for (int k = 1; k < line.Count; k++)
        {
            Vector3 a = line[k - 1], seg = line[k] - a;
            int n = Mathf.Max(1, Mathf.CeilToInt(seg.magnitude / step));
            for (int j = 1; j <= n; j++)
            {
                if (!Standing(a + seg * ((float)j / n))) continue;
                o.Add(a + seg * ((float)(j - 1) / n));
                return o;
            }
            o.Add(line[k]);
        }
        return o;
    }

    bool Standing(Vector3 p)
    {
        foreach (S.RampageSim.Building b in near)
        {
            float lx = p.x - ((float)(double)b.x - (float)(double)b.w * 0.5f);
            float lz = p.z - ((float)(double)b.z - (float)(double)b.d * 0.5f);
            float ly = p.y - (float)(double)b.@base;
            if (lx < 0f || lz < 0f || ly < 0f || lx >= (float)(double)b.w || lz >= (float)(double)b.d) continue;
            var cell = new S.Vector3i { x = Mathf.FloorToInt(lx), y = Mathf.FloorToInt(ly), z = Mathf.FloorToInt(lz) };
            if (b.frame.Alive(cell)) return true;
        }
        return false;
    }
}
