// Generated from sim/city_alleys.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityAlleys : RefCounted
    {
        public static implicit operator CityAlleys(Variant v) => (CityAlleys)v.Obj;

        // Which grid edges of the street plan are alleys (part of CityGen.map, split out to keep files
        // small). An alley carries no asphalt: the pavements of the blocks either side meet across it.
        // So that every road meets other roads and pavements the way a real city's do (director
        // 2026-10-26: "we need a system to ensure that roads are intersecting with other roads and
        // pavements in a natural, realistic way"; his crop: the road off a river bridge running into a
        // paved block and stopping), an alley never lies where a road must run on:
        // - along the river's banks (CityRiver.river_row), so the far bank has one road the whole way and
        // every bridge lands on it (#12); nor across the river's row, where an alley would be a
        // footpath over open water with no deck, or the riverside park's (city audit D-265);
        // - round a landmark's site, whose plaza is inset for a street on every side (CitySites);
        // - where it would leave a road ending at a pavement (a dead end), or turning a corner whose
        // outside is a block's square pavement corner (an L): the alley that carries the road on is
        // laid as a street instead, until no such crossing is left.
        // Pure: lines, sites and config in; the rolls are drawn whatever the rules say, so the plan does
        // not shift when one changes.
        // {x: Dictionary, z: Dictionary}: x-line i between zs[j] and zs[j+1] is an alley when
        // x[Vector2i(i, j)]; z-line j between xs[i] and xs[i+1] when z[Vector2i(j, i)].

        public static GDict Lay(RandomNumberGenerator rng, GDict plan, GArray<Variant> avenues, GDict cfg)
        {
            GArray<double> xs = plan["xs"];
            GArray<double> zs = plan["zs"];
            GDict avX = avenues[0];
            GDict avZ = avenues[1];
            double full = CityGen.Districts(cfg)[-1];
            long bank = CityRiver.RiverRow(zs, cfg);
            GDict ax = new GDict();
            GDict az = new GDict();
            foreach (long i in Gd.Range(xs.Size()))
            {
                foreach (long j in Gd.Range(zs.Size() - 1))
                {
                    var keep = ((avX.Has(i) || (bank >= 0 && ((j == bank || j == bank + 1))) || _OnSite(plan, new Vector2(xs[i], zs[j]), new Vector2(xs[i], zs[j + 1])) || CityHarbour.TouchesAny(cfg, new Vector2(xs[i], zs[j]), new Vector2(xs[i], zs[j + 1]))));
                    // across the river (a road with a bridge deck, never a footpath on water) and the
                    // riverside park beyond it (a road there brings parked cars and street trees)
                    if (_Ok(rng.Randf(), Gd.Arr(xs[i], zs[j], zs[j + 1]), full, keep, cfg))
                    {
                        ax[new Vector2i(i, j)] = true;
                    }
                }
            }
            foreach (long j in Gd.Range(zs.Size()))
            {
                foreach (long i in Gd.Range(xs.Size() - 1))
                {
                    bool keep = ((avZ.Has(j) || (bank >= 0 && ((j == bank || j == bank + 1))) || _OnSite(plan, new Vector2(xs[i], zs[j]), new Vector2(xs[i + 1], zs[j])) || CityHarbour.TouchesAny(cfg, new Vector2(xs[i], zs[j]), new Vector2(xs[i + 1], zs[j]))));
                    if (_Ok(rng.Randf(), Gd.Arr(zs[j], xs[i], xs[i + 1]), full, keep, cfg))
                    {
                        az[new Vector2i(j, i)] = true;
                    }
                }
            }
            GDict @out = new GDict { { "x", ax }, { "z", az } };
            _Settle(plan, @out);
            return @out;
        }
        // An alley by its roll, inside the last district, off its ring lines, unless the line keeps
        // its road (`keep`). line: [the line, one end, the other end].

        public static bool _Ok(double roll, GArray<Variant> line, double full, bool keep, GDict cfg)
        {
            double at = Num.F(line[0]);
            double ends = Gd.Maxf(Gd.Absf(Num.F(line[1])), Gd.Absf(Num.F(line[2])));
            if ((keep || Gd.Absf(at) >= full - 0.01 || ends > full + 0.01))
            {
                return false;
            }
            return roll < Num.F(cfg["alley_chance"]);
        }
        // True when the edge from a to b runs along a landmark site's edge.

        public static bool _OnSite(GDict plan, Vector2 a, Vector2 b)
        {
            var mid = (a + b) * 0.5;
            foreach (GDict site in Gd.Iter(plan.Get("sites", Gd.Arr())))
            {
                Rect2 outer = site["outer"];
                if (outer.Grow(0.01).HasPoint(mid) && !(outer.Grow(-0.01).HasPoint(mid)))
                {
                    return true;
                }
            }
            return false;
        }
        // Lays as streets the alleys that would leave a road ending (one road at a crossing) or turning
        // an L (two at right angles): the one straight on from the road (for an L, the shorter of the two
        // straight on), else for a dead end one across it. Repeats until every crossing is settled.

        public static void _Settle(GDict plan, GDict alleys)
        {
            GArray<double> xs = plan["xs"];
            GArray<double> zs = plan["zs"];
            var changed = true;
            while (changed)
            {
                changed = false;
                foreach (long i in Gd.Range(xs.Size()))
                {
                    foreach (long j in Gd.Range(zs.Size()))
                    {
                        changed = (_SettleNode(plan, alleys, new Vector2i(i, j)) || changed);
                    }
                }
            }
        }

        public static bool _SettleNode(GDict plan, GDict alleys, Vector2i n)
        {
            var edges = _Edges(plan, alleys, n);
            GArray<long> road = new GArray<long>();
            foreach (long k in Gd.Range(4))
            {
                if (!(edges[k].IsEmpty()) && !_IsAlley(edges[k]))
                {
                    road.Append(k);
                }
            }
            if (road.Size() == 1)
            {
                // north <-> south, west <-> east
                long ahead = (road[0] ^ 1);
                if (_IsAlley(edges[ahead]))
                {
                    return _LayStreet(edges[ahead]);
                }
                return (_LayStreet(edges[(road[0] + 2) % 4]) || _LayStreet(edges[(road[0] + 3) % 4]));
            }
            // an L
            if (road.Size() == 2 && ((road[0] >> (int)(1))) != ((road[1] >> (int)(1))))
            {
                GArray<GDict> on = new GArray<GDict>();
                foreach (long k in Gd.Arr((road[0] ^ 1), (road[1] ^ 1)))
                {
                    if (_IsAlley(edges[k]))
                    {
                        on.Append(edges[k]);
                    }
                }
                on.SortCustom(new Callable(a_ =>
                {
                    GDict p = a_[0];
                    GDict q = a_[1];
                    return Num.F(p["length"]) < Num.F(q["length"]);
                }));
                return !on.IsEmpty() && _LayStreet(on[0]);
            }
            return false;
        }
        // The node's four edges, north, south, west, east: {alleys (that axis's dictionary), key,
        // length}, or {} where no edge is laid (the grid's border, or inside a landmark's site).

        public static GArray<GDict> _Edges(GDict plan, GDict alleys, Vector2i n)
        {
            GArray<double> xs = plan["xs"];
            GArray<double> zs = plan["zs"];
            GArray<GDict> @out = new GArray<GDict>();
            foreach (Vector2i d in Gd.Arr(new Vector2i(0, -1), new Vector2i(0, 1), new Vector2i(-1, 0), new Vector2i(1, 0)))
            {
                var m = n + d;
                if ((m.x < 0 || m.y < 0 || m.x >= xs.Size() || m.y >= zs.Size()))
                {
                    @out.Append(new GDict());
                    continue;
                }
                var a = new Vector2(xs[n.x], zs[n.y]);
                var b = new Vector2(xs[m.x], zs[m.y]);
                if (CitySites.Cuts(plan, a, b))
                {
                    @out.Append(new GDict());
                    continue;
                }
                // an x-line edge (running along z)
                var alongX = d.x == 0;
                var key = (alongX ? new Vector2i(n.x, Gd.Mini(n.y, m.y)) : new Vector2i(n.y, Gd.Mini(n.x, m.x)));
                @out.Append(new GDict { { "alleys", alleys[(alongX ? "x" : "z")] }, { "key", key }, { "length", a.DistanceTo(b) } });
            }
            return @out;
        }

        public static bool _IsAlley(GDict edge)
        {
            if (edge.IsEmpty())
            {
                return false;
            }
            GDict alleys = edge["alleys"];
            return alleys.Has(edge["key"]);
        }

        public static bool _LayStreet(GDict edge)
        {
            if (!_IsAlley(edge))
            {
                return false;
            }
            GDict alleys = edge["alleys"];
            alleys.Erase(edge["key"]);
            return true;
        }

        void _InitFields()
        {
        }
        public CityAlleys() { _InitFields(); }
    }
}
