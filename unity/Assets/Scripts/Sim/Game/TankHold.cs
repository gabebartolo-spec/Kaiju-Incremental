// Generated from sim/tank_hold.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TankHold : RefCounted
    {
        public static implicit operator TankHold(Variant v) => (TankHold)v.Obj;

        // What a flung tank does to a building it meets (director 2026-11-01: "when a tank hits a building
        // it needs to carve it, it would be really cool if a tank could even wedge into and get stuck in
        // the bigger buildings or if they land ontop of a building they could crush it"; picked "Tank-sized
        // hole", "Too big to punch through", "Punch through floors"). A tank flying into a wall bores a
        // hull-sized tunnel (bore_half to each side, wall_floors high), bore_min deep at any speed and
        // bore_per_speed deeper per unit of ground speed up to bore_max. Out the far side it flies on at
        // bore_keep of its speed; else it sticks nose-in at the tunnel's end, wedged. A tank coming down
        // on a roof caves in roof_per_speed floors per unit of fall speed (roof_min..roof_max) under its
        // hull and ends inside. A wreck left above the street is a husk (TankFlight.husks): it stays
        // where it came to rest and falls when the floor under it breaks; a wedged one also stays at
        // street level while the floors over it stand. Numbers are army.flight.hold in data/tuning.json.
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Wrecks resting above the street or wedged in a building (Army.clear_dead hands them over).
        public GArray<RampageSim.Tank> husks = new GArray<RampageSim.Tank>();
        // Tunnels bored, tanks wedged, tanks out a building's far side, roofs caved in (fixtures).
        public long bored = 0;
        public long wedged = 0;
        public long through = 0;
        public long punched = 0;
        // tank id -> true
        public GDict _wedged = new GDict();

        public TankHold(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
        }
        // The top of the highest standing floor at `pos` at or below height `y` (0: the street).

        public double FloorUnder(Vector2 pos, double y)
        {
            foreach (long i in sim.grid.Around(pos, 0.0))
            {
                var b = sim.buildings[i];
                long lx = Gd.Floori(pos.x - (b.x - b.w * 0.5));
                long lz = Gd.Floori(pos.y - (b.z - b.d * 0.5));
                if (lx >= 0 && lz >= 0 && lx < b.w && lz < b.d)
                {
                    return Gd.Float(Gd.Maxi(0, b.frame.TopBelow(lx, lz, Gd.Floori(y) - b.@base) + 1 + b.@base));
                }
            }
            return 0.0;
        }
        // Is there a standing chunk at `pos`, height `y`?

        public bool Solid(Vector2 pos, double y)
        {
            if (y < 0.0)
            {
                return true;
            }
            foreach (long i in sim.grid.Around(pos, 0.0))
            {
                var b = sim.buildings[i];
                var c = new Vector3i(Gd.Floori(pos.x - (b.x - b.w * 0.5)), Gd.Floori(y) - b.@base, Gd.Floori(pos.y - (b.z - b.d * 0.5)));
                if (c.x >= 0 && c.z >= 0 && c.x < b.w && c.z < b.d)
                {
                    return c.y >= 0 && b.frame.Alive(c);
                }
            }
            return false;
        }
        // A wall met at `at`, height `y`, at ground velocity `flat`: bores the tunnel. True if the tank
        // came out the far side (put at the exit, it flies on at bore_keep); false if it is wedged at the
        // tunnel's end.

        public bool Bore(RampageSim.Tank tank, Vector2 at, double y, Vector2 flat)
        {
            var way = flat.Normalized();
            double depth = Gd.Clampf(Num.F(cfg["bore_min"]) + flat.Length() * Num.F(cfg["bore_per_speed"]), Num.F(cfg["bore_min"]), Num.F(cfg["bore_max"]));
            long floorAt = Gd.Maxi(0, Gd.Floori(y));
            double half = Num.F(cfg["bore_half"]);
            _Break(at + way * depth * 0.5, new Callable(a_ =>
            {
                Vector2 p = a_[0];
                var d = p - at;
                return d.Dot(way) >= -0.5 && d.Dot(way) <= depth && Gd.Absf(d.Cross(way)) <= half;
            }), depth * 0.5 + half + 1.0, new Vector2i(floorAt, floorAt + Num.I(sim.flight.cfg["wall_floors"])));
            bored += 1;
            var exit = at + way * (depth + 0.5);
            if (!(Solid(exit, y + Num.F(sim.flight.cfg["clearance"]))))
            {
                through += 1;
                // out the far side, as a wedged tank is put at its tunnel's end
                tank.pos = exit;
                var keep = flat * Num.F(cfg["bore_keep"]);
                tank.vel = new Vector3(keep.x, tank.vel.y, keep.y);
                return true;
            }
            tank.pos = at + way * Gd.Maxf(0.5, depth - Num.F(cfg["hull_half_length"]));
            tank.height = FloorUnder(tank.pos, y + Num.F(sim.flight.cfg["clearance"]));
            tank.vel = Vector3.ZERO;
            tank.spin = Vector3.ZERO;
            tank.flying = false;
            tank.wrecked = true;
            _wedged[tank.id] = true;
            wedged += 1;
            sim.events.Append(new GDict { { "type", "tank_wedged" }, { "tank", tank.id }, { "at", tank.pos }, { "height", tank.height } });
            return false;
        }
        // A tank come down on a roof at `fall` speed: caves its floors in under the hull; it ends on
        // whatever floor still stands below them.

        public void Punch(RampageSim.Tank tank, double fall)
        {
            long top = Gd.Floori(tank.height);
            if (top <= 0)
            {
                return;
            }
            long floors = Gd.Clampi(Gd.Ceili(fall * Num.F(cfg["roof_per_speed"])), Num.I(cfg["roof_min"]), Num.I(cfg["roof_max"]));
            var at = tank.pos;
            double half = Num.F(cfg["bore_half"]);
            _Break(at, new Callable(a_ =>
            {
                Vector2 p = a_[0];
                return Gd.Absf(p.x - at.x) <= half && Gd.Absf(p.y - at.y) <= half;
            }), half + 1.0, new Vector2i(Gd.Maxi(0, top - floors), top));
            punched += 1;
            tank.height = FloorUnder(at, tank.height);
            sim.events.Append(new GDict { { "type", "tank_punched" }, { "tank", tank.id }, { "at", at }, { "height", tank.height }, { "floors", floors } });
        }
        // Is the wreck `tank` kept as a husk rather than cleared where it lies?

        public bool Holds(RampageSim.Tank tank)
        {
            return (tank.height > 0.0 || _wedged.Has(tank.id));
        }
        // Husks whose floor broke fall to the next one; one back on the street, and no longer under a
        // standing building if it was wedged, is gone (tank_husk_down).

        public void Step(double dt)
        {
            if (husks.IsEmpty())
            {
                return;
            }
            double g = Num.F(sim.flight.cfg["gravity"]);
            double clear = Num.F(sim.flight.cfg["clearance"]);
            GArray<RampageSim.Tank> kept = new GArray<RampageSim.Tank>();
            foreach (RampageSim.Tank husk in husks)
            {
                double below = FloorUnder(husk.pos, husk.height + clear);
                if (below < husk.height)
                {
                    husk.vel.y -= g * dt;
                    husk.height = Gd.Maxf(below, husk.height + husk.vel.y * dt);
                    if (husk.height <= below)
                    {
                        husk.vel = Vector3.ZERO;
                    }
                }
                var roofed = (_wedged.Has(husk.id) && Solid(husk.pos, husk.height + Num.F(sim.flight.cfg["wall_floors"]) + 0.5));
                if ((husk.height > 0.0 || roofed))
                {
                    kept.Append(husk);
                    continue;
                }
                _wedged.Erase(husk.id);
                sim.events.Append(new GDict { { "type", "tank_husk_down" }, { "tank", husk.id }, { "x", husk.pos.x }, { "z", husk.pos.y } });
            }
            husks = kept;
        }
        // Breaks every standing chunk on world floors `floors` (lo..hi-1) whose centre `inside` takes,
        // among the buildings within `reach` of `centre`: bore_damage each, past any building's toughness.

        public void _Break(Vector2 centre, Callable inside, double reach, Vector2i floors)
        {
            double amount = Num.F(cfg["bore_damage"]);
            foreach (long i in sim.grid.Around(centre, reach))
            {
                var b = sim.buildings[i];
                if (b.frame.aliveCount == 0)
                {
                    continue;
                }
                var local = b.LocalFloors(floors);
                GArray<Vector3i> cells = new GArray<Vector3i>();
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
                                if (Gd.Truthy(inside.Call(new Vector2(p.x, p.z))))
                                {
                                    cells.Append(c);
                                }
                            }
                        }
                    }
                }
                var amounts = new PackedFloat32Array();
                amounts.Resize(cells.Size());
                amounts.Fill(amount);
                sim.DamageCells(i, cells, amounts);
            }
        }

        void _InitFields()
        {
        }
    }
}
