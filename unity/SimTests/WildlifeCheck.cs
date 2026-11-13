// The wildlife (Rampage/Wildlife.cs; scenes/wildlife_view.gd). On the wildlife suite's two towers, the port builds
// Godot's gulls, pigeons and whale and moves them as Godot does, step for step, through a roar beside the towers, a
// section landing and a roar far away (golden/wildlife.txt, tools/unity/dump_wildlife_golden.gd). Player-effect
// fixture "wildlife.roar" (tests/run_wildlife_tests.gd): with no roar (off) every pigeon stays on its roof; a roar
// beside them (on) puts every one up; a roar out of range scatters nothing; the whale surfaces within its first
// window, dives at once on a roar, surfaces 2 or 3 times a run and is then gone; the same seed flies the same gulls.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Sim;

static class WildlifeCheck
{
    const double DT = 1.0 / 15.0, RISEN = 3.0, LONG_RUN = 400.0, NEAR = 0.002;
    const int STEPS = 1800, EVERY = 60, ROAR_AT = 150, FALL_AT = 600, FAR_AT = 900;
    static readonly Vector3 FAR = new Vector3(5000.0, 0.0, 5000.0);
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        RoarScattersPigeons();
        FarRoarLeavesThem();
        WhaleSurfacesAndDives();
        Seeded();
        Godot();
        Console.WriteLine(failed == 0 ? $"wildlife: ok ({checks} checks)" : $"wildlife: {failed} of {checks} failed");
        return failed;
    }

    static GDict Tower(double x, double z, long h)
    {
        var t = new GDict();
        t["x"] = x;
        t["z"] = z;
        t["w"] = 4L;
        t["d"] = 4L;
        t["h"] = h;
        t["tier"] = 1L;
        t["style"] = 0L;
        return t;
    }

    // tests/run_wildlife_tests.gd _view: the suite's two towers.
    static Wildlife Make()
    {
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), new UpgradeTree(Content.Upgrades()));
        var layout = new GArray<GDict>();
        layout.Append(Tower(0.0, 0.0, 20L));
        layout.Append(Tower(12.0, 6.0, 16L));
        return new Wildlife(new RampageSim(stats, Content.Tuning(), layout, Seeds.Make("army", 0)));
    }

    static void Steps(Wildlife w, double seconds)
    {
        for (int n = 0; n < (int)Math.Ceiling(seconds / DT); n++) w.Step(DT);
    }

    static Wildlife.Flock Kind(Wildlife w, string kind) => w.flocks.Find(f => f.kind == kind);

    static List<double> Heights(Wildlife w) => Kind(w, "pigeon").birds.ConvertAll(b => (double)b.pos.y);

    static GDict Roar() => new GDict { ["type"] = "ultimate" };

    static void RoarScattersPigeons()
    {
        Wildlife still = Make(), roared = Make();
        List<double> before = Heights(roared);
        Check(before.Count > 0, $"pigeons sit on the towers' roofs ({before.Count})");
        roared.OnEvent(Roar(), Vector3.ZERO);
        Steps(still, 2.0);
        Steps(roared, 2.0);
        List<double> stayed = Heights(still), after = Heights(roared);
        bool same = true;
        int risen = 0;
        for (int i = 0; i < before.Count; i++)
        {
            same &= stayed[i] == before[i];
            risen += after[i] > before[i] + RISEN ? 1 : 0;
        }
        Check(same, "off: with no roar every pigeon stays on its roof");
        Check(roared.scattered >= before.Count && risen == after.Count, $"on: a roar beside the roofs puts every pigeon up ({risen} of {after.Count} risen)");
    }

    static void FarRoarLeavesThem()
    {
        Wildlife w = Make();
        List<double> before = Heights(w);
        w.OnEvent(new GDict { ["type"] = "leap" }, FAR);
        Steps(w, 1.0);
        List<double> after = Heights(w);
        bool same = true;
        for (int i = 0; i < before.Count; i++) same &= after[i] == before[i];
        Check(w.scattered == 0 && same, $"a roar out of range scatters nothing ({w.scattered})");
    }

    static void WhaleSurfacesAndDives()
    {
        Wildlife w = Make();
        GDict cfg = (GDict)Content.Section("wildlife")["whale"];
        GArray<Variant> first = cfg["first"], times = cfg["surfacings"];
        double waited = 0.0;
        while (w.whaleState == "wait" && waited < Num.F(first[1]) + DT)
        {
            Steps(w, DT);
            waited += DT;
        }
        Steps(w, Num.F(cfg["rise_seconds"]) * 0.5);
        Check(w.surfacings == 1 && w.whaleVisible && w.whaleState == "rise", $"the whale surfaces first within {Num.F(first[1]):F0} s ({w.whaleState})");
        w.OnEvent(Roar(), FAR);
        Check(w.whaleState == "dive", "a roar sends it down at once, however far");
        Steps(w, Math.Max(Num.F(Content.Section("kaiju").Get("run_seconds", 300.0)), LONG_RUN));
        Check(w.surfacings >= Num.I(times[0]) && w.surfacings <= Num.I(times[1]), $"it surfaces {w.surfacings} times in a run (2 or 3)");
        Check(w.whaleState == "gone" && !w.whaleVisible, "then it is gone");
    }

    static void Seeded()
    {
        Wildlife a = Make(), b = Make();
        Steps(a, 30.0);
        Steps(b, 30.0);
        List<Wildlife.Bird> pa = Kind(a, "gull").birds, pb = Kind(b, "gull").birds;
        bool same = pa.Count > 0 && pa.Count == pb.Count;
        for (int i = 0; same && i < pa.Count; i++) same = pa[i].pos.DistanceTo(pb[i].pos) < NEAR;
        Check(same, "the same seed flies the same gulls");
    }

    // tools/unity/dump_wildlife_golden.gd's run, line for line.
    static void Godot()
    {
        string[] gold = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "wildlife.txt"));
        var ours = new List<string>();
        Wildlife w = Make();
        foreach (Wildlife.Flock flock in w.flocks)
            for (int i = 0; i < flock.birds.Count; i++)
            {
                Wildlife.Bird b = flock.birds[i];
                ours.Add(Inv($"B {flock.kind} {i} {b.pos.x:F4} {b.pos.y:F4} {b.pos.z:F4} {b.centre.x:F4} {b.centre.y:F4} {b.centre.z:F4} {b.radius:F4} {b.height:F4} {b.angle:F4} {b.spin:F4} {b.phase:F4} {Bool(b.perched)}"));
            }
        for (int s = 0; s < STEPS; s++)
        {
            if (s == ROAR_AT) w.OnEvent(Roar(), Vector3.ZERO);
            else if (s == FALL_AT) w.OnEvent(new GDict { ["type"] = "fall_land", ["building"] = 1L }, Vector3.ZERO);
            else if (s == FAR_AT) w.OnEvent(new GDict { ["type"] = "leap" }, FAR);
            w.Step(DT);
            if (s % EVERY == 0) Dump(w, s, ours);
        }
        ours.Add($"END {w.scattered} {w.surfacings} {w.dives}");
        Check(ours.Count == gold.Length, $"as many lines as Godot's wildlife ({ours.Count} vs {gold.Length})");
        int same = 0, firstBad = -1;
        for (int i = 0; i < Math.Min(ours.Count, gold.Length); i++)
        {
            bool ok = Match(ours[i], gold[i]);
            same += ok ? 1 : 0;
            if (!ok && firstBad < 0) firstBad = i;
        }
        if (firstBad >= 0) Console.WriteLine($"  first diff line {firstBad + 1}:\n    ours {ours[firstBad]}\n    gold {gold[firstBad]}");
        Check(same == gold.Length, $"each bird and the whale as Godot's ({same} of {gold.Length} lines within {NEAR})");
        Check(w.scattered > 0 && w.dives > 0, $"the run scatters birds ({w.scattered}) and sends the whale down ({w.dives})");
    }

    static void Dump(Wildlife w, int s, List<string> ours)
    {
        foreach (Wildlife.Flock flock in w.flocks)
            for (int i = 0; i < flock.birds.Count; i++)
            {
                Wildlife.Bird b = flock.birds[i];
                ours.Add(Inv($"S {s} {flock.kind} {i} {b.pos.x:F4} {b.pos.y:F4} {b.pos.z:F4} {b.x.x:F4} {b.x.y:F4} {b.x.z:F4} {b.z.x:F4} {b.z.y:F4} {b.z.z:F4} {Bool(b.perched)}"));
            }
        ours.Add(Inv($"W {s} {w.whaleState} {Bool(w.whaleVisible)} {w.whaleAt.x:F4} {w.whaleAt.y:F4} {w.whaleAt.z:F4} {w.whaleYaw:F4}"));
    }

    static string Bool(bool b) => b ? "true" : "false";

    static string Inv(FormattableString s) => s.ToString(CultureInfo.InvariantCulture);

    static bool Match(string a, string b)
    {
        string[] x = a.Split(' '), y = b.Split(' ');
        if (x.Length != y.Length) return false;
        for (int i = 0; i < x.Length; i++)
        {
            bool nx = double.TryParse(x[i], NumberStyles.Float, CultureInfo.InvariantCulture, out double vx);
            bool ny = double.TryParse(y[i], NumberStyles.Float, CultureInfo.InvariantCulture, out double vy);
            if (nx && ny ? Math.Abs(vx - vy) > NEAR : x[i] != y[i]) return false;
        }
        return true;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL wildlife: " + what);
    }
}
