// Generated from sim/city_lines.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityLines : RefCounted
    {
        public static implicit operator CityLines(Variant v) => (CityLines)v.Obj;

        // The street centre lines of the city plan on one axis (part of CityGen.map, split out to keep
        // files small): across the first district, out through each later district, and on through the
        // outskirts. Pure and seeded by the caller's streams.
        //
        // Each gap is drawn at random and then fitted (CityLineFit): the nearest gap to the draw that
        // still lets the run reach its end line, never shorter than a block (so no block is cut thinner
        // than a lot, director's audit D-265), and, where the diagonal avenue crosses, placed so the
        // diagonal crosses every line mid-block: never in a grid crossing's junction box (director
        // 2026-10-26 on a 6-way crossing: "No, split them apart"). The rule for each axis comes from
        // CityLineFit.x_rule / z_rule.
        // Street centre lines across the playable city on one axis: drawn gaps, with lines exactly on
        // the ring (+-half).
        // pins: lines the run must pass through (the sea bay's, CityHarbour.pins), each a fixed end line
        // of its own; the longest stretch between them takes `rule`, the others `plain`.

        public static GArray<double> Across(RandomNumberGenerator rng, double half, GArray<long> gaps, GArray<GDict> rules, GArray<double> pins)
        {
            GArray<double> @out = new GArray<double> { -half };
            foreach (long p in Pinned(rng, Gd.Roundi(-half), Gd.Roundi(half), gaps, rules, pins))
            {
                @out.Append(Gd.Float(p));
            }
            return @out;
        }
        public static GArray<double> Across(RandomNumberGenerator rng, double half, GArray<long> gaps, GArray<GDict> rules) => Across(rng, half, gaps, rules, new GArray<double>());
        // CityLineFit.run from start to end through every pin strictly between them, each stretch fitted
        // on its own (a pin is an end line); rules: [the longest stretch's rule, the others'].

        public static GArray<long> Pinned(RandomNumberGenerator rng, long start, long end, GArray<long> gaps, GArray<GDict> rules, GArray<double> pins)
        {
            long dir = (end >= start ? 1 : -1);
            GArray<long> stops = new GArray<long>();
            foreach (double v in pins)
            {
                long p = Gd.Roundi(v);
                if ((p - start) * dir > 0 && (end - p) * dir > 0 && !Gd.In(p, stops))
                {
                    stops.Append(p);
                }
            }
            stops.Sort();
            if (dir < 0)
            {
                stops.Reverse();
            }
            stops.Append(end);
            long longest = 0;
            long most = -1;
            long from = start;
            foreach (long k in Gd.Range(stops.Size()))
            {
                if (Gd.Absi(stops[k] - from) > most)
                {
                    most = Gd.Absi(stops[k] - from);
                    longest = k;
                }
                from = stops[k];
            }
            GArray<long> @out = new GArray<long>();
            from = start;
            foreach (long k in Gd.Range(stops.Size()))
            {
                GDict rule = (k == longest ? rules[0] : rules[rules.Size() - 1]);
                @out.AppendArray(CityLineFit.Run(rng, from, stops[k], gaps, rule));
                from = stops[k];
            }
            return @out;
        }
        // A district's street lines between the ring at +-from and its own ring at +-to, both ways,
        // with the same block sizes as the city inside.

        public static void Ring(RandomNumberGenerator rng, GArray<double> lines, GArray<double> span, GArray<long> gaps, GDict rule, GArray<double> pins)
        {
            foreach (long side in Gd.Arr(1, -1))
            {
                long from = Gd.Roundi(span[0]) * side;
                foreach (long p in Pinned(rng, from, Gd.Roundi(span[1]) * side, gaps, new GArray<GDict> { rule }, pins))
                {
                    _Add(lines, Gd.Float(p));
                }
            }
        }
        public static void Ring(RandomNumberGenerator rng, GArray<double> lines, GArray<double> span, GArray<long> gaps, GDict rule) => Ring(rng, lines, span, gaps, rule, new GArray<double>());

        public static void _Add(GArray<double> lines, double v)
        {
            if (v > lines[lines.Size() - 1])
            {
                lines.Append(v);
            }
            else
            {
                lines.PushFront(v);
            }
        }
        // Carries the lines on out to +-outer, both ways (no end line: the first past +-outer ends it).

        public static void Extend(RandomNumberGenerator rng, GArray<double> lines, double outer, GArray<long> gaps, GDict rule)
        {
            GDict open = rule.Duplicate();
            open["open"] = true;
            foreach (long p in CityLineFit.Run(rng, Gd.Roundi(lines[-1]), Gd.Ceili(outer), gaps, open))
            {
                lines.Append(Gd.Float(p));
            }
            foreach (long p in CityLineFit.Run(rng, Gd.Roundi(lines[0]), -Gd.Ceili(outer), gaps, open))
            {
                lines.PushFront(Gd.Float(p));
            }
        }
        // The street lines' gap bounds [lo, hi], m: long blocks one way, short the other (Manhattan):
        // x-lines far apart, z-lines close; the outskirts' ("far_": city "block_far", m added to each
        // bound) vary far more, so they are no even grid, but none is cut thinner than a lot between two
        // avenues.

        public static GDict Gaps(GDict cfg)
        {
            GArray<Variant> @long = cfg["block_long"];
            GArray<Variant> @short = cfg["block_short"];
            long thin = Gd.Roundi(CityGen.WidthOf(CityGen.AVENUE, cfg) + 2.0 * Num.F(cfg["sidewalk"]) + CityGen.MIN_LOT_M);
            GDict @out = new GDict { { "long", ((GArray<long>)Gd.Arr(Num.I(@long[0]), Num.I(@long[1]))) }, { "short", ((GArray<long>)Gd.Arr(Num.I(@short[0]), Num.I(@short[1]))) } };
            GDict far = cfg["block_far"];
            GArray<Variant> farLong = far["long"];
            GArray<Variant> farShort = far["short"];
            @out["far_long"] = (((GArray<long>)Gd.Arr(Gd.Maxi(Num.I(@long[0]) + Num.I(farLong[0]), thin), Num.I(@long[1]) + Num.I(farLong[1]))));
            @out["far_short"] = (((GArray<long>)Gd.Arr(Gd.Maxi(Num.I(@short[0]) + Num.I(farShort[0]), thin), Num.I(@short[1]) + Num.I(farShort[1]))));
            return @out;
        }
        // Which x-line may be the inner avenue: one CityLineFit.avenue_fits_x allows, at least tuning city
        // "avenue_spawn_clear" off x = 0: that avenue carries the viaduct (Rail), and the kaiju sets off
        // from (0, half) on the south ring, so a viaduct closer holds up its first steps. Never a sea bay's
        // side street (`bay_x`): its quay deck would jut into an avenue's asphalt.

        public static Callable _XFits(GDict xRule, GArray<double> xs, GDict cfg, GArray<double> bayX)
        {
            double keep = Num.F(cfg["avenue_spawn_clear"]);
            return new Callable(a_ =>
            {
                long i = a_[0];
                return (Gd.Absf(xs[i]) >= keep && !Gd.In(xs[i], bayX) && CityLineFit.AvenueFitsX(xRule, xs, i));
            });
        }
        // Every district's ring lines and one or two lines through the first district are avenues; an
        // inner avenue is a line `fits` allows (the diagonal crosses it clear of the grid at an
        // avenue's width, CityLineFit), when there is one.

        public static GDict Avenues(RandomNumberGenerator rng, GArray<double> lines, GArray<double> rings, Callable fits, GDict cfg)
        {
            GDict @out = new GDict();
            GArray<long> inner = new GArray<long>();
            GArray<long> clear = new GArray<long>();
            foreach (long i in Gd.Range(lines.Size()))
            {
                var ring = false;
                foreach (double h in rings)
                {
                    ring = (ring || Gd.IsEqualApprox(Gd.Absf(lines[i]), h));
                }
                if (ring)
                {
                    @out[i] = true;
                }
                else if (Gd.Absf(lines[i]) < rings[0])
                {
                    inner.Append(i);
                    if (Gd.Truthy(fits.Call(i)))
                    {
                        clear.Append(i);
                    }
                }
            }
            if (!clear.IsEmpty())
            {
                inner = clear;
            }
            foreach (long n in Gd.Range(Gd.Mini(Num.I(cfg["avenues"]), inner.Size())))
            {
                long pick = inner[rng.RandiRange(0, inner.Size() - 1)];
                inner.Erase(pick);
                @out[pick] = true;
            }
            return @out;
        }
        // Every street line of the plan and its avenues: {xs, zs, avenues_x, avenues_z} (line indices),
        // and "breaks": the rules the fitted runs break (CityLineFit's fewest-breaks fallback; 0 when
        // every run fits clean).
        // rng: the plan's own stream (the first district's lines and the avenue picks); later districts
        // and the outskirts draw from their own (map_seed + 2, + 1).
        // diags: CityDiagonals.of(cfg). No inner avenue runs through the plaza where they meet
        // (CityPlaza), whose ground swallows the streets inside it.

        public static GDict Draw(RandomNumberGenerator rng, GDict cfg, GArray<GDict> diags)
        {
            var rings = CityGen.Districts(cfg);
            double outer = Num.F(cfg["outer_half"]);
            GDict xRule = CityLineFit.XRule(cfg, diags, rings);
            Vector2 meet = diags[0]["at"];
            GDict gaps = Gaps(cfg);
            // The x-lines come first: the z-lines then sit between the diagonal's crossings with them
            // (CityLineFit).
            var streams = _Streams(rng, cfg);
            GDict report = new GDict { { "breaks", 0 } };
            // the sea bay's own street lines, laid first
            GDict bay = CityHarbour.Pins(cfg);
            GArray<double> bayX = bay["x"];
            GArray<double> bayZ = bay["z"];
            xRule["report"] = report;
            GDict innerRule = xRule.Duplicate();
            // room for the inner avenue (CityLineFit)
            innerRule["avenue"] = true;
            var xs = _Lay(streams, rings, outer, Gd.Arr(gaps["long"], gaps["far_long"]), new GArray<GDict> { innerRule, xRule }, bayX);
            var xClear = _XFits(xRule, xs, cfg, bayX);
            var xFits = new Callable(a_ =>
            {
                long i = a_[0];
                return Gd.Truthy(xClear.Call(i)) && !CityPlaza.Swallows(xs, i, meet.x, cfg);
            });
            GDict avenuesX = Avenues(rng, xs, rings, xFits, cfg);
            GArray<double> avenueAt = new GArray<double>();
            avenueAt.Assign(avenuesX.Keys().Map(new Callable(a_ =>
            {
                long i = a_[0];
                return xs[i];
            })));
            GDict zRule = CityLineFit.ZRule(cfg, diags, xs, rings, avenueAt);
            zRule["report"] = report;
            var zs = _Lay(streams, rings, outer, Gd.Arr(gaps["short"], gaps["far_short"]), new GArray<GDict> { zRule, zRule }, bayZ);
            double need = (CityGen.WidthOf(CityGen.DIAGONAL, cfg) * 0.5 + CityGen.WidthOf(CityGen.AVENUE, cfg) * 0.5);
            var zFits = new Callable(a_ =>
            {
                long j = a_[0];
                return (CityLineFit.Clearance(diags, "z", zs[j], xs) >= need && !CityPlaza.Swallows(zs, j, meet.y, cfg));
            });
            GDict avenuesZ = Avenues(rng, zs, rings, zFits, cfg);
            return new GDict { { "xs", xs }, { "zs", zs }, { "avenues_x", avenuesX }, { "avenues_z", avenuesZ }, { "breaks", Num.I(report["breaks"]) } };
        }
        // The plan's streams: its own, then each later district's streets (out to its own ring avenue)
        // and the outskirts' from their own, so tuning them never reshuffles the city.

        public static GArray<RandomNumberGenerator> _Streams(RandomNumberGenerator rng, GDict cfg)
        {
            var grow = new RandomNumberGenerator();
            grow.seed = Num.I(cfg["map_seed"]) + 2;
            var far = new RandomNumberGenerator();
            far.seed = Num.I(cfg["map_seed"]) + 1;
            return new GArray<RandomNumberGenerator> { rng, grow, far };
        }
        // One axis's lines: across the first district from streams[0] (rules[0], the first district's
        // rule, on its longest stretch), out through each later district from streams[1] and on through
        // the outskirts to +-`outer` from streams[2] (rules[1]), through every pin inside the last
        // district. bounds: [gaps, far gaps] (gaps).

        public static GArray<double> _Lay(GArray<RandomNumberGenerator> streams, GArray<double> rings, double outer, GArray<Variant> bounds, GArray<GDict> rules, GArray<double> pins)
        {
            GArray<long> near = bounds[0];
            GArray<long> far = bounds[1];
            GDict rule = rules[1];
            var @out = Across(streams[0], rings[0], near, rules, pins);
            foreach (long k in Gd.Range(1, rings.Size()))
            {
                Ring(streams[1], @out, ((GArray<double>)Gd.Arr(rings[k - 1], rings[k])), near, rule, pins);
            }
            Extend(streams[2], @out, outer, far, rule);
            return @out;
        }
        // The rules the plan of `cfg` breaks to fit its street lines (draw's "breaks"; CityLineFit's
        // fewest-breaks fallback): 0 when the diagonal and the rings let every run fit clean.

        public static long FitBreaks(GDict cfg)
        {
            var rng = new RandomNumberGenerator();
            // CityGen.map's own stream
            rng.seed = Num.I(cfg["map_seed"]);
            return Num.I(Draw(rng, cfg, CityDiagonals.Of(cfg))["breaks"]);
        }

        void _InitFields()
        {
        }
        public CityLines() { _InitFields(); }
    }
}
