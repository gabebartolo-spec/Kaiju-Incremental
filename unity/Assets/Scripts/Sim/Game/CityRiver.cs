// Generated from sim/city_river.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityRiver : RefCounted
    {
        public static implicit operator CityRiver(Variant v) => (CityRiver)v.Obj;

        // The river the kaiju rises from at the start of every run (D-083, director 2026-10-19: "a
        // city caught unaware - have our reptilian emerge from a river to start each run"). It is the
        // row of blocks just south of the first district's ring avenue, across the whole street grid,
        // so it lies in the same place at every stage: past the young city's edge, then through the
        // grown city. Its blocks hold water and no buildings; the streets across it are its bridges.
        // The row past it is its far bank, a park (lawn and trees, crushable decor): the young city's
        // game camera looks across it as the kaiju rises, so no skyline stand-in stands in that view
        // (playtest 2026-10-19: "smaller buildings south of the spawn position dont seem
        // destructible?").
        // Part of CityGen.map, split out to keep files small.
        // Turns the river's row of blocks into "river" and the row past it into a "park" in `plan`
        // (CityGen.map's; each keeps its old use under "was", for CityGen.generate), and records the
        // river's band (z from, z to) as plan["river"] and the kaiju's rise point as
        // plan["river_spawn"]: on the city's north-south axis (x 0), in the river block across it or
        // the nearest one, at least city "river_inset" in from its ends, and where it wades to as
        // plan["river_bank"]: "river_inset" onto the city side, across the ring avenue from it.
        // (Emergence caps the wade at tuning "emerge" "max_seconds", so a bank point that lands in the
        // water can never stall the run's start.)

        public static void Mark(GDict plan, GArray<double> zs, GDict cfg)
        {
            long row = RiverRow(zs, cfg);
            if (row < 0)
            {
                return;
            }
            double inset = Num.F(cfg["river_inset"]);
            var band = new Vector2(Gd.INF, -Gd.INF);
            var spawn = new Vector2(Gd.INF, Gd.INF);
            // how far the chosen block lies from the axis
            double off = Gd.INF;
            foreach (GDict block in Gd.Iter(plan["blocks"]))
            {
                if ((block.Has("site") || !block.Has("cell")))
                {
                    continue;
                }
                Vector2i cell = block["cell"];
                if (cell.y != row && cell.y != row + 1)
                {
                    continue;
                }
                // CityGen.generate still draws its lots, and drops them
                block["was"] = block["use"];
                block["use"] = (cell.y == row ? "river" : "park");
                if (cell.y != row)
                {
                    continue;
                }
                Rect2 rect = block["rect"];
                band = new Vector2(Gd.Minf(band.x, rect.position.y), Gd.Maxf(band.y, rect.end.y));
                double gap = Gd.Absf(Gd.Clampf(0.0, rect.position.x, rect.end.x));
                if (gap < off)
                {
                    off = gap;
                    double x = Gd.Clampf(0.0, rect.position.x + inset, rect.end.x - inset);
                    spawn = new Vector2(x, rect.GetCenter().y);
                }
            }
            if (spawn.x < Gd.INF)
            {
                plan["river"] = band;
                plan["river_spawn"] = spawn;
                plan["river_bank"] = new Vector2(spawn.x, band.x - inset);
                _DigInlets(plan, band, cfg);
            }
        }
        // A bridge landmark's water (D-254): an inlet off the river's far bank, its span's length less a
        // landing at each end wide, from the river's open water to a landing short of its plaza's far
        // kerb, so the bridge meets land at both ends (#12). Sets the site's "water" (Rect2) and "at"
        // (where the bridge stands: across the inlet's middle).

        public static void _DigInlets(GDict plan, Vector2 band, GDict cfg)
        {
            double walk = Num.F(cfg["sidewalk"]);
            foreach (GDict site in Gd.Iter(plan.Get("sites", Gd.Arr())))
            {
                GDict spec = site["spec"];
                if (Gd.Str(spec.Get("kind", "")) != "bridge")
                {
                    continue;
                }
                GDict shape = site["shape"];
                Rect2 rect = site["rect"];
                double landing = Num.F(spec["landing"]);
                double wide = Num.F(shape["w"]) - 2.0 * landing;
                // where the river's open water ends (a sidewalk past its blocks)
                double top = band.y + walk;
                var water = new Rect2(rect.GetCenter().x - wide * 0.5, top, wide, rect.end.y - landing - top);
                site["water"] = water;
                site["at"] = new Vector2(rect.GetCenter().x, water.GetCenter().y);
            }
        }
        // Every bridge inlet's water (empty without one).

        public static GArray<Rect2> Inlets(GDict plan)
        {
            GArray<Rect2> @out = new GArray<Rect2>();
            foreach (GDict site in Gd.Iter(plan.Get("sites", Gd.Arr())))
            {
                if (site.Has("water"))
                {
                    @out.Append(site["water"]);
                }
            }
            return @out;
        }
        // The street-grid row (z cell) the river runs along: the one just south of district 0's ring
        // line; -1 without a river. CitySites keeps every landmark's site out of it (sim review FIX
        // 2026-10-20 on #88: a landmark in this row would stand in the water).

        public static long RiverRow(GArray<double> zs, GDict cfg)
        {
            if (!(Gd.Truthy(cfg.Get("river", false))))
            {
                return -1;
            }
            double edge = CityGen.Districts(cfg)[0];
            long row = -1;
            foreach (long j in Gd.Range(zs.Size() - 1))
            {
                if (Gd.IsEqualApprox(zs[j], edge))
                {
                    row = j;
                }
            }
            return row;
        }
        // The river's open water (x, z): ONE channel from the west end of the street grid to the east
        // end, however many blocks and gaps lie along it (a gap is a street or a landmark's site; each
        // is carried over the water by CityRiver.bridges, so the water runs on under all of them and is
        // never cut short), first; then each bridge landmark's inlet off it. Empty without a river.

        public static GArray<Rect2> Channels(GDict plan, GDict cfg)
        {
            GArray<Rect2> @out = new GArray<Rect2>();
            var spans = _Spans(plan, cfg);
            if (spans.IsEmpty())
            {
                return @out;
            }
            var whole = spans[0];
            foreach (Rect2 span in spans)
            {
                whole = whole.Merge(span);
            }
            @out.Append(whole);
            @out.AppendArray(Inlets(plan));
            return @out;
        }
        // The roads across the river (x, z): one deck over the water in every gap between neighbouring
        // river blocks, a street's or a site's, from bank to bank of the whole channel (its blocks are
        // not all as deep, so a deck as deep as the block beside it stopped short of the bank: director,
        // build 4 comments 2026-10-21 #12, "bridge is not connected to land").

        public static GArray<Rect2> Bridges(GDict plan, GDict cfg)
        {
            GArray<Rect2> @out = new GArray<Rect2>();
            var spans = _Spans(plan, cfg);
            var water = Channels(plan, cfg);
            if (water.IsEmpty())
            {
                return @out;
            }
            double z0 = water[0].position.y;
            double deep = water[0].size.y;
            // no road bridge where an inlet opens (its streets are cut)
            GArray<Rect2> mouths = new GArray<Rect2>();
            foreach (GDict site in Gd.Iter(plan.Get("sites", Gd.Arr())))
            {
                if (site.Has("water"))
                {
                    mouths.Append(site["outer"]);
                }
            }
            foreach (long n in Gd.Range(1, spans.Size()))
            {
                double from = spans[n - 1].end.x;
                if (spans[n].position.x - from > 0.01)
                {
                    var deck = new Rect2(from, z0, spans[n].position.x - from, deep);
                    var cut = false;
                    foreach (Rect2 mouth in mouths)
                    {
                        double mid = deck.GetCenter().x;
                        cut = (cut || (mid > mouth.position.x && mid < mouth.end.x));
                    }
                    if (!cut)
                    {
                        @out.Append(deck);
                    }
                }
            }
            return @out;
        }
        // Each diagonal avenue's own bridge over the river (roads suite R2: no road crosses open water
        // off a deck): its centre line from where its carriageway first reaches over the water to where
        // it last does, {from, to, width}; one per diagonal that crosses.

        public static GArray<GDict> DiagonalDecks(GDict plan, GDict cfg)
        {
            var water = Channels(plan, cfg);
            GArray<GDict> @out = new GArray<GDict>();
            if (water.IsEmpty())
            {
                return @out;
            }
            foreach (GDict diag in Gd.Iter(plan["diagonals"]))
            {
                GDict deck = _Deck(diag, water[0], cfg);
                if (!deck.IsEmpty())
                {
                    @out.Append(deck);
                }
            }
            return @out;
        }

        public static GDict _Deck(GDict diag, Rect2 water, GDict cfg)
        {
            Vector2 at = diag["at"];
            Vector2 dir = diag["dir"];
            if (Gd.Absf(dir.y) < 0.01)
            {
                return new GDict();
            }
            double width = CityGen.WidthOf(CityGen.DIAGONAL, cfg);
            // how far the carriageway's edges reach past its centre in z
            double lean = width * 0.5 * Gd.Absf(dir.x);
            GArray<Vector2> ends = new GArray<Vector2>();
            foreach (double z in Gd.Arr(water.position.y - lean, water.end.y + lean))
            {
                ends.Append(at + dir * ((z - at.y) / dir.y));
            }
            var mid = (ends[0] + ends[1]) * 0.5;
            if ((mid.x < water.position.x || mid.x > water.end.x))
            {
                return new GDict();
            }
            return new GDict { { "from", ends[0] }, { "to", ends[1] }, { "width", width } };
        }
        // Quay sheds (lead check 2026-10-19: the young city's first steps out of the water must hit
        // something; lead 2026-10-26, once blocks grew, D-265: "blocks within quay reach of the bank
        // build the 2 m sheds on their river face, so the start plays as before"): every built block of
        // the first district within city "quay" "reach" of the bank point drops the lots that reach
        // within it (off_quay) and lines that ground with small sheds instead, in rows "depth" deep
        // from its river face inward. They draw their own numbers, so no other lot moves, and stand the
        // same at every stage.

        public static bool OnQuay(GDict plan, GDict block, GDict cfg)
        {
            if (!_HasStart(plan))
            {
                return false;
            }
            Rect2 rect = block["rect"];
            var bank = _Start(plan);
            return _Gap(rect, bank) <= Num.F(cfg["quay"]["reach"]);
        }
        // Where the run starts on land: the sea bay's bank (CityHarbour plan["rise_bank"]) when the
        // city has a bay, else the river's (plan["river_bank"]). The quay sheds stand by it, so his
        // first steps out of the water meet small buildings (SpawnView's 10 s bar, D-131).

        public static Vector2 _Start(GDict plan)
        {
            return plan.Get("rise_bank", plan.Get("river_bank", new Vector2(Gd.INF, Gd.INF)));
        }

        public static bool _HasStart(GDict plan)
        {
            return (plan.Has("rise_bank") || plan.Has("river_bank"));
        }
        // The lots of a quay block that stand clear of the quay (every one, without a river).

        public static GArray<GDict> OffQuay(GDict plan, GArray<GDict> lots, GDict cfg)
        {
            if (!_HasStart(plan))
            {
                return lots;
            }
            double reach = Num.F(cfg["quay"]["reach"]);
            var bank = _Start(plan);
            GArray<GDict> @out = new GArray<GDict>();
            foreach (GDict b in lots)
            {
                if (_Gap(_Foot(b), bank) > reach)
                {
                    @out.Append(b);
                }
            }
            return @out;
        }
        // The sheds of the quay blocks (on_quay), clear of the diagonal and of `standing` (the city's
        // other buildings).

        public static GArray<GDict> Sheds(GDict plan, GArray<GDict> quay, GArray<GDict> standing, GDict cfg)
        {
            GArray<GDict> @out = new GArray<GDict>();
            if (!_HasStart(plan))
            {
                return @out;
            }
            GDict q = cfg["quay"];
            var bank = _Start(plan);
            var rng = new RandomNumberGenerator();
            rng.seed = Num.I(cfg["map_seed"]) + 3;
            double clear = CityGen.WidthOf(CityGen.DIAGONAL, cfg) * 0.5 + 1.0;
            foreach (GDict block in quay)
            {
                Rect2 rect = block["rect"];
                foreach (GDict shed in _Rows(rng, rect, bank, q))
                {
                    var foot = _Foot(shed);
                    if (_Gap(foot, bank) > Num.F(q["reach"]))
                    {
                        continue;
                    }
                    if (CityGen.DiagonalDistance(plan, foot.GetCenter()) < clear + foot.size.x)
                    {
                        continue;
                    }
                    if (standing.Any(new Callable(a_ =>
                    {
                        GDict b = a_[0];
                        return _Foot(b).Intersects(foot);
                    })))
                    {
                        continue;
                    }
                    shed["tier"] = CityGen.TierForHeight(Num.I(shed["h"]), cfg);
                    @out.Append(shed);
                }
            }
            return @out;
        }
        // Rows of sheds along a block's face toward the bank, "depth" deep each, back to back inward;
        // along each row, widths and gaps drawn from `rng` (every shed draws, kept or not).

        public static GArray<GDict> _Rows(RandomNumberGenerator rng, Rect2 rect, Vector2 bank, GDict q)
        {
            GArray<GDict> @out = new GArray<GDict>();
            long depth = Num.I(q["depth"]);
            long gap = Num.I(q["gap"]);
            GArray<Variant> widths = q["width"];
            GArray<Variant> heights = q["height"];
            // rows start at the face toward the bank
            var south = bank.y >= rect.GetCenter().y;
            foreach (long k in Gd.Range(Gd.Floori(rect.size.y / depth)))
            {
                double z = (south ? rect.end.y - depth * (k + 0.5) : rect.position.y + depth * (k + 0.5));
                double t = Gd.Float(gap);
                while (true)
                {
                    long w = rng.RandiRange(Num.I(widths[0]), Num.I(widths[1]));
                    long h = rng.RandiRange(Num.I(heights[0]), Num.I(heights[1]));
                    long style = rng.RandiRange(0, 3);
                    if (t + w > rect.size.x - gap)
                    {
                        break;
                    }
                    @out.Append(new GDict { { "x", rect.position.x + t + w * 0.5 }, { "z", z }, { "w", w }, { "d", depth }, { "h", h }, { "style", style } });
                    t += w + gap;
                }
            }
            return @out;
        }

        public static Rect2 _Foot(GDict b)
        {
            double w = Num.F(b["w"]);
            double d = Num.F(b["d"]);
            return new Rect2(Num.F(b["x"]) - w * 0.5, Num.F(b["z"]) - d * 0.5, w, d);
        }
        // How far `p` lies from `rect` (0 inside it).

        public static double _Gap(Rect2 rect, Vector2 p)
        {
            return p.Clamp(rect.position, rect.end).DistanceTo(p);
        }
        // The river blocks with their sidewalks, west to east.

        public static GArray<Rect2> _Spans(GDict plan, GDict cfg)
        {
            GArray<Rect2> @out = new GArray<Rect2>();
            foreach (GDict block in Gd.Iter(plan["blocks"]))
            {
                if (Gd.Str(block["use"]) == "river")
                {
                    Rect2 rect = block["rect"];
                    @out.Append(rect.Grow(Num.F(cfg["sidewalk"])));
                }
            }
            @out.SortCustom(new Callable(a_ =>
            {
                Rect2 a = a_[0];
                Rect2 b = a_[1];
                return a.position.x < b.position.x;
            }));
            return @out;
        }

        void _InitFields()
        {
        }
        public CityRiver() { _InitFields(); }
    }
}
