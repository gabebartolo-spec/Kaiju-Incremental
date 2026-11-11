// RunStart (Assets/Scripts/GameLogic/RunStart.cs) against what Godot starts a rampage with: scenes/run_start.gd,
// scenes/main.gd _start_rampage and scenes/globe_missions.gd _start_city, read line by line, on the data files.
// Each expectation below names the Godot line or data row it comes from.
using System;
using Kaiju.Game;
using Kaiju.Sim;

static class RunStartCheck
{
    const double EPS = 1e-9;
    const long SEED = 12345;

    static int checks, failed;

    public static int Run(string repoRoot)
    {
        FileAccess.Root = repoRoot;
        checks = failed = 0;
        NewCroc();
        Settings();
        NextRun();
        Continents();
        Upgraded();
        Console.WriteLine($"runstart: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL runstart: " + what);
    }

    static void Near(GDict stats, string stat, double want)
    {
        double got = stats.Has(stat) ? Num.F(stats[stat]) : double.NaN;
        Check(Math.Abs(got - want) < EPS, $"stat {stat} is {got}, Godot gives {want}");
    }

    // autoload/save_file.gd new_save(species_id, city_seed) with campaign(): a new kaiju's save.
    static GDict NewSave(string species, long seed)
    {
        return new GDict
        {
            { "version", 6L }, { "species", species }, { "seed", seed }, { "rubble", 0L }, { "levels", new GDict() }, { "runs", 0L },
            { "best", new GDict() }, { "city_seconds", 0.0 }, { "demo", false }, { "demo_done", false }, { "totals", new GDict() },
            { "specimen", 1L }, { "lab_card", false }, { "conquered", Gd.Arr() }, { "bonuses", new GDict() }, { "threat", 0.0 },
            { "noise_log", Gd.Arr() },
        };
    }

    // A new croc, no continent (main.gd _start_rampage).
    static void NewCroc()
    {
        GDict save = NewSave("reptilian", SEED);
        RunRequest r = RunStart.Prepare(save, null);
        Check(r.species == "reptilian", $"species is {r.species}");
        Check(r.continent == "", $"continent is '{r.continent}', a plain rampage names none");
        // main.gd: tier = stats.size; data/tuning.json kaiju.size is 1 and a new save owns no evolution.
        Check(r.tier == 1, $"tier is {r.tier}, a new kaiju is the young croc (1)");
        // main.gd: CitySeed.layout binds the save's seed and its runs (0 on a new save).
        Check(r.seed == SEED, $"seed is {r.seed}, the save's is {SEED}");
        Check(r.runIndex == 0, $"run index is {r.runIndex}, a new save has 0 runs");
        // run_start.gd prepare: city_seconds from the save (new_save: 0.0).
        Check(r.citySeconds == 0.0, $"city seconds is {r.citySeconds}");
        Check(!r.endless && r.slot == -1, "endless or a slot set by default");
        Check(r.levels.Size() == 0 && r.bonuses.Size() == 0, "a new save has levels or bonuses");
        // data/looks.json times.play is ["dusk"] (D-359): TimeOfDay.pick has one time to give.
        Check(r.time == "dusk", $"time is '{r.time}', the only playable time is dusk");
        Check(Gd.Str(save["last_time"]) == "dusk", "the save does not remember the time (run_start.gd prepare)");
        // Weather.pick(0, "", ""): a seeded draw from data/looks.json weather.order on the stream "weather", run 0.
        Check(Content.Weathers().Has(r.weather), $"weather '{r.weather}' is not one of looks.json weather.order");
        Check(r.weather == Weather.Pick(0, "", ""), "weather is not Weather.pick(runs, last_weather, setting)");
        Check(Gd.Str(save["last_weather"]) == r.weather, "the save does not remember the weather (run_start.gd prepare)");
        // UpgradeTree.run_stats: data/tuning.json kaiju, with data/species.json reptilian stats over it, no upgrades.
        GDict s = r.stats;
        Near(s, "hp", 120);             // species
        Near(s, "speed", 5.5);          // species
        Near(s, "stomp_damage", 10);    // species
        Near(s, "stomp_radius", 2.5);   // species
        Near(s, "stomp_interval", 0.7); // species
        Near(s, "sweep_damage", 8);     // species
        Near(s, "sweep_width", 1.6);    // species
        Near(s, "ability_damage", 36);  // species
        Near(s, "ability_cooldown", 7); // species
        Near(s, "ability_range", 14.5); // species
        Near(s, "run_seconds", 40);     // tuning kaiju
        Near(s, "rubble_mult", 1);      // tuning kaiju
        Near(s, "armor", 0);            // tuning kaiju
        Near(s, "size", 1);             // tuning kaiju
        Near(s, "growth", 0);           // run_stats: levels owned
        Near(s, "stage_growth", 0);     // run_stats: levels owned on this tier
        Check(!s.Has("continent"), "a plain rampage's stats name a continent");
        // run_start.gd intro: intro_size is absent (-1) on a new save, so the whole intro plays, and the tier is kept.
        Check(!save.Has("intro_size"), "Prepare wrote intro_size: Godot writes it after the save is written");
        RunStart.Intro(save, r);
        Check(r.fullIntro, "the first run does not play the whole intro");
        Check(Num.I(save["intro_size"]) == 1, "intro_size is not the run's tier");
        RunStart.Intro(save, r);
        Check(!r.fullIntro, "a second run at the same size still plays the whole intro");
        // A request with no stats of its own (built by hand) gives the same stats from its fields.
        var bare = new RunRequest { species = r.species, levels = r.levels, bonuses = r.bonuses, tier = r.tier };
        Near(RunStart.Stats(bare), "hp", 120);
        Near(RunStart.Stats(bare), "size", 1);
        // main.gd: CitySeed.layout(Content.tuning(), tier, seed, runs): the city is planned and has buildings.
        Check(RunStart.Layout(r).Size() > 0, "the run's city has no buildings");
    }

    // The options fix a time or a weather (PlayerSettings.time_of_day / weather): pick returns a setting it knows.
    static void Settings()
    {
        RunRequest r = RunStart.Prepare(NewSave("reptilian", SEED), null, "", "rain");
        Check(r.weather == "rain", $"weather is '{r.weather}' with the options set to rain");
        // "night" is in times.order but not times.play: not a setting TimeOfDay.pick takes, so the seeded pick (dusk).
        r = RunStart.Prepare(NewSave("reptilian", SEED), null, "night", "");
        Check(r.time == "dusk", $"time is '{r.time}' with the options set to a time that is not playable");
        r = RunStart.Prepare(NewSave("reptilian", SEED), null, "", "", true, 2);
        Check(r.endless && r.slot == 2, "endless and the slot are not carried");
    }

    // The next run: the run index is the save's runs, and the weather is never the last run's (Weather.pick's pool).
    static void NextRun()
    {
        GDict save = NewSave("reptilian", SEED);
        string first = RunStart.Prepare(save, null).weather;
        for (long run = 1; run <= 20; run++)
        {
            save["runs"] = run;
            string last = Gd.Str(save["last_weather"]);
            RunRequest r = RunStart.Prepare(save, null);
            Check(r.runIndex == run, $"run index is {r.runIndex} on a save with {run} runs");
            Check(r.weather != last, $"run {run} plays '{r.weather}' twice in a row");
        }
        Check(first != "", "no weather picked");
        save["city_seconds"] = 73.5;
        Check(RunStart.Prepare(save, null).citySeconds == 73.5, "the Taskforce's clock so far is not the save's city_seconds");
    }

    // A continent's real city (globe_missions.gd _start_city): Campaign.city_stats puts the stats at the continent's
    // stage + 1 and names it. data/continents.json: ostia_minor stage 0, carthago stage 1.
    static void Continents()
    {
        RunRequest r = RunStart.Prepare(NewSave("reptilian", SEED), Content.Continent("ostia_minor"));
        Check(r.continent == "ostia_minor" && r.tier == 1, $"ostia_minor: continent '{r.continent}' tier {r.tier}, want tier 1");
        Check(Gd.Str(r.stats["continent"]) == "ostia_minor", "ostia_minor: the stats do not name the continent");
        r = RunStart.Prepare(NewSave("reptilian", SEED), Content.Continent("carthago"));
        Check(r.continent == "carthago" && r.tier == 2, $"carthago: continent '{r.continent}' tier {r.tier}, want tier 2");
        Near(r.stats, "size", 2);
        Near(r.stats, "hp", 120);  // the kaiju is the save's, only the city's stage is the continent's
        Check(Gd.Str(r.stats["continent"]) == "carthago", "carthago: the stats do not name the continent");
        Check(RunStart.Layout(r).Size() > 0, "carthago's city has no buildings");
    }

    // A save with upgrades and a kept bonus, in carthago. data/upgrades.json: claws +5 sweep_damage and +0.6
    // sweep_width a level, hide +20 hp a level; data/continents.json bonus_ostia_minor_2 scales hp by +0.1.
    static void Upgraded()
    {
        GDict save = NewSave("reptilian", SEED);
        save["levels"] = new GDict { { "claws", 2L }, { "hide", 1L } };
        save["bonuses"] = new GDict { { "ostia_minor", "bonus_ostia_minor_2" } };
        save["runs"] = 4L;
        save["intro_size"] = 1L;
        RunRequest r = RunStart.Prepare(save, Content.Continent("carthago"));
        Near(r.stats, "sweep_damage", 8 + 2 * 5);
        Near(r.stats, "sweep_width", 1.6 + 2 * 0.6);
        Near(r.stats, "hp", (120 + 20) * 1.1);  // UpgradeTree.apply: levels first, then the bonus fractions
        Near(r.stats, "growth", 3);
        Near(r.stats, "stage_growth", 3);       // counted at the kaiju's own tier (1), before city_stats
        Near(r.stats, "size", 2);
        Check(r.tier == 2 && r.runIndex == 4, $"tier {r.tier} run {r.runIndex}, want 2 and 4");
        // run_start.gd intro: the save last showed size 1, this city is size 2: the whole intro again.
        RunStart.Intro(save, r);
        Check(r.fullIntro && Num.I(save["intro_size"]) == 2, "a new size does not play the whole intro");
    }
}
