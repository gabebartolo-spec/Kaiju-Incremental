// One rampage to start: everything scenes/main.gd and scenes/globe_missions.gd hand a Rampage (setup_later, RunStart).
// Built by RunStart.Prepare from a save; RampageGame.Request reads it. Plain C#.
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class RunRequest
    {
        // The species id as the game resolved it (Content.SpeciesDef: an unknown id is the first playable one).
        public string species = "";
        // The save's upgrade levels and the conquest bonuses it kept (continent id -> bonus id).
        public GDict levels = new GDict();
        public GDict bonuses = new GDict();
        // The continent whose real city this is; "" for a plain rampage (Endless).
        public string continent = "";
        // The city's stage as a size tier (stats "size"): the kaiju's own, or the continent's stage + 1.
        public int tier = 1;
        // The slot's own city seed and the run number (the save's "runs"): CitySeed and the army's stream.
        public long seed;
        public int runIndex;
        // The time of day and the weather picked for this run ("" = leave what is set).
        public string time = "";
        public string weather = "";
        // The save slot in play; -1 when there is none.
        public int slot = -1;
        public bool endless;
        // Rampage seconds in this city so far, from the save (the Taskforce's clock, D-160).
        public double citySeconds;
        // The whole run intro or its short cut (RunStart.Intro).
        public bool fullIntro = true;
        // The final run stats (UpgradeTree.run_stats, at the continent's stage when one is named); null: RunStart.Stats.
        public GDict stats;
    }
}
