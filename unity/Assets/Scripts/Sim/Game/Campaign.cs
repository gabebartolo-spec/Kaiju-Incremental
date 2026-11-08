// Generated from sim/campaign.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Campaign : RefCounted
    {
        public static implicit operator Campaign(Variant v) => (Campaign)v.Obj;

        // The campaign's state on the globe (Overworld plan row G3; the rest of plan row T1, Threat and
        // noise, lands here later). Pure: reads the continent rows (Content.continents()) and a save's
        // conquered list, no Node.
        // - conquered: in the save's conquered list;
        // - available: Ostia Minor alone until it falls; then the two lowest unconquered continents in
        // the fixed sequence (D-420); the capital once every other continent has fallen (D-422);
        // - locked: everything else.
        public static class State
        {
            public const long LOCKED = 0;
            public const long AVAILABLE = 1;
            public const long CONQUERED = 2;
        }
        // Continents the globe offers at once after the first (D-420).
        public const long OFFERED = 2;
        // D-422: Threat stays at or under THREAT_CAP until the last conquest before the capital sets it
        // to THREAT_FULL and opens Aurelia.
        public const double THREAT_CAP = 99.0;
        public const double THREAT_FULL = 100.0;
        // Whether LAUNCH starts this continent's real city (data "real_city", D-454: Ostia Minor,
        // Carthago, Thule); otherwise the stand-in WIN / LOSE mission.

        public static bool RealCity(GDict def)
        {
            return def.Get("real_city", false) == true;
        }
        // The run stats for a continent's real city (D-454): `stats` (UpgradeTree.run_stats) at the
        // continent's stage (stage index 0.. is size tier 1..; D-419) and naming the continent, so
        // CityGrowth.for_stats plays its own city (D-435). The input is left as it was.

        public static GDict CityStats(GDict stats, GDict def)
        {
            GDict @out = stats.Duplicate(true);
            @out["size"] = Num.I(def["stage"]) + 1;
            @out["continent"] = Gd.Str(def["id"]);
            return @out;
        }
        // The save after a won mission (plan row G5): the continent joins conquered, the one bonus the
        // player kept of its three is stored under its id (D-421), and Threat rises by its share, capped
        // at THREAT_CAP, until the last conquest before the capital sets THREAT_FULL (D-422). The input
        // is left as it was; a continent already conquered changes nothing.

        public static GDict Conquer(GDict save, GDict def, string bonusId)
        {
            GDict @out = save.Duplicate(true);
            GArray<Variant> conquered = @out.Get("conquered", Gd.Arr());
            string id = def["id"];
            if (conquered.Has(id))
            {
                return @out;
            }
            conquered.Append(id);
            @out["conquered"] = conquered;
            GDict bonuses = @out.Get("bonuses", new GDict());
            bonuses[id] = bonusId;
            @out["bonuses"] = bonuses;
            double threat = @out.Get("threat", 0.0);
            double share = def["threat"];
            threat = Gd.Minf(threat + share, THREAT_CAP);
            @out["threat"] = (_CapitalOpens(conquered) ? THREAT_FULL : threat);
            _UnlockTitans(@out, conquered.Size());
            return @out;
        }
        // D-423: species unlocks ride the path, not the map. Each titan whose unlock_conquests is reached
        // by this many conquests joins the save's titans_unlocked list (data/tuning.json "creation"),
        // whichever continents those were.

        public static void _UnlockTitans(GDict save, long count)
        {
            GDict cfg = Content.Section("creation");
            var key = Gd.Str(cfg["save_key"]);
            GArray<Variant> opened = save.Get(key, Gd.Arr());
            foreach (GDict row in Gd.Iter(cfg["titans"]))
            {
                long need = row["unlock_conquests"];
                var id = Gd.Str(row["id"]);
                if (need > 0 && count >= need && !opened.Has(id))
                {
                    opened.Append(id);
                }
            }
            save[key] = opened;
        }
        // D-466: unlocks are meta progression; a New Kaiju keeps the titans the slot already opened.

        public static GDict CarryUnlocks(GDict old, GDict fresh)
        {
            var key = Gd.Str(Content.Section("creation")["save_key"]);
            GArray<Variant> opened = old.Get(key, Gd.Arr());
            if (!opened.IsEmpty())
            {
                fresh[key] = opened.Duplicate();
            }
            return fresh;
        }
        // True once every continent but the capital has fallen (D-422).

        public static bool _CapitalOpens(GArray<Variant> conquered)
        {
            foreach (GDict def in Content.Continents())
            {
                if (!(Gd.Truthy(def.Get("capital", false))) && !conquered.Has(def["id"]))
                {
                    return false;
                }
            }
            return true;
        }
        // Each continent's State by id, from the rows in sequence order and the conquered ids.

        public static GDict States(GArray<GDict> continents, GArray<Variant> conquered)
        {
            GDict @out = new GDict();
            // Ostia Minor, the first row, stands alone until it is conquered
            long open = 1;
            if (!continents.IsEmpty() && conquered.Has(continents[0]["id"]))
            {
                open = OFFERED;
            }
            // unconquered continents that are not the capital
            long left = 0;
            foreach (GDict def in continents)
            {
                string id = def["id"];
                if (conquered.Has(id))
                {
                    @out[id] = State.CONQUERED;
                }
                else if (Gd.Truthy(def.Get("capital", false)))
                {
                    @out[id] = State.LOCKED;
                }
                else
                {
                    @out[id] = (left < open ? State.AVAILABLE : State.LOCKED);
                    left += 1;
                }
            }
            foreach (GDict def in continents)
            {
                if (Gd.Truthy(def.Get("capital", false)) && @out[def["id"]] == State.LOCKED && left == 0)
                {
                    @out[def["id"]] = State.AVAILABLE;
                }
            }
            return @out;
        }

        void _InitFields()
        {
        }
        public Campaign() { _InitFields(); }
    }
}
