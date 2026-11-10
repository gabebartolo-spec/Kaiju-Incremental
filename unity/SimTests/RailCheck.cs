// No golden rampage is held to its trains by name, and the Unity view only draws what the sim says, so the
// railway's sim is checked here the way tests/run_trains_tests.gd does in Godot: a train comes on the
// schedule, coupled on its track; a blow beside its locomotive derails it, breaks the track and says so in
// events; the wreck slides to rest off its rail; and the same seed leaves the same wreck.
using System;
using System.Globalization;
using System.Text;
using Kaiju.Sim;

static class RailCheck
{
    const double Dt = 1.0 / 60.0;
    const long Tier = 3, Seed = 1;
    const string Species = "reptilian";
    // The kaiju stands idle under the army's fire for the whole check; it must not die first.
    const double Toughness = 100.0;
    const double WaitSeconds = 120.0, WreckSeconds = 8.0, LineShare = 0.1, Near = 0.05;

    static int failures;
    static bool report;

    public static int Run()
    {
        failures = 0;
        FileAccess.Root = RepoRoot();
        report = true;
        string first = Play();
        report = false;
        string second = Play();
        report = true;
        Check(first == second, "the same seed left two different wrecks");
        Console.WriteLine($"rail: {first}");
        return failures;
    }

    static string RepoRoot()
    {
        string at = AppContext.BaseDirectory;
        while (!System.IO.File.Exists(System.IO.Path.Combine(at, "data", "tuning.json"))) at = System.IO.Path.GetDirectoryName(at);
        return at;
    }

    static void Check(bool ok, string what)
    {
        if (ok || !report) return;
        failures++;
        Console.WriteLine("FAIL rail: " + what);
    }

    // The replay's rampage (SimLog.Start): a real city of this tier, risen from the bay.
    static RampageSim Start()
    {
        GDict species = Content.SpeciesDef(Species);
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, new UpgradeTree(Content.Upgrades()));
        stats["hp"] = Num.F(stats["hp"]) * Toughness;
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), Tier, Seeds.Make("city", Seed));
        RampageSim sim = new RampageSim(stats, CityGrowth.TuningFor(Content.Tuning(), Tier), layout, Seeds.Make("army", Seed));
        GDict ability = species["ability"];
        sim.abilityType = Gd.Str(ability["type"]);
        sim.emerge.Start(sim);
        return sim;
    }

    // Steps until a train runs with its lead car past LineShare of the line (run_trains_tests.gd _until_running).
    static Rail.Train UntilRunning(RampageSim sim)
    {
        long ticks = (long)Math.Round(WaitSeconds / Dt);
        for (long i = 0; i < ticks; i++)
        {
            sim.Step(Dt, Vector2.ZERO, false, 0);
            foreach (Rail.Train train in sim.rail.trains)
                if (train.state == Rail.RUN && train.s > sim.rail.length * LineShare) return train;
        }
        return null;
    }

    static string Play()
    {
        RampageSim sim = Start();
        Rail rail = sim.rail;
        Rail.Train train = UntilRunning(sim);
        Check(train != null, $"no train ran within {WaitSeconds} s");
        if (train == null) return "no train";

        long cars = train.cars.Size();
        Check(cars == Num.I(rail.cfg["cars"]), $"a train has {cars} cars, tuning says {Num.I(rail.cfg["cars"])}");
        double pitch = Num.F(rail.cfg["car_length"]) + Num.F(rail.cfg["coupler_gap"]);
        for (long i = 0; i < cars; i++)
        {
            Rail.Car car = train.cars[i];
            Check(car.loco == (i == 0), $"car {i} loco is {car.loco}");
            Check(car.y == rail.deckY, $"car {i} runs at height {car.y}, the deck is {rail.deckY}");
            Check(Math.Abs(car.pos.x - rail.TrackX(train.dir)) < Near, $"car {i} is at x {car.pos.x}, its track is {rail.TrackX(train.dir)}");
            if (i > 0)
            {
                double gap = car.pos.DistanceTo(train.cars[i - 1].pos);
                Check(Math.Abs(gap - pitch) < Near, $"car {i} follows at {gap}, coupled spacing is {pitch}");
            }
        }
        Check(train.v > 0.0, "the running train stands still");

        // A blow from beside the locomotive. Step replaces the event list, so it is read before the next one.
        Rail.Car lead = train.cars[0];
        Vector2 leadWas = lead.pos;
        long derailedWas = rail.derailed;
        rail.Derail(train, 0, new Vector2(lead.pos.x - 1.0, lead.pos.y));
        long said = 0, broken = 0;
        foreach (GDict e in sim.events)
        {
            string type = Gd.Str(e["type"]);
            if (type == "train_derailed" && Num.I(e["train"]) == train.id) said++;
            if (type == "track_broken") broken++;
        }
        Check(said == 1, $"{said} train_derailed events for train {train.id}");
        Check(broken >= 1, "the blow broke no track (no track_broken event)");
        Check(rail.derailed > derailedWas, "the derailed count did not rise");
        Check(train.state == Rail.WRECK, $"the derailed train's state is {train.state}");

        long more = (long)Math.Round(WreckSeconds / Dt);
        for (long i = 0; i < more; i++) sim.Step(Dt, Vector2.ZERO, false, 0);
        Check(!sim.over, "the kaiju died during the check, so the wreck stopped stepping");
        Check(rail.trains.Has(train), "the wreck was removed from the line");
        bool offRail = false;
        StringBuilder text = new StringBuilder($"train {train.id} dir {train.dir}, derailed {rail.derailed}, wreck");
        for (long i = 0; i < cars; i++)
        {
            Rail.Car car = train.cars[i];
            Check(car.vel.Length() == 0.0, $"car {i} still slides at {car.vel.Length()} m/s after {WreckSeconds} s");
            offRail = offRail || car.roll != 0.0 || car.y < rail.deckY;
            text.Append(string.Format(CultureInfo.InvariantCulture, " ({0:R},{1:R},{2:R} yaw {3:R} roll {4:R})", car.pos.x, car.y, car.pos.y, car.yaw, car.roll));
        }
        Check(offRail, "no car rolled or fell: the wreck sits on its rail");
        Check(lead.pos.DistanceTo(leadWas) > Near, "the locomotive did not move after the derailment");
        return text.ToString();
    }
}
