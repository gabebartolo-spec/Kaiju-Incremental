// Generated from sim/fire_spread.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class FireSpread : RefCounted
    {
        public static implicit operator FireSpread(Variant v) => (FireSpread)v.Obj;

        // Fire that spreads building to building on its own, once City Ablaze is owned (stat
        // fire_spread; D-126, R 26.2-26.3). Each building has a heat meter: a burning building heats its
        // neighbours by the gap between them, the wind (Fire Front: fixed per run, D-115) and how well the
        // neighbour burns (tuning fire.flammability by style). A building whose heat reaches 1 glows first
        // (event fire_glow, glow_seconds, seeded) so the kaiju can still smash it as a firebreak, then
        // burns (fire_burning) and burns out (fire_burnt): its ground floors give way and the rest
        // collapses and topples like a smashed building (D-129), so no burning shell is ever left (#111).
        // What it drops pays burn_pay of a smash, times a conflagration multiplier that climbs with each
        // burn-out and decays, and far_pay far from the kaiju. Fires start from the beam's burning coat,
        // the breath (scorch) and stray army shells (shelled) once City Ablaze is owned (D-129).
        // Neighbours come from a grid of footprints built once; the heat pass runs every spread_tick s
        // and touches only the buildings that are heating, glowing or burning. Heat is a plain meter:
        // anything that later takes heat away (a fire crew, comment #50) lowers heat[i], and a heating
        // building back at 0 is intact again. Part of SpeciesPowers; pure and seeded (its own stream).
        public static class State
        {
            public const long INTACT = 0;
            public const long HEATING = 1;
            public const long GLOWING = 2;
            public const long BURNING = 3;
            public const long BURNT = 4;
        }
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Per building: its State, heat (0..1) and the seconds left glowing or burning.
        public PackedByteArray state = new PackedByteArray();
        public PackedFloat32Array heat = new PackedFloat32Array();
        public PackedFloat32Array timer = new PackedFloat32Array();
        // The payout multiplier from burn-outs in a row (1 = none lately).
        public double conflagration = 1.0;
        public long burntOut = 0;
        // The run's wind, a unit vector on the ground plane (only Fire Front reads it).
        public Vector2 wind = Vector2.RIGHT;
        public RandomNumberGenerator _rng;
        public double _reach = 0.0;
        // Vector2i cell -> PackedInt32Array of building indices whose footprint it holds
        public GDict _grid = new GDict();
        public double _cell = 1.0;
        // building -> [PackedInt32Array neighbours, PackedFloat32Array heat a second]
        public GDict _near = new GDict();
        // building -> true while HEATING, GLOWING or BURNING (insertion order)
        public GDict _active = new GDict();
        // seconds since the last heat pass
        public double _since = 0.0;
        // heat passes so far; _warm[j] == _pass when a fire warmed j this pass
        public long _pass = 0;
        public PackedInt32Array _warm = new PackedInt32Array();
        // Buildings giving way: building -> [ground cells still standing, downwind first; cells a batch;
        // ticks between batches; ticks to the next batch].
        public GDict _crumbling = new GDict();
        // p_cfg: tuning powers.fire.

        public FireSpread(RampageSim pSim, GDict pCfg, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            _rng = rng;
            long n = sim.buildings.Size();
            state.Resize(n);
            heat.Resize(n);
            timer.Resize(n);
            _warm.Resize(n);
            _warm.Fill(-1);
            wind = Vector2.RIGHT.Rotated(_rng.Randf() * Gd.TAU);
            _reach = Num.F(cfg["reach"]) + Num.F(cfg["ember_reach"]) * sim.Stat("fire_embers");
            _cell = Num.F(cfg["grid"]);
            foreach (long i in Gd.Range(n))
            {
                var r = _Rect(i);
                foreach (long x in Gd.Range(Gd.Floori(r.position.x / _cell), Gd.Floori(r.end.x / _cell) + 1))
                {
                    foreach (long z in Gd.Range(Gd.Floori(r.position.y / _cell), Gd.Floori(r.end.y / _cell) + 1))
                    {
                        var key = new Vector2i(x, z);
                        PackedInt32Array list = _grid.Get(key, new PackedInt32Array());
                        list.Append(i);
                        _grid[key] = list;
                    }
                }
            }
        }
        // Whether fire spreads this run (City Ablaze owned).

        public bool On()
        {
            return sim.Stat("fire_spread") > 0.0;
        }
        // Building i catches fire now (a burning coat reached it, or a blast): it burns, and heats its
        // neighbours, until it burns out. Nothing happens without City Ablaze or once it has burnt.

        public void Ignite(long i)
        {
            if ((!On() || state[i] >= State.BURNING || !_CanBurn(i)))
            {
                return;
            }
            _Burn(i);
        }
        // The breath swept `area` (D-129): each building `force` (position, own radius -> 0..1) reaches
        // catches with chance breath_ignite.

        public void Scorch(Rect2 area, Callable force)
        {
            if (!On())
            {
                return;
            }
            double chance = Num.F(cfg["breath_ignite"]);
            foreach (long i in _Around(area, 0.0))
            {
                var b = sim.buildings[i];
                double near = force.Call(new Vector2(b.x, b.z), new Vector2(b.w, b.d).Length() * 0.5);
                if (near > 0.0 && _rng.Randf() < chance)
                {
                    Ignite(i);
                }
            }
        }
        // A stray army shell landed at `at` (D-129): a building within shell_reach catches with chance
        // shell_ignite. The clumsy army (claude/clumsy-army, StrayShell.land) calls this once it merges.

        public void Shelled(Vector2 at)
        {
            if (!On())
            {
                return;
            }
            double reach = Num.F(cfg["shell_reach"]);
            var spot = new Rect2(at, Vector2.ZERO);
            foreach (long i in _Around(spot, reach))
            {
                if (_Gap(_Rect(i), spot) <= reach && _rng.Randf() < Num.F(cfg["shell_ignite"]))
                {
                    Ignite(i);
                }
            }
        }
        // An explosive site went off at `at` (Firestorm, D-126): every building within `radius` catches.
        // Nothing calls it until explosive sites merge (claude/city-explosives): Firestorm is a stub.

        public void Blast(Vector2 at, double radius)
        {
            if (sim.Stat("firestorm") <= 0.0)
            {
                return;
            }
            double r = radius * (1.0 + Num.F(cfg["firestorm_grow"]) * (sim.Stat("firestorm") - 1.0));
            foreach (long i in _Around(new Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0), 0.0))
            {
                if (_Gap(_Rect(i), new Rect2(at, Vector2.ZERO)) <= r)
                {
                    Ignite(i);
                }
            }
        }

        public void Step(double dt)
        {
            conflagration = Gd.Maxf(1.0, conflagration - Num.F(cfg["conflag_decay"]) * dt);
            if ((_active.IsEmpty() || !On()))
            {
                return;
            }
            _since += dt;
            // a whole number of ticks
            var spread = _since >= Num.F(cfg["spread_tick"]) - dt * 0.5;
            GArray<Variant> keys = _active.Keys();
            foreach (long i in keys)
            {
                // smashed first: nothing left to burn
                if (sim.buildings[i].frame.aliveCount == 0)
                {
                    _Drop(i, State.BURNT);
                }
            }
            if (spread)
            {
                _HeatPass(keys);
            }
            foreach (long i in keys)
            {
                _Tick(i, dt);
            }
            if (spread)
            {
                _since = 0.0;
            }
        }
        // Every burning building heats its neighbours for the seconds since the last pass; then each
        // heating one glows or cools.

        public void _HeatPass(GArray<Variant> keys)
        {
            _pass += 1;
            foreach (long i in keys)
            {
                if (state[i] == State.BURNING)
                {
                    _HeatNeighbours(i, _since);
                }
            }
            foreach (long i in keys)
            {
                if (state[i] == State.HEATING)
                {
                    _Heating(i, _since);
                }
            }
        }
        // A glowing building's glow and a burning one's fire count down by dt.

        public void _Tick(long i, double dt)
        {
            if (state[i] != State.GLOWING && state[i] != State.BURNING)
            {
                return;
            }
            if (_crumbling.Has(i))
            {
                _Crumble(i);
                return;
            }
            timer[i] -= dt;
            if (timer[i] > 0.0)
            {
                return;
            }
            if (state[i] == State.GLOWING)
            {
                _Burn(i);
            }
            else
            {
                _BurnOut(i, dt);
            }
        }
        // Burning building i heats every neighbour still intact or heating; neighbours already past
        // heating (they never come back) leave its list for good, so a long fire gets cheaper.

        public void _HeatNeighbours(long i, double dt)
        {
            GArray<Variant> near = _near.Get(i, Gd.Arr());
            if (near.IsEmpty())
            {
                near = _Neighbours(i);
                _near[i] = near;
            }
            PackedInt32Array who = near[0];
            PackedFloat32Array rate = near[1];
            long gone = 0;
            foreach (long k in Gd.Range(who.Size()))
            {
                long j = who[k];
                if (state[j] > State.HEATING)
                {
                    gone += 1;
                    continue;
                }
                if (state[j] == State.INTACT)
                {
                    state[j] = State.HEATING;
                    _active[j] = true;
                }
                heat[j] += rate[k] * dt;
                _warm[j] = _pass;
            }
            if (gone > 0)
            {
                _near[i] = _StillHeatable(who, rate);
            }
        }

        public GArray<Variant> _StillHeatable(PackedInt32Array who, PackedFloat32Array rate)
        {
            var keep = new PackedInt32Array();
            var keepRate = new PackedFloat32Array();
            foreach (long k in Gd.Range(who.Size()))
            {
                if (state[who[k]] <= State.HEATING)
                {
                    keep.Append(who[k]);
                    keepRate.Append(rate[k]);
                }
            }
            return Gd.Arr(keep, keepRate);
        }

        public void _Heating(long i, double dt)
        {
            if (_warm[i] != _pass)
            {
                heat[i] -= Num.F(cfg["cool_rate"]) * dt;
                if (heat[i] <= 0.0)
                {
                    heat[i] = 0.0;
                    _Drop(i, State.INTACT);
                }
                return;
            }
            if (heat[i] < 1.0)
            {
                return;
            }
            GArray<Variant> glow = cfg["glow_seconds"];
            state[i] = State.GLOWING;
            timer[i] = _rng.RandfRange(Num.F(glow[0]), Num.F(glow[1]));
            sim.events.Append(new GDict { { "type", "fire_glow" }, { "building", i }, { "seconds", timer[i] } });
        }

        public void _Burn(long i)
        {
            var b = sim.buildings[i];
            state[i] = State.BURNING;
            heat[i] = 1.0;
            timer[i] = Num.F(cfg["burn_seconds"]) + Num.F(cfg["burn_per_floor"]) * b.height;
            _active[i] = true;
            sim.events.Append(new GDict { { "type", "fire_burning" }, { "building", i }, { "seconds", timer[i] } });
        }
        // It burns out: its ground floors (burn_out_floors) give way over burn_out_seconds, the downwind
        // side first, so the rest drops and topples toward it like a smashed building whose base was
        // eaten (D-129); no burning shell is left (#111). Everything it drops pays burn_pay of a smash
        // times the conflagration, and far_pay of that when the kaiju is far away.

        public void _BurnOut(long i, double dt)
        {
            var b = sim.buildings[i];
            double share = Num.F(cfg["burn_pay"]) * conflagration;
            var far = new Vector2(b.x, b.z).DistanceTo(sim.kaijuPos) > Num.F(cfg["far_radius"]);
            if (far)
            {
                share *= Num.F(cfg["far_pay"]);
            }
            b.payShare = share;
            var cells = GroundCells(i);
            long steps = Num.I(cfg["burn_out_steps"]);
            long every = Gd.Maxi(1, Gd.Roundi(Num.F(cfg["burn_out_seconds"]) / steps / dt));
            _crumbling[i] = Gd.Arr(cells, Gd.Ceili(cells.Size() / Gd.Float(steps)), every, 1);
            burntOut += 1;
            conflagration = Gd.Minf(Num.F(cfg["conflag_max"]), conflagration + Num.F(cfg["conflag_step"]));
            sim.events.Append(new GDict { { "type", "fire_burnt" }, { "building", i }, { "share", share }, { "far", far } });
            _Crumble(i);
        }
        // The cells of building i's burn_out_floors lowest floors in the order they give way: the
        // downwind side first (then by floor, x and z, the same every run).

        public GArray<Vector3i> GroundCells(long i)
        {
            var b = sim.buildings[i];
            GArray<Vector3i> cells = new GArray<Vector3i>();
            foreach (long y in Gd.Range(Gd.Mini(Num.I(cfg["burn_out_floors"]), b.height)))
            {
                foreach (long x in Gd.Range(b.w))
                {
                    foreach (long z in Gd.Range(b.d))
                    {
                        cells.Append(new Vector3i(x, y, z));
                    }
                }
            }
            var mid = new Vector2(b.w, b.d) * 0.5;
            var key = new Callable(a_ =>
            {
                Vector3i c = a_[0];
                return (new Vector2(c.x, c.z) + Vector2.ONE * 0.5 - mid).Dot(wind);
            });
            cells.SortCustom(new Callable(a_ =>
            {
                Vector3i p = a_[0];
                Vector3i q = a_[1];
                double kp = key.Call(p);
                double kq = key.Call(q);
                if (kp != kq)
                {
                    return kp > kq;
                }
                return new Vector3i(p.y, p.x, p.z) < new Vector3i(q.y, q.x, q.z);
            }));
            return cells;
        }
        // Every few ticks the next batch of a building giving way breaks (one support check a batch,
        // burn_out_steps in all); once none stand it is burnt out.

        public void _Crumble(long i)
        {
            GArray<Variant> entry = _crumbling[i];
            entry[3] = Num.I(entry[3]) - 1;
            if (Num.I(entry[3]) > 0)
            {
                return;
            }
            entry[3] = entry[2];
            GArray<Vector3i> cells = entry[0];
            GArray<Vector3i> batch = new GArray<Vector3i>();
            while (!cells.IsEmpty() && batch.Size() < Num.I(entry[1]))
            {
                batch.Append(cells.PopFront());
            }
            var amounts = new PackedFloat32Array();
            amounts.Resize(batch.Size());
            amounts.Fill(Num.F(cfg["burn_out_damage"]));
            sim.DamageCells(i, batch, amounts);
            if ((cells.IsEmpty() || sim.buildings[i].frame.aliveCount == 0))
            {
                _Drop(i, State.BURNT);
            }
        }
        // Building `i` stands whole again (Endless regrowth): no fire state is left on it, so it can burn,
        // heat its neighbours and pay a full smash once more. The neighbour lists are rebuilt on demand.

        public void ResetBuilding(long i)
        {
            state[i] = State.INTACT;
            heat[i] = 0.0;
            timer[i] = 0.0;
            _active.Erase(i);
            _crumbling.Erase(i);
            _near.Clear();
            sim.buildings[i].payShare = 1.0;
        }

        public void _Drop(long i, long to)
        {
            state[i] = to;
            _active.Erase(i);
            _crumbling.Erase(i);
        }

        public bool _CanBurn(long i)
        {
            var b = sim.buildings[i];
            return b.frame.aliveCount > 0 && ((b.landmark == "" || cfg["spread_landmarks"] == true));
        }
        // The buildings within reach of i and the heat a second each takes from it burning: gap
        // closeness x Five-Alarm x Fire Front downwind x the neighbour's flammability.

        public GArray<Variant> _Neighbours(long i)
        {
            var who = new PackedInt32Array();
            var rate = new PackedFloat32Array();
            var from = _Rect(i);
            double @base = Num.F(cfg["heat_rate"]) * (1.0 + sim.Stat("fire_rate"));
            GArray<Variant> flammable = cfg["flammability"];
            foreach (long j in _Around(from, _reach))
            {
                if ((j == i || !_CanBurn(j)))
                {
                    continue;
                }
                double gap = _Gap(from, _Rect(j));
                if (gap > _reach)
                {
                    continue;
                }
                var b = sim.buildings[j];
                var to = (new Vector2(b.x, b.z) - from.GetCenter()).Normalized();
                double downwind = 1.0 + sim.Stat("fire_wind") * Gd.Maxf(0.0, to.Dot(wind));
                double burns = Num.F(flammable[Gd.Posmod(b.style, flammable.Size())]);
                who.Append(j);
                rate.Append(@base * (1.0 - gap / Gd.Maxf(_reach, 0.001)) * downwind * burns);
            }
            return Gd.Arr(who, rate);
        }
        // Every building whose footprint shares a grid cell with `area` grown by `margin`, once each,
        // lowest index first (the same order every run).

        public PackedInt32Array _Around(Rect2 area, double margin)
        {
            var r = area.Grow(margin);
            GDict seen = new GDict();
            foreach (long x in Gd.Range(Gd.Floori(r.position.x / _cell), Gd.Floori(r.end.x / _cell) + 1))
            {
                foreach (long z in Gd.Range(Gd.Floori(r.position.y / _cell), Gd.Floori(r.end.y / _cell) + 1))
                {
                    foreach (long j in Gd.Iter(_grid.Get(new Vector2i(x, z), new PackedInt32Array())))
                    {
                        seen[j] = true;
                    }
                }
            }
            var @out = new PackedInt32Array(seen.Keys());
            @out.Sort();
            return @out;
        }

        public Rect2 _Rect(long i)
        {
            var b = sim.buildings[i];
            return new Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d);
        }
        // The ground gap between two footprints (0 when they touch or overlap).

        public static double _Gap(Rect2 a, Rect2 b)
        {
            double dx = Gd.Maxf(0.0, Gd.Maxf(a.position.x - b.end.x, b.position.x - a.end.x));
            double dz = Gd.Maxf(0.0, Gd.Maxf(a.position.y - b.end.y, b.position.y - a.end.y));
            return new Vector2(dx, dz).Length();
        }

        void _InitFields()
        {
        }
    }
}
