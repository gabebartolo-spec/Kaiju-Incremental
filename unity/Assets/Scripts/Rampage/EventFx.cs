using UnityEngine;
using S = Kaiju.Sim;

// Reads the sim's events and draws them: scenes/rampage.gd _on_event, blast_fx.gd, powers_view.gd, topple_fx.gd,
// city_falls.gd, leap_view.gd and rampage_footfall.gd. Everything here is in Godot axes. It never decides an outcome.
public sealed class EventFx
{
    // scenes/rampage.gd and scenes/fx.gd.
    const float FOOTFALL_DUST = 1.1f, FOOTFALL_RING = 1.4f, STOMP_WAIT = 0.6f, STOMP_RING = 3f, STOMP_REACH = 1.3f;
    const float FOOTFALL_LIFT = 0.2f, FOOTFALL_BASE = 0.2f, FOOTFALL_STRENGTH_MIN = 0.2f;
    const float COLLAPSE_DUST_PER_CELL = 0.05f, COLLAPSE_DUST_BASE = 0.5f;
    const int COLLAPSE_MIN_CELLS = 4, COATS_SHOWN = 4;
    const float COAT_FIRE = 0.45f, FALL_DUST = 1f, FALL_LIFT = 0.5f, LAND_DUST = 1.5f;
    const float TAIL_SWEEP_BEHIND = 0.7f, TAIL_AUTO_BEHIND = 0.5f, TAIL_LINE_WIDTH = 2f, LEAP_DUST = 2f, LEAP_DUST_Y = 0.3f;

    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly S.GDict blast, topple, fire;
    readonly Color toppleTint;
    readonly float impactDust, dustLift, chunkFade, viewSize, viewSpacing;
    readonly System.Random rng;

    float stompWait, stompRadius, flashLeft0, flashLeft1, flashLeft2;
    string stompSide = "";

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static Vector3 Godot(S.Vector3 v) => new Vector3((float)v.x, (float)v.y, (float)v.z);

    static Color Hex(string hex)
    {
        ColorUtility.TryParseHtmlString("#" + hex, out Color c);
        return c;
    }

    public EventFx(S.RampageSim sim, CityFx fx, int seed)
    {
        this.sim = sim;
        this.fx = fx;
        rng = new System.Random(seed);
        blast = S.Content.Section("blast_fx");
        topple = S.Content.Section("topple_fx");
        impactDust = F(topple, "impact_dust");
        dustLift = F(topple, "dust_lift");
        toppleTint = Hex(S.Gd.Str(topple["dust_color"]));
        fire = sim.powersCfg["fire"];
        chunkFade = F(fire, "view_out_fade");
        viewSize = F(fire, "view_size");
        viewSpacing = F(fire, "view_spacing");
    }

    public void Step(float dt)
    {
        fx.PutOutExpired();
        if (stompWait > 0f) stompWait -= dt;
        flashLeft0 -= dt;
        flashLeft1 -= dt;
        flashLeft2 -= dt;
    }

    // A foot came down: a little dust, a ring, and the waiting stomp lands under it (scenes/rampage_footfall.gd).
    // True when this foot delivered the waiting stomp.
    public bool Footfall(string side, float strength, Vector3 at)
    {
        bool stomped = stompWait > 0f && (stompSide == "" || stompSide == side);
        if (stomped) stompWait = 0f;
        float bs = (float)sim.BodyScale();
        float size = bs * (FOOTFALL_BASE + strength);
        fx.Footfall(at + Vector3.up * FOOTFALL_LIFT, FOOTFALL_DUST * size);
        float ring = stomped ? stompRadius * STOMP_REACH * STOMP_RING : FOOTFALL_RING * size;
        fx.Shockwave(at, ring, false, stomped);
        return stomped;
    }

    public void OnEvent(S.GDict e, Vector3 kaiju)
    {
        float bs = (float)sim.BodyScale();
        switch (S.Gd.Str(e["type"]))
        {
            case "stomp":
                stompRadius = F(e, "radius");
                stompSide = (bool)e["on_foot"] ? S.Gd.Str(e["side"]) : "";
                stompWait = STOMP_WAIT;
                break;
            case "chunks_broken":
                ChunksBroken(e);
                break;
            case "fall_start":
                FallStart(e);
                break;
            case "fall_land":
                FallLand(e);
                break;
            case "tail_sweep":
                fx.ShockwaveTo(kaiju, F(e, "reach"));
                TailLine(kaiju, F(e, "reach") * TAIL_SWEEP_BEHIND, bs);
                break;
            case "tail_auto":
                TailLine(kaiju, F(e, "reach") * TAIL_AUTO_BEHIND, bs);
                break;
            case "coated":
                Coated(e);
                break;
            case "fire_burning":
                Burning((int)S.Num.I(e["building"]));
                break;
            case "leap_off":
                S.Vector2 off = e["at"];
                fx.Dust(new Vector3((float)off.x, LEAP_DUST_Y, (float)off.y), bs * LEAP_DUST);
                break;
            case "leap_land":
                S.Vector2 land = e["at"];
                fx.Shockwave(new Vector3((float)land.x, 0f, (float)land.y), F(e, "radius") * STOMP_REACH * STOMP_RING, false, true);
                break;
            case "explosion":
                Explode(S.Gd.Str(e["kind"]), e);
                break;
            case "airstrike_bomb":
                Bomb(e);
                break;
            case "firework_burst":
                Firework(At(e));
                break;
            case "toxic_cloud":
                Site(e, out Vector3 centre, out Vector3 half);
                fx.ToxicCloud(centre, half, F(e, "radius"), F(e, "seconds"));
                break;
        }
    }

    void TailLine(Vector3 kaiju, float behind, float bs)
    {
        var facing = new Vector3((float)(double)sim.facing.x, 0f, (float)(double)sim.facing.y);
        fx.DustLine(kaiju, kaiju - facing * behind + Vector3.up * FALL_LIFT, bs * TAIL_LINE_WIDTH);
    }

    void ChunksBroken(S.GDict e)
    {
        long index = S.Num.I(e["building"]);
        S.GArray<S.Vector3i> cells = e["cells"];
        S.RampageSim.Building b = sim.buildings[index];
        if (cells.Size() >= COLLAPSE_MIN_CELLS)
        {
            Vector3 mid = Vector3.zero;
            for (int i = 0; i < cells.Size(); i++) mid += Godot(b.ChunkWorld(cells[i]));
            fx.Dust(mid / cells.Size(), COLLAPSE_DUST_BASE + cells.Size() * COLLAPSE_DUST_PER_CELL);
        }
        Broke(index, cells);
    }

    void Broke(long index, S.GArray<S.Vector3i> cells)
    {
        fx.Broke(index, cells, sim.buildings[index].frame.aliveCount == 0, chunkFade);
    }

    void FallStart(S.GDict e)
    {
        S.Vector3 pivot = e["pivot"];
        fx.Dust(Godot(pivot) + Vector3.up * FALL_LIFT, FALL_DUST);
        S.GArray<S.Vector3i> cells = e["cells"];
        Broke(S.Num.I(e["building"]), cells);
    }

    void FallLand(S.GDict e)
    {
        S.RampageSim.Building site = sim.buildings[S.Num.I(e["building"])];
        // scenes/city_falls.gd land: a piece that came down on the kaiju or a building, and a landmark's,
        // gets the one plain puff below, not the street's dust line.
        if (S.Gd.Str(e["kind"]) == "topple" && e.Has("from") && !e.Has("contact") && site.landmark == "")
        {
            S.Vector2 from = e["from"], to = e["to"];
            var a = new Vector3((float)from.x, 0f, (float)from.y);
            var b = new Vector3((float)to.x, 0f, (float)to.y);
            Vector3 lift = Vector3.up * dustLift;
            fx.Dust(b + lift, impactDust, true, toppleTint);
            fx.Dust(Vector3.Lerp(a, b, 0.6f) + lift, impactDust * 0.7f, true, toppleTint);
            fx.DustLine(a, b, F(e, "width"), true, toppleTint);
            return;
        }
        var at = new Vector3((float)site.x, FALL_LIFT, (float)site.z);
        if (City != null && City.Landed(S.Num.I(e["id"]), out Vector3 landed)) at = new Vector3(landed.x, FALL_LIFT, landed.z);
        fx.Dust(at, LAND_DUST);
    }

    // The city's drawing, for where a fallen piece came down; RampageGame sets it.
    public CityDraw City;

    // scenes/powers_view.gd _coated: a few of the cells the beam coated burn on.
    void Coated(S.GDict e)
    {
        long index = S.Num.I(e["building"]);
        S.GArray<S.Vector3i> cells = e["cells"];
        S.RampageSim.Building b = sim.buildings[index];
        int n = (int)cells.Size(), shown = Mathf.Min(COATS_SHOWN, n);
        for (int k = 0; k < shown; k++)
        {
            S.Vector3i cell = cells[k * n / shown];
            fx.BurnChunk(index, cell, Godot(b.ChunkWorld(cell)), COAT_FIRE);
        }
    }

    void Burning(int index)
    {
        S.RampageSim.Building b = sim.buildings[index];
        int nx = b.w >= viewSpacing ? 2 : 1, nz = b.d >= viewSpacing ? 2 : 1;
        for (int a = 0; a < nx; a++)
        {
            for (int c = 0; c < nz; c++)
            {
                long x = (long)System.Math.Floor(b.w * (2.0 * a + 1.0) / (2.0 * nx));
                long z = (long)System.Math.Floor(b.d * (2.0 * c + 1.0) / (2.0 * nz));
                long y = b.frame.TopBelow(x, z, b.height);
                if (y < 0) continue;
                var cell = new S.Vector3i(x, y, z);
                fx.BurnChunk(index, cell, Godot(b.ChunkWorld(cell)), viewSize);
            }
        }
    }

    static Vector3 At(S.GDict e) => new Vector3(F(e, "x"), 0f, F(e, "z"));

    // scenes/blast_fx.gd _site: the box as it stands now; one already flat blows out of its rubble.
    void Site(S.GDict e, out Vector3 centre, out Vector3 half)
    {
        S.RampageSim.Building b = sim.buildings[S.Num.I(e["building"])];
        float high = b.frame.aliveCount > 0 ? (float)b.height : F(blast, "site_rubble");
        half = new Vector3((float)(double)b.w, high, (float)(double)b.d) * 0.5f;
        centre = new Vector3((float)b.x, half.y, (float)b.z);
    }

    void Explode(string kind, S.GDict e)
    {
        float radius = F(e, "radius");
        Vector3 at = At(e);
        Site(e, out Vector3 high, out Vector3 half);
        Blast(high, half, at, Mathf.Max(half.x, half.z) * 2f, radius, kind == "chem_lab" ? "chem_color" : "color");
        S.GDict burn = blast["fire"];
        fx.Fire(at, F(burn, "size") * radius / 5f, F(burn, "seconds"));
    }

    void Bomb(S.GDict e)
    {
        float radius = F(e, "radius");
        Vector3 at = At(e);
        var half = new Vector3(radius, radius, radius) * 0.5f;
        Blast(at + Vector3.up * half.y, half, at, radius * 2f, radius, "color");
        S.GDict burn = blast["fire"];
        bool wet = sim.emerge.Wet(new S.Vector2(at.x, at.z));
        fx.Fire(at, F(burn, "size") * radius / 5f, wet ? F(burn, "water_seconds") : F(burn, "seconds"));
    }

    void Blast(Vector3 high, Vector3 half, Vector3 at, float span, float radius, string tintKey)
    {
        fx.Core(high, half, radius);
        fx.Fireball(high, half, radius);
        S.GDict shock = blast["shock"];
        S.GDict ring = shock["ring"];
        float reach = Mathf.Max(span * F(ring, "footprint_scale") * 0.5f, radius * 2f);
        fx.Shockwave(at, reach);
        int puffs = (int)S.Num.I(ring["puffs"]);
        for (int k = 0; k < puffs; k++)
        {
            float a = Mathf.PI * 2f * k / puffs;
            fx.Dust(at + new Vector3(Mathf.Cos(a), 0f, Mathf.Sin(a)) * reach + Vector3.up * F(ring, "height"), F(ring, "puff_size"));
        }
        S.GDict flash = blast["flash"];
        Flash(high, Hex(S.Gd.Str(flash[tintKey])), F(flash, "energy") * radius / 5f, F(flash, "seconds"));
    }

    void Firework(Vector3 at)
    {
        S.GDict cfg = blast["fireworks"];
        S.GArray<S.Variant> colours = cfg["colors"];
        Color colour = Hex(S.Gd.Str(colours[rng.Next((int)colours.Size())]));
        Vector3 up = Vector3.up * F(cfg, "height") * (0.7f + (float)rng.NextDouble() * 0.5f);
        fx.Firework(at + up, colour);
        Flash(at + up, colour, F(cfg, "flash_energy"), F(blast["flash"], "seconds"));
        fx.Fire(at, F(cfg, "fire_size"));
    }

    // At most flash.max_live at once (scenes/blast_fx.gd _flash).
    void Flash(Vector3 at, Color color, float energy, float seconds)
    {
        if (flashLeft0 > 0f && flashLeft1 > 0f && flashLeft2 > 0f) return;
        if (flashLeft0 <= 0f) flashLeft0 = seconds;
        else if (flashLeft1 <= 0f) flashLeft1 = seconds;
        else flashLeft2 = seconds;
        fx.FlashLight(at, color, energy, seconds);
    }
}
