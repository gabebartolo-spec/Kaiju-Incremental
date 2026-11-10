using System;
using S = Kaiju.Sim;

// What the two post effects show right now (scenes/post_fx_state.gd, D-142, tuning "post_fx"), line for line: the
// vignette's colour and strength, and the colour fringe's size. Presentation only, stepped by the frames' own
// delta (no clock). The vignette is the same dark edge at any health; the fringe is a split-second burst on a
// top-tier impact, with a cooldown. No UnityEngine here: unity/SimTests compiles this file (PostFxCheck).
public sealed class PostFxState
{
    // The vignette's colour ("#rrggbb") and the opacity at the screen corner.
    public string vignetteHex = "#000000";
    public double vignetteAlpha;
    // The fringe's red-blue split at the screen edge, in pixels at 1080 lines (0 = none).
    public double fringePx;
    // Fringes begun so far, for the stats line and the log (not in Godot).
    public int fringes;

    readonly S.GDict vig;
    readonly S.GDict fringe;
    double t = -1.0;  // seconds into the running fringe; negative when none
    double since = double.PositiveInfinity;  // seconds since the last fringe began
    double lastHp = 1.0;

    public PostFxState()
    {
        S.GDict cfg = S.Content.Section("post_fx");
        vig = cfg["vignette"];
        fringe = cfg["fringe"];
        vignetteHex = S.Gd.Str(vig["color"]);
        vignetteAlpha = S.Num.F(vig["strength"]);
    }

    // True while a fringe is showing.
    public bool FringeOn() => t >= 0.0;

    // A stomp of `radius` (world units) lands. True when it began a fringe.
    public bool Stomp(double radius) => radius >= S.Num.F(fringe["stomp_min_radius"]) && Begin();

    // A falling building part collapses along `length` (world units). True when it began a fringe.
    public bool Collapse(double length) => length >= S.Num.F(fringe["collapse_min_length"]) && Begin();

    // The kaiju lost `share` of its max health in one frame. True when it began a fringe.
    public bool Hurt(double share) => share >= S.Num.F(fringe["hit_hp_fraction"]) && Begin();

    // A Taskforce railgun hit (a sim `railgun_hit` event): every one earns the fringe (D-145), whatever the
    // cooldown, so it restarts the burst.
    public bool Railgun()
    {
        t = 0.0;
        since = 0.0;
        fringes++;
        return true;
    }

    // A falling part lands (a sim `fall_land` event): a topple of a tall part earns the fringe.
    public bool Fall(S.GDict e)
    {
        if (S.Gd.Str(e["kind"]) != "topple" || (bool)e["scrap"]) return false;
        S.Vector2 from = e["from"];
        S.Vector2 to = e["to"];
        return Collapse(from.DistanceTo(to));
    }

    bool Begin()
    {
        if (since < S.Num.F(fringe["cooldown_s"])) return false;
        t = 0.0;
        since = 0.0;
        fringes++;
        return true;
    }

    // One frame: `hpShare` is health over max health (0..1), `motion` the 0..1 camera-motion setting.
    public void Update(double delta, double hpShare, double motion)
    {
        since += delta;
        Hurt(lastHp - hpShare);  // a heavy hit: a big share of max health gone since the last frame
        lastHp = hpShare;
        fringePx = 0.0;
        if (t < 0.0) return;
        t += delta;
        double seconds = Math.Max(S.Num.F(fringe["seconds"]), 0.001);
        if (t >= seconds)
        {
            t = -1.0;
            return;
        }
        fringePx = S.Num.F(fringe["peak_px"]) * Envelope(t / seconds) * Math.Min(Math.Max(motion, 0.0), 1.0);
    }

    // 0..1..0 over a fringe's life: a quick rise to the peak at `attack`, then an ease out.
    public double Envelope(double u)
    {
        double attack = Math.Min(Math.Max(S.Num.F(fringe["attack"]), 0.01), 0.99);
        if (u < attack) return u / attack;
        double rest = 1.0 - (u - attack) / (1.0 - attack);
        return rest * rest;
    }
}
