// Generated from sim/city_parks.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityParks : RefCounted
    {
        public static implicit operator CityParks(Variant v) => (CityParks)v.Obj;

        // The parks and the plaza of the street plan (part of CityGen.map, split out to keep files
        // small). Each district gets a park for every city "park_every" m2 of its ground (at least one;
        // D-065, D-075: a believable amount of green, so a district 1.5x wider keeps its share, D-254):
        // its biggest blocks between the towers and its ring, quiet ones first (town share under
        // "park_town"), each at least "park_gap" m from the district's other parks. One plaza: the
        // block at the heart of the first tower district. Pure: the plan's blocks in, uses set.
        // inner: CityGen.map's indices of every block inside the last district.

        public static void Pick(GDict plan, GArray<long> inner, GDict cfg)
        {
            GArray<GDict> blocks = plan["blocks"];
            var rings = CityGen.Districts(cfg);
            GArray<Variant> byRing = _ByRing(blocks, inner, rings, cfg);
            // before any block turns to park
            long plaza = _Plaza(blocks, inner, cfg);
            GArray<long> parks = new GArray<long>();
            foreach (long k in Gd.Range(rings.Size()))
            {
                double inside = (k > 0 ? rings[k - 1] : 0.0);
                double ground = 4.0 * (rings[k] * rings[k] - inside * inside);
                long want = Gd.Maxi(1, Gd.Roundi(ground / Num.F(cfg["park_every"])));
                GArray<Variant> list = byRing[k];
                parks.AppendArray(_PickRing(blocks, list, want, cfg));
            }
            foreach (long n in parks)
            {
                blocks[n]["use"] = "park";
            }
            if (plaza >= 0 && !Gd.In(plaza, parks) && Num.F(cfg["plaza_blocks"]) > 0.0)
            {
                blocks[plaza]["use"] = "plaza";
            }
        }
        // The built blocks a district may turn to park, per district: the first district's away from
        // its edge (its ring stays built), every later one's whole (a later district is one ring of
        // blocks deep).

        public static GArray<Variant> _ByRing(GArray<GDict> blocks, GArray<long> inner, GArray<double> rings, GDict cfg)
        {
            GArray<Variant> byRing = Gd.Arr();
            foreach (long k in Gd.Range(rings.Size()))
            {
                byRing.Append(Gd.Arr());
            }
            foreach (long n in inner)
            {
                Rect2 rect = blocks[n]["rect"];
                if ((Gd.Str(blocks[n]["use"]) != "built" || CityHarbour.InAny(cfg, rect)))
                {
                    // the river (CityRiver), any stage's sea bay (CityHarbour)
                    continue;
                }
                long ring = Num.I(blocks[n]["district"]);
                double edge = Gd.Maxf(Gd.Absf(rect.GetCenter().x), Gd.Absf(rect.GetCenter().y)) / rings[ring];
                if ((edge < 0.75 || ring > 0))
                {
                    GArray<Variant> list = byRing[ring];
                    list.Append(n);
                }
            }
            return byRing;
        }
        // Up to `want` of a district's candidate blocks: quiet ones first, then the biggest, each
        // park_gap m from the ones already picked.

        public static GArray<long> _PickRing(GArray<GDict> blocks, GArray<Variant> list, long want, GDict cfg)
        {
            double quiet = Num.F(cfg["park_town"]);
            list.SortCustom(new Callable(a_ =>
            {
                long a = a_[0];
                long b = a_[1];
                var qa = _Town(blocks[a], cfg) < quiet;
                var qb = _Town(blocks[b], cfg) < quiet;
                if (qa != qb)
                {
                    return qa;
                }
                Rect2 ra = blocks[a]["rect"];
                Rect2 rb = blocks[b]["rect"];
                if (ra.GetArea() != rb.GetArea())
                {
                    return ra.GetArea() > rb.GetArea();
                }
                // a tie: the first block in the plan, so the sort is the same every run
                return a < b;
            }));
            GArray<Vector2> mine = new GArray<Vector2>();
            GArray<long> @out = new GArray<long>();
            foreach (long n in list)
            {
                if (@out.Size() >= want)
                {
                    break;
                }
                Rect2 rect = blocks[n]["rect"];
                var spaced = true;
                foreach (Vector2 at in mine)
                {
                    spaced = spaced && at.DistanceTo(rect.GetCenter()) >= Num.F(cfg["park_gap"]);
                }
                if (spaced)
                {
                    mine.Append(rect.GetCenter());
                    @out.Append(n);
                }
            }
            return @out;
        }
        // The built block nearest the heart of the first tower district (-1 when none).

        public static long _Plaza(GArray<GDict> blocks, GArray<long> inner, GDict cfg)
        {
            var heart = CityGen.Cores(cfg)[0];
            long best = -1;
            double away = Gd.INF;
            foreach (long n in inner)
            {
                Rect2 rect = blocks[n]["rect"];
                if ((Gd.Str(blocks[n]["use"]) != "built" || CityHarbour.InAny(cfg, rect)))
                {
                    continue;
                }
                double d = rect.GetCenter().DistanceTo(new Vector2(heart.x, heart.y));
                if (d < away)
                {
                    best = n;
                    away = d;
                }
            }
            return best;
        }

        public static double _Town(GDict block, GDict cfg)
        {
            Rect2 rect = block["rect"];
            return CityLots.TownShare(rect.GetCenter(), cfg);
        }

        void _InitFields()
        {
        }
        public CityParks() { _InitFields(); }
    }
}
