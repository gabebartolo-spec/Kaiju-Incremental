// The jet run on screen is AirstrikeView's reading of one sim event. This runs a live sim's clock out
// (tests/run_death_tests.gd _check_airstrike) and holds the event, and the formation the view draws from
// it (Rampage/AirstrikePath.cs), to what the player must see: one run, through him, square to his
// facing, the lead over him at half way, the wingmen behind and one each side, bombs before his death,
// and no jets at all when he is killed.
using System;
using Kaiju.Sim;

static class AirstrikeCheck
{
    const double Dt = 1.0 / 60.0;
    const int Tier = 1, Seed = 0;
    // The rise, and Godot's 30 s for a death to play out.
    const int MostRiseTicks = 60 * 120, MostDeathTicks = 60 * 30;
    const double Near = 0.01, Square = 0.001;
    const string Species = "reptilian";

    static int failed;

    public static int Run(string repoRoot)
    {
        failed = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        GDict death = Content.Section("death");
        GDict cfg = death["airstrike"];
        double spacing = Num.F(Content.Section("vehicles")["jet_spacing"]);

        RampageSim timed = Start();
        timed.timeLeft = 0.0;
        int runs = 0, bombs = 0, strikeAt = -1, firstBomb = -1, deathAt = -1, order = 0;
        GDict run = null;
        Vector2 pos = Vector2.ZERO, facing = Vector2.ZERO;
        for (int tick = 0; tick < MostDeathTicks && deathAt < 0; tick++)
        {
            foreach (GDict e in timed.Step(Dt, Vector2.ZERO, false))
            {
                string type = Gd.Str(e["type"]);
                order++;
                if (type == "airstrike")
                {
                    runs++;
                    run = e;
                    strikeAt = order;
                    pos = timed.kaijuPos;
                    facing = timed.facing;
                }
                else if (type == "airstrike_bomb")
                {
                    bombs++;
                    if (firstBomb < 0) firstBomb = order;
                }
                else if (type == "death_begin" && deathAt < 0) deathAt = order;
            }
        }
        Check(runs == 1, $"time's up flies one jet run: {runs}");
        Check(deathAt >= 0 && strikeAt >= 0 && strikeAt < deathAt, $"the jets come before his death: airstrike {strikeAt}, death_begin {deathAt}");
        Check(bombs == Num.I(cfg["bombs"]), $"every bomb lands before his death: {bombs} of {Num.I(cfg["bombs"])}");
        Check(firstBomb > strikeAt, $"the bombs follow the jets: airstrike {strikeAt}, first bomb {firstBomb}");
        long jets = 0;
        if (run != null)
        {
            Vector2 from = run["from"];
            Vector2 to = run["to"];
            double seconds = Num.F(run["seconds"]);
            jets = Num.I(run["jets"]);
            Vector2 along = (to - from).Normalized();
            Vector2 side = along.Orthogonal();
            Check(jets > 0 && jets == Num.I(cfg["jets"]), $"the event carries the jets: {jets}");
            Check(seconds > 0.0 && Num.F(run["altitude"]) > 0.0, $"the run takes time, above the ground: {seconds} s at {Num.F(run["altitude"])}");
            Check(((from + to) * 0.5).DistanceTo(pos) < Near, $"the run goes through him: middle {(from + to) * 0.5}, kaiju {pos}");
            Check(Math.Abs(along.Dot(facing)) < Square, $"the run is square to his facing: dot {along.Dot(facing)}");
            Check(Math.Abs(from.DistanceTo(to) - Num.F(cfg["run_length"])) < Near, $"the run is run_length long: {from.DistanceTo(to)}");
            double sides = 0.0;
            for (long i = 0; i < jets; i++)
            {
                Vector2 off = AirstrikePath.Offset(from, to, spacing, i);
                double back = spacing * AirstrikePath.Rank(i);
                Check(Math.Abs(off.Dot(along) + back) < Near, $"jet {i} flies {back} behind the lead: {-off.Dot(along)}");
                Check(Math.Abs(Math.Abs(off.Dot(side)) - back) < Near, $"jet {i} flies {back} to one side: {off.Dot(side)}");
                if (i == 1 || i == 2) sides += Math.Sign(off.Dot(side));
                Vector2 half = AirstrikePath.At(from, to, off, AirstrikePath.Share(seconds * 0.5, seconds));
                Check(half.DistanceTo(pos + off) < Near, $"jet {i} is abreast of him at half way: {half} against {pos + off}");
                Check(AirstrikePath.At(from, to, off, 0.0).DistanceTo(from + off) < Near, $"jet {i} starts at the run's start");
            }
            if (jets >= 3) Check(sides == 0.0, $"the wingmen fly one each side: {sides}");
            Check(AirstrikePath.Share(seconds, seconds) >= 1.0 && AirstrikePath.Share(seconds - Dt, seconds) < 1.0, "the jets are gone when the run's seconds are up, not a tick sooner");
        }

        RampageSim killed = Start();
        killed.hp = -killed.maxHp;
        int killedRuns = 0, killedDeaths = 0;
        for (int tick = 0; tick < MostDeathTicks && !killed.over; tick++)
            foreach (GDict e in killed.Step(Dt, Vector2.ZERO, false))
            {
                string type = Gd.Str(e["type"]);
                if (type == "airstrike") killedRuns++;
                if (type == "death_begin") killedDeaths++;
            }
        Check(killedDeaths == 1 && killedRuns == 0, $"a kill has no jet run: {killedDeaths} deaths, {killedRuns} runs");

        Console.WriteLine($"airstrike: {runs} run of {jets} jets, {bombs} bombs before his death, {killedRuns} runs on a kill, {failed} failed");
        return failed;
    }

    // SimLog.Start's sim, risen from the bay and standing.
    static RampageSim Start()
    {
        GDict species = Content.SpeciesDef(Species);
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, new UpgradeTree(Content.Upgrades()));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), Tier, Seeds.Make("city", Seed));
        RampageSim sim = new RampageSim(stats, CityGrowth.TuningFor(Content.Tuning(), Tier), layout, Seeds.Make("army", Seed));
        GDict ability = species["ability"];
        sim.abilityType = Gd.Str(ability["type"]);
        sim.emerge.Start(sim);
        for (int tick = 0; tick < MostRiseTicks && sim.emerge.active; tick++) sim.Step(Dt, Vector2.ZERO, false);
        Check(!sim.emerge.active, "the rise ends, so the clock can run");
        return sim;
    }

    static void Check(bool ok, string what)
    {
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL airstrike: " + what);
    }
}
