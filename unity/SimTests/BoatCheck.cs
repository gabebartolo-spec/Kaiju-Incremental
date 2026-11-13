// The boats (Rampage/Boats.cs; scenes/boat_view.gd, D-404). On the boat suite's own sim, the port moors Godot's
// boats in Godot's places and moves them as Godot does, step for step, while the kaiju chases three of them
// (golden/boats.txt, tools/unity/dump_boat_golden.gd). Player-effect fixture "boats.wake" (tests/run_boat_tests.gd):
// with the kaiju far away (off) they only rock gently on the swell and stay put; with him close (on) they rock
// harder and are pushed away; one he wades into rolls over and sinks out of sight; walking after a river boat at
// his opening pace he catches it; the same seed moors the same boats.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Sim;

static class BoatCheck
{
    const double DT = 1.0 / 15.0, WALK = 2.5, START = 14.0, CATCH_S = 12.0, NEAR = 0.002;
    const int STEPS = 600, EVERY = 15, FAR_STEPS = 90;
    static readonly Vector2 FAR = new Vector2(5000.0, 5000.0);
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        Moored(Make());
        FarLeavesThem(Make());
        WakePushes(Make());
        WadeCapsizes(Make());
        WalkCatches(Make());
        Seeded();
        Godot();
        Console.WriteLine(failed == 0 ? $"boats: ok ({checks} checks)" : $"boats: {failed} of {checks} failed");
        return failed;
    }

    // tests/run_boat_tests.gd _view: the default city of data/tuning.json, no layout.
    static Boats Make()
    {
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), new UpgradeTree(Content.Upgrades()));
        var sim = new RampageSim(stats, Content.Tuning(), new GArray<GDict>(), Seeds.Make("army", 0));
        return new Boats(sim.city);
    }

    static void Steps(Boats boats, double seconds, Vector2 kaiju)
    {
        for (int n = 0; n < (int)Math.Ceiling(seconds / DT); n++) boats.Step(DT, kaiju);
    }

    static int Where(Boats boats, string place) => boats.boats.FindAll(b => b.where == place).Count;

    // The roll a pose gives: its x column's rise (turn * roll * pitch takes x to (cos roll, sin roll, 0) turned).
    static double Roll(Boats.Boat b) => Math.Asin(Math.Clamp((b.basis * new Vector3(1f, 0f, 0f)).y, -1.0, 1.0));

    static void Moored(Boats boats)
    {
        foreach (string place in new[] { "pier", "bay", "river" })
            Check(Where(boats, place) > 0, $"boats moored: {place} ({Where(boats, place)})");
        Check(boats.boats.TrueForAll(b => b.height > 0.0 && Kaiju.Sim.FileAccess.FileExists(Boats.File(b.id))), "every boat has its voxel model");
    }

    static void FarLeavesThem(Boats boats)
    {
        var start = new List<Vector2>();
        foreach (Boats.Boat b in boats.boats) start.Add(b.pos);
        double maxRoll = 0.0;
        for (int n = 0; n < FAR_STEPS; n++)
        {
            boats.Step(DT, FAR);
            foreach (Boats.Boat b in boats.boats) maxRoll = Math.Max(maxRoll, Math.Abs(Roll(b)));
        }
        int moved = 0;
        for (int i = 0; i < boats.boats.Count; i++) moved += boats.boats[i].pos.DistanceTo(start[i]) > 0.001 ? 1 : 0;
        Check(moved == 0, $"no kaiju near (off): no boat drifts ({moved} moved)");
        Check(maxRoll > 0.001, "no kaiju near (off): the boats still rock on the swell");
        double gentle = Gd.DegToRad(Num.F(Content.Section("boats")["rock_deg"]) + 1.0);
        Check(maxRoll < gentle, $"no kaiju near (off): the swell's rock stays gentle ({maxRoll:F4} rad)");
        Check(boats.capsized == 0, "no kaiju near (off): none capsizes");
    }

    static void WakePushes(Boats boats)
    {
        GDict cfg = Content.Section("boats");
        Boats.Boat b = boats.boats[0];
        Vector2 kaiju = b.pos + new Vector2(Num.F(cfg["capsize_radius"]) * 2.0, 0.0);
        double before = b.pos.DistanceTo(kaiju);
        Steps(boats, DT, kaiju);
        double wake = b.wake;
        Steps(boats, 3.0, kaiju);
        double after = b.pos.DistanceTo(kaiju);
        Check(after > before + 0.1, $"his wake (on) pushes the boat away ({before:F2} -> {after:F2})");
        Check(wake > 0.5, $"his wake (on) rocks the boat harder (wake {wake:F2})");
        Check(!b.sunk && b.flip == 0.0, "outside capsize reach it stays upright");
    }

    static void WadeCapsizes(Boats boats)
    {
        GDict cfg = Content.Section("boats");
        Boats.Boat b = boats.boats[0];
        Steps(boats, DT, b.pos);
        Check(boats.capsized == 1, "the boat he wades into rolls over");
        Steps(boats, Num.F(cfg["capsize_s"]) + Num.F(cfg["sink_s"]) + 1.0, FAR);
        Check(b.sunk && !b.visible, "then it sinks out of sight");
    }

    // Director 2026-10-31: walking after a river boat from 14 u at his opening pace, he capsizes it.
    static void WalkCatches(Boats boats)
    {
        Boats.Boat b = boats.boats.Find(x => x.where == "river");
        Vector2 kaiju = b.pos + new Vector2(START, 0.0);
        for (int n = 0; n < (int)Math.Ceiling(CATCH_S / DT) && boats.capsized == 0; n++)
        {
            kaiju += (b.pos - kaiju).LimitLength(WALK * DT);
            boats.Step(DT, kaiju);
        }
        Check(boats.capsized == 1, "walking after a boat he catches and capsizes it");
    }

    static void Seeded()
    {
        Boats a = Make(), b = Make();
        bool same = a.boats.Count == b.boats.Count && a.boats.Count > 0;
        for (int i = 0; same && i < a.boats.Count; i++) same = a.boats[i].id == b.boats[i].id && a.boats[i].pos == b.boats[i].pos;
        Check(same, $"the same seed moors the same boats ({a.boats.Count})");
    }

    // tools/unity/dump_boat_golden.gd's run: the same boats moored, then every boat's pose every EVERY steps while
    // the kaiju chases the first bay, pier and river boat in turn, and as many capsized.
    static void Godot()
    {
        string[] gold = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "boats.txt"));
        var ours = new List<string>();
        Boats boats = Make();
        for (int i = 0; i < boats.boats.Count; i++)
        {
            Boats.Boat b = boats.boats[i];
            ours.Add(Inv($"B {i} {b.id} {b.where} {b.pos.x:F4} {b.pos.y:F4} {b.yaw:F4} {b.y:F4} {b.hz:F4} {b.phase:F4}"));
        }
        Chase(boats, ours);
        ours.Add($"END capsized {boats.capsized}");
        Check(ours.Count == gold.Length, $"as many lines as Godot's boats ({ours.Count} vs {gold.Length})");
        int same = 0;
        for (int i = 0; i < Math.Min(ours.Count, gold.Length); i++) same += Match(ours[i], gold[i]) ? 1 : 0;
        Check(same == gold.Length, $"each boat moored and posed as Godot's ({same} of {gold.Length} lines within {NEAR})");
        Check(boats.capsized > 0, $"the chase capsizes boats ({boats.capsized})");
    }

    static void Chase(Boats boats, List<string> ours)
    {
        Boats.Boat[] chased = { boats.boats.Find(x => x.where == "bay"), boats.boats.Find(x => x.where == "pier"), boats.boats.Find(x => x.where == "river") };
        Vector2 kaiju = Vector2.ZERO;
        for (int s = 0; s < STEPS; s++)
        {
            Boats.Boat b = chased[s * chased.Length / STEPS];
            if (s % (STEPS / chased.Length) == 0) kaiju = b.pos + new Vector2(START, 0.0);
            kaiju += (b.pos - kaiju).LimitLength(WALK * DT);
            boats.Step(DT, kaiju);
            if (s % EVERY != 0) continue;
            for (int i = 0; i < boats.boats.Count; i++)
            {
                Boats.Boat o = boats.boats[i];
                Vector3 bx = o.basis * new Vector3(1f, 0f, 0f), by = o.basis * new Vector3(0f, 1f, 0f);
                ours.Add(Inv($"S {s} {i} {o.at.x:F4} {o.at.y:F4} {o.at.z:F4} {bx.x:F4} {bx.y:F4} {bx.z:F4} {by.x:F4} {by.y:F4} {by.z:F4} {(o.sunk ? "true" : "false")}"));
            }
        }
    }

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
        Console.WriteLine("  FAIL boats: " + what);
    }
}
