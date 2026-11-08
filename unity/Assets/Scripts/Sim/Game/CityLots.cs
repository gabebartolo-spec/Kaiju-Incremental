// Generated from sim/city_lots.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityLots : RefCounted
    {
        public static implicit operator CityLots(Variant v) => (CityLots)v.Obj;

        // Fills a block of the street plan (CityGen.map) with buildings, New York and Tokyo style: lots
        // line each block face and share party walls (terraces, street walls), with a courtyard in a
        // deep block; two tower districts (a midtown and a downtown) thin out to low-rise with front
        // yards, where now and then a narrow pencil building shoots up. Lots the diagonal avenue cuts
        // through are left as little plazas. Part of CityGen; split out to keep files small.
        // The buildings of one block. height_scale shrinks them (the outskirts use it).

        public static GArray<GDict> FillBlock(RandomNumberGenerator rng, GDict plan, GDict block, GDict cfg, double heightScale)
        {
            Rect2 rect = block["rect"];
            long x0 = Gd.Ceili(rect.position.x);
            long z0 = Gd.Ceili(rect.position.y);
            long w = Gd.Floori(rect.end.x) - x0;
            long d = Gd.Floori(rect.end.y) - z0;
            if ((w < 2 || d < 2))
            {
                return new GArray<GDict>();
            }
            double downtown = TownShare(rect.GetCenter(), cfg);
            long grow = LotGrow(block, cfg);
            long depth = rng.RandiRange(Num.I(cfg["depth_min"]), Num.I(cfg["depth_max"])) + grow;
            if (downtown > 0.6)
            {
                depth += 1;
            }
            // each: rect (Rect2i), along_x, street side (-1/+1)
            GArray<GDict> rows = new GArray<GDict>();
            // a perimeter of lots round a courtyard
            if (w >= 2 * depth + 2 && d >= 2 * depth + 2)
            {
                rows.Append(new GDict { { "r", new Rect2i(x0, z0, w, depth) }, { "along_x", true }, { "front", -1 } });
                rows.Append(new GDict { { "r", new Rect2i(x0, z0 + d - depth, w, depth) }, { "along_x", true }, { "front", 1 } });
                rows.Append(new GDict { { "r", new Rect2i(x0, z0 + depth, depth, d - 2 * depth) }, { "along_x", false }, { "front", -1 } });
                rows.Append(new GDict { { "r", new Rect2i(x0 + w - depth, z0 + depth, depth, d - 2 * depth) }, { "along_x", false }, { "front", 1 } });
            }
            else if (w >= d)
            {
                // back to back rows along the long side
                long north = (d >> (int)(1));
                rows.Append(new GDict { { "r", new Rect2i(x0, z0, w, north) }, { "along_x", true }, { "front", -1 } });
                rows.Append(new GDict { { "r", new Rect2i(x0, z0 + north, w, d - north) }, { "along_x", true }, { "front", 1 } });
            }
            else
            {
                long west = (w >> (int)(1));
                rows.Append(new GDict { { "r", new Rect2i(x0, z0, west, d) }, { "along_x", false }, { "front", -1 } });
                rows.Append(new GDict { { "r", new Rect2i(x0 + west, z0, w - west, d) }, { "along_x", false }, { "front", 1 } });
            }
            // the courtyard: low buildings behind the street wall, no open pad
            if (rows.Size() == 4)
            {
                var yard = new Rect2i(x0 + depth, z0 + depth, w - 2 * depth, d - 2 * depth);
                rows.Append(new GDict { { "r", yard }, { "along_x", yard.size.x >= yard.size.y }, { "front", 0 }, { "back", true } });
            }
            GArray<GDict> @out = new GArray<GDict>();
            foreach (GDict row in rows)
            {
                row["grow"] = grow;
                @out.AppendArray(_FillRow(rng, row, downtown, heightScale, plan, cfg));
            }
            return @out;
        }
        // How much bigger than the first district's the lots of a block's district are (D-039: the
        // districts a grown kaiju opens are blocks of bigger, denser buildings). Past the last
        // district (the outskirts): 0.

        public static long LotGrow(GDict block, GDict cfg)
        {
            GArray<Variant> grows = cfg.Get("district_lot_grow", Gd.Arr());
            long k = Num.I(block.Get("district", 0));
            return (k < grows.Size() ? Num.I(grows[k]) : 0);
        }
        // Tallest a building may be at this much downtown.

        public static long _HeightCap(double town, GDict cfg)
        {
            double lo = Num.F(cfg["min_height"]) + 3.0;
            return Gd.Roundi(Gd.Lerpf(lo, Num.F(cfg["max_height"]), Gd.Sqrt(town)));
        }
        // 0 at the edge of town .. 1 at the core.

        public static double TownShare(Vector2 p, GDict cfg)
        {
            double best = 0.0;
            foreach (Vector3 c in CityGen.Cores(cfg))
            {
                best = Gd.Maxf(best, 1.0 - p.DistanceTo(new Vector2(c.x, c.y)) / c.z);
            }
            return Gd.Clampf(best, 0.0, 1.0);
        }
        // Cuts a row of lots along its street face; neighbours in a row read as one terrace.

        public static GArray<GDict> _FillRow(RandomNumberGenerator rng, GDict row, double downtown, double heightScale, GDict plan, GDict cfg)
        {
            Rect2i r = row["r"];
            bool alongX = row["along_x"];
            long length = (alongX ? r.size.x : r.size.y);
            long deep = (alongX ? r.size.y : r.size.x);
            if ((length < 2 || deep < 2))
            {
                return new GArray<GDict>();
            }
            long grow = Num.I(row.Get("grow", 0));
            long fmin = Num.I(cfg["frontage_min"]) + grow;
            long fmax = Num.I(cfg["frontage_max"]) + ((downtown > 0.5 ? 2 : 0)) + grow * 2;
            long minH = Num.I(cfg["min_height"]);
            bool back = row.Get("back", false);
            long rowCap = _HeightCap(downtown, cfg);
            if (back)
            {
                rowCap = minH + 2;
            }
            long terraceH = rng.RandiRange(minH, Gd.Maxi(minH, ((rowCap + minH) >> (int)(1))));
            long terraceStyle = rng.RandiRange(0, 3);
            var yards = downtown < 0.15 && rng.Randf() < Num.F(cfg["yard_chance"]) && !back;
            GArray<GDict> @out = new GArray<GDict>();
            long t = 0;
            while (t < length)
            {
                long span = rng.RandiRange(fmin, fmax);
                if (length - (t + span) < fmin)
                {
                    span = length - t;
                }
                var mid = (new Vector2(r.position) + ((alongX ? new Vector2(t + span * 0.5, deep * 0.5) : new Vector2(deep * 0.5, t + span * 0.5))));
                double town = TownShare(mid, cfg);
                long cap = (back ? rowCap : _HeightCap(town, cfg));
                long h = Gd.Mini(terraceH + rng.RandiRange(-1, 1), cap);
                double roll = rng.Randf();
                // Both heights are always drawn, so a stage's tower chance or height cap (D-039) never
                // shifts the numbers the lots after this one draw.
                long towerH = rng.RandiRange(Gd.Maxi(minH, Gd.Roundi(cap * 0.6)), Gd.Maxi(minH, cap));
                GArray<Variant> pencil = cfg["pencil_height"];
                long pencilH = rng.RandiRange(Num.I(pencil[0]), Num.I(pencil[1]));
                if (back)
                {
                }
                else if (roll < Gd.Sqrt(town) * Num.F(cfg["tower_chance"]))
                {
                    h = towerH;
                }
                else if (span <= 3 && roll > 1.0 - Num.F(cfg["pencil_chance"]))
                {
                    // a Tokyo pencil building shoots up among the low-rise
                    h = pencilH;
                }
                h = Gd.Maxi(2, Gd.Roundi(h * heightScale));
                long style = (rng.Randf() < 0.6 ? terraceStyle : rng.RandiRange(0, 3));
                long lotDeep = deep;
                // a front yard: the house steps back off the street
                long shift = 0;
                if (yards && lotDeep >= 3 && rng.Randf() < 0.6)
                {
                    lotDeep -= 1;
                    shift = (Num.I(row["front"]) < 0 ? 1 : 0);
                }
                var lot = new Rect2i();
                if (alongX)
                {
                    lot = new Rect2i(r.position.x + t, r.position.y + shift, span, lotDeep);
                }
                else
                {
                    lot = new Rect2i(r.position.x + shift, r.position.y + t, lotDeep, span);
                }
                t += span;
                var centre = new Vector2(lot.position) + new Vector2(lot.size) * 0.5;
                if (OnDiagonal(plan, centre, new Vector2(lot.size), cfg))
                {
                    // cut by the diagonal avenue: the leftover corner is a plaza
                    continue;
                }
                @out.Append(new GDict { { "x", centre.x }, { "z", centre.y }, { "w", lot.size.x }, { "d", lot.size.y }, { "h", h }, { "tier", CityGen.TierForHeight(h, cfg) }, { "style", style } });
            }
            return @out;
        }
        // Whether a footprint (centre, size) reaches into the diagonal avenue or its sidewalks.

        public static bool OnDiagonal(GDict plan, Vector2 centre, Vector2 size, GDict cfg)
        {
            GDict diag = plan["diagonal"];
            Vector2 dir = diag["dir"];
            var normal = new Vector2(-dir.y, dir.x);
            double reach = Gd.Absf(normal.x) * size.x * 0.5 + Gd.Absf(normal.y) * size.y * 0.5;
            double clear = CityGen.WidthOf(CityGen.DIAGONAL, cfg) * 0.5 + Num.F(cfg["sidewalk"]) + reach;
            return CityGen.DiagonalDistance(plan, centre) < clear;
        }

        void _InitFields()
        {
        }
        public CityLots() { _InitFields(); }
    }
}
