// Generated from sim/water_sim.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class WaterSim : RefCounted
    {
        public static implicit operator WaterSim(Variant v) => (WaterSim)v.Obj;

        // The city's water as a liquid (director 2026-10-31: "make the water a real physical thing ...
        // make it act like water should"; "real splash physics reacting dynamically to things which
        // disturb the water"): the bay and the river are each a grid of water columns (tuning
        // "water_sim" "cell" metres square) on the sim's own floor (CityHarbour.floor_at, the river's
        // channel bed), moved by the shallow-water equations as virtual pipes between neighbouring
        // columns: water runs downhill from a higher surface to a lower one, so a push makes a real wave
        // that travels at the speed its depth gives it (sqrt(g * depth)), slows and steepens over the
        // shelf, bounces off the quays and banks, runs up the sand and drains back. Inside the bay
        // nothing is added or lost: each column holds its depth of water and the pipes only move it; at
        // the bay's mouth (row 0) water runs out to the open sea at the wave's own speed, so a wave
        // leaves there instead of bouncing back.
        //
        // What disturbs it: the kaiju's body (its submerged column stands in the water, so where it
        // walks it lifts the surface ahead of it and the water closes in behind: a bow wave and a wake),
        // each stomp in the water and the rise from the sea (a volume thrown out of a disc onto its rim:
        // a crater and a ring wave, with a splash event for the spray), and anything else through
        // disturb(). Only an active window round the disturbance is stepped (the rest is at rest); it
        // grows a column a step each way until it holds the whole basin, so a wave runs as far as the
        // water does (director 2026-10-31: the window was capped at 80 m, its edge a wall, so the waves
        // piled up in a box), and sleeps once they die down (tuning friction). The native core
        // (KaijuWater) steps it when the extension is there, the same floats as the GDScript pipes.
        // Fire is untouched: the water's puts-out stays where it was.
        public const double G = 9.8;
        public const long SPLASHES_KEPT = 16;
        // a floor this far over the surface: never wet
        public const double WALL = 1000.0;
        // One body of water (the bay, the river): a grid of columns (sim/water_basin.gd).
        public GArray<WaterBasin> basins = new GArray<WaterBasin>();
        // Splashes this step, for the view's spray: {"pos": Vector3, "size": metres}.
        public GArray<GDict> splashes = new GArray<GDict>();
        // Step with the native core when the extension has it (a check turns it off to compare).
        public bool useNative = true;
        public GDict _cfg = new GDict();
        public bool _surfaced = false;
        // the body has stood in the water once (its first place lies still)
        public bool _placed = false;
        // seconds to the next ripple while the body holds under
        public double _ripple = 0.0;
        // the sub-step being taken: its window, length (s) and flow kept
        public Rect2i _r = new Rect2i();
        public double _h = 0.0;
        public double _keep = 1.0;
        // KaijuWater, or null: the GDScript pipes
        public RefCounted _native;

        public WaterSim(GDict city, GDict tuning)
        {
            _InitFields();
            _cfg = tuning["water_sim"];
            if (ClassDB.ClassExists("KaijuWater"))
            {
                _native = ClassDB.Instantiate("KaijuWater");
            }
            GDict plan = CityGen.Map(city);
            double cell = Num.F(_cfg["cell"]);
            if (plan.Has("harbour"))
            {
                var bay = _Bay(plan, city, cell);
                bay.open = true;
                basins.Append(bay);
            }
            var channels = CityRiver.Channels(plan, city);
            if (!channels.IsEmpty())
            {
                basins.Append(_River(channels, city, cell));
            }
        }
        // The bay: the harbour from its mouth to run_up metres up the beach (the floor decides the rest:
        // the street and the quays stand over the water, so they are its walls).

        public static WaterBasin _Bay(GDict plan, GDict city, double cell)
        {
            GDict b = plan["harbour"];
            Rect2 rect = b["rect"];
            double far = Num.F(b["quay_z"]);
            foreach (Vector2 p in CityHarbour.Arc(plan, city))
            {
                far = Gd.Maxf(far, p.y);
            }
            double z0 = Num.F(b["mouth"]);
            var basin = new WaterBasin(new Vector2(rect.position.x, z0), cell, new Vector2i(Gd.Ceili(rect.size.x / cell), Gd.Ceili((far - z0) / cell) + 1), CityHarbour.Sea(city));
            foreach (long k in Gd.Range(basin.nx * basin.nz))
            {
                var p = basin.Centre(new Vector2i(k % basin.nx, k / basin.nx));
                double bed = (CityHarbour.Holds(plan, p) ? CityHarbour.FloorAt(plan, city, p) : WALL);
                basin.floorY[k] = bed;
                basin.depth[k] = Gd.Maxf(0.0, basin.rest - bed);
            }
            return basin;
        }
        // The river: every channel's bed (city river_depth + wade_depth under the street), the banks
        // between them walls.

        public static WaterBasin _River(GArray<Rect2> channels, GDict city, double cell)
        {
            var whole = channels[0];
            foreach (Rect2 c in channels)
            {
                whole = whole.Merge(c);
            }
            double rest = -Num.F(city["river_depth"]);
            double bed = rest - Num.F(city["wade_depth"]);
            var basin = new WaterBasin(whole.position, cell, new Vector2i(Gd.Ceili(whole.size.x / cell), Gd.Ceili(whole.size.y / cell)), rest);
            foreach (long k in Gd.Range(basin.nx * basin.nz))
            {
                var p = basin.Centre(new Vector2i(k % basin.nx, k / basin.nx));
                var wet = channels.Any(new Callable(a_ =>
                {
                    Rect2 c = a_[0];
                    return c.HasPoint(p);
                }));
                basin.floorY[k] = (wet ? bed : WALL);
                basin.depth[k] = (wet ? rest - bed : 0.0);
            }
            return basin;
        }
        // The basin holding p, or null.

        public WaterBasin BasinAt(Vector2 p)
        {
            foreach (WaterBasin basin in basins)
            {
                var c = basin.At(p);
                if (c.x >= 0 && c.y >= 0 && c.x < basin.nx && c.y < basin.nz)
                {
                    if (basin.floorY[c.y * basin.nx + c.x] < basin.rest)
                    {
                        return basin;
                    }
                }
            }
            return null;
        }
        // The surface's height at p (world y), or NAN where there is no water.

        public double SurfaceAt(Vector2 p)
        {
            var basin = BasinAt(p);
            if (basin == null)
            {
                return Gd.NAN;
            }
            var c = basin.At(p);
            return basin.rest + basin.Lift(c.y * basin.nx + c.x);
        }
        // Throws `volume` cubic metres of water out of the disc of `radius` at p onto its rim (a stomp,
        // a body falling in, the rise): a crater that the water rushes back into, and a ring wave.
        // Returns false where there is no water.

        public bool Disturb(Vector2 p, double volume, double radius)
        {
            var basin = BasinAt(p);
            if (basin == null)
            {
                return false;
            }
            double reach = radius * Num.F(_cfg["rim"]);
            var c = basin.At(p);
            long n = Gd.Ceili(reach / basin.cell) + 1;
            GArray<Variant> rings = _Rings(basin, p, new Vector2(radius, reach));
            GArray<long> inner = rings[0];
            GArray<long> rim = rings[1];
            if (inner.IsEmpty())
            {
                return false;
            }
            double area = basin.cell * basin.cell;
            double taken = 0.0;
            double each = volume / (area * inner.Size());
            foreach (long k in inner)
            {
                double @out = Gd.Minf(each, basin.depth[k]);
                basin.depth[k] -= @out;
                taken += @out * area;
            }
            if (rim.IsEmpty())
            {
                rim = inner;
            }
            foreach (long k in rim)
            {
                basin.depth[k] += taken / (area * rim.Size());
            }
            basin.Wake(new Rect2i(c - new Vector2i(n, n), new Vector2i(n, n) * 2 + Vector2i.ONE));
            return true;
        }
        // The wet columns round p: [those within reach.x, those beyond it out to reach.y].

        public static GArray<Variant> _Rings(WaterBasin basin, Vector2 p, Vector2 reach)
        {
            GArray<long> inner = new GArray<long>();
            GArray<long> rim = new GArray<long>();
            var c = basin.At(p);
            long n = Gd.Ceili(reach.y / basin.cell) + 1;
            foreach (long j in Gd.Range(Gd.Maxi(0, c.y - n), Gd.Mini(basin.nz, c.y + n + 1)))
            {
                foreach (long i in Gd.Range(Gd.Maxi(0, c.x - n), Gd.Mini(basin.nx, c.x + n + 1)))
                {
                    long k = j * basin.nx + i;
                    if (basin.depth[k] <= 0.0)
                    {
                        continue;
                    }
                    double d = basin.Centre(new Vector2i(i, j)).DistanceTo(p);
                    if (d <= reach.x)
                    {
                        inner.Append(k);
                    }
                    else if (d <= reach.y)
                    {
                        rim.Append(k);
                    }
                }
            }
            return Gd.Arr(inner, rim);
        }
        // One step: the kaiju's body stands in the water; its stomps and the rise throw it; the water
        // flows. events: the sim's events this step (read for "stomp").

        public void Step(RampageSim sim, double dt, GArray<GDict> events)
        {
            // the view takes them each frame; a headless run keeps the last
            if (splashes.Size() > SPLASHES_KEPT)
            {
                splashes = splashes.Slice(-SPLASHES_KEPT);
            }
            _Stand(sim, dt);
            double bs = sim.BodyScale();
            foreach (GDict @event in events)
            {
                if (Gd.Str(@event["type"]) != "stomp")
                {
                    continue;
                }
                Vector2 p = @event["at"];
                double r = Num.F(@event["radius"]) * Num.F(_cfg["stomp_share"]);
                if (Disturb(p, Num.F(_cfg["stomp_volume"]) * bs * bs * bs, r))
                {
                    splashes.Append(new GDict { { "pos", new Vector3(p.x, SurfaceAt(p), p.y) }, { "size", r } });
                }
            }
            // it holds under: rings spread from over it
            if (sim.emerge.active && !sim.emerge.surfaced)
            {
                _ripple -= dt;
                if (_ripple <= 0.0)
                {
                    _ripple += Num.F(_cfg["ripple_seconds"]);
                    double r = Num.F(_cfg["rise_radius"]) * bs * 0.5;
                    Disturb(sim.kaijuPos, Num.F(_cfg["ripple_volume"]) * bs * bs * bs, r);
                }
            }
            // the body breaks the surface: the fountain
            if (sim.emerge.surfaced && !_surfaced)
            {
                var p = sim.kaijuPos;
                double r = Num.F(_cfg["rise_radius"]) * bs;
                if (Disturb(p, Num.F(_cfg["rise_volume"]) * bs * bs * bs, r))
                {
                    splashes.Append(new GDict { { "pos", new Vector3(p.x, SurfaceAt(p), p.y) }, { "size", r } });
                }
            }
            _surfaced = sim.emerge.surfaced;
            foreach (WaterBasin basin in basins)
            {
                _Flow(basin, dt);
            }
        }
        // The kaiju's submerged body in the columns it stands in (body_radius x its height across, up to
        // its head or the still surface). Its first place takes the water's place (the sea over it lies
        // still); then it moves or grows at most body_rate m/s a cell, pushing the water (bow wave, wake):
        // a whole column dropped into a cell is a wall of water the pipes blow up on (20 m spikes).

        public void _Stand(RampageSim sim, double dt)
        {
            double radius = Num.F(_cfg["body_radius"]) * sim.ReachHeight();
            var p = sim.kaijuPos;
            double head = sim.standY + sim.ReachHeight();
            double rate = Num.F(_cfg["body_rate"]) * dt;
            foreach (WaterBasin basin in basins)
            {
                var c = basin.At(p);
                long n = Gd.Ceili(radius / basin.cell) + 1;
                var near = new Rect2i(c - new Vector2i(n, n), new Vector2i(n, n) * 2 + Vector2i.ONE);
                // round him and where his body still is: the rest holds none (the window cost 10 ms)
                var span = (basin.held.HasArea() ? near.Merge(basin.held) : near);
                span = span.Intersection(new Rect2i(0, 0, basin.nx, basin.nz));
                var moved = false;
                basin.held = new Rect2i();
                foreach (long j in Gd.Range(span.position.y, span.end.y))
                {
                    foreach (long i in Gd.Range(span.position.x, span.end.x))
                    {
                        long k = j * basin.nx + i;
                        double d = basin.Centre(new Vector2i(i, j)).DistanceTo(p);
                        double share = 1.0 - Gd.Smoothstep(radius * 0.6, radius, d);
                        double foot = Gd.Maxf(basin.floorY[k], sim.standY);
                        double top = Gd.Minf(basin.rest, head);
                        double want = (basin.depth[k] > 0.0 ? share * Gd.Maxf(0.0, top - foot) : 0.0);
                        if (Gd.Absf(want - basin.body[k]) > 0.0001)
                        {
                            if (!_placed)
                            {
                                basin.depth[k] = Gd.Maxf(0.0, basin.depth[k] - (want - basin.body[k]));
                                basin.body[k] = want;
                            }
                            else
                            {
                                basin.body[k] = Gd.MoveToward(basin.body[k], want, rate);
                            }
                            moved = true;
                        }
                        if (basin.body[k] > 0.0)
                        {
                            basin.Hold(new Vector2i(i, j));
                        }
                    }
                }
                if (moved)
                {
                    basin.Wake(near);
                }
            }
            _placed = true;
        }
        // The virtual pipes: each column pushes water into each lower neighbour (g * its depth * the
        // surface drop over a cell, kept by friction), never more than it holds; then every column
        // takes in what flowed to it. Sub-stepped so a wave never crosses more than a share of a cell.

        public void _Flow(WaterBasin basin, double dt)
        {
            if (!basin.active.HasArea())
            {
                return;
            }
            // The window spreads a column a step each way (waves outrun it only where they are already
            // small), out to the whole basin.
            var r = basin.active.Grow(1).Intersection(new Rect2i(0, 0, basin.nx, basin.nz));
            basin.active = r;
            double speed = Gd.Sqrt(G * Gd.Maxf(basin.Deepest(r), 0.01));
            long subs = Gd.Maxi(1, Gd.Ceili(speed * dt / (basin.cell * Num.F(_cfg["courant"]))));
            double h = dt / subs;
            double keep = Gd.Maxf(0.0, 1.0 - Num.F(_cfg["friction"]) * h);
            double stir = 0.0;
            if (useNative && _native != null)
            {
                _h = h;
                _keep = keep;
                stir = _StepNative(basin, r, subs);
            }
            else
            {
                foreach (long s in Gd.Range(subs))
                {
                    stir = _Pipes(basin, r, h, keep);
                }
            }
            if (stir < Num.F(_cfg["calm"]))
            {
                _Settle(basin, r);
            }
        }
        // All of _flow's sub-steps in one native call (KaijuWater.step: the GDScript pipes' floats).

        public double _StepNative(WaterBasin basin, Rect2i r, long subs)
        {
            GArray<Variant> @out = _native.Call("step", basin.floorY, basin.depth, basin.body, basin.flow, basin.nx, r, subs, _h, _keep, G, basin.cell, basin.rest, basin.open);
            basin.depth = @out[0];
            basin.flow = @out[1];
            return @out[2];
        }
        // One sub-step over r (its edge a wall: the basin's own, or calm water the window has not
        // reached yet); then the open sea at the mouth. Returns the biggest surface lift left in it (m).

        public double _Pipes(WaterBasin basin, Rect2i r, double h, double keep)
        {
            _r = r;
            _h = h;
            _keep = keep;
            var top = basin.floorY.Duplicate();
            foreach (long j in Gd.Range(r.position.y, r.end.y))
            {
                foreach (long k in Gd.Range(j * basin.nx + r.position.x, j * basin.nx + r.end.x))
                {
                    top[k] += basin.depth[k] + basin.body[k];
                }
            }
            foreach (long j in Gd.Range(r.position.y, r.end.y))
            {
                foreach (long i in Gd.Range(r.position.x, r.end.x))
                {
                    _Outflow(basin, top, i, j);
                }
            }
            double stir = _Drain(basin);
            _Open(basin);
            return stir;
        }
        // The bay's mouth (row 0) is open sea: water runs out of it at the wave's own speed (sqrt(g d)
        // times its lift off the still water; in where it dips), so a wave leaves there, never bouncing
        // back as off a wall (a first-order radiating edge).

        public void _Open(WaterBasin basin)
        {
            if ((!basin.open || _r.position.y > 0))
            {
                return;
            }
            var d = basin.depth;
            double gain = _h / basin.cell;
            foreach (long k in Gd.Range(_r.position.x, _r.end.x))
            {
                if (d[k] <= 0.0)
                {
                    continue;
                }
                double lift = basin.floorY[k] + d[k] - basin.rest;
                d[k] = Gd.Maxf(0.0, d[k] - gain * Gd.Sqrt(G * d[k]) * lift);
            }
        }
        // Column (i, j)'s four outflows this sub-step, pushed by the surface drop to each neighbour.

        public void _Outflow(WaterBasin basin, PackedFloat32Array top, long i, long j)
        {
            long nx = basin.nx;
            var f = basin.flow;
            long k = j * nx + i;
            double dk = basin.depth[k];
            long e = k * 4;
            if (dk <= 0.0)
            {
                foreach (long o in Gd.Range(4))
                {
                    f[e + o] = 0.0;
                }
                return;
            }
            double t = top[k];
            double a = _h * G / basin.cell * dk;
            long x1 = _r.end.x - 1;
            long y1 = _r.end.y - 1;
            double qr = (i < x1 ? Gd.Maxf(0.0, f[e] * _keep + a * (t - top[k + 1])) : 0.0);
            double ql = (i > _r.position.x ? Gd.Maxf(0.0, f[e + 1] * _keep + a * (t - top[k - 1])) : 0.0);
            double qd = (j < y1 ? Gd.Maxf(0.0, f[e + 2] * _keep + a * (t - top[k + nx])) : 0.0);
            double qu = (j > _r.position.y ? Gd.Maxf(0.0, f[e + 3] * _keep + a * (t - top[k - nx])) : 0.0);
            double @out = (qr + ql + qd + qu) * _h;
            double scale = 1.0;
            // never more than it holds
            if (@out > dk * basin.cell)
            {
                scale = dk * basin.cell / @out;
            }
            f[e] = qr * scale;
            f[e + 1] = ql * scale;
            f[e + 2] = qd * scale;
            f[e + 3] = qu * scale;
        }
        // Moves the sub-step's flows into the columns; returns the biggest surface lift left (m).

        public double _Drain(WaterBasin basin)
        {
            long nx = basin.nx;
            var f = basin.flow;
            var d = basin.depth;
            long x0 = _r.position.x;
            long x1 = _r.end.x - 1;
            long y0 = _r.position.y;
            long y1 = _r.end.y - 1;
            double gain = _h / basin.cell;
            double stir = 0.0;
            foreach (long j in Gd.Range(y0, y1 + 1))
            {
                foreach (long i in Gd.Range(x0, x1 + 1))
                {
                    long k = j * nx + i;
                    long e = k * 4;
                    double net = -(f[e] + f[e + 1] + f[e + 2] + f[e + 3]);
                    if (i > x0)
                    {
                        // the left neighbour's right pipe
                        net += f[e - 4];
                    }
                    if (i < x1)
                    {
                        // the right neighbour's left pipe
                        net += f[e + 5];
                    }
                    if (j > y0)
                    {
                        net += f[e - nx * 4 + 2];
                    }
                    if (j < y1)
                    {
                        net += f[e + nx * 4 + 3];
                    }
                    if (net == 0.0 && d[k] <= 0.0)
                    {
                        continue;
                    }
                    d[k] = Gd.Maxf(0.0, d[k] + gain * net);
                    if (d[k] > 0.0)
                    {
                        stir = Gd.Maxf(stir, Gd.Absf(basin.floorY[k] + d[k] - basin.rest));
                    }
                }
            }
            return stir;
        }
        // The window has gone still: back to rest, asleep until the next push.

        public void _Settle(WaterBasin basin, Rect2i r)
        {
            foreach (long j in Gd.Range(r.position.y, r.end.y))
            {
                foreach (long i in Gd.Range(r.position.x, r.end.x))
                {
                    long k = j * basin.nx + i;
                    if (basin.body[k] > 0.0)
                    {
                        // he still stands in it
                        return;
                    }
                }
            }
            foreach (long j in Gd.Range(r.position.y, r.end.y))
            {
                foreach (long i in Gd.Range(r.position.x, r.end.x))
                {
                    long k = j * basin.nx + i;
                    foreach (long e in Gd.Range(4))
                    {
                        basin.flow[k * 4 + e] = 0.0;
                    }
                }
            }
            basin.active = new Rect2i();
        }

        void _InitFields()
        {
        }
    }
}
