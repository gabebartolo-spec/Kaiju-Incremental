// Generated from sim/city_hazards.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityHazards : RefCounted
    {
        public static implicit operator CityHazards(Variant v) => (CityHazards)v.Obj;

        // The city's "red barrels" (director comments #19): a few low buildings in play become fuel
        // silos, fireworks factories or chemical labs (cfg.hazards; Explosives sets them off). They sit
        // toward the playable edge, the industrial fringe and the docks, never by the kaiju's rise from
        // the river (spawn_clear), and keep min_spacing apart. Each keeps its lot's size: only
        // entry["hazard"] is added. Pure: its own seeded numbers (map_seed and the stage), so every other
        // building is drawn exactly as before.
        // Adds the river's quay `sheds` (the docks, welcome however central) to `out` (CityGen.generate's
        // buildings) and tags hazards in it for the stage in `cfg`.

        public static void Tag(GArray<GDict> @out, GDict plan, GDict cfg, GArray<GDict> sheds)
        {
            long quayFrom = @out.Size();
            @out.AppendArray(sheds);
            GDict h = cfg.Get("hazards", new GDict());
            if (h.IsEmpty())
            {
                return;
            }
            double half = Num.F(cfg["half"]);
            // The stage's own ring: a point just inside its edge.
            long ring = CityGen.DistrictOf(new Rect2(-half + 0.01, -half + 0.01, 0.0, 0.0), cfg);
            GArray<Variant> counts = h["count"];
            long want = Num.I(counts[Gd.Mini(ring, counts.Size() - 1)]);
            GArray<Variant> kinds = h["kinds"];
            if ((want <= 0 || kinds.IsEmpty()))
            {
                return;
            }
            Vector2 spawn = plan.Get("rise_spawn", new Vector2(Gd.INF, Gd.INF));
            double edge = half * Num.F(h["edge_share"]);
            GArray<long> candidates = new GArray<long>();
            foreach (long i in Gd.Range(@out.Size()))
            {
                GDict e = @out[i];
                var at = new Vector2(Num.F(e["x"]), Num.F(e["z"]));
                if ((e.Has("landmark") || e.Has("model") || Num.I(e["h"]) > Num.I(h["max_height"])))
                {
                    continue;
                }
                if (Gd.Maxf(Gd.Absf(at.x), Gd.Absf(at.y)) > half)
                {
                    // stands in play: a lot straddling the edge has its middle out of reach
                    continue;
                }
                if (Gd.Maxf(Gd.Absf(at.x), Gd.Absf(at.y)) < edge && i < quayFrom)
                {
                    continue;
                }
                if (spawn.x != Gd.INF && at.DistanceTo(spawn) < Num.F(h["spawn_clear"]))
                {
                    continue;
                }
                candidates.Append(i);
            }
            var rng = Seeds.Make("hazards", Num.I(cfg.Get("map_seed", 0)) * 8 + ring);
            _Shuffle(candidates, rng);
            GArray<Vector2> placed = new GArray<Vector2>();
            long next = rng.RandiRange(0, kinds.Size() - 1);
            foreach (long i in candidates)
            {
                if (placed.Size() >= want)
                {
                    break;
                }
                var at = new Vector2(Num.F(@out[i]["x"]), Num.F(@out[i]["z"]));
                if (placed.Any(new Callable(a_ =>
                {
                    Vector2 p = a_[0];
                    return p.DistanceTo(at) < Num.F(h["min_spacing"]);
                })))
                {
                    continue;
                }
                @out[i]["hazard"] = Gd.Str(kinds[next % kinds.Size()]);
                next += 1;
                placed.Append(at);
            }
        }

        public static void _Shuffle(GArray<long> list, RandomNumberGenerator rng)
        {
            foreach (long i in Gd.Range(list.Size() - 1, 0, -1))
            {
                long j = rng.RandiRange(0, i);
                long t = list[i];
                list[i] = list[j];
                list[j] = t;
            }
        }

        void _InitFields()
        {
        }
        public CityHazards() { _InitFields(); }
    }
}
