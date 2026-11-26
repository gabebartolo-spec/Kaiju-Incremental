// CityDraw reads a plain building's lit windows, lit shopfronts and hidden slab cells from WindowLights, a
// byte-box copy of BuildingLayout's parts. This holds it to BuildingLayout itself, cell for cell, for every plain
// building of several cities (stages, the runs' city seeds), at the view's lit share and at none and all.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Kaiju.Sim;

static class WindowLightsCheck
{
    const long RES = 8;
    static readonly int[] Stages = { 1, 2, 3 };
    static readonly int[] CitySeeds = { 0, 1 };
    static readonly double[] EdgeShares = { 0.0, 1.0 };

    static int failed, buildings;

    public static int Run(string repoRoot)
    {
        failed = 0;
        buildings = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        Content.Look();
        double share = (float)Num.F(Content.Look().Get("window_lit", 0.0));
        Check(share > 0.0 && share < 1.0, $"the view lights a share of its windows: {share}");
        bool first = true;
        foreach (int stage in Stages)
            foreach (int seed in CitySeeds)
            {
                var sim = new RampageSim(UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"),
                        new UpgradeTree(Content.Upgrades())), CityGrowth.TuningFor(Content.Tuning(), stage),
                    CityGrowth.Layout(Content.Tuning(), stage, Seeds.Make("city", seed)), Seeds.Make("army", seed));
                City(sim, $"stage {stage}, city seed {seed}", first ? EdgeShares.Append(share).ToArray() : new[] { share });
                first = false;
            }
        Console.WriteLine($"window lights: {buildings} buildings matched BuildingLayout, {failed} failed");
        return failed;
    }

    static void City(RampageSim sim, string name, double[] shares)
    {
        GArray<GDict> party = PartyWalls.Of(sim.buildings);
        var plain = new List<int>();
        for (int n = 0; n < sim.buildings.Size(); n++)
        {
            RampageSim.Building b = sim.buildings[n];
            if (b.landmark == "" && b.model == "" && b.hazard == "" && !b.IsSpan()) plain.Add(n);
        }
        Check(plain.Count > 100, $"{name}: {plain.Count} plain buildings");
        var wrong = new System.Collections.Concurrent.ConcurrentBag<string>();
        foreach (double share in shares)
            Parallel.ForEach(plain, n =>
            {
                string why = One(sim.buildings[n], party[n], share);
                if (why != null) wrong.Add($"{name}, building {n}, lit share {share}: {why}");
                Interlocked.Increment(ref buildings);
            });
        foreach (string why in wrong.Take(5)) Check(false, why);
        Check(wrong.IsEmpty, $"{name}: {wrong.Count} buildings differ");
    }

    static string One(RampageSim.Building b, GDict party, double share)
    {
        var laid = new BuildingLayout(b, RES, party, share);
        var lit = new HashSet<Vector3i>();
        var shop = new HashSet<Vector3i>();
        var hidden = new HashSet<Vector3i>();
        foreach (Variant key in laid.cells.Keys())
        {
            string what = Gd.Str(laid.cells[key]);
            Vector3i c = key;
            if (what == "lit") lit.Add(c);
            else if (what == "shop_lit") shop.Add(c);
            else if (what == "slab" && (c.x < 0 || c.z < 0 || c.x >= b.w * RES || c.z >= b.d * RES)) hidden.Add(c);
        }
        WindowLights.Result fast;
        try { fast = WindowLights.Read(b, RES, party, share); }
        catch (InvalidOperationException e) { return e.Message; }
        return Same("lit", lit, fast.lit) ?? Same("shop_lit", shop, fast.shopLit) ?? Same("hidden slab", hidden, fast.hiddenSlab);
    }

    static string Same(string what, HashSet<Vector3i> want, List<Vector3i> got)
    {
        if (got.Count == want.Count && want.SetEquals(got)) return null;
        Vector3i odd = got.FirstOrDefault(c => !want.Contains(c));
        return $"{what}: {got.Count} cells, BuildingLayout {want.Count} (e.g. {odd.x},{odd.y},{odd.z})";
    }

    static void Check(bool ok, string what)
    {
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL window lights: " + what);
    }
}
