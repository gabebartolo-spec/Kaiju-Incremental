using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The water before the kaiju breaks it (scenes/intro_water.gd, intro_crackle.gd): purple electricity
// skating over the surface, building until the head breaks it, then a burst of spray with the break and
// the same electricity climbing it. Paced by the sim's own rise, never the clock. Godot axes.
public sealed class IntroWater
{
    const float WATER_LIFT = 0.05f, SPEED_LOW = 0.6f, EXPLOSIVE_WINDOW = 0.05f;

    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly S.GDict cfg;
    readonly BoltView view;
    readonly BurstStyle spray;
    readonly S.RandomNumberGenerator rng = S.Seeds.Make("intro_crackle", 0);
    readonly List<List<Vector3>> arcs = new List<List<Vector3>>();
    readonly bool active;
    readonly float scale, breakAt, height;
    readonly Vector3 origin;
    float wait;
    float sinceBurst = float.PositiveInfinity;
    bool burstDone;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);
    float Rand() => (float)rng.Randf();

    static Color Tone(S.Variant v)
    {
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(v), out Color c);
        return c.linear;
    }

    // ahead: how far the head's crown stands ahead of the hips (world units).
    public IntroWater(S.RampageSim sim, CityFx fx, Shader boltShader, float ahead)
    {
        this.sim = sim;
        this.fx = fx;
        S.GDict intro = S.Content.Section("intro");
        cfg = intro["water"];
        active = sim.emerge.active;
        if (!active) return;
        scale = (float)sim.BodyScale();
        breakAt = (float)sim.emerge.BreakAt(sim);
        height = (float)sim.emerge.WaterY() + WATER_LIFT;
        origin = new Vector3((float)(double)sim.kaijuPos.x + (float)(double)sim.facing.x * ahead, height, (float)(double)sim.kaijuPos.y + (float)(double)sim.facing.y * ahead);
        S.GDict look = S.Content.Section("fx");
        S.GDict bolt = look["bolt"];
        view = new BoltView(boltShader, F(cfg, "crackle_width") * scale, F(bolt, "arc_min_px"), 1f, bolt);
        spray = SprayStyle();
    }

    BurstStyle SprayStyle()
    {
        float speed = F(cfg, "burst_speed") * scale;
        var style = new BurstStyle
        {
            gravity = new Vector3(0f, -F(cfg, "gravity") * scale, 0f),
            vmin = speed * SPEED_LOW,
            vmax = speed,
            spread = F(cfg, "burst_spread"),
            smin = F(cfg, "drop_min"),
            smax = 1f,
            unit = F(cfg, "drop") * scale,
            selfLit = 0f,
            clear = 0f,
        }.Size(0f, 1f).Colors(new[] { 0f, 1f }, Color.white, new Color(1f, 1f, 1f, 0f));
        S.GArray<S.Variant> colors = cfg["colors"];
        for (int i = 0; i < style.shades.Length; i++)
            style.shades[i] = Tone(colors[i]);
        return style;
    }

    public void Step(float dt)
    {
        if (!active) return;
        S.Emergence emerge = sim.emerge;
        float t = (float)emerge.Progress() * (float)emerge.Total();
        float from = F(cfg, "crackle_from_seconds");
        float build = 0f;
        if (emerge.active && !emerge.surfaced && t >= from)
            build = Mathf.Clamp((t - from) / Mathf.Max(0.001f, breakAt - from), 0.01f, 1f);
        var body = new Vector3((float)(double)sim.kaijuPos.x, height, (float)(double)sim.kaijuPos.y);
        if (emerge.surfaced && !burstDone)
        {
            burstDone = true;
            sinceBurst = 0f;
            float width = F(cfg, "width") * scale;
            float life = F(cfg, "life");
            fx.Spray(spray, body, Vector3.one * width, (int)S.Num.I(cfg["burst_amount"]), life, life * EXPLOSIVE_WINDOW);
        }
        sinceBurst += dt;
        Crackle(dt, build, Mathf.Clamp01(1f - sinceBurst / F(cfg, "burst_arc_seconds")), body);
        view.Draw();
    }

    void Crackle(float dt, float surface, float climb, Vector3 body)
    {
        wait -= dt;
        if (surface <= 0f && climb <= 0f)
        {
            view.Hide();
            return;
        }
        if (wait > 0f) return;
        wait = F(cfg, "crackle_every");
        arcs.Clear();
        if (surface > 0f)
        {
            S.GArray<S.Variant> counts = cfg["crackle_arcs"];
            int flat = Mathf.RoundToInt(Mathf.Lerp((float)(double)S.Num.F(counts[0]), (float)(double)S.Num.F(counts[1]), surface));
            for (int i = 0; i < flat; i++) arcs.Add(Skate());
        }
        if (climb > 0f)
        {
            int up = Mathf.CeilToInt(F(cfg, "burst_arcs") * climb);
            for (int i = 0; i < up; i++) arcs.Add(Climb(body));
        }
        view.Rebuild(arcs);
    }

    Vector2 Around(float reach)
    {
        float angle = Rand() * Mathf.PI * 2f;
        return new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * reach;
    }

    // One arc lying on the water: from a point within crackle_reach, up to crackle_length long.
    List<Vector3> Skate()
    {
        Vector2 at = Around(Rand() * F(cfg, "crackle_reach"));
        Vector2 way = Around(F(cfg, "crackle_length")) * Mathf.Lerp(0.5f, 1f, Rand());
        Vector3 a = origin + new Vector3(at.x, 0f, at.y) * scale;
        return Shape(a, a + new Vector3(way.x, 0f, way.y) * scale);
    }

    // One arc up the burst's column: from near its middle at the water to up to burst_arc_height.
    List<Vector3> Climb(Vector3 body)
    {
        float width = F(cfg, "width") * scale;
        Vector2 foot = Around(width * F(cfg, "burst_arc_foot"));
        Vector2 top = Around(width * F(cfg, "burst_arc_top"));
        float rise = F(cfg, "burst_arc_height") * scale * Mathf.Lerp(0.5f, 1f, Rand());
        return Shape(body + new Vector3(foot.x, 0f, foot.y), body + new Vector3(top.x, rise, top.y));
    }

    List<Vector3> Shape(Vector3 a, Vector3 b)
    {
        List<Vector3> shape = BoltShape.Channel(rng, (int)S.Num.I(cfg["crackle_rounds"]), F(cfg, "crackle_push"));
        return BoltShape.Place(shape, a, b);
    }
}
