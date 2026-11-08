// Generated from sim/upgrade_tree.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class UpgradeTree : RefCounted
    {
        public static implicit operator UpgradeTree(Variant v) => (UpgradeTree)v.Obj;

        // The upgrade tree: definitions (data/upgrades.json), the levels bought, and the stats they
        // produce on top of a species. Pure: no nodes, no files. A definition with a "species" key
        // belongs to that species' own branch and is left out of every other species' tree.
        // Rings (tuning "tree", ROADMAP E): a species listed there grows its tree outward in rings, each
        // node a kind (stat, verb, stage); only the open rings can be bought, the next one shows as
        // shapes, the rest stay hidden (R 1.4, R 16.3). A species not listed keeps the whole tree open.
        // Conquest bonuses (D-421, plan row F4) ride the same path: the picks a save holds scale the
        // stats after the upgrades, so combat reads them as it reads any upgrade.
        // How much of a node the tree screen may show (R 16.3).
        public static class Reveal
        {
            public const long HIDDEN = 0;
            public const long SHAPE = 1;
            public const long FULL = 2;
        }
        public GDict defs = new GDict();
        public GArray<string> order = new GArray<string>();
        public GDict levels = new GDict();
        // Every price x this (data/species.json cost_mult of the kaiju's species, D-167 pacing bar);
        // 1 for "".
        public double costMult = 1.0;
        // The species' rings from the centre out (tuning "tree" "species"): each {"stage", "target"}.
        // Empty: no rings, every node open.
        public GArray<Variant> rings = Gd.Arr();
        // The conquest bonus ids picked (the save's "bonuses" values, Content.bonus).
        public GArray<string> bonuses = new GArray<string>();
        public GDict _tiers = new GDict();
        // species_id "" keeps every branch (data checks); a game passes its kaiju's species, and its
        // save's "bonuses" (continent id -> bonus id picked) as picked.

        public UpgradeTree(GArray<GDict> definitions, GDict savedLevels, string speciesId, GDict picked)
        {
            _InitFields();
            foreach (string continent in picked)
            {
                bonuses.Append(Gd.Str(picked[continent]));
            }
            foreach (GDict def in definitions)
            {
                var owner = Gd.Str(def.Get("species", ""));
                if (speciesId != "" && owner != "" && owner != speciesId)
                {
                    continue;
                }
                string id = def["id"];
                defs[id] = def;
                order.Append(id);
            }
            if (speciesId != "")
            {
                costMult = Num.F(Content.SpeciesDef(speciesId).Get("cost_mult", 1.0));
                GDict ringed = Content.Section("tree").Get("species", new GDict());
                GDict own = ringed.Get(speciesId, new GDict());
                rings = own.Get("rings", Gd.Arr());
            }
            // Old saves keep every level they bought: ids never change and levels are only clamped
            // to today's max (a save owning a node in a ring not yet open still owns it).
            foreach (string id in savedLevels)
            {
                if (defs.Has(id))
                {
                    levels[id] = Gd.Clampi(Num.I(savedLevels[id]), 0, MaxLevel(id));
                }
            }
        }
        public UpgradeTree(GArray<GDict> definitions, GDict savedLevels, string speciesId) : this(definitions, savedLevels, speciesId, new GDict()) { }
        public UpgradeTree(GArray<GDict> definitions, GDict savedLevels) : this(definitions, savedLevels, "", new GDict()) { }
        public UpgradeTree(GArray<GDict> definitions) : this(definitions, new GDict(), "", new GDict()) { }

        public long Level(string id)
        {
            return Num.I(levels.Get(id, 0));
        }

        public long MaxLevel(string id)
        {
            GDict def = defs[id];
            return Num.I(def.Get("max_level", 1));
        }

        public bool IsMaxed(string id)
        {
            return Level(id) >= MaxLevel(id);
        }
        // Rubble for the next level, or -1 when maxed.

        public long Cost(string id)
        {
            GDict def = defs[id];
            GArray<Variant> costs = def["cost"];
            long next = Level(id);
            if ((next >= costs.Size() || IsMaxed(id)))
            {
                return -1;
            }
            return Gd.Roundi(Num.F(costs[next]) * costMult);
        }
        // Every prerequisite owned at level 1 or more, in an open ring.

        public bool IsUnlocked(string id)
        {
            if (!(RingOpen(Ring(id))))
            {
                return false;
            }
            GDict def = defs[id];
            GArray<Variant> requires = def.Get("requires", Gd.Arr());
            foreach (string req in requires)
            {
                if (Level(req) < 1)
                {
                    return false;
                }
            }
            return true;
        }
        // The node's ring, 1 at the centre (1 when the species has no rings).

        public long Ring(string id)
        {
            GDict def = defs[id];
            return Num.I(def.Get("ring", 1));
        }
        // "stat", "verb" or "stage"; a node without a kind is a stage if it grows the kaiju, else a stat.

        public string Kind(string id)
        {
            GDict def = defs[id];
            if (def.Has("kind"))
            {
                return Gd.Str(def["kind"]);
            }
            GDict effects = def.Get("effects", new GDict());
            return (effects.Has("size") ? "stage" : "stat");
        }
        // The growth stage the kaiju has reached: 1 plus the evolutions owned.

        public long Stage()
        {
            long @out = 1;
            foreach (string id in order)
            {
                if (Kind(id) == "stage")
                {
                    @out += Level(id);
                }
            }
            return @out;
        }
        // A ring can be bought from once the kaiju has reached its stage and owns a node of the ring
        // before it (ring 1 always). Every ring is open when the species has no rings.

        public bool RingOpen(long r)
        {
            if ((rings.IsEmpty() || r <= 1))
            {
                return true;
            }
            if (r > rings.Size())
            {
                return false;
            }
            GDict ringDef = rings[r - 1];
            if (Stage() < Num.I(ringDef["stage"]))
            {
                return false;
            }
            foreach (string id in order)
            {
                if (Ring(id) == r - 1 && Level(id) > 0)
                {
                    return true;
                }
            }
            return false;
        }
        // What the tree screen shows of a node: in full when its ring is open or it is owned; as a
        // shape in the next ring out, and an evolution always (the landmark ahead); else nothing.

        public long RevealOf(string id)
        {
            long r = Ring(id);
            if ((Level(id) > 0 || RingOpen(r)))
            {
                return Reveal.FULL;
            }
            if ((Kind(id) == "stage" || RingOpen(r - 1)))
            {
                return Reveal.SHAPE;
            }
            return Reveal.HIDDEN;
        }

        public bool CanBuy(string id, long rubble)
        {
            return IsUnlocked(id) && !IsMaxed(id) && Cost(id) <= rubble;
        }
        // Buys one level and returns what it cost (0 if it could not be bought).

        public long Buy(string id, long rubble)
        {
            if (!CanBuy(id, rubble))
            {
                return 0;
            }
            long price = Cost(id);
            levels[id] = Level(id) + 1;
            return price;
        }

        public long LevelsOwned()
        {
            long total = 0;
            foreach (string id in order)
            {
                total += Level(id);
            }
            return total;
        }

        public long LevelsTotal()
        {
            long total = 0;
            foreach (string id in order)
            {
                total += MaxLevel(id);
            }
            return total;
        }
        // Base stats with every bought level's effects added, then each picked bonus's scale: a stat
        // grows by the fractions on it, summed (two +10% picks are +20%, not +21%).

        public GDict Apply(GDict @base, string speciesId = "")
        {
            GDict @out = @base.Duplicate();
            foreach (string id in order)
            {
                long owned = Level(id);
                if (owned == 0)
                {
                    continue;
                }
                GDict def = defs[id];
                GDict effects = EffectsFor(def, speciesId);
                foreach (string stat in effects)
                {
                    @out[stat] = Num.F(@out.Get(stat, 0.0)) + Num.F(effects[stat]) * owned;
                }
            }
            GDict fractions = new GDict();
            foreach (string id in bonuses)
            {
                GDict pick = Content.Bonus(id);
                GDict scale = pick.Get("scale", new GDict());
                foreach (string stat in scale)
                {
                    fractions[stat] = Num.F(fractions.Get(stat, 0.0)) + Num.F(scale[stat]);
                }
            }
            foreach (string stat in fractions)
            {
                @out[stat] = Num.F(@out.Get(stat, 0.0)) * (1.0 + Num.F(fractions[stat]));
            }
            return @out;
        }
        // The size tier a node belongs to: 1 plus the evolutions (nodes with a "size" effect) in its
        // prerequisite chain. The evolution node itself belongs to the tier it is bought in.

        public long TierOf(string id)
        {
            if (_tiers.Has(id))
            {
                return Num.I(_tiers[id]);
            }
            GDict def = defs[id];
            long tier = 1;
            GArray<Variant> requires = def.Get("requires", Gd.Arr());
            foreach (string req in requires)
            {
                if (!defs.Has(req))
                {
                    continue;
                }
                GDict reqDef = defs[req];
                GDict effects = reqDef.Get("effects", new GDict());
                tier = Gd.Maxi(tier, TierOf(req) + ((effects.Has("size") ? 1 : 0)));
            }
            _tiers[id] = tier;
            return tier;
        }
        // Levels bought on this tier's own nodes: the growth the army has seen since the last
        // evolution. Resets to 0 the moment the kaiju evolves.

        public long LevelsOwnedAtTier(long tier)
        {
            long total = 0;
            foreach (string id in order)
            {
                if (TierOf(id) == tier)
                {
                    total += Level(id);
                }
            }
            return total;
        }
        // Stats for a run: the shared base, the species' own values over it, then upgrades.
        // "growth" = every level owned (body scale); "stage_growth" = levels owned on the current
        // tier's nodes (the army's in-stage escalation, CityGrowth.for_stats).

        public static GDict RunStats(GDict @base, GDict species, UpgradeTree tree)
        {
            GDict stats = @base.Duplicate();
            GDict own = species.Get("stats", new GDict());
            foreach (string stat in own)
            {
                stats[stat] = Num.F(own[stat]);
            }
            GDict @out = tree.Apply(stats, Gd.Str(species.Get("id", "")));
            @out["growth"] = Gd.Float(tree.LevelsOwned());
            @out["stage_growth"] = Gd.Float(tree.LevelsOwnedAtTier(Num.I(@out.Get("size", 1))));
            return @out;
        }
        // An upgrade's effects for a species: its "species_effects" entry when it has one (an upgrade
        // that differs by species), else its "effects".

        public static GDict EffectsFor(GDict def, string speciesId)
        {
            GDict own = def.Get("species_effects", new GDict());
            GDict effects = own.Get(speciesId, def.Get("effects", new GDict()));
            return effects;
        }
        // An upgrade's description for a species: its "species_desc" entry when it has one, else "desc".

        public static string DescFor(GDict def, string speciesId)
        {
            GDict own = def.Get("species_desc", new GDict());
            return Gd.Str(own.Get(speciesId, def.Get("desc", "")));
        }

        void _InitFields()
        {
        }
    }
}
