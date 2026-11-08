// Generated from sim/road_graph.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RoadGraph : RoadNet
    {
        public static implicit operator RoadGraph(Variant v) => (RoadGraph)v.Obj;

        // The roads tanks use (D-066), from the street plan (CityGen.map): avenues, streets and the
        // diagonal, never an alley, clipped to the box round the playable city plus the entry depth.
        // Also the grids that keep a hull on the carriageway and off every lot, the start of a route
        // and the waypoints along one (right-hand lane on a two-lane road), and the roads a toppled
        // tower closes. Part of Convoy; numbers are army.convoy in data/tuning.json.
        // Room for the whole hull at p, its front along `front`: the centre no further off a road's
        // centre line than the road's half width plus the sidewalk less half the hull's width, every
        // corner over a road or its sidewalk, and the hull (corners and all) clear of every building lot
        // (where a street runs out into an alley between buildings).

        public bool Drivable(Vector2 p, Vector2 front)
        {
            GArray<Variant> hull = cfg["hull"];
            var half = new Vector2(Num.F(hull[0]), Num.F(hull[1])) * 0.5;
            double walk = Num.F(sim.city["sidewalk"]);
            if (!_OverRoad(p, walk - half.y - 0.1))
            {
                return false;
            }
            var side = front.Orthogonal();
            foreach (double sx in Gd.Arr(-1.0, 1.0))
            {
                foreach (double sy in Gd.Arr(-1.0, 1.0))
                {
                    if (!_OverRoad(p + front * half.x * sx + side * half.y * sy, walk))
                    {
                        return false;
                    }
                }
            }
            half += new Vector2(0.05, 0.05);
            var ext = new Vector2(Gd.Absf(front.x) * half.x + Gd.Absf(side.x) * half.y, Gd.Absf(front.y) * half.x + Gd.Absf(side.y) * half.y);
            var key = CellOf(p);
            foreach (long dx in Gd.Arr(-1, 0, 1))
            {
                foreach (long dz in Gd.Arr(-1, 0, 1))
                {
                    foreach (long i in LotsAt(key + new Vector2i(dx, dz)))
                    {
                        var b = sim.buildings[i];
                        var d = new Vector2(b.x, b.z) - p;
                        var hb = new Vector2(b.w, b.d) * 0.5;
                        if ((Gd.Absf(d.x) >= ext.x + hb.x || Gd.Absf(d.y) >= ext.y + hb.y))
                        {
                            continue;
                        }
                        double rf = hb.x * Gd.Absf(front.x) + hb.y * Gd.Absf(front.y);
                        double rs = hb.x * Gd.Absf(side.x) + hb.y * Gd.Absf(side.y);
                        if (Gd.Absf(d.Dot(front)) < half.x + rf && Gd.Absf(d.Dot(side)) < half.y + rs)
                        {
                            return false;
                        }
                    }
                }
            }
            return true;
        }
        // The way in for a column on `bearing`: the road entry at the city's edge on that side, or, in
        // a city grown past the spawn radius, the road crossing nearest spawn_radius from the kaiju
        // (D-039); never a stub too short for a hull, nor one within `keep_out` of the kaiju (a bearing
        // out over the sea bay would otherwise pick the coast road beside it).

        public long PickEntry(double bearing, Vector2 kaiju, double spawnRadius, double keepOut = 0.0)
        {
            var dir = Vector2.FromAngle(bearing);
            var edge = box <= spawnRadius;
            var aim = (edge ? dir * box * 2.0 : kaiju + dir * spawnRadius);
            GArray<long> pool = new GArray<long>();
            pool.Assign((edge ? entries : new PackedInt32Array(Gd.Range(nodes.Size()))));
            long best = -1;
            double bestD = Gd.INF;
            foreach (long n in pool)
            {
                double d = nodes[n].DistanceSquaredTo(aim);
                if ((d >= bestD || nodes[n].DistanceTo(kaiju) < keepOut))
                {
                    continue;
                }
                if (!(links[n].IsEmpty()) && Fits(n))
                {
                    bestD = d;
                    best = n;
                }
            }
            return best;
        }
        // Does a hull fit at node n facing into its first road (no tank enters on a short stub)?

        public bool Fits(long n)
        {
            long e = links[n][0];
            long far = (edgeA[e] == n ? edgeB[e] : edgeA[e]);
            return Drivable(nodes[n], (nodes[far] - nodes[n]).Normalized());
        }

        public bool _OverRoad(Vector2 p, double spare)
        {
            foreach (long e in RoadsAt(CellOf(p)))
            {
                if (OffLine(p, e) <= edgeHalf[e] + spare)
                {
                    return true;
                }
            }
            return false;
        }
        // The road nearest p (the one it is on when `edge` still holds it).

        public long RoadUnder(Vector2 p, long edge)
        {
            if (edge >= 0 && OnEdge(p, edge))
            {
                return edge;
            }
            GArray<long> near = new GArray<long>();
            foreach (long dx in Gd.Arr(-1, 0, 1))
            {
                foreach (long dz in Gd.Arr(-1, 0, 1))
                {
                    foreach (long k in RoadsAt(CellOf(p) + new Vector2i(dx, dz)))
                    {
                        near.Append(k);
                    }
                }
            }
            // far off the plan: every road
            if (near.IsEmpty())
            {
                near.Assign(Gd.Range(edgeA.Size()));
            }
            long best = -1;
            double bestD = Gd.INF;
            foreach (long k in near)
            {
                double d = OffLine(p, k);
                if (d < bestD)
                {
                    bestD = d;
                    best = k;
                }
            }
            return best;
        }
        // The waypoints from `from` along `chain` (roads, from start node n) to `at` on road `last`:
        // [path, legs]. On a road wide enough for two lanes it keeps right of the centre line (each
        // waypoint moves right of the way it arrives), so columns going opposite ways pass each other.

        public GArray<Variant> Waypoints(Vector2 from, GDict start, GArray<long> chain, GDict goal)
        {
            GArray<Variant> raw = _RawPath(from, start, chain, goal);
            GArray<Vector2> path = raw[0];
            GArray<long> legs = raw[1];
            var last = from;
            double sharp = Gd.Cos(Gd.DegToRad(Num.F(cfg["pivot_deg"])));
            double lead = Num.F(cfg["follow"]);
            GArray<Vector2> @out = new GArray<Vector2>();
            GArray<long> outLegs = new GArray<long>();
            foreach (long i in Gd.Range(path.Size()))
            {
                var centre = path[i];
                long e = legs[i];
                var d = (centre - last).Normalized();
                double span = centre.DistanceTo(last);
                if (i + 1 < path.Size() && d.Dot((path[i + 1] - centre).Normalized()) < sharp)
                {
                    // a sharp turn ahead: ease to the crown, turn standing there
                    if (span > lead * 1.5)
                    {
                        @out.Append(centre - d * lead);
                        outLegs.Append(e);
                    }
                    @out.Append(centre);
                }
                else if (e >= 0 && edgeLane[e] > 0.0 && span > 0.01)
                {
                    @out.Append(centre + new Vector2(-d.y, d.x) * edgeLane[e]);
                }
                else
                {
                    @out.Append(centre);
                }
                outLegs.Append(e);
                last = centre;
            }
            _SquareLegs(from, Num.I(start["edge"]), @out, outLegs);
            return Gd.Arr(@out, outLegs);
        }
        // The crowns along `chain` (roads, from start node n) to the goal on its road, and the road each
        // runs on, less any already within reach of `from`: [path, legs].

        public GArray<Variant> _RawPath(Vector2 from, GDict start, GArray<long> chain, GDict goal)
        {
            GArray<Vector2> path = new GArray<Vector2>();
            GArray<long> legs = new GArray<long>();
            long n = Num.I(start["node"]);
            if (n >= 0)
            {
                path.Append(nodes[n]);
                legs.Append(Num.I(start["edge"]));
                foreach (long e in chain)
                {
                    n = (edgeA[e] == n ? edgeB[e] : edgeA[e]);
                    path.Append(nodes[n]);
                    legs.Append(e);
                }
            }
            path.Append(goal["at"]);
            legs.Append(Num.I(goal["edge"]));
            // already there
            while (!path.IsEmpty() && path[0].DistanceTo(from) < 0.05)
            {
                path.RemoveAt(0);
                legs.RemoveAt(0);
            }
            return Gd.Arr(path, legs);
        }
        // Draws each waypoint in so the leg to it runs within skew_deg of its road's axis: a tank set off
        // from a post near the kerb drifts back across the road as it drives, never crabbing down a
        // diagonal. A leg that cannot (it would cut a corner) turns the corner square instead: along the
        // road the tank is on to the crossing, a pivot there, then along the next road.

        public void _SquareLegs(Vector2 from, long on, GArray<Vector2> @out, GArray<long> outLegs)
        {
            double slope = Gd.Tan(Gd.DegToRad(Num.F(cfg["skew_deg"])));
            var cur = from;
            long was = on;
            long i = 0;
            while (i < @out.Size())
            {
                long e = outLegs[i];
                if (e >= 0)
                {
                    var a = Axis(e);
                    var v = @out[i] - cur;
                    double cap = Gd.Absf(v.Dot(a)) * slope;
                    var to = cur + a * v.Dot(a) + a.Orthogonal() * Gd.Clampf(v.Dot(a.Orthogonal()), -cap, cap);
                    if (OffLine(to, e) <= _Room(e))
                    {
                        @out[i] = to;
                    }
                    else if (was >= 0 && Gd.Absf(Axis(was).Cross(a)) > 0.5)
                    {
                        var corner = (cur + Axis(was) * (nodes[edgeA[e]] - cur).Cross(a) / Axis(was).Cross(a));
                        if (OffLine(corner, was) <= _Room(was) && OffLine(corner, e) <= _Room(e))
                        {
                            @out.Insert(i, corner);
                            outLegs.Insert(i, was);
                            e = was;
                        }
                    }
                    was = e;
                }
                cur = @out[i];
                i += 1;
            }
        }
        // The point `to` drawn in so the leg from `from` runs within skew_deg of road e's axis (as
        // _square_legs), or `to` itself when that would leave the road.

        public Vector2 SquareLeg(Vector2 from, Vector2 to, long e)
        {
            if (e < 0)
            {
                return to;
            }
            var a = Axis(e);
            var v = to - from;
            double cap = Gd.Absf(v.Dot(a)) * Gd.Tan(Gd.DegToRad(Num.F(cfg["skew_deg"])));
            double side = v.Dot(a.Orthogonal());
            if (Gd.Absf(side) <= cap)
            {
                return to;
            }
            var drawn = from + a * v.Dot(a) + a.Orthogonal() * Gd.Clampf(side, -cap, cap);
            return (OffLine(drawn, e) <= _Room(e) ? drawn : to);
        }
        // Does a hull pointing along `front` lie along road e (within skew_deg)? Any way off a road.

        public bool Square(Vector2 front, long e)
        {
            double tilt = (e >= 0 ? Gd.Absf(front.Cross(Axis(e))) : 0.0);
            return tilt <= Gd.Sin(Gd.DegToRad(Num.F(cfg["skew_deg"])));
        }
        // How far off road e's centre line a hull's centre may stand.

        public double _Room(long e)
        {
            GArray<Variant> hull = cfg["hull"];
            return edgeHalf[e] + Num.F(sim.city["sidewalk"]) - Num.F(hull[1]) * 0.5 - 0.1;
        }
        // Closes the roads under every tower that toppled this step (fall_land topple events). True
        // when one closed.

        public bool ReadRubble(GArray<GDict> events)
        {
            var closed = false;
            foreach (GDict @event in events)
            {
                if ((Gd.Str(@event["type"]) != "fall_land" || Gd.Str(@event.Get("kind", "")) != "topple"))
                {
                    continue;
                }
                // a carved scrap blocks no road
                if (@event.Get("scrap", false) == true)
                {
                    continue;
                }
                Vector2 from = @event["from"];
                Vector2 to = @event["to"];
                closed = (CloseStrip(from, to, Num.F(@event["width"])) || closed);
            }
            return closed;
        }
        // Closes every open road within reach of a fallen strip (from -> to, `width` across) plus half
        // a hull. True when one closed.

        public bool CloseStrip(Vector2 from, Vector2 to, double width)
        {
            GArray<Variant> hull = cfg["hull"];
            double within = width * 0.5 + Num.F(hull[1]) * 0.5;
            var closed = false;
            foreach (long e in Gd.Range(edgeA.Size()))
            {
                if (blocked[e] == 0 && _Near(nodes[edgeA[e]], nodes[edgeB[e]], from, to) < within)
                {
                    blocked[e] = 1;
                    closed = true;
                }
            }
            return closed;
        }

        public static double _Near(Vector2 a, Vector2 b, Vector2 c, Vector2 d)
        {
            if (!Gd.IsNull(Geometry2D.SegmentIntersectsSegment(a, b, c, d)))
            {
                return 0.0;
            }
            double best = Gd.Minf(Geometry2D.GetClosestPointToSegment(a, c, d).DistanceTo(a), Geometry2D.GetClosestPointToSegment(b, c, d).DistanceTo(b));
            best = Gd.Minf(best, Geometry2D.GetClosestPointToSegment(c, a, b).DistanceTo(c));
            return Gd.Minf(best, Geometry2D.GetClosestPointToSegment(d, a, b).DistanceTo(d));
        }

        new void _InitFields()
        {
        }
        public RoadGraph(RampageSim pSim, GDict pCfg) : base(pSim, pCfg) { _InitFields(); }
    }
}
