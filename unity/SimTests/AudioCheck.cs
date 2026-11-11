// The sound table and the mixing rules (GameLogic/Audio*.cs, after scenes/sfx*.gd, audio_buses.gd,
// city_curve.gd, music_layers.gd) are plain C#, so they are held here: every id the table holds and every id a
// Godot script plays resolves to a file on disk, the levels and buses are tuning's, and the voice, gap, duck
// and curve rules give Godot's answers.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using Kaiju.Game;
using S = Kaiju.Sim;

static class AudioCheck
{
    static int checks, failed;

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        S.FileAccess.Root = repoRoot;
        AudioTable table = AudioTable.Load();
        Files(table, repoRoot);
        GodotIds(table, repoRoot);
        Rows(table);
        Buses(table);
        Voices(table);
        Shade(table);
        Curves(table);
        Console.WriteLine($"audio: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("audio: FAILED " + what);
    }

    static bool Near(double a, double b, double eps = 1e-6) => Math.Abs(a - b) <= eps;

    // Every id has a file under assets/, and the player's copy (when the build has made one) holds it too.
    static void Files(AudioTable table, string repoRoot)
    {
        Check(table.ids.Count >= 70, "the table holds every sound (" + table.ids.Count + ")");
        foreach (string id in table.ids)
            Check(File.Exists(Path.Combine(repoRoot, table.Get(id).file)), id + " -> " + table.Get(id).file + " is on disk");
        string copy = Path.Combine(repoRoot, "unity", "Assets", "StreamingAssets", "res");
        if (!Directory.Exists(Path.Combine(copy, "assets", "sfx"))) return;
        int missing = 0;
        foreach (string file in table.Files())
            if (!File.Exists(Path.Combine(copy, file))) missing++;
        Check(missing == 0, "the player's StreamingAssets copy holds every file (" + missing + " missing)");
    }

    // Every sound a Godot script names in a play call is in the table.
    static void GodotIds(AudioTable table, string repoRoot)
    {
        var call = new Regex("(?:sfx\\.play|sfx\\.ui|play_at|play_near|_looping|_emit|_loop)\\(\\s*\"([a-z0-9_]+)\"", RegexOptions.IgnoreCase);
        var found = new SortedSet<string>();
        foreach (string dir in new[] { "scenes", "autoload" })
            foreach (string path in Directory.GetFiles(Path.Combine(repoRoot, dir), "*.gd"))
                foreach (Match m in call.Matches(File.ReadAllText(path)))
                    found.Add(m.Groups[1].Value);
        Check(found.Count >= 25, "the scan finds Godot's play calls (" + found.Count + ")");
        foreach (string id in found) Check(table.Has(id), "Godot plays \"" + id + "\" and the table has it");
        foreach (string id in new[] { "breath", "leap_whoosh", "leap_land", "lash", "ready", "deflect", "tank_fire",
            "shell_hit", "heli_gun", "heli_crash", "blast_crack", "blast_body", "blast_rumble", "sonic_boom", "ui_click", "tree_buy" })
            Check(found.Contains(id), "the scan sees \"" + id + "\"");
    }

    static void Rows(AudioTable table)
    {
        Check(Near(table.Get("roar").db, -1.0) && table.Get("roar").bus == "Hero" && table.Get("roar").category == "hero", "roar: -1 dB, Hero bus, hero voice");
        Check(Near(table.Get("stomp_1").db, -4.0) && table.Get("stomp_1").category == "stomp", "stomp_1 takes the \"stomp\" level");
        Check(Near(table.Get("stomp_crack").db, -5.0), "stomp_crack keeps its own level");
        Check(Near(table.Get("footstep_2").db, -9.0) && table.Get("footstep_2").category == "body", "footstep_2 takes the \"footstep\" level");
        AudioRow far = table.Get("rifle_far");
        Check(far.file == "assets/sfx/rifle.ogg" && Near(far.db, -14.0) && Near(far.pitch, 0.7), "rifle_far is the rifle, softer and lower");
        Check(Near(far.minInterval, 0.5) && Near(far.intervalJitter, 0.8) && Near(far.gainJitterDb, 3.0) && Near(far.pitchJitter, 0.1), "rifle_far's gap and swing");
        Check(Near(table.Get("breath").pitchJitter, 0.06) && Near(table.Get("breath").minInterval, 0.0), "breath: the default jitter, no gap");
        Check(table.Get("collapse_drop").file == "assets/sfx/collapse.ogg" && table.Get("collapse_drop").bus == "Debris", "a dropped slab is the collapse on Debris");
        Check(table.Get("ui_click").bus == "UI" && Near(table.Get("ui_click").db, -12.0), "ui_click: UI bus, -12 dB");
        Check(table.Get("lab_latch").bus == "SFX" && table.Get("lab_room").bus == "Ambience", "the lab's buses");
        Check(table.Get("theme").file == "assets/music/theme.ogg" && Near(table.Get("theme").db, -4.0) && table.Get("theme").bus == "Music", "the theme");
        Check(table.Tracks().Count == 3 && table.Get("city_2_brass").file == "assets/music/city_2_brass.ogg", "three city tracks of stems");
        Check(Near(AudioMix.TrackSeconds(table.Track("city_1")), 21 * 4 * 60.0 / 67.8953), "city_1 is 21 bars long");
        Check(table.BusOf("nothing") == "SFX" && table.CategoryOf("nothing") == "body" && Near(table.VolumeDb("nothing"), 0.0), "an unknown sound: SFX, body, 0 dB");
    }

    static void Buses(AudioTable table)
    {
        var map = new AudioBusMap(table.audio);
        foreach (string bus in map.names) Check(map.Chain(bus)[map.Chain(bus).Count - 1] == "Master", bus + " reaches Master");
        Check(string.Join(">", map.Chain("Crowd")) == "Crowd>Bed>SFX>Master", "Crowd > Bed > SFX > Master");
        Check(map.Under("UI", "SFX") && map.Under("Hero", "SFX") && !map.Under("Music", "SFX"), "the sfx slider reaches UI and Hero, not Music");
        Check(string.Join(",", map.Ducks("Military")) == "bed" && string.Join(",", map.Ducks("Music")) == "music" && map.Ducks("Hero").Count == 0, "the bed and the music duck; the hero does not");
        Check(string.Join(">", map.Chain("Nowhere")) == "Master", "an unknown bus plays on Master");
        Check(Near(AudioMix.Linear(0), 1.0) && Near(AudioMix.Linear(-20), 0.1) && Near(AudioMix.Db(0.5), -6.0206, 1e-3), "decibels");
        Check(Near(AudioMix.MoveToward(-60, 0, 6), -54) && Near(AudioMix.MoveToward(-2, 0, 6), 0) && Near(AudioMix.MoveToward(0, -60, 8), -8), "move toward");
        Check(Near(AudioMix.DistanceDb(40, 80, -18), 0) && Near(AudioMix.DistanceDb(160, 80, -18), -6.0206, 1e-3) && Near(AudioMix.DistanceDb(5000, 80, -18), -18), "distance: full near, -6 dB a doubling, floored");
        Check(Near(AudioMix.UnitDb(12, 12), 0) && Near(AudioMix.UnitDb(24, 12), -6.0206, 1e-3) && Near(AudioMix.UnitDb(1, 12), 3), "a 3D player's fall-off");
        S.GDict duck = map.ducks["music"];
        double cut = AudioMix.DuckDb(-8, S.Num.F(duck["threshold_db"]), S.Num.F(duck["ratio"]));
        Check(Near(cut, 6.0) && Near(AudioMix.DuckDb(-30, -18, 2.5), 0), "the music duck: 10 dB over at 2.5:1 is 6 dB off");
        Check(Near(AudioMix.DuckStep(0, 6, 400, 0.016), 6) && AudioMix.DuckStep(6, 0, 400, 0.4) < 2.3 && AudioMix.DuckStep(6, 0, 400, 0.4) > 2.1, "a duck bites at once and eases back");
    }

    static void Voices(AudioTable table)
    {
        S.GDict caps = table.sfx["voice_caps"];
        int count = (int)S.Num.I(table.sfx["voices"]);
        var v = new AudioVoices(count, caps);
        Check(count == 24 && v.Cap("hero") == 2 && v.IsHero("stomp") && !v.IsHero("weapon"), "24 voices; hero cap 2; stomps are the kaiju's");
        int a = v.Take("rifle", "weapon", 0, 1);
        Check(a == 0 && v.Take("rifle", "weapon", 0, 1) < 0 && v.dropped == 1, "the same sound inside 30 ms is dropped");
        v.Advance(0.05);
        Check(v.Take("rifle", "weapon", 0, 1) == 1, "and plays 50 ms on");
        // The hero's cap: a third roar inside a second is dropped, after it the oldest is cut.
        v = new AudioVoices(count, caps);
        v.Take("roar", "hero", 0, 5);
        v.Take("thunder_beam", "hero", 0, 5);
        Check(v.Take("thunder_beam_end", "hero", 0, 5) < 0, "a third hero sound inside a second is dropped");
        v.Advance(1.1);
        Check(v.Take("thunder_beam_end", "hero", 0, 5) == 0 && v.heroesCut == 1, "after a second it cuts the oldest of its own");
        // A full category gives up its quietest voice to a louder sound only.
        v = new AudioVoices(count, caps);
        for (int i = 0; i < 3; i++) v.Take("c" + i, "crowd", -10 + i, 5);
        Check(v.Take("quiet", "crowd", -20, 5) < 0, "a quieter sound does not steal");
        Check(v.Take("loud", "crowd", -5, 5) == 0 && v.stolen == 1, "a louder one takes the quietest voice");
        // The others leave room for the hero.
        v = new AudioVoices(count, caps);
        int reserve = (int)S.Num.I(caps["reserve_hero"]);
        int held = 0;
        foreach (string kind in new[] { "weapon", "debris" })
            for (int i = 0; i < v.Cap(kind); i++)
                if (v.Take(kind + i, kind, 0, 5) >= 0) held++;
        Check(held == count - reserve, "the others fill " + (count - reserve) + " voices (" + held + ")");
        Check(v.Take("b0", "body", -3, 5) < 0, "a quieter body sound finds the share full");
        Check(v.Take("roar", "hero", -30, 5) == held && v.heroesStolen == 0, "the hero still gets a free voice");
        v.Clear();
        Check(v.BusyIn("") == 0, "a new scene frees every voice");
    }

    static void Shade(AudioTable table)
    {
        var shade = new AudioShade(table, S.Seeds.Make("sfx", 1));
        Check(!shade.TooSoon("breath") && !shade.TooSoon("breath"), "a sound with no gap always plays");
        Check(!shade.TooSoon("blast_crack") && shade.TooSoon("blast_crack"), "blast_crack: once, then too soon");
        shade.Advance(0.09);
        Check(!shade.TooSoon("blast_crack"), "and again 90 ms on");
        Check(!shade.TooSoon("rifle"), "the first rifle shot plays");
        shade.Advance(0.2);
        Check(shade.TooSoon("rifle"), "a rifle 0.2 s on is too soon");
        shade.Advance(0.25);
        Check(!shade.TooSoon("rifle"), "0.45 s on it plays (gap 0.25 stretched at most 0.6)");
        bool inRange = true, moved = false;
        for (int i = 0; i < 50; i++)
        {
            double p = shade.Pitched("breath", 1.0);
            inRange &= p >= 0.94 - 1e-6 && p <= 1.06 + 1e-6;
            moved |= Math.Abs(p - 1.0) > 0.001;
            double s = shade.Swing("rifle");
            inRange &= s >= -3.0 && s <= 3.0;
        }
        Check(inRange && moved, "pitch stays within 6 %, the rifle's swing within 3 dB");
        Check(Near(shade.Swing("breath"), 0.0), "no swing where tuning gives none");
        shade.SetSizeTier(3);
        double low = shade.Pitched("stomp_1", 1.0);
        Check(low >= 0.88 * 0.94 - 1e-6 && low <= 0.88 * 1.06 + 1e-6, "the adult's stomp is pitched down (0.88)");
        double farShot = shade.Pitched("rifle_far", 1.0);
        Check(farShot >= 0.7 * 0.9 - 1e-6 && farShot <= 0.7 * 1.1 + 1e-6, "a far rifle is pitched to 0.7");
        // The same seed gives the same variation: a replay sounds the same.
        var one = new AudioShade(table, S.Seeds.Make("sfx", 7));
        var two = new AudioShade(table, S.Seeds.Make("sfx", 7));
        Check(Near(one.Pitched("lash", 1.0), two.Pitched("lash", 1.0)), "the dice are seeded");
    }

    static void Curves(AudioTable table)
    {
        S.GDict city = S.Content.Section("city_sound");
        S.GDict phase = city["phase"];
        Check(Near(AudioMix.Phase(phase, 0, 0, 100), 0) && Near(AudioMix.Phase(phase, 0.2, 60, 100), 1) && Near(AudioMix.Phase(phase, 0.1, 0, 100), 0.25), "the city's phase");
        S.GDict beds = city["beds"];
        S.GDict siren = beds["city_siren"];
        S.GArray<S.Variant> curve = siren["curve"];
        Check(Near(AudioMix.Along(curve, -1), -60) && Near(AudioMix.Along(curve, 0.2), -10) && Near(AudioMix.Along(curve, 0.3), -11) && Near(AudioMix.Along(curve, 2), -60), "the siren's curve");
        S.GDict crowdBed = beds["crowd"];
        S.GArray<S.Variant> crowdCurve = crowdBed["curve"];
        Check(Near(AudioMix.Along(crowdCurve, 0.1), 0) && Near(AudioMix.Along(crowdCurve, 0.475), -15), "the crowd's trim");
        Check(Near(AudioMix.StemDb(0.0, 0.2, 0.4, -60), -60) && Near(AudioMix.StemDb(0.3, 0.2, 0.4, -60), -30) && Near(AudioMix.StemDb(1, 0.2, 0.4, -60), 0), "a stem fades in between enter and full");
        S.GDict crowd = table.sfx["crowd"];
        double full = table.VolumeDb("crowd_panic");
        Check(Near(AudioMix.CrowdTarget(crowd, full, 0.0, false), -60) && Near(AudioMix.CrowdTarget(crowd, full, 1.0, false), -6) && Near(AudioMix.CrowdTarget(crowd, full, 1.0, true), -15) && Near(AudioMix.CrowdTarget(crowd, full, 0.5, false), -15), "the crowd's level and its duck under the breath");
        Check(Near(AudioMix.CrowdIntensity(crowd, 40, 30), 1.0) && Near(AudioMix.CrowdIntensity(crowd, 20, 0), 0.35), "the crowd's intensity");
    }
}
