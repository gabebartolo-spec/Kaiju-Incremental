// Generated from sim/firing_posts.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class FiringPosts : RefCounted
    {
        public static implicit operator FiringPosts(Variant v) => (FiringPosts)v.Obj;

        // Where a tank posts itself (D-066): a firing post on a road in the firing band round the
        // kaiju with a clear line of fire, spread from the other tanks' posts round it on an arc; with
        // every post taken, a reserve post out of range on the reserve ring or one behind it. Part of
        // Convoy; numbers are army.convoy in data/tuning.json.
        // body() held for one convoy step (Convoy.step): the kaiju does not move while tanks plan.
        public PackedVector2Array heldBody = new PackedVector2Array();
        public Convoy convoy;
        public RoadGraph graph;
        public RampageSim sim;
        public GDict cfg = new GDict();

        public FiringPosts(Convoy pConvoy)
        {
            _InitFields();
            convoy = pConvoy;
            graph = convoy.graph;
            sim = convoy.sim;
            cfg = convoy.cfg;
        }
        // The post for `tank` with routes `found` (RoadSearch.search): {at, node, edge, reserve}, or {}
        // to keep the reserve post it holds (or when there is none to be had). The cheapest route wins:
        // spread_deg round the kaiju from every other post first, then post_gap apart alone.

        public GDict Choose(RampageSim.Tank tank, ConvoyRoute r, GDict found, bool urgent)
        {
            var k = sim.kaijuPos;
            var others = _Posts(tank.id);
            double spread = Gd.DegToRad(Num.F(cfg["spread_deg"]));
            double follow = Num.F(cfg["follow"]);
            double gap = Num.F(cfg["post_gap"]);
            var cands = _BandPosts(tank, r, found);
            foreach (double arc in Gd.Arr(spread, 0.0))
            {
                foreach (GDict c in cands)
                {
                    Vector2 at = c["at"];
                    if (_Spaced(at, others, arc, gap) && ClearLine(at, k))
                    {
                        return c;
                    }
                }
            }
            double held = r.goal.DistanceTo(k);
            var rings = ReserveRings();
            double widest = rings[rings.Size() - 1] + follow;
            var keep = r.reserve && !urgent && held > convoy.Reach() && held < widest;
            if (keep && _Spaced(r.goal, others, 0.0, follow))
            {
                return new GDict();
            }
            foreach (GDict c in RingPosts(tank, r, found, rings))
            {
                Vector2 at = c["at"];
                if (_Spaced(at, others, 0.0, follow))
                {
                    c["reserve"] = true;
                    return c;
                }
            }
            return new GDict();
        }
        // The reserve ring (reserve x full reach) and three wider ones behind it.

        public GArray<double> ReserveRings()
        {
            double @out = convoy.Reach() * Num.F(cfg["reserve"]);
            GArray<double> rings = new GArray<double>();
            foreach (long n in Gd.Range(4))
            {
                rings.Append(@out * (1.0 + 0.25 * n));
            }
            return rings;
        }
        // Firing posts: points post_gap apart along every reachable, open road inside the firing band
        // (band x full reach), the ones nearest the standoff ring on the cheapest routes first.

        public GArray<GDict> _BandPosts(RampageSim.Tank tank, ConvoyRoute r, GDict found)
        {
            var k = sim.kaijuPos;
            GArray<Variant> band = cfg["band"];
            double lo = convoy.Reach() * Num.F(band[0]);
            double hi = convoy.Reach() * Num.F(band[1]);
            double mid = convoy.Reach() * Num.F(cfg["standoff"]);
            double step = Num.F(cfg["post_gap"]);
            GArray<GDict> cands = new GArray<GDict>();
            foreach (long e in graph.EdgesWithin(k, hi))
            {
                if ((graph.blocked[e] != 0 || r.skip.Has(e) || graph.OffLine(k, e) > hi))
                {
                    continue;
                }
                double length = graph.edgeLen[e];
                var a = graph.nodes[graph.edgeA[e]];
                var b = graph.nodes[graph.edgeB[e]];
                // metres along the road of the last post taken
                double last = -Gd.INF;
                foreach (long n in Gd.Range(Gd.Floori(length) + 1))
                {
                    var at = a.Lerp(b, Gd.Minf(1.0, n / Gd.Maxf(length, 0.001)));
                    double d = at.DistanceTo(k);
                    if ((d < lo || d > hi || n - last < step || ToBody(at) < convoy.Danger()))
                    {
                        continue;
                    }
                    last = n;
                    GDict c = _ReachPost(tank, r, found, Gd.Arr(e, at));
                    if (!c.IsEmpty())
                    {
                        c["cost"] = Num.F(c["cost"]) + Gd.Absf(d - mid) * 2.0;
                        cands.Append(c);
                    }
                }
            }
            cands.SortCustom(new Callable(a_ =>
            {
                GDict x = a_[0];
                GDict y = a_[1];
                return x["cost"] < y["cost"];
            }));
            return cands;
        }
        // Every point where a reachable, open road crosses one of `rings` round the kaiju, cheapest
        // route first.

        public GArray<GDict> RingPosts(RampageSim.Tank tank, ConvoyRoute r, GDict found, GArray<double> rings)
        {
            var k = sim.kaijuPos;
            GArray<GDict> cands = new GArray<GDict>();
            double widest = rings.Max();
            foreach (long e in graph.EdgesWithin(k, widest))
            {
                if ((graph.blocked[e] != 0 || r.skip.Has(e)))
                {
                    continue;
                }
                var a = graph.nodes[graph.edgeA[e]];
                var b = graph.nodes[graph.edgeB[e]];
                foreach (double ring in rings)
                {
                    foreach (double t in _RingHits(a, b, k, ring))
                    {
                        if (ToBody(a.Lerp(b, t)) < convoy.Danger())
                        {
                            continue;
                        }
                        GDict c = _ReachPost(tank, r, found, Gd.Arr(e, a.Lerp(b, t)));
                        if (!c.IsEmpty())
                        {
                            cands.Append(c);
                        }
                    }
                }
            }
            cands.SortCustom(new Callable(a_ =>
            {
                GDict x = a_[0];
                GDict y = a_[1];
                return x["cost"] < y["cost"];
            }));
            return cands;
        }
        // A post at spot = [road e, point at] and how to get there: {at, node (where the route
        // leaves the graph; -1 drives straight along the road the tank is on), edge, cost}, or {} if
        // out of reach.

        public GDict _ReachPost(RampageSim.Tank tank, ConvoyRoute r, GDict found, GArray<Variant> spot)
        {
            long e = spot[0];
            Vector2 at = spot[1];
            if (r.edge == e && graph.OnEdge(tank.pos, e))
            {
                var turn = !r.path.IsEmpty() && (at - tank.pos).Dot(r.heading) < 0.0;
                double extra = (turn ? Num.F(cfg["uturn_cost"]) : 0.0);
                return new GDict { { "at", at }, { "node", -1 }, { "edge", e }, { "cost", tank.pos.DistanceTo(at) + extra } };
            }
            PackedFloat32Array cost = found["cost"];
            long na = graph.edgeA[e];
            long nb = graph.edgeB[e];
            double viaA = cost[na] + graph.nodes[na].DistanceTo(at);
            double viaB = cost[nb] + graph.nodes[nb].DistanceTo(at);
            if (Gd.Minf(viaA, viaB) == Gd.INF)
            {
                return new GDict();
            }
            return new GDict { { "at", at }, { "node", (viaA <= viaB ? na : nb) }, { "edge", e }, { "cost", Gd.Minf(viaA, viaB) } };
        }
        // Parameters t in [0, 1] where segment a-b crosses the circle (centre c, radius rr).

        public static GArray<double> _RingHits(Vector2 a, Vector2 b, Vector2 c, double rr)
        {
            GArray<double> @out = new GArray<double>();
            var d = b - a;
            var f = a - c;
            double qa = d.Dot(d);
            double qb = 2.0 * f.Dot(d);
            double disc = qb * qb - 4.0 * qa * (f.Dot(f) - rr * rr);
            if ((qa < 0.0001 || disc < 0.0))
            {
                return @out;
            }
            foreach (double t in Gd.Arr((-qb - Gd.Sqrt(disc)) / (2.0 * qa), (-qb + Gd.Sqrt(disc)) / (2.0 * qa)))
            {
                if (t >= 0.0 && t <= 1.0)
                {
                    @out.Append(t);
                }
            }
            return @out;
        }
        // Where the other tanks are posted (their goal, or where they stand without one).

        public GArray<Vector2> _Posts(long except)
        {
            GArray<Vector2> @out = new GArray<Vector2>();
            foreach (RampageSim.Tank other in sim.tanks)
            {
                if (other.id == except)
                {
                    continue;
                }
                ConvoyRoute o = convoy.routes.Get(other.id);
                @out.Append((o != null && o.goal.x != Gd.INF ? o.goal : other.pos));
            }
            return @out;
        }
        // Is `at` gap from every post, and (arc > 0) arc round the kaiju from each?

        public bool _Spaced(Vector2 at, GArray<Vector2> others, double arc, double gap)
        {
            var k = sim.kaijuPos;
            foreach (Vector2 p in others)
            {
                if ((p.DistanceTo(at) < gap || (arc > 0.0 && Gd.Absf((at - k).AngleTo(p - k)) < arc)))
                {
                    return false;
                }
            }
            return true;
        }
        // The kaiju's head: its snout, where the breath starts (BreathCone). kaiju_pos is the model's
        // origin (on the croc its tail root); danger is measured from the body between the two.

        public Vector2 Head()
        {
            Vector2 at = BreathCone.Of(sim)["origin"];
            return at;
        }
        // The ground the kaiju's body covers now and over the next `lookahead` seconds at the pace it
        // walks (Convoy.kaiju_vel): the line from its origin to its head, swept along its walk. A
        // striding kaiju's path ahead is danger already, so the tanks clear it in time.

        public PackedVector2Array Body()
        {
            if (!heldBody.IsEmpty())
            {
                return heldBody;
            }
            var h = Head();
            var ahead = convoy.kaijuVel * Num.F(cfg["lookahead"]);
            return new PackedVector2Array(Gd.Arr(sim.kaijuPos, h, h + ahead, sim.kaijuPos + ahead));
        }
        // The body's keep-away from its line (a tank's centre): the body's edge (body_radius) + edge_gap
        // + the hull's half diagonal, so edge_gap holds from the hull's nearest corner whichever way it
        // lies (LEAD r7: the ground gap the player sees). Convoy.danger is at least this.

        public double KeepAway()
        {
            GArray<Variant> hull = cfg["hull"];
            double corner = new Vector2(Num.F(hull[0]), Num.F(hull[1])).Length() * 0.5;
            double body = Num.F(sim.powersCfg["body_radius"]) * sim.BodyScale();
            return body + Num.F(cfg["edge_gap"]) + corner;
        }
        // Where a tank at p aims: the nearest point of the kaiju's body line, origin (tail root) to head,
        // with no walk ahead. Its range is measured to this point, as its post is (Convoy.reach), so a
        // tank posted by the head of a long body fires (measured to the tail root, it never did).
        // at_head: the kaiju's head this step (head()), read once per step by the caller.

        public Vector2 AimPoint(Vector2 p, Vector2 atHead)
        {
            return Geometry2D.GetClosestPointToSegment(p, sim.kaijuPos, atHead);
        }
        // How far p is from the kaiju's body (body(): 0 inside it).

        public double ToBody(Vector2 p)
        {
            var at = Body();
            if (at[0].DistanceTo(at[3]) > 0.001 && Geometry2D.IsPointInPolygon(p, at))
            {
                return 0.0;
            }
            double best = Gd.INF;
            foreach (long n in Gd.Range(4))
            {
                var q = Geometry2D.GetClosestPointToSegment(p, at[n], at[(n + 1) % 4]);
                best = Gd.Minf(best, q.DistanceTo(p));
            }
            return best;
        }
        // How near the road a-b comes to the kaiju's body (body()).

        public double NearBody(Vector2 a, Vector2 b)
        {
            var at = Body();
            if ((Geometry2D.IsPointInPolygon(a, at) || Geometry2D.IsPointInPolygon(b, at)))
            {
                return 0.0;
            }
            double best = Gd.INF;
            foreach (long n in Gd.Range(4))
            {
                best = Gd.Minf(best, RoadGraph._Near(a, b, at[n], at[(n + 1) % 4]));
            }
            return best;
        }
        // The roads within `near` of the kaiju's body (road -> true).

        public GDict RoadsByBody(double near)
        {
            var at = Body();
            double span = Gd.Maxf(at[0].DistanceTo(at[1]), at[0].DistanceTo(at[2]));
            GDict @out = new GDict();
            foreach (long e in graph.EdgesWithin(sim.kaijuPos, near + span))
            {
                if (NearBody(graph.nodes[graph.edgeA[e]], graph.nodes[graph.edgeB[e]]) < near)
                {
                    @out[e] = true;
                }
            }
            return @out;
        }
        // Does the route from `from` through `points` pass inside the danger radius of the body (any
        // nearer it than `from` itself, when it already stands inside)?

        public bool CrossesDanger(Vector2 from, GArray<Variant> points)
        {
            double inner = Gd.Minf(convoy.Danger(), ToBody(from) - 0.5);
            var a = from;
            foreach (Vector2 b in points)
            {
                if (NearBody(a, b) < inner)
                {
                    return true;
                }
                a = b;
            }
            return false;
        }
        // Back off along a road under the tank (at a crossing, whichever road and way leaves it
        // furthest from where the body will be after `lookahead` seconds, counting the time to swing
        // the hull), to `follow` beyond the danger radius or as far as it can drive in that time (no
        // further than that road's end): [path, legs], empty if it is already out or no way leaves it
        // clearer than holding.

        public GArray<Variant> FallBack(RampageSim.Tank tank, ConvoyRoute r)
        {
            double want = convoy.Danger() + Num.F(cfg["follow"]) - ToBody(tank.pos);
            if (want <= 0.0)
            {
                return Gd.Arr(Gd.Arr(), Gd.Arr());
            }
            double t = Num.F(cfg["lookahead"]);
            var ahead = convoy.kaijuVel * t;
            var tail = sim.kaijuPos + ahead;
            var snout = Head() + ahead;
            double fast = Num.F(cfg["retreat_speed"]);
            double turn = Gd.DegToRad(Num.F(cfg["hull_turn"]));
            double go = Gd.Maxf(want, fast * t);
            long under = graph.RoadUnder(tank.pos, r.edge);
            // Never a way that ends nearer the body than standing fast (a stub with the kaiju at its far
            // end, at the box's edge): hold rather than drive at it (LEAD r7).
            double best = Geometry2D.GetClosestPointToSegment(tank.pos, tail, snout).DistanceTo(tank.pos);
            GArray<Variant> @out = Gd.Arr(Gd.Arr(), Gd.Arr());
            foreach (long e in graph.RoadsAt(graph.CellOf(tank.pos)) + new PackedInt32Array(Gd.Arr(under)))
            {
                if (e != under && !graph.OnEdge(tank.pos, e))
                {
                    continue;
                }
                var na = graph.nodes[graph.edgeA[e]];
                var nb = graph.nodes[graph.edgeB[e]];
                foreach (Vector2 away in Gd.Arr(graph.Axis(e), -graph.Axis(e)))
                {
                    double end = Gd.Maxf((na - tank.pos).Dot(away), (nb - tank.pos).Dot(away));
                    if (end <= 0.5)
                    {
                        continue;
                    }
                    double swing = ((r.front != Vector2.ZERO ? Gd.Acos(Gd.Clampf(Gd.Absf(r.front.Dot(away)), 0.0, 1.0)) : 0.0));
                    double drive = Gd.Minf(end, fast * Gd.Maxf(0.0, t - swing / turn));
                    var then = tank.pos + away * drive;
                    double clear = Geometry2D.GetClosestPointToSegment(then, tail, snout).DistanceTo(then);
                    if (clear > best + 0.01)
                    {
                        best = clear;
                        @out = Gd.Arr(Gd.Arr(tank.pos + away * Gd.Minf(go, end)), Gd.Arr(e));
                    }
                }
            }
            return @out;
        }
        // Is the line from `from` to `to` (stopping short of the kaiju's body) clear of standing
        // buildings at least cover x the kaiju's height (a lower one it fires over)?

        public bool ClearLine(Vector2 from, Vector2 to)
        {
            double body = Num.F(sim.powersCfg["body_radius"]) * sim.BodyScale();
            double length = from.DistanceTo(to);
            if (length <= body)
            {
                return true;
            }
            var end = from.Lerp(to, (length - body) / length);
            double over = Num.F(cfg["cover"]) * sim.ReachHeight();
            GDict seen = new GDict();
            long steps = Gd.Ceili(from.DistanceTo(end) / (graph.cell * 0.5)) + 1;
            foreach (long s in Gd.Range(steps + 1))
            {
                foreach (long i in graph.LotsAt(graph.CellOf(from.Lerp(end, Gd.Float(s) / steps))))
                {
                    if (seen.Has(i))
                    {
                        continue;
                    }
                    seen[i] = true;
                    var b = sim.buildings[i];
                    if (Gd.Float(b.frame.aliveCount) / Gd.Float(b.w * b.d) < over)
                    {
                        continue;
                    }
                    if (_HitsRect(from, end, new Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)))
                    {
                        return false;
                    }
                }
            }
            return true;
        }

        public static bool _HitsRect(Vector2 a, Vector2 b, Rect2 rect)
        {
            if ((rect.HasPoint(a) || rect.HasPoint(b)))
            {
                return true;
            }
            GArray<Vector2> c = new GArray<Vector2> { rect.position, new Vector2(rect.end.x, rect.position.y), rect.end, new Vector2(rect.position.x, rect.end.y) };
            foreach (long n in Gd.Range(4))
            {
                if (!Gd.IsNull(Geometry2D.SegmentIntersectsSegment(a, b, c[n], c[(n + 1) % 4])))
                {
                    return true;
                }
            }
            return false;
        }

        void _InitFields()
        {
        }
    }
}
