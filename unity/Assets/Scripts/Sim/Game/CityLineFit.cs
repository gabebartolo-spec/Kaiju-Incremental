// Generated from sim/city_line_fit.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityLineFit : RefCounted
    {
        public static implicit operator CityLineFit(Variant v) => (CityLineFit)v.Obj;

        // Fits one run of street lines (CityLines) between two lines, on whole metres: each gap is drawn
        // from the caller's stream as before, then the gap nearest the draw is taken that still lets the
        // run end on its end line, never under `lo` (the narrowest block a lot fits in) and never so
        // that the diagonal avenue meets the grid in an overlapping junction (director 2026-10-26 on a
        // 6-way crossing: "No, split them apart"; the city audit's "close!" rule, D-265).
        //
        // The diagonal (z = c at an x-line) and the grid meet cleanly when, on every x-line, its
        // crossing c lies at least s from every z-line: s = half the diagonal's width plus half the
        // widest street of the grid crossing (street or avenue). So:
        // - x_rule: an x-line's c keeps s_avenue off the fixed ring z-lines, and two x-lines' c values lie
        // far enough apart for a z-line to sit between them (s each side, plus a metre for whole
        // metres): the x blocks along the diagonal draw a little longer;
        // - z_rule: a z-line keeps s off every x-line's c (one z-line sits between each two crossings).
        // A run with no clean fit breaks as few of these rules as it can.
        // Pure: the same stream, ends and rule give the same lines.
        // an unreachable run's cost
        public const long BIG = (1L << (int)(20));
        // lines sit on whole metres; a z-line needs a window this wide between crossings
        public const double STEP = 1.0;
        // The lines after `start` up to `end` (included), or for rule["open"] up to the first one
        // at or past `end`. gaps: [lo, hi] drawn; a fitted gap may run to max(hi, 2 lo - 1), the widest
        // gap that cannot hold two blocks; where no run fits clean within that, up to lo more (an
        // outskirts x-line pair can leave the diagonal's crossings too far apart for short blocks to
        // thread). Where no run meets every rule, the one that breaks the fewest is taken (each line in
        // a barred place or gap counts one). With rule["avenue"] the run also leaves at least one line
        // an avenue fits on (avenue_fits_x), for CityGen's inner avenue.
        // With rule["report"] (a Dictionary) the rules the run breaks are added to its "breaks".

        public static GArray<long> Run(RandomNumberGenerator rng, long start, long end, GArray<long> gaps, GDict rule)
        {
            long lo = gaps[0];
            long hi = gaps[1];
            long cap = Gd.Maxi(hi, 2 * lo - 1);
            GArray<Variant> runAt = Gd.Arr(start, (end >= start ? 1 : -1), Gd.Absi(end - start));
            long length = runAt[2];
            long states = (Gd.Truthy(rule.Get("avenue", false)) ? 3 : 1);
            var cost = _Costs(runAt, new GArray<long> { lo, cap }, rule, states);
            // no clean run: let one gap stretch a block further before breaking a rule
            if (cost[0] > 0)
            {
                var wide = _Costs(runAt, new GArray<long> { lo, cap + lo }, rule, states);
                if (wide[0] < cost[0])
                {
                    cap += lo;
                    cost = wide;
                }
            }
            // the fewest-breaks fallback taken (CityLines.draw: plan "fit_breaks")
            if (rule.Has("report"))
            {
                GDict report = rule["report"];
                report["breaks"] = Num.I(report["breaks"]) + ((cost[0] < BIG ? cost[0] : 1));
            }
            GArray<long> @out = new GArray<long>();
            long d = 0;
            long st = 0;
            bool open = rule.Get("open", false);
            while ((open ? (d < length) : (d != length)))
            {
                long draw = rng.RandiRange(lo, hi);
                long best = -1;
                foreach (long g in Gd.Range(lo, cap + 1))
                {
                    long e = d + g;
                    if (e * states >= cost.Size())
                    {
                        continue;
                    }
                    long then = cost[e * states + _Next(runAt, d, e, st, rule)];
                    if ((then >= BIG || then + _StepCost(runAt, d, e, rule) != cost[d * states + st]))
                    {
                        // off the cheapest run
                        continue;
                    }
                    if ((best < 0 || Gd.Absi(g - draw) < Gd.Absi(best - draw)))
                    {
                        best = g;
                    }
                }
                // no run at all (a run shorter than lo): one gap to the end
                if (best < 0)
                {
                    best = (!open ? length - d : draw);
                }
                st = (states > 1 ? _Next(runAt, d, d + best, st, rule) : 0);
                d += best;
                @out.Append(start + Num.I(runAt[1]) * d);
            }
            return @out;
        }
        // cost[d * states + st]: the fewest broken rules from a line at start + dir d, in avenue state
        // st, to the end (BIG: unreachable). run_at: [start, dir, length].

        public static PackedInt32Array _Costs(GArray<Variant> runAt, GArray<long> gaps, GDict rule, long states)
        {
            long length = runAt[2];
            bool open = rule.Get("open", false);
            long size = length + ((open ? gaps[1] : 0)) + 1;
            var cost = new PackedInt32Array();
            cost.Resize(size * states);
            cost.Fill(BIG);
            foreach (long d in Gd.Range(size - 1, -1, -1))
            {
                foreach (long st in Gd.Range(states))
                {
                    if ((open ? (d >= length) : (d == length)))
                    {
                        // no avenue line: one broken
                        cost[d * states + st] = (st == states - 1 ? 0 : 1);
                        continue;
                    }
                    long best = BIG;
                    foreach (long g in Gd.Range(gaps[0], gaps[1] + 1))
                    {
                        long e = d + g;
                        if (e >= size)
                        {
                            break;
                        }
                        long then = cost[e * states + ((states > 1 ? _Next(runAt, d, e, st, rule) : 0))];
                        if (then < BIG)
                        {
                            best = Gd.Mini(best, then + _StepCost(runAt, d, e, rule));
                        }
                    }
                    cost[d * states + st] = best;
                }
            }
            return cost;
        }
        // The avenue state after a line at e (the previous at d): 0 none yet, 1 the line at d has room
        // for an avenue on its near side, 2 a line with room both sides is laid.

        public static long _Next(GArray<Variant> runAt, long d, long e, long st, GDict rule)
        {
            if ((st == 2 || !(Gd.Truthy(rule.Get("avenue", false)))))
            {
                return st;
            }
            double a = _At(runAt, d);
            double b = _At(runAt, e);
            double gap = Gd.INF;
            foreach (GDict diag in Gd.Iter(rule["diags"]))
            {
                gap = Gd.Minf(gap, Gd.Absf(Crossing(diag, b) - Crossing(diag, a)));
            }
            double avenue = Num.F(rule["s_avenue"]);
            if (st == 1 && gap >= avenue + _SOf(b, rule) + STEP)
            {
                return 2;
            }
            var inner = e != Num.I(runAt[2]);
            return (inner && gap >= avenue + _SOf(a, rule) + STEP ? 1 : 0);
        }

        public static double _At(GArray<Variant> runAt, long d)
        {
            return Gd.Float(Num.I(runAt[0]) + Num.I(runAt[1]) * d);
        }
        // What a gap from d to e breaks: the line at e in a barred place (a fixed end line never
        // counts), and the gap itself.

        public static long _StepCost(GArray<Variant> runAt, long d, long e, GDict rule)
        {
            long n = (_GapOk(_At(runAt, d), _At(runAt, e), rule) ? 0 : 1);
            bool @fixed = e == Num.I(runAt[2]) && !(Gd.Truthy(rule.Get("open", false)));
            if (!@fixed && !(_PosOk(Gd.Roundi(_At(runAt, e)), rule)))
            {
                n += 1;
            }
            return n;
        }

        public static bool _PosOk(long p, GDict rule)
        {
            if (Gd.Str(rule.Get("axis", "")) == "z")
            {
                GDict bad = rule["bad"];
                return !bad.Has(p);
            }
            if (Gd.Str(rule.Get("axis", "")) == "x")
            {
                foreach (GDict diag in Gd.Iter(rule["diags"]))
                {
                    double c = Crossing(diag, Gd.Float(p));
                    foreach (double z in Gd.Iter(rule["fixed_z"]))
                    {
                        if (Gd.Absf(c - z) < Num.F(rule["s_avenue"]))
                        {
                            return false;
                        }
                    }
                }
            }
            return true;
        }

        public static bool _GapOk(double a, double b, GDict rule)
        {
            if (Gd.Str(rule.Get("axis", "")) != "x")
            {
                return true;
            }
            foreach (GDict diag in Gd.Iter(rule["diags"]))
            {
                if (!_GapOkFor(a, b, diag, rule))
                {
                    return false;
                }
            }
            return true;
        }
        // _gap_ok for one diagonal.

        public static bool _GapOkFor(double a, double b, GDict diag, GDict rule)
        {
            double need = _SOf(a, rule) + _SOf(b, rule) + STEP;
            double ca = Crossing(diag, a);
            double cb = Crossing(diag, b);
            if (Gd.Absf(cb - ca) < need)
            {
                return false;
            }
            // A ring or pinned z-line between the two crossings is a z-line fixed in place: the z-lines
            // either side of it must still reach it in one gap (z_cap), so neither crossing lies too far
            // from it.
            double cap = Num.F(rule["z_cap"]);
            foreach (double r in Gd.Iter(rule["fixed_z"]))
            {
                if ((r - ca) * (r - cb) < 0.0)
                {
                    if ((Gd.Absf(r - ca) > cap - _SOf(a, rule) || Gd.Absf(r - cb) > cap - _SOf(b, rule)))
                    {
                        return false;
                    }
                }
            }
            return true;
        }
        // Clearance an x-line at x needs from the z-lines: an avenue's (the rings, and any listed in
        // rule["avenue_x"]) or a street's.

        public static double _SOf(double x, GDict rule)
        {
            foreach (double r in Gd.Iter(rule["ring_z"]))
            {
                if (Gd.IsEqualApprox(Gd.Absf(x), Gd.Absf(r)))
                {
                    return Num.F(rule["s_avenue"]);
                }
            }
            if (Gd.In(x, rule.Get("avenue_x", Gd.Arr())))
            {
                return Num.F(rule["s_avenue"]);
            }
            return Num.F(rule["s_street"]);
        }
        // The grid cells whose street piece a diagonal would cross sharper than
        // city.diagonal_min_cross_deg (director 2026-11-01, Carthago's 13 deg spokes: "Drop sharp street
        // bits"), into plan: sharp_x {Vector2i(x-line i, cell j): true}, sharp_z {Vector2i(z-line j,
        // cell i): true}, keyed as CityAlleys' edges. CityGen leaves those pieces out, no node on them.
        // Such a steep diagonal's crossings of the other axis beside a grid junction count as sharp too.

        public static void SharpCells(GDict plan, GArray<GDict> diags, GArray<double> xs, GArray<double> zs, double outer, GDict cfg)
        {
            double least = Gd.DegToRad(Num.F(cfg["diagonal_min_cross_deg"]));
            GArray<Variant> @short = cfg["block_short"];
            double near = Gd.Maxf(_Clearances(cfg)[1], Num.F(@short[0]));
            GDict sx = new GDict();
            GDict sz = new GDict();
            foreach (GDict diag in diags)
            {
                Vector2 dir = diag["dir"];
                // near the x-lines' own run
                var alongZ = Gd.Atan2(Gd.Absf(dir.x), Gd.Absf(dir.y)) < least;
                // near the z-lines' run
                var alongX = Gd.Atan2(Gd.Absf(dir.y), Gd.Absf(dir.x)) < least;
                foreach (long i in Gd.Range(xs.Size()))
                {
                    double z = CityDiagonals.AtX(diag, xs[i]);
                    if (Gd.Absf(z) <= outer && ((alongZ || (alongX && _Beside(z, zs, near)))))
                    {
                        sx[new Vector2i(i, CityGen.CellOf(zs, z))] = true;
                    }
                }
                foreach (long j in Gd.Range(zs.Size()))
                {
                    double x = CityDiagonals.AtZ(diag, zs[j]);
                    if (Gd.Absf(x) <= outer && ((alongX || (alongZ && _Beside(x, xs, near)))))
                    {
                        sz[new Vector2i(j, CityGen.CellOf(xs, x))] = true;
                    }
                }
            }
            plan["sharp_x"] = sx;
            plan["sharp_z"] = sz;
        }
        // Is v off every one of `lines` but within `near` (an avenue's clearance, or the shortest block
        // when that is wider: the road rule's "close") of one? A steep diagonal drifts too slowly across
        // the other axis for the line fit to keep its crossings off the grid junctions (13 deg: 3.5 m a
        // 15 m block), so such a crossing's piece is left out as well.

        public static bool _Beside(double v, GArray<double> lines, double near)
        {
            foreach (double line in lines)
            {
                if (Gd.Absf(v - line) < near)
                {
                    return v != line;
                }
            }
            return false;
        }
        // The diagonal's z where it crosses the x-line at x.

        public static double Crossing(GDict diag, double x)
        {
            Vector2 at = diag["at"];
            Vector2 dir = diag["dir"];
            return at.y + (x - at.x) * dir.y / dir.x;
        }
        // The x-lines' rule: rings are the district ring lines (both axes share them); fixed_z those and
        // the sea bay's pinned z-lines (CityHarbour.pins: the back street), which no fitted z-line can
        // dodge the diagonal for, so the x-lines keep its crossings an avenue's clearance off them; z_cap
        // the widest z gap CityLines fits (the z-lines' own max(hi, 2 lo - 1)).

        public static GDict XRule(GDict cfg, GArray<GDict> diags, GArray<double> rings)
        {
            GArray<double> ringZ = new GArray<double>();
            foreach (double r in rings)
            {
                ringZ.Append(r);
                ringZ.Append(-r);
            }
            var fixedZ = ringZ.Duplicate();
            GArray<double> pinned = CityHarbour.Pins(cfg)["z"];
            fixedZ.AppendArray(pinned);
            var s = _Clearances(cfg);
            GArray<Variant> @short = cfg["block_short"];
            long zCap = Gd.Maxi(Num.I(@short[1]), 2 * Num.I(@short[0]) - 1);
            return new GDict { { "axis", "x" }, { "diags", diags }, { "ring_z", ringZ }, { "fixed_z", fixedZ }, { "s_street", s[0] }, { "s_avenue", s[1] }, { "z_cap", Gd.Float(zCap) } };
        }
        // Whether x-line i may be an avenue: each diagonal's crossings either side leave a z-line room
        // at an avenue's clearance on its side.

        public static bool AvenueFitsX(GDict rule, GArray<double> xs, long i)
        {
            foreach (GDict diag in Gd.Iter(rule["diags"]))
            {
                double c = Crossing(diag, xs[i]);
                foreach (long k in Gd.Arr(i - 1, i + 1))
                {
                    if ((k < 0 || k >= xs.Size()))
                    {
                        continue;
                    }
                    double need = Num.F(rule["s_avenue"]) + _SOf(xs[k], rule) + STEP;
                    if (Gd.Absf(Crossing(diag, xs[k]) - c) < need)
                    {
                        return false;
                    }
                }
            }
            return true;
        }
        // The z-lines' rule: every whole metre within s of an x-line's crossing with any diagonal is
        // barred.

        public static GDict ZRule(GDict cfg, GArray<GDict> diags, GArray<double> xs, GArray<double> rings, GArray<Variant> avenueX)
        {
            var s = _Clearances(cfg);
            GDict xRules = XRule(cfg, diags, rings);
            xRules["avenue_x"] = avenueX;
            GDict bad = new GDict();
            foreach (GDict diag in diags)
            {
                foreach (double x in xs)
                {
                    double c = Crossing(diag, x);
                    double need = _SOf(x, xRules);
                    foreach (long z in Gd.Range(Gd.Ceili(c - need), Gd.Floori(c + need) + 1))
                    {
                        if (Gd.Absf(z - c) < need)
                        {
                            bad[z] = true;
                        }
                    }
                }
            }
            return new GDict { { "axis", "z" }, { "bad", bad }, { "s_street", s[0] }, { "s_avenue", s[1] } };
        }
        // [street, avenue]: how far a grid crossing of a street (avenue) must stay from the diagonal's
        // crossing on the same line for their junction boxes not to overlap.

        public static GArray<double> _Clearances(GDict cfg)
        {
            double diag = CityGen.WidthOf(CityGen.DIAGONAL, cfg) * 0.5;
            return new GArray<double> { diag + CityGen.WidthOf(CityGen.STREET, cfg) * 0.5, diag + CityGen.WidthOf(CityGen.AVENUE, cfg) * 0.5 };
        }
        // How far line `v` on `axis` keeps from the nearest crossing of any diagonal with the other axis
        // (INF with none): an avenue needs _clearances()[1].

        public static double Clearance(GArray<GDict> diags, string axis, double v, GArray<double> others)
        {
            double @out = Gd.INF;
            foreach (GDict diag in diags)
            {
                foreach (double o in others)
                {
                    double c = Crossing(diag, (axis == "z" ? o : v));
                    @out = Gd.Minf(@out, Gd.Absf(((axis == "z" ? v : o)) - c));
                }
            }
            return @out;
        }
        // Whether the x-lines of cfg's plan can meet every rule whatever the seed (the runs between the
        // fixed ring lines and out to the outskirts; the z-lines then always fit between the diagonal's
        // crossings): the check tools/audit/diagonal_fit.gd uses to pick city.diagonal_through and
        // city.diagonal_deg. diags: CityDiagonals.of(cfg), or a candidate's.

        public static bool XRunsFit(GDict cfg, GArray<GDict> diags)
        {
            var rings = CityGen.Districts(cfg);
            GDict rule = XRule(cfg, diags, rings);
            foreach (double r in rings)
            {
                if ((!(_PosOk(Gd.Roundi(r), rule)) || !(_PosOk(-Gd.Roundi(r), rule))))
                {
                    return false;
                }
            }
            GDict gaps = CityLines.Gaps(cfg);
            GArray<long> @long = gaps["long"];
            long cap = Gd.Maxi(@long[1], 2 * @long[0] - 1);
            GDict inner = rule.Duplicate();
            inner["avenue"] = true;
            long r0 = Gd.Roundi(rings[0]);
            if (_Costs(Gd.Arr(-r0, 1, 2 * r0), new GArray<long> { @long[0], cap }, inner, 3)[0] != 0)
            {
                return false;
            }
            foreach (long k in Gd.Range(1, rings.Size()))
            {
                long from = Gd.Roundi(rings[k - 1]);
                foreach (long side in Gd.Arr(1, -1))
                {
                    GArray<Variant> runAt = Gd.Arr(from * side, side, Gd.Roundi(rings[k]) - from);
                    if (_Costs(runAt, new GArray<long> { @long[0], cap }, rule, 1)[0] != 0)
                    {
                        return false;
                    }
                }
            }
            GArray<long> far = gaps["far_long"];
            GDict open = rule.Duplicate();
            open["open"] = true;
            long full = Gd.Roundi(rings[-1]);
            long outer = Gd.Ceili(Num.F(cfg["outer_half"]));
            foreach (long side in Gd.Arr(1, -1))
            {
                GArray<Variant> runAt = Gd.Arr(full * side, side, outer - full);
                if (_Costs(runAt, new GArray<long> { far[0], Gd.Maxi(far[1], 2 * far[0] - 1) }, open, 1)[0] != 0)
                {
                    return false;
                }
            }
            return true;
        }

        void _InitFields()
        {
        }
        public CityLineFit() { _InitFields(); }
    }
}
