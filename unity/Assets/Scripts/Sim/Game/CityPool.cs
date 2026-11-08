// Generated from sim/city_pool.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityPool : RefCounted
    {
        public static implicit operator CityPool(Variant v) => (CityPool)v.Obj;

        // Puts the pool's buildings (data/city_buildings.json: Tripo heroes and fillers, D-256) in the
        // city, until the districts layer lands (D-255, D-261). Every neighbourhood (a square of
        // placement.patch_m) takes one district style its town share allows. Heroes go first, rarer: a
        // block (CityGen.map) now and then takes one of its style that fits it in some facing, set into
        // one of its corners, and the lots under it give way. Then a share of the remaining lots each
        // take a filler of their style that fits the lot (no more than fill_slack units short of it on
        // either side). Every copy picks a facing, a mirror, a floor stretch toward the lots' height and
        // a palette shift; a model never stands within placement.reuse_m of another copy of itself, so
        // no two copies touch and none crowds a view. Procedural buildings keep every other lot.
        // The public interface the city-blocks and districts work will build on:
        // rows(cfg) -> the pool rows by id (empty when off); fits(row, w, d) -> the facings that fit;
        // place(entries, rng, cfg, plan) -> puts pool entries into the layout in place.
        // Seeded from its own stream (Seeds.derive), so the lots' own draws never shift. Pure.
        public const long SALT = 0x7095L;
        // The side of the squares the lots are filed under for the block pass (metres).
        public const double INDEX_CELL = 8.0;
        // two districts this close behind their share tie
        public const double EPS = 1e-6;
        // The pool's baked rows by id (empty when the pool is off or missing).

        public static GDict Rows(GDict cfg)
        {
            GDict book = cfg.Get("building_pool", new GDict());
            GDict placement = book.Get("placement", new GDict());
            if (!(Gd.Truthy(placement.Get("on", false))))
            {
                return new GDict();
            }
            return book.Get("pool", new GDict());
        }
        // The facings (0..3) in which `row` stands inside a w x d space.

        public static GArray<long> Fits(GDict row, long w, long d)
        {
            GArray<long> @out = new GArray<long>();
            long rw = Num.I(row["w"]);
            long rd = Num.I(row["d"]);
            foreach (long facing in Gd.Range(4))
            {
                var turned = facing % 2 == 1;
                if (((turned ? rd : rw)) <= w && ((turned ? rw : rd)) <= d)
                {
                    @out.Append(facing);
                }
            }
            return @out;
        }
        // A layout entry's footprint (x, z centre; w, d).

        public static Rect2 Footprint(GDict e)
        {
            double w = Num.F(e["w"]);
            double d = Num.F(e["d"]);
            return new Rect2(Num.F(e["x"]) - w * 0.5, Num.F(e["z"]) - d * 0.5, w, d);
        }
        // Puts block models (heroes, and fillers too big for a lot) on blocks and fillers on lots of
        // `entries` (CityGen.generate's), in place.

        public static void Place(GArray<GDict> entries, RandomNumberGenerator rng, GDict cfg, GDict plan)
        {
            if (Rows(cfg).IsEmpty())
            {
                return;
            }
            GDict book = cfg["building_pool"];
            GDict ctx = new GDict { { "cfg", cfg }, { "plan", plan }, { "book", book }, { "pl", book["placement"] }, { "r", Seeds.Derive(rng, SALT) }, { "used", new GDict() }, { "count", new GDict() }, { "patches", new GDict() }, { "given", new GDict() }, { "gone", new GDict() }, { "index", _Index(entries) }, { "by", CityPoolPick.ByKind(book) }, { "suited", new GDict() }, { "heights", CityPoolPick.Heights(book) } };
            GArray<GDict> blocks = new GArray<GDict>();
            foreach (GDict block in Gd.Iter(plan["blocks"]))
            {
                if (Gd.Str(block["use"]) == "built")
                {
                    GDict got = _Block(entries, block, ctx);
                    if (!got.IsEmpty())
                    {
                        blocks.Append(got);
                    }
                }
            }
            GDict gone = ctx["gone"];
            GArray<GDict> @out = new GArray<GDict>();
            foreach (long n in Gd.Range(entries.Size()))
            {
                if (gone.Has(n))
                {
                    continue;
                }
                GDict got = _Filler(entries[n], ctx);
                @out.Append((got.IsEmpty() ? entries[n] : got));
            }
            @out.AppendArray(blocks);
            entries.Assign(@out);
        }
        // Lot indices (landmarks left out) by the INDEX_CELL square their centre stands in, and
        // "reach": the widest half-footprint, so a search grows its rect by it.

        public static GDict _Index(GArray<GDict> entries)
        {
            GDict @out = new GDict();
            GArray<Rect2> rects = new GArray<Rect2>();
            rects.Resize(entries.Size());
            double reach = 0.0;
            foreach (long n in Gd.Range(entries.Size()))
            {
                GDict e = entries[n];
                if (e.Has("landmark"))
                {
                    continue;
                }
                var r = Footprint(e);
                rects[n] = r;
                reach = Gd.Maxf(reach, Gd.Maxf(r.size.x, r.size.y) * 0.5);
                var cell = new Vector2i((r.GetCenter() / INDEX_CELL).Floor());
                GArray<Variant> list = @out.Get(cell, Gd.Arr());
                list.Append(n);
                @out[cell] = list;
            }
            return new GDict { { "cells", @out }, { "reach", reach }, { "rects", rects } };
        }

        public static GArray<Vector2i> _Cells(Rect2 rect)
        {
            GArray<Vector2i> @out = new GArray<Vector2i>();
            var lo = new Vector2i((rect.position / INDEX_CELL).Floor());
            var hi = new Vector2i((rect.end / INDEX_CELL).Floor());
            foreach (long x in Gd.Range(lo.x, hi.x + 1))
            {
                foreach (long z in Gd.Range(lo.y, hi.y + 1))
                {
                    @out.Append(new Vector2i(x, z));
                }
            }
            return @out;
        }
        // A block's draw: now and then a hero of the block's style (or, less often, a filler too big for
        // a lot) set into one of its corners; the lots under it give way. Returns the entry or {}.
        // Every block draws the same two numbers, taken or not.

        public static GDict _Block(GArray<GDict> entries, GDict block, GDict ctx)
        {
            RandomNumberGenerator r = ctx["r"];
            GDict pl = ctx["pl"];
            double roll = r.Randf();
            long pick = r.Randi();
            var hero = roll < Num.F(pl["hero_chance"]);
            if (!hero && roll >= Num.F(pl["hero_chance"]) + Num.F(pl["big_chance"]))
            {
                return new GDict();
            }
            Rect2 rect = block["rect"];
            var under = _Under(rect, ctx);
            if (under.IsEmpty())
            {
                return new GDict();
            }
            long tallest = 0;
            foreach (long n in under)
            {
                tallest = Gd.Maxi(tallest, Num.I(entries[n]["h"]));
            }
            GDict want = new GDict { { "district", _District(rect.GetCenter(), ctx) }, { "pick", pick }, { "h", tallest } };
            want["role"] = (hero ? "hero" : "filler");
            want["big"] = !hero;
            GDict placed = _Choose(rect, want, Num.I(entries[under[0]]["style"]), ctx);
            if (placed.IsEmpty())
            {
                return new GDict();
            }
            var spot = _Corner(rect, placed, pick);
            GDict plan = ctx["plan"];
            GDict cfg = ctx["cfg"];
            if (CityLots.OnDiagonal(plan, spot.GetCenter(), spot.size, cfg))
            {
                // a block the diagonal avenue cuts: its corner may lie in the street
                return new GDict();
            }
            placed["x"] = spot.GetCenter().x;
            placed["z"] = spot.GetCenter().y;
            CityPoolPick.Count(Gd.Str(placed["model"]), spot.GetCenter(), ctx);
            GDict gone = ctx["gone"];
            GArray<Rect2> rects = ctx["index"]["rects"];
            foreach (long n in under)
            {
                if (spot.Grow(-0.01).Intersects(rects[n]))
                {
                    gone[n] = true;
                }
            }
            return placed;
        }
        // The lots (not landmarks, not already given way) whose footprints meet `rect`.

        public static GArray<long> _Under(Rect2 rect, GDict ctx)
        {
            GDict index = ctx["index"];
            GDict cells = index["cells"];
            GArray<Rect2> rects = index["rects"];
            GDict gone = ctx["gone"];
            GArray<long> @out = new GArray<long>();
            foreach (Vector2i cell in _Cells(rect.Grow(Num.F(index["reach"]))))
            {
                GArray<Variant> list = cells.Get(cell, Gd.Arr());
                foreach (long n in list)
                {
                    if (gone.Has(n))
                    {
                        continue;
                    }
                    if (rect.Intersects(rects[n]))
                    {
                        @out.Append(n);
                    }
                }
            }
            @out.Sort();
            return @out;
        }
        // The hero's footprint set into one of the block's corners (pick chooses which).

        public static Rect2 _Corner(Rect2 rect, GDict placed, long pick)
        {
            var size = new Vector2(Num.F(placed["w"]), Num.F(placed["d"]));
            long corner = ((pick >> (int)(12))) % 4;
            double x = (corner % 2 == 0 ? rect.position.x : rect.end.x - size.x);
            double z = (corner < 2 ? rect.position.y : rect.end.y - size.y);
            return new Rect2(x, z, size.x, size.y);
        }
        // A lot's filler draw: the pool entry that replaces it, or {}. Every lot draws the same two
        // numbers, taken or not; landmarks and heroes are left alone.

        public static GDict _Filler(GDict lot, GDict ctx)
        {
            RandomNumberGenerator r = ctx["r"];
            double roll = r.Randf();
            long pick = r.Randi();
            if ((lot.Has("landmark") || lot.Has("model") || roll >= Num.F(ctx["pl"]["share"])))
            {
                return new GDict();
            }
            var rect = Footprint(lot);
            var at = rect.GetCenter();
            GDict want = new GDict { { "district", _District(at, ctx) }, { "pick", pick }, { "h", Num.I(lot["h"]) } };
            want["role"] = "filler";
            want["slack"] = Num.I(ctx["pl"]["fill_slack"]);
            GDict placed = _Choose(rect, want, Num.I(lot["style"]), ctx);
            if (!placed.IsEmpty())
            {
                CityPoolPick.Count(Gd.Str(placed["model"]), at, ctx);
            }
            return placed;
        }
        // The district style round `at`: drawn once per patch among those whose town range holds the
        // patch's town share (CityLots.town_share), "residential" when none does: the one furthest
        // behind its share (patches it has so far per model it holds; ties drawn), so every model, not
        // every district, gets a like share of every city (director 2026-10-29: every Tripo model serves
        // every stage, and the young city has few patches).

        public static string _District(Vector2 at, GDict ctx)
        {
            GDict book = ctx["book"];
            double size = Num.F(ctx["pl"]["patch_m"]);
            var patch = new Vector2i(Gd.Floori(at.x / size), Gd.Floori(at.y / size));
            GDict patches = ctx["patches"];
            if (patches.Has(patch))
            {
                return Gd.Str(patches[patch]);
            }
            GDict cfg = ctx["cfg"];
            double town = CityLots.TownShare((new Vector2(patch) + new Vector2(0.5, 0.5)) * size, cfg);
            GDict districts = book["districts"];
            GArray<Variant> names = districts.Keys();
            names.Sort();
            GDict by = ctx["by"];
            GDict given = ctx["given"];
            RandomNumberGenerator r = ctx["r"];
            long roll = r.Randi();
            var pick = "residential";
            double behind = Gd.INF;
            GArray<string> ties = new GArray<string>();
            foreach (Variant name in names)
            {
                GDict district = districts[name];
                GArray<Variant> span = district["town"];
                if ((town < Num.F(span[0]) || town > Num.F(span[1])))
                {
                    continue;
                }
                GArray<Variant> heroes = by.Get(Gd.Format("%s|hero", name), Gd.Arr());
                GArray<Variant> fillers = by.Get(Gd.Format("%s|filler", name), Gd.Arr());
                long models = heroes.Size() + fillers.Size();
                if (models == 0)
                {
                    continue;
                }
                double share = Num.F(given.Get(name, 0)) / models;
                if (share < behind - EPS)
                {
                    behind = share;
                    ties.Clear();
                }
                if (share < behind + EPS)
                {
                    ties.Append(Gd.Str(name));
                }
            }
            if (!ties.IsEmpty())
            {
                pick = ties[roll % ties.Size()];
                given[pick] = Num.I(given.Get(pick, 0)) + 1;
            }
            patches[patch] = pick;
            return pick;
        }
        // The pool entry for a model that stands in `rect` (centred): want.district and want.role, fits
        // in some facing (with no more than want.slack units to spare a side, when set), suits want.h
        // floors and has no copy within reuse_m; the least used first (ties by id), want.pick choosing
        // among equals and the facing, mirror and palette. {} when none qualifies.

        public static GDict _Choose(Rect2 rect, GDict want, long style, GDict ctx)
        {
            var id = CityPoolPick.Best(rect, want, ctx);
            if (id == "")
            {
                return new GDict();
            }
            GDict book = ctx["book"];
            GDict row = book["pool"][id];
            long pick = Num.I(want["pick"]);
            var facings = _Facings(row, rect, want);
            GDict v = new GDict { { "facing", facings[((pick >> (int)(4))) % facings.Size()] }, { "mirror", false }, { "stretch", 0 } };
            if (Num.I(row.Get("stretch_floor", -1)) >= 0)
            {
                long room = Num.I(want["h"]) - Num.I(row["h"]);
                v["stretch"] = Gd.Clampi(room, 0, Num.I(ctx["pl"]["max_stretch"]));
            }
            var dims = ModelVariant.Size(row, v);
            GDict cfg = ctx["cfg"];
            GDict districts = book["districts"];
            GDict district = districts[Gd.Str(row["district"])];
            GArray<Variant> shifts = district["shifts"];
            return new GDict { { "x", rect.GetCenter().x }, { "z", rect.GetCenter().y }, { "w", dims.x }, { "d", dims.z }, { "h", dims.y }, { "tier", CityGen.TierForHeight(dims.y, cfg) }, { "style", style }, { "model", id }, { "facing", v["facing"] }, { "mirror", ((pick >> (int)(8))) % 2 == 1 }, { "stretch", v["stretch"] }, { "palette", ((pick >> (int)(9))) % shifts.Size() } };
        }
        // The facings in which `row` fits `rect`, short of it by at most want.slack a side when set.

        public static GArray<long> _Facings(GDict row, Rect2 rect, GDict want)
        {
            long w = Gd.Floori(rect.size.x + 0.001);
            long d = Gd.Floori(rect.size.y + 0.001);
            var @out = Fits(row, w, d);
            if (!want.Has("slack"))
            {
                return @out;
            }
            long slack = Num.I(want["slack"]);
            GArray<long> tight = new GArray<long>();
            foreach (long facing in @out)
            {
                var turned = facing % 2 == 1;
                long rw = Num.I((turned ? row["d"] : row["w"]));
                long rd = Num.I((turned ? row["w"] : row["d"]));
                if (w - rw <= slack && d - rd <= slack)
                {
                    tight.Append(facing);
                }
            }
            return tight;
        }

        void _InitFields()
        {
        }
        public CityPool() { _InitFields(); }
    }
}
