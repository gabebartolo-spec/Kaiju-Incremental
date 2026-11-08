// Generated from sim/taskforce_mechs.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TaskforceMechs : RefCounted
    {
        public static implicit operator TaskforceMechs(Variant v) => (TaskforceMechs)v.Obj;

        // The Taskforce's walking mechs (D-143, D-145, D-152), adult city only: knee-high machines, a few
        // at a time, walk the tanks' roads (RoadGraph) toward the kaiju and stop at `standoff`. From
        // there each fires laser-bomb volleys: electric-blue target rings appear round the kaiju and the
        // bombs land `warn` seconds later, hurting him if he still stands in a ring and breaking the city
        // under it. Any blow of his that reaches a mech kills it (one stomp, tail sweep or the Thunder
        // Beam), and so does a toppled tower falling on it; a dead mech blows up, breaking the buildings
        // round it, and pays biomass. Part of Taskforce; pure and seeded. Events: mech_spawned,
        // mech_volley (rings), mech_bomb, mech_died.

        public class Mech : RefCounted
        {
            public static implicit operator Mech(Variant v) => (Mech)v.Obj;

            public long id;
            public Vector2 pos = Vector2.ZERO;
            // the road node it walks to
            public long node = -1;
            // the node it came from (it does not turn back unless it must)
            public long prev = -1;
            public Vector2 facing = Vector2.RIGHT;
            public double volleyCd = 0.0;
            public bool walking = true;

            void _InitFields()
            {
            }
            public Mech() { _InitFields(); }
        }
        public RampageSim sim;
        public GDict cfg = new GDict();
        public GArray<TaskforceMechs.Mech> mechs = new GArray<TaskforceMechs.Mech>();
        // Bombs on their way down: [seconds left, where (x, z)].
        public GArray<GArray<Variant>> bombs = new GArray<GArray<Variant>>();
        public long kills = 0;
        public RandomNumberGenerator _rng;
        public double _timer;
        public long _nextId = 0;

        public TaskforceMechs(RampageSim pSim, GDict pCfg, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            _rng = rng;
            _timer = Num.F(cfg["first_delay"]);
        }
        // How many may walk at once in this city (none before the adult city).

        public long Cap()
        {
            GArray<Variant> byTier = cfg["max_by_tier"];
            return Num.I(byTier[Gd.Clampi(sim.SizeTier() - 1, 0, byTier.Size() - 1)]);
        }
        // `open`: the Taskforce has joined this rampage (Taskforce.step's gate); `escalation` shortens
        // the wait between mechs the more of the city has fallen.

        public void Step(double dt, bool open)
        {
            if (open && Cap() > 0)
            {
                _timer -= dt;
                if (_timer <= 0.0 && mechs.Size() < Cap())
                {
                    _timer = Gd.Maxf(Num.F(cfg["min_interval"]), Num.F(cfg["start_interval"]) - Num.F(cfg["escalation_per_chunk"]) * sim.Escalation());
                    Spawn();
                }
            }
            _LandBombs(dt);
            foreach (TaskforceMechs.Mech mech in mechs)
            {
                mech.volleyCd = Gd.Maxf(0.0, mech.volleyCd - dt);
                double dist = mech.pos.DistanceTo(sim.kaijuPos);
                mech.facing = (dist > 0.01 ? (sim.kaijuPos - mech.pos).Normalized() : mech.facing);
                mech.walking = dist > Num.F(cfg["standoff"]);
                if (mech.walking)
                {
                    _Walk(mech, dt);
                }
                if (mech.volleyCd <= 0.0 && dist <= Num.F(cfg["range"]))
                {
                    mech.volleyCd = Num.F(cfg["volley_cooldown"]);
                    _Volley(mech);
                }
            }
        }
        // A mech walks in at a road entry on a seeded bearing (none when no entry is free of the kaiju).

        public TaskforceMechs.Mech Spawn()
        {
            var graph = sim.armyUnits.convoy.graph;
            double bearing = _rng.Randf() * Gd.TAU;
            long n = graph.PickEntry(bearing, sim.kaijuPos, Num.F(sim.army["spawn_radius"]), Num.F(cfg["standoff"]));
            if (n < 0)
            {
                return null;
            }
            return Place(graph.nodes[n], n);
        }
        // A mech standing at `at`, walking to road node `node` (spawn, and the tests' way to place one).

        public TaskforceMechs.Mech Place(Vector2 at, long node)
        {
            var mech = new Mech();
            mech.id = _nextId;
            _nextId += 1;
            mech.pos = at;
            mech.node = node;
            mech.volleyCd = Num.F(cfg["volley_cooldown"]) * Num.F(cfg["first_charge"]);
            mechs.Append(mech);
            sim.events.Append(new GDict { { "type", "mech_spawned" }, { "mech", mech.id }, { "x", at.x }, { "z", at.y } });
            return mech;
        }
        // An area blow (RampageSim.hit_area's force over ground points) kills every mech it reaches.

        public void Hit(Callable force, double damage)
        {
            if (damage <= 0.0)
            {
                return;
            }
            GArray<TaskforceMechs.Mech> down = new GArray<TaskforceMechs.Mech>();
            foreach (TaskforceMechs.Mech mech in mechs)
            {
                if (Num.F(force.Call(mech.pos, Num.F(cfg["radius"]))) > 0.0)
                {
                    down.Append(mech);
                }
            }
            foreach (TaskforceMechs.Mech mech in down)
            {
                _Kill(mech, "smashed");
            }
        }
        // A toppled tower lands on the strip `in_strip` (Callable(p, r) -> bool): every mech under it dies.

        public void Crush(Callable inStrip)
        {
            GArray<TaskforceMechs.Mech> down = new GArray<TaskforceMechs.Mech>();
            foreach (TaskforceMechs.Mech mech in mechs)
            {
                if (Gd.Truthy(inStrip.Call(mech.pos, Num.F(cfg["radius"]))))
                {
                    down.Append(mech);
                }
            }
            foreach (TaskforceMechs.Mech mech in down)
            {
                _Kill(mech, "crushed");
            }
        }
        // What a kill pays: `rubble_share` of a tank's biomass in this city.

        public double KillPay()
        {
            return Num.F(sim.army["tank_rubble"]) * Num.F(cfg["rubble_share"]) * sim.Stat("rubble_mult");
        }
        // Along its road to its node; at the node, on to the linked node nearest the kaiju (never back
        // the way it came unless that is the only road open).

        public void _Walk(TaskforceMechs.Mech mech, double dt)
        {
            var graph = sim.armyUnits.convoy.graph;
            if (mech.node < 0)
            {
                return;
            }
            var goal = graph.nodes[mech.node];
            double step = Num.F(cfg["speed"]) * dt;
            if (mech.pos.DistanceTo(goal) > step)
            {
                mech.pos += (goal - mech.pos).Normalized() * step;
                return;
            }
            mech.pos = goal;
            long best = -1;
            double bestD = Gd.INF;
            foreach (long e in graph.links[mech.node])
            {
                if (graph.blocked[e] != 0)
                {
                    continue;
                }
                long far = (graph.edgeA[e] == mech.node ? graph.edgeB[e] : graph.edgeA[e]);
                double d = graph.nodes[far].DistanceTo(sim.kaijuPos) + ((far == mech.prev ? Gd.INF : 0.0));
                if ((d < bestD || best < 0))
                {
                    bestD = d;
                    best = far;
                }
            }
            mech.prev = mech.node;
            mech.node = best;
        }
        // Rings round the kaiju: one on his feet, the rest a seeded `spread` round him.

        public void _Volley(TaskforceMechs.Mech mech)
        {
            GArray<Vector2> rings = new GArray<Vector2> { sim.kaijuPos };
            foreach (long _n in Gd.Range(Num.I(cfg["bombs"]) - 1))
            {
                var off = Vector2.FromAngle(_rng.Randf() * Gd.TAU) * _rng.Randf() * Num.F(cfg["spread"]);
                rings.Append(sim.kaijuPos + off);
            }
            foreach (Vector2 at in rings)
            {
                bombs.Append(Gd.Arr(Num.F(cfg["warn"]), at));
            }
            sim.events.Append(new GDict { { "type", "mech_volley" }, { "mech", mech.id }, { "rings", rings }, { "radius", cfg["bomb_radius"] }, { "warn", cfg["warn"] } });
        }

        public void _LandBombs(double dt)
        {
            GArray<GArray<Variant>> falling = new GArray<GArray<Variant>>();
            foreach (GArray<Variant> bomb in bombs)
            {
                bomb[0] = Num.F(bomb[0]) - dt;
                if (Num.F(bomb[0]) > 0.0)
                {
                    falling.Append(bomb);
                    continue;
                }
                Vector2 at = bomb[1];
                var hit = sim.kaijuPos.DistanceTo(at) <= Num.F(cfg["bomb_radius"]);
                double damage = (hit ? sim.maxHp * Num.F(cfg["bomb_share"]) : 0.0);
                sim.hp -= damage;
                sim.events.Append(new GDict { { "type", "mech_bomb" }, { "x", at.x }, { "z", at.y }, { "hit", hit }, { "damage", damage } });
                _Blast(at, Num.F(cfg["bomb_radius"]), Num.F(cfg["bomb_damage"]), Num.I(cfg["bomb_floors"]));
            }
            bombs = falling;
        }
        // Breaks the city round `at` (buildings only: a blast never chains through other units).

        public void _Blast(Vector2 at, double radius, double damage, long floors)
        {
            StrayShell.HitBuildings(sim, new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(p.DistanceTo(at) - r, radius);
            }), damage, new Vector2i(0, floors));
        }

        public void _Kill(TaskforceMechs.Mech mech, string kind)
        {
            // a blast's topple already took it
            if (!mechs.Has(mech))
            {
                return;
            }
            mechs.Erase(mech);
            kills += 1;
            sim.rubble += KillPay();
            sim.events.Append(new GDict { { "type", "mech_died" }, { "mech", mech.id }, { "kind", kind }, { "x", mech.pos.x }, { "z", mech.pos.y } });
            _Blast(mech.pos, Num.F(cfg["death_radius"]), Num.F(cfg["death_damage"]), Num.I(cfg["death_floors"]));
        }

        void _InitFields()
        {
        }
    }
}
