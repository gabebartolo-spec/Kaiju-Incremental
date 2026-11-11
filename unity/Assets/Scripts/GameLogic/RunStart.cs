// What every rampage takes from the save as it starts: scenes/run_start.gd, with the lines scenes/main.gd
// (_start_rampage) and scenes/globe_missions.gd (_start_city) run around it. Plain C#.
// The caller's order is Godot's: SaveFile.TakeLabCard first (the lab card after a death), then Prepare, write the
// save, then Intro (so intro_size is only saved with the run's result).
using Kaiju.Sim;

namespace Kaiju.Game
{
    public static class RunStart
    {
        // The run for `save`: its kaiju and upgrades, in `continentRow`'s real city (null: a plain rampage, which is
        // Endless only), on the slot's own seed and run number. The time of day (D-145) and the weather (D-155) are
        // seeded picks, never the last run's, unless the options fix one (`timeSetting`, `weatherSetting`; "" = none);
        // the save remembers both, even if the rampage is quit before it ends.
        public static RunRequest Prepare(GDict save, GDict continentRow, string timeSetting = "", string weatherSetting = "", bool endless = false, int slot = -1)
        {
            var request = new RunRequest();
            string saved = Gd.Str(save.Get("species", ""));
            GDict species = Content.SpeciesDef(saved);
            request.species = Gd.Str(species["id"]);
            request.levels = save.Get("levels", new GDict());
            request.bonuses = save.Get("bonuses", new GDict());
            // globe_missions.gd builds the tree on the resolved species id, main.gd on the save's own string.
            var tree = new UpgradeTree(Content.Upgrades(), request.levels, continentRow != null ? request.species : saved, request.bonuses);
            GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, tree);
            if (continentRow != null)
            {
                stats = Campaign.CityStats(stats, continentRow);
                request.continent = Gd.Str(continentRow["id"]);
            }
            request.stats = stats;
            request.tier = (int)Num.I(stats["size"]);
            long runs = Num.I(save.Get("runs", 0));
            request.runIndex = (int)runs;
            request.seed = Num.I(save.Get("seed", 0));
            request.endless = endless;
            request.slot = slot;
            // RunStart.prepare.
            request.citySeconds = Num.F(save.Get("city_seconds", 0.0));
            request.time = TimeOfDay.Pick(runs, Gd.Str(save.Get("last_time", "")), timeSetting);
            save["last_time"] = request.time;
            request.weather = Weather.Pick(runs, Gd.Str(save.Get("last_weather", "")), weatherSetting);
            save["last_weather"] = request.weather;
            return request;
        }

        // RunStart.intro: the whole run intro on the first run and the first at a new size (a new body to show); the
        // short cut otherwise (R 20.4). Call it after the save is written, so it is saved with the result.
        public static void Intro(GDict save, RunRequest request)
        {
            request.fullIntro = Num.I(save.Get("intro_size", -1)) != request.tier;
            save["intro_size"] = request.tier;
        }

        // The request's run stats: the ones Prepare made, or the same from its fields for a request built by hand.
        public static GDict Stats(RunRequest request)
        {
            if (request.stats != null) return request.stats;
            GDict species = Content.SpeciesDef(request.species);
            var tree = new UpgradeTree(Content.Upgrades(), request.levels, Gd.Str(species["id"]), request.bonuses);
            GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, tree);
            return request.continent != "" ? Campaign.CityStats(stats, Content.Continent(request.continent)) : stats;
        }

        // The run's buildings, as main.gd and globe_missions.gd bind CitySeed.layout.
        public static GArray<GDict> Layout(RunRequest request)
        {
            return CitySeed.Layout(Content.Tuning(), request.tier, request.seed, request.runIndex, request.continent);
        }
    }
}
