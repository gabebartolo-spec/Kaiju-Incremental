// Generated from sim/emerge_reach.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class EmergeReach : RefCounted
    {
        public static implicit operator EmergeReach(Variant v) => (EmergeReach)v.Obj;

        // The biggest body that can rise from the sea bay at a stage (CityHarbour), and the bay fitted
        // to hold it (director 2026-10-21, "Fit the biggest possible"). Every
        // species' body at the stage's size tier (tuning "contact" "bodies"), at the most growth it can
        // own at that size: every level of every upgrade at or below the tier, short of the evolution
        // that leaves it (Growth.body_scale, UpgradeTree.tier_of). Pure: tuning and upgrades in.
        // The longest and widest such body (x: snout to tail tip, y: across), world units.

        public static Vector2 Biggest(GDict tuning, GArray<GDict> upgrades, long tier)
        {
            GDict contact = tuning.Get("contact", new GDict());
            GDict bodies = contact.Get("bodies", new GDict());
            var @out = Vector2.ZERO;
            foreach (string speciesId in bodies)
            {
                GArray<Variant> stages = bodies[speciesId];
                if (stages.IsEmpty())
                {
                    continue;
                }
                GDict stage = stages[Gd.Clampi(tier - 1, 0, stages.Size() - 1)];
                GDict stats = new GDict { { "size", tier }, { "growth", MaxGrowth(upgrades, speciesId, tier) } };
                GDict city = tuning["city"];
                double s = Growth.BodyScale(stats, city);
                double front = 0.0;
                double back = 0.0;
                double wide = 0.0;
                foreach (GArray<Variant> d in Gd.Iter(stage["discs"]))
                {
                    front = Gd.Maxf(front, Num.F(d[0]) + Num.F(d[1]));
                    back = Gd.Minf(back, Num.F(d[0]) - Num.F(d[1]));
                    wide = Gd.Maxf(wide, Num.F(d[1]) * 2.0);
                }
                @out = new Vector2(Gd.Maxf(@out.x, (front - back) * s), Gd.Maxf(@out.y, wide * s));
            }
            return @out;
        }
        // The biggest body scale (Growth.body_scale) any species reaches at this size tier.

        public static double BiggestScale(GDict tuning, GArray<GDict> upgrades, long tier)
        {
            GDict contact = tuning.Get("contact", new GDict());
            GDict bodies = contact.Get("bodies", new GDict());
            GDict city = tuning["city"];
            double @out = 0.0;
            foreach (string speciesId in bodies)
            {
                GDict stats = new GDict { { "size", tier }, { "growth", MaxGrowth(upgrades, speciesId, tier) } };
                @out = Gd.Maxf(@out, Growth.BodyScale(stats, city));
            }
            return @out;
        }
        // The most upgrade levels a kaiju of this species can own while at this size tier.

        public static long MaxGrowth(GArray<GDict> upgrades, string speciesId, long tier)
        {
            var tree = new UpgradeTree(upgrades, new GDict(), speciesId);
            long levels = 0;
            foreach (string id in tree.order)
            {
                long t = tree.TierOf(id);
                GDict def = tree.defs[id];
                GDict effects = def.Get("effects", new GDict());
                if ((t < tier || (t == tier && !effects.Has("size"))))
                {
                    levels += tree.MaxLevel(id);
                }
            }
            return levels;
        }
        // Fits the city's "harbour" in `tuning` (a stage's, CityGrowth.tuning_for) to the biggest body: at
        // least as wide as it plus "fit_margin" each side ("fit_width"), the sea floor at the rise its
        // crouched back ("crouch_back" per body scale) plus "seabed_clear" under the surface
        // ("seabed_depth"; below size tier "shelf_below", the baby with no keyed rise clip, it is the
        // wading shelf, city "wade_depth": director 2026-11-02 "Shallower hollow") in a hollow that holds
        // the whole body ("hollow"), and no painted stand-in within
        // the game camera's ground reach of the rise ("view_clear").

        public static void Fit(GDict tuning, GArray<GDict> upgrades, long tier)
        {
            GDict city = tuning.Get("city", new GDict());
            if (!CityHarbour.On(city))
            {
                return;
            }
            GDict bay = city["harbour"];
            var body = Biggest(tuning, upgrades, tier);
            double scale = BiggestScale(tuning, upgrades, tier);
            bay["fit_width"] = Gd.Ceilf(body.y + Num.F(bay["fit_margin"]) * 2.0);
            double crouch = Num.F(bay["crouch_back"]) * scale + Num.F(bay["seabed_clear"]);
            bay["seabed_depth"] = Gd.Maxf(Num.F(bay["seabed_depth"]), crouch);
            if (tier < Num.I(bay["shelf_below"]))
            {
                bay["seabed_depth"] = Num.F(city["wade_depth"]);
            }
            // The rise's hollow holds the whole body, nose to tail, out from the beach line.
            double hold = Gd.Maxf(body.x, body.y) * 0.5 + Num.F(bay["nose_gap"]) + Num.F(bay["fit_margin"]);
            bay["hollow"] = Gd.Maxf(Num.F(bay["hollow"]), Gd.Ceilf(hold));
            GDict cam = tuning.Get("camera", new GDict());
            GArray<Variant> offset = cam.Get("offset", Gd.Arr(0, 0, 0));
            double behind = Gd.Absf(Num.F(offset[2]));
            bay["view_clear"] = Gd.Ceilf((behind + Num.F(bay["view_margin"])) * scale);
        }
        // Whether a footprint (centre `at`, `size`) lies within the game camera's reach of where the
        // kaiju rises or the bank point it wades to (city "harbour" "view_clear", set by fit): no
        // painted stand-in stands there, only real buildings (CitySkyline; playtest 2026-10-19).

        public static bool InView(GDict plan, GDict city, Vector2 at, Vector2 size)
        {
            GDict bay = city.Get("harbour", new GDict());
            double clear = Num.F(bay.Get("view_clear", 0.0));
            if ((clear <= 0.0 || !plan.Has("rise_spawn")))
            {
                return false;
            }
            var foot = new Rect2(at - size * 0.5, size);
            foreach (Vector2 p in Gd.Arr(plan["rise_spawn"], plan.Get("rise_bank", plan["rise_spawn"])))
            {
                if (p.Clamp(foot.position, foot.end).DistanceTo(p) < clear)
                {
                    return true;
                }
            }
            return false;
        }
        // in_view for a lot (CityLots: a dictionary with x, z, w, d).

        public static bool LotInView(GDict plan, GDict city, GDict lot)
        {
            var at = new Vector2(Num.F(lot["x"]), Num.F(lot["z"]));
            return InView(plan, city, at, new Vector2(Num.F(lot["w"]), Num.F(lot["d"])));
        }

        void _InitFields()
        {
        }
        public EmergeReach() { _InitFields(); }
    }
}
