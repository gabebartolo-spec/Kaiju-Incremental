using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

// The rampage's effects, called in Godot axes (scenes/fx.gd, the fires and flashes of scenes/city_view.gd,
// the parts of scenes/blast_parts.gd). Presentation only: what happened comes from the sim's events.
public sealed class CityFx : IDisposable
{
    // scenes/fx.gd: the street's dust, by time of day.
    const string STREET_DUST = "8a6f4e", NIGHT_DUST = "6a5238";
    const float SUN_NIGHT = 0.35f, SUN_NOON = 1.6f;
    const float EXPLOSIVENESS = 0.9f;
    const float DUST_UNIT = 2.2f, PUFF_UNIT = 0.5f, STEP_UNIT = 3f, DUST_LIFE = 2.6f, PUFF_LIFE = 1.2f;
    const float DUST_LINE_STEP = 2.5f, DUST_LINE_LIFT = 0.5f, DUST_ALPHA = 0.47f;
    const int SLAM_PUFFS = 3;
    const float SLAM_SIZE = 0.6f, SLAM_SECONDS = 0.85f, SLAM_GROW = 0.15f, SLAM_PEAK = 0.18f, SLAM_HOLD = 0.4f;
    const int SPARK_COUNT = 28;
    const float SPARK_CUBE = 0.2f, SPARK_LIFE = 0.5f, SPARK_WHITE = 0.15f, SPARK_SPREAD = 35f, SPARK_DARKEN = 0.45f;
    const float RING_LIFT = 0.15f, RING_PLANE = 2.4f, RING_REACH = 1.2f;
    // scenes/fire.gd: Fire's own flame, what a blast is made of.
    const float FLAME_CUBE = 0.18f, FLAME_SCALE_MIN = 0.5f, FLAME_SCALE_MAX = 1.2f, EMBER_HEAT = 1.4f;
    static readonly float[] FLAME_AT = { 0f, 0.1f, 0.55f, 1f };
    static readonly Color SPARK_TINT = new Color(1f, 0.45f, 0.1f);

    readonly Bursts bursts;
    readonly Fires fires;
    readonly float exposureUnit, lightMatch;
    readonly int maxFires;
    readonly Color dustTone, dustLight;
    readonly float tintScale;
    readonly float ringScale, ringSeconds, ringAlpha, ringSoft, ringFootStart, stepAlpha, stepRise, stepSeconds;
    readonly int stepMaxLive;
    readonly System.Random rng;
    readonly List<Fires.Burning> burning = new List<Fires.Burning>();
    readonly Dictionary<long, List<KeyValuePair<S.Vector3i, Fires.Burning>>> chunkFires = new Dictionary<long, List<KeyValuePair<S.Vector3i, Fires.Burning>>>();
    readonly List<float> stepsEnd = new List<float>();
    readonly BurstStyle dust, tinted, step, slam, spark, flame, core, firework, cloud;
    readonly S.GDict blast;

    sealed class Flash
    {
        public Light light;
        public float energy, seconds, left;
    }
    readonly List<Flash> flashes = new List<Flash>();
    readonly Stack<Flash> flashPool = new Stack<Flash>();

    public float Now { get; private set; }
    public int LiveBursts => bursts.Count;
    public int LiveFires => burning.Count;

    static Color Hex(string hex)
    {
        ColorUtility.TryParseHtmlString("#" + hex, out Color c);
        return c;
    }

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static BurstStyle DustStyle(Color tone, float alpha) => new BurstStyle
    {
        spread = 70f, gravity = new Vector3(0, 0.6f, 0), vmin = 1.5f, vmax = 4f, dmin = 1.5f, dmax = 3f, smin = 1f, smax = 2.6f, unit = DUST_UNIT,
    }.Size(0f, 0.4f, 1f, 1.6f).Colors(new[] { 0f, 1f }, new Color(tone.r, tone.g, tone.b, alpha), new Color(tone.r, tone.g, tone.b, 0f));

    public CityFx(Shader burstShader, Fires fires, float sunEnergy, float exposureUnit, float lightMatch, int seed)
    {
        bursts = new Bursts(burstShader);
        this.fires = fires;
        this.exposureUnit = exposureUnit;
        this.lightMatch = lightMatch;
        rng = new System.Random(seed);
        S.GDict tuning = S.Content.Tuning();
        S.GDict graphics = tuning["display"];
        graphics = graphics["graphics"];
        graphics = graphics["max"];
        maxFires = (int)S.Num.I(graphics["max_fires"]);
        S.GDict fx = S.Content.Section("fx");
        S.GDict ring = fx["shockwave"];
        ringScale = F(ring, "radius_scale");
        ringSeconds = F(ring, "seconds");
        ringAlpha = F(ring, "alpha");
        ringSoft = F(ring, "soft");
        ringFootStart = F(ring, "foot_start");
        S.GDict stepCfg = fx["footfall_dust"];
        stepAlpha = F(stepCfg, "alpha");
        stepRise = F(stepCfg, "rise");
        stepSeconds = F(stepCfg, "seconds");
        stepMaxLive = (int)S.Num.I(stepCfg["max_live"]);
        blast = S.Content.Section("blast_fx");

        float day = Mathf.Clamp01(Mathf.InverseLerp(SUN_NIGHT, SUN_NOON, sunEnergy));
        dustTone = Color.Lerp(Hex(NIGHT_DUST), Hex(STREET_DUST), day);
        dustLight = dustTone.linear;
        float night = F(fx, "tint_dust_night");
        tintScale = Mathf.Lerp(night, 1f, day * day);

        dust = DustStyle(dustLight, DUST_ALPHA);
        tinted = DustStyle(dustLight, DUST_ALPHA);
        var c = new Color(dustLight.r, dustLight.g, dustLight.b, stepAlpha);
        var c0 = new Color(c.r, c.g, c.b, 0f);
        step = new BurstStyle
        {
            spread = 55f, gravity = new Vector3(0, 0.2f, 0), vmin = 0.5f, vmax = stepRise, dmin = 1.5f, dmax = 3f, unit = STEP_UNIT, clear = 0f,
        }.Size(0f, 0.4f, 1f, 1.6f).Colors(new[] { 0f, 1f }, c, c0);
        slam = new BurstStyle
        {
            spread = 55f, gravity = new Vector3(0, 0.2f, 0), vmin = 0.5f, vmax = stepRise, dmin = 1.5f, dmax = 3f, unit = STEP_UNIT, clear = 0f,
        }.Size(0f, 0.4f, SLAM_GROW, 1f, SLAM_HOLD, 1.05f, 1f, 1.05f).Colors(new[] { 0f, SLAM_PEAK, 1f }, c0, c, c0);
        Color dark = Color.Lerp(SPARK_TINT, Color.black, SPARK_DARKEN);
        spark = new BurstStyle
        {
            glow = true, spread = SPARK_SPREAD, gravity = new Vector3(0, -18f, 0), vmin = 8f, vmax = 16f, dmin = 0.5f, dmax = 1.5f,
            smin = 0.6f, smax = 1f, unit = SPARK_CUBE, heat = EMBER_HEAT,
        }.Size(0f, 1f, 1f, 0f).Colors(new[] { 0f, SPARK_WHITE, 1f }, Color.white, SPARK_TINT, dark);
        flame = new BurstStyle { glow = true, unit = FLAME_CUBE, heat = EMBER_HEAT }.Size(0f, 1f, 1f, 0.1f)
            .Colors(FLAME_AT, Hex("fff0b8"), Hex("ff9a1e"), Hex("e04a0c"), Hex("3a1a10"));
        core = new BurstStyle { glow = true, spread = 180f }.Size(0f, 1f, 0.4f, 1.1f, 1f, 0.3f);
        firework = new BurstStyle { glow = true, spread = 180f, gravity = new Vector3(0, -4f, 0) }.Size(0f, 1f, 0.4f, 1f, 1f, 0.2f);
        cloud = new BurstStyle
        {
            spread = 90f, gravity = new Vector3(0.3f, 0.35f, 0.15f), vmin = 0.4f, vmax = 1.6f, dmin = 0.3f, dmax = 0.6f, selfLit = 0f,
        }.Colors(new[] { 0f, 0.15f, 0.6f, 1f }, new Color(1, 1, 1, 0f), new Color(1, 1, 1, 0.5f), new Color(1, 1, 1, 0.35f), new Color(1, 1, 1, 0f));
        S.GDict cloudCfg = blast["cloud"];
        S.GArray<S.Variant> boil = cloudCfg["boil"];
        S.GArray<S.Variant> shades = cloudCfg["shades"];
        var points = new float[(int)boil.Size() * 2];
        for (int i = 0; i < boil.Size(); i++)
        {
            S.GArray<S.Variant> point = boil[i];
            points[i * 2] = (float)(double)S.Num.F(point[0]);
            points[i * 2 + 1] = (float)(double)S.Num.F(point[1]);
        }
        cloud.Size(points);
        for (int i = 0; i < cloud.shades.Length && i < shades.Size(); i++) cloud.shades[i] = Hex(S.Gd.Str(shades[i]));
    }

    float Rand(float lo, float hi) => lo + (float)rng.NextDouble() * (hi - lo);
    float Seed() => (float)rng.NextDouble() * 10f;

    // A burst in the caller's own style (the intro's spray).
    public void Spray(BurstStyle style, Vector3 at, Vector3 box, int count, float life, float window) => bursts.Spawn(style, at, box, count, life, window, Now, Seed());

    public void Tick(float time, float dt)
    {
        Now = time;
        for (int i = flashes.Count - 1; i >= 0; i--)
        {
            Flash f = flashes[i];
            f.left -= dt;
            if (f.left <= 0f)
            {
                f.light.gameObject.SetActive(false);
                flashes.RemoveAt(i);
                flashPool.Push(f);
                continue;
            }
            f.light.intensity = f.energy * (f.left / f.seconds) * Mathf.PI * exposureUnit * lightMatch;
        }
        for (int i = stepsEnd.Count - 1; i >= 0; i--)
            if (stepsEnd[i] <= time) stepsEnd.RemoveAt(i);
    }

    public void Draw(float time)
    {
        bursts.Draw(time);
        fires.Draw(time);
    }

    public void SetFocus(float depth) => fires.SetFocus(depth);

    // A billowing dust cloud; size ~ the width of what came down. tint: a toppled tower's pale concrete.
    public void Dust(Vector3 at, float size, bool hasTint = false, Color tint = default)
    {
        BurstStyle s = dust;
        if (hasTint)
        {
            s = tinted;
            s.Colors(new[] { 0f, 1f }, new Color(tint.r * tintScale, tint.g * tintScale, tint.b * tintScale, tint.a), new Color(tint.r * tintScale, tint.g * tintScale, tint.b * tintScale, 0f));
        }
        s.unit = DUST_UNIT;
        s.vmin = 1.5f;
        s.vmax = 4f;
        bursts.Spawn(s, at, new Vector3(size, 0.4f, size), Mathf.RoundToInt(12f * Mathf.Clamp(size, 0.5f, 4f)), DUST_LIFE, (1f - EXPLOSIVENESS) * DUST_LIFE, Now, Seed());
    }

    // A small puff: a person crushed underfoot, a wreck's dust.
    public void Puff(Vector3 at)
    {
        dust.unit = PUFF_UNIT;
        dust.vmin = 0.4f;
        dust.vmax = 1f;
        bursts.Spawn(dust, at, new Vector3(0.2f, 0.1f, 0.2f), 6, PUFF_LIFE, (1f - EXPLOSIVENESS) * PUFF_LIFE, Now, Seed());
    }

    // Short-lived and thin, a puff per step; skipped while max_live are still up.
    public void Footfall(Vector3 at, float size)
    {
        if (stepsEnd.Count >= stepMaxLive) return;
        step.smin = 0.8f * size;
        step.smax = 1.3f * size;
        bursts.Spawn(step, at, new Vector3(size * 0.6f, 0.2f, size * 0.6f), Mathf.RoundToInt(6f * Mathf.Clamp(size, 0.5f, 3f)), stepSeconds, (1f - EXPLOSIVENESS) * stepSeconds, Now, Seed());
        stepsEnd.Add(Now + stepSeconds);
    }

    public void DustLine(Vector3 from, Vector3 to, float width, bool hasTint = false, Color tint = default)
    {
        int steps = Mathf.Max(2, Mathf.CeilToInt(Vector3.Distance(from, to) / DUST_LINE_STEP));
        for (int i = 0; i <= steps; i++)
            Dust(Vector3.Lerp(from, to, (float)i / steps) + Vector3.up * DUST_LINE_LIFT, width * 0.6f, hasTint, tint);
    }

    // scenes/fx_particles.gd sparks(tint) with a direction: the breath's burst off the struck face.
    public void AimedSparks(Color tint, Vector3 aim, Vector3 at, int count, float life)
    {
        Color dark = Color.Lerp(tint, Color.black, SPARK_DARKEN);
        var style = new BurstStyle
        {
            glow = true, aim = aim, spread = SPARK_SPREAD, gravity = new Vector3(0, -18f, 0), vmin = 8f, vmax = 16f, dmin = 0.5f, dmax = 1.5f,
            smin = 0.6f, smax = 1f, unit = SPARK_CUBE, heat = EMBER_HEAT,
        }.Size(0f, 1f, 1f, 0f).Colors(new[] { 0f, SPARK_WHITE, 1f }, Color.white, tint, dark);
        Spray(style, at, Vector3.zero, count, life, (1f - EXPLOSIVENESS) * life);
    }

    public void Sparks(Vector3 at) => bursts.Spawn(spark, at, Vector3.zero, SPARK_COUNT, SPARK_LIFE, (1f - EXPLOSIVENESS) * SPARK_LIFE, Now, Seed());

    public void Shockwave(Vector3 at, float radius, bool tail = false, bool foot = false)
    {
        if (tail)
        {
            SlamPuff(at + Vector3.up * 0.2f, radius * SLAM_SIZE);
            for (int k = 0; k < SLAM_PUFFS; k++)
            {
                float a = Mathf.PI * 2f * k / SLAM_PUFFS;
                SlamPuff(at + new Vector3(Mathf.Cos(a), 0.4f, Mathf.Sin(a)) * radius * 0.35f, radius * SLAM_SIZE * 0.8f);
            }
            return;
        }
        bursts.Ring(at + Vector3.up * RING_LIFT, radius * ringScale * RING_PLANE * 0.5f, foot ? ringFootStart : 0f, ringSeconds, dustTone.linear, ringAlpha, ringSoft, Now);
    }

    public void ShockwaveTo(Vector3 at, float reach) => Shockwave(at, reach / (ringScale * RING_REACH));

    void SlamPuff(Vector3 at, float size)
    {
        slam.smin = 0.4f * size;
        slam.smax = 0.8f * size;
        bursts.Spawn(slam, at, new Vector3(size * 0.6f, 0.2f, size * 0.6f), Mathf.RoundToInt(6f * Mathf.Clamp(size, 0.5f, 3f)), SLAM_SECONDS, (1f - EXPLOSIVENESS) * SLAM_SECONDS, Now, Seed());
    }

    // A fire that keeps burning; past the cap the oldest goes out. seconds > 0: it goes out by itself.
    public Fires.Burning Fire(Vector3 at, float size, float seconds = 0f)
    {
        Fires.Burning f = fires.Light(at, size, Seed(), Now);
        burning.Add(f);
        if (burning.Count > maxFires)
        {
            fires.GoOut(burning[0], 0f, Now);
            burning.RemoveAt(0);
        }
        if (seconds > 0f) timed.Add(new KeyValuePair<float, Fires.Burning>(Now + seconds, f));
        return f;
    }

    readonly List<KeyValuePair<float, Fires.Burning>> timed = new List<KeyValuePair<float, Fires.Burning>>();

    public void PutOutExpired()
    {
        for (int i = timed.Count - 1; i >= 0; i--)
        {
            if (timed[i].Key > Now) continue;
            Out(timed[i].Value, 0f);
            timed.RemoveAt(i);
        }
    }

    void Out(Fires.Burning f, float fade)
    {
        if (burning.Remove(f)) fires.GoOut(f, fade, Now);
    }

    // A fire the sim lit on one chunk: it goes out when that chunk breaks or falls.
    public void BurnChunk(long building, S.Vector3i cell, Vector3 at, float size)
    {
        if (!chunkFires.TryGetValue(building, out var list))
            chunkFires[building] = list = new List<KeyValuePair<S.Vector3i, Fires.Burning>>();
        list.Add(new KeyValuePair<S.Vector3i, Fires.Burning>(cell, Fire(at, size)));
    }

    // scenes/city_view.gd _broke: fires on those cells out, all of them if the building is gone.
    public void Broke(long building, S.GArray<S.Vector3i> cells, bool allGone, float fade)
    {
        if (!chunkFires.TryGetValue(building, out var list)) return;
        for (int i = list.Count - 1; i >= 0; i--)
        {
            bool hit = allGone;
            if (!hit)
            {
                for (int k = 0; k < cells.Size() && !hit; k++) hit = cells[k] == list[i].Key;
            }
            if (!hit) continue;
            Out(list[i].Value, fade);
            list.RemoveAt(i);
        }
    }

    // A short burst of real light (muzzle flash, explosion, breath).
    public void FlashLight(Vector3 at, Color color, float energy, float seconds)
    {
        Flash f;
        if (flashPool.Count > 0)
        {
            f = flashPool.Pop();
        }
        else
        {
            var go = new GameObject("flash");
            f = new Flash { light = go.AddComponent<Light>() };
            f.light.type = LightType.Point;
            f.light.shadows = LightShadows.None;
            f.light.lightUnit = UnityEngine.Rendering.LightUnit.Candela;
            go.AddComponent<HDAdditionalLightData>();
        }
        f.light.gameObject.SetActive(true);
        f.light.transform.position = new Vector3(at.x, at.y, -at.z);
        f.light.color = color;
        f.light.range = 3f + energy;
        f.energy = energy * SettingsApply.FlashScale;  // Reduce flashing (city_view.gd flash)
        f.seconds = seconds;
        f.left = seconds;
        f.light.intensity = f.energy * Mathf.PI * exposureUnit * lightMatch;
        flashes.Add(f);
    }

    public int LiveFlashes => flashes.Count;

    // scenes/blast_parts.gd fireball: Fire's flame voxels leaving the site's box, stopping top_scale site heights up.
    public void Fireball(Vector3 at, Vector3 half, float radius)
    {
        S.GDict cfg = blast["fireball"];
        float speed = radius * F(cfg, "speed_scale");
        float rise = Mathf.Max(0.4f, half.y * 2f * (F(cfg, "top_scale") - 1f));
        float grow = Mathf.Clamp(radius / 5f, 1f, 3f);
        flame.spread = F(cfg, "spread");
        flame.vmin = speed * 0.5f;
        flame.vmax = speed;
        flame.gravity = new Vector3(0, F(cfg, "lift"), 0);
        flame.dmin = speed * speed / (2f * rise);
        flame.dmax = flame.dmin * 1.3f;
        flame.smin = FLAME_SCALE_MIN * grow;
        flame.smax = FLAME_SCALE_MAX * grow;
        int amount = Mathf.RoundToInt(F(cfg, "amount") * Mathf.Clamp(radius / 5f, 0.5f, 1.6f));
        bursts.Spawn(flame, at, half, amount, F(cfg, "seconds"), F(cfg, "burst_seconds"), Now, Seed());
    }

    // The instant: white-hot voxels out of the whole site, gone in a few frames.
    public void Core(Vector3 at, Vector3 half, float radius)
    {
        S.GDict cfg = blast["core"];
        float seconds = F(cfg, "seconds");
        float strength = Mathf.Clamp(radius / F(cfg, "full_radius"), 0.5f, 1f);
        core.vmin = radius * F(cfg, "throw") * 0.5f / seconds;
        core.vmax = radius * F(cfg, "throw") / seconds;
        core.smin = 0.8f * radius * F(cfg, "size");
        core.smax = 1.2f * radius * F(cfg, "size");
        core.Colors(new[] { 0f, 1f }, new Color(2.2f * strength, 2f * strength, 1.25f * strength, strength), new Color(2f * strength, 1.2f * strength, 0.35f * strength, strength));
        int amount = Mathf.RoundToInt(F(cfg, "amount") * Mathf.Clamp(radius / 5f, 0.5f, 1.6f));
        bursts.Spawn(core, at, half, amount, seconds, 0f, Now, Seed());
    }

    public void Firework(Vector3 at, Color color)
    {
        S.GDict cfg = blast["fireworks"];
        float speed = F(cfg, "speed"), size = F(cfg, "spark_size");
        firework.vmin = speed * 0.8f;
        firework.vmax = speed;
        firework.dmin = speed * 0.45f;
        firework.dmax = speed * 0.6f;
        firework.smin = 0.8f * size;
        firework.smax = 1.2f * size;
        var hot = new Color(color.r * 1.5f, color.g * 1.5f, color.b * 1.5f, 1f);
        firework.Colors(new[] { 0f, 0.04f, 0.6f, 1f }, new Color(2f, 2f, 2f, 1f), hot, new Color(hot.r, hot.g, hot.b, 0.8f), new Color(color.r, color.g, color.b, 0f));
        bursts.Spawn(firework, at, Vector3.one * 0.3f, (int)S.Num.I(cfg["sparks"]), F(cfg, "seconds"), 0f, Now, Seed());
    }

    // The chem lab's gas: a burst at once, then a boil that stops a puff's life before the sim's cloud ends.
    public void ToxicCloud(Vector3 at, Vector3 half, float radius, float seconds)
    {
        S.GDict cfg = blast["cloud"];
        float wide = radius * F(cfg, "cloud_share");
        Vector3 box = half * F(cfg, "size_scale");
        box = new Vector3(Mathf.Max(box.x, wide), box.y, Mathf.Max(box.z, wide));
        S.GArray<S.Variant> puff = cfg["puff"];
        cloud.smin = (float)(double)S.Num.F(puff[0]);
        cloud.smax = (float)(double)S.Num.F(puff[1]);
        float life = F(cfg, "billow_seconds");
        bursts.Spawn(cloud, at, box, (int)S.Num.I(cfg["amount"]), life, 0.2f * life, Now, Seed());
        float boil = Mathf.Max(0.1f, seconds - life);
        bursts.Spawn(cloud, at, box, Mathf.RoundToInt((float)S.Num.I(cfg["boil_amount"]) * boil / life), life, boil, Now, Seed());
    }

    public void Dispose()
    {
        bursts.Dispose();
        fires.Dispose();
        foreach (Flash f in flashes) if (f.light != null) UnityEngine.Object.Destroy(f.light.gameObject);
        foreach (Flash f in flashPool) if (f.light != null) UnityEngine.Object.Destroy(f.light.gameObject);
    }
}
