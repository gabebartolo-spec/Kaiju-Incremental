// The landmark slow motion (GameLogic/LandmarkSlowmo.cs, tests/run_slowmo_tests.gd and tests/lib/slowmo_play.gd,
// D-259): the speed curve holds the tuned scale, eases back once and is whole after; a fall slows the world and gives
// it back after hold_s + ease_s of real time; a second fall restarts the clock and never stacks; only a landmark's fall
// slows it; his death, the end beat and a finished run never do; a press on a frame the sim sat out reaches the next
// step once; and the player effect, on against off: the same seeded Behemoth rampage with a landmark felled at the same
// step, stepped through RampageGame's frame loop (Time.timeScale shrinks the frame's delta, the accumulator steps
// whole ticks), takes the same steps to the same end state, while the "on" run really slows and takes longer.
using System;
using System.Collections.Generic;
using System.Text;
using Kaiju.Game;
using Kaiju.Sim;

static class SlowmoCheck
{
    // RampageGame's TICK and MAX_STEPS; the screen's frame (real seconds) the loop is fed.
    const float TICK = 1f / 60f, FRAME = 1f / 60f;
    const int MAX_STEPS = 4;
    const int Seed = 0;
    const string Species = "reptilian";
    // tests/lib/slowmo_play.gd: the fall and the end, in sim steps.
    const int FELL_STEP = 330, END_STEP = 700;
    // Frames a slowdown may take to start, and slack on the restore (tests/run_slowmo_tests.gd: 4 ticks).
    const int SLOW_WAIT_FRAMES = 12, RESTORE_SLACK = 4;
    const double NEAR = 1e-9;

    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        FileAccess.Root = repoRoot;
        GDict cfg = Content.Section("slowmo");
        SpeedCurve(cfg);
        FallSlowsAndRestores(cfg);
        SecondFallRestarts(cfg);
        OnlyALandmarkSlows();
        NeverInTheEnd();
        PressWaits();
        OnAgainstOff(cfg);
        Console.WriteLine(failed == 0 ? $"landmark slowmo: ok ({checks} checks)" : $"landmark slowmo: {failed} of {checks} failed");
        return failed;
    }

    static void SpeedCurve(GDict cfg)
    {
        double low = Num.F(cfg["scale"]), hold = Num.F(cfg["hold_s"]), ease = Num.F(cfg["ease_s"]);
        Check(LandmarkSlowmo.SpeedAt(-1.0, cfg) == 1.0, "no fall: full speed");
        Check(LandmarkSlowmo.SpeedAt(0.0, cfg) == low, $"the fall slows at once to the tuned {low}");
        Check(LandmarkSlowmo.SpeedAt(hold * 0.5, cfg) == low, "and holds it through hold_s");
        double last = low;
        bool rising = true;
        for (int k = 1; k <= 20; k++)
        {
            double s = LandmarkSlowmo.SpeedAt(hold + ease * k / 20.0, cfg);
            rising = rising && s >= last;
            last = s;
        }
        Check(rising, "the ease only ever climbs back");
        Check(LandmarkSlowmo.SpeedAt(hold + ease, cfg) == 1.0, "whole once the ease is done");
        GDict deep = new GDict { { "scale", 0.0 }, { "hold_s", 1.0 }, { "ease_s", 1.0 } };
        Check(LandmarkSlowmo.SpeedAt(0.0, deep) == LandmarkSlowmo.FLOOR, $"never below the floor {LandmarkSlowmo.FLOOR}");
    }

    // A landmark_felled event drops the speed to the tuned scale; it is back to 1.0 once hold_s + ease_s of real time
    // have gone, counted in frames of real time at the slowed speed.
    static void FallSlowsAndRestores(GDict cfg)
    {
        var slowmo = new LandmarkSlowmo(cfg, null);
        slowmo.OnEvent(new GDict { { "type", "landmark_felled" }, { "landmark", "spire" } });
        Check(slowmo.Speed == Num.F(cfg["scale"]), $"the fall drops the speed to the tuned {Num.F(cfg["scale"])} ({slowmo.Speed})");
        double total = Num.F(cfg["hold_s"]) + Num.F(cfg["ease_s"]);
        int frames = 0;
        while (slowmo.Active && frames < 1000)
        {
            double speedThen = slowmo.Speed;
            slowmo.Advance(LandmarkSlowmo.Real(FRAME * speedThen, speedThen));
            frames++;
        }
        Check(slowmo.Speed == 1.0 && Math.Abs(frames * FRAME - total) < RESTORE_SLACK * FRAME,
            $"and restores 1.0 once the tuned {total:F2} s are up ({frames} frames, {frames * FRAME:F2} s)");
    }

    static void SecondFallRestarts(GDict cfg)
    {
        double low = Num.F(cfg["scale"]), hold = Num.F(cfg["hold_s"]), ease = Num.F(cfg["ease_s"]);
        var slowmo = new LandmarkSlowmo(cfg, null);
        slowmo.Trigger();
        slowmo.Advance(hold * 0.8);
        slowmo.Trigger();
        Check(slowmo.Speed == low, $"a second fall does not stack: still {low} ({slowmo.Speed})");
        slowmo.Advance(hold * 0.8);
        Check(slowmo.Speed == low, $"and it restarted the clock: {hold * 1.6:F2} s after the first fall it still holds");
        slowmo.Advance(hold * 0.2 + ease * 0.5);
        Check(slowmo.Speed > low && slowmo.Speed < 1.0, "then it eases back once");
        slowmo.Advance(ease);
        Check(slowmo.Speed == 1.0 && !slowmo.Active, "and ends at 1.0");
    }

    // Towers toppling, the VIP's arrival, kill and escape leave time alone (D-243).
    static void OnlyALandmarkSlows()
    {
        var slowmo = new LandmarkSlowmo(Content.Section("slowmo"), null);
        slowmo.OnEvent(new GDict { { "type", "towers_toppled" }, { "count", 10L } });
        slowmo.OnEvent(new GDict { { "type", "vip_spawned" }, { "heli", 1L }, { "rank", 1L } });
        slowmo.OnEvent(new GDict { { "type", "vip_down" }, { "heli", 1L } });
        slowmo.OnEvent(new GDict { { "type", "vip_killed" }, { "rank", 1L }, { "by", "stomp" } });
        slowmo.OnEvent(new GDict { { "type", "vip_escaped" }, { "heli", 1L }, { "rank", 1L } });
        Check(slowmo.Speed == 1.0 && !slowmo.Active, $"the towers and the VIP leave time alone ({slowmo.Speed})");
        slowmo.OnEvent(new GDict { { "type", "landmark_felled" }, { "landmark", "spire" } });
        Check(slowmo.Active && slowmo.Speed < 1.0, "a landmark's fall does slow it");
        slowmo.Stop();
        Check(slowmo.Speed == 1.0 && !slowmo.Active, "stop gives the speed back");
    }

    // The end beat (the HUD's BeatRunning), his death playing and a finished run: a fall starts nothing, and one
    // already playing is cut short.
    static void NeverInTheEnd()
    {
        bool beat = true;
        var slowmo = new LandmarkSlowmo(Content.Section("slowmo"), () => beat);
        slowmo.Trigger();
        Check(!slowmo.Active && slowmo.Speed == 1.0, "a fall in the end beat starts nothing");
        beat = false;
        slowmo.Trigger();
        Check(slowmo.Speed < 1.0, "a fall before the beat slows the world");
        beat = true;
        slowmo.Advance(FRAME);
        Check(slowmo.Speed == 1.0 && !slowmo.Active, $"and the end beat cuts it short: normal speed ({slowmo.Speed})");
        RampageSim dying = Start();
        var onDeath = new LandmarkSlowmo(Content.Section("slowmo"), () => dying.over || dying.death.Active());
        dying.End("time");
        Check(dying.death.Active() && !dying.over, "(his death is playing, the run not over yet)");
        onDeath.Trigger();
        Check(!onDeath.Active && onDeath.Speed == 1.0, "his death playing is not slowed");
        RampageSim over = Start();
        var onOver = new LandmarkSlowmo(Content.Section("slowmo"), () => over.over || over.death.Active());
        over.End("time", true);
        onOver.Trigger();
        Check(!onOver.Active && onOver.Speed == 1.0, "a finished rampage never slows");
    }

    // RampageGame.WaitPresses: a press on a frame no step ran is held, and the next frame that steps gets it, once.
    static void PressWaits()
    {
        var waited = new HudLatch(Num.F(Content.Section("emerge")["input_latch_seconds"]));
        var press = new Dictionary<string, bool> { { "signature", true }, { "ultimate", false } };
        var quiet = new Dictionary<string, bool> { { "signature", false }, { "ultimate", false } };
        waited.Through(true, press, FRAME * 0.35);
        bool first = waited.Through(false, quiet, FRAME)["signature"];
        bool again = waited.Through(false, quiet, FRAME)["signature"];
        Check(first, "a press on a frame the sim sat out reaches the step");
        Check(!again, "and is given to one step only");
    }

    // The same seeded rampage, on and off.
    static void OnAgainstOff(GDict cfg)
    {
        Play on = Rampage(true, cfg), off = Rampage(false, cfg);
        Check(on.fell && off.fell, $"a landmark was felled at step {FELL_STEP} in both runs (on {on.fell}, off {off.fell})");
        Check(on.felledEvent, "the sim reported landmark_felled itself");
        Check(on.steps == off.steps && on.steps == END_STEP, $"both runs took {END_STEP} steps (on {on.steps}, off {off.steps})");
        Check(on.digest == off.digest, $"and ended in the same state:\n    on  {on.digest}\n    off {off.digest}");
        Check(on.trace == off.trace, "with the same events in the same order");
        Check(on.wholeTicks && off.wholeTicks, "every sim step was a whole tick");
        Check(Math.Abs(on.slowest - Num.F(cfg["scale"])) < NEAR, $"the on run slowed to the tuned {Num.F(cfg["scale"])} ({on.slowest})");
        Check(on.slowedWithin <= SLOW_WAIT_FRAMES, $"within {SLOW_WAIT_FRAMES} frames of the fall ({on.slowedWithin})");
        Check(off.slowest == 1.0, $"the off run never slowed ({off.slowest})");
        Check(on.endSpeed == 1.0, "the on run is back at full speed by the end");
        // hold 1.5 s at 0.35 and the ease: the slowed window costs the wall clock about a second and a half.
        double hold = Num.F(cfg["hold_s"]), low = Num.F(cfg["scale"]);
        int extra = on.frames - off.frames;
        Check(extra >= (int)(hold * (1.0 - low) / FRAME * 0.9), $"and took longer on the wall clock: {on.frames} frames against {off.frames} (+{extra * FRAME:F2} s)");
        Console.WriteLine($"  slowmo on/off: {END_STEP} steps each; on {on.frames} frames ({on.frames * FRAME:F2} s), off {off.frames} frames ({off.frames * FRAME:F2} s), slowest {on.slowest}, slowed {on.slowedWithin} frame(s) after the fall");
    }

    sealed class Play
    {
        public int steps, frames, slowedWithin = -1;
        public double slowest = 1.0, endSpeed = 1.0;
        public bool fell, felledEvent, wholeTicks = true;
        public string digest = "", trace = "";
    }

    // RampageGame.Update's loop, fed a 60 Hz screen: the frame's delta is the real frame shrunk by the speed set last
    // frame; the accumulator steps whole TICKs (at most MAX_STEPS a frame); the events reach the slow motion; then
    // its clock moves on by the real frame.
    static Play Rampage(bool slowmoOn, GDict cfg)
    {
        RampageSim sim = Start();
        var slowmo = new LandmarkSlowmo(cfg, () => sim.over || sim.death.Active()) { Enabled = slowmoOn };
        var play = new Play();
        var trace = new StringBuilder();
        float accumulator = 0f;
        int fellFrame = -1;
        while (play.steps < END_STEP && !sim.over && play.frames < END_STEP * 10)
        {
            double speedThen = slowmo.Speed;
            float dt = FRAME * (float)speedThen;
            accumulator += dt;
            int ran = 0;
            while (accumulator >= TICK && ran < MAX_STEPS && play.steps < END_STEP)
            {
                accumulator -= TICK;
                ran++;
                if (!play.fell && play.steps >= FELL_STEP)
                {
                    play.fell = Fell(sim);
                    fellFrame = play.frames;
                }
                bool sign = sim.abilityReadyIn <= 0.0;
                long buttons = RampageSim.ULTIMATE | (sim.breathReadyIn <= 0.0 ? RampageSim.BREATH : 0);
                GArray<GDict> events = sim.Step(TICK, new Vector2(0.0, -1.0), sign, buttons);
                play.steps++;
                foreach (GDict e in events)
                {
                    string type = Gd.Str(e.Get("type", ""));
                    trace.Append(type).Append(' ');
                    if (type == "landmark_felled") play.felledEvent = true;
                    slowmo.OnEvent(e);
                }
            }
            if (ran == MAX_STEPS) accumulator = 0f;
            slowmo.Advance(LandmarkSlowmo.Real(dt, speedThen));
            play.frames++;
            play.slowest = Math.Min(play.slowest, slowmo.Speed);
            if (slowmo.Speed < 1.0 && play.slowedWithin < 0 && fellFrame >= 0) play.slowedWithin = play.frames - fellFrame;
        }
        play.endSpeed = slowmo.Speed;
        play.trace = trace.ToString();
        GDict r = sim.Result();
        play.digest = FormattableString.Invariant($"at {sim.kaijuPos.x:R},{sim.kaijuPos.y:R} facing {sim.facing.x:R},{sim.facing.y:R} hp {Num.F(sim.hp):R} left {sim.timeLeft:R} destruction {Num.F(r["destruction"]):R} rubble {Num.F(r["rubble"]):R} buildings {Num.I(r["buildings"])} tanks {sim.tanks.Size()} helis {sim.air.helis.Size()}");
        return play;
    }

    // tests/lib/slowmo_play.gd _fell_landmark: the first landmark loses its felled share of live cells, so the sim
    // reports landmark_felled itself on its next look.
    static bool Fell(RampageSim sim)
    {
        double share = Num.F(Content.Section("results")["landmark_felled_share"]);
        foreach (long i in Gd.Range(sim.buildings.Size()))
        {
            RampageSim.Building b = sim.buildings[i];
            if (b.landmark == "") continue;
            var live = new List<Vector3i>();
            for (long x = 0; x < b.w; x++)
                for (long z = 0; z < b.d; z++)
                    for (long y = 0; y < b.height; y++)
                        if (b.frame.Alive(new Vector3i(x, y, z))) live.Add(new Vector3i(x, y, z));
            int take = (int)Math.Ceiling(share * live.Count);
            for (int k = 0; k < take; k++) b.frame.Remove(live[k]);
            return true;
        }
        return false;
    }

    // The Behemoth's run (tests/lib/slowmo_play.gd LEVELS: the stage with rooftop squads and landmarks standing).
    static RampageSim Start()
    {
        var levels = new GDict { { "claws", 3L }, { "hide", 3L }, { "rage", 3L }, { "evolve1", 1L } };
        GDict species = Content.SpeciesDef(Species);
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, new UpgradeTree(Content.Upgrades(), levels, Species));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), Num.I(stats["size"]), Seeds.Make("city", Seed));
        RampageSim sim = new RampageSim(stats, CityGrowth.ForStats(stats), layout, Seeds.Make("army", Seed));
        sim.abilityType = Gd.Str(species["ability"]["type"]);
        sim.body.UseSpecies(Species);
        return sim;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine($"  FAIL slowmo: {what}");
    }
}
