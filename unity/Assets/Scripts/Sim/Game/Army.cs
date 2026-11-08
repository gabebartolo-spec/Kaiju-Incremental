// Generated from sim/army.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Army : RefCounted
    {
        public static implicit operator Army(Variant v) => (Army)v.Obj;

        // The tanks: they arrive faster the more the city falls, drive in by road to firing positions
        // (Convoy, D-066) and shell the kaiju when they have a clear line of
        // fire. Coated tanks burn. Part of RampageSim; the tanks themselves
        // live in sim.tanks. Draws from the army's own seeded stream.
        // Rooftop defenders (D-063): armed citizens hold some of the taller roofs from the start and
        // fire rifles at the kaiju in range, a sting far below a tank shell, scaled by its size tier and
        // by the same threat the tanks' armour grows with. A squad dies when the roof chunk under it
        // goes (broken, dropped or toppled) or under any attack whose splash reaches its roof floor.
        // Armed citizens holding a roof: they stand on chunk `cell` of building `building`.

        public class Squad : RefCounted
        {
            public static implicit operator Squad(Variant v) => (Squad)v.Obj;

            public long id;
            public long building;
            public Vector3i cell;
            public Vector2 pos;
            public double cooldown;
            public bool dead = false;

            void _InitFields()
            {
            }
            public Squad() { _InitFields(); }
        }
        public RampageSim sim;
        public GDict cfg = new GDict();
        public GDict rooftop = new GDict();
        public GArray<Army.Squad> squads = new GArray<Army.Squad>();
        // Rooftop volleys fired this run (D-076: how often the player is shot at).
        public long volleys = 0;
        // tank shells that missed the kaiju and landed in the city
        public long misses = 0;
        public long rooftopsDestroyed = 0;
        // Road movement and firing positions (D-066).
        public Convoy convoy;
        // The Anti Kaiju Taskforce's agents (D-137): they come in above the tanks and police.
        public Taskforce taskforce;
        public RandomNumberGenerator _rng;
        // Each squad's next shot comes a seeded, ragged while later (D-076: no unison).
        public RandomNumberGenerator _ragged;
        // which shells miss, and where they land (StrayShell)
        public RandomNumberGenerator _aim;
        // missed shells in flight: {at, left (seconds to land)}
        public GArray<GDict> _strays = new GArray<GDict>();
        public double _spawnTimer;
        public long _nextId = 0;
        public long _column = -1;
        public long _columnLeft = 0;
        public long _columnEntry = -1;

        public Army(RampageSim pSim, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = sim.army;
            rooftop = cfg["rooftop"];
            _rng = rng;
            _spawnTimer = Num.F(cfg["start_interval"]);
            GDict convoyCfg = cfg["convoy"];
            convoy = new Convoy(sim, convoyCfg);
            _PlaceSquads(Seeds.Derive(rng, 0x2007L));
            _ragged = Seeds.Derive(rng, 0x2008L);
            taskforce = new Taskforce(sim, Seeds.Derive(rng, 0x7FL));
            _aim = Seeds.Derive(rng, 0x2009L);
        }

        public void Step(double dt)
        {
            _LandStrays(dt);
            _spawnTimer -= dt;
            if (_spawnTimer <= 0.0 && _Spawn())
            {
                _spawnTimer = Gd.Maxf(Num.F(cfg["min_interval"]), Num.F(cfg["start_interval"]) - Num.F(cfg["escalation_per_chunk"]) * sim.Escalation());
            }
            double reach = convoy.Reach();
            var atHead = convoy.posts.Head();
            convoy.Step(dt);
            taskforce.Step(dt);
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                if (!_GunReady(tank, dt))
                {
                    continue;
                }
                // range is measured to the body line, as the tank's post is (FiringPosts.aim_point)
                var aim = convoy.posts.AimPoint(tank.pos, atHead);
                double dist = tank.pos.DistanceTo(aim);
                if (dist <= reach + 1.0 && convoy.ClearLine(tank.pos, aim))
                {
                    tank.cooldown = Num.F(cfg["fire_interval"]);
                    Shoot(tank, dist, reach);
                }
            }
            if (_StepSquads(dt))
            {
                ClearDead();
            }
        }
        // Counts down a tank's reload; true once it may fire (never while flung or toppled, TankFlight).

        public bool _GunReady(RampageSim.Tank tank, double dt)
        {
            tank.cooldown -= dt;
            return tank.cooldown <= 0.0 && !tank.flying && !tank.toppled;
        }
        // One shell at the kaiju: a hit (StrayShell.chance) does the shot's damage over that chance, so
        // the kaiju takes the shot's damage on average, as when every shell hit; a miss lands in the
        // city past the kaiju and breaks what it hits there.

        public void Shoot(RampageSim.Tank tank, double dist, double reach)
        {
            double odds = StrayShell.Chance(cfg, dist, reach);
            if (_aim.Randf() < odds)
            {
                double hurt = Num.F(cfg["tank_damage"]) - sim.Stat("armor");
                sim.hp -= Gd.Maxf(Num.F(cfg["min_damage"]), hurt) / odds;
                sim.events.Append(new GDict { { "type", "tank_fired" }, { "tank", tank.id } });
                return;
            }
            misses += 1;
            var at = StrayShell.Landing(sim, _aim);
            sim.events.Append(new GDict { { "type", "tank_fired" }, { "tank", tank.id }, { "at", at }, { "miss", true } });
            _strays.Append(new GDict { { "at", at }, { "left", Num.F(cfg["shell_flight"]) } });
        }
        // A missed shell lands when its flight is over (the view draws the tracer for the same time):
        // stray_landed, then what it breaks.

        public void _LandStrays(double dt)
        {
            foreach (long i in Gd.Range(_strays.Size() - 1, -1, -1))
            {
                GDict stray = _strays[i];
                stray["left"] = Num.F(stray["left"]) - dt;
                if (Num.F(stray["left"]) > 0.0)
                {
                    continue;
                }
                Vector2 at = stray["at"];
                _strays.RemoveAt(i);
                sim.events.Append(new GDict { { "type", "stray_landed" }, { "at", at } });
                StrayShell.Land(sim, at);
            }
        }
        // Each squad whose roof still stands fires a volley every fire_interval while the kaiju is in
        // range, measured from the edge of its stomp as the tanks' is (D-076: from its centre, a grown
        // kaiju's own reach killed squads before they got a shot). True when a squad lost its roof
        // (clear_dead removes it and pays its biomass).

        public bool _StepSquads(double dt)
        {
            var lost = false;
            double reach = Num.F(rooftop["range"]) + sim.StompRadius();
            foreach (Army.Squad squad in squads)
            {
                if (!(sim.buildings[squad.building].frame.Alive(squad.cell)))
                {
                    squad.dead = true;
                    lost = true;
                    continue;
                }
                squad.cooldown -= dt;
                if ((squad.cooldown > 0.0 || squad.pos.DistanceTo(sim.kaijuPos) > reach))
                {
                    continue;
                }
                squad.cooldown = _NextShot();
                sim.hp -= Volley();
                volleys += 1;
                sim.events.Append(new GDict { { "type", "rooftop_fired" }, { "squad", squad.id } });
            }
            return lost;
        }
        // A tank joins the current column at its road entry, or starts a new column on a seeded
        // bearing (D-039: in a city grown past spawn_radius, round the kaiju). False when that way in
        // is jammed too: it tries again next step.

        public bool _Spawn()
        {
            if (Endless.TanksFull(sim))
            {
                return false;
            }
            var at = new Vector2(Gd.INF, Gd.INF);
            if (_columnLeft > 0)
            {
                at = convoy.Enter(_nextId, _column, _columnEntry);
            }
            // a new column, or the way in is still taken: the next column sets off
            if (at.x == Gd.INF)
            {
                _column += 1;
                _columnLeft = Num.I(convoy.cfg["column"]);
                _columnEntry = convoy.PickEntry(_rng.Randf() * Gd.TAU);
                at = convoy.Enter(_nextId, _column, _columnEntry);
            }
            if (at.x == Gd.INF)
            {
                return false;
            }
            _columnLeft -= 1;
            var tank = new RampageSim.Tank();
            tank.id = _nextId;
            _nextId += 1;
            tank.pos = at;
            tank.cooldown = Num.F(cfg["fire_interval"]);
            sim.tanks.Append(tank);
            sim.events.Append(new GDict { { "type", "tank_spawned" }, { "tank", tank.id } });
            return true;
        }

        public void ClearDead()
        {
            GArray<RampageSim.Tank> alive = new GArray<RampageSim.Tank>();
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                if (!tank.wrecked)
                {
                    alive.Append(tank);
                }
                else
                {
                    sim.tanksDestroyed += 1;
                    sim.rubble += Num.F(cfg["tank_rubble"]) * sim.Stat("rubble_mult");
                    // wedged, or on a floor above the street: stays
                    var husk = sim.flight.hold.Holds(tank);
                    if (husk)
                    {
                        sim.flight.hold.husks.Append(tank);
                    }
                    sim.events.Append(new GDict { { "type", "tank_destroyed" }, { "tank", tank.id }, { "x", tank.pos.x }, { "y", tank.height }, { "z", tank.pos.y }, { "husk", husk } });
                }
            }
            sim.tanks = alive;
            _ClearDeadSquads();
        }

        public void _ClearDeadSquads()
        {
            if (squads.Any(new Callable(a_ =>
            {
                Army.Squad squad = a_[0];
                return squad.dead;
            })))
            {
                GArray<Army.Squad> holding = new GArray<Army.Squad>();
                foreach (Army.Squad squad in squads)
                {
                    if (!squad.dead)
                    {
                        holding.Append(squad);
                        continue;
                    }
                    rooftopsDestroyed += 1;
                    sim.rubble += _ByTier("rooftop_rubble") * sim.Stat("rubble_mult");
                    var at = sim.buildings[squad.building].ChunkWorld(squad.cell);
                    sim.events.Append(new GDict { { "type", "rooftop_destroyed" }, { "squad", squad.id }, { "x", at.x }, { "y", at.y + 0.5 }, { "z", at.z } });
                }
                squads = holding;
            }
        }
        // Seconds to a squad's next volley: fire_interval give or take interval_jitter of it, evenly
        // (the mean stays fire_interval), so squads never fall into step: improvised, not drilled.

        public double _NextShot()
        {
            double jitter = Num.F(rooftop["interval_jitter"]) * (_ragged.Randf() * 2.0 - 1.0);
            return Num.F(rooftop["fire_interval"]) * (1.0 + jitter);
        }
        // How hard the rooftop squads' volleys sting: more the more of the city has fallen (their
        // damage, never how tough anything is: no unit has hit points, D-437).

        public double ThreatScale()
        {
            return 1.0 + Num.F(cfg["threat_per_chunk"]) * sim.Escalation();
        }
        // One squad's volley at the kaiju: the size tier's sting, grown by the threat.

        public double Volley()
        {
            return _ByTier("damage_by_tier") * ThreatScale();
        }
        // A rooftop entry for the kaiju's size tier (tiers past the list use its last entry).

        public double _ByTier(string key)
        {
            GArray<Variant> list = rooftop[key];
            return Num.F(list[Gd.Clampi(sim.SizeTier() - 1, 0, list.Size() - 1)]);
        }
        // Squads take some of the arena's roofs min_height floors and up, each with `chance`, visited in
        // a seeded order so they spread over the whole arena, up to the size tier's cap (a backdrop lot
        // past the arena is out of the kaiju's reach, so a squad there never fires). A squad keeps off
        // the corner where a roof's stair hut stands.

        public void _PlaceSquads(RandomNumberGenerator rng)
        {
            long cap = Gd.Roundi(_ByTier("max_by_tier"));
            foreach (long i in _TallRoofs(rng))
            {
                if (squads.Size() >= cap)
                {
                    break;
                }
                if (rng.Randf() >= Num.F(rooftop["chance"]))
                {
                    continue;
                }
                var b = sim.buildings[i];
                var cell = new Vector3i(rng.RandiRange(0, b.w - 1), b.height - 1, rng.RandiRange(0, b.d - 1));
                if (b.w >= 3 && b.d >= 3 && cell.x < 2 && cell.z < 2)
                {
                    cell = new Vector3i(b.w - 1, cell.y, b.d - 1);
                }
                // The column's real roof: a setback or a cut-out leaves some columns lower or empty, and a
                // squad never stands in the air over one.
                long top = b.frame.TopBelow(cell.x, cell.z, b.height);
                if (top < Num.I(rooftop["min_height"]) - 1)
                {
                    continue;
                }
                cell.y = top;
                var squad = new Squad();
                squad.id = squads.Size();
                squad.building = i;
                squad.cell = cell;
                var at = b.ChunkWorld(cell);
                squad.pos = new Vector2(at.x, at.z);
                squad.cooldown = rng.Randf() * Num.F(rooftop["fire_interval"]);
                squads.Append(squad);
            }
        }
        // The arena's buildings min_height floors and up, in a seeded order (Fisher-Yates on the army's
        // own stream).

        public GArray<long> _TallRoofs(RandomNumberGenerator rng)
        {
            GArray<long> tall = new GArray<long>();
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                var b = sim.buildings[i];
                if (b.inArena && b.height >= Num.I(rooftop["min_height"]))
                {
                    tall.Append(i);
                }
            }
            foreach (long n in Gd.Range(tall.Size() - 1, 0, -1))
            {
                long k = rng.RandiRange(0, n);
                long swap = tall[n];
                tall[n] = tall[k];
                tall[k] = swap;
            }
            return tall;
        }
        // An attack on floors y_lo..y_hi-1 kills every squad whose roof floor it reaches and whose
        // spot its force touches; then the dead tanks and squads are cleared and paid for.

        public void Splash(Callable force, long yLo, long yHi)
        {
            foreach (Army.Squad squad in squads)
            {
                if (squad.cell.y >= yLo && squad.cell.y < yHi)
                {
                    double k = force.Call(squad.pos, Num.F(rooftop["radius"]));
                    squad.dead = (squad.dead || k > 0.0);
                }
            }
            ClearDead();
        }

        void _InitFields()
        {
        }
    }
}
