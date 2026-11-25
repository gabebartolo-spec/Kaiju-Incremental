using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// scenes/heli_fx.gd: the recipes a downed helicopter is drawn with (ArmyView.HeliWreck), each an existing family: the
// flash is the flare shader (Shaders/Flare, no rays), the fireball is the flame's voxels thrown in a ball, the smoke is
// the fires' own smoke ramp on the burst quads. Numbers: tuning "heli_wreck"; the recipes' own literals are named
// below. Godot axes in. Differences from Godot: Bursts emits from a box (the sphere's radius on each axis), draws no
// particle spin (the smoke's ±40°), and grades the fireball's cubes by height as flame.gdshader does, without the
// tongue's rim.
public sealed partial class CityFx
{
    // heli_fx.gd FLASH_TINT: the shell-hit orange-white.
    static readonly Color FLASH_TINT = Hex("ffb468");
    // fireball: every direction, damped 0.4..0.9, scale 0.8..1.2 shrinking to 0.1 over its life, fading in by 0.06
    // and out from 0.8 (its ramp is only that fade: the colour is flame.gdshader's, by height).
    const float BALL_SPREAD = 180f, BALL_DMIN = 0.4f, BALL_DMAX = 0.9f, BALL_SMIN = 0.8f, BALL_SMAX = 1.2f, BALL_END = 0.1f;
    const float BALL_IN = 0.06f, BALL_OUT = 0.8f;
    // smoke_puff: a sphere 0.2 of its size, within 100° of up, 0.4..1 of smoke_speed, damped 0.8..1.6; 0.95 at once.
    const float PUFF_BOX = 0.2f, PUFF_SPREAD = 100f, PUFF_SLOW = 0.4f, PUFF_DMIN = 0.8f, PUFF_DMAX = 1.6f, PUFF_AT_ONCE = 0.95f;
    // smoke_trail: a sphere 0.15 of its size, within 60° of up, 0.3..1.2 m/s.
    const float TRAIL_BOX = 0.15f, TRAIL_SPREAD = 60f, TRAIL_VMIN = 0.3f, TRAIL_VMAX = 1.2f;
    // _smoke_mat: 0.7 of the wind plus 1.6 m/s2 up; scale 0.7..1.2 growing 0.5 to 1.7; the ramp's stops.
    const float SMOKE_WIND = 0.7f, SMOKE_RISE = 1.6f, SMOKE_SMIN = 0.7f, SMOKE_SMAX = 1.2f, SMOKE_FROM = 0.5f, SMOKE_TO = 1.7f;
    static readonly float[] SMOKE_AT = { 0f, 0.08f, 0.45f, 1f };
    // fire.gd SMOKE_COLORS: the stops the young smoke's warm and mid replace.
    const int SMOKE_WARM = 1, SMOKE_MID = 2, SMOKE_LAST = 3;
    // The flash quad is placed by its shader: bounds that never cull it.
    const float FLARE_BOUNDS = 1e6f;

    sealed class HeliFlash
    {
        public Vector3 at;
        public float size, born, seconds;
    }

    // A wreck's smoke trail: puffs left behind it at trail_puffs every trail_smoke_seconds, until End.
    public sealed class HeliTrail
    {
        internal float carry;
        internal bool on = true;

        public void End() => on = false;
    }

    readonly List<HeliFlash> heliFlashes = new List<HeliFlash>();
    S.GDict heliCfg;
    BurstStyle heliBall, heliPuff, heliTrail;
    Material flareMat;
    Mesh flareQuad;
    MaterialPropertyBlock flareBlock;

    S.GDict HeliCfg => heliCfg ??= S.Content.Section("heli_wreck");

    float H(string key) => F(HeliCfg, key);

    // flare: a hot core and halo `size` metres across at `at`, fading out over `seconds` (Reduce flashing scales it).
    public void HeliFlare(Vector3 at, float size, float seconds) =>
        heliFlashes.Add(new HeliFlash { at = at, size = size, born = Now, seconds = seconds });

    // fireball: a ball of the flame's voxels thrown out every way from fireball_radius, slowing as it blooms and climbing
    // with fireball_rise; `scale` multiplies how many and how far.
    public void HeliFireball(Vector3 at, float scale = 1f)
    {
        if (heliBall == null)
        {
            // flame.gdshader heat: the flame's (fire.json flame_heat), under the bloom threshold.
            heliBall = new BurstStyle
            {
                glow = true, spread = BALL_SPREAD, dmin = BALL_DMIN, dmax = BALL_DMAX, smin = BALL_SMIN, smax = BALL_SMAX,
                heat = fires.Tuning.flame_heat,
            }.Size(0f, 1f, 1f, BALL_END).Colors(new[] { 0f, BALL_IN, BALL_OUT, 1f }, Color.clear, Color.white, Color.white, Color.clear);
        }
        heliBall.flameH = H("fireball_flame_h") * scale;
        heliBall.unit = H("fireball_tongue") * fires.Tuning.tongue[0];
        heliBall.vmin = H("fireball_speed_min") * scale;
        heliBall.vmax = H("fireball_speed_max") * scale;
        heliBall.gravity = new Vector3(0f, H("fireball_rise"), 0f);
        float life = H("fireball_seconds");
        bursts.Spawn(heliBall, at, Vector3.one * H("fireball_radius") * scale, Mathf.RoundToInt(H("fireball_tongues") * scale), life,
            (1f - H("fireball_spread")) * life, Now, Seed());
    }

    // smoke_puff: smoke_puffs quads smoke_size across billowing up and leaning with the wind.
    public void HeliSmoke(Vector3 at, float scale = 1f)
    {
        heliPuff ??= Smoke(PUFF_SPREAD, "smoke_warm", "smoke_mid", "smoke_self_lit", "smoke_alpha");
        float size = H("smoke_size") * scale;
        heliPuff.unit = size;
        heliPuff.vmin = H("smoke_speed") * PUFF_SLOW * scale;
        heliPuff.vmax = H("smoke_speed") * scale;
        heliPuff.dmin = PUFF_DMIN;
        heliPuff.dmax = PUFF_DMAX;
        float life = H("smoke_seconds");
        bursts.Spawn(heliPuff, at, Vector3.one * size * PUFF_BOX, Mathf.RoundToInt(H("smoke_puffs") * scale), life, (1f - PUFF_AT_ONCE) * life,
            Now, Seed());
    }

    public HeliTrail StartTrail() => new HeliTrail();

    // smoke_trail, one frame: the puffs born since the last frame, left in the air where the wreck is now (Godot's
    // trail is world-space particles at a steady rate).
    public void StepTrail(HeliTrail trail, Vector3 at, float dt)
    {
        if (!trail.on) return;
        heliTrail ??= Smoke(TRAIL_SPREAD, "trail_warm", "trail_mid", "trail_self_lit", "trail_alpha");
        float life = H("trail_smoke_seconds"), size = H("trail_smoke_size");
        trail.carry += H("trail_puffs") / life * dt;
        int born = Mathf.FloorToInt(trail.carry);
        if (born == 0) return;
        trail.carry -= born;
        heliTrail.unit = size;
        heliTrail.vmin = TRAIL_VMIN;
        heliTrail.vmax = TRAIL_VMAX;
        bursts.Spawn(heliTrail, at, Vector3.one * size * TRAIL_BOX, born, life, dt, Now, Seed());
    }

    // _smoke_mat and _smoke_quad: the fires' smoke ramp with its young stops warmed (`warm`, `mid`, thickened by
    // `alpha`), rising and leaning with the wind, part self-lit, keeping smoke_centre_keep at the screen's middle.
    BurstStyle Smoke(float spread, string warm, string mid, string selfLit, string alpha)
    {
        Color[] ramp = fires.Tuning.smoke_ramp;
        float thick = H(alpha);
        Color w = Hex(S.Gd.Str(HeliCfg[warm])), m = Hex(S.Gd.Str(HeliCfg[mid]));
        w.a = Mathf.Min(1f, ramp[SMOKE_WARM].a * thick);
        m.a = Mathf.Min(1f, ramp[SMOKE_MID].a * thick);
        float[] wind = fires.Tuning.wind;
        return new BurstStyle
        {
            spread = spread, smin = SMOKE_SMIN, smax = SMOKE_SMAX, selfLit = H(selfLit), keep = H("smoke_centre_keep"),
            gravity = new Vector3(wind[0], wind[1], wind[2]) * SMOKE_WIND + new Vector3(0f, SMOKE_RISE, 0f),
        }.Size(0f, SMOKE_FROM, 1f, SMOKE_TO).Colors(SMOKE_AT, ramp[0], w, m, ramp[SMOKE_LAST]);
    }

    // A fire carried along (a falling wreck's flames, a burning piece): `at` in Godot axes.
    public void MoveFire(Fires.Burning f, Vector3 at) => fires.Move(f, at);

    // Fire.go_out(): it stops at once.
    public void PutOut(Fires.Burning f) => Out(f, 0f);

    // A fire this view lit goes out over `fade` seconds (0: at once).
    void Out(Fires.Burning f, float fade)
    {
        if (burning.Remove(f)) fires.GoOut(f, fade, Now);
    }

    // Each frame: the live flashes, as RooftopView draws its muzzle flares.
    void DrawHeliFlashes()
    {
        if (heliFlashes.Count == 0) return;
        if (flareMat == null)
        {
            flareMat = new Material(Resources.Load<Shader>("Shaders/Flare"));
            flareQuad = new Mesh { name = "heli flare quad" };
            flareQuad.SetVertices(new[] { new Vector3(-1, -1, 0), new Vector3(1, -1, 0), new Vector3(1, 1, 0), new Vector3(-1, 1, 0) });
            flareQuad.SetTriangles(new[] { 0, 1, 2, 0, 2, 3 }, 0, false);
            flareQuad.bounds = new Bounds(Vector3.zero, Vector3.one * FLARE_BOUNDS);
            flareBlock = new MaterialPropertyBlock();
        }
        Vector4 tint = FLASH_TINT.linear;
        for (int i = heliFlashes.Count - 1; i >= 0; i--)
        {
            HeliFlash f = heliFlashes[i];
            float v = (Now - f.born) / f.seconds;
            if (v >= 1f)
            {
                heliFlashes.RemoveAt(i);
                continue;
            }
            flareBlock.Clear();
            flareBlock.SetVector("_FlarePos", new Vector4(f.at.x, f.at.y, -f.at.z, f.size));
            flareBlock.SetVector("_FlareTint", tint);
            flareBlock.SetFloat("_FlareFade", (1f - v) * SettingsApply.FlashScale);
            flareBlock.SetFloat("_FlareEdge", 0f);
            flareBlock.SetFloat("_FlareSoft", 0f);
            Graphics.DrawMesh(flareQuad, Matrix4x4.identity, flareMat, 0, null, 0, flareBlock, ShadowCastingMode.Off, false);
        }
    }

    void DisposeHeliFx()
    {
        if (flareMat != null) Object.Destroy(flareMat);
        if (flareQuad != null) Object.Destroy(flareQuad);
    }
}
