// The Tripo street props' placement (Rampage/StreetProps.cs, after scenes/street_props.gd) is plain seeded maths, so
// it is held here against Godot 4.7.2 itself: with the same seed and the same calls, Godot's StreetProps placed the
// counts, spots and quarter turns pinned below (decor seed 12345, the repo's city.street_props). Also: a kerb's props
// keep kerb.clear apart and face the road; where the ground is taken none stands (on vs off); a car is a Tripo car
// only by the draw; a model with no baked file is never placed; the same seed gives the same street.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

static class StreetPropsCheck
{
    const long Seed = 12345;
    const double Near = 1.0e-4;
    const int Cars = 40, Third = 3;
    // Godot's run: the first kerb, the cars, the second kerb (only its y > 0 half is free).
    const int KerbProps = 29, TripoCars = 20, AfterSecond = 65;
    const string GodotKerb = "P02:1 P04:1 P06:1 P07:1 P08:5 P10:4 P11:3 P12:7 P18:3 P19:2 P20:1";
    const string GodotAll = "P02:1 P04:1 P05:4 P06:1 P07:1 P08:5 P10:4 P11:3 P12:7 P13:8 P14:2 P15:2 P17:4 P18:3 P19:2 P20:1";
    const string GodotTurns = "P02:2 P04:2 P05:1 P05:2 P06:0 P07:0 P08:0 P08:2 P10:0 P10:2 P11:0 P11:2 P12:0 P12:2 P13:0 P13:1 P13:2 P13:3 P14:0 P14:2 P15:0 P15:1 P17:1 P17:3 P18:0 P18:2 P19:0 P20:2";

    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        GDict city = Content.Section("city");
        GDict cfg = city["street_props"];
        GDict kerb = cfg["kerb"];
        double clear = Num.F(kerb["clear"]);

        // On: the calls Godot was given.
        StreetProps props = Street(city, (p, apart) => true);
        Check(props.placed.Count == KerbProps, $"a kerb's props, as Godot placed them: {props.placed.Count}");
        Check(Counts(props) == GodotKerb, $"the same models as Godot: {Counts(props)}");
        Check(At(props.placed[0], 2.949573, -2.45) && At(props.placed[KerbProps - 1], 57.43884, 2.45),
            $"the first and last spots are Godot's: {props.placed[0].at.x},{props.placed[0].at.y}");
        Spacing(props, clear);
        Facing(props);
        Check(Known(props, kerb["weights"]), "every pavement prop is one of kerb.weights");

        int tripo = Vehicles(props);
        Check(tripo == TripoCars, $"of {Cars} cars, the Tripo ones by the draw, as Godot: {tripo}");
        Check(Counts(props) == GodotAll, $"with the cars, the same models as Godot: {Counts(props)}");
        Check(Turns(props) == GodotTurns, $"each model's quarter turns are Godot's: {Turns(props)}");

        props.Kerb(new Vector2(5.0, -30.0), new Vector2(5.0, 30.0), 6.0, (p, apart) => p.y > 0.0);
        StreetProps.Placed last = props.placed[props.placed.Count - 1];
        Check(props.placed.Count == AfterSecond && At(last, 1.55, 28.59511), $"a second street, half of it taken, as Godot: {props.placed.Count}");
        bool onTaken = false;
        for (int i = KerbProps + TripoCars; i < props.placed.Count; i++) onTaken |= props.placed[i].at.y <= 0.0;
        Check(!onTaken, "no prop stands where the ground is taken");

        // Off: all the ground taken.
        StreetProps none = Street(city, (p, apart) => false);
        Check(none.placed.Count == 0, $"off: with no free pavement nothing is placed: {none.placed.Count}");

        // The same seed, the same street; another seed, another.
        StreetProps again = Street(city, (p, apart) => true);
        Vehicles(again);
        StreetProps first = Street(city, (p, apart) => true);
        Vehicles(first);
        Check(Same(again, first), "the same seed places the same props");
        var other = new StreetProps(city, Seed + 1);
        other.Kerb(new Vector2(0.0, 0.0), new Vector2(60.0, 0.0), 4.0, (p, apart) => true);
        Check(!Same(other, Street(city, (p, apart) => true)), "another seed places others");

        Check(!props.Put("P99", new Vector2(0.0, 0.0), new Vector2(0.0, 1.0)), "a model with no baked file is never placed");
        Turning();

        Console.WriteLine(failed == 0
            ? $"street props: {checks} checks, 0 failed (on: {KerbProps} on a 60 m street, {tripo} of {Cars} cars Tripo; off: 0)"
            : $"street props: {failed} failed");
        return failed;
    }

    static StreetProps Street(GDict city, Func<Vector2, double, bool> clearOf)
    {
        var props = new StreetProps(city, Seed);
        props.Kerb(new Vector2(0.0, 0.0), new Vector2(60.0, 0.0), 4.0, clearOf);
        return props;
    }

    // The cars Godot was asked for: every third across its street, every second stopped in the lane.
    static int Vehicles(StreetProps props)
    {
        int tripo = 0;
        for (int i = 0; i < Cars; i++)
        {
            Vector2 dir = i % Third > 0 ? new Vector2(1.0, 0.0) : new Vector2(0.0, 1.0);
            if (props.Vehicle(new Vector2(i * 3.0, 10.0), dir, i % 2 == 0)) tripo++;
        }
        return tripo;
    }

    static void Spacing(StreetProps props, double clear)
    {
        double nearest = double.MaxValue;
        for (int i = 0; i < props.placed.Count; i++)
            for (int j = i + 1; j < props.placed.Count; j++)
                nearest = Math.Min(nearest, props.placed[i].at.DistanceTo(props.placed[j].at));
        Check(nearest >= clear, $"no two props nearer than kerb.clear: {nearest} of {clear}");
    }

    // On a street along +x a prop on the -y kerb faces +y (two quarter turns), one on the +y kerb faces -y (none),
    // before the model's own yaw (0 for every model in the data).
    static void Facing(StreetProps props)
    {
        bool faces = true;
        foreach (StreetProps.Placed p in props.placed) faces &= p.turns == (p.at.y < 0.0 ? 2 : 0);
        Check(faces, "each pavement prop faces the road");
    }

    static void Turning()
    {
        Check(StreetProps.Quarter(new Vector2(0.0, -1.0)) == 0 && StreetProps.Quarter(new Vector2(-1.0, 0.0)) == 1
            && StreetProps.Quarter(new Vector2(0.0, 1.0)) == 2 && StreetProps.Quarter(new Vector2(1.0, 0.2)) == Third,
            "the quarter turn that brings a model's front (-Z) to a facing");
        int x = 0, z = -1;
        StreetProps.Turn(ref x, ref z, 1);
        Check(x == -1 && z == 0, $"one turn takes -Z to -X: {x},{z}");
        x = 2;
        z = -1;
        StreetProps.Turn(ref x, ref z, 2);
        Check(x == -2 && z == 1, $"two turns face a cell about: {x},{z}");
    }

    static bool At(StreetProps.Placed p, double x, double y) => Math.Abs(p.at.x - x) < Near && Math.Abs(p.at.y - y) < Near;

    static bool Known(StreetProps props, GDict weights)
    {
        foreach (StreetProps.Placed p in props.placed)
            if (!weights.Has(p.id)) return false;
        return true;
    }

    static bool Same(StreetProps a, StreetProps b)
    {
        if (a.placed.Count != b.placed.Count) return false;
        for (int i = 0; i < a.placed.Count; i++)
            if (a.placed[i].id != b.placed[i].id || a.placed[i].turns != b.placed[i].turns || a.placed[i].at != b.placed[i].at) return false;
        return true;
    }

    static string Counts(StreetProps props)
    {
        var rows = new List<string>();
        foreach (KeyValuePair<string, int> row in props.counts) rows.Add($"{row.Key}:{row.Value}");
        rows.Sort(StringComparer.Ordinal);
        return string.Join(" ", rows);
    }

    static string Turns(StreetProps props)
    {
        var rows = new SortedSet<string>(StringComparer.Ordinal);
        foreach (StreetProps.Placed p in props.placed) rows.Add($"{p.id}:{p.turns}");
        return string.Join(" ", rows);
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL street props: " + what);
    }
}
