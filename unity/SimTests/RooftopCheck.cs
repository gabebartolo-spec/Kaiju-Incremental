// The Rooftop Taskforce (D-063, D-076), sim side and the view's maths: squads stand on real roofs, fire only
// with the kaiju in reach (one rooftop_fired event a volley), die with the cell under them (one
// rooftop_destroyed), and RooftopAim puts every soldier on the squad's roof facing the kaiju and every round on
// one of the bones nearest its shooter.
using System;
using System.IO;
using Kaiju.Sim;

static class RooftopCheck
{
    const long Tier = 1, Seed = 1;
    const double Dt = 1.0 / 60.0;
    const int Ticks = 240, Draws = 200;

    static int failures;

    public static int Run()
    {
        failures = 0;
        string root = AppContext.BaseDirectory;
        while (!File.Exists(Path.Combine(root, "data", "tuning.json"))) root = Path.GetDirectoryName(root);
        Kaiju.Sim.FileAccess.Root = root;
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), new UpgradeTree(Content.Upgrades()));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), Tier, Seeds.Make("city", Seed));
        RampageSim sim = new RampageSim(stats, CityGrowth.TuningFor(Content.Tuning(), Tier), layout, Seeds.Make("army", Seed));
        Army army = sim.armyUnits;
        GDict cfg = sim.army["rooftop"];
        int size = (int)Num.I(cfg["squad_size"]);
        long squads = army.squads.Size();
        Must(squads > 0, "no squad was placed");
        if (squads == 0) return failures;

        // Placement: on the column's real roof, high enough, in the arena.
        foreach (Army.Squad squad in army.squads)
        {
            RampageSim.Building b = sim.buildings[squad.building];
            Vector3i c = squad.cell;
            Must(b.inArena, $"squad {squad.id} stands outside the arena");
            Must(b.frame.Alive(c), $"squad {squad.id} stands on a dead cell");
            Must(c.y == b.frame.TopBelow(c.x, c.z, b.height), $"squad {squad.id} is not on its column's top");
            Must(c.y >= Num.I(cfg["min_height"]) - 1, $"squad {squad.id} stands below min_height");
            Stances(sim, squad, b, size);
        }

        // Off: the kaiju far out of reach, nobody fires.
        long before = Fired(sim);
        sim.kaijuPos = new Vector2(sim.arenaHalf * 10.0, sim.arenaHalf * 10.0);
        for (int i = 0; i < Ticks; i++) army._StepSquads(Dt);
        Must(army.volleys == 0 && Fired(sim) == before, $"{army.volleys} volleys with the kaiju out of reach");

        // On: the kaiju beside the first squad; every volley is one event and costs hp.
        Army.Squad first = army.squads[0];
        double hp = sim.hp;
        sim.kaijuPos = first.pos + new Vector2(1, 0);
        for (int i = 0; i < Ticks; i++) army._StepSquads(Dt);
        long events = Fired(sim) - before;
        Must(army.volleys > 0, "no volley with the kaiju beside a squad");
        Must(events == army.volleys, $"{events} rooftop_fired events for {army.volleys} volleys");
        Must(sim.hp < hp, "the volleys cost no hp");

        // The roof cell goes: the squad goes with it, with one event where it stood.
        long id = first.id;
        Vector3 stood = sim.buildings[first.building].ChunkWorld(first.cell);
        sim.buildings[first.building].frame.Remove(first.cell);
        Must(army._StepSquads(Dt), "a squad outlived its roof cell");
        army._ClearDeadSquads();
        Must(army.squads.Size() == squads - 1, $"{squads - army.squads.Size()} squads cleared for one lost roof cell");
        Must(army.rooftopsDestroyed == 1, $"rooftopsDestroyed is {army.rooftopsDestroyed}");
        int destroyed = 0;
        foreach (GDict e in sim.events)
        {
            if (Gd.Str(e["type"]) != "rooftop_destroyed") continue;
            destroyed++;
            Must(Num.I(e["squad"]) == id, "rooftop_destroyed names the wrong squad");
            Must(Math.Abs(Num.F(e["y"]) - (stood.y + 0.5)) < 1e-6, "rooftop_destroyed is not at the roof");
        }
        Must(destroyed == 1, $"{destroyed} rooftop_destroyed events");

        Rounds();
        Console.WriteLine($"rooftops: {squads} squads of {size}, {army.volleys} volleys, {failures} failed");
        return failures;
    }

    static long Fired(RampageSim sim)
    {
        long n = 0;
        foreach (GDict e in sim.events)
            if (Gd.Str(e["type"]) == "rooftop_fired") n++;
        return n;
    }

    // Every soldier on the squad's own roof, at roof height, facing the kaiju wherever it stands.
    static void Stances(RampageSim sim, Army.Squad squad, RampageSim.Building b, int size)
    {
        Rect2 roof = RooftopAim.Roof(b, squad.cell);
        double feet = RooftopAim.Feet(b, squad.cell);
        Must(In(roof, squad.pos), $"squad {squad.id}: its roof does not hold it");
        Must(feet >= squad.cell.y + 1.0, $"squad {squad.id}: feet under the roof");
        foreach (Vector2 off in new[] { new Vector2(12, 0), new Vector2(-7, 9), new Vector2(0.5, -20), new Vector2(0, 0) })
        {
            Vector2 kaiju = squad.pos + off;
            Vector2 to = off == Vector2.ZERO ? new Vector2(0, -1) : off.Normalized();
            for (int k = 0; k < size; k++)
            {
                Transform3D t = RooftopAim.Stance(squad.pos, kaiju, roof, feet, k, size);
                Must(In(roof, new Vector2(t.origin.x, t.origin.z)), $"squad {squad.id} soldier {k} stands off the roof");
                Must(t.origin.y == (float)feet, $"squad {squad.id} soldier {k} is not at roof height");
                Vector3 f = RooftopAim.Forward(t);
                Must(f.x * to.x + f.z * to.y > 0.999, $"squad {squad.id} soldier {k} faces away from the kaiju");
                Vector3 muzzle = RooftopAim.Muzzle(t, 0.065);
                Must(muzzle.y > t.origin.y, $"squad {squad.id} soldier {k}: the muzzle is not above the feet");
            }
        }
    }

    static bool In(Rect2 r, Vector2 p) =>
        p.x >= r.position.x - 1e-4 && p.y >= r.position.y - 1e-4 && p.x <= r.end.x + 1e-4 && p.y <= r.end.y + 1e-4;

    // A round strikes one of the NEAREST bones, all of them in turn, on a cube facing the shooter.
    static void Rounds()
    {
        RandomNumberGenerator rng = Seeds.Make("rooftop_check", 1);
        double[] far = { 9, 1, 5, 3, 7, 11, 13 };
        bool[] seen = new bool[far.Length];
        for (int i = 0; i < Draws; i++)
        {
            int pick = RooftopAim.Pick(far, far.Length, rng);
            if (pick < 0 || pick >= far.Length)
            {
                Must(false, $"Pick gave {pick}");
                continue;
            }
            seen[pick] = true;
        }
        Must(seen[0] && seen[1] && seen[2] && seen[3] && seen[4], "Pick never chose one of the five nearest");
        Must(!seen[5] && !seen[6], "Pick chose a bone past the five nearest");
        Must(RooftopAim.Pick(far, 0, rng) == -1, "Pick chose from no bones");

        // Cubes in a ring round the bone, the shooter out along +x.
        Vector3 axis = new Vector3(3, 2, -4);
        Vector3[] ring = new Vector3[32];
        for (int i = 0; i < ring.Length; i++)
            ring[i] = axis + new Vector3(Math.Cos(i * Math.PI / 16.0), 0, Math.Sin(i * Math.PI / 16.0));
        for (int i = 0; i < Draws; i++)
        {
            int cell = RooftopAim.Facing(ring.Length, c => ring[c], axis, axis + new Vector3(30, 5, 0), rng);
            Must(cell >= 0 && ring[cell].x - axis.x >= RooftopAim.FACING - 1e-4, $"a round struck cube {cell}, on the far side");
        }
        Must(RooftopAim.Facing(0, c => axis, axis, axis, rng) == -1, "Facing chose a cube of a bone with none");

        long state = rng.state;
        Must(RooftopAim.Wait(0, rng) == 0 && rng.state == state, "the first rifle waits or draws");
        for (int i = 0; i < Draws; i++)
        {
            int wait = RooftopAim.Wait(1, rng);
            Must(wait >= RooftopAim.RAGGED_FROM && wait <= RooftopAim.RAGGED_FRAMES, $"a rifle waits {wait} frames");
        }
        double flight = RooftopAim.Flight(new Vector3(0, 0, 0), new Vector3(RooftopAim.TRACER_SPEED, 0, 0));
        Must(RooftopAim.Frames(flight) == RooftopAim.TICKS_PER_SECOND, "a round flying TRACER_SPEED metres does not take a second");
    }

    static void Must(bool ok, string what)
    {
        if (ok) return;
        failures++;
        if (failures <= 20) Console.WriteLine("FAIL rooftops: " + what);
    }
}
