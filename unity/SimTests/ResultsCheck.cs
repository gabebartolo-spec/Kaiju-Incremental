// The results report as plain C# (GameLogic/ResultsRows.cs) against scenes/results_screen.gd and the cases of
// tests/run_results_tests.gd: rows in Godot's order, formatting, bests, NEW RECORD rows, verdicts, headlines,
// the crawl, the count's frame maths and the end beat's words and timing.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using Kaiju.Sim;

public static class ResultsCheck
{
    static int checks, failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL results: " + what);
    }

    // tests/run_results_tests.gd SAMPLE.
    static GDict Sample()
    {
        return new GDict
        {
            { "rubble", 420L }, { "destruction", 0.37 }, { "toppled", 6L }, { "tallest_topple", 14L },
            { "landmarks", 2L }, { "civilians", 88L }, { "tanks", 5L }, { "helis", 1L }, { "agents", 3L },
            { "reason", "time" },
        };
    }

    static ResultsRow Row(ResultsModel m, string key) => m.rows.Find(r => r.key == key);

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        FileAccess.Root = repoRoot;
        Tr.Language = "en";

        // Rows, groups and order.
        ResultsModel first = ResultsRows.Build(Sample(), new GDict());
        string order = string.Join(",", first.rows.ConvertAll(r => r.key));
        Check(order == "rubble,best_combo,toppled,tallest_topple,destruction,landmarks,civilians,tanks,helis,agents,mechs",
            "rows in Godot's order: " + order);
        Check(first.rows.Count == 11 && first.groups.Count == 3, "11 rows in 3 groups");
        Check(first.groups[0].heading == "BIOMASS" && first.groups[0].perLine == 2 && first.groups[0].rows.Count == 2,
            "biomass group: 2 rows, 2 a line");
        Check(first.groups[1].heading == "DESTRUCTION" && first.groups[1].rows.Count == 4, "destruction group: 4 rows");
        Check(first.groups[2].heading == "BODY COUNT" && first.groups[2].rows.Count == 5, "body count group: 5 rows");
        Check(Row(first, "rubble").label == "Biomass earned" && Row(first, "civilians").label == "People eaten",
            "row labels");

        // Formatting.
        Check(Row(first, "rubble").Shown(420.9) == "420", "int floors: " + Row(first, "rubble").Shown(420.9));
        Check(Row(first, "destruction").Shown(0.37) == "37%", "pct: " + Row(first, "destruction").Shown(0.37));
        Check(Row(first, "tallest_topple").Shown(14) == "14 STOREYS", "storeys: " + Row(first, "tallest_topple").Shown(14));
        Check(Row(first, "tallest_topple").Shown(1.5) == "1 STOREY", "one storey: " + Row(first, "tallest_topple").Shown(1.5));
        Check(Row(first, "best_combo").Shown(1.8) == ResultsRows.NO_VALUE, "an unreported combo shows a dash");
        Check(Row(first, "mechs").Shown(0) == ResultsRows.NO_VALUE, "an unreported stat shows a dash");

        // First rampage: no bests, no records.
        Check(first.first && first.verdict == "YOUR FIRST RAMPAGE", "first rampage verdict: " + first.verdict);
        Check(first.records.Count == 0 && first.rows.TrueForAll(r => r.bestText == "" && !r.newBest),
            "a first rampage has no bests and no records");
        Check(first.headline == "FINAL STRIKE FELLS KAIJU", "headed by its ending: " + first.headline);

        // Record stamps (_check_record_stamps).
        GDict best = new GDict { { "rubble", 500.0 }, { "landmarks", 1.0 }, { "agents", 5.0 }, { "toppled", 6.0 } };
        ResultsModel m = ResultsRows.Build(Sample(), best);
        Check(m.records.Contains("landmarks") && !m.records.Contains("agents") && !m.records.Contains("toppled"),
            "landmarks beat their best, agents and a tie did not: " + string.Join(",", m.records));
        Check(Row(m, "agents").bestText == "best 5" && Row(m, "toppled").bestText == "best 6",
            "missed and tied rows show their best");
        Check(Row(m, "rubble").bestText == "" && !Row(m, "rubble").stamp, "the verdict's row has no best and no stamp");
        Check(Row(m, "destruction").bestText == "best 0%" && Row(m, "destruction").stamp,
            "a best the save lacks reads as 0: " + Row(m, "destruction").bestText);
        Check(Row(m, "tallest_topple").bestText == "best 0 STOREYS", "storeys best: " + Row(m, "tallest_topple").bestText);
        Check(m.verdict == "80 SHORT OF YOUR BEST BIOMASS, BUT NEW RECORDS", "short but records: " + m.verdict);

        // Verdicts.
        GDict worse = Sample();
        ResultsModel shortOf = ResultsRows.Build(worse, new GDict
        {
            { "rubble", 500.5 }, { "destruction", 0.9 }, { "toppled", 9L }, { "tallest_topple", 20L },
            { "landmarks", 3L }, { "civilians", 99L }, { "tanks", 9L }, { "helis", 9L }, { "agents", 9L },
        });
        Check(shortOf.verdict == "81 BIOMASS SHORT OF YOUR BEST" && shortOf.records.Count == 0,
            "short of the best, rounded up: " + shortOf.verdict);
        Check(ResultsRows.Build(Sample(), new GDict { { "rubble", 400.0 } }).verdict == "BIGGER THAN LAST TIME  +5% BIOMASS",
            "bigger by a share: " + ResultsRows.Build(Sample(), new GDict { { "rubble", 400.0 } }).verdict);
        Check(ResultsRows.Build(Sample(), new GDict { { "rubble", 0L } }).verdict == "BIGGER THAN EVER", "bigger than a zero best");
        ResultsModel beat = ResultsRows.Build(Sample(), new GDict { { "rubble", 400.0 } });
        Check(Row(beat, "rubble").newBest && !Row(beat, "rubble").stamp && !beat.records.Contains("rubble"),
            "a biomass record turns green but takes no stamp");

        // Best combo (_check_combo_hook).
        GDict comboBest = new GDict { { "rubble", 1.0 }, { "best_combo", 1.2 } };
        ResultsModel bare = ResultsRows.Build(Sample(), comboBest);
        GDict fedResult = Sample();
        fedResult["best_combo"] = 1.8;
        ResultsModel fed = ResultsRows.Build(fedResult, comboBest);
        Check(bare.ShownAt(1, bare.TotalFrames) == "-" && Row(bare, "best_combo").bestText == "" && !bare.records.Contains("best_combo"),
            "with no combo fed the row shows a dash, no best, no stamp");
        Check(fed.ShownAt(1, fed.TotalFrames) == "x1.8" && Row(fed, "best_combo").stamp && Row(fed, "best_combo").bestText == "best x1.2",
            "a fed combo shows as a multiplier and can set a record: " + fed.ShownAt(1, fed.TotalFrames));

        // Headlines and crawl (_check_headlines).
        HashSet<string> seen = new HashSet<string>();
        foreach (string reason in new[] { "city_fallen", "time", "defeated", "ended" })
        {
            string line = ResultsRows.Headline(reason);
            Check(line != ResultsRows.DEFAULT_HEADLINE && seen.Add(line), "ending '" + reason + "' has its own headline: " + line);
            List<string> crawl = ResultsRows.News(new GDict { { "reason", reason } });
            string close = crawl[crawl.Count - 1];
            Check(close.Contains("REMAINS") == (reason != "city_fallen"), "ending '" + reason + "' closes the crawl: " + close);
        }
        Check(ResultsRows.Headline("") == ResultsRows.DEFAULT_HEADLINE, "no reason gets the plain report title");
        string news = string.Join(" | ", m.news);
        Check(news == "DOWNTOWN LIES IN RUINS | 14-FLOOR TOWER COMES DOWN - SKYLINE CHANGED FOREVER | "
            + "INSURERS REFUSE CLAIMS: 'ACT OF MONSTER' | MASS EVACUATION ORDERED | GENERALS DEMAND BIGGER TANKS | "
            + "TOURISTS TOLD: 'THE LANDMARKS ARE CLOSED' | TASKFORCE RECRUITING - NO EXPERIENCE NEEDED | "
            + "SCIENTISTS RUSH TO STUDY THE REMAINS", "the crawl: one line a stat, first reached, then the close: " + news);

        // The count.
        Check(m.TotalFrames == 374 && Math.Abs(m.TotalSeconds - 374.0 / 60.0) < 1e-9, "the count takes 374 frames: " + m.TotalFrames);
        Check(m.Counting(373.9) && !m.Counting(374), "counting until the last frame");
        Check(m.ShownAt(0, 0) == "0" && m.ShownAt(0, 26) == "420" && m.Landed(0, 26) && !m.Landed(0, 25.9), "row 0 lands at frame 26");
        Check(m.RowT(1, 34) == 0.0 && Math.Abs(m.RowT(1, 47) - 0.5) < 1e-9 && m.Landed(1, 60), "row 1 starts at 34, lands at 60");
        Check(!m.Landed(10, 365.9) && m.Landed(10, 366), "the last row lands at frame 366");
        // Godot ease(0.5, 0.4) = 1 - 0.5^2.5.
        Check(Math.Abs(ResultsRows.Ease(0.5, 0.4) - (1.0 - Math.Pow(0.5, 2.5))) < 1e-12 && ResultsRows.Ease(0, 0.4) == 0.0
            && ResultsRows.Ease(1, 0.4) == 1.0, "ease out, as Godot's ease(x, 0.4)");
        Check(m.ShownAt(0, 13) == Gd.Str(Gd.Floori(420.0 * (1.0 - Math.Pow(0.5, 2.5)))), "half way row 0 shows " + m.ShownAt(0, 13));
        bool rising = true;
        for (int f = 1; f <= 26; f++) rising &= long.Parse(m.ShownAt(0, f)) >= long.Parse(m.ShownAt(0, f - 1));
        Check(rising, "the count never steps back");

        // From the save before and after the bank.
        GDict before = new GDict { { "runs", 0L }, { "rubble", 0L }, { "best", new GDict { { "rubble", 0L } } } };
        GDict after = new GDict { { "runs", 1L }, { "rubble", 420L }, { "best", new GDict { { "rubble", 420L } } } };
        ResultsModel fromSave = ResultsRows.Build(Sample(), before, after);
        Check(fromSave.first && fromSave.banked == 420 && fromSave.verdict == "YOUR FIRST RAMPAGE", "a save with no rampage is a first rampage");
        GDict later = new GDict { { "runs", 3L }, { "rubble", 900L }, { "best", new GDict { { "rubble", 400L }, { "agents", 5L } } } };
        ResultsModel second = ResultsRows.Build(Sample(), later, new GDict { { "rubble", 1320L } });
        Check(!second.first && second.banked == 1320 && Row(second, "agents").bestText == "best 5"
            && second.verdict == "BIGGER THAN LAST TIME  +5% BIOMASS", "a later rampage reads the save's best: " + second.verdict);
        Check(ResultsRows.Build(null, null).rows.Count == 11, "an empty result still lists every row");

        // The end beat.
        Check(ResultsBeat.Lines("defeated")[0] == "BROUGHT DOWN" && ResultsBeat.Lines("defeated")[1] == "The army got you this time", "beat: defeated");
        Check(ResultsBeat.Lines("time")[0] == "AIRSTRIKE" && ResultsBeat.Lines("time")[1] == "The army ran out of patience", "beat: time");
        Check(ResultsBeat.Lines("city_fallen")[0] == "THE CITY HAS FALLEN" && ResultsBeat.Lines("city_fallen")[1] == "Nothing left standing", "beat: city fallen");
        Check(ResultsBeat.Lines("ended")[0] == "RAMPAGE ENDED" && ResultsBeat.Lines("ended")[1] == "You called it off", "beat: ended");
        Check(ResultsBeat.Lines("")[0] == "RAMPAGE OVER" && ResultsBeat.Lines(null)[1] == "", "beat: fallback");
        Check(Math.Abs(ResultsBeat.Seconds - 2.5) < 1e-9 && Math.Abs(ResultsBeat.MinSeconds - 40.0 / 60.0) < 1e-9, "beat: 2.5 s, skippable after 0.667 s");
        Check(ResultsBeat.BackOut(0) < 1e-9 && Math.Abs(ResultsBeat.BackOut(1) - 1.0) < 1e-9 && ResultsBeat.BackOut(0.7) > 1.0, "beat: back-out overshoots then lands");

        Console.WriteLine("results: " + checks + " checks, " + failed + " failed");
        return failed;
    }
}
