// The arena edge bollards (GameLogic/ArenaEdge.cs; scenes/arena_edge.gd) against Godot's own output
// (golden/arena_edge.txt, tools/unity/dump_arena_edge_golden.gd): at stages 1-4 in three cities, given Godot's street
// trees, the port finds the same streets near the line and stands the same bollards in the same places; and it passes
// Godot's own check (tests/lib/city_arena_edge.gd): none off the line, over water, on a street or in a trunk, and
// every side but the river's carries at least 35% of the bollards its dry length allows.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using S = Kaiju.Sim;

static class ArenaEdgeCheck
{
    // Godot writes 9 decimals of float32 values of a few hundred metres.
    const double TOL = 1e-5;
    // tests/lib/city_arena_edge.gd:42: each side carries at least this share of the bollards its dry length allows.
    const double SIDE_SHARE = 0.35;
    // tests/lib/city_arena_edge.gd:64-76 _dry: the line is walked a metre at a time, tested at each metre's middle.
    const double DRY_STEP = 1.0, DRY_MID = 0.5;
    static readonly string[] SIDES = { "n", "s", "e", "w" };
    static int failed, checks;

    sealed class Case
    {
        public int stage, mapSeed;
        public double arenaHalf, half;
        public readonly List<S.Vector2> trees = new List<S.Vector2>();
        public readonly List<string[]> roads = new List<string[]>(), posts = new List<string[]>();
        public string[] sides, dry;
    }

    public static int Run(string repoRoot)
    {
        S.FileAccess.Root = repoRoot;
        failed = 0;
        checks = 0;
        var cases = new List<Case>();
        foreach (string line in File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "arena_edge.txt")))
        {
            string[] x = line.Split(' ');
            if (x[0] == "CASE")
            {
                cases.Add(new Case { stage = int.Parse(x[1]), mapSeed = int.Parse(x[2]), arenaHalf = D(x[3]), half = D(x[4]) });
                continue;
            }
            Case c = cases[cases.Count - 1];
            switch (x[0])
            {
                case "TREE": c.trees.Add(new S.Vector2(D(x[1]), D(x[2]))); break;
                case "ROAD": c.roads.Add(x); break;
                case "POST": c.posts.Add(x); break;
                case "SIDE": c.sides = x; break;
                case "DRY": c.dry = x; break;
            }
        }
        int posts = 0;
        foreach (Case c in cases)
        {
            One(c);
            posts += c.posts.Count;
        }
        Check(cases.Count == 12, $"Godot wrote {cases.Count} cases (want stages 1-4 in three cities)");
        Console.WriteLine($"arena edge: {cases.Count} cities, {posts} bollards; {checks} checks, {failed} failed");
        return failed;
    }

    static void One(Case c)
    {
        string name = $"stage {c.stage}, map_seed {c.mapSeed}";
        S.GDict tuning = S.Content.Tuning().Duplicate(true);
        S.GDict city = tuning["city"];
        city["map_seed"] = c.mapSeed;
        S.GDict stats = S.UpgradeTree.RunStats(S.Content.Section("kaiju"), S.Content.SpeciesDef("reptilian"),
            new S.UpgradeTree(S.Content.Upgrades()));
        var sim = new S.RampageSim(stats, S.CityGrowth.TuningFor(tuning, c.stage),
            S.CityGrowth.Layout(tuning, c.stage, S.Seeds.Make("city", 0)), S.Seeds.Make("army", 0));
        S.GDict cfg = S.Content.Tuning()["arena_edge"];
        double half = sim.arenaHalf + S.Num.F(cfg["out"]);
        Check(Math.Abs(sim.arenaHalf - c.arenaHalf) < TOL && Math.Abs(half - c.half) < TOL,
            $"{name}: the arena's half {sim.arenaHalf}, Godot {c.arenaHalf}");
        S.GDict plan = S.CityGen.Map(sim.city);

        List<EdgeRoad> roads = ArenaEdge.Roads(plan, sim.city, half);
        bool sameRoads = roads.Count == c.roads.Count;
        for (int i = 0; sameRoads && i < roads.Count; i++)
        {
            string[] g = c.roads[i];
            EdgeRoad r = roads[i];
            sameRoads = Near(r.from.x, g[1]) && Near(r.from.y, g[2]) && Near(r.to.x, g[3]) && Near(r.to.y, g[4]) && Near(r.reach, g[5]);
        }
        Check(sameRoads, $"{name}: the port found {roads.Count} streets near the line, Godot {c.roads.Count}, the same ones");

        List<S.Vector3> spots = ArenaEdge.Spots(sim, c.trees);
        int same = 0;
        for (int i = 0; i < Math.Min(spots.Count, c.posts.Count); i++)
        {
            string[] g = c.posts[i];
            if (Near(spots[i].x, g[1]) && Near(spots[i].y, g[2]) && Near(spots[i].z, g[3])) same++;
            else if (same == i) Console.WriteLine($"  {name}: bollard {i} at {spots[i]}, Godot {g[1]} {g[2]} {g[3]}");
        }
        Check(spots.Count == c.posts.Count && same == spots.Count,
            $"{name}: {same}/{c.posts.Count} bollards where Godot stood them (port stood {spots.Count})");

        // tests/lib/city_arena_edge.gd check, on the port's bollards.
        double clear = S.Num.F(cfg["tree_clear"]);
        var water = new List<S.Rect2>();
        foreach (S.Rect2 r in S.CityRiver.Channels(plan, sim.city)) water.Add(r);
        foreach (S.Rect2 r in S.CityHarbour.Basin(plan)) water.Add(r);
        var per = new Dictionary<string, int> { { "n", 0 }, { "s", 0 }, { "e", 0 }, { "w", 0 } };
        int off = 0, wet = 0, road = 0, tree = 0;
        foreach (S.Vector3 d in spots)
        {
            var ground = new S.Vector2(d.x, d.z);
            bool onX = S.Gd.IsEqualApprox(Math.Abs(d.x), half), onZ = S.Gd.IsEqualApprox(Math.Abs(d.z), half);
            if (!onX && !onZ) off++;
            else if (onZ && !onX) per[d.z > 0 ? "s" : "n"]++;
            else if (onX && !onZ) per[d.x > 0 ? "e" : "w"]++;
            foreach (S.Rect2 r in water)
                if (r.HasPoint(ground)) { wet++; break; }
            if (ArenaEdge.OnRoad(ground, roads)) road++;
            foreach (S.Vector2 t in c.trees)
                if (t.DistanceTo(ground) < clear) { tree++; break; }
        }
        Check(off == 0 && wet == 0 && road == 0 && tree == 0,
            $"{name}: no bollard off the line ({off}), over water ({wet}), on a street ({road}) or in a trunk ({tree})");
        string riverSide = plan.Has("river") ? "s" : "";
        double spacing = S.Num.F(cfg["spacing"]);
        for (int k = 0; k < SIDES.Length; k++)
        {
            string side = SIDES[k];
            double dry = Dry(plan, half, side);
            Check(Near(dry, c.dry[k + 1]), $"{name}: side {side} has {dry} dry metres, Godot {c.dry[k + 1]}");
            Check(per[side] == int.Parse(c.sides[k + 1]), $"{name}: side {side} carries {per[side]} bollards, Godot {c.sides[k + 1]}");
            int want = (int)(dry / spacing * SIDE_SHARE);
            if (side != riverSide)
                Check(per[side] >= want, $"{name}: side {side} carries {per[side]} bollards, at least {want} wanted");
        }
    }

    // tests/lib/city_arena_edge.gd _dry: metres of a side's line on the city's own land, not in the beachfront.
    static double Dry(S.GDict plan, double half, string side)
    {
        S.GArray<S.Rect2> front = S.CityHarbour.Basin(plan);
        double dry = 0.0;
        for (double t = -half; t < half; t += DRY_STEP)
        {
            var at = new S.Vector2(t + DRY_MID, side == "s" ? half : -half);
            if (side == "e" || side == "w") at = new S.Vector2(side == "e" ? half : -half, t + DRY_MID);
            bool inFront = false;
            foreach (S.Rect2 r in front)
                if (r.HasPoint(at)) { inFront = true; break; }
            if (!inFront) dry += DRY_STEP;
        }
        return dry;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL ArenaEdgeCheck: " + what);
    }

    static bool Near(double a, string g) => Math.Abs(a - D(g)) <= TOL;
    static bool Near(double a, double b) => Math.Abs(a - b) <= TOL;
    static double D(string s) => double.Parse(s, CultureInfo.InvariantCulture);
}
