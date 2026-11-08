// Generated from sim/stray_shell.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class StrayShell : RefCounted
    {
        public static implicit operator StrayShell(Variant v) => (StrayShell)v.Obj;

        // A clumsy military (director, comments #18: "tanks shouldnt be perfectly accurate every time,
        // i really like the idea of a clumsy military which destroys parts of its own city
        // occasionally"). A tank's shot at the kaiju hits with a chance that falls from hit_near at
        // point blank to hit_far at full reach; a hit does the shot's damage / that chance, so the
        // kaiju takes what it took before on average. A miss lands in the city round the kaiju: it
        // breaks the chunks it reaches on the low floors like any blow (the carving path for carved
        // buildings). Seeded by the army's own stream; numbers are army.miss in data/tuning.json.
        // The chance a shot from `dist` hits, with the tanks' full reach `reach`.

        public static double Chance(GDict cfg, double dist, double reach)
        {
            GDict miss = cfg["miss"];
            double t = Gd.Clampf(dist / Gd.Maxf(reach, 0.001), 0.0, 1.0);
            return Gd.Lerpf(Num.F(miss["hit_near"]), Num.F(miss["hit_far"]), t);
        }
        // Where a missed shell lands: beside the kaiju (director, 2026-10-21: "land beside him", so the
        // player sees it break the buildings next to him), on a ring round it at a random angle, from
        // ring_near to ring_far out past its body. Not along the line of fire: a tank to one side would
        // put it behind the kaiju from the camera. A shell that lands in the street breaks nothing, so
        // it tries up to ring_tries spots and takes the first within the blast radius of a standing
        // building (the last when none is).

        public static Vector2 Landing(RampageSim sim, RandomNumberGenerator rng)
        {
            GDict miss = sim.army["miss"];
            double body = Num.F(sim.powersCfg["body_radius"]) * sim.BodyScale();
            var at = sim.kaijuPos;
            foreach (long _try in Gd.Range(Gd.Maxi(1, Num.I(miss["ring_tries"]))))
            {
                double @out = body + rng.RandfRange(Num.F(miss["ring_near"]), Num.F(miss["ring_far"]));
                at = sim.kaijuPos + Vector2.FromAngle(rng.RandfRange(0.0, Gd.TAU)) * @out;
                if (_NearBuilding(sim, at, Num.F(miss["radius"])))
                {
                    break;
                }
            }
            return at;
        }
        // Is a standing building's footprint within `reach` of p?

        public static bool _NearBuilding(RampageSim sim, Vector2 p, double reach)
        {
            foreach (RampageSim.Building b in sim.buildings)
            {
                if (b.frame.aliveCount == 0)
                {
                    continue;
                }
                var half = new Vector2(b.w, b.d) * 0.5 + new Vector2(reach, reach);
                if (Gd.Absf(p.x - b.x) <= half.x && Gd.Absf(p.y - b.z) <= half.y)
                {
                    return true;
                }
            }
            return false;
        }
        // The shell lands at `at`: every standing chunk within radius on the floors below `floors` takes
        // the shell's damage (falling off past it). Tanks, squads and helicopters are not touched.

        public static void Land(RampageSim sim, Vector2 at)
        {
            GDict miss = sim.army["miss"];
            double radius = Num.F(miss["radius"]);
            HitBuildings(sim, new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(p.DistanceTo(at) - r, radius);
            }), Num.F(miss["damage"]), new Vector2i(0, Num.I(miss["floors"])));
        }
        // Damages every standing chunk on floors floors.x..floors.y-1 that `force` (position, own radius
        // -> 0..1) reaches by damage x force, through the carving path for carved buildings, and lets the
        // hit buildings settle (RampageSim.hit_area's buildings, shared with it).

        public static void HitBuildings(RampageSim sim, Callable force, double damage, Vector2i floors)
        {
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                var b = sim.buildings[i];
                double near = force.Call(new Vector2(b.x, b.z), new Vector2(b.w, b.d).Length() * 0.5);
                if (near > 0.0 && sim.carving.Takes(i))
                {
                    // any damage arms a red barrel (comments #19)
                    sim.explosives.Damaged(i);
                    // coats what it reaches too
                    sim.carving.Hit(i, force, damage, b.LocalFloors(floors));
                    continue;
                }
                if ((near <= 0.0 || b.frame.aliveCount == 0))
                {
                    continue;
                }
                GArray<Vector3i> cells = new GArray<Vector3i>();
                var amounts = new PackedFloat32Array();
                var local = b.LocalFloors(floors);
                foreach (long y in Gd.Range(Gd.Maxi(0, local.x), Gd.Mini(local.y, b.height)))
                {
                    foreach (long x in Gd.Range(b.w))
                    {
                        foreach (long z in Gd.Range(b.d))
                        {
                            var c = new Vector3i(x, y, z);
                            if (b.frame.Alive(c))
                            {
                                var p = b.ChunkWorld(c);
                                double k = force.Call(new Vector2(p.x, p.z), 0.5);
                                if (k > 0.0)
                                {
                                    cells.Append(c);
                                    amounts.Append(damage * k);
                                }
                            }
                        }
                    }
                }
                if (!sim.hitCoat.IsEmpty())
                {
                    sim.powers.Coat(i, cells);
                }
                sim.DamageCells(i, cells, amounts);
            }
        }

        void _InitFields()
        {
        }
        public StrayShell() { _InitFields(); }
    }
}
