// Generated from sim/taskforce_perch.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TaskforcePerch : RefCounted
    {
        public static implicit operator TaskforcePerch(Variant v) => (TaskforcePerch)v.Obj;

        // Where a Taskforce agent lands (D-137): a standing top chunk of a building in the band round the
        // kaiju that no other agent holds. Part of Taskforce; pure, and shares its seeded stream.
        public RampageSim sim;
        public GDict cfg = new GDict();
        public RandomNumberGenerator _rng;

        public TaskforcePerch(RampageSim pSim, GDict pCfg, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            _rng = rng;
        }
        // A standing top chunk in the perch band around the kaiju, on a building no other agent holds
        // or is bound for: [building index, cell], or [] when there is none.

        public GArray<Variant> Pick(Taskforce.Agent agent, GArray<Taskforce.Agent> agents)
        {
            var options = _Options(agent, agents);
            foreach (long _try in Gd.Range(Num.I(cfg["perch_tries"])))
            {
                if (options.IsEmpty())
                {
                    break;
                }
                long i = options[_rng.RandiRange(0, options.Size() - 1)];
                var b = sim.buildings[i];
                long x = _rng.RandiRange(0, b.w - 1);
                long z = _rng.RandiRange(0, b.d - 1);
                long y = _Top(b, x, z);
                if (y >= 0)
                {
                    return Gd.Arr(i, new Vector3i(x, y, z));
                }
            }
            return Gd.Arr();
        }
        // The highest standing chunk of a column that is tall enough to perch on (the building's roof
        // where it is whole, a lower floor where its top was chewed away), or -1.

        public long _Top(RampageSim.Building b, long x, long z)
        {
            foreach (long y in Gd.Range(b.height - 1, Num.I(cfg["perch_min_height"]) - 2, -1))
            {
                if (b.frame.Alive(new Vector3i(x, y, z)))
                {
                    return y;
                }
            }
            return -1;
        }
        // Whether any column of the building still has a chunk to perch on.

        public bool _HasTop(RampageSim.Building b)
        {
            foreach (long x in Gd.Range(b.w))
            {
                foreach (long z in Gd.Range(b.d))
                {
                    if (_Top(b, x, z) >= 0)
                    {
                        return true;
                    }
                }
            }
            return false;
        }
        // The buildings an agent may perch on: standing, tall enough, in the perch band round the kaiju,
        // and not held or aimed at by another agent. With none in the band (the kaiju at the map edge, or
        // the city round it flattened) the `perch_fallback` nearest to the band, so a squad never hovers.

        public GArray<long> _Options(Taskforce.Agent agent, GArray<Taskforce.Agent> agents)
        {
            GArray<Variant> span = cfg["perch_range"];
            GDict taken = new GDict();
            foreach (Taskforce.Agent other in agents)
            {
                if (other != agent && other.building >= 0)
                {
                    taken[other.building] = true;
                }
            }
            GArray<long> options = new GArray<long>();
            // [distance outside the band, building]
            GArray<GArray<Variant>> outside = new GArray<GArray<Variant>>();
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                if ((taken.Has(i) || !_Perchable(sim.buildings[i])))
                {
                    continue;
                }
                var b = sim.buildings[i];
                double away = new Vector2(b.x, b.z).DistanceTo(sim.kaijuPos);
                double gap = Gd.Maxf(Gd.Maxf(Num.F(span[0]) - away, away - Num.F(span[1])), 0.0);
                if (gap == 0.0)
                {
                    options.Append(i);
                }
                else
                {
                    outside.Append(Gd.Arr(gap, i));
                }
            }
            if (options.IsEmpty())
            {
                outside.SortCustom(new Callable(a_ =>
                {
                    GArray<Variant> a = a_[0];
                    GArray<Variant> c = a_[1];
                    return Num.F(a[0]) < Num.F(c[0]);
                }));
                foreach (GArray<Variant> pair in outside.Slice(0, Num.I(cfg["perch_fallback"])))
                {
                    options.Append(Num.I(pair[1]));
                }
            }
            return options;
        }
        // Standing, in the arena, tall enough, and with a chunk left to land on.

        public bool _Perchable(RampageSim.Building b)
        {
            return (b.inArena && b.frame.aliveCount > 0 && b.height >= Num.I(cfg["perch_min_height"]) && _HasTop(b));
        }

        void _InitFields()
        {
        }
    }
}
