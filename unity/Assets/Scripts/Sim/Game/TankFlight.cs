// Generated from sim/tank_flight.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TankFlight : RefCounted
    {
        public static implicit operator TankFlight(Variant v) => (TankFlight)v.Obj;

        // Tanks the reptilian sends flying (research 22 recs 2-4; director 2026-10-30: real flung tanks
        // first, then Ricochet and Domino on them). The ram and the leap launch a tank on a ballistic arc
        // that lands where today's shove put it (launch(): the distance sets the speed at loft_deg). Each
        // tick it moves by exact constant-gravity kinematics; a standing chunk ahead at its height is a
        // wall: it bores a hull-sized tunnel and flies on out the far side or sticks there, wedged
        // (TankHold). The ground (the street, a floor inside, or a roof it caves in) ends the flight, and
        // the tank with it: it comes down wrecked (no hit points, director 2026-11-01: "if the tank gets
        // smacked by a kaiju, i want that tank to go flying and die"); a wreck above the street stays,
        // a husk, until its floor goes.
        // Ricochet (throw_ricochet, per level) gives a bounce off a wall or the ground instead of
        // stopping, at wall_restitution / ground_restitution. Domino (throw_domino, per level) is chain
        // depth: a flying tank that reaches a grounded one launches it on
        // along its own way, domino_reach out, one generation deeper. An airborne tank neither drives
        // nor fires (Convoy, Army skip it). It tumbles
        // (director 2026-10-30, "Seeded mix"): each launch spins it about an axis from this class's own
        // seeded stream; where it lands past topple_deg it rests on its side or roof, toppled for good
        // ("Lands as it falls"). Numbers are army.flight in data/tuning.json.
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Tanks launched, walls hit and tanks knocked on by Domino this rampage (the fixtures read them).
        public long launched = 0;
        public long wallsHit = 0;
        public long knocked = 0;
        public long toppled = 0;
        // Bores, wedges, caved-in roofs and the husks they leave (TankHold).
        public TankHold hold;
        public RandomNumberGenerator _rng;

        public TankFlight(RampageSim pSim, GDict pCfg, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            _rng = rng;
            GDict holdCfg = pCfg["hold"];
            hold = new TankHold(pSim, holdCfg);
        }
        // Sends `tank` flying along `dir` to land `distance` out on open ground; chain generation `gen`.

        public void Launch(RampageSim.Tank tank, Vector2 dir, double distance, long gen = 0)
        {
            if ((distance <= Num.F(cfg["min_distance"]) || dir == Vector2.ZERO))
            {
                return;
            }
            double loft = Gd.DegToRad(Num.F(cfg["loft_deg"]));
            double g = Num.F(cfg["gravity"]);
            double speed = Gd.Sqrt(distance * g / Gd.Sin(2.0 * loft));
            var flat = dir.Normalized() * speed * Gd.Cos(loft);
            tank.vel = new Vector3(flat.x, speed * Gd.Sin(loft), flat.y);
            tank.flying = true;
            tank.bounces = 0;
            tank.gen = gen;
            tank.toppled = false;
            tank.spin = _Spin(speed * Gd.Sin(loft) * 2.0 / g);
            launched += 1;
            sim.events.Append(new GDict { { "type", "tank_launched" }, { "tank", tank.id }, { "from", tank.pos }, { "height", tank.height }, { "vel", tank.vel }, { "gen", gen } });
        }

        public void Step(double dt)
        {
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                if (tank.flying)
                {
                    _Fly(tank, dt);
                }
            }
            hold.Step(dt);
        }

        public void _Fly(RampageSim.Tank tank, double dt)
        {
            double g = Num.F(cfg["gravity"]);
            var flat = new Vector2(tank.vel.x, tank.vel.z);
            var next = sim.ClampToArena(tank.pos + flat * dt);
            double y = tank.height + tank.vel.y * dt - 0.5 * g * dt * dt;
            // what it flew level with: walls, floors
            double fromY = tank.height + Num.F(cfg["clearance"]);
            tank.vel.y -= g * dt;
            if (hold.Solid(next, fromY))
            {
                if (!_Wall(tank, next, y, fromY))
                {
                    // wedged where the tunnel ends
                    return;
                }
                // bounced back off, or out the far side (TankHold.bore)
                next = tank.pos;
            }
            tank.pos = next;
            tank.height = y;
            if (tank.spin != Vector3.ZERO)
            {
                var turn = new Basis(tank.spin.Normalized(), tank.spin.Length() * dt);
                tank.tilt = (turn * tank.tilt).Orthonormalized();
            }
            _Strike(tank);
            double ground = hold.FloorUnder(tank.pos, fromY);
            if (tank.height <= ground)
            {
                tank.height = ground;
                _TouchDown(tank);
            }
        }
        // A building in the way at `next`: with a bounce left (Ricochet) it carves round the impact and
        // bounces back off; else it bores in (TankHold.bore). False if it stuck there, wedged.

        public bool _Wall(RampageSim.Tank tank, Vector2 next, double y, double fromY)
        {
            wallsHit += 1;
            var flat = new Vector2(tank.vel.x, tank.vel.z);
            sim.events.Append(new GDict { { "type", "tank_hit_wall" }, { "tank", tank.id }, { "at", next }, { "height", y } });
            if (!_BounceLeft(tank))
            {
                return hold.Bore(tank, next, y, flat);
            }
            double radius = Num.F(cfg["wall_radius"]);
            long floorAt = Gd.Maxi(0, Gd.Floori(y));
            sim.HitArea(new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(p.DistanceTo(next) - r, radius);
            }), flat.Length() * Num.F(cfg["wall_damage"]), floorAt, floorAt + Num.I(cfg["wall_floors"]));
            tank.bounces += 1;
            var normal = _WallNormal(tank.pos, next, fromY);
            flat = (flat - 2.0 * flat.Dot(normal) * normal) * Num.F(cfg["wall_restitution"]);
            tank.vel = new Vector3(flat.x, tank.vel.y, flat.y);
            return true;
        }
        // Which way the wall faces: the axis whose step alone runs into it (both: straight back).

        public Vector2 _WallNormal(Vector2 from, Vector2 next, double fromY)
        {
            var xHits = hold.Solid(new Vector2(next.x, from.y), fromY);
            var zHits = hold.Solid(new Vector2(from.x, next.y), fromY);
            var step = next - from;
            if (xHits && !zHits)
            {
                return new Vector2(Gd.Signf(step.x), 0.0);
            }
            if (zHits && !xHits)
            {
                return new Vector2(0.0, Gd.Signf(step.y));
            }
            return step.Normalized();
        }

        public void _TouchDown(RampageSim.Tank tank)
        {
            double fall = -tank.vel.y;
            if (fall > Num.F(cfg["min_bounce_speed"]) && _BounceLeft(tank))
            {
                tank.bounces += 1;
                double keep = 1.0 - Num.F(cfg["ground_friction"]);
                tank.vel = new Vector3(tank.vel.x * keep, fall * Num.F(cfg["ground_restitution"]), tank.vel.z * keep);
                tank.spin *= keep;
                sim.events.Append(new GDict { { "type", "tank_bounced" }, { "tank", tank.id }, { "at", tank.pos } });
                return;
            }
            tank.vel = Vector3.ZERO;
            tank.flying = false;
            tank.wrecked = true;
            _Settle(tank);
            // come down on a roof: it caves in
            hold.Punch(tank, fall);
            sim.events.Append(new GDict { { "type", "tank_landed" }, { "tank", tank.id }, { "at", tank.pos }, { "height", tank.height }, { "toppled", tank.toppled } });
        }
        // A seeded tumble for a flight of `seconds`: a random axis (a mix of flip, roll and yaw) turned
        // spin_turns_min..max times over the flight.

        public Vector3 _Spin(double seconds)
        {
            var axis = new Vector3(_rng.RandfRange(-1.0, 1.0), _rng.RandfRange(-1.0, 1.0), _rng.RandfRange(-1.0, 1.0));
            double turns = _rng.RandfRange(Num.F(cfg["spin_turns_min"]), Num.F(cfg["spin_turns_max"]));
            if ((axis == Vector3.ZERO || seconds <= 0.0))
            {
                return Vector3.ZERO;
            }
            return axis.Normalized() * turns * Gd.TAU / seconds;
        }
        // The hull comes to rest as it fell: within topple_deg of upright it drops onto its tracks;
        // past it, onto its roof (upside down past the same angle) or else its side, toppled.

        public void _Settle(RampageSim.Tank tank)
        {
            tank.spin = Vector3.ZERO;
            var up = tank.tilt * Vector3.UP;
            double lean = Gd.Cos(Gd.DegToRad(Num.F(cfg["topple_deg"])));
            if (up.y >= lean)
            {
                tank.tilt = Basis.IDENTITY;
                return;
            }
            var rest = (up.y <= -lean ? Vector3.DOWN : new Vector3(up.x, 0.0, up.z).Normalized());
            tank.tilt = (new Basis(new Quaternion(up.Normalized(), rest)) * tank.tilt).Orthonormalized();
            tank.toppled = true;
            toppled += 1;
        }

        public bool _BounceLeft(RampageSim.Tank tank)
        {
            return tank.bounces < Num.I(cfg["bounces"]) + Gd.Roundi(sim.Stat("throw_ricochet"));
        }
        // Domino: a grounded tank within strike_radius of a flying one of a shallower generation than the
        // node's depth is knocked on along the flyer's way.

        public void _Strike(RampageSim.Tank tank)
        {
            if (tank.gen >= Gd.Roundi(sim.Stat("throw_domino")))
            {
                return;
            }
            double reach = Num.F(cfg["strike_radius"]);
            var flat = new Vector2(tank.vel.x, tank.vel.z);
            foreach (RampageSim.Tank other in sim.tanks)
            {
                if ((other == tank || other.flying || other.wrecked))
                {
                    continue;
                }
                if ((other.pos.DistanceTo(tank.pos) > reach || tank.height - other.height > reach))
                {
                    continue;
                }
                var way = (flat != Vector2.ZERO ? flat : other.pos - tank.pos);
                knocked += 1;
                sim.events.Append(new GDict { { "type", "tank_knocked" }, { "tank", other.id }, { "by", tank.id } });
                Launch(other, way, Num.F(cfg["domino_reach"]), tank.gen + 1);
            }
        }

        void _InitFields()
        {
        }
    }
}
