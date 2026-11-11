// What the results screen says (scenes/results_screen.gd, without the drawing): the rows in Godot's order with
// Godot's formatting, each against the best rampage before this one, the headline by how it ended, the verdict
// line, the NEW RECORD rows, the news crawl's lines and the count-up's frame maths. Reads the result; decides
// nothing. The view (Game/Screens/ResultsScreen.cs) only draws what this built.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    // One line of the report.
    public sealed class ResultsRow
    {
        // Stat key, its label in the player's language, how the value is shown and its group id.
        public string key, label, kind, group;
        // False when the run did not report the stat: it shows NO_VALUE and never a best.
        public bool reported;
        // The value the count lands on, and the best before this rampage.
        public double target, best;
        // "best 12", or "" (first rampage, the verdict's own row, a stat not reported).
        public string bestText = "";
        // Beat the best before it (the value turns green), and carries the NEW RECORD stamp (never the verdict's row).
        public bool newBest, stamp;

        // The row's text at `value` (results_screen.gd _shown).
        public string Shown(double value)
        {
            if (!reported) return ResultsRows.NO_VALUE;
            switch (kind)
            {
                case "pct": return Tr.Format("%d%%", Gd.Floori(value * 100.0));
                case "storeys": return Gd.Floori(value) != 1 ? Tr.F("%d STOREYS", Gd.Floori(value)) : Tr.T("1 STOREY");
                case "combo": return Tr.Format("x%.1f", value);
            }
            return Tr.Format("%d", Gd.Floori(value));
        }
    }

    // A group of rows: its id, its heading in the player's language, rows per line, and the rows' indexes.
    public sealed class ResultsGroup
    {
        public string id, heading;
        public int perLine;
        public List<int> rows = new List<int>();
    }

    // The whole report.
    public sealed class ResultsModel
    {
        public string reason = "", headline = "", verdict = "";
        public List<ResultsRow> rows = new List<ResultsRow>();
        public List<ResultsGroup> groups = new List<ResultsGroup>();
        // The rows that carry a NEW RECORD stamp once the count is done.
        public List<string> records = new List<string>();
        // The news crawl under the report.
        public List<string> news = new List<string>();
        // True on a first rampage: no bests, no records.
        public bool first;
        // The save's biomass after the bank (-1 when no save was given): for the proof line, not shown.
        public long banked = -1;

        // Frames (at 60 a second) until every row has counted up.
        public int TotalFrames => rows.Count * (ResultsRows.COUNT_FRAMES + ResultsRows.ROW_GAP_FRAMES);
        public double TotalSeconds => TotalFrames / ResultsRows.FRAME_RATE;

        public bool Counting(double frame) => frame < TotalFrames;

        // How far row `n` has counted at `frame`, 0..1 (results_screen.gd _show_frame).
        public double RowT(int n, double frame)
        {
            double from = n * (ResultsRows.COUNT_FRAMES + ResultsRows.ROW_GAP_FRAMES);
            return Gd.Clampf((frame - from) / ResultsRows.COUNT_FRAMES, 0.0, 1.0);
        }

        // A landed row shows its best badge, its record colour and its stamp.
        public bool Landed(int n, double frame) => RowT(n, frame) >= 1.0;

        public string ShownAt(int n, double frame)
        {
            ResultsRow row = rows[n];
            return row.Shown(row.target * ResultsRows.Ease(RowT(n, frame), ResultsRows.COUNT_EASE));
        }
    }

    public static class ResultsRows
    {
        // Stat key, label, how the value is shown ("int", "pct", "storeys" or "combo") and its group.
        public static readonly string[][] ROWS =
        {
            new[] { "rubble", "Biomass earned", "int", "biomass" },
            new[] { "best_combo", "Best combo", "combo", "biomass" },
            new[] { "toppled", "Towers toppled", "int", "destruction" },
            new[] { "tallest_topple", "Tallest tower toppled", "storeys", "destruction" },
            new[] { "destruction", "City destroyed", "pct", "destruction" },
            new[] { "landmarks", "Landmarks felled", "int", "destruction" },
            new[] { "civilians", "People eaten", "int", "body" },
            new[] { "tanks", "Tanks", "int", "body" },
            new[] { "helis", "Helicopters", "int", "body" },
            new[] { "agents", "Agents", "int", "body" },
            new[] { "mechs", "Mechs", "int", "body" },
        };
        // Group id, heading, rows per line: biomass across the top, then the tally beside the body count.
        public static readonly string[][] GROUPS =
        {
            new[] { "biomass", "BIOMASS", "2" },
            new[] { "destruction", "DESTRUCTION", "1" },
            new[] { "body", "BODY COUNT", "1" },
        };
        // What a stat the run did not report shows (best combo until the combo system feeds it).
        public const string NO_VALUE = "-";
        // The headline when the end reason has no row in tuning "results" "endings".
        public const string DEFAULT_HEADLINE = "RAMPAGE REPORT";
        public const string STAMP_TEXT = "NEW RECORD";
        // Frames each line takes to count up, the gap before the next starts, and the count's ease (Godot ease()).
        public const int COUNT_FRAMES = 26;
        public const int ROW_GAP_FRAMES = 8;
        public const double COUNT_EASE = 0.4;
        // Godot paced the count by frames at this rate; Unity turns frames into seconds with it.
        public const double FRAME_RATE = 60.0;
        // The stat the verdict under the title compares with the best (its row shows no best badge).
        public const string VERDICT_STAT = "rubble";
        // The button's text once the count is done, unless the caller names another ("BACK  >").
        public const string GO_LABEL = "EVOLVE  >";
        public const string SKIP_LABEL = "SKIP";

        // previousBest: the save's best record before this rampage ({} on a first rampage): what SaveFile.Bank returns.
        public static ResultsModel Build(GDict result, GDict previousBest)
        {
            result = result ?? new GDict();
            previousBest = previousBest ?? new GDict();
            ResultsModel m = new ResultsModel();
            m.reason = Gd.Str(result.Get("reason", ""));
            m.headline = Tr.T(Headline(m.reason));
            m.first = previousBest.IsEmpty();
            foreach (string[] g in GROUPS)
            {
                m.groups.Add(new ResultsGroup { id = g[0], heading = Tr.T(g[1]), perLine = int.Parse(g[2]) });
            }
            foreach (string[] def in ROWS)
            {
                ResultsRow row = new ResultsRow { key = def[0], label = Tr.T(def[1]), kind = def[2], group = def[3] };
                row.reported = result.Has(row.key);
                row.target = Num.F(result.Get(row.key, 0.0));
                row.best = Num.F(previousBest.Get(row.key, 0.0));
                row.newBest = IsNewBest(result, previousBest, row.key);
                row.stamp = row.newBest && row.key != VERDICT_STAT;
                // The verdict under the title already compares its row with the best: say it once.
                if (!m.first && row.key != VERDICT_STAT && row.reported) row.bestText = Tr.F("best %s", row.Shown(row.best));
                if (row.stamp) m.records.Add(row.key);
                m.groups.Find(g => g.id == row.group).rows.Add(m.rows.Count);
                m.rows.Add(row);
            }
            m.verdict = Verdict(result, previousBest);
            m.news = News(result);
            return m;
        }

        // The same from the save as it was before the bank and after it.
        public static ResultsModel Build(GDict result, GDict saveBefore, GDict saveAfter)
        {
            ResultsModel m = Build(result, PreviousBest(saveBefore));
            if (saveAfter != null) m.banked = Num.I(saveAfter.Get("rubble", 0L));
            return m;
        }

        // The best record a save held before a bank: {} when it has no rampage yet (save_file.gd bank).
        public static GDict PreviousBest(GDict saveBefore)
        {
            if (saveBefore == null || Num.I(saveBefore.Get("runs", 0L)) == 0) return new GDict();
            return saveBefore.Get("best", default(Variant)).Obj as GDict ?? new GDict();
        }

        // The headline (English, a text key) for a rampage that ended for `reason` (the sim's end reason).
        public static string Headline(string reason)
        {
            GDict ending = Ending(reason);
            return Gd.Str(ending.Get("headline", DEFAULT_HEADLINE));
        }

        static GDict Ending(string reason)
        {
            GDict endings = Content.Section("results")["endings"].Obj as GDict ?? new GDict();
            return endings.Get(reason ?? "", default(Variant)).Obj as GDict ?? new GDict();
        }

        // The evening news about this rampage, for the crawl under the report: per stat, the first tuning
        // "news.report" line whose "min" the rampage reached ("{n}" is the stat's value), closed by the ending's own.
        public static List<string> News(GDict r)
        {
            List<string> lines = new List<string>();
            HashSet<string> done = new HashSet<string>();
            GDict cfg = Content.Section("news");
            if (cfg.Get("report", default(Variant)).Obj is GArray<Variant> report)
            {
                foreach (Variant item in report)
                {
                    GDict entry = item.Obj as GDict;
                    if (entry == null) continue;
                    string stat = Gd.Str(entry["stat"]);
                    double value = Num.F(r.Get(stat, 0L));
                    if (done.Contains(stat) || value < Num.F(entry["min"])) continue;
                    done.Add(stat);
                    lines.Add(Tr.T(Gd.Str(entry["line"])).Replace("{n}", Gd.Str(Gd.Floori(value))));
                }
            }
            GDict ending = Ending(Gd.Str(r.Get("reason", "")));
            if (ending.Has("close")) lines.Add(Tr.T(Gd.Str(ending["close"])));
            return lines;
        }

        // The line under the title: did this rampage beat the best before it, on biomass?
        public static string Verdict(GDict result, GDict previousBest)
        {
            double rubble = Num.F(result.Get(VERDICT_STAT, 0L));
            if (previousBest.IsEmpty()) return Tr.T("YOUR FIRST RAMPAGE");
            double best = Num.F(previousBest.Get(VERDICT_STAT, 0.0));
            if (rubble > best)
            {
                if (best <= 0.0) return Tr.T("BIGGER THAN EVER");
                long more = Gd.Roundi(100.0 * (rubble - best) / best);
                return Tr.F("BIGGER THAN LAST TIME  +%d%% BIOMASS", more);
            }
            // A record on another row beside "short of your best" would read as a contradiction.
            foreach (string[] row in ROWS)
            {
                if (row[0] != VERDICT_STAT && IsNewBest(result, previousBest, row[0]))
                    return Tr.F("%d SHORT OF YOUR BEST BIOMASS, BUT NEW RECORDS", Gd.Ceili(best - rubble));
            }
            return Tr.F("%d BIOMASS SHORT OF YOUR BEST", Gd.Ceili(best - rubble));
        }

        // True when this rampage beat the best before it on `key` (never on a first rampage, never on a stat the
        // run did not report).
        public static bool IsNewBest(GDict result, GDict previousBest, string key)
        {
            if (previousBest.IsEmpty() || !result.Has(key)) return false;
            return Num.F(result[key]) > Num.F(previousBest.Get(key, 0.0));
        }

        // Godot's ease(x, curve) for the curves the game uses (curve > 0).
        public static double Ease(double x, double curve)
        {
            x = Gd.Clampf(x, 0.0, 1.0);
            if (curve <= 0.0) return 0.0;
            return curve < 1.0 ? 1.0 - Math.Pow(1.0 - x, 1.0 / curve) : Math.Pow(x, curve);
        }
    }

    // The end beat's words (scenes/rampage_hud.gd HEADLINES) and timing (frames at 60 a second).
    public static class ResultsBeat
    {
        public const int BEAT_FRAMES = 150;
        public const int BEAT_MIN_FRAMES = 40;
        public const string FALLBACK = "RAMPAGE OVER";

        // Reason: headline, line under it (English, text keys).
        static readonly Dictionary<string, string[]> HEADLINES = new Dictionary<string, string[]>
        {
            { "defeated", new[] { "BROUGHT DOWN", "The army got you this time" } },
            { "time", new[] { "AIRSTRIKE", "The army ran out of patience" } },
            { "city_fallen", new[] { "THE CITY HAS FALLEN", "Nothing left standing" } },
            { "ended", new[] { "RAMPAGE ENDED", "You called it off" } },
        };

        public static double Seconds => BEAT_FRAMES / ResultsRows.FRAME_RATE;
        public static double MinSeconds => BEAT_MIN_FRAMES / ResultsRows.FRAME_RATE;

        // The headline and the line under it, in the player's language.
        public static string[] Lines(string reason)
        {
            string[] lines = HEADLINES.TryGetValue(reason ?? "", out string[] found) ? found : new[] { FALLBACK, "" };
            return new[] { Tr.T(lines[0]), Tr.T(lines[1]) };
        }

        // Godot's Tween TRANS_BACK, EASE_OUT: 0 at t = 0, past 1, back to 1 at t = 1.
        public static double BackOut(double t)
        {
            const double s = 1.70158;
            t = Gd.Clampf(t, 0.0, 1.0) - 1.0;
            return t * t * ((s + 1.0) * t + s) + 1.0;
        }
    }
}
