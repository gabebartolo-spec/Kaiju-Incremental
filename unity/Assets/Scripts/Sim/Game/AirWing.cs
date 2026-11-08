// Generated from sim/air_wing.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class AirWing : RefCounted
    {
        public static implicit operator AirWing(Variant v) => (AirWing)v.Obj;

        // Military helicopters (D-037): once the kaiju has done enough damage they arrive and fire on
        // it as stand-off gunships (D-183, AirFlight): they hold firing positions well beyond its
        // reach, glide between them under their own speed and turn limits and pull back when it
        // advances; now and then one makes a strafing pass within tail reach. A kaiju reaches them
        // only when it stands tall enough (a grown body or a climbed roof) or with an attack that
        // reaches the air (fire). They keep to the far side of the kaiju from the game camera
        // (`camera_bearing`, clear of `clear_arc` either side of it), so a helicopter never hangs
        // between the player and the kaiju. How one dies (D-140, D-141, D-145): any blow that reaches it
        // downs it (no hit points, D-437); a blow of at least `burst_blow` blows it apart in the air, a
        // lighter one (a glancing hit, a toppling tower sweeping through it) sends it spinning down for
        // `fall_seconds`,
        // drifting `fall_drift`, its crew sometimes bailing out by parachute (`bailout_chance`, up to
        // `bailout_max`), until it crashes: the wreck smashes `crash_floors` floors within
        // `crash_radius`, crushing the tanks and squads below (D-167; never the kaiju), and sets the
        // building it hits burning (City Ablaze). It pays its rubble when it is downed.
        // Part of RampageSim. Pure and seeded.

        public class Heli : RefCounted
        {
            public static implicit operator Heli(Variant v) => (Heli)v.Obj;

            public long id;
            public Vector2 pos;
            // which way its nose points, radians (turn-limited)
            public double heading = 0.0;
            // its velocity, units a second (acceleration-limited)
            public Vector2 vel = Vector2.ZERO;
            // its own stand-off distance from the kaiju (world units)
            public double ring = 0.0;
            // the bearing from the kaiju of its firing position, on its ring (radians)
            public double slot = 0.0;
            // the point it steers for now: its firing position, or a pass's point
            public Vector2 goal = Vector2.ZERO;
            // seconds until it glides along the ring to another slot
            public double hold = 0.0;
            // on a strafing pass: a fly-by along a flank line past him
            public bool passing = false;
            // on a pass: lined up and running the line (else flying to its entry)
            public bool run = false;
            // unit vector from the kaiju to the pass line's nearest point
            public Vector2 passAt = Vector2.ZERO;
            // the way along the line it flies
            public Vector2 passDir = Vector2.ZERO;
            public double passLeft = 0.0;
            public double cooldown;
            // a blow reached it: out of the sky
            public bool downed = false;
            // the damage of the blow that downed it: burst or spin down
            public double lastBlow = 0.0;

            void _InitFields()
            {
            }
            public Heli() { _InitFields(); }
        }
        // A downed helicopter spinning to the ground; it crashes when `left` runs out.

        public class Falling : RefCounted
        {
            public static implicit operator Falling(Variant v) => (Falling)v.Obj;

            public long id;
            public Vector2 pos;
            // ground units a second
            public Vector2 drift;
            public double left;
            // the whole fall's time
            public double seconds = 0.0;
            // Lands on roofs (a Taskforce gunship, D-458): it falls from `alt` as the view draws it
            // (height alt x (1 - u^2)) and crashes on the first roof it meets, never through it.
            public bool roofs = false;
            public double alt = 0.0;

            void _InitFields()
            {
            }
            public Falling() { _InitFields(); }
        }
        public RampageSim sim;
        public GDict cfg = new GDict();
        public AirFlight flight;
        public GArray<AirWing.Heli> helis = new GArray<AirWing.Heli>();
        public GArray<AirWing.Falling> falling = new GArray<AirWing.Falling>();
        public long destroyed = 0;
        // its own stream: spawns draw exactly as before deaths fell
        public RandomNumberGenerator _fallRng;
        // a wreck's own impact never reaches the sky
        public bool _crashing = false;
        public double _spawnTimer = 0.0;
        public long _nextId = 0;

        public AirWing(RampageSim pSim, GDict pCfg, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            flight = new AirFlight(sim, cfg, Seeds.Derive(rng, 0xF17L));
            _fallRng = Seeds.Derive(rng, 0xFA11L);
        }

        public double Altitude()
        {
            return Num.F(cfg["altitude"]);
        }
        // How many may be up at once: more the more of the city has fallen.

        public long Cap()
        {
            long after = Num.I(cfg["after_chunks"]);
            if (sim.Escalation() < after)
            {
                return 0;
            }
            long extra = (sim.Escalation() - after) / Gd.Maxi(1, Num.I(cfg["max_per_chunks"]));
            return Gd.Mini(Num.I(cfg["max"]), 1 + extra);
        }

        public void Step(double dt)
        {
            _SweptByFalls();
            // The call-in clock only runs while the sky is short of helicopters: a kill is replaced
            // after `interval`, never on the next step.
            if (helis.Size() < Cap())
            {
                _spawnTimer -= dt;
                if (_spawnTimer <= 0.0)
                {
                    _spawnTimer = Num.F(cfg["interval"]);
                    Spawn();
                }
            }
            flight.Step(helis, dt);
            foreach (AirWing.Heli heli in helis)
            {
                heli.cooldown -= dt;
                if (heli.cooldown <= 0.0)
                {
                    heli.cooldown = Num.F(cfg["fire_interval"]);
                    GDict army = sim.army;
                    double hurt = Num.F(cfg["damage"]) - sim.Stat("armor");
                    sim.hp -= Gd.Maxf(Num.F(army["min_damage"]), hurt);
                    sim.events.Append(new GDict { { "type", "heli_fired" }, { "heli", heli.id } });
                }
            }
            _Fall(dt);
        }
        // A tower toppling this step (Collapse's fall_start) that is tall enough to reach the sky sweeps
        // its landing strip: every helicopter over the strip is knocked spinning down (D-140).

        public void _SweptByFalls()
        {
            var hit = false;
            foreach (GDict @event in sim.events)
            {
                if ((Gd.Str(@event["type"]) != "fall_start" || !@event.Has("to")))
                {
                    continue;
                }
                Vector3 pivot = @event["pivot"];
                var start = new Vector2(pivot.x, pivot.z);
                Vector2 end = @event["to"];
                var span = end - start;
                if (span.Length() + pivot.y < Altitude())
                {
                    // it never reaches the helicopters' height
                    continue;
                }
                double half = Num.F(@event["width"]) * 0.5 + Num.F(cfg["heli_radius"]);
                foreach (AirWing.Heli heli in helis)
                {
                    double t = Gd.Clampf((heli.pos - start).Dot(span) / Gd.Maxf(0.001, span.LengthSquared()), 0.0, 1.0);
                    if (heli.pos.DistanceTo(start + span * t) <= half)
                    {
                        heli.downed = true;
                        // knocked aside, never blown apart
                        heli.lastBlow = 0.0;
                        hit = true;
                    }
                }
            }
            if (hit)
            {
                ClearDead();
            }
        }
        // A new helicopter flies in from beyond its ring (AirFlight.place) on the far side from the camera.

        public AirWing.Heli Spawn()
        {
            var heli = new Heli();
            heli.id = _nextId;
            _nextId += 1;
            flight.Place(heli);
            heli.cooldown = Num.F(cfg["fire_interval"]) * Num.F(cfg["first_burst_delay"]);
            helis.Append(heli);
            sim.events.Append(new GDict { { "type", "heli_spawned" }, { "heli", heli.id } });
            return heli;
        }
        // An attack's force reaches helicopters only when reaches_air (else they fly too high).

        public void Hit(Callable force, double damage, bool reachesAir)
        {
            if ((!reachesAir || helis.IsEmpty() || _crashing))
            {
                return;
            }
            foreach (AirWing.Heli heli in helis)
            {
                double k = force.Call(heli.pos, Num.F(cfg["heli_radius"]));
                if (k > 0.0 && !heli.downed)
                {
                    heli.downed = true;
                    heli.lastBlow = damage * k;
                }
            }
            ClearDead();
        }
        // Takes the dead out of the sky.

        public void ClearDead()
        {
            GArray<AirWing.Heli> alive = new GArray<AirWing.Heli>();
            foreach (AirWing.Heli heli in helis)
            {
                if (!heli.downed)
                {
                    alive.Append(heli);
                    continue;
                }
                destroyed += 1;
                sim.rubble += Num.F(cfg["rubble"]) * sim.Stat("rubble_mult");
                GDict @event = new GDict { { "type", "heli_destroyed" }, { "heli", heli.id }, { "x", heli.pos.x }, { "z", heli.pos.y } };
                if (heli.lastBlow >= Num.F(cfg["burst_blow"]))
                {
                    @event["fate"] = "burst";
                }
                else
                {
                    @event.Merge(_SpinDown(heli));
                }
                sim.events.Append(@event);
            }
            helis = alive;
        }
        // A downed helicopter starts its fall: the fate, the fall's time and drift and the crew who jump.
        // `p_rng` is the stream those are drawn from (the air wing's own unless a caller brings one).

        public GDict _SpinDown(AirWing.Heli heli, RandomNumberGenerator pRng = null)
        {
            var rng = (pRng != null ? pRng : _fallRng);
            var down = new Falling();
            down.id = heli.id;
            down.pos = heli.pos;
            down.left = Num.F(cfg["fall_seconds"]);
            down.seconds = down.left;
            var away = Vector2.FromAngle(rng.Randf() * Gd.TAU);
            down.drift = away * Num.F(cfg["fall_drift"]) / down.left;
            falling.Append(down);
            long crew = 0;
            if (rng.Randf() < Num.F(cfg["bailout_chance"]))
            {
                crew = rng.RandiRange(1, Num.I(cfg["bailout_max"]));
            }
            return new GDict { { "fate", "spin" }, { "seconds", down.left }, { "dx", down.drift.x }, { "dz", down.drift.y }, { "crew", crew } };
        }
        // Falling wrecks drift down; each one that lands crashes (on the street, or on the roof it meets).

        public void _Fall(double dt)
        {
            GArray<AirWing.Falling> still = new GArray<AirWing.Falling>();
            foreach (AirWing.Falling down in falling)
            {
                down.left -= dt;
                down.pos = sim.ClampToArena(down.pos + down.drift * dt);
                double y = 0.0;
                var landed = down.left <= 0.0;
                if (down.roofs && !landed)
                {
                    double u = Gd.Clampf(1.0 - down.left / Gd.Maxf(down.seconds, 0.001), 0.0, 1.0);
                    y = down.alt * (1.0 - u * u);
                    landed = y <= TopAt(sim, down.pos);
                }
                if (!landed)
                {
                    still.Append(down);
                    continue;
                }
                sim.events.Append(new GDict { { "type", "heli_crashed" }, { "heli", down.id }, { "x", down.pos.x }, { "z", down.pos.y }, { "y", y } });
                _Crash(down.pos, y);
            }
            falling = still;
        }
        // The tallest standing building's height (floors) whose footprint holds `p`; 0 on open ground.

        public static long TopAt(RampageSim pSim, Vector2 p)
        {
            long top = 0;
            foreach (RampageSim.Building b in pSim.buildings)
            {
                if (b.frame.aliveCount == 0)
                {
                    continue;
                }
                if (Gd.Absf(p.x - b.x) <= b.w * 0.5 && Gd.Absf(p.y - b.z) <= b.d * 0.5)
                {
                    top = Gd.Maxi(top, b.height + b.@base);
                }
            }
            return top;
        }
        // The wreck hits the street at `at`: it sets the building it hits burning, which spreads with
        // City Ablaze (D-141), and smashes the low floors around it. It hurts the city and the army
        // below (D-167), never the kaiju or the sky. On a roof at height `y` it smashes the
        // `crash_floors` floors under it instead of the street's.

        public void _Crash(Vector2 at, double y = 0.0)
        {
            double radius = Num.F(cfg["crash_radius"]);
            long nearest = -1;
            double best = radius;
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                var b = sim.buildings[i];
                if (b.frame.aliveCount == 0)
                {
                    continue;
                }
                var gap = new Vector2(Gd.Maxf(0.0, Gd.Absf(at.x - b.x) - b.w * 0.5), Gd.Maxf(0.0, Gd.Absf(at.y - b.z) - b.d * 0.5));
                if (gap.Length() <= best)
                {
                    best = gap.Length();
                    nearest = i;
                }
            }
            if (nearest >= 0)
            {
                sim.powers.fire.Ignite(nearest);
            }
            _crashing = true;
            sim.HitArea(new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(p.DistanceTo(at) - r, radius);
            }), Num.F(cfg["crash_damage"]), Gd.Maxi(0, Gd.Floori(y) - Num.I(cfg["crash_floors"])), Gd.Maxi(Gd.Floori(y), Num.I(cfg["crash_floors"])));
            _crashing = false;
            _CrushRoofs(at, radius);
        }
        // The wreck lands on the roofs under it (D-167, D-173): every rooftop squad and every perched
        // Taskforce agent on a building the impact reaches dies, at any floor (the building's footprint
        // decides, as for hit_buildings, not the floor range). Squads have no hp, so a reach above 0 is
        // enough, as for any splash (Army.splash). Only the crash does this; stomps and bites keep their
        // floor ranges. Agents jetpacking in the air, the kaiju and the sky are not touched.

        public void _CrushRoofs(Vector2 at, double radius)
        {
            var struck = new Callable(a_ =>
            {
                long index = a_[0];
                return _Struck(sim.buildings[index], at, radius);
            });
            foreach (Army.Squad squad in sim.armyUnits.squads)
            {
                if (Gd.Truthy(struck.Call(squad.building)))
                {
                    squad.dead = true;
                }
            }
            sim.armyUnits.ClearDead();
            sim.armyUnits.taskforce.CrushPerched(struck);
        }
        // Does the crash at `at` reach building `b`'s footprint (hit_buildings' own test)?

        public bool _Struck(RampageSim.Building b, Vector2 at, double radius)
        {
            double reach = new Vector2(b.w, b.d).Length() * 0.5;
            return RampageSim.Falloff(new Vector2(b.x, b.z).DistanceTo(at) - reach, radius) > 0.0;
        }

        void _InitFields()
        {
        }
    }
}
