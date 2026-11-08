// Generated from sim/city_growth.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityGrowth : RefCounted
    {
        public static implicit operator CityGrowth(Variant v) => (CityGrowth)v.Obj;

        // The city grows with each evolution (D-039). data/tuning.json "growth.stages" holds one stage
        // per size tier (young, Behemoth, Colossus; D-135); each stage overrides keys of the
        // tuning sections it names: the city's playable half-extent, its coast and height cap, and
        // harder defences (more and tougher tanks, helicopters from the Behemoth on). The street plan
        // itself spans every district at every stage (CityGen.districts), so an evolution opens new
        // districts round the one the kaiju already knows. Pure: tuning in, tuning out.
        // The tuning a rampage at this size tier runs on: a deep copy of `tuning` with the stage's
        // overrides applied, then the continent's own (data/continents.json "tuning", D-435: its street
        // plan's seed and pattern) when one is named. Tiers past the last stage use the last stage.

        public static GDict TuningFor(GDict tuning, long tier, string continent = "")
        {
            GDict @out = tuning.Duplicate(true);
            GArray<Variant> stages = _Stages(tuning);
            if (stages.IsEmpty())
            {
                return @out;
            }
            GDict stage = stages[Gd.Clampi(tier - 1, 0, stages.Size() - 1)];
            _Overlay(@out, stage);
            if (continent != "")
            {
                GDict own = Content.Continent(continent).Get("tuning", new GDict());
                _Overlay(@out, own);
            }
            // the bay holds this stage's biggest body
            EmergeReach.Fit(@out, Content.Upgrades(), tier);
            return @out;
        }
        // Sets every key `over` names, section by section, in `out` (a stage's "per_level" is no section).

        public static void _Overlay(GDict @out, GDict over)
        {
            foreach (string section in over)
            {
                if (section == "per_level")
                {
                    continue;
                }
                GDict into = @out[section];
                GDict keys = over[section];
                foreach (string key in keys)
                {
                    into[key] = _Copy(keys[key]);
                }
            }
        }
        // The game's tuning for a rampage with these run stats: their size tier picks the stage, their
        // "continent" (when set) its own city, and the levels bought inside that stage ("stage_growth")
        // harden the army and air on top.

        public static GDict ForStats(GDict stats)
        {
            return TuningForStats(Content.Tuning(), stats);
        }

        public static GDict TuningForStats(GDict tuning, GDict stats)
        {
            long tier = Num.I(stats.Get("size", 1));
            GDict @out = TuningFor(tuning, tier, Gd.Str(stats.Get("continent", "")));
            return Hardened(@out, tuning, tier, Num.F(stats.Get("stage_growth", 0.0)));
        }
        // The army learns (finding 1 of the active-incremental research, 2026-10-18): inside a stage,
        // every upgrade level the kaiju buys scales the keys named in "growth.per_level" (or the
        // stage's own "per_level") by (1 + fraction * levels), so defeat stays possible after the
        // first evolution instead of the clock ending every run. Pure: stage tuning in, tuning out.

        public static GDict Hardened(GDict stageTuning, GDict tuning, long tier, double stageGrowth)
        {
            GDict @out = stageTuning.Duplicate(true);
            GDict perLevel = PerLevelFor(tuning, tier);
            foreach (string section in perLevel)
            {
                if (!@out.Has(section))
                {
                    continue;
                }
                GDict into = @out[section];
                GDict fractions = perLevel[section];
                foreach (string key in fractions)
                {
                    double mult = Gd.Maxf(0.1, 1.0 + Num.F(fractions[key]) * stageGrowth);
                    into[key] = Num.F(into[key]) * mult;
                }
            }
            return @out;
        }
        // The per-level fractions a tier escalates by: the stage's own "per_level" when it has one,
        // else "growth.per_level", else nothing.

        public static GDict PerLevelFor(GDict tuning, long tier)
        {
            GDict growth = tuning.Get("growth", new GDict());
            GArray<Variant> stages = _Stages(tuning);
            if (!stages.IsEmpty())
            {
                GDict stage = stages[Gd.Clampi(tier - 1, 0, stages.Size() - 1)];
                if (stage.Has("per_level"))
                {
                    return stage["per_level"];
                }
            }
            return growth.Get("per_level", new GDict());
        }
        // The playable city of a size tier (on a continent's own plan when named), seeded from `rng`
        // (CityGen.generate on the stage's city).

        public static GArray<GDict> Layout(GDict tuning, long tier, RandomNumberGenerator rng, string continent = "")
        {
            GDict cfg = TuningFor(tuning, tier, continent)["city"];
            return CityGen.Generate(rng, cfg);
        }

        public static long StageCount(GDict tuning)
        {
            return _Stages(tuning).Size();
        }

        public static GArray<Variant> _Stages(GDict tuning)
        {
            GDict growth = tuning.Get("growth", new GDict());
            GArray<Variant> stages = growth.Get("stages", Gd.Arr());
            return stages;
        }

        public static Variant _Copy(Variant value)
        {
            if (Gd.Is<GArray<Variant>>(value))
            {
                GArray<Variant> arr = value;
                return arr.Duplicate(true);
            }
            if (Gd.Is<GDict>(value))
            {
                GDict dict = value;
                return dict.Duplicate(true);
            }
            return value;
        }

        void _InitFields()
        {
        }
        public CityGrowth() { _InitFields(); }
    }
}
