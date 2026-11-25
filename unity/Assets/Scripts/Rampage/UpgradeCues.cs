using System;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The upgrades on screen (scenes/power_cues.gd and ability_fx.gd ready_pulse and regen): when the signature comes
// ready again (Signature Recharge) the eyes flare in the species' colour for half a second, a hot core and four short
// rays; while Regeneration heals, green rings run up the hide (rim.gdshader, Croc.SetRegen) and motes drift up off
// it. Reads the sim; decides nothing. Godot axes. The sounds are RampageAudio's (the same power_cues.gd).
public sealed class UpgradeCues : IDisposable
{
    // scenes/power_cues.gd and ability_fx.gd: the head (a height and a step ahead, per body scale), the flare's size
    // per body scale and seconds, and its rays (flare.gdshader ray_gain).
    const float HEAD_UP = 6f, HEAD_AHEAD = 1f, FLARE_SIZE = 3f, FLARE_SECONDS = 0.5f, FLARE_RAYS = 1.5f;
    // ability_fx.gd: the rim overlay's strength; the motes' height on the body (per body scale).
    const float RIM = 0.55f, MOTES_UP = 3f;
    // ability_fx.gd _regen and fx_particles.gd motes: 40 glow cubes of 0.14 m living 1.5 s, from a box (1, 2, 1) x body
    // scale, rising at 0.6-1.4 m/s within 15 degrees of straight up, gravity 0.8 up, damped 0.5-1.5, each 0.6-1 of
    // 1 + 0.3 x body scale and shrinking to nothing.
    const int MOTES = 40;
    const float MOTE_LIFE = 1.5f, MOTE_CUBE = 0.14f, MOTE_SPREAD = 15f, MOTE_V_MIN = 0.6f, MOTE_V_MAX = 1.4f, MOTE_RISE = 0.8f;
    const float MOTE_DAMP_MIN = 0.5f, MOTE_DAMP_MAX = 1.5f, MOTE_SCALE_MIN = 0.6f, MOTE_GROW = 0.3f, BOX_HIGH = 2f;
    // A continuous emitter as bursts: one every MOTE_STEP seconds, its share of the 40 spread over that step.
    const float MOTE_STEP = 0.25f, FAR_BOUNDS = 1e6f;

    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly Croc croc;
    readonly Color regenTint;
    readonly BurstStyle motes;
    readonly Mesh quad;
    readonly Material flareMat;
    readonly MaterialPropertyBlock flare = new MaterialPropertyBlock();
    readonly float scale;
    bool wasReady = true;
    float flareAge = -1f, moteWait;

    // Ready pulses so far, and whether it is healing now (captures).
    public int ReadyPulses { get; private set; }
    public bool Healing { get; private set; }

    // eye: the species' eye colour (sRGB), the flare's tint.
    public UpgradeCues(S.RampageSim sim, CityFx fx, Croc croc, Color eye)
    {
        this.sim = sim;
        this.fx = fx;
        this.croc = croc;
        scale = (float)sim.BodyScale();
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(S.Content.Section("fx")["regen_tint"]), out regenTint);
        motes = new BurstStyle
        {
            glow = true, spread = MOTE_SPREAD, gravity = new Vector3(0f, MOTE_RISE, 0f), vmin = MOTE_V_MIN, vmax = MOTE_V_MAX,
            dmin = MOTE_DAMP_MIN, dmax = MOTE_DAMP_MAX, smin = MOTE_SCALE_MIN, smax = 1f, unit = MOTE_CUBE * (1f + MOTE_GROW * scale),
        }.Size(0f, 1f, 1f, 0f).Colors(new[] { 0f, 1f }, regenTint.linear, new Color(regenTint.linear.r, regenTint.linear.g, regenTint.linear.b, 0f));
        quad = new Mesh { name = "ready flare" };
        quad.SetVertices(new[] { new Vector3(-1, -1, 0), new Vector3(1, -1, 0), new Vector3(1, 1, 0), new Vector3(-1, 1, 0) });
        quad.SetTriangles(new[] { 0, 1, 2, 0, 2, 3 }, 0, false);
        quad.bounds = new Bounds(Vector3.zero, Vector3.one * FAR_BOUNDS);
        flareMat = new Material(Resources.Load<Shader>("Shaders/Flare"));
        flare.SetVector("_FlareTint", eye.linear);
        flare.SetFloat("_FlareEdge", 0f);
        flare.SetFloat("_FlareSoft", 0f);
        flare.SetFloat("_FlareRays", FLARE_RAYS);
    }

    // One frame; `at` is where the croc stands (Godot axes).
    public void Step(float dt, Vector3 at)
    {
        bool charged = sim.abilityReadyIn <= 0.0;
        if (charged && !wasReady) Pulse(at);
        wasReady = charged;
        DrawFlare(dt);
        Healing = sim.Stat("regen") > 0.0 && sim.hp < sim.maxHp;
        croc.SetRegen(Healing ? RIM : 0f, regenTint);
        if (!Healing)
        {
            moteWait = 0f;
            return;
        }
        moteWait -= dt;
        if (moteWait > 0f) return;
        moteWait += MOTE_STEP;
        var box = new Vector3(1f, BOX_HIGH, 1f) * scale;
        fx.Spray(motes, at + Vector3.up * (MOTES_UP * scale), box, Mathf.RoundToInt(MOTES * MOTE_STEP / MOTE_LIFE), MOTE_LIFE, MOTE_STEP);
    }

    // ability_fx.gd ready_pulse: the eyes flare in the species' colour (not the whole body, which read as taking damage).
    void Pulse(Vector3 at)
    {
        var facing = new Vector3((float)sim.facing.x, 0f, (float)sim.facing.y);
        Vector3 head = at + Vector3.up * (HEAD_UP * scale) + facing * (HEAD_AHEAD * scale);
        flare.SetVector("_FlarePos", new Vector4(head.x, head.y, -head.z, FLARE_SIZE * scale));
        flareAge = 0f;
        ReadyPulses++;
    }

    void DrawFlare(float dt)
    {
        if (flareAge < 0f) return;
        flareAge += dt;
        if (flareAge >= FLARE_SECONDS)
        {
            flareAge = -1f;
            return;
        }
        flare.SetFloat("_FlareFade", 1f - flareAge / FLARE_SECONDS);
        Graphics.DrawMesh(quad, Matrix4x4.identity, flareMat, 0, null, 0, flare, ShadowCastingMode.Off, false);
    }

    public void Dispose()
    {
        UnityEngine.Object.Destroy(quad);
        UnityEngine.Object.Destroy(flareMat);
    }
}
