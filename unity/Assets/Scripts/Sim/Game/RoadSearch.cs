// Generated from sim/road_search.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RoadSearch : RefCounted
    {
        public static implicit operator RoadSearch(Variant v) => (RoadSearch)v.Obj;

        // Cheapest routes over the RoadGraph (D-066), Dijkstra from a tank's start nodes. A road by
        // the kaiju's feet costs heavily (tanks drive round the kaiju, not past it), so does one where
        // a tank holds its post (others go round rather than queue behind) and a one-lane street a
        // column is coming down (no head-on meetings). Closed roads and the ones a stuck tank backs
        // away from are out. The search stays inside `disc` round the kaiju, where every post is.
        public RoadGraph graph;
        public GDict cfg = new GDict();
        // Set by Convoy each step: road -> true by the kaiju, road -> true held, road -> direction driven.
        public GDict nearKaiju = new GDict();
        public GDict held = new GDict();
        public GDict driven = new GDict();

        public RoadSearch(RoadGraph pGraph, GDict pCfg)
        {
            _InitFields();
            graph = pGraph;
            cfg = pCfg;
        }
        // {cost: per node, prev: the road it was reached by} from start {node: cost}, leaving out the
        // roads in `skip`, never further than disc from centre.

        public GDict Search(GDict start, GDict skip, Vector2 centre, double disc)
        {
            long count = graph.nodes.Size();
            var cost = new PackedFloat32Array();
            cost.Resize(count);
            cost.Fill(Gd.INF);
            var prev = new PackedInt32Array();
            prev.Resize(count);
            prev.Fill(-1);
            // (cost, node)
            GArray<Vector2> heap = new GArray<Vector2>();
            foreach (long n in start.Keys())
            {
                cost[n] = Num.F(start[n]);
                _Push(heap, new Vector2(cost[n], n));
            }
            while (!heap.IsEmpty())
            {
                var top = _Pop(heap);
                long n = Gd.Int(top.y);
                if (top.x > cost[n])
                {
                    continue;
                }
                foreach (long e in graph.links[n])
                {
                    if ((graph.blocked[e] != 0 || skip.Has(e)))
                    {
                        continue;
                    }
                    long to = (graph.edgeA[e] == n ? graph.edgeB[e] : graph.edgeA[e]);
                    if (graph.nodes[to].DistanceSquaredTo(centre) > disc * disc)
                    {
                        continue;
                    }
                    double c = _Surcharged(top.x + graph.edgeCost[e], e, n, to);
                    if (c < cost[to])
                    {
                        cost[to] = c;
                        prev[to] = e;
                        _Push(heap, new Vector2(c, to));
                    }
                }
            }
            return new GDict { { "cost", cost }, { "prev", prev } };
        }
        // `c`, the cost of taking road e from node n to node `to`, plus its penalties: the kaiju is
        // by it, a tank holds its post on it, or a column is coming the other way down its one lane.

        public double _Surcharged(double c, long e, long n, long to)
        {
            if (nearKaiju.Has(e))
            {
                c += Num.F(cfg["danger_cost"]);
            }
            if (held.Has(e))
            {
                c += Num.F(cfg["held_cost"]);
            }
            if (graph.edgeLane[e] == 0.0 && driven.Has(e))
            {
                Vector2 way = driven[e];
                if (way.Dot(graph.nodes[to] - graph.nodes[n]) < 0.0)
                {
                    c += Num.F(cfg["oncoming_cost"]);
                }
            }
            return c;
        }
        // The roads from a start node to `head` (in driving order) and that start node: [chain, node].

        public GArray<Variant> ChainTo(GDict found, long head)
        {
            PackedInt32Array prev = found["prev"];
            GArray<long> chain = new GArray<long>();
            long n = head;
            while (prev[n] >= 0)
            {
                long e = prev[n];
                chain.PushFront(e);
                n = (graph.edgeB[e] == n ? graph.edgeA[e] : graph.edgeB[e]);
            }
            return Gd.Arr(chain, n);
        }

        public static void _Push(GArray<Vector2> heap, Vector2 v)
        {
            heap.Append(v);
            long i = heap.Size() - 1;
            while (i > 0)
            {
                long up = (i - 1) / 2;
                if (heap[up].x <= heap[i].x)
                {
                    break;
                }
                var tmp = heap[up];
                heap[up] = heap[i];
                heap[i] = tmp;
                i = up;
            }
        }

        public static Vector2 _Pop(GArray<Vector2> heap)
        {
            var top = heap[0];
            Vector2 last = heap.PopBack();
            if (heap.IsEmpty())
            {
                return top;
            }
            heap[0] = last;
            long i = 0;
            while (true)
            {
                long l = i * 2 + 1;
                long m = i;
                if (l < heap.Size() && heap[l].x < heap[m].x)
                {
                    m = l;
                }
                if (l + 1 < heap.Size() && heap[l + 1].x < heap[m].x)
                {
                    m = l + 1;
                }
                if (m == i)
                {
                    break;
                }
                var tmp = heap[m];
                heap[m] = heap[i];
                heap[i] = tmp;
                i = m;
            }
            return top;
        }
        // Where a tank at `p` sets off from: {edge (the road under it), via (its point on that road's
        // line), from: {node: cost}}, both ends of that road, or only the end behind it when it was held
        // up on this road going the other way.

        public GDict Origin(Vector2 p, ConvoyRoute r)
        {
            long e = graph.RoadUnder(p, r.edge);
            var na = graph.nodes[graph.edgeA[e]];
            var nb = graph.nodes[graph.edgeB[e]];
            var via = Geometry2D.GetClosestPointToSegment(p, na, nb);
            double off = via.DistanceTo(p);
            GDict from = new GDict { { graph.edgeA[e], off + via.DistanceTo(na) }, { graph.edgeB[e], off + via.DistanceTo(nb) } };
            // only the end behind it
            if (r.skip.Has(e) && !r.path.IsEmpty())
            {
                var aheadB = nb.DistanceTo(r.path[0]) < na.DistanceTo(r.path[0]);
                from.Erase((aheadB ? graph.edgeB[e] : graph.edgeA[e]));
            }
            else if (!r.path.IsEmpty() && r.heading != Vector2.ZERO)
            {
                // turning back costs more
                var behindB = (nb - p).Dot(r.heading) < 0.0;
                long back = (behindB ? graph.edgeB[e] : graph.edgeA[e]);
                from[back] = Num.F(from[back]) + Num.F(cfg["uturn_cost"]);
            }
            return new GDict { { "edge", e }, { "via", via }, { "from", from } };
        }

        void _InitFields()
        {
        }
    }
}
