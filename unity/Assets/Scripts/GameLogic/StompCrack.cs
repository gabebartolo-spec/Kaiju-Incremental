// When a stomp cracks the street and how brightly (scenes/ability_fx.gd power and stomp_cracks): a blow is weighed
// against the species' own stomp_damage, 1 up to fx "power_max"; from fx "crack_stomp_power" up it leaves a disc of
// molten cracks 2.2 times the stomp's radius across, glowing 2.5 + 3 per power past that. Plain C# so
// SimTests/StompCrackCheck.cs checks it; StompCracks draws it. Cosmetic: the sim decided the stomp and its damage.
using System;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public static class StompCrack
    {
        // ability_fx.gd power: the floor under the species' own stat.
        const double OWN_FLOOR = 0.001;
        // ability_fx.gd stomp_cracks: the mark's size (a share of the radius), its glow, its glow per power, its cracks.
        public const double SIZE = 2.2, GLOW_BASE = 2.5, GLOW_PER_POWER = 3.0;
        public const int CRACKS = 7;

        // ability_fx.gd power: how heavy `value` is next to the species' own `own`, 1 up to fx "power_max".
        public static double Power(double value, double own)
        {
            double max = S.Num.F(S.Content.Section("fx")["power_max"]);
            return Math.Max(1.0, Math.Min(max, value / Math.Max(own, OWN_FLOOR)));
        }

        // ability_fx.gd stomp_cracks: whether a blow of `power` cracks the street; its glow when it does.
        public static bool Cracks(double power, out double glow)
        {
            double from = S.Num.F(S.Content.Section("fx")["crack_stomp_power"]);
            glow = GLOW_BASE + GLOW_PER_POWER * (power - from);
            return power >= from;
        }
    }
}
