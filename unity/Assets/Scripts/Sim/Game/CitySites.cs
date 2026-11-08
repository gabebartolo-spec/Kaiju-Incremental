// Generated from sim/city_sites.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CitySites : RefCounted
    {
        public static implicit operator CitySites(Variant v) => (CitySites)v.Obj;

        // Landmark sites (part of CityGen.map, split out to keep files small). Each landmark the
        // seeded spread (CitySpread) places takes the street-grid cells round its anchor, as many as its
        // baked footprint (city.landmark_shapes: data/landmarks.json, merged in by Content) plus a
        // margin needs, as one plaza: the streets inside it are never laid, so traffic and the ground
        // go round it. A site stays inside one district (it never swallows a ring avenue), clear of the
        // diagonal avenue and out of the river's row (CityRiver.river_row); a landmark that cannot get
        // one is left out. Pure: the same city config always gives the same sites.
        // One site per landmark the seeded spread places (CitySpread.landmarks): {"id", "spec",
        // "shape", "district", "i": Vector2i (first and last x cell), "j": Vector2i (z cells), "outer":
        // Rect2 between the street centre lines, "rect": Rect2 inside the kerbs}; a bridge's site also
        // carries "water" and "at" once CityRiver.mark has dug its inlet.

        public static GArray<GDict> Find(GDict plan, GArray<double> rings, GArray<Variant> avenues, GDict cfg)
        {
            return CitySpread.Landmarks(plan, rings, avenues, cfg);
        }
        // The site a landmark of `shape` would take round `anchor` (x, z), or {} where it cannot: it
        // fits between ring avenues, stays out of the river's row and every stage's sea bay and clear of
        // the diagonal.
        // axes: [along x, along z], each {lines, rings, avenues, cfg}.

        public static GDict SiteAt(GDict plan, GDict spec, GDict shape, Vector2 anchor, GArray<Variant> axes)
        {
            GDict alongX = axes[0];
            GDict alongZ = axes[1];
            GDict cfg = alongX["cfg"];
            GArray<double> xs = alongX["lines"];
            GArray<double> zs = alongZ["lines"];
            double pad = 2.0 * Num.F(spec.Get("margin", 0.0));
            var i = _Span(alongX, anchor.x, Num.F(shape["w"]) + pad);
            var j = _Span(alongZ, anchor.y, Num.F(shape["d"]) + pad);
            if ((i.x < 0 || j.x < 0))
            {
                return new GDict();
            }
            long river = CityRiver.RiverRow(zs, cfg);
            if (river >= 0 && j.x <= river + 1 && j.y >= river)
            {
                // never in the river's row (CityRiver) nor its far bank, where inlets open
                return new GDict();
            }
            var outer = new Rect2(xs[i.x], zs[j.x], xs[i.y + 1] - xs[i.x], zs[j.y + 1] - zs[j.x]);
            if (((_CrossesDiagonal(plan, outer, cfg) || CityHarbour.InAny(cfg, outer) || CityWater.Reaches(plan, outer))))
            {
                // never across the diagonal nor in any stage's sea bay (CityHarbour)
                return new GDict();
            }
            return _Site(spec, shape, i, j, outer, axes);
        }
        // A bridge's site (spec "kind" "bridge"): `rows` rows of cells on the river's far bank, from the
        // x cell run round anchor_x wide enough for the span and its landings. Its "outer" (the streets
        // it cuts) reaches back over the river's row, so no street crosses the water inside it and its
        // inlet opens straight onto the river (CityRiver.mark digs it). {} where it cannot fit.

        public static GDict BridgeAt(GDict plan, GDict spec, GDict shape, double anchorX, GArray<Variant> axes, long rows)
        {
            GDict alongX = axes[0];
            GDict alongZ = axes[1];
            GDict cfg = alongX["cfg"];
            GArray<double> xs = alongX["lines"];
            GArray<double> zs = alongZ["lines"];
            GArray<double> rings = alongZ["rings"];
            long river = CityRiver.RiverRow(zs, cfg);
            if ((river < 0 || river + 1 + rows >= zs.Size()))
            {
                return new GDict();
            }
            foreach (long k in Gd.Range(river + 2, river + 1 + rows))
            {
                if (_IsRing(zs[k], rings))
                {
                    // the inlet never swallows a ring avenue
                    return new GDict();
                }
            }
            var i = _Span(alongX, anchorX, Num.F(shape["w"]) + 2.0 * Num.F(spec.Get("margin", 0.0)));
            if (i.x < 0)
            {
                return new GDict();
            }
            var j = new Vector2i(river + 1, river + rows);
            var outer = new Rect2(xs[i.x], zs[river], xs[i.y + 1] - xs[i.x], zs[j.y + 1] - zs[river]);
            if (((_CrossesDiagonal(plan, outer, cfg) || CityHarbour.InAny(cfg, outer) || CityWater.Reaches(plan, outer))))
            {
                return new GDict();
            }
            return _Site(spec, shape, i, j, outer, axes);
        }

        public static GDict _Site(GDict spec, GDict shape, Vector2i i, Vector2i j, Rect2 outer, GArray<Variant> axes)
        {
            GDict alongX = axes[0];
            GDict alongZ = axes[1];
            GDict cfg = alongX["cfg"];
            GArray<double> xs = alongX["lines"];
            GArray<double> zs = alongZ["lines"];
            GDict avX = alongX["avenues"];
            GDict avZ = alongZ["avenues"];
            double x0 = xs[i.x] + _Inset(avX, i.x, cfg);
            double z0 = zs[j.x] + _Inset(avZ, j.x, cfg);
            double x1 = xs[i.y + 1] - _Inset(avX, i.y + 1, cfg);
            double z1 = zs[j.y + 1] - _Inset(avZ, j.y + 1, cfg);
            var rect = new Rect2(x0, z0, x1 - x0, z1 - z0);
            return new GDict { { "id", Gd.Str(spec["id"]) }, { "spec", spec }, { "shape", shape }, { "i", i }, { "j", j }, { "outer", outer }, { "rect", rect }, { "district", CityGen.DistrictOf(rect, cfg) } };
        }
        // True when the street from a to b would run through a site (its middle lies inside one).

        public static bool Cuts(GDict plan, Vector2 a, Vector2 b)
        {
            foreach (GDict site in Gd.Iter(plan.Get("sites", Gd.Arr())))
            {
                Rect2 outer = site["outer"];
                if (outer.Grow(-0.01).HasPoint((a + b) * 0.5))
                {
                    return true;
                }
            }
            return false;
        }
        // True when grid cell (i, j) is part of a site (it becomes the site's one block).

        public static bool Covers(GDict plan, long i, long j)
        {
            foreach (GDict site in Gd.Iter(plan.Get("sites", Gd.Arr())))
            {
                Vector2i si = site["i"];
                Vector2i sj = site["j"];
                if (i >= si.x && i <= si.y && j >= sj.x && j <= sj.y)
                {
                    return true;
                }
            }
            return false;
        }
        // Each site's block: "landmark" while it lies in the playable city or the real band the camera
        // shows past its edge (CityBand), else "outer" (a stand-in until an evolution
        // brings it near); the diagonals' plaza (CityPlaza) is "plaza", open paved ground.

        public static void AddBlocks(GDict plan, GDict cfg)
        {
            GArray<GDict> blocks = plan["blocks"];
            double half = CityGen.HalfExtent(cfg);
            GArray<GDict> sites = plan.Get("sites", ((GArray<GDict>)Gd.Arr()));
            foreach (long n in Gd.Range(sites.Size()))
            {
                Rect2 rect = sites[n]["rect"];
                double reach = Gd.Maxf(Gd.Maxf(Gd.Absf(rect.position.x), Gd.Absf(rect.end.x)), Gd.Maxf(Gd.Absf(rect.position.y), Gd.Absf(rect.end.y)));
                blocks.Append(new GDict { { "rect", rect }, { "use", _Use(sites[n], (reach < half || CityBand.Real(rect, cfg))) }, { "district", CityGen.DistrictOf(rect, cfg) }, { "site", n } });
            }
        }

        public static string _Use(GDict site, bool near)
        {
            if (Gd.Truthy(site.Get("plaza", false)))
            {
                return "plaza";
            }
            return (near ? "landmark" : "outer");
        }
        // The landmarks standing in district `ring` of the playable city, as layout entries
        // (Landmarks.building): centred on their site, with their baked chunks, tier, bonus and arcs.

        public static GArray<GDict> Entries(GDict plan, long ring)
        {
            GArray<GDict> @out = new GArray<GDict>();
            GArray<GDict> sites = plan.Get("sites", ((GArray<GDict>)Gd.Arr()));
            foreach (GDict block in Gd.Iter(plan["blocks"]))
            {
                if ((Gd.Str(block["use"]) != "landmark" || Num.I(block["district"]) != ring))
                {
                    continue;
                }
                GDict site = sites[Num.I(block["site"])];
                GDict shape = site["shape"];
                GDict spec = site["spec"];
                Rect2 rect = site["rect"];
                // a bridge stands over its water
                Vector2 at = site.Get("at", rect.GetCenter());
                @out.Append(new GDict { { "x", at.x }, { "z", at.y }, { "w", Num.I(shape["w"]) }, { "d", Num.I(shape["d"]) }, { "h", Num.I(shape["h"]) }, { "tier", Num.I(spec["tier"]) }, { "style", 0 }, { "landmark", Gd.Str(site["id"]) }, { "chunks", shape["chunks"] }, { "rubble_bonus", Num.F(spec["rubble_bonus"]) } });
                if (spec.Has("arcs"))
                {
                    @out[-1]["arcs"] = spec["arcs"];
                }
            }
            return @out;
        }
        // The run of grid cells (first, last) round v whose inside, kerb to kerb, is at least `need`
        // wide: grown one cell at a time, toward whichever side keeps v nearer the middle, never past a
        // avenue (a site that swallowed one would leave the avenue's cut ends poking into its plaza:
        // the landmark-clear audit). (-1, -1) if it cannot. axis: {lines, rings, avenues, cfg}.

        public static Vector2i _Span(GDict axis, double v, double need)
        {
            GArray<double> lines = axis["lines"];
            GDict avenues = axis["avenues"];
            GDict cfg = axis["cfg"];
            long a = _CellOf(lines, v);
            if (a < 0)
            {
                return new Vector2i(-1, -1);
            }
            long b = a;
            while (lines[b + 1] - lines[a] - _Inset(avenues, a, cfg) - _Inset(avenues, b + 1, cfg) < need)
            {
                long grow = _GrowSide(axis, v, a, b);
                if (grow == 0)
                {
                    return new Vector2i(-1, -1);
                }
                if (grow < 0)
                {
                    a -= 1;
                }
                else
                {
                    b += 1;
                }
            }
            return new Vector2i(a, b);
        }
        // The index of the grid cell holding v (the last, if lines overlap), -1 if none.

        public static long _CellOf(GArray<double> lines, double v)
        {
            long a = -1;
            foreach (long k in Gd.Range(lines.Size() - 1))
            {
                if (v >= lines[k] && v < lines[k + 1])
                {
                    a = k;
                }
            }
            return a;
        }
        // Which side the run a..b grows on: -1 low, +1 high, 0 neither (ring streets, avenues and the
        // edge stop it).

        public static long _GrowSide(GDict axis, double v, long a, long b)
        {
            GArray<double> lines = axis["lines"];
            var lowOk = a > 0 && _MaySwallow(axis, a);
            var highOk = b + 2 < lines.Size() && _MaySwallow(axis, b + 1);
            if (!lowOk && !highOk)
            {
                return 0;
            }
            if (lowOk && ((!highOk || v - lines[a] < lines[b + 1] - v)))
            {
                return -1;
            }
            return 1;
        }
        // Whether a plaza may grow past street line k: not a ring street, not an avenue.

        public static bool _MaySwallow(GDict axis, long k)
        {
            GArray<double> lines = axis["lines"];
            GArray<double> rings = axis["rings"];
            GDict avenues = axis["avenues"];
            return !_IsRing(lines[k], rings) && !avenues.Has(k);
        }

        public static bool _IsRing(double line, GArray<double> rings)
        {
            foreach (double h in rings)
            {
                if (Gd.IsEqualApprox(Gd.Absf(line), h))
                {
                    return true;
                }
            }
            return false;
        }
        // How far a plaza's edge sits in from street line k: half the street's width. A landmark's plaza
        // runs out to the kerb, taking the sidewalk in (so the stadium fits between district 1's ring
        // avenues, past the baby's play area: build 2 note 21).

        public static double _Inset(GDict avenues, long k, GDict cfg)
        {
            var kind = (avenues.Has(k) ? CityGen.AVENUE : CityGen.STREET);
            return CityGen.WidthOf(kind, cfg) * 0.5;
        }
        // True when a diagonal avenue (with its half width) passes through the rect.

        public static bool _CrossesDiagonal(GDict plan, Rect2 outer, GDict cfg)
        {
            foreach (GDict diag in Gd.Iter(plan["diagonals"]))
            {
                if (_Crosses(diag, outer, cfg))
                {
                    return true;
                }
            }
            return false;
        }

        public static bool _Crosses(GDict diag, Rect2 outer, GDict cfg)
        {
            Vector2 at = diag["at"];
            Vector2 dir = diag["dir"];
            double clear = CityGen.WidthOf(CityGen.DIAGONAL, cfg) * 0.5 + Num.F(cfg["sidewalk"]);
            double za = at.y + (outer.position.x - at.x) * dir.y / dir.x;
            double zb = at.y + (outer.end.x - at.x) * dir.y / dir.x;
            return Gd.Maxf(za, zb) + clear >= outer.position.y && Gd.Minf(za, zb) - clear <= outer.end.y;
        }

        void _InitFields()
        {
        }
        public CitySites() { _InitFields(); }
    }
}
