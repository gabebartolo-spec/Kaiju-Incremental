// Generated from sim/city_spread.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CitySpread : RefCounted
    {
        public static implicit operator CitySpread(Variant v) => (CitySpread)v.Obj;

        // Where a city's landmarks stand (D-254: "space out our landmarks ... across the new expanded
        // area"; the explosive sites are CityHazards'), seeded by the city's map_seed alone, so the
        // same seed always gives the same city and every stage shows the sites of the districts it has
        // opened (D-039: sites never move between stages). Part of CityGen.map; pure.
        //
        // The public interface other systems read (districts, city blocks):
        // plan["sites"]            landmark sites (CitySites.find's dictionaries), "district" = ring
        // opens_at(district)       the growth stage (1-based) a district first comes into play
        // width(rings, district)   that stage's play-area width
        //
        // Spacing (city "spread", lead call 2026-10-26): sites a stage newly opens keep apart by a share
        // of that stage's width; a pair with a site of an inner district keeps the share of the INNER
        // stage's width. Landmarks also keep spawn_clear x width (or their own "rise_clear" m, the
        // stadium: b2-21) from the kaiju's rise, plus rise_slack for the rise's exact spot, which the
        // river fixes only once the blocks are laid. A landmark with "far_from_rise" (the stadium: "as
        // far away from our spawn spot as possible", b2-21) takes the fitting cell of its district
        // farthest from the rise (seeded order breaks a tie); "max_ring" caps its districts (the stadium
        // stays reachable from stage 2: D-271); "place_order" places the most constrained first (the
        // stadium, then the bridge, which only the river's far bank takes), the rest after them.
        public const string LANDMARK_STREAM = "city_spread";
        public const string DRAW_STREAM = "landmark_draw";
        // The growth stage (1 = the young city) in which district `ring` first lies in the play area.

        public static long OpensAt(long ring)
        {
            return ring + 1;
        }
        // The play-area width (both sides) of the stage that opens district `ring`.

        public static double Width(GArray<double> rings, long ring)
        {
            return 2.0 * rings[Gd.Clampi(ring, 0, rings.Size() - 1)];
        }
        // The landmark sites: the pool (city "landmarks") in seeded order, each into a seeded district
        // from its "min_ring" on with room left (spread "landmarks_per_ring"), at the first seeded cell
        // of that district where it fits and keeps its distances. A landmark no district can take is
        // left out. A spec with an "anchor" [x, z] stands there instead (no spread). Specs place in
        // "place_order" (lowest first; none = after every ordered one), seeded order among equals.

        public static GArray<GDict> Landmarks(GDict plan, GArray<double> rings, GArray<Variant> avenues, GDict cfg)
        {
            GDict spread = cfg.Get("spread", new GDict());
            GDict shapes = cfg.Get("landmark_shapes", new GDict());
            var rng = Seeds.Make(LANDMARK_STREAM, Num.I(cfg["map_seed"]));
            GArray<Variant> axes = Gd.Arr(new GDict { { "lines", plan["xs"] }, { "rings", rings }, { "avenues", avenues[0] }, { "cfg", cfg } }, new GDict { { "lines", plan["zs"] }, { "rings", rings }, { "avenues", avenues[1] }, { "cfg", cfg } });
            GArray<Variant> pool = Gd.Arr();
            foreach (GDict spec in Gd.Iter(cfg.Get("landmarks", Gd.Arr())))
            {
                if (shapes.Has(Gd.Str(spec["id"])) && ((spec.Has("anchor") || !spec.Has("size"))))
                {
                    pool.Append(spec);
                }
            }
            pool.AppendArray(SpotDraws(cfg));
            _Shuffle(pool, rng);
            pool = _InPlaceOrder(pool);
            long perRing = Num.I(spread.Get("landmarks_per_ring", 0));
            GArray<long> taken = new GArray<long>();
            foreach (long k in Gd.Range(rings.Size()))
            {
                taken.Append(0);
            }
            GArray<double> zs = plan["zs"];
            var rise = RiseEstimate(zs, cfg);
            GArray<GDict> @out = new GArray<GDict>();
            foreach (GDict spec in pool)
            {
                GDict shape = shapes[Gd.Str(spec["id"])];
                // its designated spot (D-375), or the nearest cell that fits
                if (spec.Has("anchor"))
                {
                    GArray<Variant> at = spec["anchor"];
                    var spot = new Vector2(Num.F(at[0]), Num.F(at[1]));
                    GDict pinned = _Nearest(plan, spec, shape, spot, axes, @out);
                    if (!pinned.IsEmpty())
                    {
                        @out.Append(pinned);
                    }
                    continue;
                }
                GArray<Variant> choices = Gd.Arr();
                long last = Gd.Mini(Num.I(spec.Get("max_ring", rings.Size() - 1)), rings.Size() - 1);
                foreach (long k in Gd.Range(Num.I(spec.Get("min_ring", 0)), last + 1))
                {
                    if (taken[k] < perRing)
                    {
                        choices.Append(k);
                    }
                }
                _Shuffle(choices, rng);
                foreach (long k in choices)
                {
                    GDict site = _Place(plan, spec, shape, k, axes, @out, rise, rng);
                    if (!site.IsEmpty())
                    {
                        @out.Append(site);
                        taken[k] += 1;
                        break;
                    }
                }
            }
            return @out;
        }
        // The pool's draw into the designated spots (D-375): the sized pool entries (city "landmarks"
        // with a "size") in seeded order, each into a free spot of its size ("landmark_spots"; its own
        // "spot" only, if it names one); an entry with no free spot sits this run out, a spot with no
        // entry left stays plain city. Returns the drawn entries, each with its spot's "anchor" and
        // "spot" set (an entry given its own "anchor", a test's, skips the draw). Its own stream
        // (map_seed), so the draw never shifts the spread's order.

        public static GArray<GDict> SpotDraws(GDict cfg)
        {
            GDict spots = cfg.Get("landmark_spots", new GDict());
            GDict shapes = cfg.Get("landmark_shapes", new GDict());
            var rng = Seeds.Make(DRAW_STREAM, Num.I(cfg["map_seed"]));
            GArray<Variant> pool = Gd.Arr();
            foreach (GDict spec in Gd.Iter(cfg.Get("landmarks", Gd.Arr())))
            {
                if (spec.Has("size") && !spec.Has("anchor") && shapes.Has(Gd.Str(spec["id"])))
                {
                    pool.Append(spec);
                }
            }
            _Shuffle(pool, rng);
            GArray<Variant> free = Gd.Arr();
            foreach (string id in spots)
            {
                if (!id.BeginsWith("_"))
                {
                    free.Append(id);
                }
            }
            free.Sort();
            _Shuffle(free, rng);
            GArray<GDict> @out = new GArray<GDict>();
            foreach (GDict spec in pool)
            {
                foreach (string id in free)
                {
                    GDict spot = spots[id];
                    if ((Gd.Str(spot["size"]) != Gd.Str(spec["size"]) || Gd.Str(spec.Get("spot", id)) != id))
                    {
                        continue;
                    }
                    GDict drawn = spec.Duplicate();
                    drawn["anchor"] = spot["at"];
                    drawn["spot"] = id;
                    @out.Append(drawn);
                    free.Erase(id);
                    break;
                }
            }
            return @out;
        }
        // An anchored landmark's site: at its spot, else in the cell of the spot's district nearest it
        // where it fits clear of the sites placed before it (the diagonal or a sea bay can cross the
        // spot on some seeds); {} if none fits.

        public static GDict _Nearest(GDict plan, GDict spec, GDict shape, Vector2 spot, GArray<Variant> axes, GArray<GDict> placed)
        {
            GDict alongX = axes[0];
            GDict cfg = alongX["cfg"];
            GDict site = CitySites.SiteAt(plan, spec, shape, spot, axes);
            if (!site.IsEmpty() && _Clear(site, placed))
            {
                return site;
            }
            GArray<double> xs = plan["xs"];
            GArray<double> zs = plan["zs"];
            long ring = CityGen.DistrictOf(new Rect2(spot, Vector2.ZERO), cfg);
            GArray<Vector2> cells = new GArray<Vector2>();
            foreach (long i in Gd.Range(xs.Size() - 1))
            {
                foreach (long j in Gd.Range(zs.Size() - 1))
                {
                    cells.Append(new Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5));
                }
            }
            cells.SortCustom(new Callable(a_ =>
            {
                Vector2 a = a_[0];
                Vector2 b = a_[1];
                double da = a.DistanceSquaredTo(spot);
                double db = b.DistanceSquaredTo(spot);
                return (da != db ? da < db : ((a.x != b.x ? a.x < b.x : a.y < b.y)));
            }));
            foreach (Vector2 at in cells)
            {
                site = CitySites.SiteAt(plan, spec, shape, at, axes);
                if (!site.IsEmpty() && Num.I(site["district"]) == ring && _Clear(site, placed))
                {
                    return site;
                }
            }
            return new GDict();
        }
        // True when the site's plaza overlaps none of the placed sites'.

        public static bool _Clear(GDict site, GArray<GDict> placed)
        {
            Rect2 outer = site["outer"];
            foreach (GDict other in placed)
            {
                Rect2 theirs = other["outer"];
                if (outer.Grow(-0.01).Intersects(theirs))
                {
                    return false;
                }
            }
            return true;
        }
        // Roughly where the kaiju rises: the fixed beachfront's waterline at its rise_x (CityHarbour,
        // D-381; the exact spot lies a few metres out in the water, which rise_slack covers), else the
        // middle of the river's row on the city's axis. INF with neither.

        public static Vector2 RiseEstimate(GArray<double> zs, GDict cfg)
        {
            if (CityHarbour.On(cfg))
            {
                GDict h = cfg["harbour"];
                double x = Num.F(h["rise_x"]);
                return new Vector2(x, CityHarbour.ShoreAt(h, x));
            }
            long row = CityRiver.RiverRow(zs, cfg);
            if (row < 0)
            {
                return new Vector2(Gd.INF, Gd.INF);
            }
            return new Vector2(0.0, (zs[row] + zs[row + 1]) * 0.5);
        }

        public static GDict _Place(GDict plan, GDict spec, GDict shape, long k, GArray<Variant> axes, GArray<GDict> placed, Vector2 rise, RandomNumberGenerator rng)
        {
            GDict alongX = axes[0];
            GDict cfg = alongX["cfg"];
            GDict spread = cfg.Get("spread", new GDict());
            GArray<double> rings = alongX["rings"];
            GArray<double> xs = plan["xs"];
            GArray<double> zs = plan["zs"];
            double inner = (k > 0 ? rings[k - 1] : 0.0);
            GArray<Variant> anchors = Gd.Arr();
            foreach (long i in Gd.Range(xs.Size() - 1))
            {
                foreach (long j in Gd.Range(zs.Size() - 1))
                {
                    var at = new Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5);
                    double reach = Gd.Maxf(Gd.Absf(at.x), Gd.Absf(at.y));
                    if (reach > inner && reach < rings[k])
                    {
                        anchors.Append(at);
                    }
                }
            }
            _Shuffle(anchors, rng);
            if (Gd.Truthy(spec.Get("far_from_rise", false)) && rise.x != Gd.INF)
            {
                anchors = _FarthestFirst(anchors, rise);
            }
            var bridge = Gd.Str(spec.Get("kind", "")) == "bridge";
            long rows = Num.I(spread.Get("bridge_rows", 1));
            foreach (Vector2 at in anchors)
            {
                GDict site = ((bridge ? CitySites.BridgeAt(plan, spec, shape, at.x, axes, rows) : CitySites.SiteAt(plan, spec, shape, at, axes)));
                if ((site.IsEmpty() || Num.I(site["district"]) != k))
                {
                    continue;
                }
                if (_LandmarkOk(site, k, placed, rise, rings, spread))
                {
                    return site;
                }
            }
            return new GDict();
        }

        public static bool _LandmarkOk(GDict site, long k, GArray<GDict> placed, Vector2 rise, GArray<double> rings, GDict spread)
        {
            GDict spec = site["spec"];
            Rect2 outer = site["outer"];
            Rect2 rect = site["rect"];
            var at = rect.GetCenter();
            double clear = Gd.Maxf(Num.F(spread["spawn_clear"]) * Width(rings, k), Num.F(spec.Get("rise_clear", 0.0)));
            if (rise.x != Gd.INF && at.DistanceTo(rise) < clear + Num.F(spread["rise_slack"]))
            {
                return false;
            }
            foreach (GDict other in placed)
            {
                Rect2 otherOuter = other["outer"];
                if (outer.Grow(-0.01).Intersects(otherOuter.Grow(-0.01)))
                {
                    return false;
                }
                long ring = Gd.Mini(k, Num.I(other["district"]));
                double gap = Num.F(spread["landmark_gap"]) * Width(rings, ring);
                Rect2 otherRect = other["rect"];
                if (at.DistanceTo(otherRect.GetCenter()) < gap)
                {
                    return false;
                }
            }
            return true;
        }
        // The pool sorted by "place_order" (none = last); equal orders keep their (seeded) order.

        public static GArray<Variant> _InPlaceOrder(GArray<Variant> pool)
        {
            GArray<Variant> keyed = Gd.Arr();
            foreach (long n in Gd.Range(pool.Size()))
            {
                GDict spec = pool[n];
                keyed.Append(Gd.Arr(-Num.F(spec.Get("place_order", Gd.INF)), n, spec));
            }
            keyed.SortCustom(new Callable(a_ => _Farther(a_[0], a_[1])));
            GArray<Variant> @out = Gd.Arr();
            foreach (GArray<Variant> row in keyed)
            {
                @out.Append(row[2]);
            }
            return @out;
        }
        // The anchors sorted farthest from the rise first; equal distances keep their (seeded) order.

        public static GArray<Variant> _FarthestFirst(GArray<Variant> anchors, Vector2 rise)
        {
            GArray<Variant> keyed = Gd.Arr();
            foreach (long n in Gd.Range(anchors.Size()))
            {
                Vector2 at = anchors[n];
                keyed.Append(Gd.Arr(at.DistanceTo(rise), n, at));
            }
            keyed.SortCustom(new Callable(a_ => _Farther(a_[0], a_[1])));
            GArray<Variant> @out = Gd.Arr();
            foreach (GArray<Variant> row in keyed)
            {
                @out.Append(row[2]);
            }
            return @out;
        }
        // Sort order for [key, seeded index, item] rows: the larger key first, then the lower index.

        public static bool _Farther(GArray<Variant> a, GArray<Variant> b)
        {
            double da = a[0];
            double db = b[0];
            if (da != db)
            {
                return da > db;
            }
            long ia = a[1];
            long ib = b[1];
            return ia < ib;
        }

        public static void _Shuffle(GArray<Variant> items, RandomNumberGenerator rng)
        {
            foreach (long n in Gd.Range(items.Size() - 1, 0, -1))
            {
                long m = rng.RandiRange(0, n);
                Variant keep = items[n];
                items[n] = items[m];
                items[m] = keep;
            }
        }

        void _InitFields()
        {
        }
        public CitySpread() { _InitFields(); }
    }
}
