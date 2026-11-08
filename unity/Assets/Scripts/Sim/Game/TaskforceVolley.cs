// Generated from sim/taskforce_volley.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TaskforceVolley : RefCounted
    {
        public static implicit operator TaskforceVolley(Variant v) => (TaskforceVolley)v.Obj;

        // The Taskforce's railguns (D-139, D-161, D-166, D-178 "Lock together, fire in turn"): a squad
        // shoots in volleys. The first ready gunner opens one and every other ready gunner of its squad
        // puts its aiming line up with it. The lines follow the kaiju, then lock together at one moment
        // on one point (`lock_seconds` before the first shot), and the shots land `squad_gap` seconds
        // apart in the squad's list order, so a single dash at the lock saves the kaiju from the whole
        // squad and a kaiju standing still takes at most 2 hits a second from a squad. A shot costs
        // `share` of max health if the kaiju still stands in the lock. Part of Taskforce; pure, no
        // random draw. Events: railgun_aim, railgun_locked, railgun_hit, railgun_missed.
        // A railgun counts as ready within this share of a step before its cooldown runs out, so float
        // noise and a squad_gap that is not a whole number of steps cannot split a squad's volleys.
        public const double READY_SLACK = 0.5;
        public RampageSim sim;
        // tuning "taskforce" "railgun"
        public GDict cfg = new GDict();
        // Per squad, the volley in progress: {"lock": seconds until its lines lock, "age": seconds since
        // it opened, "first": the age at its first shot (-1 before it)}. It is over when no gunner of the
        // squad is still aiming, and only then may the squad open another; a gunner killed mid-aim leaves
        // its shot out, the others fire on their turns.
        public GDict _volleys = new GDict();

        public TaskforceVolley(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
        }
        // Whether the squad has a volley in progress (its other gunners hold their fire until it ends).

        public bool Busy(long squad)
        {
            return _volleys.Has(squad);
        }
        // Whether the gunner's railgun is ready (its cooldown has run out, give or take READY_SLACK).

        public bool Ready(Taskforce.Agent agent, double dt)
        {
            return agent.railCd <= dt * READY_SLACK;
        }
        // Ages every volley: the squad's lines lock together when theirs is up, and a volley none of
        // whose gunners is still aiming is over.

        public void Tick(double dt, GArray<Taskforce.Agent> agents)
        {
            foreach (long squad in _volleys.Keys())
            {
                GDict volley = _volleys[squad];
                if (!_Aiming(squad, agents))
                {
                    _volleys.Erase(squad);
                    continue;
                }
                volley["age"] = Num.F(volley["age"]) + dt;
                double @lock = Num.F(volley["lock"]);
                if (@lock > 0.0)
                {
                    volley["lock"] = @lock - dt;
                    if (@lock - dt <= 0.0)
                    {
                        _Lock(squad, agents);
                    }
                }
            }
        }
        // `opener` (a perched gunner with its railgun ready and the kaiju in range) opens its squad's
        // volley: it and every later-listed ready gunner of the squad put their lines up now. The nth
        // shot is due `aim_seconds` + n x `squad_gap` after, the first shot first, and its gunner's
        // cooldown counts from the first shot (see `_fire`), so the squad is ready together again for its
        // next volley. A gunner listed after the opener also runs `aim` this very step, so it starts one
        // `dt` behind to stay level.

        public void Open(Taskforce.Agent opener, GArray<Taskforce.Agent> agents, double dt)
        {
            double gap = Num.F(cfg["squad_gap"]);
            long shots = 0;
            foreach (long i in Gd.Range(agents.Find(opener), agents.Size()))
            {
                var agent = agents[i];
                if ((agent == opener || _CanJoin(agent, opener.squad, dt)))
                {
                    _StartAim(agent, shots * gap + ((agent == opener ? 0.0 : dt)));
                    shots += 1;
                }
            }
            _volleys[opener.squad] = new GDict { { "lock", Num.F(cfg["aim_seconds"]) - LockSeconds() }, { "age", 0.0 }, { "first", -1.0 } };
        }
        // The warning between the lines locking and the first shot, by growth stage (director
        // 2026-10-26, "Longer warning, scaled by size"): long enough for a leap pressed at the lock to
        // crouch and be off the lock before the shot lands.

        public double LockSeconds()
        {
            GArray<Variant> byStage = cfg["lock_seconds_by_stage"];
            return Num.F(byStage[Gd.Clampi(sim.SizeTier() - 1, 0, byStage.Size() - 1)]);
        }
        // One step of an aiming gunner: the line follows the kaiju until the squad's lines lock, then the
        // shot lands when its turn comes, on the kaiju only if it still stands in the lock.

        public void Aim(Taskforce.Agent agent, double dt)
        {
            agent.aimLeft -= dt;
            if (agent.aimLeft <= 0.0)
            {
                _Fire(agent);
            }
            else if (!agent.locked)
            {
                agent.aimAt = sim.kaijuPos;
            }
        }
        // Whether `agent` is a ready gunner of `squad` on a roof that still holds (the opener's own test
        // in Taskforce.step is the same), with the kaiju in range.

        public bool _CanJoin(Taskforce.Agent agent, long squad, double dt)
        {
            return (agent.squad == squad && agent.state == Taskforce.PERCH && Ready(agent, dt) && sim.buildings[agent.building].frame.Alive(agent.cell) && agent.pos.DistanceTo(sim.kaijuPos) <= Num.F(cfg["range"]));
        }
        // Whether any gunner of `squad` is still aiming.

        public bool _Aiming(long squad, GArray<Taskforce.Agent> agents)
        {
            foreach (Taskforce.Agent agent in agents)
            {
                if (agent.squad == squad && agent.state == Taskforce.AIM)
                {
                    return true;
                }
            }
            return false;
        }
        // The gunner puts its railgun line up; its shot is due `aim_seconds` + `delay` from now.

        public void _StartAim(Taskforce.Agent agent, double delay)
        {
            agent.state = Taskforce.AIM;
            agent.aimLeft = Num.F(cfg["aim_seconds"]) + delay;
            agent.aimAt = sim.kaijuPos;
            agent.locked = false;
            sim.events.Append(new GDict { { "type", "railgun_aim" }, { "agent", agent.id }, { "from", agent.Muzzle() } });
        }
        // The squad's lines lock together, every one on the first line's point.

        public void _Lock(long squad, GArray<Taskforce.Agent> agents)
        {
            var point = Vector2.ZERO;
            var first = true;
            foreach (Taskforce.Agent agent in agents)
            {
                if ((agent.squad != squad || agent.state != Taskforce.AIM || agent.locked))
                {
                    continue;
                }
                if (first)
                {
                    point = agent.aimAt;
                    first = false;
                }
                agent.aimAt = point;
                agent.locked = true;
                sim.events.Append(new GDict { { "type", "railgun_locked" }, { "agent", agent.id }, { "x", point.x }, { "z", point.y } });
            }
        }

        public void _Fire(Taskforce.Agent agent)
        {
            double reach = Num.F(cfg["hit_radius"]);
            GDict shot = new GDict { { "type", "railgun_hit" }, { "agent", agent.id }, { "from", agent.Muzzle() } };
            if (sim.kaijuPos.DistanceTo(agent.aimAt) <= reach)
            {
                // armour softens it as it does a tank's shell (D-161), never below the army's minimum
                double damage = Gd.Maxf(Num.F(sim.army["min_damage"]), sim.maxHp * Num.F(cfg["share"]) - sim.Stat("armor"));
                sim.hp -= damage;
                // every hit fires the colour fringe (D-145); `share` is what it cost of max health
                sim.events.Append(shot.Merged(new GDict { { "damage", damage }, { "share", damage / sim.maxHp }, { "x", sim.kaijuPos.x }, { "z", sim.kaijuPos.y } }));
            }
            else
            {
                sim.events.Append(new GDict { { "type", "railgun_missed" }, { "agent", agent.id }, { "x", agent.aimAt.x }, { "z", agent.aimAt.y } });
            }
            agent.state = Taskforce.PERCH;
            agent.railCd = Num.F(cfg["cooldown"]) - _Trail(agent);
            agent.wait = Num.F(cfg["hop_after"]);
        }
        // How long after its volley's first shot this one is, in the volley's own steps: the gunner's
        // cooldown starts then, so the whole squad's railguns come ready on the same step again.

        public double _Trail(Taskforce.Agent agent)
        {
            GDict volley = _volleys.Get(agent.squad, new GDict());
            if (volley.IsEmpty())
            {
                return 0.0;
            }
            if (Num.F(volley["first"]) < 0.0)
            {
                volley["first"] = volley["age"];
            }
            return Num.F(volley["age"]) - Num.F(volley["first"]);
        }

        void _InitFields()
        {
        }
    }
}
