// Generated from sim/final_strike.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class FinalStrike : RefCounted
    {
        public static implicit operator FinalStrike(Variant v) => (FinalStrike)v.Obj;

        // Time's up (D-263; director 2026-10-31 "Jet run", headline AIRSTRIKE): the army's final strike.
        // When the clock runs out, `jets` jets fly one low run across the screen through where he
        // stands (square to his facing, so across the camera that stays behind him, D-330; which side
        // they come from is seeded), `run_length` world units long in `pass_s`, at `altitude`. They drop
        // `bombs` bombs spaced evenly along `bomb_span` of the run, centred on him, each landing `fall_s`
        // after the lead jet passes over its point: a blow of `damage` within `radius` on the bottom
        // `floors` floors (RampageSim.hit_area, the normal destruction path, so it pays biomass as any
        // blow does). His death (DeathOverload's stagger, stone and shatter) starts `death_after_s` after
        // the last bomb. Part of DeathOverload; pure: one derived stream, no clock.
        // Events: airstrike {from, to, seconds, jets, altitude}, airstrike_bomb {x, z, radius}.
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Seconds since the strike began.
        public double t = 0.0;
        public Vector2 from = Vector2.ZERO;
        public Vector2 to = Vector2.ZERO;
        // The bombs still to land: [seconds after the start, ground point].
        public GArray<GArray<Variant>> bombs = new GArray<GArray<Variant>>();
        // What the bombs broke (chunks), for tests.
        public long chunks = 0;
        public double _end = 0.0;

        public FinalStrike(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
        }
        // The run begins now: the line, the bombs, the event.

        public void Start(RandomNumberGenerator rng)
        {
            t = 0.0;
            double side = (rng.Randf() < 0.5 ? 1.0 : -1.0);
            var dir = sim.facing.Orthogonal().Normalized() * side;
            double half = Num.F(cfg["run_length"]) * 0.5;
            from = sim.kaijuPos - dir * half;
            to = sim.kaijuPos + dir * half;
            double passS = Num.F(cfg["pass_s"]);
            long count = Num.I(cfg["bombs"]);
            double span = Num.F(cfg["bomb_span"]);
            bombs.Clear();
            foreach (long i in Gd.Range(count))
            {
                // from his centre
                double along = (Gd.Float(i) / Gd.Maxf(1.0, count - 1.0) - 0.5) * span;
                double at = (along + half) / (2.0 * half) * passS + Num.F(cfg["fall_s"]);
                bombs.Append(Gd.Arr(at, sim.ClampToArena(sim.kaijuPos + dir * along)));
            }
            _end = (count > 0 ? Num.F(bombs[-1][0]) + Num.F(cfg["death_after_s"]) : passS);
            sim.events.Append(new GDict { { "type", "airstrike" }, { "from", from }, { "to", to }, { "seconds", passS }, { "jets", Num.I(cfg["jets"]) }, { "altitude", Num.F(cfg["altitude"]) } });
        }
        // One step: the bombs that land now. True once his death should begin.

        public bool Step(double dt)
        {
            t += dt;
            while (!bombs.IsEmpty() && t >= Num.F(bombs[0][0]))
            {
                Vector2 at = bombs.PopFront()[1];
                _Land(at);
            }
            return t >= _end;
        }

        public void _Land(Vector2 at)
        {
            double radius = Num.F(cfg["radius"]);
            sim.events.Append(new GDict { { "type", "airstrike_bomb" }, { "x", at.x }, { "z", at.y }, { "radius", radius } });
            long before = sim.chunksDestroyed;
            var force = new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(Gd.Maxf(0.0, p.DistanceTo(at) - r), radius);
            });
            sim.HitArea(force, Num.F(cfg["damage"]), 0, Num.I(cfg["floors"]));
            chunks += sim.chunksDestroyed - before;
        }

        void _InitFields()
        {
        }
    }
}
