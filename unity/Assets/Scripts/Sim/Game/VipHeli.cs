// Generated from sim/vip_heli.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class VipHeli : RefCounted
    {
        public static implicit operator VipHeli(Variant v) => (VipHeli)v.Obj;

        // The leader's escape helicopter (D-149): once a rampage, at a seeded moment, the city's leader
        // (Mayor, Governor or President by city) lifts off a mid-rise roof and flees. It climbs while it
        // flies one smooth lap beside the pad, curling away from the kaiju (a banked circle at its own
        // speed, never pinned to the kaiju, D-183; never through it, director 2026-10-30), then runs
        // straight for the map edge so that the whole flight takes about `window_seconds`. Bringing it down
        // pays `payout` (about a city block's worth, Tuning "vip"); letting it reach the edge costs only
        // that payout. How it dies (one blow, no hit points, D-437): any area attack that reaches its
        // height (the breath, the Thunder Beam; a stomp or tail only while it is still low over the
        // roofs) or a toppling tower sweeping its height. It falls like any gunship (AirWing's fates and
        // wreck), under its own id. Own file and own seeded stream, so it never shifts the army's or the
        // air wing's draws. Part of RampageSim.
        // Its id among the sky's helicopters: far above AirWing's own counter.
        public const long ID = 1000000;
        public static readonly Vector2 NO_TARGET = new Vector2(Gd.INF, Gd.INF);
        public RampageSim sim;
        public GDict cfg = new GDict();
        // "waiting" (before lift-off), "flying", "killed", "escaped" or "none" (no roof to lift off).
        public string state = "waiting";
        public Vector2 pos = Vector2.ZERO;
        public double heading = 0.0;
        public double speed = 0.0;
        // Radians a second it is turning now: the view banks on it.
        public double turnRate = 0.0;
        public double flightT = 0.0;
        public string rank = "";
        // What a kill pays (before the kaiju's rubble multiplier), and what it paid.
        public double payout = 0.0;
        public double paid = 0.0;
        public RandomNumberGenerator _rng;
        // its own fall draws: a kill never shifts the air wing's
        public RandomNumberGenerator _fallRng;
        public double _spawnAt = 0.0;
        public double _roof = 0.0;
        public double _turned = 0.0;
        public Vector2 _exit = NO_TARGET;
        public double _dashSpeed = 0.0;
        public double _lastBlow = 0.0;

        public VipHeli(RampageSim pSim, GDict pCfg, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            _rng = rng;
            _fallRng = Seeds.Derive(rng, 0x71CL);
            GArray<Variant> window = cfg["window"];
            _spawnAt = Gd.Lerpf(Num.F(window[0]), Num.F(window[1]), _rng.Randf()) * sim.Stat("run_seconds");
            GArray<Variant> ranks = cfg["ranks"];
            GArray<Variant> payouts = cfg["payout"];
            long tier = Gd.Clampi(sim.SizeTier() - 1, 0, ranks.Size() - 1);
            rank = Gd.Str(ranks[tier]);
            payout = Num.F(payouts[tier]);
        }
        // Is it in the air now (the one thing the view and the other powers ask)?

        public bool Flying()
        {
            return state == "flying";
        }
        // Its height: off the pad's roof at lift-off, climbing to its cruise over `climb_seconds`.

        public double Altitude()
        {
            double up = Gd.Smoothstep(0.0, 1.0, flightT / Gd.Maxf(0.1, Num.F(cfg["climb_seconds"])));
            return Gd.Lerpf(_roof, Num.F(cfg["altitude"]), up);
        }
        // What the result screen and the news read.

        public GDict Summary()
        {
            return new GDict { { "vip_killed", (state == "killed" ? 1 : 0) }, { "vip_escaped", (state == "escaped" ? 1 : 0) }, { "vip_paid", paid } };
        }

        public void Step(double dt)
        {
            if (state == "waiting")
            {
                if (sim.elapsed >= _spawnAt)
                {
                    _LiftOff();
                }
                return;
            }
            if (state != "flying")
            {
                return;
            }
            flightT += dt;
            _SweptByFalls();
            if (state == "flying")
            {
                _Fly(dt);
            }
        }
        // An area attack: reaches it when it fires into the sky (hit_air) or the kaiju stands as high.

        public void Hit(Callable force, double damage)
        {
            // a gunship wreck's impact never reaches the sky
            if ((state != "flying" || sim.air._crashing))
            {
                return;
            }
            if (!(((sim.hitAir || sim.ReachTop() >= Altitude()))))
            {
                return;
            }
            double k = force.Call(pos, Num.F(cfg["radius"]));
            if (k <= 0.0)
            {
                return;
            }
            _lastBlow = damage * k;
            Down("blow");
        }
        // It is down: pays the kill, then falls as AirWing's fates say.

        public void Down(string by)
        {
            state = "killed";
            paid = payout * sim.Stat("rubble_mult");
            sim.rubble += paid;
            GDict air = sim.air.cfg;
            var heli = new AirWing.Heli();
            heli.id = ID;
            heli.pos = pos;
            GDict @event = new GDict { { "type", "vip_down" }, { "heli", ID }, { "x", pos.x }, { "z", pos.y }, { "y", Altitude() } };
            if (_lastBlow >= Num.F(air["burst_blow"]))
            {
                @event["fate"] = "burst";
            }
            else
            {
                @event.Merge(sim.air._SpinDown(heli, _fallRng));
            }
            sim.events.Append(@event);
            sim.events.Append(new GDict { { "type", "vip_killed" }, { "rank", rank }, { "payout", paid }, { "by", by } });
        }

        public void _LiftOff()
        {
            long pad = _PickPad();
            if (pad < 0)
            {
                state = "none";
                return;
            }
            var b = sim.buildings[pad];
            _roof = Gd.Minf(Gd.Float(b.height), Num.F(cfg["altitude"]) - 1.0);
            pos = new Vector2(b.x, b.z);
            // The lap curls away from the kaiju (director 2026-10-30: it flew straight into the kaiju every
            // time; it is something to chase): it sets off sideways, its circle's centre beyond the pad.
            double away = (pos - sim.kaijuPos).Angle();
            heading = away - Gd.PI * 0.5 + (_rng.Randf() - 0.5) * Gd.DegToRad(Num.F(cfg["lap_jitter_deg"]));
            state = "flying";
            sim.events.Append(new GDict { { "type", "vip_spawned" }, { "heli", ID }, { "rank", rank }, { "x", pos.x }, { "z", pos.y } });
        }
        // A seeded standing mid-rise in the arena, near enough to chase; any such roof when none is near.

        public long _PickPad()
        {
            GArray<Variant> heights = cfg["pad_height"];
            GArray<Variant> rangeM = cfg["pad_range"];
            GArray<long> near = new GArray<long>();
            GArray<long> any = new GArray<long>();
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                var b = sim.buildings[i];
                var tall = b.height >= Num.I(heights[0]) && b.height <= Num.I(heights[1]);
                if (!((tall && b.inArena && _Standing(i))))
                {
                    continue;
                }
                any.Append(i);
                double gap = new Vector2(b.x, b.z).DistanceTo(sim.kaijuPos);
                if (gap >= Num.F(rangeM[0]) && gap <= Num.F(rangeM[1]))
                {
                    near.Append(i);
                }
            }
            var pool = (!near.IsEmpty() ? near : any);
            return (pool.IsEmpty() ? -1 : pool[_rng.Randi() % pool.Size()]);
        }
        // Does building `i` still stand? A building the kaiju has been near is promoted to the fine
        // destruction grid (Carving), and its coarse frame then reads empty: ask the grid.

        public bool _Standing(long i)
        {
            var grid = sim.carving.Frame(i);
            return ((grid != null ? grid.aliveCount : sim.buildings[i].frame.aliveCount)) > 0;
        }
        // A tower toppling this step that reaches its height sweeps its landing strip: it goes down.

        public void _SweptByFalls()
        {
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
                    continue;
                }
                double half = Num.F(@event["width"]) * 0.5 + Num.F(cfg["radius"]);
                double t = Gd.Clampf((pos - start).Dot(span) / Gd.Maxf(0.001, span.LengthSquared()), 0.0, 1.0);
                if (pos.DistanceTo(start + span * t) <= half)
                {
                    // knocked aside, never blown apart
                    _lastBlow = 0.0;
                    Down("topple");
                    return;
                }
            }
        }
        // One step of the flight: the banked lap round the pad, then the dash to the edge.

        public void _Fly(double dt)
        {
            double radius = Num.F(cfg["circle_radius"]) * sim.BodyScale();
            double lapSpeed = Gd.TAU * radius / Num.F(cfg["circle_seconds"]);
            if (_turned < Gd.TAU)
            {
                speed = lapSpeed * Gd.Minf(1.0, flightT / Num.F(cfg["liftoff_seconds"]));
                turnRate = speed / radius;
                heading += turnRate * dt;
                _turned += turnRate * dt;
                if (_turned >= Gd.TAU)
                {
                    _BeginDash(lapSpeed);
                }
            }
            else
            {
                _Dash(dt);
            }
            pos += Vector2.FromAngle(heading) * speed * dt;
            double limit = sim.arenaHalf + Num.F(cfg["exit_margin"]);
            if (((Gd.Absf(pos.x) >= limit || Gd.Absf(pos.y) >= limit || flightT >= Num.F(cfg["window_seconds"]) * Num.F(cfg["escape_cap"]))))
            {
                state = "escaped";
                sim.events.Append(new GDict { { "type", "vip_escaped" }, { "heli", ID }, { "rank", rank }, { "payout", payout } });
            }
        }
        // Picks the edge point it runs to, away from the kaiju, and the speed that makes the whole
        // flight last `window_seconds`.

        public void _BeginDash(double lapSpeed)
        {
            double away = (pos - sim.kaijuPos).Angle();
            double spread = Gd.DegToRad(Num.F(cfg["exit_spread_deg"]));
            var dir = Vector2.FromAngle(away + _rng.RandfRange(-spread, spread));
            double limit = sim.arenaHalf + Num.F(cfg["exit_margin"]);
            double reach = Gd.INF;
            foreach (long axis in Gd.Range(2))
            {
                if (Gd.Absf(dir[axis]) > 0.001)
                {
                    reach = Gd.Minf(reach, (limit * Gd.Signf(dir[axis]) - pos[axis]) / dir[axis]);
                }
            }
            _exit = pos + dir * reach;
            double left = Gd.Maxf(1.0, Num.F(cfg["window_seconds"]) - flightT);
            _dashSpeed = Gd.Maxf(lapSpeed, pos.DistanceTo(_exit) / left);
        }
        // Straight for the edge: turning no faster than `turn_limit` rad/s, gathering speed to its dash.

        public void _Dash(double dt)
        {
            double want = (_exit - pos).Angle();
            double limit = Num.F(cfg["turn_limit"]) * dt;
            double turn = Gd.Clampf(Gd.AngleDifference(heading, want), -limit, limit);
            heading += turn;
            turnRate = turn / Gd.Maxf(0.001, dt);
            speed = Gd.MoveToward(speed, _dashSpeed, Num.F(cfg["accel"]) * dt);
        }

        void _InitFields()
        {
        }
    }
}
