// Generated from sim/sim_damage.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class SimDamage : RefCounted
    {
        public static implicit operator SimDamage(Variant v) => (SimDamage)v.Obj;

        // RampageSim's two damage paths, kept out of rampage_sim.gd for its line cap: an area blow
        // (hit_area) and the blows on one building's chunks (damage_cells). Pure sim, no Node.
        // Damages every standing chunk on floors y_lo..y_hi-1 (y_hi < 0: up to the kaiju's reach) by
        // damage x force(position, own radius), force 0..1; then lets the hit buildings settle. Units have
        // no hit points (D-437): a blow that reaches a tank wrecks it, thrown (throw()) when `throws` (a
        // sideways hit: tail lash, tail sweep, explosion) or where it stands (a stomp, slam, crash, breath;
        // director 2026-11-01: "a stomp shouldnt send it flying but a tail swipe? or a charge attack? yeah
        // it should go flying"); roof squads, walking mechs and helicopters it reaches go down. hit_coat
        // and hit_air widen what it does.

        public static void Area(RampageSim sim, Callable force, double damage, long yLo, long yHi, bool throws = false)
        {
            long top = (yHi < 0 ? Gd.Ceili(sim.ReachHeight()) : yHi);
            StrayShell.HitBuildings(sim, force, damage, new Vector2i(yLo, top));
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                double k = force.Call(tank.pos, RampageSim.TANK_RADIUS);
                if ((k <= 0.0 || tank.flying))
                {
                    continue;
                }
                if (throws)
                {
                    Throw(sim, tank, force, damage * k);
                }
                else
                {
                    tank.lastBlow = damage * k;
                    // crushed or burnt where it stands
                    tank.wrecked = true;
                }
            }
            // then clears dead tanks and squads
            sim.armyUnits.Splash(force, Gd.Maxi(0, yLo), top);
            // one blow that reaches a mech kills it
            sim.armyUnits.taskforce.mechs.Hit(force, damage);
            var air = (sim.hitAir || sim.ReachTop() >= sim.air.Altitude());
            sim.air.Hit(force, damage, air);
            // flies at the helicopters' height
            sim.armyUnits.taskforce.gunships.Hit(force, damage, air);
            sim.rail.Hit(force, damage);
            sim.vip.Hit(force, damage);
        }
        // A blow of `blow` (damage x force) on a grounded tank throws it: blow_throw m per unit of blow,
        // throw_min..throw_max out, away from where the blow is strongest (the force falls off that way;
        // a flat force: away from the kaiju). TankFlight wrecks it where it comes down.

        public static void Throw(RampageSim sim, RampageSim.Tank tank, Callable force, double blow)
        {
            GDict cfg = sim.army["flight"];
            tank.lastBlow = blow;
            double r = RampageSim.TANK_RADIUS;
            double e = r * 0.5;
            double dx = (force.Call(tank.pos + new Vector2(e, 0.0), r) - force.Call(tank.pos - new Vector2(e, 0.0), r));
            double dz = (force.Call(tank.pos + new Vector2(0.0, e), r) - force.Call(tank.pos - new Vector2(0.0, e), r));
            var way = -new Vector2(dx, dz);
            if (way.Length() < 0.001)
            {
                way = tank.pos - sim.kaijuPos;
            }
            if (way == Vector2.ZERO)
            {
                way = sim.facing;
            }
            double far = Gd.Clampf(blow * Num.F(cfg["blow_throw"]), Num.F(cfg["throw_min"]), Num.F(cfg["throw_max"]));
            sim.flight.Launch(tank, way, far);
        }
        // Damages chunks of one building, each by its own amount. A building that dwarfs the kaiju
        // takes less of each blow (Growth.dwarf_mult, D-091). Broken chunks pay rubble; then whatever
        // lost support starts to fall. Returns chunks broken. A carved building goes to Carving.

        public static long Cells(RampageSim sim, long index, GArray<Vector3i> hit, PackedFloat32Array amounts)
        {
            if (!hit.IsEmpty())
            {
                // a red barrel lights its fuse at any blow
                sim.explosives.Damaged(index);
            }
            if (sim.carving.Takes(index))
            {
                return sim.carving.Apply(index, hit, amounts);
            }
            var b = sim.buildings[index];
            double mult = Growth.DwarfMult(sim.SizeTier(), b.tier, sim.city);
            GArray<Vector3i> broken = new GArray<Vector3i>();
            foreach (long n in Gd.Range(hit.Size()))
            {
                if (b.frame.Damage(hit[n], amounts[n] * mult))
                {
                    broken.Append(hit[n]);
                }
            }
            if (broken.IsEmpty())
            {
                return 0;
            }
            sim.Pay(b, broken.Size(), 1.0);
            sim.events.Append(new GDict { { "type", "chunks_broken" }, { "building", index }, { "cells", broken } });
            sim.collapse.Settle(index);
            return broken.Size();
        }

        void _InitFields()
        {
        }
        public SimDamage() { _InitFields(); }
    }
}
