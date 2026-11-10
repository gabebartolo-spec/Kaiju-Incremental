// The leap and the slam on screen are LeapView's and SlamView's reading of the sim's dash and momentum.
// This runs a live sim through one leap and one slam (tests/run_leap_tests.gd, tests/run_momentum_tests.gd)
// and holds what the views draw from: the phases in order, one leap_off and one leap_land, the height the
// body is lifted by, and the keyed clip's frame (Rampage/LeapFrames.cs) only ever moving forward.
using System;
using Kaiju.Sim;

static class LeapCheck
{
    const double Dt = 1.0 / 60.0;
    const int Seed = 0;
    const int MostWalkTicks = 60 * 20, MostLeapTicks = 60 * 20;
    // tests/lib/momentum_base.gd: CHARGE_S 13 s at 60 Hz, LEAD, WIDTH, TALL; leap_base.gd: he stands at z 30.
    const int SlamTicks = 780;
    const double SlamFrom = 30.0, SlamLead = 9.0;
    const long SlamWidth = 3, SlamFloors = 8;
    const double Near = 1e-6;
    const string Species = "reptilian";
    // croc.kclip's "leap": 26 frames, the feet off the ground from frame 0 and back on it at 22.
    const int ClipFrames = 26, ClipLand = 22;

    static int failed;

    public static int Run(string repoRoot)
    {
        failed = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        Frames();
        Leap();
        Slam();
        Console.WriteLine(failed == 0 ? "leap and slam: ok" : $"leap and slam: {failed} failed");
        return failed;
    }

    static void Frames()
    {
        byte[] planted = new byte[ClipFrames];
        for (int n = ClipLand; n < ClipFrames; n++) planted[n] = 2;
        LeapFrames.Air(planted, out int off, out int land);
        Check(off == 0 && land == ClipLand, $"the clip's air is read from its planted bits: off {off}, land {land}");
        byte[] late = { 3, 3, 0, 0, 0, 1, 3 };
        LeapFrames.Air(late, out int lateOff, out int lateLand);
        Check(lateOff == 2 && lateLand == 5, $"a clip with a crouch takes off after it: off {lateOff}, land {lateLand}");
        int last = late.Length - 1;
        Check(LeapFrames.Frame("crouch", 0.0, 0.5, lateOff, lateLand, last) == 0.0, "the crouch starts on frame 0");
        Check(LeapFrames.Frame("crouch", 1.0, 0.5, lateOff, lateLand, last) == lateOff, "the crouch ends at take-off");
        Check(LeapFrames.Frame("flight", 1.0, 0.5, lateOff, lateLand, last) == lateLand, "the flight ends on the landing frame");
        Check(LeapFrames.Frame("settle", 1.0, 0.5, lateOff, lateLand, last) == 5.5, "the settle takes its share of the rest");
        Check(LeapFrames.Frame("recover", 0.0, 0.5, lateOff, lateLand, last) == 5.5, "the recovery starts where the settle ends");
        Check(LeapFrames.Frame("recover", 1.0, 0.5, lateOff, lateLand, last) == last, "the recovery ends on the last frame");
        Check(LeapFrames.Frame("flight", 7.0, 0.5, lateOff, lateLand, last) == lateLand, "a phase past its end holds its last frame");
        Check(LeapFrames.Grounded(-9.0, -11.82) == -11.82, "the clip's own rise comes out of the hips");
        Check(LeapFrames.Grounded(-12.5, -11.82) == -12.5, "the clip's crouch stays in the hips");
    }

    static void Leap()
    {
        RampageSim sim = Start(3);
        Dash dash = sim.body.dash;
        Check(dash.Available(), "the croc has a leap");
        Vector2 dir = Toward(sim);
        int tick = 0;
        while (tick < MostWalkTicks && !dash.CanLeap())
        {
            sim.Step(Dt, dir, false);
            tick++;
        }
        if (!dash.CanLeap())
        {
            Check(false, "he never had a leap to press for");
            return;
        }
        double share = dash.PhaseSeconds("settle") / Math.Max(0.001, dash.PhaseSeconds("settle") + dash.PhaseSeconds("recover"));
        int last = ClipFrames - 1;
        string[] order = { "crouch", "flight", "settle", "recover" };
        int at = 0, offs = 0, lands = 0, offTick = -1, landTick = -1, wrongAir = 0, lifted = 0;
        double frame = 0.0, settleWas = double.MaxValue, highest = 0.0;
        bool flew = false, backwards = false, outside = false, rose = false, grounded = true, sank = true, under = true;
        for (tick = 0; tick < MostLeapTicks; tick++)
        {
            foreach (GDict e in sim.Step(Dt, Vector2.ZERO, false, tick == 0 ? Dash.BUTTON : 0))
            {
                string type = Gd.Str(e["type"]);
                if (type == "leap_off")
                {
                    offs++;
                    offTick = tick;
                }
                else if (type == "leap_land")
                {
                    lands++;
                    landTick = tick;
                    Check(Num.F(e["radius"]) > 0.0, "the landing has a ring to crush in");
                }
            }
            if (!dash.On()) break;
            string phase = dash.Phase();
            int now = Array.IndexOf(order, phase);
            if (now < at) backwards = true;
            at = Math.Max(at, now);
            double height = dash.Height();
            highest = Math.Max(highest, height);
            if (phase == "flight")
            {
                flew = true;
                if (height > 0.0) rose = true;
                if (height > dash.arc.top + Near) under = false;
            }
            else if (phase == "settle")
            {
                if (height > settleWas + Near) sank = false;
                settleWas = height;
            }
            else if (height != 0.0) grounded = false;
            if (sim.airborne != (phase == "flight")) wrongAir++;
            if (height > 0.0) lifted++;
            double f = LeapFrames.Frame(phase, dash.PhaseT(), share, 0, ClipLand, last);
            if (f < frame - Near) backwards = true;
            if (f < 0.0 || f > last) outside = true;
            frame = f;
        }
        Check(!dash.On(), "the leap ends");
        Check(tick > 0, "a press with a leap ready starts one");
        Check(flew && at == order.Length - 1, $"the leap runs crouch, flight, settle, recover: reached {order[at]}");
        Check(!backwards, "the phases and the clip's frame only move forward");
        Check(!outside, "the clip's frame stays inside the clip");
        Check(offs == 1 && lands == 1 && offTick < landTick, $"one take-off, then one landing: {offs} off at {offTick}, {lands} land at {landTick}");
        Check(dash.landings == 1, $"the sim counts the landing: {dash.landings}");
        Check(rose && lifted > 0, "the body is lifted through the flight");
        Check(under, $"never over the top of its arc: {highest} of {dash.arc.top}");
        Check(sank, "the settle only sinks");
        Check(grounded, "the crouch and the recovery stand on the street");
        Check(wrongAir == 0, $"airborne from take-off to landing only: {wrongAir} ticks off");
        Check(dash.Height() == 0.0 && !sim.airborne, "back on the street after it");
        Check(!dash.CanLeap(), "the cooldown holds the next leap");
    }

    // tests/run_momentum_tests.gd _check_slam on tests/lib/momentum_base.gd's fixture: the young croc at
    // (0, 30) walks north into a block over his shoulder whose near face stands SlamLead beyond his snout.
    static void Slam()
    {
        RampageSim probe = Croc(new GArray<GDict>());
        double snout = 0.0;
        foreach (GArray<Variant> d in probe.body.Discs())
            snout = Math.Max(snout, Num.F(d[0]) + Num.F(d[1]));
        snout *= probe.BodyScale();
        GArray<GDict> tall = new GArray<GDict>();
        tall.Append(Block(0.0, SlamFrom - snout - SlamLead - SlamWidth * 0.5, SlamWidth, SlamFloors));
        RampageSim sim = Croc(tall);
        sim.stats["sweep_damage"] = 0.0;
        Momentum run = sim.powers.run;
        Check(run.Active(), "the croc builds momentum");
        int slams = 0;
        long building = -1, dent = 0;
        double strength = 0.0, before = 0.0, after = -1.0, moved = -1.0;
        Vector3 at = new Vector3(0, 0, 0);
        for (int tick = 0; tick < SlamTicks; tick++)
        {
            Vector2 was = sim.kaijuPos;
            double had = run.value;
            long alive = sim.buildings[0].frame.aliveCount;
            foreach (GDict e in sim.Step(Dt, new Vector2(0, -1), false))
            {
                if (Gd.Str(e["type"]) != "slam") continue;
                slams++;
                if (slams > 1) continue;
                building = Num.I(e["building"]);
                strength = Num.F(e["strength"]);
                at = e["at"];
                before = had;
                after = run.value;
                moved = was.DistanceTo(sim.kaijuPos);
                dent = alive - sim.buildings[0].frame.aliveCount;
            }
        }
        double least = Num.F(run.titan["slam_min"]) * Num.F(run.titan["hit"]);
        RampageSim.Building b = sim.buildings[0];
        Check(slams == 1, $"one slam into the tall building: {slams}");
        Check(building == 0, $"the slam names the building he ran into: {building}");
        Check(strength >= least && strength <= 1.0, $"the slam is as strong as his run: {strength}, at least {least}");
        Check(before >= Num.F(run.titan["slam_min"]), $"he had the run for it: {before}");
        Check(after == 0.0 && moved == 0.0, $"the slam spends the run and stops him: momentum {after}, moved {moved}");
        Check(dent > 0, $"the slam dents the building: {dent} chunks");
        Check(run.slams == 1, $"the sim counts the slam: {run.slams}");
        // SlamView shudders the building along (its centre - at): the blow lands on its near, south, side.
        Check(at.z > b.z && Math.Abs(at.x - b.x) <= SlamWidth, $"the blow lands on the side he came from: {at.x}, {at.z} on {b.x}, {b.z}");
    }

    // tests/lib/leap_base.gd _croc: the young croc on a hand-made layout, with its one far block.
    static RampageSim Croc(GArray<GDict> blocks)
    {
        GArray<GDict> layout = new GArray<GDict>();
        foreach (GDict block in blocks) layout.Append(block);
        layout.Append(Block(38.0, 38.0, 2, 2));
        GDict species = Content.SpeciesDef(Species);
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, new UpgradeTree(Content.Upgrades(), new GDict(), Species));
        RampageSim sim = new RampageSim(stats, CityGrowth.ForStats(stats), layout, Seeds.Make("army", Seed));
        sim.abilityType = "cone";
        sim.body.UseSpecies(Species);
        sim.timeLeft = 1.0e9;
        sim.kaijuPos = new Vector2(0, SlamFrom);
        return sim;
    }

    // tests/lib/leap_base.gd _block: `w` x `w` cells, `h` floors, centred at (x, z).
    static GDict Block(double x, double z, long w, long h)
    {
        GDict block = new GDict();
        block["x"] = x;
        block["z"] = z;
        block["w"] = w;
        block["d"] = w;
        block["h"] = h;
        block["tier"] = 1L;
        block["style"] = 0L;
        return block;
    }

    // scenes/rampage.gd _take_sim, at the upgrades that reach `stage` (tools/capture/capture_kit.gd STAGE_LEVELS).
    static RampageSim Start(int stage)
    {
        GDict levels = new GDict();
        levels["claws"] = stage == 1 ? 2 : 5;
        levels["hide"] = stage == 1 ? 2 : 5;
        if (stage >= 2)
        {
            levels["rage"] = stage == 2 ? 3 : 5;
            levels["evolve1"] = 1;
        }
        if (stage >= 3)
        {
            levels["tail"] = 3;
            levels["sig_power"] = 3;
            levels["evolve2"] = 1;
        }
        GDict species = Content.SpeciesDef(Species);
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, new UpgradeTree(Content.Upgrades(), levels, Species));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), stage, Seeds.Make("city", Seed));
        RampageSim sim = new RampageSim(stats, CityGrowth.ForStats(stats), layout, Seeds.Make("army", Seed));
        GDict ability = species["ability"];
        sim.abilityType = Gd.Str(ability["type"]);
        sim.body.UseSpecies(Species);
        return sim;
    }

    // One straight line at the nearest building: a turn bleeds the run.
    static Vector2 Toward(RampageSim sim)
    {
        Vector2 goal = sim.NearestStanding(sim.kaijuPos);
        if (double.IsInfinity(goal.x) || goal == sim.kaijuPos) return sim.facing;
        return (goal - sim.kaijuPos).Normalized();
    }

    static void Check(bool ok, string what)
    {
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL leap: " + what);
    }
}
