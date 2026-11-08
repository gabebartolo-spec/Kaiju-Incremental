// Generated from sim/city_pool_pick.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityPoolPick : RefCounted
    {
        public static implicit operator CityPoolPick(Variant v) => (CityPoolPick)v.Obj;

        // CityPool's model search: which pool model a space takes (its district and role, fits the space,
        // suits its height, no copy of itself near, the least used first), and the counts and spots
        // that keep copies apart. Works on CityPool.place's ctx. Pure.
        // The baked rows' floors by id.

        public static GDict Heights(GDict book)
        {
            GDict pool = book["pool"];
            GDict @out = new GDict();
            foreach (string id in pool)
            {
                GDict row = pool[id];
                @out[id] = Num.I(row.Get("h", 0));
            }
            return @out;
        }
        // The baked ids of each "district|role", sorted.

        public static GDict ByKind(GDict book)
        {
            GDict pool = book["pool"];
            GArray<Variant> ids = pool.Keys();
            ids.Sort();
            GDict @out = new GDict();
            foreach (Variant id in ids)
            {
                GDict row = pool[id];
                if (!row.Has("w"))
                {
                    continue;
                }
                var key = Gd.Format("%s|%s", Gd.Arr(row["district"], row["role"]));
                GArray<Variant> list = @out.Get(key, Gd.Arr());
                list.Append(Gd.Str(id));
                @out[key] = list;
            }
            return @out;
        }
        // The id CityPool._choose takes, or "": the least used of the suited ids with no copy near.

        public static string Best(Rect2 rect, GDict want, GDict ctx)
        {
            GDict counts = ctx["count"];
            GDict heights = ctx["heights"];
            GDict pl = ctx["pl"];
            var span = _HeightSpan(want, pl);
            var at = rect.GetCenter();
            GArray<string> best = new GArray<string>();
            long bestUses = (1L << (int)(30));
            foreach (string id in _Suited(rect, want, ctx))
            {
                long h = heights[id];
                if ((h < span.x || h > span.y || _Crowded(id, at, ctx)))
                {
                    continue;
                }
                long uses = Num.I(counts.Get(id, 0));
                if (uses < bestUses)
                {
                    bestUses = uses;
                    best.Clear();
                }
                if (uses == bestUses)
                {
                    best.Append(id);
                }
            }
            return (best.IsEmpty() ? "" : best[Num.I(want["pick"]) % best.Size()]);
        }
        // The ids of want's district and role that fit `rect` (and are big enough for a block, when
        // want.big), sorted; kept in ctx per kind of space, as lots repeat their sizes.

        public static GArray<Variant> _Suited(Rect2 rect, GDict want, GDict ctx)
        {
            GArray<Variant> key = Gd.Arr(want["district"], want["role"], Gd.Floori(rect.size.x + 0.001), Gd.Floori(rect.size.y + 0.001), want.Get("slack", -1), want.Get("big", false));
            GDict memo = ctx["suited"];
            Variant known = memo.Get(key);
            if (!Gd.IsNull(known))
            {
                GArray<Variant> hit = known;
                return hit;
            }
            GDict book = ctx["book"];
            GDict pool = book["pool"];
            GDict pl = ctx["pl"];
            GDict by = ctx["by"];
            GArray<Variant> ids = by.Get(Gd.Format("%s|%s", Gd.Arr(want["district"], want["role"])), Gd.Arr());
            GArray<Variant> @out = Gd.Arr();
            foreach (Variant id in ids)
            {
                GDict row = pool[id];
                if ((Gd.Truthy(want.Get("big", false)) && Gd.Mini(Num.I(row["w"]), Num.I(row["d"])) < Num.I(pl["big_side"])))
                {
                    continue;
                }
                if (_FitsAny(row, key))
                {
                    @out.Append(id);
                }
            }
            memo[key] = @out;
            return @out;
        }
        // Whether `row` fits the space of a _suited key (w, d, slack) in either turn.

        public static bool _FitsAny(GDict row, GArray<Variant> key)
        {
            long w = key[2];
            long d = key[3];
            long slack = key[4];
            long rw = Num.I(row["w"]);
            long rd = Num.I(row["d"]);
            foreach (bool turn in Gd.Arr(false, true))
            {
                long a = (turn ? rd : rw);
                long b = (turn ? rw : rd);
                if (a <= w && b <= d && ((slack < 0 || (w - a <= slack && d - b <= slack))))
                {
                    return true;
                }
            }
            return false;
        }

        public static void Count(string id, Vector2 at, GDict ctx)
        {
            GDict counts = ctx["count"];
            counts[id] = Num.I(counts.Get(id, 0)) + 1;
            GDict used = ctx["used"];
            GArray<Variant> spots = used.Get(id, Gd.Arr());
            spots.Append(at);
            used[id] = spots;
        }

        public static bool _Crowded(string id, Vector2 at, GDict ctx)
        {
            double reuse = Num.F(ctx["pl"]["reuse_m"]);
            GDict used = ctx["used"];
            GArray<Variant> spots = used.Get(id, Gd.Arr());
            foreach (Vector2 spot in spots)
            {
                if (spot.DistanceSquaredTo(at) < reuse * reuse)
                {
                    return true;
                }
            }
            return false;
        }
        // The floors (lowest, highest) a model may have to suit want.h: within height_fit of them (a
        // share, never under height_fit_min floors); a block model (hero or big filler) any height up to
        // hero_rise times the block's tallest lot.

        public static Vector2 _HeightSpan(GDict want, GDict pl)
        {
            double lotH = Num.F(want["h"]);
            if (want.Has("big"))
            {
                return new Vector2(0.0, Gd.Maxf(lotH * Num.F(pl["hero_rise"]), Num.F(pl["height_fit_min"]) + lotH));
            }
            double slack = Gd.Maxf(Num.F(pl["height_fit_min"]), lotH * Num.F(pl["height_fit"]));
            return new Vector2(lotH - slack, lotH + slack);
        }

        void _InitFields()
        {
        }
        public CityPoolPick() { _InitFields(); }
    }
}
