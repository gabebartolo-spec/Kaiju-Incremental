// Generated from sim/city_gen.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityGen : RefCounted
    {
        public static implicit operator CityGen(Variant v) => (CityGen)v.Obj;

        // Seeded city layout, in two steps.
        //
        // The city grows with each evolution (D-039): cfg.districts = nested district half-extents,
        // cfg.half = the one in play. The plan always spans every district, so an evolution only turns
        // more of the same city playable; the districts still to come stand past the edge.
        //
        // map(cfg): the street plan, fixed by the city config alone (its own map_seed), so presentation
        // (streets, traffic, the outskirts) can rebuild it without the run's seed. Streets run at
        // irregular spacing with a ring avenue on the playable edge, a couple of avenues, alleys that
        // split some blocks, and one diagonal avenue cutting across. Blocks between them are built up,
        // a park, a plaza or a parking lot. Past the edge, blocks as far as the camera shows are built
        // up too (real, destroyable, out of the kaiju's walk); beyond them "outer" (drawn stand-ins).
        //
        // generate(rng, cfg): the buildings of the playable blocks (CityLots fills each block). Each
        // building is its own Structure, so neighbours touch but fall separately. Its tier (from
        // height) decides how tough it is.
        public const string AVENUE = "avenue";
        public const string STREET = "street";
        public const string ALLEY = "alley";
        public const string DIAGONAL = "diagonal";
        // plans kept (a stage's city, the title's, the overworld's)
        public const long MAPS_KEPT = 4;
        // CityLots' narrowest lot side: no block is cut thinner
        public const double MIN_LOT_M = 2.0;
        // The last few plans built, [cfg, plan] each: a plan takes 0.3 s and a rampage asked for it
        // 14 times (the sim's water, rail, roads, the views' ground, decor, traffic ...).
        public static GArray<GArray<Variant>> _made = new GArray<GArray<Variant>>();
        // The buildings of the playable city, one dictionary each: x, z (centre), w, d, h, tier, style
        // (CityPool's add a model).
        // Blocks fill district by district, innermost first, so a district's lots draw the same
        // numbers whichever stage is in play (only the stage's height caps change them). The river's
        // blocks (CityRiver) still draw their lots and drop them, so every other building stays put;
        // its quay sheds come last, from their own numbers, in place of the lots by the bank.

        public static GArray<GDict> Generate(RandomNumberGenerator rng, GDict cfg)
        {
            GDict plan = Map(cfg);
            GArray<GDict> @out = new GArray<GDict>();
            // the built blocks by the start bank (CityRiver.on_quay)
            GArray<GDict> quay = new GArray<GDict>();
            // each block cuts its lots from its own seed (_block_rng)
            long citySeed = rng.seed;
            // + 1: the real blocks past the last district
            foreach (long ring in Gd.Range(Districts(cfg).Size() + 1))
            {
                foreach (GDict block in Gd.Iter(plan["blocks"]))
                {
                    if (Gd.Str(block.Get("was", block["use"])) == "built" && Num.I(block["district"]) == ring)
                    {
                        var lots = CityLots.FillBlock(_BlockRng(citySeed, block), plan, block, cfg, 1.0);
                        if (Gd.Str(block["use"]) == "built")
                        {
                            if (CityRiver.OnQuay(plan, block, cfg))
                            {
                                quay.Append(block);
                                lots = CityRiver.OffQuay(plan, lots, cfg);
                            }
                            @out.AppendArray(lots);
                        }
                    }
                }
                @out.AppendArray(CitySites.Entries(plan, ring));
            }
            // lots take the pool's models (D-256), on their own stream
            CityPool.Place(@out, rng, cfg, plan);
            // the port's fixed cranes, stacks, sheds
            @out.AppendArray(CityPort.Entries(plan, cfg));
            // + red barrels (#19)
            CityHazards.Tag(@out, plan, cfg, CityRiver.Sheds(plan, quay, @out, cfg));
            return @out;
        }
        // A block's own lot numbers, from the city's seed and where the block lies: the bay drops
        // different streets at each stage (CityHarbour.inside), so a shared draw in block order would
        // re-cut every block after the first difference; this way a block of the young city cuts the
        // same lots at every stage.

        public static RandomNumberGenerator _BlockRng(long citySeed, GDict block)
        {
            Rect2 rect = block["rect"];
            var @out = new RandomNumberGenerator();
            @out.seed = Gd.Hash(Gd.Arr(citySeed, Gd.Snappedf(rect.position.x, 0.01), Gd.Snappedf(rect.position.y, 0.01)));
            return @out;
        }
        // Half-extents of the nested districts, smallest first (just [half] for a one-district city).

        public static GArray<double> Districts(GDict cfg)
        {
            GArray<double> @out = new GArray<double>();
            GArray<Variant> raw = cfg.Get("districts", Gd.Arr(cfg["half"]));
            foreach (Variant h in raw)
            {
                @out.Append(Num.F(h));
            }
            return @out;
        }
        // The district a rect lies in by its furthest edge (0 innermost; past the last: size()).

        public static long DistrictOf(Rect2 rect, GDict cfg)
        {
            double edge = Gd.Maxf(Gd.Maxf(Gd.Absf(rect.position.x), Gd.Absf(rect.end.x)), Gd.Maxf(Gd.Absf(rect.position.y), Gd.Absf(rect.end.y)));
            var rings = Districts(cfg);
            foreach (long k in Gd.Range(rings.Size()))
            {
                if (edge < rings[k])
                {
                    return k;
                }
            }
            return rings.Size();
        }

        public static long TierForHeight(long height, GDict cfg)
        {
            double step = Num.F(cfg["tier_height"]);
            return Gd.Clampi(1 + Num.I(Gd.Floor(Num.F(height - 1) / step)), 1, 4);
        }
        // Half the playable city's side: the centre line of the ring avenue round it.

        public static double HalfExtent(GDict cfg)
        {
            return Num.F(cfg["half"]);
        }
        // The tower districts (a midtown and a downtown): x, z, radius each.

        public static GArray<Vector3> Cores(GDict cfg)
        {
            GArray<Vector3> @out = new GArray<Vector3>();
            foreach (GArray<Variant> at in Gd.Iter(cfg["cores"]))
            {
                @out.Append(new Vector3(Num.F(at[0]), Num.F(at[1]), Num.F(at[2])));
            }
            return @out;
        }
        // The street plan: nodes (crossings), streets between them, blocks between the streets. The same
        // cfg always makes the same plan, so it is built once and each caller gets its own copy.

        public static GDict Map(GDict cfg)
        {
            foreach (GArray<Variant> made in _made)
            {
                if (made[0] == cfg)
                {
                    GDict plan = made[1];
                    return plan.Duplicate(true);
                }
            }
            GDict plan2 = _Map(cfg);
            _made.PushFront(Gd.Arr(cfg.Duplicate(true), plan2.Duplicate(true)));
            if (_made.Size() > MAPS_KEPT)
            {
                _made.PopBack();
            }
            return plan2;
        }

        public static GDict _Map(GDict cfg)
        {
            var rng = new RandomNumberGenerator();
            rng.seed = Num.I(cfg["map_seed"]);
            var rings = Districts(cfg);
            double full = rings[rings.Size() - 1];
            double outer = Num.F(cfg["outer_half"]);
            var diags = CityDiagonals.Of(cfg);
            GDict lines = CityLines.Draw(rng, cfg, diags);
            GArray<double> xs = lines["xs"];
            GArray<double> zs = lines["zs"];
            GDict avenuesX = lines["avenues_x"];
            GDict avenuesZ = lines["avenues_z"];
            GDict plan = _EmptyPlan(cfg, diags, xs, zs);
            // Thule's fjord: no street but its bridges crosses it
            CityWater.Dig(plan, cfg);
            plan["sites"] = CitySites.Find(plan, rings, Gd.Arr(avenuesX, avenuesZ), cfg);
            // where two diagonals meet: no street inside
            CityPlaza.Add(plan, Gd.Arr(avenuesX, avenuesZ), cfg);
            CityLineFit.SharpCells(plan, diags, xs, zs, outer, cfg);
            // Which grid edges are alleys (CityAlleys): x-line i between zs[j] and zs[j+1] is
            // alley_x[Vector2i(i, j)].
            GDict alleys = CityAlleys.Lay(rng, plan, Gd.Arr(avenuesX, avenuesZ), cfg);
            GDict alleyX = alleys["x"];
            GDict alleyZ = alleys["z"];
            GDict index = new GDict();
            _LayStreets(plan, index, lines, Gd.Arr(alleyX, alleyZ), cfg);
            foreach (GDict d in diags)
            {
                _LayDiagonal(plan, index, d, xs, zs, outer, cfg);
            }
            // Carthago's harbour ring and spokes
            CityWater.Lay(plan, index, cfg);
            _Blocks(plan, xs, zs, avenuesX, avenuesZ, alleyX, alleyZ, rng, cfg);
            // Thule's fjord banks, the rise
            CityWater.Mark(plan, cfg);
            return plan;
        }
        // The plan before any street, block or site is laid.

        public static GDict _EmptyPlan(GDict cfg, GArray<GDict> diags, GArray<double> xs, GArray<double> zs)
        {
            return new GDict { { "nodes", ((GArray<Vector2>)Gd.Arr()) }, { "streets", ((GArray<GDict>)Gd.Arr()) }, { "blocks", ((GArray<GDict>)Gd.Arr()) }, { "sidewalk", Num.F(cfg["sidewalk"]) }, { "diagonal", diags[0] }, { "diagonals", diags }, { "xs", xs }, { "zs", zs }, { "bay", CityHarbour.RectOf(cfg) } };
        }
        // the first diagonal (the only one but in a two-diagonal plan)
        // the sea bay, laid first: no street enters it
        // Every grid street, split at each crossing and where each diagonal crosses: x-lines (running
        // along z) first, then z-lines. alleys: [alley_x, alley_z].

        public static void _LayStreets(GDict plan, GDict index, GDict lines, GArray<Variant> alleys, GDict cfg)
        {
            GArray<double> xs = lines["xs"];
            GArray<double> zs = lines["zs"];
            double outer = Num.F(cfg["outer_half"]);
            GArray<GDict> diags = plan["diagonals"];
            GDict avenuesX = lines["avenues_x"];
            GDict avenuesZ = lines["avenues_z"];
            GDict alleyX = alleys[0];
            GDict alleyZ = alleys[1];
            GDict sx = plan["sharp_x"];
            GDict sz = plan["sharp_z"];
            foreach (long i in Gd.Range(xs.Size()))
            {
                GArray<double> stops = new GArray<double>();
                stops.Assign(zs);
                foreach (GDict diag in diags)
                {
                    double cross = CityDiagonals.AtX(diag, xs[i]);
                    if (Gd.Absf(cross) <= outer && !(sx.Has(new Vector2i(i, CellOf(zs, cross)))))
                    {
                        stops.Append(cross);
                    }
                }
                stops.Sort();
                foreach (long k in Gd.Range(stops.Size() - 1))
                {
                    long j = CellOf(zs, (stops[k] + stops[k + 1]) * 0.5);
                    if (sx.Has(new Vector2i(i, j)))
                    {
                        // a diagonal crosses it too sharply, or too near a junction: left out
                        continue;
                    }
                    var kind = (avenuesX.Has(i) ? AVENUE : STREET);
                    if (alleyX.Has(new Vector2i(i, j)))
                    {
                        kind = ALLEY;
                    }
                    _Street(plan, index, new Vector2(xs[i], stops[k]), new Vector2(xs[i], stops[k + 1]), kind, cfg);
                }
            }
            foreach (long j in Gd.Range(zs.Size()))
            {
                GArray<double> stops = new GArray<double>();
                stops.Assign(xs);
                foreach (GDict diag in diags)
                {
                    double cross = CityDiagonals.AtZ(diag, zs[j]);
                    if (Gd.Absf(cross) <= outer && !(sz.Has(new Vector2i(j, CellOf(xs, cross)))))
                    {
                        stops.Append(cross);
                    }
                }
                stops.Sort();
                foreach (long k in Gd.Range(stops.Size() - 1))
                {
                    long i = CellOf(xs, (stops[k] + stops[k + 1]) * 0.5);
                    if (sz.Has(new Vector2i(j, i)))
                    {
                        continue;
                    }
                    var kind = (avenuesZ.Has(j) ? AVENUE : STREET);
                    if (alleyZ.Has(new Vector2i(j, i)))
                    {
                        kind = ALLEY;
                    }
                    _Street(plan, index, new Vector2(stops[k], zs[j]), new Vector2(stops[k + 1], zs[j]), kind, cfg);
                }
            }
        }
        // The diagonal avenue, crossing to crossing.

        public static void _LayDiagonal(GDict plan, GDict index, GDict diag, GArray<double> xs, GArray<double> zs, double outer, GDict cfg)
        {
            GArray<Vector2> along = new GArray<Vector2>();
            GDict sx = plan["sharp_x"];
            GDict sz = plan["sharp_z"];
            foreach (long i in Gd.Range(xs.Size()))
            {
                double z = CityDiagonals.AtX(diag, xs[i]);
                if (Gd.Absf(z) <= outer && !(sx.Has(new Vector2i(i, CellOf(zs, z)))))
                {
                    along.Append(new Vector2(xs[i], z));
                }
            }
            foreach (long j in Gd.Range(zs.Size()))
            {
                double x = CityDiagonals.AtZ(diag, zs[j]);
                if (Gd.Absf(x) <= outer && !(sz.Has(new Vector2i(j, CellOf(xs, x)))))
                {
                    along.Append(new Vector2(x, zs[j]));
                }
            }
            along.SortCustom(new Callable(a_ =>
            {
                Vector2 a = a_[0];
                Vector2 b = a_[1];
                return a.x < b.x;
            }));
            foreach (long k in Gd.Range(along.Size() - 1))
            {
                _Street(plan, index, along[k], along[k + 1], DIAGONAL, cfg);
            }
        }
        // Distance from p to the nearest diagonal's centre line.

        public static double DiagonalDistance(GDict plan, Vector2 p)
        {
            double @out = Gd.INF;
            foreach (GDict diag in Gd.Iter(plan["diagonals"]))
            {
                @out = Gd.Minf(@out, LineDistance(diag, p));
            }
            return @out;
        }
        // Distance from p to one diagonal's centre line.

        public static double LineDistance(GDict diag, Vector2 p)
        {
            Vector2 at = diag["at"];
            Vector2 dir = diag["dir"];
            return Gd.Absf((p - at).Cross(dir));
        }
        // A block's pavement: its rect grown over the sidewalk, except a landmark's plaza, which already
        // runs out to the kerb (CitySites._inset), so its pavement never spills into the street.

        public static Rect2 Pavement(GDict block, GDict cfg)
        {
            Rect2 rect = block["rect"];
            return (block.Has("site") ? rect : rect.Grow(Num.F(cfg["sidewalk"])));
        }

        public static double WidthOf(string kind, GDict cfg)
        {
            var matched1 = kind;
            if (matched1 == AVENUE || matched1 == DIAGONAL)
            {
                return Num.F(cfg["avenue_width"]);
            }
            else if (matched1 == ALLEY)
            {
                return Num.F(cfg["alley_width"]);
            }
            return Num.F(cfg["street_width"]);
        }
        // Index of the gap between lines that holds `v`.

        public static long CellOf(GArray<double> lines, double v)
        {
            foreach (long k in Gd.Range(lines.Size() - 1))
            {
                if (v >= lines[k] && v <= lines[k + 1])
                {
                    return k;
                }
            }
            return 0;
        }

        public static long _Node(GDict plan, GDict index, Vector2 p)
        {
            var key = new Vector2i(Gd.Roundi(p.x * 100.0), Gd.Roundi(p.y * 100.0));
            if (!index.Has(key))
            {
                GArray<Vector2> nodes = plan["nodes"];
                index[key] = nodes.Size();
                nodes.Append(p);
            }
            return Num.I(index[key]);
        }

        public static void _Street(GDict plan, GDict index, Vector2 a, Vector2 b, string kind, GDict cfg)
        {
            if ((CitySites.Cuts(plan, a, b) || CityHarbour.Inside(plan, a, b)))
            {
                return;
            }
            if (CityWater.Wet(plan, a, b, kind))
            {
                return;
            }
            Lay(plan, index, a, b, kind, cfg);
        }
        // One street from a to b, wherever it lies (CityWater's ring and spokes inside their open site).

        public static void Lay(GDict plan, GDict index, Vector2 a, Vector2 b, string kind, GDict cfg)
        {
            if (a.DistanceTo(b) < 0.01)
            {
                return;
            }
            GArray<GDict> streets = plan["streets"];
            streets.Append(new GDict { { "from", _Node(plan, index, a) }, { "to", _Node(plan, index, b) }, { "width", WidthOf(kind, cfg) }, { "kind", kind } });
        }
        // Blocks between the lines, inset by each side's street half-width and sidewalk (alleys have
        // no sidewalk), with what each is used for.

        public static void _Blocks(GDict plan, GArray<double> xs, GArray<double> zs, GDict avenuesX, GDict avenuesZ, GDict alleyX, GDict alleyZ, RandomNumberGenerator rng, GDict cfg)
        {
            double full = Districts(cfg)[-1];
            double walk = Num.F(cfg["sidewalk"]);
            GArray<GDict> blocks = plan["blocks"];
            GArray<long> inner = new GArray<long>();
            // [alleys, left-out pieces]
            GArray<GDict> ex = new GArray<GDict> { alleyX, plan["sharp_x"] };
            GArray<GDict> ez = new GArray<GDict> { alleyZ, plan["sharp_z"] };
            foreach (long i in Gd.Range(xs.Size() - 1))
            {
                foreach (long j in Gd.Range(zs.Size() - 1))
                {
                    var inset = new Callable(a_ =>
                    {
                        bool avenue = a_[0];
                        GArray<GDict> edges = a_[1];
                        Vector2i key = a_[2];
                        if (edges[1].Has(key))
                        {
                            // no street: the blocks either side abut, the diagonal cuts both
                            return 0.0;
                        }
                        if (edges[0].Has(key))
                        {
                            return Num.F(cfg["alley_width"]) * 0.5;
                        }
                        return WidthOf((avenue ? AVENUE : STREET), cfg) * 0.5 + walk;
                    });
                    double x0 = xs[i] + inset.Call(avenuesX.Has(i), ex, new Vector2i(i, j));
                    double x1 = xs[i + 1] - inset.Call(avenuesX.Has(i + 1), ex, new Vector2i(i + 1, j));
                    double z0 = zs[j] + inset.Call(avenuesZ.Has(j), ez, new Vector2i(j, i));
                    double z1 = zs[j + 1] - inset.Call(avenuesZ.Has(j + 1), ez, new Vector2i(j + 1, i));
                    var rect = new Rect2(x0, z0, x1 - x0, z1 - z0);
                    // Inside the last district a block takes the use it has once that district is in
                    // play, whatever the stage, so its lots never change (CityBand holds it back).
                    var city = Gd.Maxf(Gd.Maxf(Gd.Absf(x0), Gd.Absf(x1)), Gd.Maxf(Gd.Absf(z0), Gd.Absf(z1))) < full;
                    var use = ((city || CityBand.Real(rect, cfg)) ? "built" : "outer");
                    double roll = rng.Randf();
                    if (CitySites.Covers(plan, i, j))
                    {
                        // one of a landmark's merged cells
                        continue;
                    }
                    if (!rect.HasArea())
                    {
                        // two bays' pinned lines closer than their kerbs: only street between them
                        continue;
                    }
                    if (city && CityLots.TownShare(rect.GetCenter(), cfg) < 0.2)
                    {
                        if (roll < Num.F(cfg["parking_chance"]))
                        {
                            use = "parking";
                        }
                    }
                    blocks.Append(new GDict { { "rect", rect }, { "use", use }, { "district", DistrictOf(rect, cfg) }, { "cell", new Vector2i(i, j) } });
                    if (city)
                    {
                        inner.Append(blocks.Size() - 1);
                    }
                }
            }
            CitySites.AddBlocks(plan, cfg);
            CityRiver.Mark(plan, zs, cfg);
            // the sea bay's blocks
            CityHarbour.Mark(plan, avenuesX, avenuesZ, cfg);
            CityParks.Pick(plan, inner, cfg);
            CityBand.HoldBack(plan, inner, cfg);
        }

        void _InitFields()
        {
        }
        public CityGen() { _InitFields(); }
    }
}
