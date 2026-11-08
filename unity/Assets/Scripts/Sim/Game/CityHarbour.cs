// Generated from sim/city_harbour.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityHarbour : RefCounted
    {
        public static implicit operator CityHarbour(Variant v) => (CityHarbour)v.Obj;

        // The fixed beachfront the kaiju rises from at the start of every run (D-381, board v4, director
        // 2026-10-29: "build this as a bespoke, fixed location, its always the same, just have the
        // randomzied map connect to these fixed roads and environmental positions"). Everything north of
        // the back street (city "harbour" "back_z", the one street line it pins, CityLines) is the
        // front, the same at every stage: the sea, a long curved beach (sand, promenade, the beach road),
        // hotel blocks squared off between side streets from the road to the back street, and past the
        // beach's east end a man-made seawall and the working port (quay, finger piers, yard). The random
        // grid meets it on the back street: no grid street, alley or diagonal is laid north of it, and
        // no landmark, park or plaza is chosen there. Part of CityGen.map, which records the front as
        // plan["bay"] (out to the map's edges, down to the back street's centre line), plan["harbour"]
        // (its shapes) and the rise as plan["rise_spawn"] (in the water off the beach at "rise_x") and
        // plan["rise_bank"] (on the sand straight up the beach). Pure.
        // True when the city has the beachfront: it has "harbour" tuning and its layout is the bay
        // (CityWater; Carthago and Thule rise from their own water, D-435).

        public static bool On(GDict cfg)
        {
            return cfg.Has("harbour") && CityWater.Kind(cfg) == CityWater.BAY;
        }
        // The front between the street centre lines: the whole map north of the back street; an empty
        // Rect2 without one.

        public static Rect2 RectOf(GDict cfg)
        {
            if (!CityHarbour.On(cfg))
            {
                return new Rect2();
            }
            double outer = Num.F(cfg["outer_half"]) + 1.0;
            return new Rect2(-outer, -outer, outer * 2.0, Num.F(cfg["harbour"]["back_z"]) + outer);
        }
        // True when `rect` reaches into the front (CityGen and CitySites keep landmarks, parks and plazas
        // out of it).

        public static bool InAny(GDict cfg, Rect2 rect)
        {
            var bay = RectOf(cfg);
            return bay.HasArea() && bay.Intersects(rect.Grow(-0.01));
        }
        // The street lines every plan pins: {"x": [], "z": [the back street]}.

        public static GDict Pins(GDict cfg)
        {
            GArray<double> xs = new GArray<double>();
            GArray<double> zs = new GArray<double>();
            if (CityHarbour.On(cfg))
            {
                zs.Append(Num.F(cfg["harbour"]["back_z"]));
            }
            return new GDict { { "x", xs }, { "z", zs } };
        }
        // True when the street from a to b enters the front (any part within plan["bay"]): it is never
        // laid. The back street lies on its south edge and is laid; a grid line on its west, north or
        // east edge is not (the 1.5x city's outermost x-line falls on the east edge).

        public static bool Inside(GDict plan, Vector2 a, Vector2 b)
        {
            Rect2 bay = plan.Get("bay", new Rect2());
            // Any part of the line inside (not only its middle): a long segment can cross the bay's corner
            // with its middle outside. Only the south edge is inset (-0.01): the back street stays.
            var front = bay.GrowIndividual(0.01, 0.01, 0.01, -0.01);
            return bay.HasArea() && front.Intersects(new Rect2(a.Min(b), (b - a).Abs()), true);
        }
        // True when the street from a to b lies on the front's edge or inside it (CityAlleys: never an
        // alley, so the front always meets a street with a pavement).

        public static bool Touches(GDict plan, Vector2 a, Vector2 b)
        {
            Rect2 bay = plan.Get("bay", new Rect2());
            return bay.HasArea() && bay.Grow(0.01).HasPoint((a + b) * 0.5);
        }
        // touches() from the city's config alone (CityAlleys: the back street is never an alley).

        public static bool TouchesAny(GDict cfg, Vector2 a, Vector2 b)
        {
            var bay = RectOf(cfg);
            return bay.HasArea() && bay.Grow(0.01).HasPoint((a + b) * 0.5);
        }
        // True when grid cell (i, j) lies in the front (its centre inside plan["bay"]).

        public static bool Covers(GDict plan, long i, long j)
        {
            Rect2 bay = plan.Get("bay", new Rect2());
            GArray<double> xs = plan["xs"];
            GArray<double> zs = plan["zs"];
            var c = new Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5);
            return bay.HasArea() && bay.HasPoint(c);
        }
        // Marks the front on `plan` (CityGen.map's, its blocks laid): every grid block in it becomes sea
        // ("harbour", keeping its use under "was" so CityGen.generate draws its lots the same and drops
        // them), its own hotel blocks are added, and its shapes and the rise are recorded. avenues_z:
        // the plan's avenue line indices, so the back street's carriageway takes an avenue's width there.

        public static void Mark(GDict plan, GDict _avenuesX, GDict avenuesZ, GDict cfg)
        {
            Rect2 bay = plan.Get("bay", new Rect2());
            if (!bay.HasArea())
            {
                return;
            }
            GArray<double> zs = plan["zs"];
            var backKind = (avenuesZ.Has(zs.Find(bay.end.y)) ? CityGen.AVENUE : CityGen.STREET);
            double back = CityGen.WidthOf(backKind, cfg) * 0.5;
            foreach (GDict block in Gd.Iter(plan["blocks"]))
            {
                if (block.Has("cell") && !block.Has("site"))
                {
                    Vector2i cell = block["cell"];
                    if (Covers(plan, cell.x, cell.y))
                    {
                        block["was"] = block.Get("was", block["use"]);
                        block["use"] = "harbour";
                    }
                }
            }
            GDict h = cfg["harbour"];
            var inner = new Rect2(bay.position, new Vector2(bay.size.x, bay.size.y - back));
            GArray<Variant> ends = h["beach_x"];
            GArray<Rect2> walls = new GArray<Rect2>();
            foreach (GArray<Variant> r in Gd.Iter(h["seawall"]))
            {
                walls.Append(new Rect2(Num.F(r[0]), Num.F(r[1]), Num.F(r[2]), Num.F(r[3])));
            }
            double quay = Bands(h, Num.F(ends[1]))[2] - Num.F(h["quay_back"]);
            GArray<Rect2> piers = new GArray<Rect2>();
            foreach (GArray<Variant> r in Gd.Iter(h["piers"]))
            {
                double w = Num.F(r[1]);
                piers.Append(new Rect2(Num.F(r[0]) - w, quay - Num.F(r[2]), w, Num.F(r[2])));
            }
            GArray<Variant> light = h["light"];
            double rise = Num.F(h["rise_x"]);
            double apex = ShoreAt(h, rise);
            plan["harbour"] = new GDict { { "rect", inner }, { "h", h }, { "mouth", Num.F(cfg["coast_z"]) }, { "apex", apex }, { "beach_east", Num.F(ends[1]) }, { "port_x", walls[0].end.x }, { "quay_z", quay }, { "walls", walls }, { "piers", piers }, { "light", new Vector2(Num.F(light[0]), Num.F(light[1])) }, { "sides", Sides(h, inner) } };
            plan["rise_spawn"] = new Vector2(rise, apex - Num.F(h["beach"]) - Num.F(h["nose_gap"]));
            plan["rise_bank"] = new Vector2(rise, apex + Num.F(h["bank_inset"]));
            _HotelBlocks(plan, cfg);
        }
        // The side streets' x lines, west from city "harbour" "side_streets" [first, spacing] to the
        // front's west edge.

        public static GArray<double> Sides(GDict h, Rect2 inner)
        {
            GArray<Variant> row = h["side_streets"];
            GArray<double> @out = new GArray<double>();
            double x = Num.F(row[0]);
            while (x > inner.position.x)
            {
                @out.Append(x);
                x -= Num.F(row[1]);
            }
            return @out;
        }
        // The hotel blocks: one between each pair of side streets (the first from the beach's east end),
        // from the beach road's far kerb (its furthest point along the block, so the block is square)
        // to the back street, inset by the sidewalk; built inside the last district, a stand-in past
        // the stage's band (CityBand), "outer" past the last district.

        public static void _HotelBlocks(GDict plan, GDict cfg)
        {
            GDict b = plan["harbour"];
            GDict h = b["h"];
            Rect2 inner = b["rect"];
            double walk = Num.F(cfg["sidewalk"]);
            double street = CityGen.WidthOf(CityGen.STREET, cfg) * 0.5;
            double full = CityGen.Districts(cfg)[-1];
            GArray<double> edges = new GArray<double> { Num.F(b["beach_east"]) + street };
            GArray<double> sides = b["sides"];
            edges.AppendArray(sides);
            edges.Append(inner.position.x - street - walk);
            GArray<GDict> blocks = plan["blocks"];
            GArray<long> held = new GArray<long>();
            foreach (long k in Gd.Range(edges.Size() - 1))
            {
                double x0 = edges[k + 1] + street + walk;
                double x1 = edges[k] - street - walk;
                double kerb = -Gd.INF;
                double x = x0;
                while (x < x1 + 0.5)
                {
                    kerb = Gd.Maxf(kerb, Bands(h, Gd.Minf(x, x1))[3]);
                    x += 0.5;
                }
                var rect = new Rect2(x0, kerb + walk, x1 - x0, inner.end.y - kerb - walk * 2.0);
                if ((rect.size.y < Num.F(cfg["depth_min"]) || rect.size.x < Num.F(cfg["frontage_min"])))
                {
                    continue;
                }
                var city = Gd.Maxf(Gd.Absf(x0), Gd.Absf(x1)) < full;
                blocks.Append(new GDict { { "rect", rect }, { "use", ((city || CityBand.Real(rect, cfg)) ? "built" : "outer") }, { "district", CityGen.DistrictOf(rect, cfg) }, { "front", true } });
                if (city)
                {
                    held.Append(blocks.Size() - 1);
                }
            }
            CityBand.HoldBack(plan, held, cfg);
        }
        // u along the beach: 0 at its east end, 1 at its west end (held past them).

        public static double _U(GDict h, double x)
        {
            GArray<Variant> ends = h["beach_x"];
            double east = Num.F(ends[1]);
            return Gd.Clampf((east - x) / (east - Num.F(ends[0])), 0.0, 1.0);
        }
        // The waterline's z at x (city "harbour" "shore"; h: that dictionary).

        public static double ShoreAt(GDict h, double x)
        {
            GArray<Variant> s = h["shore"];
            double u = _U(h, x);
            double bulge = Num.F(s[1]) * Gd.Pow(Gd.Sin(Gd.PI * u), Num.F(s[2]));
            return Num.F(h["sea_z"]) + Num.F(s[0]) + bulge + Num.F(s[3]) * u;
        }
        // The beach's bands at x, landward: [the waterline, the sand's land edge, the promenade's land
        // edge (the beach road's near kerb), the road's far kerb] (z). Past the beach's east end the
        // road runs on straight along the port.

        public static PackedFloat32Array Bands(GDict h, double x)
        {
            double u = _U(h, x);
            GArray<Variant> sand = h["sand"];
            GArray<Variant> prom = h["promenade"];
            double water = ShoreAt(h, x);
            double top = water + Gd.Lerpf(Num.F(sand[0]), Num.F(sand[1]), u);
            double kerb = top + Gd.Lerpf(Num.F(prom[0]), Num.F(prom[1]), u);
            return new PackedFloat32Array(Gd.Arr(water, top, kerb, kerb + Num.F(h["road"])));
        }
        // The front inside its kerbs (plan["harbour"]["rect"]): no land, pavement block or prop of the
        // city's own; the front's water, sand, promenade, roads and port stand there (HarbourView). []
        // with none.

        public static GArray<Rect2> Basin(GDict plan)
        {
            GArray<Rect2> @out = new GArray<Rect2>();
            if (plan.Has("harbour"))
            {
                @out.Append(plan["harbour"]["rect"]);
            }
            return @out;
        }
        // Whether p lies in the front's water: seaward of the beach's waterline, of the port's quay (bar
        // its piers) and of the seawall, south of the coast.

        public static bool Holds(GDict plan, Vector2 p)
        {
            if (!plan.Has("harbour"))
            {
                return false;
            }
            GDict b = plan["harbour"];
            GDict h = b["h"];
            return HoldsAt(plan, p, ShoreAt(h, p.x));
        }
        // holds() with the shore line at p.x given (`shore`: shore_at of the plan's harbour "h"), for a
        // grid that reads it once per column (HarbourView._heights).

        public static bool HoldsAt(GDict plan, Vector2 p, double shore)
        {
            if (!plan.Has("harbour"))
            {
                return false;
            }
            GDict b = plan["harbour"];
            Rect2 rect = b["rect"];
            if ((!rect.HasPoint(p) || p.y < Num.F(b["mouth"])))
            {
                return false;
            }
            GArray<Rect2> walls = b["walls"];
            foreach (Rect2 r in walls)
            {
                if (r.HasPoint(p))
                {
                    return false;
                }
            }
            if (p.x >= Num.F(b["port_x"]))
            {
                GArray<Rect2> piers = b["piers"];
                foreach (Rect2 r in piers)
                {
                    if (r.HasPoint(p))
                    {
                        return false;
                    }
                }
                return p.y < Num.F(b["quay_z"]);
            }
            return p.y < shore;
        }
        // Whether p lies on the beach's sand: between the waterline and the promenade, west of the
        // seawall.

        public static bool OnSand(GDict plan, GDict _cfg, Vector2 p)
        {
            if (!plan.Has("harbour"))
            {
                return false;
            }
            GDict b = plan["harbour"];
            Rect2 rect = b["rect"];
            GDict h = b["h"];
            var at = Bands(h, p.x);
            return rect.HasPoint(p) && p.x <= Num.F(b["beach_east"]) && p.y >= at[0] && p.y <= at[1];
        }
        // The waterline from the front's west edge to the beach's east end (city "harbour" "arc_points"
        // samples along the beach).

        public static PackedVector2Array Arc(GDict plan, GDict cfg)
        {
            var @out = new PackedVector2Array();
            if (!plan.Has("harbour"))
            {
                return @out;
            }
            GDict b = plan["harbour"];
            GDict h = b["h"];
            GArray<Variant> ends = h["beach_x"];
            Rect2 rect = b["rect"];
            @out.Append(new Vector2(rect.position.x, ShoreAt(h, rect.position.x)));
            long n = Num.I(cfg["harbour"]["arc_points"]);
            foreach (long k in Gd.Range(n + 1))
            {
                double x = Gd.Lerpf(Num.F(ends[0]), Num.F(ends[1]), Gd.Float(k) / n);
                @out.Append(new Vector2(x, ShoreAt(h, x)));
            }
            return @out;
        }
        // How far p lies from the waterline (the arc), metres.

        public static double FromShore(GDict plan, GDict cfg, Vector2 p)
        {
            var line = Arc(plan, cfg);
            double best = Gd.INF;
            foreach (long k in Gd.Range(line.Size() - 1))
            {
                var q = Geometry2D.GetClosestPointToSegment(p, line[k], line[k + 1]);
                best = Gd.Minf(best, p.DistanceTo(q));
            }
            return best;
        }
        // The sea's surface (world y): city "harbour" "sea_level".

        public static double Sea(GDict cfg)
        {
            return (CityHarbour.On(cfg) ? Num.F(cfg["harbour"]["sea_level"]) : 0.0);
        }
        // The sea floor at the rise (world y): the sea's surface less city "harbour" "seabed_depth"
        // (EmergeReach.fit: the stage's biggest body crouched, plus "seabed_clear"; the data's own
        // figure until it is fitted).

        public static double Seabed(GDict cfg)
        {
            return (CityHarbour.On(cfg) ? Sea(cfg) - Num.F(cfg["harbour"]["seabed_depth"]) : 0.0);
        }
        // The wading floor (world y): city "wade_depth" under the sea's surface, where the shelf levels
        // out (director 2026-10-31: the baby half submerged).

        public static double ShelfFloor(GDict cfg)
        {
            return Sea(cfg) - Num.F(cfg["wade_depth"]);
        }
        // How far seaward of the shore line the water meets the sand (the shelf's slope crosses the sea).

        public static double Waterline(GDict cfg)
        {
            GDict h = cfg["harbour"];
            double top = Num.F(h["sand_top"]);
            return Num.F(h["drop"]) * (top - Sea(cfg)) / (top - DropFloor(cfg));
        }
        // The foot of the drop (world y): city "harbour" "drop_depth" under the sea's surface, "drop"
        // metres out from the shore line (director 2026-10-31: steeper near the shore, so a wave's trough
        // never bares the seabed), from where the shelf eases on down to the wading floor.

        public static double DropFloor(GDict cfg)
        {
            return Sea(cfg) - Num.F(cfg["harbour"]["drop_depth"]);
        }
        // The ground's height at p: 0 (the street) on land; in the water the sea floor, sloping gently from
        // "sand_top" (the sand's own height, just under the street) at the shore line, faster over the
        // first "drop" metres to drop_floor, then down to the wading floor by "shelf" metres, measured
        // straight out (director 2026-10-31: "slowly deeper but never too deep"); only the rise's hollow
        // goes down to the seabed. The port's water is deep to its quay.

        public static double FloorAt(GDict plan, GDict cfg, Vector2 p)
        {
            if (!Holds(plan, p))
            {
                return 0.0;
            }
            GDict h = cfg["harbour"];
            return FloorHeld(plan, cfg, p, ShoreAt(h, p.x));
        }
        // floor_at() at a p that holds() water, the shore line at p.x given (`shore`: shore_at of
        // cfg "harbour").

        public static double FloorHeld(GDict plan, GDict cfg, Vector2 p, double shore)
        {
            GDict b = plan["harbour"];
            GDict h = cfg["harbour"];
            if (p.x >= Num.F(b["port_x"]))
            {
                return Seabed(cfg);
            }
            double @out = shore - p.y;
            double drop = Num.F(h["drop"]);
            double shelf = Gd.Lerpf(Num.F(h["sand_top"]), DropFloor(cfg), Gd.Clampf(@out / drop, 0.0, 1.0));
            if (@out > drop)
            {
                double share = Gd.Clampf((@out - drop) / (Num.F(h["shelf"]) - drop), 0.0, 1.0);
                shelf = Gd.Lerpf(DropFloor(cfg), ShelfFloor(cfg), share);
            }
            double hollow = Num.F(h["hollow"]);
            var centre = new Vector2(Num.F(h["rise_x"]), Num.F(b["apex"]) - Num.F(h["beach"]) - hollow);
            double rim = Gd.Smoothstep(hollow, hollow + Num.F(h["hollow_edge"]), p.DistanceTo(centre));
            return Gd.Minf(shelf, Gd.Lerpf(Seabed(cfg), shelf, rim));
        }

        void _InitFields()
        {
        }
        public CityHarbour() { _InitFields(); }
    }
}
