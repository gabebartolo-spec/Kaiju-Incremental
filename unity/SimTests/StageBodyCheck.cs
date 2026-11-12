// The croc's growth-stage bodies (Rampage/CrocStages.cs, scenes/kaiju_model.gd): each size tier draws its own
// stage's body, a missing stage falls back to the next one up, and a stage's takes decide what it plays. On the
// repo's own reptilian_<stage>.kclip files: the baby lashes but cannot sweep, the Behemoth (adolescent) does
// neither, the Colossus (adult) does both, and only the Colossus has the keyed run and rise from the bay.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;

static class StageBodyCheck
{
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Tiers();
        Fallback();
        Takes(repoRoot);
        Spheres(repoRoot);
        Console.WriteLine(failed == 0 ? $"stage bodies: ok ({checks} checks)" : $"stage bodies: {failed} of {checks} failed");
        return failed;
    }

    // KaijuModel.stage_for: tier 1 and below the baby, 2 the adolescent, 3 and up the adult.
    static void Tiers()
    {
        string[] want = { "baby", "baby", "adolescent", "adult", "adult" };
        for (long tier = 0; tier < want.Length; tier++)
            Check(CrocStages.StageFor(tier) == want[tier], $"tier {tier} is the {CrocStages.StageFor(tier)}, Godot's stage_for says {want[tier]}");
    }

    static void Fallback()
    {
        Func<string, bool> all = _ => true;
        Check(CrocStages.BodyStage(1, all) == "baby", "with every body, tier 1 draws the baby");
        Check(CrocStages.BodyStage(2, all) == "adolescent", "with every body, tier 2 draws the adolescent");
        Check(CrocStages.BodyStage(3, all) == "adult", "with every body, tier 3 draws the adult");
        Func<string, bool> adultOnly = s => s == "adult";
        Check(CrocStages.BodyStage(1, adultOnly) == "adult", "with only the adult, tier 1 falls up to the adult");
        Func<string, bool> upper = s => s != "baby";
        Check(CrocStages.BodyStage(1, upper) == "adolescent", "without the baby, tier 1 falls up to the adolescent, not past it");
        Check(CrocStages.BodyStage(3, upper) == "adult", "a fallback never reaches down: tier 3 stays the adult");
    }

    // The on and off of each take, read from the stage's own clip header as Croc.cs reads it.
    static void Takes(string repoRoot)
    {
        var expect = new Dictionary<string, (bool lash, bool sweep, bool run, bool rise)>
        {
            ["baby"] = (true, false, false, false),
            ["adolescent"] = (false, false, false, false),
            ["adult"] = (true, true, true, true),
        };
        foreach (string stage in CrocStages.STAGES)
        {
            string path = Path.Combine(repoRoot, "assets", "kaiju", $"reptilian_{stage}.kclip");
            if (!File.Exists(path))
            {
                Check(false, $"{path} is missing");
                continue;
            }
            byte[] raw = File.ReadAllBytes(path);
            int length = BitConverter.ToInt32(raw, 8);
            using JsonDocument header = JsonDocument.Parse(Encoding.UTF8.GetString(raw, 12, length));
            var names = new HashSet<string>();
            var layers = new HashSet<string>();
            foreach (JsonElement c in header.RootElement.GetProperty("clips").EnumerateArray())
            {
                string name = c.GetProperty("name").GetString()!;
                names.Add(name);
                if (c.TryGetProperty("layer", out JsonElement l) && l.ValueKind == JsonValueKind.True) layers.Add(name);
            }
            Check(names.Contains("walk") && names.Contains("idle"), $"the {stage} has the walk and idle every body plays");
            var want = expect[stage];
            Check(CrocStages.Lashes(layers) == want.lash, $"the {stage} lashes: {CrocStages.Lashes(layers)}, want {want.lash}");
            Check(CrocStages.Sweeps(layers) == want.sweep, $"the {stage} sweeps: {CrocStages.Sweeps(layers)}, want {want.sweep}");
            Check(names.Contains("run") == want.run, $"the {stage} has a keyed run: {names.Contains("run")}, want {want.run}");
            Check(names.Contains("rise_bay") == want.rise, $"the {stage} has the keyed rise: {names.Contains("rise_bay")}, want {want.rise}");
        }
    }

    // Croc.cs's pushers: each stage keeps the tuning spheres whose bones its rig carries and skips the rest. Every
    // stage keeps the trunk, head and each leg down to leg_x2 and the tail to tail8; only the baby and adult keep the rest.
    static void Spheres(string repoRoot)
    {
        using JsonDocument tuning = JsonDocument.Parse(File.ReadAllText(Path.Combine(repoRoot, "unity", "Assets", "StreamingAssets", "tuning.json")));
        var wanted = new List<string>();
        foreach (string list in new[] { "body", "tail" })
            foreach (JsonElement s in tuning.RootElement.GetProperty(list).EnumerateArray()) wanted.Add(s.GetProperty("bone").GetString()!);
        string[] every = { "spine0", "spine1", "spine2", "head0", "leg_l0", "leg_r0", "leg_l1", "leg_r1", "leg_l2", "leg_r2", "tail0", "tail2", "tail4", "tail6", "tail8" };
        foreach (string stage in CrocStages.STAGES)
        {
            string path = Path.Combine(repoRoot, "assets", "kaiju", $"reptilian_{stage}.rig.json");
            if (!File.Exists(path)) { Check(false, $"{path} is missing"); continue; }
            using JsonDocument rig = JsonDocument.Parse(File.ReadAllText(path));
            var bones = new HashSet<string>();
            foreach (JsonElement b in rig.RootElement.GetProperty("bones").EnumerateArray()) bones.Add(b.GetProperty("name").GetString()!);
            var kept = new HashSet<string>(wanted.FindAll(bones.Contains));
            foreach (string bone in every) Check(kept.Contains(bone), $"the {stage} keeps its {bone} sphere");
            Check(stage == "adolescent" ? kept.Count == every.Length : kept.Count == wanted.Count,
                $"the {stage} keeps {kept.Count} of {wanted.Count} spheres");
        }
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL stage bodies: " + what);
    }
}
