// tools/unity/export_slice.gd without Godot: one real city block (grids, looks, palettes, window
// grids), the dusk look, the camera's tuning, the approved croc (skin, clips, rest pose and binds),
// and the digests tools/unity/check_core.py replays. Same steps, same order, same bytes.
//   dotnet run --project tools/unity/slicebake -c Release -- --out=<dir> [--croc=<dir>/reptilian_adult]
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Kaiju.Sim;

static class Program
{
    const long STAGE = 3;
    // Dusk is the game's one time of day (D-359); the block's lit windows are drawn from its look.
    const string TIME = "dusk";
    const double RADIUS = 62.0;
    const int MAX_BUILDINGS = 36;

    static int Main(string[] args)
    {
        string outDir = "", croc = "";
        foreach (string arg in args)
        {
            if (arg.StartsWith("--out=", StringComparison.Ordinal)) outDir = arg.Substring(6);
            if (arg.StartsWith("--croc=", StringComparison.Ordinal)) croc = arg.Substring(7);
        }
        string repo = RepoRoot();
        if (outDir == "") outDir = Path.Combine(repo, "unity", "Assets", "StreamingAssets", "slice");
        Kaiju.Sim.FileAccess.Root = repo;
        ClassDB.UseNative = true;
        if (!ClassDB.ClassExists("KaijuSettle"))
        {
            Console.Error.WriteLine("slicebake: kaiju_core.dll is missing (build unity/native first)");
            return 1;
        }
        Directory.CreateDirectory(outDir);

        GDict species = Content.SpeciesDef("reptilian");
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, new UpgradeTree(Content.Upgrades(), StageLevels(STAGE)));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), STAGE, Seeds.Make("city", 0));
        Content.SetTime(TIME);
        var sim = new RampageSim(stats, CityGrowth.ForStats(stats), layout, Seeds.Make("army", 2));
        List<int> picked = PickBlock(sim);
        GArray<GDict> party = PartyWalls.Of(sim.buildings);
        var meta = new GArray<Variant>();
        var built = new List<SliceBuilding>();
        using (var bin = new BinaryWriter(File.Create(Path.Combine(outDir, "buildings.bin"))))
        {
            bin.Write(Encoding.ASCII.GetBytes("KSB1"));
            bin.Write((uint)picked.Count);
            foreach (int n in picked)
            {
                var one = new SliceBuilding(sim.buildings[n], party[n]);
                built.Add(one);
                one.Store(bin);
                meta.Append(one.Meta());
            }
        }
        WriteJson(outDir, "slice.json", SliceJson(sim, meta));
        WriteJson(outDir, "digests.json", SliceDigests.Of(built));
        if (croc != "")
        {
            string why = CrocBake.Export(croc, outDir, repo);
            if (why != "")
            {
                Console.Error.WriteLine("slicebake: " + why);
                return 1;
            }
        }
        Console.WriteLine($"exported {picked.Count} buildings to {outDir}");
        return 0;
    }

    // tools/capture/capture_kit.gd STAGE_LEVELS: the upgrade levels a capture gives each stage.
    static GDict StageLevels(long stage)
    {
        GDict[] table =
        {
            new GDict { { "claws", 2L }, { "hide", 2L } },
            new GDict { { "claws", 5L }, { "hide", 5L }, { "rage", 3L }, { "evolve1", 1L } },
            new GDict
            {
                { "claws", 5L }, { "hide", 5L }, { "rage", 5L }, { "evolve1", 1L }, { "tail", 3L },
                { "sig_power", 3L }, { "evolve2", 1L },
            },
        };
        return table[stage - 1];
    }

    static bool Plain(RampageSim.Building b) =>
        b.landmark == "" && b.model == "" && b.hazard == "" && !b.IsSpan() && Gd.IsZeroApprox((double)b.@base);

    // Godot's Vector2(dx, dz).length(): 32-bit parts, a 32-bit root.
    static float Dist(RampageSim.Building b, RampageSim.Building c) =>
        (float)new Vector2(b.x - c.x, b.z - c.z).Length();

    // The densest real block on the map: the plain ground buildings around the spot holding the most
    // building volume within RADIUS.
    static List<int> PickBlock(RampageSim sim)
    {
        var plain = new List<int>();
        for (int n = 0; n < sim.buildings.Size(); n++)
        {
            if (Plain(sim.buildings[n])) plain.Add(n);
        }
        int best = -1;
        double bestLoad = -1.0;
        foreach (int c in plain)
        {
            RampageSim.Building at = sim.buildings[c];
            double load = 0.0;
            foreach (int n in plain)
            {
                RampageSim.Building b = sim.buildings[n];
                if (Dist(b, at) < RADIUS) load += (double)(b.w * b.d * b.height);
            }
            if (load > bestLoad)
            {
                bestLoad = load;
                best = c;
            }
        }
        RampageSim.Building centre = sim.buildings[best];
        var near = plain.FindAll(n => Dist(sim.buildings[n], centre) < RADIUS);
        // A strict order (distance, then index), so any sort gives Godot's sort_custom answer.
        near.Sort((a, b) =>
        {
            double da = Dist(sim.buildings[a], centre), db = Dist(sim.buildings[b], centre);
            if (da != db) return da < db ? -1 : 1;
            return a.CompareTo(b);
        });
        return near.GetRange(0, Math.Min(MAX_BUILDINGS, near.Count));
    }

    static GDict SliceJson(RampageSim sim, GArray<Variant> meta)
    {
        var windows = new GArray<Variant>();
        List<float[]> cols = WindowPalette.Colours();
        List<float> ends = WindowPalette.WeightEnds();
        for (int i = 0; i < cols.Count; i++)
        {
            windows.Append(new GDict
            {
                { "color", Gd.Arr((double)cols[i][0], (double)cols[i][1], (double)cols[i][2]) },
                { "end", (double)ends[i] },
            });
        }
        float[] gain = WindowPalette.Gain();
        return new GDict
        {
            { "look", Content.Look() },
            { "camera", Content.Section("camera") },
            { "destruction", Content.Section("destruction") },
            { "time", TIME },
            { "body_scale", sim.BodyScale() },
            { "model_height", GdConst.ModelHeight() },
            { "window_palette", windows },
            { "window_gain", Gd.Arr((double)gain[0], (double)gain[1]) },
            { "window_palette_on", WindowPalette.On() },
            { "buildings", meta },
        };
    }

    static void WriteJson(string dir, string file, GDict data) =>
        File.WriteAllBytes(Path.Combine(dir, file), new UTF8Encoding(false).GetBytes(GodotJson.Stringify(data)));

    static string RepoRoot()
    {
        string dir = AppContext.BaseDirectory;
        while (dir != null && !File.Exists(Path.Combine(dir, "project.godot"))) dir = Path.GetDirectoryName(dir);
        if (dir == null) throw new InvalidOperationException("slicebake: no project.godot above " + AppContext.BaseDirectory);
        return dir;
    }
}
