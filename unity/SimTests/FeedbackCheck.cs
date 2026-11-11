// The pause menu's bug / feedback report (GameLogic/FeedbackReport.cs) against the bars of tests/lib/ui_report.gd and
// tests/lib/ui_feedback.gd: the reader of a report folder passes a good report and fails planted bad ones by name;
// the report's text (version line first, the facts in order, what was typed or "(nothing)"); two reports in one
// second land in two folders; no picture saves a real black PNG and says so; the facts of a played sim in Godot's
// formatting. Seeded by design: stamps are fixed strings, the sim's seeds are pinned, and no check reads the clock.
using System;
using System.Collections.Generic;
using System.IO;
using Kaiju.Game;
using Kaiju.Sim;
using SimFiles = Kaiju.Sim.FileAccess;

static class FeedbackCheck
{
    const string Typed = "the tank at the bridge ate my kaiju, wasd e shift space, pause";
    const string Species = "reptilian";
    const int PlaySteps = 120;
    const double Dt = 1.0 / 30.0;

    static int checks;
    static int failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("feedback FAILED: " + what);
    }

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        SimFiles.Root = repoRoot;
        Tr.Language = "en";
        string oldRoot = UserDir.Root, oldGraphics = PlayerSettings.Graphics;
        string dir = Path.Combine(Path.GetTempPath(), "kaiju_feedback_check_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        UserDir.Root = dir;
        try
        {
            Version();
            VersionSources(dir);
            Text();
            Folders();
            Reader(dir);
            SimFacts();
        }
        finally
        {
            UserDir.Root = oldRoot;
            PlayerSettings.Graphics = oldGraphics;
            try { Directory.Delete(dir, true); } catch (IOException) { }
        }
        Console.WriteLine($"feedback: {checks} checks, {failed} failed");
        return failed;
    }

    static List<KeyValuePair<string, string>> SampleFacts() =>
        FeedbackReport.FactsOf(Species, 1, 7301, 120.0, 55.4, "Windows 10.0", "Test GPU", "medium", 0.75, 1920, 1080, 1920, 1080);

    // The version comes from project.godot's [application] config/version, after the game's name from data.
    static void Version()
    {
        string project = File.ReadAllText(Path.Combine(SimFiles.Root, "project.godot"));
        string version = FeedbackReport.ProjectVersion(project);
        Check(version != "unversioned" && version.Length > 0, "project.godot has a config/version: " + version);
        Check(FeedbackReport.Version() == Gd.Str(Content.Section("feedback")["game"]) + " " + version,
            "the version line is the game's name and the project's version: " + FeedbackReport.Version());
        Check(FeedbackReport.ProjectVersion("[application]\nconfig/name=\"X\"\nconfig/version=\"1.2-demo\"\n") == "1.2-demo",
            "config/version is read from [application]");
        Check(FeedbackReport.ProjectVersion("[other]\nconfig/version=\"9\"\n") == "unversioned",
            "a config/version outside [application] is not the version");
        Check(FeedbackReport.ProjectVersion("") == "unversioned", "no project file reads as unversioned");
    }

    // Where the version comes from (U6 step 5: the build's version.txt, so the player no longer needs project.godot):
    // version.txt present -> its value; absent -> project.godot's; neither -> "unversioned". Each case is a res root
    // of its own under the scratch folder.
    static void VersionSources(string dir)
    {
        const string project = "[application]\nconfig/version=\"0.1-demo\"\n";
        string oldRoot = SimFiles.Root;
        try
        {
            SimFiles.Root = ResRoot(dir, "both", " 2.0-test \n", project);
            Check(FeedbackReport.BuildVersion() == "2.0-test",
                "version.txt present: its first line, trimmed, wins over project.godot: " + FeedbackReport.BuildVersion());
            SimFiles.Root = ResRoot(dir, "project_only", null, project);
            Check(FeedbackReport.BuildVersion() == "0.1-demo",
                "version.txt absent: project.godot's config/version: " + FeedbackReport.BuildVersion());
            SimFiles.Root = ResRoot(dir, "neither", null, null);
            Check(FeedbackReport.BuildVersion() == "unversioned",
                "neither file: unversioned: " + FeedbackReport.BuildVersion());
        }
        finally
        {
            SimFiles.Root = oldRoot;
        }
        Check(FeedbackReport.VersionOf("", project) == "0.1-demo", "an empty version.txt falls back to project.godot");
    }

    // A res root holding version.txt and project.godot with the given text (null: no such file).
    static string ResRoot(string dir, string key, string versionText, string projectText)
    {
        string root = Path.Combine(dir, "res_" + key);
        Directory.CreateDirectory(root);
        if (versionText != null) File.WriteAllText(Path.Combine(root, FeedbackReport.VERSION_NAME), versionText);
        if (projectText != null) File.WriteAllText(Path.Combine(root, "project.godot"), projectText);
        return root;
    }

    static void Text()
    {
        var details = new List<KeyValuePair<string, string>> { new KeyValuePair<string, string>("City", "stage 1 of 3, map seed 0") };
        string text = FeedbackReport.Compose("it crashed", details, "2026-10-23T10:00:00");
        string[] lines = text.Split('\n');
        Check(lines[0] == "Version: " + FeedbackReport.Version(), "the version is line one: " + lines[0]);
        Check(lines[1] == "Reported: 2026-10-23T10:00:00", "the stamp is line two: " + lines[1]);
        Check(lines[2] == "City: stage 1 of 3, map seed 0", "the facts follow: " + lines[2]);
        Check(lines[3] == "Screenshot: screenshot.png" && lines[4] == "" && lines[5] == "--- What the player wrote ---"
            && lines[6] == "it crashed" && text.EndsWith("it crashed\n"), "the picture's name, a gap, then what was typed:\n" + text);
        Check(FeedbackReport.Compose("  ", details, "t").Contains("\n(nothing)\n"), "an empty box says so");
        Check(FeedbackReport.Compose("  hi \n", details, "t").Contains("\nhi\n"), "typed text is trimmed");
        Check(FeedbackReport.Stamp(new DateTime(2026, 10, 23, 14, 5, 33)) == "2026-10-23T14:05:33",
            "the stamp is the date and time: " + FeedbackReport.Stamp(new DateTime(2026, 10, 23, 14, 5, 33)));
        Check(FeedbackReport.FolderName("2026-10-23T14:05:33") == "2026-10-23_14-05-33", "the folder name has no colons");

        List<KeyValuePair<string, string>> facts = SampleFacts();
        Check(string.Join(",", facts.ConvertAll(kv => kv.Key)) == string.Join(",", FeedbackReport.FACT_LABELS),
            "the facts in Godot's order: " + string.Join(",", facts.ConvertAll(kv => kv.Key)));
        Check(Fact(facts, "City") == "stage 1, map seed 7301", "city: " + Fact(facts, "City"));
        Check(Fact(facts, "Growth step") == "baby (size tier 1)", "growth step: " + Fact(facts, "Growth step"));
        Check(Fact(facts, "Run time") == "1:04 (55 s left)", "run time: " + Fact(facts, "Run time"));
        Check(Fact(facts, "Graphics preset") == "medium (render scale 0.75)", "graphics: " + Fact(facts, "Graphics preset"));
        Check(Fact(facts, "Resolution") == "window 1920x1080, canvas 1920x1080", "resolution: " + Fact(facts, "Resolution"));
        Check(FeedbackReport.RunTime(10.0, 30.0) == "0:00 (30 s left)", "a clock past the run's length plays 0:00");
        Check(FeedbackReport.FactsOf(Species, 3, 1, 1, 0, "", "", "high", 1.0, 1, 1, 1, 1)[6].Value == "high (render scale 1.0)",
            "a whole render scale prints as Godot's 1.0");
    }

    // Two reports in one second save into two folders; no picture saves a real PNG and the text says so.
    static void Folders()
    {
        List<KeyValuePair<string, string>> facts = SampleFacts();
        FeedbackResult first = FeedbackReport.Write("a", facts, null, "2026-10-23T10:00:01");
        FeedbackResult second = FeedbackReport.Write("b", facts, null, "2026-10-23T10:00:01");
        Check(first.ok && second.ok, $"two reports in one second both save ({first.error}{second.error})");
        Check(first.path != second.path, "...into two different folders");
        Check(Path.GetFileName(first.path) == "2026-10-23_10-00-01" && Path.GetFileName(second.path) == "2026-10-23_10-00-01_2",
            $"named by the stamp, the second _2: {Path.GetFileName(first.path)}, {Path.GetFileName(second.path)}");
        string reports = Path.GetFullPath(UserDir.Path(Gd.Str(Content.Section("feedback")["folder"])));
        Check(Path.GetDirectoryName(first.path) == reports, $"under the user folder's reports folder: {first.path}");
        Check(Path.IsPathRooted(first.path), "the path is absolute");
        string note = File.ReadAllText(Path.Combine(first.path, FeedbackReport.TEXT_FILE));
        Check(note.Contains("black placeholder"), "no picture: the text says the picture is a placeholder");
        Check(FeedbackReport.Problems(first.path, "a").Count == 0,
            "the written report has no problems: " + string.Join("; ", FeedbackReport.Problems(first.path, "a")));
        byte[] png = File.ReadAllBytes(Path.Combine(first.path, FeedbackReport.SHOT_FILE));
        Check(FeedbackReport.IsPng(png) && BigEndian(png, 16) == FeedbackReport.PLACEHOLDER_W && BigEndian(png, 20) == FeedbackReport.PLACEHOLDER_H,
            $"the placeholder is a {FeedbackReport.PLACEHOLDER_W}x{FeedbackReport.PLACEHOLDER_H} PNG");
        Check(PngChunksValid(png), "the placeholder PNG's chunks and checksums are whole");
        byte[] mine = FeedbackReport.BlackPng(4, 4);
        FeedbackResult given = FeedbackReport.Write(Typed, facts, mine, "2026-10-23T10:00:02");
        Check(given.ok && !File.ReadAllText(Path.Combine(given.path, FeedbackReport.TEXT_FILE)).Contains("placeholder"),
            "a real picture is saved as given, no placeholder note");
        Check(FeedbackReport.Problems(given.path, Typed).Count == 0, "the typed report has no problems");
    }

    // tests/lib/ui_report.gd _reader_flags_bad_reports: the reader passes a good report and fails planted bad ones.
    static void Reader(string dir)
    {
        string version = FeedbackReport.BuildVersion();
        string head = "Version: " + FeedbackReport.Version() + "\n";
        string facts = string.Join("\n", Array.ConvertAll(FeedbackReport.FACT_LABELS, l => l + ": x"));
        string good = head + facts + "\n" + "hello" + "\n";
        string root = Path.Combine(dir, "planted");
        Check(FeedbackReport.Problems(Plant(root, "good", good, "ok"), "hello").Count == 0,
            "the known-good planted report has no problems");
        var cases = new List<(string key, string path, string expect)>
        {
            ("no_report", Plant(root, "no_report", "", "ok", false), "report.txt is missing"),
            ("no_version", Plant(root, "no_version", good.Replace(head, ""), "ok"), "Version line"),
            ("wrong_version", Plant(root, "wrong_version", good.Replace(version, "9.9"), "ok"), "Version"),
            ("no_picture", Plant(root, "no_picture", good, ""), "screenshot.png is missing"),
            ("junk_picture", Plant(root, "junk_picture", good, "junk"), "not a picture"),
            ("no_typed_text", Plant(root, "no_typed_text", good.Replace("hello", ""), "ok"), "typed text"),
            ("no_facts", Plant(root, "no_facts", head + "hello", "ok"), "no GPU: line"),
        };
        foreach (var c in cases)
        {
            string text = string.Join("\n", FeedbackReport.Problems(c.path, "hello"));
            Check(text.Contains(c.expect), $"planted '{c.key}' is flagged ({c.expect}): {text}");
        }
    }

    // ui_feedback.gd played_sim: the young croc a few seconds into its city; the facts read it in Godot's form.
    static void SimFacts()
    {
        PlayerSettings.Graphics = "medium";
        GDict species = Content.SpeciesDef(Species);
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, new UpgradeTree(Content.Upgrades(), new GDict(), Species));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), 1, Seeds.Make("city", 0));
        RampageSim sim = new RampageSim(stats, CityGrowth.ForStats(stats), layout, Seeds.Make("army", 0));
        GDict ability = species["ability"];
        sim.abilityType = Gd.Str(ability["type"]);
        sim.body.UseSpecies(Species);
        for (int i = 0; i < PlaySteps; i++) sim.Step(Dt, Vector2.ZERO, false);
        List<KeyValuePair<string, string>> facts = FeedbackReport.Facts(sim, Species, "OS x", "GPU y", 1920, 1080, 1920, 1080);
        long tier = sim.SizeTier();
        Check(Fact(facts, "Species") == Species, "species: " + Fact(facts, "Species"));
        Check(Fact(facts, "City") == $"stage {tier}, map seed {Num.I(sim.city["map_seed"])}", "city of the sim: " + Fact(facts, "City"));
        Check(Fact(facts, "Growth step") == $"{TreeText.StageFor(tier)} (size tier {tier})", "growth step of the sim: " + Fact(facts, "Growth step"));
        Check(Fact(facts, "Run time") == FeedbackReport.RunTime(sim.Stat("run_seconds"), sim.timeLeft), "run time of the sim: " + Fact(facts, "Run time"));
        Check(Fact(facts, "Graphics preset") == "medium (render scale 0.75)", "graphics of the settings: " + Fact(facts, "Graphics preset"));
        Check(Fact(facts, "OS") == "OS x" && Fact(facts, "GPU") == "GPU y", "the machine's facts as the view gave them");
    }

    static string Fact(List<KeyValuePair<string, string>> facts, string key)
    {
        foreach (KeyValuePair<string, string> kv in facts) if (kv.Key == key) return kv.Value;
        return null;
    }

    // A planted report folder: report.txt with `text` (unless !withText) and screenshot.png a real picture ("ok"),
    // junk bytes ("junk") or absent (""). Returns its path.
    static string Plant(string root, string key, string text, string shot, bool withText = true)
    {
        string dir = Path.Combine(root, key);
        Directory.CreateDirectory(dir);
        if (withText) File.WriteAllText(Path.Combine(dir, FeedbackReport.TEXT_FILE), text);
        if (shot == "ok") File.WriteAllBytes(Path.Combine(dir, FeedbackReport.SHOT_FILE), FeedbackReport.BlackPng(4, 4));
        else if (shot == "junk") File.WriteAllText(Path.Combine(dir, FeedbackReport.SHOT_FILE), "not a png");
        return dir;
    }

    static long BigEndian(byte[] b, int at) => ((long)b[at] << 24) | ((long)b[at + 1] << 16) | ((long)b[at + 2] << 8) | b[at + 3];

    // Every chunk's CRC matches and the stream ends on IEND; the zlib stream inflates to the picture's bytes.
    static bool PngChunksValid(byte[] png)
    {
        int at = 8;
        bool ended = false;
        byte[] idat = null;
        while (at + 12 <= png.Length)
        {
            int len = (int)BigEndian(png, at);
            string type = System.Text.Encoding.ASCII.GetString(png, at + 4, 4);
            uint crc = 0xffffffffu;
            for (int i = at + 4; i < at + 8 + len; i++)
            {
                crc ^= png[i];
                for (int k = 0; k < 8; k++) crc = (crc & 1) != 0 ? 0xEDB88320u ^ (crc >> 1) : crc >> 1;
            }
            if ((crc ^ 0xffffffffu) != (uint)BigEndian(png, at + 8 + len)) return false;
            if (type == "IDAT") { idat = new byte[len]; Array.Copy(png, at + 8, idat, 0, len); }
            if (type == "IEND") { ended = true; break; }
            at += 12 + len;
        }
        if (!ended || idat == null) return false;
        using (var z = new System.IO.Compression.ZLibStream(new MemoryStream(idat), System.IO.Compression.CompressionMode.Decompress))
        using (var outp = new MemoryStream())
        {
            z.CopyTo(outp);
            return outp.Length == (1 + FeedbackReport.PLACEHOLDER_W * 3) * FeedbackReport.PLACEHOLDER_H;
        }
    }
}
