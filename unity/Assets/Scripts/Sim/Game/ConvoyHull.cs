// Generated from sim/convoy_hull.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class ConvoyHull : RefCounted
    {
        public static implicit operator ConvoyHull(Variant v) => (ConvoyHull)v.Obj;

        // A tank's hull on the road (D-066), part of Convoy: where it fits, how it squares to its road,
        // and how it makes room to pivot. No tank turns or steps into a place its whole hull (and every
        // part of it on the way round) does not fit on the carriageway clear of other tanks. Numbers:
        // army.convoy (pivot_deg) in data/tuning.json.
        public Convoy convoy;
        public RoadGraph graph;
        public GDict cfg = new GDict();

        public ConvoyHull(Convoy pConvoy)
        {
            _InitFields();
            convoy = pConvoy;
            graph = convoy.graph;
            cfg = convoy.cfg;
        }
        // A leg askew to every road under the tank (a lane point past a crossing's centre, or one
        // square_leg could not square) is driven along the nearest of those roads: never crabbing.

        public Vector2 OntoAxis(Vector2 at, Vector2 to, long edge)
        {
            var v = to - at;
            if (v.Length() < 0.0001)
            {
                return to;
            }
            var way = v.Normalized();
            var best = Vector2.ZERO;
            foreach (long e in graph.RoadsAt(graph.CellOf(at)) + new PackedInt32Array(Gd.Arr(edge)))
            {
                if ((e < 0 || !graph.OnEdge(at, e)))
                {
                    continue;
                }
                if (graph.Square(way, e))
                {
                    return to;
                }
                if (Gd.Absf(way.Dot(graph.Axis(e))) > Gd.Absf(way.Dot(best)))
                {
                    best = graph.Axis(e);
                }
            }
            return (best == Vector2.ZERO ? to : at + best * v.Dot(best));
        }
        // No room to pivot here: a step along the hull (forward or back) to where the whole turn fits.

        public bool Shuffle(RampageSim.Tank tank, ConvoyRoute r, Vector2 turned, double step)
        {
            // never along a half-turned hull
            if (!graph.Square(r.front, r.edge))
            {
                return false;
            }
            foreach (Vector2 way in Gd.Arr(r.front, -r.front))
            {
                var to = tank.pos + way * step;
                if (Fits(tank, to, r.front) && SweepFits(tank, to, turned))
                {
                    tank.pos = to;
                    return true;
                }
            }
            return false;
        }

        public bool Fits(RampageSim.Tank tank, Vector2 at, Vector2 front)
        {
            return graph.Drivable(at, front) && convoy.spacing.Blocker(tank, at, front) == null;
        }
        // Room to swing the hull round to `to` standing at `at`, every pivot_deg of the way: a pivot
        // starts only when it can finish.

        public bool SweepFits(RampageSim.Tank tank, Vector2 at, Vector2 to)
        {
            ConvoyRoute r = convoy.routes[tank.id];
            double turn = r.front.AngleTo(to);
            long steps = Gd.Ceili(Gd.Absf(turn) / Gd.DegToRad(Num.F(cfg["pivot_deg"])));
            foreach (long k in Gd.Range(1, steps + 1))
            {
                if (!(Fits(tank, at, r.front.Rotated(turn * k / steps))))
                {
                    return false;
                }
            }
            return true;
        }
        // At its post a tank squares its hull to its road (the nearer way; parked at a crossing, the
        // road its hull lies nearer); only its turret turns. When that swing has no room (a tank
        // pulled up beside it mid-pivot), it squares to the nearest road axis at the crossing that
        // has, so it never waits half turned; a hull already within skew_deg of its road stays put
        // (swinging it toward the cross street only to swing back next step reads as crabbing).

        public void Settle(RampageSim.Tank tank, ConvoyRoute r, double rate)
        {
            if ((r.edge < 0 || r.front == Vector2.ZERO))
            {
                return;
            }
            var nearest = true;
            foreach (Vector2 want in _Axes(tank, r))
            {
                if (Gd.Absf(r.front.AngleTo(want)) < 0.0001)
                {
                    // squared already
                    return;
                }
                if (!nearest && graph.Square(r.front, r.edge))
                {
                    // square enough to its road (skew_deg): never swung toward a cross street
                    return;
                }
                nearest = false;
                var front = r.front.Rotated(Gd.Clampf(r.front.AngleTo(want), -rate, rate));
                if (Fits(tank, tank.pos, front))
                {
                    r.front = front;
                    return;
                }
            }
        }
        // The road axes under the tank, hull-ward way, nearest the hull first: the roads it means to lie
        // along, then any other road under it at a crossing.

        public GArray<Vector2> _Axes(RampageSim.Tank tank, ConvoyRoute r)
        {
            GArray<Vector2> first = new GArray<Vector2>();
            GArray<Vector2> then = new GArray<Vector2>();
            foreach (long e in graph.RoadsAt(graph.CellOf(tank.pos)) + new PackedInt32Array(Gd.Arr(r.edge)))
            {
                var under = graph.OnEdge(tank.pos, e);
                var mine = (e == r.edge || r.path.IsEmpty() && under);
                if ((mine || under))
                {
                    var list = (mine ? first : then);
                    list.Append(graph.Axis(e) * ((graph.Axis(e).Dot(r.front) >= 0.0 ? 1.0 : -1.0)));
                }
            }
            var nearer = new Callable(a_ =>
            {
                Vector2 x = a_[0];
                Vector2 y = a_[1];
                return x.Dot(r.front) > y.Dot(r.front);
            });
            first.SortCustom(nearer);
            then.SortCustom(nearer);
            return first + then;
        }

        void _InitFields()
        {
        }
    }
}
