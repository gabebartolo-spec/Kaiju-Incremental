// Generated from sim/road_net.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RoadNet : RefCounted
    {
        public static implicit operator RoadNet(Variant v) => (RoadNet)v.Obj;

        // The road graph's data and lookups (split out of RoadGraph to keep files small): the nodes and
        // roads cut from the street plan (CityGen.map), clipped to the box round the playable city plus
        // the entry depth, the grids that file roads and building lots by cell, and the distance to a
        // road. RoadGraph adds what tanks ask of it: room for a hull, routes, the roads a tower closes.
        // Numbers are army.convoy in data/tuning.json.
        public RampageSim sim;
        public GDict cfg = new GDict();
        public GArray<Vector2> nodes = new GArray<Vector2>();
        // Roads: their two nodes, length, route cost, lane offset and half width; each node's roads.
        public PackedInt32Array edgeA = new PackedInt32Array();
        public PackedInt32Array edgeB = new PackedInt32Array();
        public PackedFloat32Array edgeLen = new PackedFloat32Array();
        public PackedFloat32Array edgeCost = new PackedFloat32Array();
        // how far right of the centre line tanks drive
        public PackedFloat32Array edgeLane = new PackedFloat32Array();
        public PackedFloat32Array edgeHalf = new PackedFloat32Array();
        // closed by a toppled tower
        public PackedByteArray blocked = new PackedByteArray();
        public GArray<PackedInt32Array> links = new GArray<PackedInt32Array>();
        // Nodes on the edge of the box (where a road leaves it): where columns enter.
        public PackedInt32Array entries = new PackedInt32Array();
        public double box;
        public double cell;
        // Vector2i cell -> PackedInt32Array of roads through it
        public GDict _roads = new GDict();
        // Vector2i cell -> PackedInt32Array of building indices
        public GDict _lots = new GDict();

        public RoadNet(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            box = sim.arenaHalf + Num.F(cfg["entry_depth"]);
            cell = Num.F(cfg["grid"]);
            _Build(CityGen.Map(sim.city));
            _Index();
        }

        public void _Build(GDict plan)
        {
            // rounded position -> node
            GDict at = new GDict();
            GArray<Variant> planNodes = plan["nodes"];
            foreach (GDict street in Gd.Iter(plan["streets"]))
            {
                var kind = Gd.Str(street["kind"]);
                if (kind == CityGen.ALLEY)
                {
                    continue;
                }
                Vector2 from = planNodes[Num.I(street["from"])];
                Vector2 to = planNodes[Num.I(street["to"])];
                var clip = _Clip(from, to);
                if (clip.IsEmpty())
                {
                    continue;
                }
                long na = _Node(at, clip[0]);
                long nb = _Node(at, clip[1]);
                if (na == nb)
                {
                    continue;
                }
                double length = nodes[na].DistanceTo(nodes[nb]);
                double width = Num.F(street["width"]);
                edgeA.Append(na);
                edgeB.Append(nb);
                edgeLen.Append(length);
                edgeCost.Append(length * ((kind == CityGen.STREET ? Num.F(cfg["street_cost"]) : 1.0)));
                edgeLane.Append((width >= Num.F(cfg["two_lanes"]) ? width * 0.25 : 0.0));
                edgeHalf.Append(width * 0.5);
                blocked.Append(0);
                links[na].Append(edgeA.Size() - 1);
                links[nb].Append(edgeA.Size() - 1);
            }
            foreach (long n in Gd.Range(nodes.Size()))
            {
                var p = nodes[n];
                if (Gd.Maxf(Gd.Absf(p.x), Gd.Absf(p.y)) >= box - 0.01 && links[n].Size() == 1)
                {
                    entries.Append(n);
                }
            }
        }

        public long _Node(GDict at, Vector2 p)
        {
            var key = new Vector2i(Gd.Roundi(p.x * 100.0), Gd.Roundi(p.y * 100.0));
            if (!at.Has(key))
            {
                at[key] = nodes.Size();
                nodes.Append(p);
                links.Append(new PackedInt32Array());
            }
            return Num.I(at[key]);
        }
        // The part of segment a-b inside the box, or [] (Liang-Barsky).

        public GArray<Vector2> _Clip(Vector2 a, Vector2 b)
        {
            double t0 = 0.0;
            double t1 = 1.0;
            var d = b - a;
            foreach (long axis in Gd.Range(2))
            {
                foreach (double side in Gd.Arr(-1.0, 1.0))
                {
                    // distance to the wall along this side
                    double q = box - side * a[axis];
                    double pv = side * d[axis];
                    if (Gd.Absf(pv) < 0.000001)
                    {
                        if (q < 0.0)
                        {
                            return new GArray<Vector2>();
                        }
                        continue;
                    }
                    if (pv > 0.0)
                    {
                        t1 = Gd.Minf(t1, q / pv);
                    }
                    else
                    {
                        t0 = Gd.Maxf(t0, q / pv);
                    }
                }
            }
            if (t0 >= t1)
            {
                return new GArray<Vector2>();
            }
            return new GArray<Vector2> { a + d * t0, a + d * t1 };
        }
        // Roads and building lots by grid cell.

        public void _Index()
        {
            foreach (long e in Gd.Range(edgeA.Size()))
            {
                var a = nodes[edgeA[e]];
                var b = nodes[edgeB[e]];
                _File(_roads, new Rect2(a.Min(b), a.Max(b) - a.Min(b)).Grow(cell), e);
            }
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                var b = sim.buildings[i];
                // traffic runs on under the viaduct and over a bridge
                if (b.IsSpan())
                {
                    continue;
                }
                var half = new Vector2(b.w, b.d) * 0.5;
                _File(_lots, new Rect2(new Vector2(b.x, b.z) - half, half * 2.0), i);
            }
        }

        public void _File(GDict grid, Rect2 area, long item)
        {
            var from = CellOf(area.position);
            var to = CellOf(area.end);
            foreach (long cx in Gd.Range(from.x, to.x + 1))
            {
                foreach (long cz in Gd.Range(from.y, to.y + 1))
                {
                    var key = new Vector2i(cx, cz);
                    PackedInt32Array list = grid.Get(key, new PackedInt32Array());
                    list.Append(item);
                    grid[key] = list;
                }
            }
        }

        public Vector2i CellOf(Vector2 p)
        {
            return new Vector2i(Gd.Floori(p.x / cell), Gd.Floori(p.y / cell));
        }

        public PackedInt32Array RoadsAt(Vector2i key)
        {
            return _roads.Get(key, new PackedInt32Array());
        }

        public PackedInt32Array LotsAt(Vector2i key)
        {
            return _lots.Get(key, new PackedInt32Array());
        }
        // The roads with any part within `radius` of `at` (by grid cell, a superset).

        public GDict EdgesWithin(Vector2 at, double radius)
        {
            GDict @out = new GDict();
            var lo = CellOf(at - new Vector2(radius, radius));
            var hi = CellOf(at + new Vector2(radius, radius));
            foreach (long cx in Gd.Range(lo.x, hi.x + 1))
            {
                foreach (long cz in Gd.Range(lo.y, hi.y + 1))
                {
                    foreach (long e in RoadsAt(new Vector2i(cx, cz)))
                    {
                        @out[e] = true;
                    }
                }
            }
            return @out;
        }

        public double OffLine(Vector2 p, long e)
        {
            return (Geometry2D.GetClosestPointToSegment(p, nodes[edgeA[e]], nodes[edgeB[e]]).DistanceTo(p));
        }
        // Is p on road e's carriageway?

        public bool OnEdge(Vector2 p, long e)
        {
            return OffLine(p, e) <= edgeHalf[e];
        }
        // Road e's direction (a to b).

        public Vector2 Axis(long e)
        {
            return (nodes[edgeB[e]] - nodes[edgeA[e]]).Normalized();
        }

        void _InitFields()
        {
        }
    }
}
