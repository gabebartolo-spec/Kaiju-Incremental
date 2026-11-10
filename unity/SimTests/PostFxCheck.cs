// The post effects' numbers (Assets/Scripts/Rampage/PostFxState.cs) against data/tuning.json "post_fx", the checks
// of tests/run_postfx_tests.gd that need no scene: a fixed 1/60 delta, no clock.
using System;
using Kaiju.Sim;

static class PostFxCheck
{
    const double FRAME = 1.0 / 60.0;
    // tests/run_postfx_tests.gd MAX_FRINGE_SECONDS: the director's bound (D-142: a split second).
    const double MAX_FRINGE_SECONDS = 0.25;

    static int failed;

    public static int Run(string repoRoot)
    {
        FileAccess.Root = repoRoot;
        failed = 0;
        GDict cfg = Content.Section("post_fx");
        GDict vig = cfg["vignette"];
        GDict fringe = cfg["fringe"];
        Calm(vig);
        Railgun();
        Gates(fringe);
        HpDropAndFall(fringe);
        Shape(fringe);
        Cooldown(fringe);
        Motion(fringe);
        Console.WriteLine($"post fx: {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL post fx: " + what);
    }

    static double RunFor(PostFxState state, double seconds, double hpShare = 1.0, double motion = 1.0)
    {
        double peak = 0.0;
        int frames = (int)Math.Round(seconds / FRAME);
        for (int i = 0; i < frames; i++)
        {
            state.Update(FRAME, hpShare, motion);
            peak = Math.Max(peak, state.fringePx);
        }
        return peak;
    }

    // _check_vignette_calm and _check_vignette_low_health: the same dark edge at any health, never red.
    static void Calm(GDict vig)
    {
        double strength = Num.F(vig["strength"]);
        PostFxState state = new PostFxState();
        RunFor(state, 1.0);
        Check(state.vignetteAlpha == strength && strength > 0.0 && strength <= 0.5, $"vignette at full health is {state.vignetteAlpha}, tuning {strength} (at most 0.5)");
        Check(state.vignetteHex == Gd.Str(vig["color"]), $"vignette colour {state.vignetteHex}");
        string hex = state.vignetteHex.TrimStart('#');
        int red = hex.Length >= 6 ? Convert.ToInt32(hex.Substring(0, 2), 16) : 255;
        int green = hex.Length >= 6 ? Convert.ToInt32(hex.Substring(2, 2), 16) : 255;
        Check(red < 26 && green < 26, $"the vignette is dark, not red: {state.vignetteHex}");
        Check(Num.F(vig["inner"]) >= 0.4 && Num.F(vig["outer"]) > Num.F(vig["inner"]), "the vignette leaves the centre clear");
        PostFxState low = new PostFxState();
        low.Update(FRAME, 1.0, 1.0);
        for (int i = 0; i < 60; i++) low.Update(FRAME, Math.Max(0.05, 1.0 - i * 0.02), 1.0);
        Check(low.vignetteAlpha == strength && low.vignetteHex == state.vignetteHex && !low.FringeOn(), $"at 5% health the vignette is unchanged: {low.vignetteAlpha} {low.vignetteHex}");
    }

    // _check_railgun: every railgun hit fires the fringe (D-145), cooldown or not.
    static void Railgun()
    {
        PostFxState state = new PostFxState();
        Check(!state.Hurt(0.08), "8% of max health alone is under the heavy-hit bar");
        Check(state.Railgun() && state.FringeOn(), "a railgun hit starts the fringe");
        RunFor(state, 1.0);
        Check(!state.FringeOn(), "the burst is over a second later");
        bool stomp = state.Stomp(100.0);
        Check(!stomp && state.Railgun() && state.FringeOn(), "a second railgun hit inside the cooldown still shows, a stomp does not");
        RunFor(state, 0.1);
        PostFxState again = new PostFxState();
        again.Railgun();
        again.Update(FRAME, 1.0, 1.0);
        again.Railgun();
        again.Update(FRAME, 1.0, 1.0);
        PostFxState once = new PostFxState();
        once.Railgun();
        once.Update(FRAME, 1.0, 1.0);
        Check(again.fringePx > 0.0 && again.fringePx == once.fringePx, $"a railgun hit restarts the burst: {again.fringePx} px, first frame {once.fringePx} px");
        Check(again.fringes == 2, $"two railgun hits count two fringes: {again.fringes}");
    }

    // _check_fringe_gates: below each bar no fringe, at it a fringe.
    static void Gates(GDict fringe)
    {
        double minStomp = Num.F(fringe["stomp_min_radius"]);
        double minFall = Num.F(fringe["collapse_min_length"]);
        double minHit = Num.F(fringe["hit_hp_fraction"]);
        PostFxState refused = new PostFxState();
        Check(!refused.Stomp(minStomp * 0.99) && !refused.FringeOn(), "a stomp under the bar starts no fringe");
        Check(!new PostFxState().Collapse(minFall * 0.99), "a collapse under the bar starts no fringe");
        Check(!new PostFxState().Hurt(minHit * 0.99), "a hit under the bar starts no fringe");
        PostFxState taken = new PostFxState();
        Check(taken.Stomp(minStomp) && taken.FringeOn() && taken.fringes == 1, "a stomp at the bar starts a fringe");
        Check(new PostFxState().Collapse(minFall), "a collapse at the bar starts a fringe");
        Check(new PostFxState().Hurt(minHit), "a hit at the bar starts a fringe");
        Check(minStomp > 3.0 && minFall > 20.0 && minHit >= 0.1, "the bars sit above a hatchling's stomp, an ordinary building and a tank shell");
    }

    // _check_hp_drop_and_fall: one heavy frame yes, a drain of chips no; only a tall, real topple.
    static void HpDropAndFall(GDict fringe)
    {
        double minHit = Num.F(fringe["hit_hp_fraction"]);
        PostFxState heavy = new PostFxState();
        heavy.Update(FRAME, 1.0, 1.0);
        heavy.Update(FRAME, 1.0 - minHit - 0.01, 1.0);
        PostFxState chip = new PostFxState();
        double share = 1.0;
        for (int i = 0; i < 240; i++)
        {
            share -= i % 20 == 0 ? minHit * 0.4 : 0.0;
            chip.Update(FRAME, share, 1.0);
        }
        Check(heavy.FringeOn() && !chip.FringeOn() && share < 0.5, $"one heavy frame earns the fringe, chips do not ({heavy.FringeOn()} {chip.FringeOn()}, {share:F2} left)");
        double length = Num.F(fringe["collapse_min_length"]);
        Check(new PostFxState().Fall(Land("topple", false, length)), "a tall topple earns the fringe");
        Check(!new PostFxState().Fall(Land("topple", true, length)), "a scrap does not");
        Check(!new PostFxState().Fall(Land("drop", false, length)), "a drop does not");
        Check(!new PostFxState().Fall(Land("topple", false, length * 0.5)), "a short topple does not");
    }

    // The fields of Collapse.cs's fall_land that PostFxState.Fall reads.
    static GDict Land(string kind, bool scrap, double length)
    {
        GDict e = new GDict();
        e["type"] = "fall_land";
        e["kind"] = kind;
        e["scrap"] = scrap;
        if (kind == "topple")
        {
            e["from"] = new Vector2(0.0, 0.0);
            e["to"] = new Vector2(length, 0.0);
        }
        return e;
    }

    // _check_fringe_shape: a split second, up to the peak and away.
    static void Shape(GDict fringe)
    {
        double seconds = Num.F(fringe["seconds"]);
        double peakPx = Num.F(fringe["peak_px"]);
        PostFxState state = new PostFxState();
        state.Stomp(100.0);
        int frames = 0, peakAt = 0, lastOn = 0;
        double peak = 0.0;
        for (int i = 0; i < 60; i++)
        {
            state.Update(FRAME, 1.0, 1.0);
            if (state.fringePx > 0.0)
            {
                frames++;
                lastOn = i;
            }
            if (state.fringePx > peak)
            {
                peak = state.fringePx;
                peakAt = i;
            }
        }
        double length = frames * FRAME;
        Check(seconds <= MAX_FRINGE_SECONDS && length <= MAX_FRINGE_SECONDS + FRAME && frames > 4, $"the fringe lasts {length:F2} s ({frames} frames)");
        Check(peak > 0.0 && peak <= peakPx + 0.001 && peakAt < lastOn, $"it peaks at {peak:F2} px on frame {peakAt} and falls away after");
        Check(state.fringePx == 0.0 && !state.FringeOn(), $"it is gone afterwards: {state.fringePx} px");
        double attack = Math.Min(Math.Max(Num.F(fringe["attack"]), 0.01), 0.99);
        Check(Math.Abs(state.Envelope(attack) - 1.0) < 1e-9 && state.Envelope(0.0) == 0.0 && Math.Abs(state.Envelope(1.0)) < 1e-9, "the envelope is 0 at the start, 1 at the attack, 0 at the end");
        Check(Math.Abs(state.Envelope(attack * 0.5) - 0.5) < 1e-9, "the rise is linear");
    }

    // _check_cooldown_and_share: the non-railgun gates share one cooldown, so the fringe stays rare.
    static void Cooldown(GDict fringe)
    {
        double cooldown = Num.F(fringe["cooldown_s"]);
        PostFxState state = new PostFxState();
        bool first = state.Stomp(100.0);
        RunFor(state, cooldown * 0.5);
        bool early = state.Stomp(100.0) || state.Collapse(1000.0) || state.Hurt(1.0);
        RunFor(state, cooldown * 0.5 + 0.1);
        bool late = state.Collapse(1000.0);
        Check(first && !early && late, $"a second big hit inside the {cooldown} s cooldown is refused, after it accepted ({first} {early} {late})");
        PostFxState rapid = new PostFxState();
        int on = 0, total = (int)Math.Round(60.0 / FRAME), every = (int)Math.Round(0.7 / FRAME);
        for (int i = 0; i < total; i++)
        {
            if (i % every == 0) rapid.Stomp(100.0);
            rapid.Update(FRAME, 1.0, 1.0);
            if (rapid.fringePx > 0.0) on++;
        }
        double share = (double)on / total;
        Check(share > 0.0 && share < 0.08, $"stomping flat out for a minute shows the fringe {share * 100.0:F1}% of the time");
    }

    // _check_motion_setting: the camera-motion setting scales the fringe, 0 shows none.
    static void Motion(GDict fringe)
    {
        PostFxState none = new PostFxState();
        none.Stomp(100.0);
        double off = RunFor(none, 0.3, 1.0, 0.0);
        PostFxState full = new PostFxState();
        full.Stomp(100.0);
        double on = RunFor(full, 0.3, 1.0, 1.0);
        PostFxState half = new PostFxState();
        half.Stomp(100.0);
        double mid = RunFor(half, 0.3, 1.0, 0.5);
        Check(off == 0.0 && on > 0.0, $"a 0% camera-motion setting shows no fringe ({off} vs {on} px)");
        Check(Math.Abs(mid - on * 0.5) < 1e-9, $"a 50% setting shows half ({mid} vs {on} px)");
    }
}
