// Generated from sim/growth.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Growth : RefCounted
    {
        public static implicit operator Growth(Variant v) => (Growth)v.Obj;

        // How big a kaiju is for a set of run stats. It starts young, dwarfed by the city; every
        // upgrade level grows it a little ("growth" = levels owned), every evolution a lot. Pure, so
        // the evolution reveal can compare the body before and after a purchase without a rampage.
        // The run stats a rampage plays on at its size tier: the stage's tuning "body" scales the
        // kaiju's speed and hp (D-074: the young stage is a slow, tough toddler, not a sprinting cub).

        public static GDict StageStats(GDict stats, GDict tuning)
        {
            GDict @out = stats.Duplicate();
            GDict body = tuning.Get("body", new GDict());
            @out["speed"] = Num.F(stats.Get("speed", 0.0)) * Num.F(body.Get("speed_mult", 1.0));
            @out["hp"] = Num.F(stats.Get("hp", 0.0)) * Num.F(body.Get("hp_mult", 1.0));
            return @out;
        }
        // How much of a blow a building takes from a kaiju of this size tier (D-091): one that dwarfs
        // the kaiju takes (size / tier)^dwarf_exp of it, so it takes longer to tear down, never forever.

        public static double DwarfMult(long sizeTier, long tier, GDict city)
        {
            return Gd.Minf(1.0, Gd.Pow(Gd.Float(sizeTier) / Gd.Maxf(1.0, tier), Num.F(city["dwarf_exp"])));
        }

        public static double BodyScale(GDict stats, GDict city)
        {
            double size = Num.F(stats.Get("size", 1.0));
            double tier = 1.0 + Num.F(city["size_scale_per_tier"]) * (size - 1.0);
            double growth = 1.0 + Num.F(city["growth_per_level"]) * Num.F(stats.Get("growth", 0.0));
            return Num.F(city["young_scale"]) * tier * growth;
        }

        void _InitFields()
        {
        }
        public Growth() { _InitFields(); }
    }
}
