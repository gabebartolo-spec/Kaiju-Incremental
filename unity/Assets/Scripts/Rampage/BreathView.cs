using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The Lightning Breath on screen (scenes/rampage_ability.gd, ability_fx.gd, breath_beam.gd, spine_charge.gd):
// arcs climb the spine through the windup, the jaw opens, the bolt leaves the throat, sparks fly off the
// struck face and a scorched wedge covers the sim's hit cone. Reads the sim's events; decides nothing.
public sealed class BreathView : IDisposable
{
    // scenes/ability_fx.gd: first-hit steps, its smallest count, the wall-cut step, the spark burst.
    const float HIT_STEP = 0.5f, CUT_STEP = 0.25f, SPARK_LIFE = 0.7f, SPARK_BACK = 0.4f, SPARK_UP = 0.4f;
    const int HIT_STEPS_MIN = 4, SPARKS = 50, COVER_ROWS = 12;
    const float SCORCH_BASE = 3f, FEET_DROP = 0.5f, SPAN_LIFT = 0.5f;
    const string SPECIES = "reptilian";

    public int Breaths { get; private set; }
    public Action<Vector3> Stroked { set => rig.stroked = value; }

    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly Croc croc;
    readonly CityTrees trees;
    readonly int seed;
    readonly S.GDict tune, bolt;
    readonly BoltRig rig;
    readonly SpineCharge charge;
    readonly ScorchMarks scorch;
    readonly StandingCut cut;
    readonly Color tint;
    readonly float baseDamage, along, up;
    readonly List<S.RampageSim.Building> near = new List<S.RampageSim.Building>();
    Vector3 hit;
    int charges;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    public BreathView(S.RampageSim sim, CityFx fx, Croc croc, CityTrees trees, int seed, float exposureUnit, float lightMatch)
    {
        this.sim = sim;
        this.fx = fx;
        this.croc = croc;
        this.trees = trees;
        this.seed = seed;
        tune = S.Content.Section("fx");
        bolt = tune["bolt"];
        S.GDict species = S.Content.SpeciesDef(SPECIES);
        S.GDict colors = species["colors"], stats = species["stats"];
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(colors["eye"]), out tint);
        baseDamage = F(stats, "ability_damage");
        S.GArray<S.Variant> throat = bolt["throat"];
        along = (float)(double)S.Num.F(throat[0]);
        up = (float)(double)S.Num.F(throat[1]);
        float scale = (float)sim.BodyScale();
        Shader boltShader = Resources.Load<Shader>("Shaders/Bolt");
        cut = new StandingCut(sim, CUT_STEP);
        rig = new BoltRig("breath", boltShader, Resources.Load<Shader>("Shaders/Flare"), fx, scale, exposureUnit, lightMatch, bolt)
        {
            blocker = FirstHit,
            wallCut = cut.Cut,
        };
        charge = new SpineCharge(croc, boltShader, scale, bolt);
        scorch = new ScorchMarks(Resources.Load<Shader>("Shaders/Scorch"));
    }

    public void OnEvent(S.GDict e)
    {
        string type = S.Gd.Str(e["type"]);
        if (type == "strike_windup" && S.Gd.Str(e["kind"]) == S.Strikes.BREATH)
        {
            charge.Start(F(e, "strike_in"), (float)(double)S.Num.F(tune["beam_seconds"]), S.Seeds.Make("bolt_charge", seed * BoltRig.SEEDS_PER_RUN + charges));
            charges++;
        }
        else if (type == "strike_windup" && S.Gd.Str(e["kind"]) == S.Strikes.BEAM)
        {
            // scenes/thunder_beam.gd: the same arcs before the beam, whose own end shuts the jaw.
            charge.Start(F(e, "strike_in"), 0f, S.Seeds.Make("bolt_charge", seed * BoltRig.SEEDS_PER_RUN + charges));
            charges++;
        }
        else if (type == "ability")
        {
            croc.Roar();
            if (S.Gd.Str(e["kind"]) == "cone") Fire(e);
        }
    }

    // scenes/rampage_ability.gd play + ability_fx.gd breath.
    void Fire(S.GDict e)
    {
        float reach = F(e, "reach");
        S.Vector2 from = e["from"];
        var facing = new Vector3((float)(double)sim.facing.x, 0f, (float)(double)sim.facing.y);
        var snout = new Vector3((float)(double)from.x, 0f, (float)(double)from.y);
        Vector3 mouth = croc.ThroatAt(along, up);
        Vector3 span = snout + facing * reach + Vector3.up * SPAN_LIFT - mouth;
        hit = mouth + span * FirstHit(mouth, span);
        Vector3 dir = (hit - mouth).normalized;
        Vector3 target = mouth + span;
        var flat = new Vector3(target.x - snout.x, 0f, target.z - snout.z);
        S.GDict aim = S.BreathCone.Of(sim);
        float half = F(aim, "half_angle");
        float strength = Mathf.Clamp((float)(double)sim.Stat("ability_damage") / Mathf.Max(baseDamage, 0.001f), 1f, F(tune, "power_max"));

        rig.cone = new BoltCone { origin = snout, dir = flat.normalized, reach = flat.magnitude, half = half, y = target.y };
        rig.power = strength;
        rig.Aim(mouth, hit);
        rig.Play(F(tune, "beam_seconds"), S.Seeds.Make("breath_bolt", seed * BoltRig.SEEDS_PER_RUN + Breaths));
        Breaths++;

        fx.AimedSparks(tint.linear, -dir + Vector3.up * SPARK_UP, hit - dir * SPARK_BACK, Mathf.RoundToInt(SPARKS * strength), SPARK_LIFE);
        scorch.Add(new Vector3(snout.x, target.y - FEET_DROP, snout.z), flat.normalized, flat.magnitude * 2f, half, F(tune, "scorch_seconds"), F(tune, "scorch_soot_in"), F(tune, "scorch_glow_in"),
            (SCORCH_BASE + strength) * F(tune, "scorch_glow_mult"), tint.linear);

        // Whatever the breath burns goes down with it (scenes/city_decor.gd crush_cone).
        trees.Crush(new Vector3((float)(double)sim.kaijuPos.x, 0f, (float)(double)sim.kaijuPos.y), reach * 0.5f);
        S.GArray<S.Vector3> cover = S.BreathCone.Cover(aim, COVER_ROWS);
        for (int i = 0; i < cover.Size(); i++)
        {
            S.Vector3 c = cover[i];
            trees.Crush(new Vector3((float)(double)c.x, 0f, (float)(double)c.y), (float)(double)c.z);
        }
        Debug.Log($"breath {Breaths} at frame {Time.frameCount}: snout {snout} facing {facing} mouth {mouth} hit {hit} reach {reach:F1} half {half:F2} power {strength:F2}");
    }

    // scenes/ability_fx.gd _first_hit: how far along the span the first standing chunk is, 0..1.
    float FirstHit(Vector3 from, Vector3 span)
    {
        int steps = Mathf.Max(HIT_STEPS_MIN, Mathf.CeilToInt(span.magnitude / HIT_STEP));
        NearLine(from, from + span);
        for (int i = 1; i <= steps; i++)
        {
            float t = (float)i / steps;
            Vector3 p = from + span * t;
            foreach (S.RampageSim.Building b in near)
            {
                float lx = p.x - ((float)(double)b.x - (float)(double)b.w * 0.5f);
                float lz = p.z - ((float)(double)b.z - (float)(double)b.d * 0.5f);
                if (lx < 0f || lz < 0f || lx >= (float)(double)b.w || lz >= (float)(double)b.d) continue;
                if (b.frame.TopBelow(Mathf.FloorToInt(lx), Mathf.FloorToInt(lz), (long)b.height) + 1 > p.y) return t;
            }
        }
        return 1f;
    }

    void NearLine(Vector3 a, Vector3 b)
    {
        near.Clear();
        float x0 = Mathf.Min(a.x, b.x), x1 = Mathf.Max(a.x, b.x), z0 = Mathf.Min(a.z, b.z), z1 = Mathf.Max(a.z, b.z);
        for (int i = 0; i < sim.buildings.Size(); i++)
        {
            S.RampageSim.Building k = sim.buildings[i];
            float hw = (float)(double)k.w * 0.5f, hd = (float)(double)k.d * 0.5f, x = (float)(double)k.x, z = (float)(double)k.z;
            if (x + hw >= x0 && x - hw <= x1 && z + hd >= z0 && z - hd <= z1) near.Add(k);
        }
    }

    // After the pose for this frame: the bolt's root stays on the jaw as the head moves.
    public void Step(float dt)
    {
        if (rig.Live) rig.Aim(croc.ThroatAt(along, up), hit);
        rig.Step(dt);
        rig.Draw();
        charge.Step(dt);
        scorch.Step(dt);
    }

    public void Dispose()
    {
        rig.Dispose();
        scorch.Dispose();
    }
}

// scenes/spine_charge.gd: the windup's arcs hop up the ridge, tail to head, and the jaw opens before the strike.
public sealed class SpineCharge
{
    readonly Croc croc;
    readonly S.GDict cfg;
    readonly BoltView view;
    readonly List<List<Vector3>> lines = new List<List<Vector3>>();
    readonly float hopLife, every, jawBefore;
    S.RandomNumberGenerator rng;
    float t, wait, strike, lead, gap, jawShutAt = -1f, beamSeconds;
    bool live, jawOpened;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static float At(S.GArray<S.Variant> a, int i) => (float)(double)S.Num.F(a[i]);

    public SpineCharge(Croc croc, Shader boltShader, float scale, S.GDict bolt)
    {
        this.croc = croc;
        cfg = bolt["charge"];
        view = new BoltView(boltShader, F(cfg, "width") * scale, F(cfg, "min_px"), F(cfg, "alpha"), bolt);
        hopLife = F(cfg, "hop_life");
        every = F(cfg, "every");
        jawBefore = F(cfg, "jaw_before");
        S.GArray<S.Variant> middle = cfg["middle"], bones = cfg["bones"];
        var names = new List<string>();
        for (int i = 0; i < bones.Size(); i++) names.Add(S.Gd.Str(bones[i]));
        croc.FindRidge(names, At(middle, 0), At(middle, 1), F(cfg, "lift"));
    }

    public void Start(float strikeIn, float beam, S.RandomNumberGenerator stream)
    {
        rng = stream;
        t = 0f;
        wait = 0f;
        strike = strikeIn;
        beamSeconds = beam;
        jawOpened = false;
        int count = croc.RidgeSize - 1;
        live = count > 0 && strikeIn > hopLife;
        if (!live) return;
        lead = Mathf.Min(F(cfg, "lead_in"), strikeIn - hopLife);
        gap = (strikeIn - lead - hopLife) / Mathf.Max(1f, count - 1f);
    }

    public void Step(float dt)
    {
        if (jawShutAt > 0f)
        {
            jawShutAt -= dt;
            if (jawShutAt <= 0f) croc.JawOpen(false, jawBefore);
        }
        if (!live) return;
        t += dt;
        if (t >= strike)
        {
            live = false;
            view.Hide();
            jawShutAt = beamSeconds;
            return;
        }
        if (!jawOpened && t >= strike - jawBefore)
        {
            jawOpened = true;
            croc.JawOpen(true, jawBefore);
        }
        wait -= dt;
        if (wait <= 0f)
        {
            wait = every;
            Redraw();
        }
        view.Draw();
    }

    void Redraw()
    {
        lines.Clear();
        int rounds = (int)S.Num.I(cfg["rounds"]), forks = (int)S.Num.I(cfg["forks"]);
        float push = F(cfg, "push");
        S.GArray<S.Variant> fork = cfg["fork"], level = cfg["level"];
        for (int k = 0; k < croc.RidgeSize - 1; k++)
        {
            float start = lead + gap * k;
            if (t < start || t >= start + hopLife) continue;
            Vector3 a = croc.RidgeAt(k), b = croc.RidgeAt(k + 1);
            List<Vector3> arc = BoltShape.Place(BoltShape.Channel(rng, rounds, push), a, b);
            lines.Add(arc);
            for (int f = 0; f < forks; f++)
            {
                Vector3 from = BoltShape.AtT(arc, (float)rng.RandfRange(0.2, 0.8));
                float away = Vector3.Distance(a, b) * (float)rng.RandfRange(At(fork, 0), At(fork, 1));
                var way = new Vector3((float)rng.RandfRange(-1.0, 1.0), (float)rng.RandfRange(0.2, 1.0), (float)rng.RandfRange(-1.0, 1.0));
                lines.Add(BoltShape.Place(BoltShape.Channel(rng, 2, push), from, from + way.normalized * away));
            }
        }
        view.SetLevel((float)rng.RandfRange(At(level, 0), At(level, 1)));
        view.Rebuild(lines, 1f, 1f, 1f, 1f);
    }
}

// scenes/fx_decals.gd WEDGE: soot on whatever stands in the cone, with glowing cracks that cool. A box drawn
// over the depth buffer; the croc's stencil bit keeps it off the hide.
public sealed class ScorchMarks : IDisposable
{
    const int SIZE = 192, CRACKS = 9, NOISE_OCTAVES = 5;
    const float DEPTH = 14f, CENTRE_LIFT = 0.2f, NORMAL_FADE = 0.35f, NOISE_FREQ = 0.03f;
    const float GLOW_SHARE = 0.6f, FADE_SHARE = 0.4f;
    static readonly Vector3 SOOT = new Vector3(0.03f, 0.027f, 0.024f);

    sealed class Mark
    {
        public readonly MaterialPropertyBlock block = new MaterialPropertyBlock();
        public float age, seconds, sootIn, glowIn, energy;
    }

    readonly List<Mark> marks = new List<Mark>();
    readonly Mesh mesh;
    readonly Material mat;
    readonly Dictionary<int, Texture2D> wedges = new Dictionary<int, Texture2D>();

    public ScorchMarks(Shader shader)
    {
        mesh = SliceGame.CubeMesh(1f, false);
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 1e6f);
        mat = new Material(shader);
    }

    // feet: Godot axes, the wedge's apex; dir: flat Godot axes; size: the square it fills.
    public void Add(Vector3 feet, Vector3 dir, float size, float half, float seconds, float sootIn, float glowIn, float energy, Color tint)
    {
        var m = new Mark { seconds = seconds, sootIn = sootIn, glowIn = glowIn, energy = energy };
        Vector3 centre = feet + Vector3.up * (DEPTH * CENTRE_LIFT);
        m.block.SetTexture("_ScorchTex", Wedge(half));
        m.block.SetVector("_ScorchAt", new Vector4(centre.x, centre.y, -centre.z, size * 0.5f));
        m.block.SetVector("_ScorchDir", new Vector4(dir.x, dir.z, DEPTH * 0.5f, NORMAL_FADE));
        m.block.SetVector("_ScorchTint", tint);
        m.block.SetVector("_ScorchSoot", SOOT);
        marks.Add(m);
    }

    public void Step(float dt)
    {
        for (int i = marks.Count - 1; i >= 0; i--)
        {
            Mark m = marks[i];
            m.age += dt;
            float lastsGlow = m.glowIn + m.seconds * GLOW_SHARE;
            float lasts = lastsGlow + m.seconds * FADE_SHARE;
            if (m.age >= lasts)
            {
                marks.RemoveAt(i);
                continue;
            }
            float glow = m.age < m.glowIn ? m.age / m.glowIn : Mathf.Max(0f, 1f - (m.age - m.glowIn) / (m.seconds * GLOW_SHARE));
            float soot = Mathf.Min(1f, m.age / m.sootIn);
            if (m.age > lastsGlow) soot *= 1f - (m.age - lastsGlow) / (m.seconds * FADE_SHARE);
            m.block.SetFloat("_ScorchMix", soot);
            m.block.SetFloat("_ScorchGlow", glow * m.energy);
            Graphics.DrawMesh(mesh, Matrix4x4.identity, mat, 0, null, 0, m.block, ShadowCastingMode.Off, false);
        }
    }

    // FastNoiseLite's default (fractal simplex) is not in Unity; this fractal Perlin fills the same role.
    static float Noise(float x, float y)
    {
        float sum = 0f, amp = 1f, total = 0f, f = NOISE_FREQ;
        for (int i = 0; i < NOISE_OCTAVES; i++)
        {
            sum += (Mathf.PerlinNoise(x * f + 31.7f, y * f + 11.3f) * 2f - 1f) * amp;
            total += amp;
            amp *= 0.5f;
            f *= 2f;
        }
        return sum / total * 2f;
    }

    static float Smooth(float a, float b, float x)
    {
        float k = Mathf.Clamp01((x - a) / (b - a));
        return k * k * (3f - 2f * k);
    }

    // R soot shade, G cover, B the crack line. One per half angle, as fx_decals.gd caches.
    Texture2D Wedge(float half)
    {
        int key = Mathf.RoundToInt(half * 1000f);
        if (wedges.TryGetValue(key, out Texture2D made)) return made;
        var tex = new Texture2D(SIZE, SIZE, TextureFormat.RGBA32, false, true) { wrapMode = TextureWrapMode.Clamp };
        var px = new Color32[SIZE * SIZE];
        for (int y = 0; y < SIZE; y++)
            for (int x = 0; x < SIZE; x++)
            {
                float px0 = (float)x / (SIZE - 1) * 2f - 1f, py0 = (float)y / (SIZE - 1) * 2f - 1f;
                float r = Mathf.Sqrt(px0 * px0 + py0 * py0);
                float ang = Mathf.Atan2(px0, -py0);
                float n = Mathf.Clamp01(Noise(x, y) * 0.5f + 0.5f);
                float edge = (n - 0.5f) * 0.3f;
                float mask = 1f - Smooth(0.55f, 1f, r + edge);
                mask *= 1f - Smooth(half * 0.8f, half * 1.1f, Mathf.Abs(ang) + edge * 0.3f);
                mask *= Smooth(0.02f, 0.12f, r);
                float line = Crack(ang, r);
                line = Mathf.Max(line, Mathf.Exp(-ang * ang * 40f) * (1f - r) * 0.8f);
                line = Mathf.Clamp01(line) * mask;
                float shade = 0.6f + 0.8f * n;
                float alpha = Mathf.Clamp01(mask * (0.65f + 0.35f * n) + line * 0.5f);
                // Shade runs to 1.4: stored halved, the shader doubles it.
                px[y * SIZE + x] = new Color32((byte)(shade * 0.5f * 255f), (byte)(alpha * 255f), (byte)(line * 255f), 255);
            }
        tex.SetPixels32(px);
        tex.Apply(false, true);
        wedges[key] = tex;
        return tex;
    }

    static float Crack(float ang, float r)
    {
        float laneF = ang * CRACKS / (Mathf.PI * 2f);
        float wander = Noise(r * 60f, Mathf.Floor(laneF) * 17f) * 0.6f;
        float lane = Mathf.Repeat(laneF + wander * r, 1f);
        float toCrack = 0.5f - Mathf.Abs(lane - 0.5f);
        float width = 0.04f + 0.05f * r;
        return (1f - Smooth(width * 0.4f, width, toCrack)) * Smooth(0.05f, 0.18f, r);
    }

    public void Dispose()
    {
        UnityEngine.Object.Destroy(mesh);
        UnityEngine.Object.Destroy(mat);
        foreach (Texture2D t in wedges.Values) UnityEngine.Object.Destroy(t);
    }
}
