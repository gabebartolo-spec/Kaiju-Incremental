// Generated from sim/city_seed.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CitySeed : RefCounted
    {
        public static implicit operator CitySeed(Variant v) => (CitySeed)v.Obj;

        // Which city a run plays in: the one place the game turns a save's seed and a run index into the
        // city's config (its street plan's map_seed) and the stream its buildings draw from. The city
        // audits (tools/audit/seed_audit.gd) measure the game through this, so a change here is what
        // makes runs differ (D-263 "Different per save": each save slot's own seed plus the run index).
        // The buildings change with both (the stream below); the street plan is still the stage's tuned
        // city.map_seed (D-261's few tested plans per stage are their own row). The same save seed and run
        // index always give the same city. Pure.
        public const string STREAM = "city";
        // The stage's tuning for this run (CityGrowth.tuning_for), its city config the run's own: the
        // continent's street plan when one is named (D-435).

        public static GDict Tuning(GDict @base, long tier, long _saveSeed, long _runIndex, string continent = "")
        {
            return CityGrowth.TuningFor(@base, tier, continent);
        }
        // The stream the run's buildings draw from (CityGen.generate): the run index's stream, salted
        // by the save's seed, so two slots on the same run play different cities.

        public static RandomNumberGenerator Stream(long saveSeed, long runIndex)
        {
            return Seeds.Derive(Seeds.Make(STREAM, runIndex), saveSeed);
        }
        // The run's buildings: CityGen.generate on the run's city config and stream.

        public static GArray<GDict> Layout(GDict @base, long tier, long saveSeed, long runIndex, string continent = "")
        {
            GDict cfg = Tuning(@base, tier, saveSeed, runIndex, continent)["city"];
            return CityGen.Generate(Stream(saveSeed, runIndex), cfg);
        }

        void _InitFields()
        {
        }
        public CitySeed() { _InitFields(); }
    }
}
