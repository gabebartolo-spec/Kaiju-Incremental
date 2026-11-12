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

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL stage bodies: " + what);
    }
}
