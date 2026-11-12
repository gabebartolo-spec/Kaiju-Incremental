// GlobeMath and GlobeMissions (Assets/Scripts/GameLogic) against what Godot's globe does: scenes/globe_view.gd,
// globe_anchors.gd, globe_missions.gd, mission_panel.gd, stub_mission.gd, threat_readout.gd, on the data files and
// the real mask. Each expectation names the Godot line, test or data row it comes from.
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using Kaiju.Game;
using Kaiju.Sim;

static class GlobeCheck
{
    const double EPS = 1e-9;
    const string MASK = "assets/overworld/tellus_nova_mask.png";

    static int checks, failed;

    public static int Run(string repoRoot)
    {
        Kaiju.Sim.FileAccess.Root = repoRoot;
        checks = failed = 0;
        Uv();
        SmallMask();
        RealMask(Path.Combine(repoRoot, MASK));
        States();
        Panel();
        Threat();
        Missions();
        Console.WriteLine($"globe: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL globe: " + what);
    }

    static GArray<Variant> Arr(Variant v)
    {
        GArray<Variant> a = v;
        return a;
    }

    // tests/run_globe_mission_tests.gd's save: a campaign not started.
    static GDict NewSave()
    {
        return new GDict
        {
            { "version", 6L }, { "species", "reptilian" }, { "seed", 12345L }, { "rubble", 0L }, { "levels", new GDict() }, { "runs", 0L },
            { "demo_done", false }, { "conquered", Gd.Arr() }, { "bonuses", new GDict() }, { "threat", 0.0 },
        };
    }

    // globe_view.gd uv_of / point_of: the two are each other's inverse; the fixed points of the mapping.
    static void Uv()
    {
        GlobeMath.UvOf(0, 0, 1, out double u, out double v);
        Check(Math.Abs(u) < EPS && Math.Abs(v - 0.5) < EPS, $"+z is uv (0, 0.5): ({u}, {v})");
        GlobeMath.UvOf(1, 0, 0, out u, out v);
        Check(Math.Abs(u - 0.25) < EPS && Math.Abs(v - 0.5) < EPS, $"+x is uv (0.25, 0.5): ({u}, {v})");
        GlobeMath.UvOf(-1, 0, 0, out u, out v);
        Check(Math.Abs(u - 0.75) < EPS, $"-x wraps to u 0.75 (fposmod): {u}");
        Check(BitConverter.DoubleToInt64Bits(Gd.Fposmod(-0.0, 1.0)) == 0L, "fposmod of -0.0 is 0.0, as Godot (its sign bit is clear)");
        GlobeMath.UvOf(0, 2, 0, out u, out v);
        Check(Math.Abs(v) < EPS, $"the north pole is v 0, whatever the length: {v}");
        double worst = 0.0;
        for (int i = 1; i < 20; i++)
        {
            for (int j = 1; j < 10; j++)
            {
                double u0 = i / 20.0, v0 = j / 10.0;
                GlobeMath.PointOf(u0, v0, out double x, out double y, out double z);
                GlobeMath.UvOf(x, y, z, out u, out v);
                worst = Math.Max(worst, Math.Max(Math.Abs(u - u0), Math.Abs(v - v0)));
            }
        }
        Check(worst < 1e-9, $"uv_of(point_of(uv)) is uv (worst {worst})");
    }

    // A 64 x 32 mask with one block of 1 and a block of 2 across the seam: id_at_uv, anchors, coast.
    static void SmallMask()
    {
        const int W = 64, H = 32;
        byte[] m = new byte[W * H];
        for (int y = 8; y < 24; y++) for (int x = 8; x < 28; x++) m[y * W + x] = 1;
        for (int y = 8; y < 24; y++) for (int x = 56; x < 72; x++) m[y * W + x % W] = 2;
        Check(GlobeMath.IdAtUv(m, W, H, 10.5 / W, 10.5 / H) == 1, "id_at_uv reads the block");
        Check(GlobeMath.IdAtUv(m, W, H, 0.5, 0.5) == 0, "id_at_uv reads the sea");
        Check(GlobeMath.IdAtUv(m, W, H, 1.0, 1.0) == 0 && GlobeMath.IdAtUv(m, W, H, -0.2, 0.3) == 2, "id_at_uv clamps to the image (clampi): past the left edge reads column 0");
        Check(GlobeMath.IdAtUv(null, 0, 0, 0.5, 0.5) == 0, "no mask is all sea");
        double[][] a = GlobeMath.AnchorUvs(m, W, H, 3);
        Check(a.Length == 4 && a[0] == null && a[3] == null, "anchors: one entry per value, none for the sea or a continent with no land");
        Check(a[1] != null && GlobeMath.IdAtUv(m, W, H, a[1][0], a[1][1]) == 1, "continent 1's anchor is on continent 1");
        // Inland samples of block 1 are x 12, 16, 20 and y 12, 16 (step 4); its samples' mean direction is at x 16.5, y 14.5.
        Check(a[1] != null && Math.Abs(a[1][0] - 16.5 / W) < EPS && (Math.Abs(a[1][1] - 12.5 / H) < EPS || Math.Abs(a[1][1] - 16.5 / H) < EPS), $"continent 1's anchor is an inland sample nearest the middle: ({a[1]?[0] * W}, {a[1]?[1] * H})");
        Check(a[2] != null && GlobeMath.IdAtUv(m, W, H, a[2][0], a[2][1]) == 2, "a continent across the seam still gets an anchor (posmod)");
        Check(a[2] != null && (Math.Abs(a[2][0] - 0.5 / W) < EPS || Math.Abs(a[2][0] - 60.5 / W) < EPS), $"the seam continent's anchor is at the seam: x {a[2]?[0] * W}");
        Check(GlobeMath.Coast(m, W, H, 8, 12, 2) && !GlobeMath.Coast(m, W, H, 16, 16, 2), "coast: an edge texel differs from a neighbour 2 away, an inland one does not");
        Check(GlobeMath.Coast(m, W, H, 63, 12, 2) == false && GlobeMath.Coast(m, W, H, 57, 12, 2), "coast wraps in x as the texture repeats");
    }

    // tests/run_globe_tests.gd _check_globe_mask and _check_globe_markers on the shipped mask.
    static void RealMask(string file)
    {
        byte[] m = Png(file, out int w, out int h);
        Check(m != null && w == 2 * h, $"the mask is 2:1 equirectangular ({w} x {h})");
        if (m == null) return;
        int count = (int)Content.Continents().Size();
        int[] counts = new int[256];
        foreach (byte b in m) counts[b]++;
        int stray = 0;
        for (int v = count + 1; v < 256; v++) stray += counts[v];
        Check(stray == 0, $"every pixel is sea or one of the {count} continents ({stray} stray)");
        double[][] a = GlobeMath.AnchorUvs(m, w, h, count);
        for (int n = 0; n < count; n++)
        {
            string id = Gd.Str(Content.Continents()[n]["id"]);
            Check(counts[n + 1] > 0, $"{id} has land on the mask");
            Check(a[n + 1] != null && GlobeMath.IdAtUv(m, w, h, a[n + 1][0], a[n + 1][1]) == n + 1, $"{id}'s anchor is on {id}");
        }
        for (int n = 1; n <= count; n++)
        {
            for (int k = n + 1; k <= count; k++)
            {
                if (a[n] == null || a[k] == null) continue;
                // The flat map's markers: two anchors must not sit on each other.
                double dx = (a[n][0] - a[k][0]) * w, dy = (a[n][1] - a[k][1]) * h;
                Check(Math.Sqrt(dx * dx + dy * dy) > 40.0, $"anchors {n} and {k} stand apart on the map ({Math.Sqrt(dx * dx + dy * dy):F0} texels)");
            }
        }
    }

    // sim/campaign.gd states through the globe: a new campaign opens Ostia Minor alone.
    static void States()
    {
        GDict save = NewSave();
        GDict states = GlobeMissions.States(save);
        List<string> open = GlobeMissions.Open(states);
        Check(open.Count >= 1 && open[0] == "ostia_minor", $"a new campaign opens ostia_minor first: {string.Join(",", open)}");
        Check(GlobeMissions.Locked(states, "aurelia") && GlobeMissions.Locked(states, ""), "the capital and the sea are locked (globe_view.gd locked)");
        Check(GlobeMissions.FirstRealCity(save) == "ostia_minor", $"the smoke's selection is ostia_minor: {GlobeMissions.FirstRealCity(save)}");
        long[] per = GlobeMissions.StatesByValue(states);
        Check(per.Length == 8 && per[0] == Campaign.State.LOCKED && per[1] == Campaign.State.AVAILABLE, "per mask value: 8 entries, the sea locked, value 1 available");
        Check(GlobeMissions.Step(states, "", 1) == open[0] && GlobeMissions.Step(states, "", -1) == open[open.Count - 1], "stepping from nothing picks the first (or last) open continent");
        Check(GlobeMissions.Step(states, open[open.Count - 1], 1) == open[0], "stepping wraps round the open continents");
        GDict won = Campaign.Conquer(save, Content.Continent("ostia_minor"), "bonus_ostia_minor_1");
        GDict after = GlobeMissions.States(won);
        Check(GlobeMissions.StateOf(after, "ostia_minor") == Campaign.State.CONQUERED, "a conquered continent reads conquered");
        Check(GlobeMissions.Open(after).Contains("ostia_minor"), "a conquered continent can still be picked (only locked ones cannot, globe_view.gd _open_at)");
        string next = GlobeMissions.FirstRealCity(won);
        Check(next != "ostia_minor" && next != "" && Campaign.RealCity(Content.Continent(next)), $"after Ostia the smoke's selection is the next real city: {next}");
        // tests/run_globe_mission_tests.gd _check_threat_readout: the sixth conquest opens Aurelia.
        GDict all = save;
        foreach (GDict def in Content.Continents()) if (def.Get("capital", false) != true) all = Campaign.Conquer(all, def, "");
        Check(!GlobeMissions.Locked(GlobeMissions.States(all), "aurelia"), "the sixth conquest opens Aurelia (D-422)");
        Check(GlobeMissions.FirstRealCity(all) == "", "with only the capital open there is no real city to launch");
    }

    // scenes/mission_panel.gd show_for and bonus_text; tests _check_panel_threat_line.
    static void Panel()
    {
        GDict save = NewSave();
        List<PanelLine> lines = GlobeMissions.PanelLines(save, Content.Continent("ostia_minor"));
        string[] want = { "OSTIA MINOR", "Young croc", "Threat +10% (to 10%)", "Stomps hit 15% harder", "10% more health", "Moves 10% faster" };
        string[] colours = { "HEADER", "MUTED", "THREAT", "TEXT", "TEXT", "TEXT" };
        Check(lines.Count == want.Length, $"Ostia's panel has {want.Length} lines: {lines.Count}");
        for (int i = 0; i < Math.Min(lines.Count, want.Length); i++)
        {
            Check(lines[i].text == want[i] && lines[i].colour == colours[i], $"panel line {i} is '{want[i]}' in {colours[i]}: '{lines[i].text}' in {lines[i].colour}");
        }
        Check(Math.Abs(lines[2].threat - 10.0) < EPS, $"the Threat line is tinted for the level after: {lines[2].threat}");
        GDict one = Campaign.Conquer(save, Content.Continent("ostia_minor"), "");
        lines = GlobeMissions.PanelLines(one, Content.Continent("carthago"));
        Check(lines[2].text == "Threat +12% (to 22%)", $"after one win Carthago reads 'Threat +12% (to 22%)': '{lines[2].text}'");
        Check(lines[1].text == "Behemoth", $"Carthago is a Behemoth city: '{lines[1].text}'");
        Check(lines.Count == 6 && lines[3].text == "Bonus to be designed", $"a bonus with no scale says so: '{lines[3].text}'");
        lines = GlobeMissions.PanelLines(one, Content.Continent("aurelia"));
        Check(lines.Count == 3 && lines[0].text == "AURELIA" && lines[1].text == "Colossus", "the capital's panel has no bonus lines");
        GDict two = new GDict { { "id", "x" }, { "scale", new GDict { { "hp", 0.25 }, { "nothing", 0.5 }, { "speed", 0.125 } } } };
        Check(GlobeMissions.BonusText(two) == "25% more health, Moves 13% faster", $"bonus_text joins its stats with ', ', skips a stat with no phrase and rounds half up: '{GlobeMissions.BonusText(two)}'");
    }

    // scenes/threat_readout.gd show_level and colour_for on tuning ui.threat_readout.ramp.
    static void Threat()
    {
        Check(GlobeMissions.ThreatText(0.0) == "0%" && GlobeMissions.ThreatText(22.9) == "22%", "the value is a whole percent, truncated");
        Check(GlobeMissions.ThreatText(Campaign.THREAT_CAP + 0.5) == "99%", "99.5 reads 99%, never 100 with Aurelia locked");
        Check(GlobeMissions.ThreatCapText() == "/ 100%", $"the cap reads '/ 100%': '{GlobeMissions.ThreatCapText()}'");
        ThreatTint t = GlobeMissions.ThreatColour(0.0);
        Check(t.from == "GOOD" && t.to == "GOOD", $"0 is the first stop: {t.from}");
        t = GlobeMissions.ThreatColour(-5.0);
        Check(t.from == "GOOD" && t.to == "GOOD", "under the first stop clamps to it");
        t = GlobeMissions.ThreatColour(15.0);
        Check(t.from == "GOOD" && t.to == "WARN" && Math.Abs(t.t - 0.5) < EPS, $"15 is half way GOOD to WARN: {t.from} {t.to} {t.t}");
        t = GlobeMissions.ThreatColour(30.0);
        Check(t.from == "WARN" && t.to == "ORANGE" && Math.Abs(t.t) < EPS, $"30 is WARN exactly: {t.from} {t.to} {t.t}");
        t = GlobeMissions.ThreatColour(77.5);
        Check(t.from == "ORANGE" && t.to == "ALERT" && Math.Abs(t.t - 0.5) < EPS, $"77.5 is half way ORANGE to ALERT: {t.from} {t.to} {t.t}");
        ThreatTint cap = GlobeMissions.ThreatColour(Campaign.THREAT_CAP), full = GlobeMissions.ThreatColour(Campaign.THREAT_FULL), over = GlobeMissions.ThreatColour(140.0);
        Check(full.from == "ALERT" && full.to == "ALERT" && over.to == "ALERT", "100 and beyond are the last stop");
        Check(cap.to == "ALERT" && cap.t > 0.97, $"99 is all but the last stop: {cap.t}");
    }

    // scenes/globe_missions.gd _launch, _city_over, _back_to_globe, _won, _lost and stub_mission.gd.
    static void Missions()
    {
        GDict save = NewSave();
        save["rubble"] = 321L;
        save["runs"] = 1L;
        GDict ostia = Content.Continent("ostia_minor");
        Check(GlobeMissions.StartsCity(ostia) && GlobeMissions.StartsCity(Content.Continent("carthago")) && GlobeMissions.StartsCity(Content.Continent("thule")), "LAUNCH starts a real city on Ostia Minor, Carthago and Thule (D-454)");
        Check(!GlobeMissions.StartsCity(Content.Continent("silvania")) && !GlobeMissions.StartsCity(Content.Continent("aurelia")), "the others open the stand-in mission");

        GDict result = new GDict { { "reason", "time" }, { "rubble", 321L } };
        MissionOutcome none = GlobeMissions.AfterRun(save, RunStart.Prepare(save, null), result);
        Check(!none.pending && !none.won && !none.lost && none.id == "", "a rampage with no continent owes no mission");
        RunRequest endless = RunStart.Prepare(save, ostia, "", "", true);
        Check(!GlobeMissions.AfterRun(save, endless, result).pending, "Endless owes no mission");
        Check(!GlobeMissions.AfterRun(save, null, result).pending, "no request owes no mission");

        RunRequest request = RunStart.Prepare(save, ostia);
        MissionOutcome pending = GlobeMissions.AfterRun(save, request, result);
        Check(pending.pending && !pending.won && !pending.lost && pending.id == "ostia_minor", $"a city rampage owes its WIN / LOSE choice: pending {pending.pending}, id {pending.id}");
        Check(pending.line == "The rampage is over", $"its line is 'The rampage is over': '{pending.line}'");
        Check(GlobeMissions.Offered(pending).Size() == 3, $"WIN offers Ostia's three bonuses: {GlobeMissions.Offered(pending).Size()}");
        // The result does not decide it (Godot has no win rule yet): a zero-biomass run owes the same choice.
        MissionOutcome poor = GlobeMissions.AfterRun(save, request, new GDict { { "reason", "dead" }, { "rubble", 0L } });
        Check(poor.pending && poor.id == "ostia_minor", "the run's result does not decide the mission: the player does");

        MissionOutcome lost = GlobeMissions.Lose(pending);
        Check(lost.lost && !lost.won && !lost.pending && lost.bonusId == "", "LOSE ends it lost");
        Check(ReferenceEquals(lost.save, save) && Arr(save["conquered"]).Size() == 0 && Num.F(save["threat"]) == 0.0, "LOSE changes nothing in the save");

        MissionOutcome won = GlobeMissions.Win(pending, "bonus_ostia_minor_2");
        Check(won.won && !won.lost && !won.pending && won.bonusId == "bonus_ostia_minor_2", "WIN with a bonus ends it won, the bonus kept");
        Check(Arr(won.save["conquered"]).Has("ostia_minor"), "the won save lists Ostia Minor conquered (Campaign.conquer)");
        GDict kept = won.save["bonuses"];
        Check(Gd.Str(kept.Get("ostia_minor", "")) == "bonus_ostia_minor_2", $"the kept bonus is stored under the continent: {Gd.Str(kept.Get("ostia_minor", ""))}");
        Check(Math.Abs(won.threat - 10.0) < EPS, $"Threat rises by Ostia's share to 10: {won.threat}");
        Check(Num.I(won.save["rubble"]) == 321L && Num.I(won.save["runs"]) == 1L, "a win leaves biomass and runs alone");
        Check(Arr(save["conquered"]).Size() == 0, "the save handed in is left as it was");
        Check(!won.demoDone, "the globe never ends the demo (main.gd _on_bought does)");
        Check(GlobeMissions.StateOf(GlobeMissions.States(won.save), "ostia_minor") == Campaign.State.CONQUERED, "the globe shows it conquered");

        // A stand-in mission from LAUNCH, and the capital: WIN conquers at once with no bonus (D-422).
        GDict all = save;
        foreach (GDict def in Content.Continents()) if (def.Get("capital", false) != true) all = Campaign.Conquer(all, def, "");
        MissionOutcome capital = GlobeMissions.StandIn(all, Content.Continent("aurelia"));
        Check(capital.pending && capital.line == "Stand-in mission: the city comes later", $"a stand-in mission's line: '{capital.line}'");
        Check(GlobeMissions.Offered(capital).Size() == 0, "the capital offers no bonus");
        MissionOutcome end = GlobeMissions.Win(capital, "");
        Check(end.won && Arr(end.save["conquered"]).Has("aurelia") && Math.Abs(end.threat - Campaign.THREAT_FULL) < EPS, $"the capital falls, Threat stays {Campaign.THREAT_FULL}: {end.threat}");
    }

    // An 8-bit greyscale PNG's bytes, row 0 at the top (the mask's format); null when it is anything else.
    static byte[] Png(string file, out int w, out int h)
    {
        w = h = 0;
        if (!File.Exists(file)) return null;
        byte[] d = File.ReadAllBytes(file);
        MemoryStream idat = new MemoryStream();
        int at = 8, type = -1, depth = 0;
        while (at + 8 <= d.Length)
        {
            int len = (d[at] << 24) | (d[at + 1] << 16) | (d[at + 2] << 8) | d[at + 3];
            string kind = System.Text.Encoding.ASCII.GetString(d, at + 4, 4);
            if (kind == "IHDR")
            {
                w = (d[at + 8] << 24) | (d[at + 9] << 16) | (d[at + 10] << 8) | d[at + 11];
                h = (d[at + 12] << 24) | (d[at + 13] << 16) | (d[at + 14] << 8) | d[at + 15];
                depth = d[at + 16];
                type = d[at + 17];
                if (d[at + 20] != 0) return null;  // interlaced
            }
            else if (kind == "IDAT") idat.Write(d, at + 8, len);
            at += 12 + len;
        }
        if (type != 0 || depth != 8) return null;
        idat.Position = 0;
        byte[] raw = new byte[(w + 1) * h];
        using (ZLibStream z = new ZLibStream(idat, CompressionMode.Decompress))
        {
            int got = 0;
            while (got < raw.Length)
            {
                int n = z.Read(raw, got, raw.Length - got);
                if (n <= 0) return null;
                got += n;
            }
        }
        byte[] px = new byte[w * h];
        for (int y = 0; y < h; y++)
        {
            int filter = raw[y * (w + 1)];
            for (int x = 0; x < w; x++)
            {
                int v = raw[y * (w + 1) + 1 + x];
                int a = x > 0 ? px[y * w + x - 1] : 0, b = y > 0 ? px[(y - 1) * w + x] : 0, c = x > 0 && y > 0 ? px[(y - 1) * w + x - 1] : 0;
                if (filter == 1) v += a;
                else if (filter == 2) v += b;
                else if (filter == 3) v += (a + b) / 2;
                else if (filter == 4)
                {
                    int p = a + b - c, pa = Math.Abs(p - a), pb = Math.Abs(p - b), pc = Math.Abs(p - c);
                    v += pa <= pb && pa <= pc ? a : (pb <= pc ? b : c);
                }
                px[y * w + x] = (byte)v;
            }
        }
        return px;
    }
}
