// Generated from sim/city_water.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityWater : RefCounted
    {
        public static implicit operator CityWater(Variant v) => (CityWater)v.Obj;

        // The water each demo city is built round and the kaiju rises from (D-435, director 2026-11-01:
        // "the layouts should be completely different. we will have to craft unique 'emerge' scenes for
        // each map / only one map should have the water layout like that"). City "layout" "kind":
        // - bay: the fixed beachfront and the river (CityHarbour, CityRiver; Ostia Minor). Nothing here.
        // - cothon: a round naval harbour mid-city (Carthago). The diagonals' open site (CityPlaza) holds
        // it: water "radius" m round diagonal_through, a ring avenue "ring" m out, and each diagonal
        // carried on from the site's kerb to the ring as a spoke. "canals": compass points ("n", "e",
        // "s", "w"), each a straight canal "canal_width" m wide from the harbour out to the map's edge
        // (director 2026-11-01: "has to somehow be connected to the edge of the map"); avenues and
        // diagonals bridge it, no other street comes within "quay" m, a block it reaches is "shore".
        // - fjord: a narrow band of water, iced over, cutting the city north to south (Thule): centre x
        // + meander[0] sin(2 pi z / meander[1]), "width" m wide. No street comes within "quay" m of it
        // but the avenues and diagonals that bridge it; a block it reaches is bare "shore".
        // Records plan["water"] (its shape) and the rise: plan["rise_spawn"] in the water's middle (the
        // fjord's at "rise_z") and plan["rise_bank"] "bank_inset" m onto land. Part of CityGen.map. Pure.
        public const string BAY = "bay";
        public const string COTHON = "cothon";
        public const string FJORD = "fjord";
        public static readonly GDict COMPASS = new GDict { { "n", new Vector2(0.0, -1.0) }, { "e", new Vector2(1.0, 0.0) }, { "s", new Vector2(0.0, 1.0) }, { "w", new Vector2(-1.0, 0.0) } };
        // The city's layout kind (bay without one).

        public static string Kind(GDict cfg)
        {
            GDict layout = cfg.Get("layout", new GDict());
            return Gd.Str(layout.Get("kind", BAY));
        }
        // Lays the harbour's ring avenue and the spokes from the open site's kerb to it (cothon only;
        // after the diagonals, CityGen.map). index: CityGen's node index.

        public static void Lay(GDict plan, GDict index, GDict cfg)
        {
            if (Kind(cfg) != COTHON)
            {
                return;
            }
            GDict site = _Site(plan);
            if (site.IsEmpty())
            {
                return;
            }
            GDict layout = cfg["layout"];
            Vector2 at = plan["diagonal"]["at"];
            double ring = Num.F(layout["ring"]);
            Rect2 outer = site["outer"];
            GArray<double> angles = new GArray<double>();
            long n = Num.I(layout["ring_points"]);
            foreach (long k in Gd.Range(n))
            {
                angles.Append(Gd.TAU * k / n);
            }
            foreach (GDict diag in Gd.Iter(plan["diagonals"]))
            {
                Vector2 dir = diag["dir"];
                foreach (Vector2 way in Gd.Arr(dir, -dir))
                {
                    angles.Append(Gd.Fposmod(way.Angle(), Gd.TAU));
                    var kerb = _Exit(diag, way, outer);
                    CityGen.Lay(plan, index, at + way * ring, kerb, CityGen.DIAGONAL, cfg);
                }
            }
            angles.Sort();
            foreach (long k in Gd.Range(angles.Size()))
            {
                var a = at + Vector2.FromAngle(angles[k]) * ring;
                var b = at + Vector2.FromAngle(angles[(k + 1) % angles.Size()]) * ring;
                CityGen.Lay(plan, index, a, b, CityGen.AVENUE, cfg);
            }
            plan["water"] = new GDict { { "kind", COTHON }, { "at", at }, { "radius", Num.F(layout["radius"]) }, { "ring", ring } };
            // ashore along a spoke, never up a canal
            Vector2 spoke = plan["diagonals"][0]["dir"];
            _Rise(plan, at, spoke, Num.F(layout["radius"]), layout);
        }
        // True when the street from a to b would run into the fjord (within its quay): it is not laid,
        // unless it is an avenue or diagonal crossing it, a bridge.

        public static bool Wet(GDict plan, Vector2 a, Vector2 b, string streetKind)
        {
            if (_CanalWet(plan, a, b, streetKind))
            {
                return true;
            }
            GDict water = plan.Get("fjord", new GDict());
            if (water.IsEmpty())
            {
                return false;
            }
            var across = Gd.Absf(b.x - a.x) > Gd.Absf(b.y - a.y);
            if (across && Gd.In(streetKind, Gd.Arr(CityGen.AVENUE, CityGen.DIAGONAL)))
            {
                return false;
            }
            double reach = Num.F(water["width"]) * 0.5 + Num.F(water["quay"]);
            long n = Gd.Maxi(1, Gd.Ceili(a.DistanceTo(b) / Num.F(water["step"])));
            foreach (long k in Gd.Range(n + 1))
            {
                if (_Off(water, a.Lerp(b, Gd.Float(k) / n)) < reach)
                {
                    return true;
                }
            }
            return false;
        }
        // Before the streets (CityGen.map): records the fjord, or the harbour's canals (plan["canals"]:
        // each {rect, dir}), so wet() can keep streets off them.

        public static void Dig(GDict plan, GDict cfg)
        {
            if (Kind(cfg) == COTHON)
            {
                _DigCanals(plan, cfg);
            }
            if (Kind(cfg) != FJORD)
            {
                return;
            }
            GDict layout = cfg["layout"];
            GDict water = layout.Duplicate(true);
            plan["fjord"] = water;
            plan["water"] = water;
        }
        // After the blocks (CityGen.map): every block the fjord reaches turns bare "shore", and the rise
        // goes in the ice at rise_z, wading east.

        public static void Mark(GDict plan, GDict cfg)
        {
            foreach (GDict block in Gd.Iter(plan["blocks"]))
            {
                if (!block.Has("site") && _InCanal(plan, CityGen.Pavement(block, cfg), 0.0))
                {
                    _Shore(block);
                }
            }
            GDict water = plan.Get("fjord", new GDict());
            if (water.IsEmpty())
            {
                return;
            }
            double half = Num.F(water["width"]) * 0.5;
            foreach (GDict block in Gd.Iter(plan["blocks"]))
            {
                if (block.Has("site"))
                {
                    continue;
                }
                var rect = CityGen.Pavement(block, cfg);
                if (_Reaches(water, rect, half))
                {
                    _Shore(block);
                }
            }
            double z = Num.F(water["rise_z"]);
            _Rise(plan, new Vector2(CentreX(water, z), z), new Vector2(1.0, 0.0), half, water);
        }
        // True when the fjord (within its quay) reaches into rect: CitySites keeps landmarks off it.

        public static bool Reaches(GDict plan, Rect2 rect)
        {
            if (_InCanal(plan, rect, Num.F(plan.Get("canal_quay", 0.0))))
            {
                return true;
            }
            GDict water = plan.Get("fjord", new GDict());
            if (water.IsEmpty())
            {
                return false;
            }
            return _Reaches(water, rect, Num.F(water["width"]) * 0.5 + Num.F(water["quay"]));
        }
        // True when p lies on open water: the fjord, the harbour or a canal (the kerb audit's bridge
        // parapets, RoadGroundAudit).

        public static bool Over(GDict plan, Vector2 p)
        {
            foreach (GDict canal in Gd.Iter(plan.Get("canals", Gd.Arr())))
            {
                Rect2 rect = canal["rect"];
                if (rect.HasPoint(p))
                {
                    return true;
                }
            }
            GDict water = plan.Get("water", new GDict());
            var matched1 = Gd.Str(water.Get("kind", ""));
            if (matched1 == COTHON)
            {
                Vector2 at = water["at"];
                return p.DistanceTo(at) < Num.F(water["radius"]);
            }
            GDict fjord = plan.Get("fjord", new GDict());
            return !fjord.IsEmpty() && _Off(fjord, p) < Num.F(fjord["width"]) * 0.5;
        }
        // The fjord's centre line at z.

        public static double CentreX(GDict water, double z)
        {
            GArray<Variant> meander = water["meander"];
            return Num.F(water["x"]) + Num.F(meander[0]) * Gd.Sin(Gd.TAU * z / Num.F(meander[1]));
        }

        public static double _Off(GDict water, Vector2 p)
        {
            return Gd.Absf(p.x - CentreX(water, p.y));
        }
        // True when the fjord's water (half wide) reaches into rect.

        public static bool _Reaches(GDict water, Rect2 rect, double half)
        {
            double step = Num.F(water["step"]);
            double z = rect.position.y;
            while (z <= rect.end.y)
            {
                double c = CentreX(water, z);
                if (c + half > rect.position.x && c - half < rect.end.x)
                {
                    return true;
                }
                z += step;
            }
            return false;
        }
        // The diagonals' open site (CityPlaza), or {}.

        public static GDict _Site(GDict plan)
        {
            foreach (GDict site in Gd.Iter(plan.Get("sites", Gd.Arr())))
            {
                if (Gd.Truthy(site.Get("plaza", false)))
                {
                    return site;
                }
            }
            return new GDict();
        }
        // Where diag, from its point "at" heading `way`, leaves rect (the open site's kerb line).

        public static Vector2 _Exit(GDict diag, Vector2 way, Rect2 rect)
        {
            Vector2 at = diag["at"];
            double x = (way.x > 0.0 ? rect.end.x : rect.position.x);
            double z = (way.y > 0.0 ? rect.end.y : rect.position.y);
            double tx = (Gd.Absf(way.x) > 0.0001 ? (x - at.x) / way.x : Gd.INF);
            double tz = (Gd.Absf(way.y) > 0.0001 ? (z - at.y) / way.y : Gd.INF);
            if (tx < tz)
            {
                return new Vector2(x, CityDiagonals.AtX(diag, x));
            }
            return new Vector2(CityDiagonals.AtZ(diag, z), z);
        }
        // The rise: in the water at `at`, wading `way` to bank_inset past the water's edge (`edge` m out).

        public static void _Rise(GDict plan, Vector2 at, Vector2 way, double edge, GDict layout)
        {
            plan["rise_spawn"] = at;
            plan["rise_bank"] = at + way * (edge + Num.F(layout["bank_inset"]));
        }
        // The harbour's canals: from its centre (diagonal_through) to the edge of the view (CityBand).

        public static void _DigCanals(GDict plan, GDict cfg)
        {
            GDict layout = cfg["layout"];
            GArray<Variant> through = cfg["diagonal_through"];
            var at = new Vector2(Num.F(through[0]), Num.F(through[1]));
            double half = Num.F(layout.Get("canal_width", 0.0)) * 0.5;
            double edge = CityBand.Extent(cfg);
            GArray<GDict> canals = new GArray<GDict>();
            foreach (string point in Gd.Iter(layout.Get("canals", Gd.Arr())))
            {
                Vector2 dir = COMPASS[point];
                var end = at + dir * (edge - at.Dot(dir));
                var side = new Vector2(dir.y, -dir.x) * half;
                var rect = new Rect2(at - side, Vector2.ZERO).Expand(at + side).Expand(end - side).Expand(end + side);
                canals.Append(new GDict { { "rect", rect }, { "dir", dir } });
            }
            plan["canals"] = canals;
            plan["canal_quay"] = Num.F(layout.Get("quay", 0.0));
        }
        // True when a street from a to b would run along a canal (within its quay); avenues crossing it
        // and diagonals are bridges.

        public static bool _CanalWet(GDict plan, Vector2 a, Vector2 b, string streetKind)
        {
            double quay = Num.F(plan.Get("canal_quay", 0.0));
            foreach (GDict canal in Gd.Iter(plan.Get("canals", Gd.Arr())))
            {
                Vector2 dir = canal["dir"];
                var across = Gd.Absf((b - a).Normalized().Dot(dir)) < 0.5;
                if ((streetKind == CityGen.DIAGONAL || (across && streetKind == CityGen.AVENUE)))
                {
                    continue;
                }
                Rect2 rect = canal["rect"];
                if (_SegmentIn(rect.Grow(quay), a, b))
                {
                    return true;
                }
            }
            return false;
        }
        // True when any canal (grown by `grow` m) overlaps rect.

        public static bool _InCanal(GDict plan, Rect2 rect, double grow)
        {
            foreach (GDict canal in Gd.Iter(plan.Get("canals", Gd.Arr())))
            {
                Rect2 water = canal["rect"];
                if (water.Grow(grow).Intersects(rect))
                {
                    return true;
                }
            }
            return false;
        }
        // True when the segment a-b passes through rect (sampled each metre).

        public static bool _SegmentIn(Rect2 rect, Vector2 a, Vector2 b)
        {
            long n = Gd.Maxi(1, Gd.Ceili(a.DistanceTo(b)));
            foreach (long k in Gd.Range(n + 1))
            {
                if (rect.HasPoint(a.Lerp(b, Gd.Float(k) / n)))
                {
                    return true;
                }
            }
            return false;
        }
        // A block the water reaches: bare ground (its old use kept in "was").

        public static void _Shore(GDict block)
        {
            block["was"] = block["use"];
            block["use"] = "shore";
        }

        void _InitFields()
        {
        }
        public CityWater() { _InitFields(); }
    }
}
