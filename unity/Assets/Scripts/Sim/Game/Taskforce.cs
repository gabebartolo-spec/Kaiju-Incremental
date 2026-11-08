// Generated from sim/taskforce.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Taskforce : RefCounted
    {
        public static implicit operator Taskforce(Variant v) => (Taskforce)v.Obj;

        // The Anti Kaiju Taskforce (D-137, D-139, D-141, D-143, D-145), agents only: squads of 3-4 jetpack
        // in from the map edge, arriving faster the more of the city has fallen (about 12 alive at most,
        // none in the young city), grapple and jet from roof to roof near the kaiju and perch. A perched
        // agent aims a railgun: the aiming line tracks the kaiju, locks shortly before the shot, and the
        // shot costs `railgun.share` of its max health if the kaiju still stands in the lock (a late
        // step dodges it). A squad shoots in volleys (TaskforceVolley, D-178): its lines lock together
        // and its shots land `railgun.squad_gap` seconds apart, so one dash saves the kaiju from the whole
        // squad and a squad lands at most 2 hits in a second (D-166). It also launches frost grenades at
        // the kaiju's feet (TaskforceFrost). An agent dies when the roof chunk it clings to goes (broken,
        // dropped or toppled) or when a tail sweep swats it out of the air mid-hop; each kill pays
        // biomass. In the adult city some agents are gas soldiers, who throw gas (TaskforceGas) in place
        // of frost, walking mechs come up the roads (TaskforceMechs) and gunships fly
        // (TaskforceGunships). Part of Army; pure and seeded
        // from its own stream; numbers in data/tuning.json "taskforce".
        // Presentation reads the agents and the events (taskforce_deployed, railgun_aim, railgun_locked,
        // railgun_hit, railgun_missed, frost_launched, frost_hit, frost_cracked, agent_died; the gas and
        // mech events are in their own files).
        // jetpacking in from the map edge
        public const long ARRIVE = 0;
        // grappling and jetting to another roof
        public const long HOP = 1;
        // on a roof chunk: holds, throws, hops on
        public const long PERCH = 2;
        // on a roof chunk: the railgun's aiming line is up
        public const long AIM = 3;

        public class Agent : RefCounted
        {
            public static implicit operator Agent(Variant v) => (Agent)v.Obj;

            public long id;
            public long squad;
            // a gas soldier: throws gas, not frost
            public bool gas = false;
            public long state = ARRIVE;
            // on the ground plane (x, z)
            public Vector2 pos = Vector2.ZERO;
            // its height above the ground
            public double y = 0.0;
            // the roof it clings to (PERCH, AIM) or is flying to (ARRIVE, HOP)
            public long building = -1;
            public Vector3i cell = Vector3i.ZERO;
            // where this flight began and where it ends
            public Vector3 from = Vector3.ZERO;
            public Vector3 to = Vector3.ZERO;
            // seconds left in this flight
            public double flight = 0.0;
            public double flightLen = 1.0;
            // perched: seconds until it hops on
            public double wait = 0.0;
            public double railCd = 0.0;
            public double frostCd = 0.0;
            public double aimLeft = 0.0;
            // where the line points; locked once `locked`
            public Vector2 aimAt = Vector2.ZERO;
            public bool locked = false;
            // Where its railgun and grenades leave it.

            public Vector3 Muzzle()
            {
                return new Vector3(pos.x, y, pos.y);
            }

            void _InitFields()
            {
            }
            public Agent() { _InitFields(); }
        }
        public RampageSim sim;
        public GDict cfg = new GDict();
        public TaskforceFrost frost;
        public TaskforcePerch perch;
        public TaskforceVolley volley;
        public TaskforceGas gas;
        public TaskforceMechs mechs;
        public TaskforceGunships gunships;
        public GArray<Taskforce.Agent> agents = new GArray<Taskforce.Agent>();
        // Agents killed this run, and each squad's size as it arrived.
        public long kills = 0;
        public GArray<long> squadSizes = new GArray<long>();
        // Rampage seconds the player had spent in the adolescent city or later before this run (the save
        // carries them, D-160), and the seconds this run has added.
        public double carried = 0.0;
        public double played = 0.0;
        public RandomNumberGenerator _rng;
        public double _timer;
        public long _nextId = 0;

        public Taskforce(RampageSim pSim, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            // a run (or a test) may edit its own copy
            cfg = Content.Section("taskforce").Duplicate(true);
            _rng = rng;
            _timer = Num.F(_First()["run_delay"]);
            GDict frostCfg = cfg["frost"];
            frost = new TaskforceFrost(sim, frostCfg);
            perch = new TaskforcePerch(sim, cfg, rng);
            GDict rail = cfg["railgun"];
            volley = new TaskforceVolley(sim, rail);
            GDict gasCfg = cfg["gas"];
            gas = new TaskforceGas(sim, gasCfg);
            GDict mechCfg = cfg["mechs"];
            mechs = new TaskforceMechs(sim, mechCfg, Seeds.Derive(rng, 0x3EC4L));
            GDict shipCfg = cfg["gunships"];
            gunships = new TaskforceGunships(sim, shipCfg, Seeds.Derive(rng, 0x6A5L));
        }
        // How many may be alive at once: none in the young city, the same from the adolescent city on.

        public long Cap()
        {
            GArray<Variant> byTier = cfg["max_by_tier"];
            return Num.I(byTier[Gd.Clampi(sim.SizeTier() - 1, 0, byTier.Size() - 1)]);
        }
        // Seconds between squads: shorter the more of the city has fallen, never under min_interval.

        public double Interval()
        {
            double left = Num.F(cfg["start_interval"]) - Num.F(cfg["escalation_per_chunk"]) * sim.Escalation();
            return Gd.Maxf(Num.F(cfg["min_interval"]), left);
        }
        // Rampage seconds in the adolescent city or later, the ones before this run and this run's.

        public double CitySeconds()
        {
            return carried + played;
        }

        public void Step(double dt)
        {
            played += (Cap() > 0 ? dt : 0.0);
            var open = Cap() > 0 && carried >= Num.F(_First()["city_seconds"]);
            if (open)
            {
                _timer -= dt;
                if (_timer <= 0.0 && Cap() - agents.Size() >= _SquadMin())
                {
                    _timer = Interval();
                    SpawnSquad();
                }
            }
            frost.Step(dt);
            gas.Step(dt);
            mechs.Step(dt, open);
            gunships.Step(dt, open);
            _CoolDown(dt);
            volley.Tick(dt, agents);
            GArray<Taskforce.Agent> fallen = new GArray<Taskforce.Agent>();
            foreach (Taskforce.Agent agent in agents)
            {
                if ((agent.state == ARRIVE || agent.state == HOP))
                {
                    _Fly(agent, dt);
                }
                else if (!_Holds(agent))
                {
                    fallen.Append(agent);
                }
                else if (agent.state == AIM)
                {
                    volley.Aim(agent, dt);
                }
                else
                {
                    _Perched(agent, dt);
                }
            }
            foreach (Taskforce.Agent agent in fallen)
            {
                _Kill(agent, "perch_collapse", new GDict());
            }
        }
        // Every agent's cooldowns run down before any agent acts, so a squad's gunners whose railguns
        // come ready on the same step all see it (a later-listed one would else read last step's value).

        public void _CoolDown(double dt)
        {
            foreach (Taskforce.Agent agent in agents)
            {
                agent.railCd = Gd.Maxf(0.0, agent.railCd - dt);
                agent.frostCd = Gd.Maxf(0.0, agent.frostCd - dt);
            }
        }
        // A squad of 3-4 jetpacks in from a seeded point of the map edge, each bound for a roof near
        // the kaiju (as many as fit under the cap). The first squad of a run raises taskforce_deployed.

        public void SpawnSquad()
        {
            GArray<Variant> sizes = cfg["squad_size"];
            long size = Gd.Mini(_rng.RandiRange(Num.I(sizes[0]), Num.I(sizes[1])), Cap() - agents.Size());
            var edge = _EdgePoint();
            var along = Vector2.FromAngle(_rng.Randf() * Gd.TAU).Orthogonal() * Num.F(cfg["squad_spacing"]);
            long squad = squadSizes.Size();
            squadSizes.Append(size);
            foreach (long n in Gd.Range(size))
            {
                var at = edge + along * (n - (size - 1) * 0.5);
                var agent = _NewAgent(squad, at, Num.F(cfg["jet_height"]));
                agent.gas = _rng.Randf() < _GasShare();
                _HopTo(agent, ARRIVE, Num.F(cfg["jet_speed"]));
            }
            if (squad == 0)
            {
                sim.events.Append(new GDict { { "type", "taskforce_deployed" }, { "x", edge.x }, { "z", edge.y }, { "agents", size } });
            }
        }
        // An agent perched on chunk `cell` of building `building` (spawn and the tests' way to place one).

        public Taskforce.Agent PlaceAgent(long building, Vector3i cell)
        {
            var agent = _NewAgent(squadSizes.Size(), Vector2.ZERO, 0.0);
            agent.state = PERCH;
            agent.building = building;
            agent.cell = cell;
            var at = sim.buildings[building].ChunkWorld(cell);
            agent.pos = new Vector2(at.x, at.z);
            agent.y = at.y + 0.5;
            agent.wait = _PerchTime();
            return agent;
        }
        // A tail sweep (D-459; its `force` over ground points, up to height `top`) swats every agent in the
        // air inside it: it spins off into the nearest wall and dies there.

        public void Swat(Callable force, double top)
        {
            GArray<Taskforce.Agent> down = new GArray<Taskforce.Agent>();
            foreach (Taskforce.Agent agent in agents)
            {
                var flying = (agent.state == ARRIVE || agent.state == HOP);
                if (flying && agent.y <= top && Num.F(force.Call(agent.pos, _SwatRadius())) > 0.0)
                {
                    down.Append(agent);
                }
            }
            foreach (Taskforce.Agent agent in down)
            {
                _Kill(agent, "swatted", _Wall(agent));
            }
        }
        // A wreck crashes on the buildings `struck` says yes to (building index -> bool): every agent
        // perched or aiming on one dies with the roof (D-173). Agents in the air are untouched.

        public void CrushPerched(Callable struck)
        {
            GArray<Taskforce.Agent> down = new GArray<Taskforce.Agent>();
            foreach (Taskforce.Agent agent in agents)
            {
                if (((agent.state == PERCH || agent.state == AIM)) && Gd.Truthy(struck.Call(agent.building)))
                {
                    down.Append(agent);
                }
            }
            foreach (Taskforce.Agent agent in down)
            {
                _Kill(agent, "crushed", new GDict());
            }
        }

        public double _SwatRadius()
        {
            GDict swatCfg = cfg["swat"];
            return Num.F(swatCfg["radius"]);
        }
        // When the Taskforce first joins (D-160): once `city_seconds` of rampage time are carried in from
        // earlier rampages in the adolescent city (the first ones are army-only), then every rampage, its
        // first squad `run_delay` seconds in. Data "first_arrival", the one place to change it.

        public GDict _First()
        {
            GDict first = cfg["first_arrival"];
            return first;
        }

        public long _SquadMin()
        {
            GArray<Variant> sizes = cfg["squad_size"];
            return Num.I(sizes[0]);
        }

        public double _PerchTime()
        {
            GArray<Variant> span = cfg["perch_seconds"];
            return _rng.RandfRange(Num.F(span[0]), Num.F(span[1]));
        }

        public Taskforce.Agent _NewAgent(long squad, Vector2 at, double height)
        {
            var agent = new Agent();
            agent.id = _nextId;
            _nextId += 1;
            agent.squad = squad;
            agent.pos = at;
            agent.y = height;
            agent.railCd = Num.F(_Rail()["cooldown"]) * Num.F(_Rail()["first_charge"]);
            agent.frostCd = Num.F(frost.cfg["cooldown"]) * Num.F(frost.cfg["first_charge"]);
            agents.Append(agent);
            return agent;
        }

        public GDict _Rail()
        {
            GDict rail = cfg["railgun"];
            return rail;
        }
        // A point on the square ring just outside the playable arena, at a seeded bearing.

        public Vector2 _EdgePoint()
        {
            var dir = Vector2.FromAngle(_rng.Randf() * Gd.TAU);
            double reach = sim.arenaHalf + Num.F(cfg["edge_inset"]);
            return dir * reach / Gd.Maxf(Gd.Absf(dir.x), Gd.Absf(dir.y));
        }
        // Starts a flight (state ARRIVE or HOP) to a roof near the kaiju at `speed` units a second; with
        // no roof to go to the agent hovers where it is a second and looks again.

        public void _HopTo(Taskforce.Agent agent, long state, double speed)
        {
            agent.state = state;
            agent.from = new Vector3(agent.pos.x, agent.y, agent.pos.y);
            GArray<Variant> spot = perch.Pick(agent, agents);
            if (spot.IsEmpty())
            {
                agent.building = -1;
                agent.to = agent.from;
                agent.flightLen = Num.F(cfg["hover_seconds"]);
            }
            else
            {
                agent.building = Num.I(spot[0]);
                agent.cell = spot[1];
                var roof = sim.buildings[agent.building].ChunkWorld(agent.cell);
                agent.to = new Vector3(roof.x, roof.y + 0.5, roof.z);
                double fly = agent.from.DistanceTo(agent.to) / speed;
                agent.flightLen = Gd.Maxf(Num.F(cfg["min_flight_s"]), fly);
            }
            agent.flight = agent.flightLen;
        }
        // One step of a flight: along a straight line with an arc over it; on landing the agent perches
        // if its roof chunk still stands, else looks for another.

        public void _Fly(Taskforce.Agent agent, double dt)
        {
            agent.flight -= dt;
            double t = 1.0 - Gd.Clampf(agent.flight / agent.flightLen, 0.0, 1.0);
            var at = agent.from.Lerp(agent.to, t);
            double arc = (agent.state == HOP ? Num.F(cfg["hop_arc"]) : 0.0);
            agent.pos = new Vector2(at.x, at.z);
            agent.y = at.y + arc * Gd.Sin(Gd.PI * t);
            if (agent.flight > 0.0)
            {
                return;
            }
            if (agent.building >= 0 && sim.buildings[agent.building].frame.Alive(agent.cell))
            {
                agent.state = PERCH;
                agent.pos = new Vector2(agent.to.x, agent.to.z);
                agent.y = agent.to.y;
                agent.wait = _PerchTime();
            }
            else
            {
                _HopTo(agent, HOP, Num.F(cfg["jet_speed"]));
            }
        }
        // Whether the roof chunk the agent clings to still stands.

        public bool _Holds(Taskforce.Agent agent)
        {
            return sim.buildings[agent.building].frame.Alive(agent.cell);
        }
        // A perched agent: the railgun when it is ready and the kaiju in range, else a frost grenade,
        // else (when it has held long enough) a hop to another roof.

        public void _Perched(Taskforce.Agent agent, double dt)
        {
            agent.wait -= dt;
            double dist = agent.pos.DistanceTo(sim.kaijuPos);
            if (volley.Ready(agent, dt) && dist <= Num.F(_Rail()["range"]))
            {
                // else it holds until its squad's volley is over (D-178)
                if (!volley.Busy(agent.squad))
                {
                    volley.Open(agent, agents, dt);
                }
            }
            else if (agent.frostCd <= 0.0 && _Throws(agent, dist))
            {
                if (agent.gas)
                {
                    agent.frostCd = Num.F(gas.cfg["cooldown"]);
                    gas.Launch(agent.id, agent.Muzzle());
                }
                else
                {
                    agent.frostCd = Num.F(frost.cfg["cooldown"]);
                    frost.Launch(agent.id, agent.Muzzle());
                }
            }
            else if (agent.wait <= 0.0)
            {
                _HopTo(agent, HOP, Num.F(cfg["jet_speed"]) * Num.F(cfg["hop_speed_share"]));
            }
        }
        // Whether the agent's grenade (gas or frost) reaches the kaiju `dist` away.

        public bool _Throws(Taskforce.Agent agent, double dist)
        {
            return (agent.gas ? gas.Reaches(dist) : frost.Reaches(dist));
        }
        // The share of a squad's agents that are gas soldiers in this city (none before the adult city).

        public double _GasShare()
        {
            GArray<Variant> byTier = gas.cfg["share_by_tier"];
            return Num.F(byTier[Gd.Clampi(sim.SizeTier() - 1, 0, byTier.Size() - 1)]);
        }
        // What a kill pays: `rubble_share` of a tank's biomass in this city (D-152: about a tank's worth).

        public double KillPay()
        {
            return Num.F(sim.army["tank_rubble"]) * Num.F(cfg["rubble_share"]) * sim.Stat("rubble_mult");
        }
        // Removes an agent (a collapsed perch, or swatted into a wall) and pays its biomass.

        public void _Kill(Taskforce.Agent agent, string kind, GDict extra)
        {
            agents.Erase(agent);
            kills += 1;
            sim.rubble += KillPay();
            GDict death = new GDict { { "type", "agent_died" }, { "agent", agent.id }, { "kind", kind } };
            sim.events.Append(death.Merged(new GDict { { "x", agent.pos.x }, { "y", agent.y }, { "z", agent.pos.y } }).Merged(extra));
        }
        // Where a swatted agent hits: the nearest standing wall, as {"wall": building, "hit": Vector3}
        // (empty when no building is within swat.wall_range).

        public GDict _Wall(Taskforce.Agent agent)
        {
            GDict swatCfg = cfg["swat"];
            double best = Num.F(swatCfg["wall_range"]);
            GDict found = new GDict();
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                var b = sim.buildings[i];
                if (b.frame.aliveCount == 0)
                {
                    continue;
                }
                var near = new Vector2(Gd.Clampf(agent.pos.x, b.x - b.w * 0.5, b.x + b.w * 0.5), Gd.Clampf(agent.pos.y, b.z - b.d * 0.5, b.z + b.d * 0.5));
                if (near.DistanceTo(agent.pos) < best)
                {
                    best = near.DistanceTo(agent.pos);
                    found = new GDict { { "wall", i }, { "hit", new Vector3(near.x, Gd.Clampf(agent.y, 0.5, b.height), near.y) } };
                }
            }
            return found;
        }

        void _InitFields()
        {
        }
    }
}
