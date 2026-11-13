// The far beast (Rampage/FarBeastWalk.cs, FarBeastGait*.cs, FarBeastRig.cs; scenes/far_beast.gd, gait_hexapod.gd).
// On the repo's own insectoid (baked here as slicebake bakes it), the port puts its feet down where Godot's does,
// frame for frame (golden/far_beast.txt, tools/unity/dump_far_beast_golden.gd). Player-effect fixture
// "skyline.beast": walking the far rampage's path (on) its feet come down all along the way it went, all four of
// them, under it; standing (off) each foot only shuffles on its spot. The same walk twice puts the same feet down;
// a stomp drops the body.
using System;
using System.Collections.Generic;
using System.IO;
using Kaiju.Sim;

static class FarBeastCheck
{
    const double SHORE = -400.0, SALT = 16, DT = 1.0 / 60.0, WALK_S = 20.0;
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        string dir = Path.Combine(Path.GetTempPath(), "kaiju_far_beast_check");
        Directory.CreateDirectory(dir);
        string why = CrocBake.ExportBeast(dir, repoRoot);
        Check(why == "", "the far beast bakes from the repo's insectoid: " + why);
        if (why != "") return Report();
        string json = File.ReadAllText(Path.Combine(dir, "far_beast.rig.json"));
        GDict cfg = Content.Section("skyline_rampage");
        var plan = new SkylineRampagePlan(cfg, new List<SkylineRampagePlan.Box>(), SHORE,
            Seeds.Derive(Seeds.Make("fx", 0), (long)SALT), SkylineRampage_PUFF);
        double height = Num.F(cfg["height"]);
        List<(string id, BV at)> walked = Walk(json, height, plan, true, out double minX, out double maxX);
        List<(string id, BV at)> stood = Walk(json, height, plan, false, out _, out _);
        Walks(walked, stood, height, minX, maxX);
        List<(string id, BV at)> again = Walk(json, height, plan, true, out _, out _);
        bool same = again.Count == walked.Count;
        for (int i = 0; same && i < walked.Count; i++) same = again[i].id == walked[i].id && again[i].at == walked[i].at;
        Check(same, "the same walk twice puts the same feet down in the same places");
        Stomps(json, height);
        Godot(json);
        return Report();
    }

    const double SkylineRampage_PUFF = 9.0;  // SkylineRampage.PUFF (the view class is not in this assembly)

    static int Report()
    {
        Console.WriteLine(failed == 0 ? $"far beast: ok ({checks} checks)" : $"far beast: {failed} of {checks} failed");
        return failed;
    }

    // WALK_S seconds at 60 fps along the plan's path (on) or standing at its start (off): the feet that came down.
    static List<(string, BV)> Walk(string json, double height, SkylineRampagePlan plan, bool moving, out double minX, out double maxX)
    {
        var beast = new FarBeastWalk(json, height);
        var feet = new List<(string, BV)>();
        beast.FootPlanted += (id, strength, at) => feet.Add((id, at));
        double speed = Num.F(Content.Section("skyline_rampage")["speed"]);
        minX = double.MaxValue;
        maxX = double.MinValue;
        for (double t = 0.0; t < WALK_S; t += DT)
        {
            double at = moving ? t : 0.0;
            double x = plan.BeastX(at);
            minX = Math.Min(minX, x);
            maxX = Math.Max(maxX, x);
            beast.Walk(DT, new BV(x, SkylineRampagePlan.GROUND_Y, plan.pathZ), FarBeastWalk.Yaw(plan.Velocity(at), speed));
        }
        return feet;
    }

    static void Walks(List<(string id, BV at)> walked, List<(string id, BV at)> stood, double height, double minX, double maxX)
    {
        var ids = new HashSet<string>();
        double lo = double.MaxValue, hi = double.MinValue;
        foreach ((string id, BV at) in walked)
        {
            ids.Add(id);
            lo = Math.Min(lo, at.x);
            hi = Math.Max(hi, at.x);
        }
        double went = maxX - minX;
        Console.WriteLine($"  far beast walked {went:F1} m: {walked.Count} footfalls over x {lo:F1}..{hi:F1}; standing: {stood.Count}");
        Check(ids.Count == 4, $"all four feet step ({string.Join(",", ids)})");
        Check(hi - lo > went * 0.8, $"its footfalls spread along the {went:F1} m it walked ({hi - lo:F1} m)");
        Check(lo > minX - height && hi < maxX + height, "every footfall is under the beast, within its height of its path");
        double spread = 0.0;
        var spots = new Dictionary<string, (double lo, double hi)>();
        foreach ((string id, BV at) in stood)
        {
            (double lo, double hi) r = spots.TryGetValue(id, out var have) ? have : (at.x, at.x);
            spots[id] = r = (Math.Min(r.lo, at.x), Math.Max(r.hi, at.x));
            spread = Math.Max(spread, r.hi - r.lo);
        }
        Check(spread < height * STAND_SHARE, $"standing, each foot stays on its spot ({spread:F1} m at most)");
    }

    const double STAND_SHARE = 0.15, NEAR = 0.002;
    const int FRAMES = 300;
    const double GODOT_WALK = 0.9;

    // tools/unity/dump_far_beast_golden.gd's two runs (the model's own units, size 1): the same feet down on the same
    // frames, in the same places, as Godot's.
    static void Godot(string json)
    {
        string[] gold = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "far_beast.txt"));
        var ours = new List<string>();
        foreach (string mode in new[] { "stand", "walk" })
        {
            double modelHeight = new FarBeastWalk(json, 1.0).modelHeight;
            var beast = new FarBeastWalk(json, modelHeight);
            int frame = 0;
            beast.FootPlanted += (id, st, at) => ours.Add($"FF {mode} {frame} {id} {st} {at.x} {at.y} {at.z}");
            double x = 0.0;
            for (frame = 0; frame < FRAMES; frame++)
            {
                if (mode == "walk") x += GODOT_WALK * DT;
                beast.Walk(DT, new BV(x, 0, 0), mode == "walk" ? Math.PI * 0.5 : 0.0);
            }
            BV p = beast.rig.Global("thorax0").origin;
            ours.Add($"END {mode} thorax {p.x} {p.y} {p.z}");
        }
        Check(ours.Count == gold.Length, $"as many footfalls as Godot's far beast ({ours.Count - 2} vs {gold.Length - 2})");
        int same = 0;
        for (int i = 0; i < Math.Min(ours.Count, gold.Length); i++) same += Match(ours[i], gold[i]) ? 1 : 0;
        Check(same == gold.Length, $"each footfall on Godot's frame, foot and spot ({same} of {gold.Length} lines within {NEAR})");
    }

    static bool Match(string a, string b)
    {
        string[] x = a.Split(' '), y = b.Split(' ');
        if (x.Length != y.Length) return false;
        for (int i = 0; i < x.Length; i++)
        {
            bool nx = double.TryParse(x[i], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out double vx);
            bool ny = double.TryParse(y[i], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out double vy);
            if (nx && ny ? Math.Abs(vx - vy) > NEAR : x[i] != y[i]) return false;
        }
        return true;
    }

    // A stomp (a tower going down) drops the body: the thorax sits lower a frame after it than without.
    static void Stomps(string json, double height)
    {
        var calm = new FarBeastWalk(json, height);
        var stomped = new FarBeastWalk(json, height);
        BV at = new BV(0.0, SkylineRampagePlan.GROUND_Y, 0.0);
        for (int i = 0; i < 60; i++)
        {
            calm.Walk(DT, at, Math.PI);
            stomped.Walk(DT, at, Math.PI);
        }
        stomped.Stomp();
        calm.Walk(DT, at, Math.PI);
        stomped.Walk(DT, at, Math.PI);
        double a = calm.rig.Global("thorax0").origin.y, b = stomped.rig.Global("thorax0").origin.y;
        Check(b < a, $"a stomp drops the body ({a:F3} -> {b:F3} little-world units)");
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL far beast: " + what);
    }
}
