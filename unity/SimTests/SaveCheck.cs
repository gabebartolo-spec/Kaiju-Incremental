// The save (GameLogic/SaveFile.cs, Json.cs, UserDir.cs) against the bars of tests/run_slots_tests.gd and
// tests/lib/flow_save.gd: the new save's shape, a save and load that changes nothing, each older version migrated,
// unreadable files kept and never shown empty, delete, the latest slot, what a rampage banks, and whole numbers
// written as integers however large. Seeded by design: file times are set by hand, the city seed is pinned.
using System;
using System.IO;
using Kaiju.Game;
using Kaiju.Sim;

static class SaveCheck
{
    const string Folder = "kaiju_save_check";
    // A v6 save file typed by hand, mid-campaign (tests/lib/slots_base.gd CAMPAIGN_FILE).
    const string CampaignFile = @"{
	""version"": 6,
	""species"": ""reptilian"",
	""seed"": 77,
	""rubble"": 5000,
	""levels"": {""claws"": 3},
	""runs"": 12,
	""best"": {""rubble"": 1500.0},
	""city_seconds"": 90.0,
	""demo"": true,
	""demo_done"": false,
	""totals"": {},
	""specimen"": 2,
	""lab_card"": false,
	""conquered"": [""ostia_minor"", ""carthago""],
	""bonuses"": {""ostia_minor"": ""bonus_ostia_minor_1"", ""carthago"": ""bonus_carthago_3""},
	""threat"": 37.5,
	""noise_log"": [
		{""continent"": ""ostia_minor"", ""noise"": 20.0},
		{""continent"": ""carthago"", ""noise"": 17.5}
	]
}";
    const string NotJson = "{ not json";
    // A bank far past what a float32 or an exponent form would keep.
    const long BigBank = 9000000000000L;
    const long Refund = 444500L;

    static int checks;
    static int failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("save FAILED: " + what);
    }

    static bool Same(Variant a, Variant b) => a.Equals(b);

    static GDict V4() => Json.ParseDict(@"{""version"": 4, ""species"": ""reptilian"", ""rubble"": 1234,
        ""levels"": {""claws"": 2, ""hide"": 1, ""evolve1"": 1}, ""runs"": 7,
        ""best"": {""rubble"": 900.0, ""destruction"": 0.42, ""toppled"": 5.0}, ""city_seconds"": 61.5, ""demo"": true,
        ""demo_done"": false, ""totals"": {""rubble"": 4000.0}, ""last_time"": ""night"", ""last_weather"": ""rain""}");

    static GDict V5() => Json.ParseDict(@"{""version"": 5, ""species"": ""reptilian"", ""seed"": 77, ""rubble"": 1234,
        ""levels"": {""claws"": 2, ""hide"": 1, ""evolve1"": 1}, ""runs"": 7, ""best"": {""rubble"": 900.0, ""destruction"": 0.42},
        ""city_seconds"": 61.5, ""demo"": true, ""demo_done"": false, ""totals"": {""rubble"": 4000.0}, ""specimen"": 3,
        ""lab_card"": false}");

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        string oldRoot = UserDir.Root;
        long oldPin = SaveFile.PinnedSeed;
        int oldSlot = SaveFile.Slot;
        Func<string, string> oldTranslate = SaveFile.Translate;
        Action<string> oldWarn = SaveFile.Warn;
        Variant demoWas = Content.Section("demo")["enabled"];
        string dir = Path.Combine(Path.GetTempPath(), Folder);
        if (Directory.Exists(dir)) Directory.Delete(dir, true);
        UserDir.Root = dir;
        SaveFile.Warn = text => { }; // refusals are expected here
        SaveFile.Translate = text => text; // English keys, whatever table is loaded
        try
        {
            Content.Section("demo")["enabled"] = true;
            Files();
            Writer();
            Shape();
            RoundTrip();
            Migrations();
            Unreadable();
            Delete();
            Latest();
            Specimen();
            Banking();
            BigNumbers();
            Seed();
            Title();
        }
        finally
        {
            Content.Section("demo")["enabled"] = demoWas;
            UserDir.Root = oldRoot;
            SaveFile.PinnedSeed = oldPin;
            SaveFile.Slot = oldSlot;
            SaveFile.Translate = oldTranslate;
            SaveFile.Warn = oldWarn;
            if (Directory.Exists(dir)) Directory.Delete(dir, true);
        }
        Console.WriteLine($"save: {checks} checks, {failed} failed");
        return failed;
    }

    // UserDir: a write lands whole, replaces what was there and leaves no temp file behind.
    static void Files()
    {
        Check(!UserDir.Exists("a.txt") && UserDir.ReadText("a.txt") == "" && UserDir.ModifiedTicks("a.txt") == -1,
            "a missing file reads empty and has no time");
        Check(UserDir.WriteText("a.txt", "one") && UserDir.ReadText("a.txt") == "one", "a first write makes the folder and the file");
        Check(UserDir.WriteText("a.txt", "two é样") && UserDir.ReadText("a.txt") == "two é样", "a second write replaces it, text beyond ASCII kept");
        Check(Directory.GetFiles(UserDir.Root).Length == 1, "no temp file is left: " + string.Join(",", Directory.GetFiles(UserDir.Root)));
        byte[] raw = File.ReadAllBytes(UserDir.Path("a.txt"));
        Check(raw.Length > 0 && raw[0] == (byte)'t', "the file has no byte-order mark");
        Check(UserDir.ModifiedTicks("a.txt") > 0, "a written file has a time");
        UserDir.Delete("a.txt");
        UserDir.Delete("a.txt");
        Check(!UserDir.Exists("a.txt"), "delete removes it; deleting nothing is quiet");
    }

    // Json: Godot's layout, whole numbers as integers, and every value back as it was through the sim's reader.
    static void Writer()
    {
        GDict small = new GDict { { "b", Gd.Arr(1L, 2.0, 0.5) }, { "a", new GDict() }, { "c", Gd.Arr() }, { "d", new GDict { { "x", true } } } };
        string want = "{\n\t\"a\": {},\n\t\"b\": [\n\t\t1,\n\t\t2,\n\t\t0.5\n\t],\n\t\"c\": [],\n\t\"d\": {\n\t\t\"x\": true\n\t}\n}";
        Check(Json.Stringify(small, "\t") == want, "tab-indented, keys sorted, as Godot writes it: " + Json.Stringify(small, "\t"));
        Check(Json.Stringify(small, "") == "{\"a\":{},\"b\":[1,2,0.5],\"c\":[],\"d\":{\"x\":true}}", "no indent is one line: " + Json.Stringify(small, ""));
        Check(Json.Stringify(small, "", false).StartsWith("{\"b\":", StringComparison.Ordinal), "unsorted keeps the order written");
        Check(Json.Number(444500.0) == "444500" && Json.Number(0.0) == "0" && Json.Number(-3.0) == "-3" && Json.Number(-0.0) == "0",
            "a whole float prints as an integer");
        GDict mixed = new GDict
        {
            { "text", "quote \" slash \\ line\nnext\ttab é样 \u0001" },
            { "none", default(Variant) },
            { "yes", true },
            { "no", false },
            { "int", 12L },
            { "float", 0.42 },
            { "nest", new GDict { { "list", Gd.Arr(new GDict { { "k", 17.5 } }, "s", Gd.Arr(1.0)) } } },
        };
        Variant back = JSON.ParseString(Json.Stringify(mixed, "\t"));
        Check(Same(back, mixed), "strings, null, bools, numbers, nested lists read back equal: " + Json.Stringify(back, ""));
        double[] awkward = { 0.1 + 0.2, 1.0 / 3.0, 1.0e-7, 61.53333333333333, 123456789.12345678, 2.5e-10, 1.7976931348623157e308, -0.007 };
        int exact = 0;
        foreach (double v in awkward)
        {
            if (BitConverter.DoubleToInt64Bits((double)JSON.ParseString(Json.Number(v))) == BitConverter.DoubleToInt64Bits(v)) exact++;
            else Console.WriteLine("save note: " + v.ToString("R") + " wrote as " + Json.Number(v));
        }
        Check(exact == awkward.Length, $"fractions read back bit for bit: {exact} of {awkward.Length}");
        Check(Json.Parse(NotJson).IsNil && Json.Parse("").IsNil && Json.ParseDict("[1, 2]").IsEmpty() && Json.ParseDict("12").IsEmpty(),
            "text that is not a JSON object parses to nothing, without throwing");
    }

    // A new save: version 6, the same keys Godot's new_save writes, K-01, the empty campaign.
    static void Shape()
    {
        GDict fresh = SaveFile.NewSave("reptilian", 77);
        string[] keys = { "version", "species", "seed", "rubble", "levels", "runs", "best", "city_seconds", "demo", "demo_done", "totals", "specimen", "lab_card", "conquered", "bonuses", "threat", "noise_log" };
        bool all = fresh.Size() == keys.Length;
        foreach (string key in keys) all = all && fresh.Has(key);
        Check(all, "a new save holds exactly Godot's keys: " + Json.Stringify(fresh, ""));
        Check(SaveFile.Version == 6 && Num.I(fresh["version"]) == 6 && fresh["species"] == "reptilian" && Num.I(fresh["seed"]) == 77
            && Num.I(fresh["rubble"]) == 0 && Num.I(fresh["runs"]) == 0 && Num.I(fresh["specimen"]) == 1
            && fresh["demo"] == false && fresh["demo_done"] == false && fresh["lab_card"] == false && Num.F(fresh["city_seconds"]) == 0.0,
            "a new save is v6, K-01, nothing banked");
        bool empty = true;
        GDict campaign = SaveFile.Campaign();
        foreach (Variant key in campaign) empty = empty && Same(fresh[key], campaign[key]);
        Check(empty && campaign.Size() == 4 && fresh["conquered"].Size() == 0 && fresh["bonuses"].Size() == 0 && Num.F(fresh["threat"]) == 0.0 && fresh["noise_log"].Size() == 0,
            "a new save starts with the empty campaign");
        Check(Num.I(SaveFile.NewSave("reptilian")["seed"]) == 0, "the city seed is 0 unless given");
        Check(SaveFile.SlotCount() == 3 && SaveFile.PathOf(2) == "save_slot_2.json", "three slots, save_slot_N.json");
        string text = Json.Stringify(fresh, "\t");
        Check(text.Contains("\"city_seconds\": 0,") && text.Contains("\"threat\": 0,") && text.Contains("\"seed\": 77,") && !text.Contains(".0"),
            "a new save's numbers are written as integers: " + text);
    }

    // The hand-written campaign save loads as written; saved and loaded again it is unchanged; v7 is refused.
    static void RoundTrip()
    {
        SaveFile.Wipe();
        UserDir.WriteText(SaveFile.PathOf(2), CampaignFile);
        GDict want = Json.ParseDict(CampaignFile);
        GDict loaded = SaveFile.LoadGame(2);
        Check(Same(loaded, want), "the hand-written campaign save loads as written: " + Json.Stringify(loaded, ""));
        Check(Same(loaded["conquered"], Gd.Arr("ostia_minor", "carthago")) && loaded["bonuses"]["carthago"] == "bonus_carthago_3"
            && Num.F(loaded["threat"]) == 37.5 && loaded["noise_log"].Size() == 2,
            "its conquests, bonuses, Threat and noise log read back");
        Check(SaveFile.SaveGame(loaded, 2), "the slot is written");
        GDict again = SaveFile.LoadGame(2);
        Check(Same(again, want), "saved and loaded again it is unchanged: " + Json.Stringify(again, ""));
        string first = UserDir.ReadText(SaveFile.PathOf(2));
        SaveFile.SaveGame(again, 2);
        Check(UserDir.ReadText(SaveFile.PathOf(2)) == first, "a second save writes the same bytes");
        Check(first.Contains("\"rubble\": 5000,") && first.Contains("\"threat\": 37.5,") && first.Contains("\"noise\": 20\n"), "whole numbers are integers in the file, fractions kept");

        GDict played = SaveFile.NewSave("reptilian", 5);
        played["levels"] = new GDict { { "claws", 2L }, { "hide", 1L } };
        played["best"] = new GDict { { "rubble", 900.0 }, { "destruction", 0.42 } };
        played["city_seconds"] = 61.53333333333333;
        played["last_time"] = "dusk";
        played["titans_unlocked"] = Gd.Arr("komodo");
        GDict before = played.Duplicate(true);
        SaveFile.SaveGame(played, 1);
        Check(Same(played, before), "saving does not change the save in hand");
        Check(Same(SaveFile.LoadGame(1), before), "a played save comes back equal, keys added by play too");
        played.Erase("version");
        SaveFile.SaveGame(played, 1);
        Check(Num.I(SaveFile.LoadGame(1).Get("version", 0L)) == 6, "the version is stamped on every write");

        SaveFile.Slot = 3;
        SaveFile.SaveGame(before);
        Check(SaveFile.HasSave() && SaveFile.HasSave(3) && Same(SaveFile.LoadGame(), before) && SaveFile.PathOf() == "save_slot_3.json",
            "without a slot number the slot in play is used (SaveSystem)");
        SaveFile.DeleteSave();
        Check(!SaveFile.HasSave(3), "and deleted");
        SaveFile.Slot = 1;

        string v7 = CampaignFile.Replace("\"version\": 6", "\"version\": 7");
        UserDir.WriteText(SaveFile.PathOf(3), v7);
        Check(SaveFile.LoadGame(3).IsEmpty(), "the same save marked v7 is refused, never half-read");
        Check(UserDir.ReadText(SaveFile.PathOf(3)) == v7, "the refused file is kept as it was");
        SaveFile.Wipe();
        Check(!SaveFile.HasSave(1) && !SaveFile.HasSave(2) && !SaveFile.HasSave(3), "wipe empties every slot");
    }

    static bool Kept(GDict up, GDict old)
    {
        foreach (Variant key in old)
        {
            if (key != "version" && !Same(up.Get(key), old[key])) return false;
        }
        return true;
    }

    static bool HasCampaign(GDict up) =>
        up.Has("conquered") && up["conquered"].Size() == 0 && up.Has("bonuses") && up["bonuses"].Size() == 0
        && up.Has("threat") && Num.F(up["threat"]) == 0.0 && up.Has("noise_log") && up["noise_log"].Size() == 0;

    // Every version Godot's migrate handles: 1, 2 (with and without the cut node), 3, 4, 5, and 6 untouched.
    static void Migrations()
    {
        GDict v1 = Json.ParseDict(@"{""version"": 1, ""species"": ""reptilian"", ""rubble"": 42, ""levels"": {""claws"": 2}, ""runs"": 3, ""best_destruction"": 0.4}");
        GDict up1 = SaveFile.Migrate(v1);
        Check(Num.I(up1["version"]) == 6 && Num.F(up1["best"]["destruction"]) == 0.4 && !up1.Has("best_destruction") && Num.I(up1["rubble"]) == 42,
            "a v1 save migrates to v6 keeping its best and its bank: " + Json.Stringify(up1, ""));
        Check(Num.F(up1["city_seconds"]) == 0.0 && up1["demo"] == false && up1["demo_done"] == false && up1["totals"].Size() == 0
            && Num.I(up1["specimen"]) == 1 && HasCampaign(up1) && Num.I(up1["levels"]["claws"]) == 2,
            "and gains every later key at its default");
        Check(v1.Has("best_destruction") && Num.I(v1["version"]) == 1, "migrating leaves the save it was given alone");
        UserDir.WriteText(SaveFile.PathOf(1), Json.Stringify(v1, ""));
        GDict disk1 = SaveFile.LoadGame(1);
        Check(Num.I(disk1.Get("version", 0L)) == 6 && Num.I(disk1["levels"]["claws"]) == 2, "a v1 save file on disk loads as v6");
        SaveFile.Wipe();

        long refund = Num.I(Content.Section("save")["refunds"]["evolve3"]);
        GDict v2 = Json.ParseDict(@"{""version"": 2, ""species"": ""reptilian"", ""rubble"": 1000,
            ""levels"": {""claws"": 5, ""evolve1"": 1, ""evolve2"": 1, ""evolve3"": 1, ""r_beam"": 2}, ""runs"": 40, ""best"": {""rubble"": 9.0}}");
        GDict up2 = SaveFile.Migrate(v2);
        GDict levels = up2["levels"];
        Check(refund == Refund && Num.I(up2["version"]) == 6 && !levels.Has("evolve3") && Num.I(up2["rubble"]) == 1000 + refund
            && Num.I(levels["r_beam"]) == 2 && Num.I(levels["evolve2"]) == 1 && Num.I(up2["runs"]) == 40 && Num.F(up2["best"]["rubble"]) == 9.0,
            "a v2 save with Apex Titan comes up as v6, refunded 444500 rubble: " + Json.Stringify(up2, ""));
        UpgradeTree tree = new UpgradeTree(Content.Upgrades(), levels, "reptilian");
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), tree);
        Check(Num.I(stats["size"]) == 3, "the migrated tree is the adult (size 3): " + Num.I(stats["size"]));
        Check(Same(SaveFile.Migrate(up2), up2), "migrating a current save changes nothing");
        GDict plain = SaveFile.Migrate(Json.ParseDict(@"{""version"": 2, ""rubble"": 7, ""levels"": {""claws"": 1}}"));
        Check(Num.I(plain["rubble"]) == 7 && Num.I(plain["version"]) == 6, "a v2 save without the cut node keeps its bank");
        GDict twice = SaveFile.Migrate(Json.ParseDict(@"{""version"": 2, ""rubble"": 7, ""levels"": {""evolve3"": 2}}"));
        Check(Num.I(twice["rubble"]) == 7 + 2 * refund && twice["levels"].Size() == 0, "the refund is per level owned");

        GDict v3 = Json.ParseDict(@"{""version"": 3, ""species"": ""reptilian"", ""rubble"": 10, ""levels"": {""claws"": 1}, ""runs"": 2, ""best"": {""rubble"": 5.0}}");
        GDict up3 = SaveFile.Migrate(v3);
        Check(Num.I(up3["version"]) == 6 && Kept(up3, v3) && Num.F(up3["city_seconds"]) == 0.0 && up3["demo"] == false
            && up3["demo_done"] == false && up3["totals"].Size() == 0 && Num.I(up3["specimen"]) == 1 && HasCampaign(up3),
            "a v3 save gains the clock, the demo keys, K-01 and the campaign: " + Json.Stringify(up3, ""));

        GDict v4 = V4();
        GDict up4 = SaveFile.Migrate(v4);
        Check(Num.I(up4["version"]) == 6, "a v4 save migrates to v6");
        Check(Num.I(up4.Get("specimen", 0L)) == 1 && HasCampaign(up4), "a migrated v4 save is specimen K-01 with nothing conquered");
        Check(Kept(up4, v4), "migration keeps every v4 key unchanged: " + Json.Stringify(up4, ""));
        Check(Same(SaveFile.Migrate(up4), up4), "migrating the migrated v4 save changes nothing");

        GDict v5 = V5();
        GDict up5 = SaveFile.Migrate(v5);
        Check(Num.I(up5["version"]) == 6 && HasCampaign(up5), "a v5 save migrates to v6 with nothing conquered, Threat 0");
        Check(Kept(up5, v5) && Num.I(up5["specimen"]) == 3, "migration keeps every v5 key unchanged: " + Json.Stringify(up5, ""));
        Check(Same(SaveFile.Migrate(up5), up5), "migrating a v6 save changes nothing");

        GDict v6 = Json.ParseDict(CampaignFile);
        Check(Same(SaveFile.Migrate(v6), v6), "a v6 campaign save passes through unchanged");
        Check(SaveFile.Migrate(new GDict { { "version", 7L } }).IsEmpty(), "a save from a newer version is refused");
        Check(SaveFile.Migrate(new GDict { { "version", 0L } }).IsEmpty() && SaveFile.Migrate(new GDict { { "runs", 3L } }).IsEmpty() && SaveFile.Migrate(new GDict()).IsEmpty(),
            "a save with no version, or version 0, is refused");
    }

    // A slot file that cannot be read never reads empty: it is taken, not readable, and kept byte for byte.
    static void Unreadable()
    {
        SaveFile.Wipe();
        UserDir.WriteText(SaveFile.PathOf(1), NotJson);
        string newer = Json.Stringify(new GDict { { "version", 7L }, { "runs", 4L } }, "");
        UserDir.WriteText(SaveFile.PathOf(3), newer);
        Check(SaveFile.LoadGame(1).IsEmpty() && SaveFile.LoadGame(3).IsEmpty(), "corrupt and newer slot files load as nothing");
        Check(SaveFile.HasSave(1) && SaveFile.HasSave(3) && !SaveFile.HasSave(2), "but their slots are taken");
        var slots = SaveFile.Slots();
        Check(slots.Count == 3 && slots[0].Taken && !slots[0].Readable && !slots[0].Continues && slots[0].Summary == "" && slots[0].Specimen == "",
            "the corrupt slot is taken and unreadable in the slot list");
        Check(slots[2].Taken && !slots[2].Readable && !slots[2].Continues, "so is the newer one");
        Check(!slots[1].Taken && !slots[1].Readable && slots[1].Slot == 2, "the slot between them is empty");
        Check(SaveFile.LatestSlot() == 0, "nothing to continue among unreadable slots");
        Check(UserDir.ReadText(SaveFile.PathOf(1)) == NotJson && UserDir.ReadText(SaveFile.PathOf(3)) == newer, "the unreadable files are kept untouched");
        UserDir.WriteText(SaveFile.PathOf(2), "");
        Check(SaveFile.LoadGame(2).IsEmpty() && SaveFile.Info(2).Taken && !SaveFile.Info(2).Readable, "an empty file is unreadable, not EMPTY");
        UserDir.WriteText(SaveFile.PathOf(2), "[1, 2]");
        Check(SaveFile.LoadGame(2).IsEmpty() && !SaveFile.Info(2).Readable, "a file that is not an object is unreadable");
        UserDir.WriteText(SaveFile.PathOf(2), CampaignFile.Substring(0, CampaignFile.Length / 2));
        Check(SaveFile.LoadGame(2).IsEmpty() && !SaveFile.Info(2).Readable, "a save cut off half way is unreadable");
        SaveFile.Wipe();
    }

    static void Delete()
    {
        SaveFile.Wipe();
        SaveFile.SaveGame(SaveFile.NewSave("reptilian"), 1);
        SaveFile.SaveGame(SaveFile.NewSave("reptilian"), 2);
        Check(SaveFile.HasSave(2) && SaveFile.Info(2).Taken, "a saved slot is taken");
        SaveFile.DeleteSave(2);
        Check(!SaveFile.HasSave(2) && !SaveFile.Info(2).Taken && SaveFile.LoadGame(2).IsEmpty() && !UserDir.Exists(SaveFile.PathOf(2)),
            "delete empties slot 2 on disk");
        Check(SaveFile.HasSave(1) && Num.I(SaveFile.LoadGame(1)["specimen"]) == 1, "deleting slot 2 leaves slot 1's kaiju");
        SaveFile.DeleteSave(2);
        Check(!SaveFile.HasSave(2), "deleting an empty slot is quiet");
        SaveFile.Wipe();
    }

    static void Stamp(int slot, int minute) =>
        File.SetLastWriteTimeUtc(UserDir.Path(SaveFile.PathOf(slot)), new DateTime(2026, 1, 1, 12, minute, 0, DateTimeKind.Utc));

    // CONTINUE resumes the save written last among those this build can continue.
    static void Latest()
    {
        SaveFile.Wipe();
        Check(SaveFile.LatestSlot() == 0 && SaveFile.LatestSlot(save => true) == 0, "no saves, nothing latest");
        for (int n = 1; n <= 3; n++)
        {
            GDict save = SaveFile.NewSave("reptilian");
            save["runs"] = (long)n;
            save["demo"] = n != 1;
            SaveFile.SaveGame(save, n);
        }
        Stamp(1, 10);
        Stamp(2, 30);
        Stamp(3, 20);
        Check(SaveFile.LatestSlot() == 2, "the slot written last is the latest: " + SaveFile.LatestSlot());
        Check(SaveFile.LatestSlot(save => Num.I(save["runs"]) != 2) == 3, "a save the filter refuses is passed over");
        Check(SaveFile.LatestSlot(save => false) == 0, "none accepted, none latest");
        Stamp(3, 30);
        Check(SaveFile.LatestSlot() == 2, "on a tie the lower slot wins (as Godot's loop)");
        Content.Section("demo")["enabled"] = false;
        Check(SaveFile.LatestSlot() == 1, "with the demo off a demo save does not continue (D-145): " + SaveFile.LatestSlot());
        Check(!SaveFile.Info(2).Continues && SaveFile.Info(2).Readable && SaveFile.Info(2).Summary == "" && SaveFile.Info(1).Continues,
            "and its slot says so (NOT IN THIS VERSION), still readable");
        Content.Section("demo")["enabled"] = true;
        Check(SaveFile.Info(2).Continues, "with the demo on it continues");
        GDict other = SaveFile.NewSave("insectoid");
        SaveFile.SaveGame(other, 2);
        Stamp(2, 50);
        Check(SaveFile.LatestSlot() == 3 && !SaveFile.Info(2).Continues, "a species this build does not play is never continued");
        UserDir.WriteText(SaveFile.PathOf(2), NotJson);
        Stamp(2, 55);
        Check(SaveFile.LatestSlot() == 3, "an unreadable newest file is passed over");
        SaveFile.Wipe();
    }

    // K-01 on a new save; every death moves it on; felling the city does not. Survives a reload.
    static void Specimen()
    {
        GDict save = SaveFile.NewSave("reptilian");
        Check(SaveFile.SpecimenName(save) == "SPECIMEN K-01", "a new kaiju is SPECIMEN K-01: " + SaveFile.SpecimenName(save));
        string moved = "";
        foreach (string reason in new[] { "time", "ended", "city_fallen", "defeated" })
        {
            moved += SaveFile.NoteEnd(save, new GDict { { "reason", reason } }) ? "1" : "0";
        }
        Check(moved == "1101" && SaveFile.SpecimenName(save) == "SPECIMEN K-04", "time's up, End rampage and a kill each make the next specimen; a fallen city does not: " + moved);
        Check(!SaveFile.NoteEnd(save, new GDict()) && Num.I(save["specimen"]) == 4, "a result with no reason is no death");
        SaveFile.SaveGame(save, 3);
        Check(SaveFile.SpecimenName(SaveFile.LoadGame(3)) == "SPECIMEN K-04", "the specimen number lives in the slot (save, reload)");
        Check(save["lab_card"] == true && SaveFile.TakeLabCard(save) && save["lab_card"] == false && !SaveFile.TakeLabCard(save),
            "a death owes the lab card once");
        Check(!SaveFile.TakeLabCard(new GDict()), "a save from before the flag owes none");
        Check(SaveFile.SpecimenName(new GDict()) == "SPECIMEN K-01" && SaveFile.SpecimenName(new GDict { { "specimen", 123.0 } }) == "SPECIMEN K-123",
            "no number reads K-01; a long one is not cut");
        SaveFile.Wipe();
    }

    // What one rampage banks, on canned results.
    static void Banking()
    {
        GDict best = new GDict { { "rubble", 900.0 }, { "toppled", 5.0 } };
        GDict merged = SaveFile.MergeBest(best, new GDict { { "rubble", 800L }, { "toppled", 7L }, { "mechs", 1L }, { "fled", 99L } });
        Check(Num.F(merged["rubble"]) == 900.0 && Num.F(merged["toppled"]) == 7.0 && Num.F(merged["mechs"]) == 1.0 && !merged.Has("fled") && merged.Size() == 3,
            "the best record keeps the higher of each stat and only the record keys: " + Json.Stringify(merged, ""));
        Check(Num.F(best["toppled"]) == 5.0 && best.Size() == 2, "the record given is not changed");

        GDict save = SaveFile.NewSave("reptilian", 3);
        save["best"] = new GDict { { "rubble", 1.0e9 } }; // runs is 0, so this is not a record yet
        GDict first = new GDict
        {
            { "reason", "time" }, { "rubble", 1500L }, { "city_seconds", 42.5 }, { "destruction", 0.6 }, { "toppled", 9L },
            { "civilians", 30L }, { "tanks", 2L }, { "helis", 1L }, { "rooftops", 3L }, { "buildings", 12L }, { "fled", 40L },
            { "seconds", 95.7 }, { "ignored", 5L },
        };
        GDict previous = SaveFile.Bank(save, first, false);
        Check(previous.IsEmpty(), "a first rampage has no record before it");
        Check(Num.I(save["rubble"]) == 1500 && Num.I(save["runs"]) == 1 && Num.F(save["city_seconds"]) == 42.5,
            "it banks its biomass, one run and the Taskforce's clock");
        Check(Num.I(save["specimen"]) == 2 && save["lab_card"] == true, "time's up is a death: K-02, lab card owed");
        GDict wantBest = new GDict { { "rubble", 1500.0 }, { "destruction", 0.6 }, { "toppled", 9.0 }, { "civilians", 30.0 }, { "tanks", 2.0 }, { "helis", 1.0 } };
        Check(Same(save["best"], wantBest), "the record is this rampage: " + Json.Stringify(save["best"], ""));
        GDict wantTotals = new GDict { { "biomass", 1500L }, { "buildings", 12L }, { "eaten", 30L }, { "fled", 40L }, { "military", 6L }, { "seconds", 95L } };
        Check(Same(save["totals"], wantTotals), "the demo totals add it up: " + Json.Stringify(save["totals"], ""));

        GDict second = new GDict { { "reason", "city_fallen" }, { "rubble", 800L }, { "destruction", 0.5 }, { "toppled", 11L }, { "tanks", 1L }, { "seconds", 10.2 } };
        previous = SaveFile.Bank(save, second, false);
        Check(Same(previous, wantBest), "the second rampage is compared with the first's record: " + Json.Stringify(previous, ""));
        Check(Num.I(save["rubble"]) == 2300 && Num.I(save["runs"]) == 2 && Num.F(save["city_seconds"]) == 42.5 && Num.I(save["specimen"]) == 2,
            "it adds to the bank; no clock in the result keeps the clock; a fallen city is no death");
        Check(Num.F(save["best"]["rubble"]) == 1500.0 && Num.F(save["best"]["toppled"]) == 11.0 && Num.F(save["best"]["destruction"]) == 0.6 && Num.F(save["best"]["tanks"]) == 2.0,
            "each record is the higher of the two: " + Json.Stringify(save["best"], ""));
        Check(Num.I(save["totals"]["biomass"]) == 2300 && Num.I(save["totals"]["seconds"]) == 105 && Num.I(save["totals"]["military"]) == 7 && Num.I(save["totals"]["buildings"]) == 12,
            "the totals grow: " + Json.Stringify(save["totals"], ""));

        GDict bestNow = ((GDict)save["best"]).Duplicate(true);
        GDict totalsNow = ((GDict)save["totals"]).Duplicate(true);
        previous = SaveFile.Bank(save, new GDict { { "reason", "defeated" }, { "rubble", 999L }, { "toppled", 500L } }, true);
        Check(Same(previous, bestNow) && Num.I(save["rubble"]) == 2300 && Num.I(save["runs"]) == 2 && Same(save["best"], bestNow) && Same(save["totals"], totalsNow),
            "Endless banks nothing");
        Check(Num.I(save["specimen"]) == 3 && save["lab_card"] == true, "but a death in Endless still makes the next specimen");

        Content.Section("demo")["enabled"] = false;
        SaveFile.Bank(save, first, false);
        Check(Same(save["totals"], totalsNow) && Num.I(save["runs"]) == 3 && Num.I(save["rubble"]) == 3800, "outside the demo no totals are kept (on vs off)");
        Content.Section("demo")["enabled"] = true;

        SaveFile.SaveGame(save, 1);
        GDict back = SaveFile.LoadGame(1);
        Check(Same(back, save), "a banked save reloads equal");
        SaveFile.Wipe();
    }

    // The Apex Titan refund on top of a huge bank: exact digits in the file, exact value back.
    static void BigNumbers()
    {
        GDict rich = Json.ParseDict("{\"version\": 2, \"species\": \"reptilian\", \"rubble\": " + BigBank + ", \"levels\": {\"evolve3\": 1}}");
        GDict up = SaveFile.Migrate(rich);
        Check(Num.I(up["rubble"]) == BigBank + Refund, "444500 lands on a 9e12 bank exactly: " + Num.I(up["rubble"]));
        SaveFile.SaveGame(up, 1);
        string text = UserDir.ReadText(SaveFile.PathOf(1));
        Check(text.Contains("\"rubble\": 9000000444500,"), "the file holds every digit: " + text.Replace("\n", " "));
        Check(!text.Contains("E+") && !text.Contains("e+") && !text.Contains(".0"), "no exponent form, no .0");
        Check(Num.I(SaveFile.LoadGame(1)["rubble"]) == BigBank + Refund, "and it reads back exactly");
        GDict save = SaveFile.LoadGame(1);
        SaveFile.Bank(save, new GDict { { "reason", "time" }, { "rubble", 444500.0 } }, false);
        SaveFile.SaveGame(save, 1);
        text = UserDir.ReadText(SaveFile.PathOf(1));
        Check(text.Contains("\"rubble\": 9000000889000,") && Num.I(SaveFile.LoadGame(1)["rubble"]) == BigBank + 2 * Refund,
            "banking 444500 more as a float (as JSON reads it) still writes an integer");
        Check(Json.Number(9007199254740992.0) == "9007199254740992" && Json.Number(1.0e15) == "1000000000000000" && Json.Stringify(4503599627370497L, "") == "4503599627370497",
            "whole values print in full up to the double's limit");
        Check(Num.I(JSON.ParseString(Json.Number(1.0e15))) == 1000000000000000L, "and parse back");
        SaveFile.Wipe();
    }

    // The city seed: pinned for tests and unattended proofs, 32 bits otherwise.
    static void Seed()
    {
        SaveFile.PinnedSeed = 0;
        Check(SaveFile.FreshSeed() == 0 && SaveFile.FreshSeed() == 0, "pinned to 0, every fresh seed is 0");
        SaveFile.PinnedSeed = 77;
        Check(SaveFile.FreshSeed() == 77, "pinned to 77, it is 77");
        SaveFile.PinnedSeed = -1;
        long drawn = SaveFile.FreshSeed();
        Check(drawn >= 0 && drawn <= uint.MaxValue, "unpinned it is a 32-bit number: " + drawn);
        SaveFile.PinnedSeed = 0;
    }

    // What the title shows for each slot (main.gd _slots() and _summary()).
    static void Title()
    {
        SaveFile.Wipe();
        GDict save = SaveFile.NewSave("reptilian");
        save["runs"] = 2L;
        save["rubble"] = 321L;
        save["specimen"] = 4L;
        save["demo"] = true;
        SaveFile.SaveGame(save, 2);
        var slots = SaveFile.Slots();
        SlotInfo two = slots[1];
        Check(slots.Count == 3 && !slots[0].Taken && !slots[2].Taken && slots[0].Slot == 1 && slots[2].Slot == 3, "three slots, 1 and 3 empty");
        Check(two.Taken && two.Readable && two.Continues && two.Specimen == "SPECIMEN K-04" && two.Species == "Reptilian" && two.SpeciesId == "reptilian" && two.Runs == 2 && two.Rubble == 321,
            "the filled slot names its specimen and species: " + two.Specimen + ", " + two.Species);
        Check(two.Summary == "Reptilian, 2 rampages, 321 biomass", "its summary: " + two.Summary);
        save["runs"] = 1L;
        Check(SaveFile.Summary(save) == "Reptilian, 1 rampage, 321 biomass", "one rampage is singular: " + SaveFile.Summary(save));
        Check(SaveFile.Summary(new GDict()) == "" && SaveFile.Summary(SaveFile.LoadGame(SaveFile.LatestSlot())) == two.Summary, "no save, no summary; Continue's line is the latest slot's");
        SaveFile.Translate = text => text.Replace("SPECIMEN", "ESEMPLARE").Replace("rampages", "distruzioni").Replace("Reptilian", "Rettile");
        Check(SaveFile.Info(2).Specimen == "ESEMPLARE K-04" && SaveFile.Info(2).Summary == "Rettile, 2 distruzioni, 321 biomass" && SaveFile.Info(2).Species == "Reptilian",
            "player text goes through the text table: " + SaveFile.Info(2).Summary);
        SaveFile.Wipe();
    }
}
