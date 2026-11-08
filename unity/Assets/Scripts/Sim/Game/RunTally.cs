// Generated from sim/run_tally.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RunTally : RefCounted
    {
        public static implicit operator RunTally(Variant v) => (RunTally)v.Obj;

        // The results screen's tally that only the sim can count (D-259 "Destruction tally": landmarks
        // felled). A landmark is felled once it has lost tuning "results" "landmark_felled_share" of the
        // chunks it stood with when the rampage began; a stadium never topples, so a share counts, not a
        // fall. Pure sim: read when the rampage ends (RampageSim.result, which is result here).
        // What `sim` (RampageSim) did, for the results screen (and the save's bests). "best_combo" is
        // the combo system's hook (D-259): it is absent until the combo lands, and the screen shows a dash.

        public static GDict Result(RampageSim sim)
        {
            return new GDict { { "rubble", Num.I(Gd.Floor(sim.rubble)) }, { "destruction", sim.Destruction() }, { "buildings", sim.collapse.DestroyedBuildings() }, { "seconds", sim.elapsed }, { "tanks", sim.tanksDestroyed }, { "helis", sim.air.destroyed + sim.armyUnits.taskforce.gunships.kills }, { "rooftops", sim.armyUnits.rooftopsDestroyed }, { "agents", sim.armyUnits.taskforce.kills }, { "mechs", sim.armyUnits.taskforce.mechs.kills }, { "city_seconds", sim.armyUnits.taskforce.CitySeconds() }, { "toppled", sim.collapse.toppled }, { "tallest_topple", sim.collapse.tallestTopple }, { "landmarks", LandmarksFelled(sim.buildings) }, { "reason", sim.endReason } };
        }
        // How many landmarks in `buildings` (RampageSim.Building) are felled.

        public static long LandmarksFelled(GArray<Variant> buildings)
        {
            double share = Num.F(Content.Section("results")["landmark_felled_share"]);
            long n = 0;
            foreach (RampageSim.Building b in buildings)
            {
                if (b.landmark != "" && Felled(b.startChunks, b.frame.aliveCount, share))
                {
                    n += 1;
                }
            }
            return n;
        }
        // True when a structure that started with `start` chunks and has `alive` left has lost `share`.

        public static bool Felled(long start, long alive, double share)
        {
            return start > 0 && Num.F(start - alive) >= share * Num.F(start);
        }

        void _InitFields()
        {
        }
        public RunTally() { _InitFields(); }
    }
}
