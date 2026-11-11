// The loading screen's choices (GameLogic/LoadingCard.cs, after scenes/loading_overlay.gd) are plain C#, so
// they are held here: the stills are Godot's twelve and all on disk, a pick never repeats the last one and
// reaches every other, the headlines are tuning's, the header is in the text table, each load shows the next one,
// and the place is the continent's name.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using Kaiju.Game;
using S = Kaiju.Sim;

static class LoadingCheck
{
    static int checks, failed;

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        S.FileAccess.Root = repoRoot;
        Stills(repoRoot);
        Picks();
        News(repoRoot);
        Place();
        Console.WriteLine($"loading: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("loading: FAILED " + what);
    }

    // The list is the one in loading_overlay.gd, in its order, and every file is in assets/loading.
    static void Stills(string repoRoot)
    {
        string gd = File.ReadAllText(Path.Combine(repoRoot, "scenes", "loading_overlay.gd"));
        var godot = new List<string>();
        foreach (Match m in Regex.Matches(gd, "\"res://(assets/loading/[^\"]+)\"")) godot.Add(m.Groups[1].Value);
        Check(godot.Count == 12, $"Godot lists 12 stills, read {godot.Count}");
        Check(string.Join("|", godot) == string.Join("|", LoadingCard.STILLS), "the stills are Godot's, in its order");
        foreach (string path in LoadingCard.STILLS) Check(File.Exists(Path.Combine(repoRoot, path)), path + " is on disk");
    }

    static void Picks()
    {
        int n = LoadingCard.STILLS.Length;
        // The first load (no last): rolls 0..n-2 give 0..n-2, as Godot's randi() % (size - 1).
        for (int roll = 0; roll < n - 1; roll++) Check(LoadingCard.Pick(roll, -1, n) == roll, $"first pick, roll {roll}");
        for (int last = 0; last < n; last++)
        {
            var seen = new HashSet<int>();
            bool inRange = true;
            for (int roll = 0; roll < 3 * n; roll++)
            {
                int pick = LoadingCard.Pick(roll, last, n);
                if (pick < 0 || pick >= n) inRange = false;
                seen.Add(pick);
            }
            Check(inRange, $"after still {last} every pick is a still");
            Check(!seen.Contains(last), $"after still {last} it is not picked again");
            Check(seen.Count == n - 1, $"after still {last} every other still can come, got {seen.Count}");
        }
        Check(LoadingCard.Pick(5, 3, 12) == 6 && LoadingCard.Pick(2, 3, 12) == 2 && LoadingCard.Pick(3, 3, 12) == 4, "a pick at or past the last one steps over it");
        Check(LoadingCard.Pick(7, -1, 1) == 0 && LoadingCard.Pick(7, 0, 0) == 0, "one still or none is index 0");
    }

    // The headlines are tuning's, the header is in the text table in every language, and loads walk the headlines in order.
    static void News(string repoRoot)
    {
        S.GDict tuning = S.JSON.ParseString(File.ReadAllText(Path.Combine(repoRoot, "data", "tuning.json")));
        S.GDict ui = tuning["ui"];
        List<string> news = LoadingCard.News(ui);
        S.GArray<S.Variant> raw = ui["loading_news"];
        Check(news.Count == raw.Size() && news.Count > 0, $"{news.Count} headlines of tuning's {raw.Size()}");
        for (int i = 0; i < news.Count && i < raw.Size(); i++) Check(news[i] == S.Gd.Str(raw[i]), $"headline {i} is tuning's");
        Check(LoadingCard.News(new S.GDict()).Count == 0, "no loading_news is no headlines");
        Check(LoadingCard.News(null).Count == 0, "no ui section is no headlines");

        string oldLanguage = Tr.Language;
        Tr.Load(File.ReadAllText(Path.Combine(repoRoot, "data", "i18n", "strings.csv")));
        try
        {
            // The headlines themselves are not in strings.csv (Godot shows them in English too): only the header.
            foreach (string language in Tr.Languages)
            {
                if (language == "en") continue;
                Check(Tr.T("INCOMING", language) != "INCOMING", $"INCOMING has a {language} text");
            }
        }
        finally
        {
            Tr.Language = oldLanguage;
        }

        Check(LoadingCard.Tip(0, 3) == 0 && LoadingCard.Tip(1, 3) == 1 && LoadingCard.Tip(2, 3) == 2 && LoadingCard.Tip(3, 3) == 0, "each load shows the next headline, round and round");
        Check(LoadingCard.Tip(4, 0) == -1, "no headlines is tip -1");
    }

    // The place is the continent's name from data/continents.json; none for a plain rampage or an unknown id.
    static void Place()
    {
        Check(LoadingCard.Place(null) == "", "no request has no place");
        Check(LoadingCard.Place(new RunRequest()) == "", "a plain rampage has no place");
        Check(LoadingCard.Place(new RunRequest { continent = "no_such_continent" }) == "", "an unknown continent has no place");
        int named = 0;
        foreach (S.GDict def in S.Content.Continents())
        {
            string id = S.Gd.Str(def["id"]);
            string name = LoadingCard.Place(new RunRequest { continent = id });
            Check(name != "" && name == S.Gd.Str(def["name"]), $"{id} is named {name}");
            named++;
        }
        Check(named == 7, $"7 continents named, got {named}");
        Check(LoadingCard.Place(new RunRequest { continent = "ostia_minor" }) == "Ostia Minor", "ostia_minor is Ostia Minor");
    }
}
