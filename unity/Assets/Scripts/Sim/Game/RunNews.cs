// Generated from sim/run_news.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RunNews : RefCounted
    {
        public static implicit operator RunNews(Variant v) => (RunNews)v.Obj;

        // The rampage's big moments, as sim events the HUD turns into a threat meter and news crawl
        // lines (D-259: "A small threat icon", news crawl "On big events"). Pure sim; it decides nothing.
        //
        // The threat level (1-5) is the city's own, tuning "threat" "level" (a growth stage overrides
        // it), fixed for the whole run (D-437): it sets where the army starts, the share of its spawn
        // ramp from "army" start_interval toward min_interval that "level_at" gives that level
        // (alert_chunks); destruction climbs the army on from there, the level never moves. Each step:
        // {"type": "landmark_felled", "landmark"}  a landmark lost RunTally's felled share
        // {"type": "towers_toppled", "count"}  the toppled towers reached a tower_counts row
        public const long LOWEST = 1;
        // The city's threat level, LOWEST..LOWEST + level_at.size().
        public long level = LOWEST;
        public RampageSim _sim;
        public GDict _cfg = new GDict();
        // Indices of the landmarks still standing (not yet reported felled).
        public GArray<long> _standing = new GArray<long>();
        public double _felledShare = 0.0;
        public long _towers = 0;

        public RunNews(RampageSim sim, GDict tuning)
        {
            _InitFields();
            _sim = sim;
            _cfg = tuning.Get("threat", Content.Section("threat"));
            GDict results = tuning.Get("results", Content.Section("results"));
            _felledShare = Num.F(results["landmark_felled_share"]);
            level = Num.I(_cfg["level"]);
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                if (sim.buildings[i].landmark != "")
                {
                    _standing.Append(i);
                }
            }
        }
        // Chunks of escalation that put `army` at the city's own threat level from the start (D-437):
        // the share of its spawn ramp where that level begins (tuning "threat" level, level_at).

        public static long AlertChunks(GDict army, GDict tuning)
        {
            GDict cfg = tuning.Get("threat", Content.Section("threat"));
            GArray<Variant> at = cfg["level_at"];
            long n = Num.I(cfg["level"]);
            if (n <= LOWEST)
            {
                return 0;
            }
            double span = Num.F(army["start_interval"]) - Num.F(army["min_interval"]);
            return Gd.Ceili(Num.F(at[n - 2]) * span / Num.F(army["escalation_per_chunk"]));
        }
        // Appends this step's big moments to `events`.

        public void Step(GArray<GDict> events)
        {
            foreach (long i in _standing.Duplicate())
            {
                var b = _sim.buildings[i];
                if (RunTally.Felled(b.startChunks, b.frame.aliveCount, _felledShare))
                {
                    _standing.Erase(i);
                    events.Append(new GDict { { "type", "landmark_felled" }, { "landmark", b.landmark } });
                }
            }
            long toppled = _sim.collapse.toppled;
            if (toppled == _towers)
            {
                return;
            }
            GArray<Variant> counts = _cfg["tower_counts"];
            foreach (Variant count in counts)
            {
                if (_towers < Num.I(count) && toppled >= Num.I(count))
                {
                    events.Append(new GDict { { "type", "towers_toppled" }, { "count", Num.I(count) } });
                }
            }
            _towers = toppled;
        }

        void _InitFields()
        {
        }
    }
}
