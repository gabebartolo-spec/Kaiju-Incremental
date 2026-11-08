// Generated from sim/tail_sweep.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TailSweep : RefCounted
    {
        public static implicit operator TailSweep(Variant v) => (TailSweep)v.Obj;

        // The automatic tail sweep (D-459, director 2026-11-03: "lets remove claw from our croc, doesnt
        // really suit him anyway, refocus damage around the tail"). It took the claw rake's slot (D-095)
        // and keeps its cadence: every sweep_interval the tail swings out to one side, the sides
        // alternating, and hits the ground and floors beside and behind the body (the lash's half ring,
        // D-329: within the tail's reach, all round past sweep_arc_dot, the 360 clip), up to
        // sweep_top. It never touches his position or speed, so the run is never broken. Each level of
        // the tail nodes hits harder (sweep_damage) and reaches further (sweep_width); a body without
        // the stats never sweeps.
        // Separate from the signature lash (SpeciesPowers.lash): its own counters and events. Part of
        // SpeciesPowers; pure, no randomness.
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Sweeps so far, and the chunks they broke themselves (not what falls after).
        public long sweeps = 0;
        public long cut = 0;
        // Fine cells the sweeps carved themselves (carving on, D-094 WP7).
        public long carved = 0;
        public double _timer = 0.0;
        public double _side = 1.0;
        public bool _wound = false;
        // cfg: the "powers" tuning (sweep_interval, sweep_windup, sweep_top, tail_reach, sweep_arc_dot).

        public TailSweep(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            _timer = Num.F(cfg["sweep_interval"]);
        }

        public void Step(double dt)
        {
            if (sim.Stat("sweep_damage") <= 0.0)
            {
                return;
            }
            _timer -= dt;
            // nor a sweep through a leap
            var busy = (sim.airborne || sim.body.dash.On());
            if (!_wound && _timer <= Num.F(cfg["sweep_windup"]) && !busy)
            {
                // The tail draws back this long before the sweep lands (presentation's cue only).
                _wound = true;
                sim.events.Append(new GDict { { "type", "tail_auto_windup" }, { "side", -_side } });
            }
            if ((_timer > 0.0 || busy))
            {
                return;
            }
            // The timer ran on through a leap; one sweep on landing, then the normal rhythm (bug bash
            // 2026-11-05: a leap longer than the interval used to fire two sweeps one frame apart).
            _timer = Gd.Maxf(_timer, 0.0) + Num.F(cfg["sweep_interval"]);
            _wound = false;
            _Sweep();
        }
        // How far the sweep reaches from his centre now (world units).

        public double Reach()
        {
            double @base = Num.F(cfg["tail_reach"]) + sim.Stat("tail_reach") + sim.Stat("sweep_width");
            return @base * sim.BodyScale();
        }

        public void _Sweep()
        {
            double bs = sim.BodyScale();
            double far = Reach();
            double top = sim.standY + Num.F(cfg["sweep_top"]) * bs;
            var centre = sim.kaijuPos;
            var ahead = sim.facing;
            // 1.0: the tail-360 clip passes the front too
            double arc = Num.F(cfg["sweep_arc_dot"]);
            _side = -_side;
            sweeps += 1;
            sim.events.Append(new GDict { { "type", "tail_auto" }, { "side", _side }, { "reach", far }, { "top", top } });
            long before = sim.chunksDestroyed;
            long beforeCells = sim.carving.cellsCarved;
            var zone = new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                var to = p - centre;
                if (to.Length() > far + r)
                {
                    return 0.0;
                }
                return ((to.Length() <= r || ahead.Dot(to.Normalized()) <= arc) ? 1.0 : 0.0);
            });
            long floorLo = Gd.Maxi(0, Gd.Floori(sim.standY));
            double dmg = sim.Stat("sweep_damage") * sim.powers.HitMult();
            // the tail throws tanks (D-437)
            SimDamage.Area(sim, zone, dmg, floorLo, Gd.Ceili(top), true);
            // a jetpack agent in the air is swatted (D-139)
            sim.armyUnits.taskforce.Swat(zone, top);
            cut += sim.chunksDestroyed - before;
            carved += sim.carving.cellsCarved - beforeCells;
        }

        void _InitFields()
        {
        }
    }
}
