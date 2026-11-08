// Generated from sim/tank_spacing.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TankSpacing : RefCounted
    {
        public static implicit operator TankSpacing(Variant v) => (TankSpacing)v.Obj;

        // Tank-to-tank spacing and right of way (D-066): no tank drives, pivots or backs any part of
        // itself into another; a younger tank gives way to an older one held up. A tank is what the
        // view draws: its hull along its front, its turret and gun turned to the kaiju (the turret
        // tracks it), each grown by `clear`. Part of Convoy; numbers are
        // army.convoy (hull, turret, gun, clear, follow) in data/tuning.json.
        public Convoy convoy;
        public RampageSim sim;
        public GDict cfg = new GDict();
        // The clearance grown round each part while a touch (not a clash) is asked; below 0, the tuned one.
        public double _margin = -1.0;

        public TankSpacing(Convoy pConvoy)
        {
            _InitFields();
            convoy = pConvoy;
            sim = convoy.sim;
            cfg = convoy.cfg;
        }
        // The tank in the way of a move to `next` with its hull along `dir`, or null: never into a new
        // clash (out of one only by opening up), never closer than `follow` behind one going its way
        // in its lane.

        public RampageSim.Tank Blocker(RampageSim.Tank tank, Vector2 next, Vector2 dir)
        {
            GArray<Variant> gun = cfg["gun"];
            double reach = _Half("hull").Length() + Num.F(gun[0]) + Num.F(cfg["follow"]);
            foreach (RampageSim.Tank other in sim.tanks)
            {
                if ((other.id == tank.id || next.DistanceTo(other.pos) > reach))
                {
                    continue;
                }
                if (_InTheWay(tank, other, next, dir))
                {
                    return other;
                }
            }
            return null;
        }
        // Whether `other` stops `tank` moving to `next` with its hull along `dir`.

        public bool _InTheWay(RampageSim.Tank tank, RampageSim.Tank other, Vector2 next, Vector2 dir)
        {
            double then = next.DistanceTo(other.pos);
            double now = tank.pos.DistanceTo(other.pos);
            var facing = _HullOf(other, dir);
            // a pivot in place: only its hull swings
            if (next.DistanceTo(tank.pos) < 0.0001)
            {
                if (_PivotClash(tank, other, next, dir))
                {
                    return true;
                }
            }
            else if (Clash(next, dir, other.pos, facing))
            {
                if ((then <= now || !(Clash(tank.pos, _HullOf(tank, dir), other.pos, facing))))
                {
                    return true;
                }
            }
            return (then < now && _InLane(tank, other, dir) && then < Num.F(cfg["follow"]) && facing.Dot(dir) > 0.7);
        }
        // The way a tank's hull lies now (`fallback` while it has no heading yet).

        public Vector2 _HullOf(RampageSim.Tank tank, Vector2 fallback)
        {
            ConvoyRoute r = convoy.routes.Get(tank.id);
            return (r != null && r.front != Vector2.ZERO ? r.front : fallback);
        }
        // `tank` pivoting at p to hull `dir` against `other`. Never into a new clash; and from inside one
        // (it parked within `clear` of a neighbour) never to where the drawn parts themselves touch
        // (0 m margin).

        public bool _PivotClash(RampageSim.Tank tank, RampageSim.Tank other, Vector2 p, Vector2 dir)
        {
            var own = _HullOf(tank, dir);
            var facing = _HullOf(other, dir);
            var q = other.pos;
            return (((HullClash(p, dir, q, facing) && !HullClash(p, own, q, facing)) || HullTouch(p, dir, q, facing)));
        }
        // Whether `other` is ahead of `tank` along `dir`, within two hull half-widths of its line.

        public bool _InLane(RampageSim.Tank tank, RampageSim.Tank other, Vector2 dir)
        {
            var ahead = other.pos - tank.pos;
            return dir.Dot(ahead) > 0.0 && Gd.Absf(dir.Cross(ahead)) < _Half("hull").y * 2.0;
        }
        // A standing tank (parked, or waiting held up) whose gun has swung over an older one's, or the
        // older one's over it (the kaiju moved), steps along its own hull away from it, `step` at a time,
        // while that keeps it on the road and clear of others.

        public void OpenUp(RampageSim.Tank tank, ConvoyRoute r, double step)
        {
            if (r.front == Vector2.ZERO)
            {
                return;
            }
            foreach (RampageSim.Tank other in sim.tanks)
            {
                ConvoyRoute o = convoy.routes.Get(other.id);
                if ((other.id >= tank.id || o == null || o.front == Vector2.ZERO))
                {
                    continue;
                }
                if (!Clash(tank.pos, r.front, other.pos, o.front))
                {
                    continue;
                }
                var away = (r.front.Dot(tank.pos - other.pos) >= 0.0 ? r.front : -r.front);
                var to = tank.pos + away * step;
                if (convoy.graph.Drivable(to, r.front) && Blocker(tank, to, r.front) == null)
                {
                    tank.pos = to;
                    r.reversing = away.Dot(r.front) < 0.0;
                }
                return;
            }
        }
        // The longest one stretch of giving way lasts (stuck x yield_cap seconds), then the tank re-plans.

        public double YieldLimit()
        {
            return Num.F(cfg["stuck"]) * Num.F(cfg["yield_cap"]);
        }
        // Giving way: back up while the older tank is held up (up to yield_limit), then wait.

        public void Yielding(RampageSim.Tank tank, ConvoyRoute r, double dt, double back)
        {
            r.yieldT -= dt;
            foreach (RampageSim.Tank older in sim.tanks)
            {
                if (older.id != r.giveTo)
                {
                    continue;
                }
                BackOff(tank, older, back);
                ConvoyRoute o = convoy.routes.Get(older.id);
                var held = o != null && o.stuckT > 0.0;
                if (held && r.yieldT <= 0.0 && r.yieldAll < YieldLimit())
                {
                    r.yieldT = dt;
                }
                r.yieldAll += dt;
            }
        }
        // Right of way: blocked by an older tank that is itself held up trying to move, the younger
        // one gives way for `stuck` seconds.

        public void GiveWay(RampageSim.Tank tank, RampageSim.Tank blocker, double back)
        {
            DemandWay(tank, blocker);
            ConvoyRoute o = convoy.routes.Get(blocker.id);
            if ((!Outranks(blocker, tank) || o == null || o.path.IsEmpty() || o.stuckT <= 0.0))
            {
                return;
            }
            ConvoyRoute r = convoy.routes[tank.id];
            r.giveTo = blocker.id;
            r.yieldT = Num.F(cfg["stuck"]);
            BackOff(tank, blocker, back);
        }
        // Is the tank inside the danger radius (the kaiju on top of it)?

        public bool InDanger(RampageSim.Tank tank)
        {
            return convoy.posts.ToBody(tank.pos) < convoy.Danger();
        }
        // Right of way: a tank inside the danger radius outranks one outside it; otherwise the older.

        public bool Outranks(RampageSim.Tank first, RampageSim.Tank second)
        {
            var firstIn = InDanger(first);
            if (firstIn != InDanger(second))
            {
                return firstIn;
            }
            return first.id < second.id;
        }
        // Held up by a tank outside the danger radius while inside it: that tank gives way at once
        // (backs along its hull as give_way does), so a retreating tank is not left standing under the
        // kaiju waiting for the younger one to find out it is in the way. Not once it has yielded for
        // yield_limit() (the cap in yielding()): a boxed-in blocker gets its free step and re-plans instead
        // of being re-armed every step the other tank stays held up.

        public void DemandWay(RampageSim.Tank tank, RampageSim.Tank blocker)
        {
            ConvoyRoute o = convoy.routes.Get(blocker.id);
            if ((o == null || !InDanger(tank) || InDanger(blocker)))
            {
                return;
            }
            if (o.yieldAll >= YieldLimit())
            {
                return;
            }
            o.giveTo = tank.id;
            o.yieldT = Num.F(cfg["stuck"]);
        }
        // Straight back along its hull, away from the older tank, only while the hull stays on the road.

        public void BackOff(RampageSim.Tank tank, RampageSim.Tank older, double step)
        {
            ConvoyRoute o = convoy.routes.Get(older.id);
            ConvoyRoute r = convoy.routes[tank.id];
            if ((o == null || o.stuckT <= 0.0))
            {
                return;
            }
            var own = (r.front != Vector2.ZERO ? r.front : (tank.pos - older.pos).Normalized());
            if (!convoy.graph.Square(r.front, r.edge))
            {
                // half turned: it squares up first (_settle), then backs
                return;
            }
            var back = (own.Dot(tank.pos - older.pos) > 0.0 ? own : -own);
            // the older tank is under the kaiju: out of its way at retreat pace
            if (InDanger(older))
            {
                step *= Num.F(cfg["retreat_speed"]) / (Num.F(sim.army["speed"]) * Num.F(cfg["reverse"]));
            }
            var to = tank.pos + back * step;
            if (convoy.graph.Drivable(to, own) && Blocker(tank, to, own) == null)
            {
                tank.pos = to;
                r.reversing = back.Dot(own) < 0.0;
            }
        }
        // Do two tanks as drawn (hull along u / w, turret and gun on the kaiju), each grown by
        // `clear`, touch?

        public bool Clash(Vector2 p, Vector2 u, Vector2 q, Vector2 w)
        {
            var mine = _Boxes(p, u);
            var theirs = _Boxes(q, w);
            foreach (long i in Gd.Range(0, 9, 3))
            {
                foreach (long j in Gd.Range(0, 9, 3))
                {
                    var at = theirs[j];
                    if (BoxesOverlap(mine[i], mine[i + 1], mine[i + 2], at, theirs[j + 1], theirs[j + 2]))
                    {
                        return true;
                    }
                }
            }
            return false;
        }
        // Does the hull at p (along u) touch any part of the tank at q (hull along w), or its hull
        // touch this tank's turret or gun? (A pivot moves only the hull: turrets track the kaiju.)

        public bool HullClash(Vector2 p, Vector2 u, Vector2 q, Vector2 w)
        {
            var mine = _Boxes(p, u);
            var theirs = _Boxes(q, w);
            foreach (long j in Gd.Range(0, 9, 3))
            {
                var at = theirs[j];
                if (BoxesOverlap(mine[0], mine[1], mine[2], at, theirs[j + 1], theirs[j + 2]))
                {
                    return true;
                }
            }
            foreach (long i in Gd.Range(3, 9, 3))
            {
                if (BoxesOverlap(mine[i], mine[i + 1], mine[i + 2], theirs[0], theirs[1], theirs[2]))
                {
                    return true;
                }
            }
            return false;
        }
        // hull_clash with no clearance grown: do the drawn parts themselves touch?

        public bool HullTouch(Vector2 p, Vector2 u, Vector2 q, Vector2 w)
        {
            _margin = 0.0;
            var touching = HullClash(p, u, q, w);
            _margin = -1.0;
            return touching;
        }
        // Centre, long axis and half extents, in turn, for the hull, the turret and the gun at p.

        public PackedVector2Array _Boxes(Vector2 p, Vector2 front)
        {
            var aim = (sim.kaijuPos - p).Normalized();
            if (aim == Vector2.ZERO)
            {
                aim = front;
            }
            var gun = _Half("gun");
            return new PackedVector2Array(Gd.Arr(p, front, _Half("hull"), p, aim, _Half("turret"), p + aim * gun.x, aim, gun));
        }

        public Vector2 _Half(string part)
        {
            GArray<Variant> size = cfg[part];
            double clear = (_margin < 0.0 ? Num.F(cfg["clear"]) : _margin);
            return new Vector2(Num.F(size[0]), Num.F(size[1])) * 0.5 + new Vector2(clear, clear);
        }
        // Do two oriented boxes overlap (separating axes)? Centre, long axis, half extents each.

        public static bool BoxesOverlap(Vector2 p, Vector2 u, Vector2 ha, Vector2 q, Vector2 w, Vector2 hb)
        {
            var d = q - p;
            foreach (Vector2 axis in ((GArray<Vector2>)Gd.Arr(u, u.Orthogonal(), w, w.Orthogonal())))
            {
                double ra = ha.x * Gd.Absf(u.Dot(axis)) + ha.y * Gd.Absf(u.Orthogonal().Dot(axis));
                double rb = hb.x * Gd.Absf(w.Dot(axis)) + hb.y * Gd.Absf(w.Orthogonal().Dot(axis));
                if (Gd.Absf(d.Dot(axis)) > ra + rb)
                {
                    return false;
                }
            }
            return true;
        }

        void _InitFields()
        {
        }
    }
}
