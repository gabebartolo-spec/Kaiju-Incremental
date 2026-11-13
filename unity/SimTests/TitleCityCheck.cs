// The title's burning city (GameLogic/TitleCity.cs, TitleClock.cs) against a headless Godot run of the real
// scripts (tools/unity/dump_title_city_golden.gd -> golden/title_city.txt): on Godot's own stand-in towers the
// fires, burning panes, lamps, sky smoke, sand and two minutes of shots, booms, stomps, flashes and colossus
// reveals come out line for line as Godot's.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using Kaiju.Game;
using S = Kaiju.Sim;

static class TitleCityCheck
{
    // The dump's run: 60 steps a second for two minutes, the city standing from step 90.
    const double DT = 1.0 / 60.0;
    const int STEPS = 7200, LOADED = 90;
    const double NEAR = 1e-3;

    // Every line as Godot's; prints the first few that differ.
    public static bool Godot()
    {
        string[] gold = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "title_city.txt"));
        S.GDict title = S.Content.Section("title");
        double farZ = Number(gold.First(l => l.StartsWith("FAR_Z ")).Split(' ')[1]);
        List<string> ours = new List<string> { Inv($"FAR_Z {farZ:0.0000}") };
        List<TitleCity.Stand> stands = Stands(gold, ours);
        Fires(title, farZ, stands, ours);
        S.GDict shore = title["shore"];
        foreach (S.Vector2 lamp in TitleCity.Lamps(shore, S.Num.F(shore["half_span"]))) ours.Add(Inv($"LAMP {lamp.x:0.0000} {lamp.y:0.0000}"));
        foreach (TitleCity.Puff p in TitleCity.Smoke(title["sky_smoke"]))
            ours.Add(Inv($"SMOKE {p.layer} {p.size:0.0000} {p.at.x:0.0000} {p.at.y:0.0000} {p.at.z:0.0000}"));
        double[] beach = TitleCity.BeachPhases();
        ours.Add(Inv($"BEACH {beach[0]:0.000000} {beach[1]:0.000000}"));
        Clock(title, farZ, ours);
        int same = 0, shown = 0;
        for (int i = 0; i < Math.Min(ours.Count, gold.Length); i++)
        {
            if (Match(ours[i], gold[i])) same++;
            else if (shown++ < 5) Console.WriteLine($"title city: line {i + 1} is '{ours[i]}', Godot's '{gold[i]}'");
        }
        Console.WriteLine($"title city: {same} of {gold.Length} lines as Godot's (ours {ours.Count})");
        return same == gold.Length && ours.Count == gold.Length;
    }

    static List<TitleCity.Stand> Stands(string[] gold, List<string> ours)
    {
        List<TitleCity.Stand> stands = new List<TitleCity.Stand>();
        foreach (string line in gold.Where(l => l.StartsWith("BOX ")))
        {
            double[] v = line.Split(' ').Skip(1).Select(Number).ToArray();
            stands.Add(new TitleCity.Stand { at = new S.Vector3(v[0], v[1], v[2]), size = new S.Vector3(v[3], v[4], v[5]) });
            ours.Add(line);
        }
        return stands;
    }

    // Tuning's foci (which light nothing today, D-377 moved the shore) and the same moved onto the front rows.
    static void Fires(S.GDict title, double farZ, List<TitleCity.Stand> stands, List<string> ours)
    {
        S.GDict fires = title["fires"];
        Light("real", fires, farZ, stands, ours);
        S.GDict probe = fires.Duplicate(true);
        double z = farZ - S.Num.F(probe["depth"]) * 0.5;
        S.GArray<S.Variant> foci = probe["foci"];
        for (int i = 0; i < foci.Size(); i++)
        {
            S.GArray<S.Variant> focus = foci[i];
            focus[1] = z;
        }
        ours.Add(Inv($"PROBE_Z {z:0.0000}"));
        Light("probe", probe, farZ, stands, ours);
    }

    static void Light(string tag, S.GDict cfg, double farZ, List<TitleCity.Stand> stands, List<string> ours)
    {
        TitleCity.District d = TitleCity.Light(cfg, farZ, stands);
        ours.Add("LIT " + tag + " " + string.Join(" ", d.lit.Select(x => x.ToString("0.0000", CultureInfo.InvariantCulture))));
        foreach (TitleCity.Fire f in d.fires)
            ours.Add(Inv($"F {tag} {f.at.x:0.0000} {f.at.y:0.0000} {f.at.z:0.0000} {f.seed:0.000000} {S.Num.F(f.spec["size"]):0.0000} {S.Num.F(f.spec["smoke_density"]):0.0000}"));
        Panes(tag, 0, d.windowPanes, ours);
        Panes(tag, 1, d.heroPanes, ours);
    }

    static void Panes(string tag, int group, List<TitleCity.Pane> panes, List<string> ours)
    {
        foreach (TitleCity.Pane p in panes)
            ours.Add(Inv($"P {tag} {group} {p.at.x:0.0000} {p.at.y:0.0000} {p.at.z:0.0000} {p.width:0.0000} {p.shade:0.0000}"));
    }

    static void Clock(S.GDict title, double farZ, List<string> ours)
    {
        TitleClock clock = new TitleClock(title, farZ, true);
        for (int s = 0; s < STEPS; s++)
        {
            if (s == LOADED) clock.Begin();
            clock.Step(DT);
            foreach (TitleClock.Event e in clock.events)
            {
                string kind = e.kind.ToString().ToLowerInvariant();
                ours.Add(e.kind == TitleClock.Kind.Boom ? $"A {s} boom 0 0" : Inv($"A {s} {kind} {e.pitch:0.000000} {e.db:0.000000}"));
                if (e.flash) ours.Add(Inv($"FLASH {s} {kind} {e.at.x:0.0000} {e.at.y:0.0000} {e.at.z:0.0000}"));
                if (e.reveal) ours.Add(Inv($"REVEAL {s} {e.revealWait:0.000000}"));
            }
        }
    }

    static double Number(string text) => double.Parse(text, NumberStyles.Float, CultureInfo.InvariantCulture);

    static string Inv(FormattableString s) => s.ToString(CultureInfo.InvariantCulture);

    static bool Match(string a, string b)
    {
        string[] x = a.TrimEnd().Split(' '), y = b.TrimEnd().Split(' ');
        if (x.Length != y.Length) return false;
        for (int i = 0; i < x.Length; i++)
        {
            bool nx = double.TryParse(x[i], NumberStyles.Float, CultureInfo.InvariantCulture, out double vx);
            bool ny = double.TryParse(y[i], NumberStyles.Float, CultureInfo.InvariantCulture, out double vy);
            if (nx && ny ? Math.Abs(vx - vy) > NEAR : x[i] != y[i]) return false;
        }
        return true;
    }
}
