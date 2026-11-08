// Generated from sim/demo.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Demo : RefCounted
    {
        public static implicit operator Demo(Variant v) => (Demo)v.Obj;

        // The demo slice (D-050, D-145). data/tuning.json "demo" limits play to its species. Buying the
        // final upgrade (every node of the tree owned) shows the thanks screen (rampage totals, a feedback
        // link) and unlocks Endless mode (Endless, D-156); normal mode stays replayable. With
        // "enabled": false (or no section) the full game plays. Pure: reads Content.

        public static bool Enabled()
        {
            return _Cfg().Get("enabled", false) == true;
        }
        // True when `species_id` is playable: one of Content.species() (never the far beast's insectoid,
        // D-438), and with the demo on one of its species.

        public static bool Allows(string speciesId)
        {
            if (!(Content.Species().Any(new Callable(a_ =>
            {
                GDict def = a_[0];
                return def["id"] == speciesId;
            }))))
            {
                return false;
            }
            if (!Enabled())
            {
                return true;
            }
            GArray<Variant> allowed = _Cfg().Get("species", Gd.Arr());
            return allowed.Has(speciesId);
        }
        // True when a build can continue `save`: its species is playable, and a save that began in a demo
        // never continues in the full game (D-145: demo saves do not carry over).

        public static bool Continues(GDict save)
        {
            if ((save.IsEmpty() || !(Allows(Gd.Str(save.Get("species", ""))))))
            {
                return false;
            }
            return (Enabled() || save.Get("demo", false) != true);
        }
        // The species a new game offers, in data order.

        public static GArray<GDict> Species()
        {
            GArray<GDict> @out = new GArray<GDict>();
            foreach (GDict def in Content.Species())
            {
                if (Allows(Gd.Str(def["id"])))
                {
                    @out.Append(def);
                }
            }
            return @out;
        }
        // True when `tree` owns every node (the final upgrade is bought): the demo's end, read from data.

        public static bool Complete(UpgradeTree tree)
        {
            return Enabled() && tree.LevelsOwned() >= tree.LevelsTotal();
        }
        // `totals` plus one rampage's `result` (RampageSim.result() with the view's people counts).

        public static GDict Add(GDict totals, GDict result)
        {
            GDict @out = totals.Duplicate();
            long military = 0;
            foreach (string key in Gd.Iter(_Cfg()["military_keys"]))
            {
                military += Num.I(result.Get(key, 0));
            }
            GDict adds = new GDict { { "biomass", Num.I(result.Get("rubble", 0)) }, { "buildings", Num.I(result.Get("buildings", 0)) }, { "eaten", Num.I(result.Get("civilians", 0)) }, { "fled", Num.I(result.Get("fled", 0)) }, { "military", military }, { "seconds", Num.I(Gd.Floor(Num.F(result.Get("seconds", 0.0)))) } };
            foreach (string key in adds)
            {
                @out[key] = Num.I(@out.Get(key, 0)) + Num.I(adds[key]);
            }
            return @out;
        }
        // The thanks screen's rows, label then text, in order (what the screen draws).

        public static GArray<PackedStringArray> Rows(GDict totals)
        {
            long secs = Num.I(totals.Get("seconds", 0));
            GArray<PackedStringArray> @out = new GArray<PackedStringArray>();
            @out.Append(new PackedStringArray(Gd.Arr("Buildings destroyed", Gd.Str(Num.I(totals.Get("buildings", 0))))));
            @out.Append(new PackedStringArray(Gd.Arr("People eaten", Gd.Str(Num.I(totals.Get("eaten", 0))))));
            @out.Append(new PackedStringArray(Gd.Arr("People fled", Gd.Str(Num.I(totals.Get("fled", 0))))));
            @out.Append(new PackedStringArray(Gd.Arr("Military destroyed", Gd.Str(Num.I(totals.Get("military", 0))))));
            @out.Append(new PackedStringArray(Gd.Arr("Time played", Gd.Format("%d:%02d", Gd.Arr(secs / 60, secs % 60)))));
            @out.Append(new PackedStringArray(Gd.Arr("Biomass earned", Gd.Str(Num.I(totals.Get("biomass", 0))))));
            return @out;
        }
        // Where "Leave feedback" goes (D-148): one data string.

        public static string FeedbackUrl()
        {
            return Gd.Str(_Cfg()["feedback_url"]);
        }

        public static GDict _Cfg()
        {
            return Content.Section("demo");
        }

        void _InitFields()
        {
        }
        public Demo() { _InitFields(); }
    }
}
