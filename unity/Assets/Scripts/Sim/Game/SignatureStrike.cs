// Generated from sim/signature_strike.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class SignatureStrike : RefCounted
    {
        public static implicit operator SignatureStrike(Variant v) => (SignatureStrike)v.Obj;

        // The kaiju's signature move as simulation: the croc's tail lash, the breath's cone, Leap
        // Slam's jump and landing, or the stomp ring. Part of RampageSim (step() fires it); split out
        // to keep files small. Pure.

        public static void Fire(RampageSim sim)
        {
            double reach = sim.AbilityReach();
            double damage = sim.Stat("ability_damage");
            var matched1 = sim.abilityType;
            if (matched1 == "lash")
            {
                sim.powers.WindLash();
            }
            else if (matched1 == "cone")
            {
                // the cone burns at the strike, where he faces then (D-166)
                sim.strikes.Breath();
            }
            else if (matched1 == "leap")
            {
                var from = sim.kaijuPos;
                sim.kaijuPos = sim.ClampToArena(sim.kaijuPos + sim.facing * Num.F(sim.city["leap_distance"]) * sim.BodyScale());
                var land = sim.kaijuPos;
                sim.events.Append(new GDict { { "type", "ability" }, { "kind", "leap" }, { "reach", reach }, { "from", from } });
                sim.HitArea(new Callable(a_ =>
                {
                    Vector2 p = a_[0];
                    double r = a_[1];
                    return RampageSim.Falloff(p.DistanceTo(land) - r, reach);
                }), damage);
            }
            else
            {
                var centre = sim.kaijuPos;
                sim.events.Append(new GDict { { "type", "ability" }, { "kind", "ring" }, { "reach", reach } });
                sim.HitArea(new Callable(a_ =>
                {
                    Vector2 p = a_[0];
                    double r = a_[1];
                    return RampageSim.Falloff(p.DistanceTo(centre) - r, reach);
                }), damage);
            }
        }
        // The signature, the croc's breath button (D-401) and the ultimate, each on its own cooldown.

        public static void StepButtons(RampageSim sim, double dt, bool signaturePressed, long buttons)
        {
            sim.abilityReadyIn = Gd.Maxf(0.0, sim.abilityReadyIn - dt);
            var lash = sim.abilityType == "lash";
            if (signaturePressed && sim.abilityReadyIn <= 0.0)
            {
                double cd = (lash ? Num.F(sim.powersCfg["lash_cooldown"]) : sim.Stat("ability_cooldown"));
                sim.abilityReadyIn = Gd.Maxf(0.5, cd);
                Fire(sim);
            }
            sim.breathReadyIn = Gd.Maxf(0.0, sim.breathReadyIn - dt);
            if (lash && (buttons & RampageSim.BREATH) != 0 && sim.breathReadyIn <= 0.0)
            {
                sim.breathReadyIn = Gd.Maxf(0.5, sim.Stat("ability_cooldown"));
                // the cone burns at the strike, where he faces then (D-166)
                sim.strikes.Breath();
            }
            sim.ultimateReadyIn = Gd.Maxf(0.0, sim.ultimateReadyIn - dt);
            if (((buttons & RampageSim.ULTIMATE) != 0 && sim.ultimateReadyIn <= 0.0 && sim.powers.HasUltimate()))
            {
                sim.ultimateReadyIn = Num.F(sim.powersCfg["ultimate_cooldown"]);
                sim.powers.Ultimate();
            }
        }

        void _InitFields()
        {
        }
        public SignatureStrike() { _InitFields(); }
    }
}
