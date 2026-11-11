// What the evolution tree screen says, without the screen: a node's role, state and words (scenes/
// upgrade_node.gd), the side panel's title, body, stat rows and status line (upgrade_screen.gd,
// upgrade_readout.gd), the buy's sounds, what a buy writes to the save and when the demo ends (main.gd
// _on_bought), and the evolution reveal's numbers (evolution_reveal.gd). Plain C#, so TreeCheck checks it.
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public static class TreeText
    {
        // What a node in the next ring out shows: its shape, not its name or price (R 16.3).
        public const string SHAPE_TEXT = "?";
        // Keeps "fall to you." together when the line wraps.
        public const string NBSP = " ";
        // The kaiju model's height in floors at scale 1 (kaiju_model.gd MODEL_HEIGHT).
        public const double MODEL_HEIGHT = 10.0;
        // The stages a specimen grows through: young croc, Behemoth, Colossus (upgrade_screen.gd "STAGE %d / %d").
        public const long STAGES = 3;

        // One stat a node changes: the words, the value now and (when a level is left to buy) after it.
        public struct StatRow
        {
            public string line, was, after;
        }

        // The evolution reveal's words and numbers.
        public struct Reveal
        {
            public string title, headline, lines;
            public long floorsBefore, floorsAfter, towerFloors;
            public string stageBefore, stageAfter;
        }

        // "ultimate": the species' ultimate; "evolve": grows the kaiju a size; "branch": the rest of the
        // species' own nodes; "plain": the shared tree.
        public static string RoleOf(UpgradeTree tree, string id)
        {
            GDict def = tree.defs[id];
            GDict effects = def.Get("effects", new GDict());
            if (effects.Has("size")) return "evolve";
            if (def.Get("ultimate", false) == true) return "ultimate";
            return Gd.Str(def.Get("species", "")) == "" ? "plain" : "branch";
        }

        // The nodes drawn as a capstone (tree_area.gd: role "ultimate").
        public static List<string> Ultimates(UpgradeTree tree)
        {
            var o = new List<string>();
            foreach (string id in tree.order)
                if (RoleOf(tree, id) == "ultimate") o.Add(id);
            return o;
        }

        // maxed, locked, or (unlocked) buy when `rubble` covers the price, else poor.
        public static string StateOf(UpgradeTree tree, string id, long rubble)
        {
            if (tree.IsMaxed(id)) return "maxed";
            if (!tree.IsUnlocked(id)) return "locked";
            return tree.CanBuy(id, rubble) ? "buy" : "poor";
        }

        public static bool Hidden(UpgradeTree tree, string id)
        {
            return tree.RevealOf(id) == UpgradeTree.Reveal.HIDDEN;
        }

        public static bool ShapeOnly(UpgradeTree tree, string id)
        {
            return tree.RevealOf(id) == UpgradeTree.Reveal.SHAPE;
        }

        // A price as a node shows it: in full below 10 000, else in thousands ("32k").
        public static string ShortPrice(long price)
        {
            return price < 10000 ? Gd.Str(price) : Tr.Format("%dk", Gd.Floori(price / 1000.0));
        }

        // The cost line of a node: "BUY 60" when affordable, the bare price when not, MAXED, or nothing (locked).
        public static string CostText(UpgradeTree tree, string id, long rubble)
        {
            string state = StateOf(tree, id, rubble);
            if (state == "maxed") return Tr.T("MAXED");
            if (state == "locked") return "";
            string price = ShortPrice(tree.Cost(id));
            return state == "buy" ? Tr.F("BUY %s", price) : price;
        }

        // The words on a node: its name, level / max and cost; the ultimate adds its button.
        public static string NodeText(UpgradeTree tree, string id, long rubble)
        {
            if (ShapeOnly(tree, id)) return SHAPE_TEXT;
            GDict def = tree.defs[id];
            string tag = RoleOf(tree, id) == "ultimate" ? "\n[E / Y]" : "";
            return Tr.Format("%s\n%d/%d %s%s", Tr.T(Gd.Str(def["name"])), tree.Level(id), tree.MaxLevel(id), CostText(tree, id, rubble), tag);
        }

        // The share of a node's cell filled with Special K.
        public static double Liquid(UpgradeTree tree, string id)
        {
            if (ShapeOnly(tree, id)) return 0.0;
            return (double)tree.Level(id) / Gd.Maxf(1.0, tree.MaxLevel(id));
        }

        // The node the tree opens on (D-275): the one that can be bought now in the outermost ring, the last
        // in data order; else the outermost one still to buy; else the first.
        public static string NewestBuyable(UpgradeTree tree, long rubble)
        {
            string best = "", fallback = "";
            foreach (string id in tree.order)
            {
                if (tree.CanBuy(id, rubble))
                {
                    if (best == "" || tree.Ring(id) >= tree.Ring(best)) best = id;
                }
                else if (tree.IsUnlocked(id) && !tree.IsMaxed(id))
                {
                    if (fallback == "" || tree.Ring(id) >= tree.Ring(fallback)) fallback = id;
                }
            }
            if (best != "") return best;
            return fallback != "" ? fallback : tree.order[0];
        }

        // The outermost open ring (1-based, as UpgradeTree.Ring).
        public static long RingsOpen(UpgradeTree tree)
        {
            long n = 0;
            for (long r = 1; r <= tree.rings.Size(); r++)
                if (tree.RingOpen(r)) n = r;
            return n;
        }

        // The sounds of a buy that went through, in order (upgrade_screen.gd _play_bought).
        public static List<string> BoughtSounds(UpgradeTree tree, string id, long ringsBefore)
        {
            var o = new List<string>();
            if (tree.Kind(id) == "stage") o.Add("tree_evolve");
            else if (tree.IsMaxed(id)) o.Add("tree_maxed");
            else o.Add("tree_buy");
            if (RingsOpen(tree) > ringsBefore) o.Add("tree_ring_open");
            return o;
        }

        public static string Biomass(long value)
        {
            return Tr.F("BIOMASS  %d", value);
        }

        // The readout's header: the specimen's species and growth stage.
        public static string Specimen(UpgradeTree tree, GDict species)
        {
            return Tr.F("SPECIMEN  %s   STAGE %d / %d", Tr.T(Gd.Str(species["name"])).ToUpperInvariant(), tree.Stage(), STAGES);
        }

        public static string Title(UpgradeTree tree, string id)
        {
            if (ShapeOnly(tree, id)) return SHAPE_TEXT;
            GDict def = tree.defs[id];
            return Tr.T(Gd.Str(def["name"]));
        }

        public static string RoleText(UpgradeTree tree, string id)
        {
            if (ShapeOnly(tree, id)) return "";
            string role = RoleOf(tree, id);
            return role == "evolve" ? Tr.T("EVOLUTION") : role == "ultimate" ? Tr.T("ULTIMATE") : "";
        }

        // The run stats the panel reads (UpgradeTree.run_stats over the kaiju's base numbers).
        public static GDict Stats(UpgradeTree tree, GDict species)
        {
            return UpgradeTree.RunStats(Content.Section("kaiju"), species, tree);
        }

        // kaiju_model.gd stage_for.
        public static string StageFor(long sizeTier)
        {
            if (sizeTier <= 1) return "baby";
            return sizeTier == 2 ? "adolescent" : "adult";
        }

        static string GrowsInto(string stage)
        {
            if (stage == "baby") return Tr.T("Grows into the baby.");
            if (stage == "adolescent") return Tr.T("Grows into the adolescent.");
            return Tr.T("Grows into the adult.");
        }

        // The node's words: its description, what an evolution grows into, how the ultimate is fired.
        public static string Body(UpgradeTree tree, string id, GDict species)
        {
            if (ShapeOnly(tree, id)) return "";
            GDict def = tree.defs[id];
            string body = Tr.T(UpgradeTree.DescFor(def, Gd.Str(species["id"])));
            string role = RoleOf(tree, id);
            if (role == "evolve" && !tree.IsMaxed(id))
            {
                GDict stats = Stats(tree, species);
                body += "\n" + GrowsInto(StageFor(Num.I(stats.Get("size", 1L)) + 1));
                body += "\n" + Tr.F("Towers one tier taller now fall%sto%syou.", NBSP, NBSP);
            }
            if (role == "ultimate")
            {
                double cooldown = Num.F(Content.Section("powers").Get("ultimate_cooldown", 0.0));
                body += "\n" + Tr.F("Press E / pad Y in a rampage; recharges in %ds.", Gd.Roundi(cooldown));
            }
            return body;
        }

        // A stat's value as its data line formats it ("inv" shows 1 / value, a rate), with its unit.
        public static string Fmt(GDict entry, double value, bool withUnit)
        {
            string fmt = Gd.Str(entry.Get("fmt", "%.1f"));
            string unit = withUnit ? Tr.T(Gd.Str(entry.Get("unit", ""))) : "";
            if (fmt == "inv") return Tr.Format("%.1f", 1.0 / Gd.Maxf(0.1, value)) + unit;
            if (fmt.Contains("%d")) return Tr.Format(fmt, Gd.Roundi(value)) + unit;
            return Tr.Format(fmt, value) + unit;
        }

        // Only the stats this node changes, each in plain words from data (D-077): the words, the value now and
        // the value after the next level (null when the node is maxed: the unit then sits on the value now).
        public static List<StatRow> StatRows(UpgradeTree tree, string id, GDict species)
        {
            var o = new List<StatRow>();
            if (ShapeOnly(tree, id)) return o;
            GDict def = tree.defs[id];
            GDict effects = UpgradeTree.EffectsFor(def, Gd.Str(species["id"]));
            GDict stats = Stats(tree, species);
            int steps = tree.IsMaxed(id) ? 0 : 1;
            GDict words = Content.Section("stat_text");
            foreach (string stat in effects)
            {
                GDict entry = words.Get(stat, new GDict());
                if (entry.Get("hidden", false) == true) continue;
                double now = Num.F(stats.Get(stat, 0.0));
                var row = new StatRow();
                row.line = Tr.F("%s:", Tr.T(Gd.Str(entry.Get("line", stat))));
                row.was = Fmt(entry, now, steps == 0);
                row.after = steps > 0 ? Fmt(entry, now + Num.F(effects[stat]), true) : null;
                o.Add(row);
            }
            return o;
        }

        // Level, then what stands between the player and the node: maxed, what it needs, or its price.
        public static string StatusLine(UpgradeTree tree, string id, long rubble)
        {
            if (ShapeOnly(tree, id)) return "";
            string head = Tr.F("Level %d / %d", tree.Level(id), tree.MaxLevel(id)) + "   ";
            if (tree.IsMaxed(id)) return head + Tr.T("MAXED");
            if (!tree.IsUnlocked(id))
            {
                var names = new List<string>();
                foreach (string req in TreeLayout.Requires(tree, id))
                {
                    if (tree.Level(req) >= 1) continue;
                    GDict reqDef = tree.defs[req];
                    names.Add(Tr.T(Gd.Str(reqDef["name"])));
                }
                // Owned from an older save in a ring that is not open yet: nothing named to buy first.
                if (names.Count == 0) return head + Tr.T("Not yet");
                return head + Tr.F("Needs: %s", string.Join(", ", names));
            }
            // Three short lines, so no wrap ever leaves a dash or a lone word at a line end.
            string have = Tr.Format(Tr.T("Cost %d") + "\n" + Tr.T("You have %d biomass") + "\n", tree.Cost(id), rubble);
            if (tree.CanBuy(id, rubble)) return head + have + Tr.T("Enter / pad A to buy");
            return head + have + Tr.F("%d more needed", tree.Cost(id) - rubble);
        }

        // ---- a buy, as main.gd banks it ---------------------------------------------------------------------

        // The tree a save holds (main.gd _build_tree).
        public static UpgradeTree TreeOf(GDict save)
        {
            GDict levels = save.Get("levels", new GDict());
            GDict picked = save.Get("bonuses", new GDict());
            return new UpgradeTree(Content.Upgrades(), levels, Gd.Str(save.Get("species", "")), picked);
        }

        // Writes a buy into the save in memory: the biomass left and the levels owned (main.gd _on_bought, before
        // its first save_game).
        public static void Bank(GDict save, UpgradeTree tree, long rubble)
        {
            save["rubble"] = rubble;
            save["levels"] = tree.levels.Duplicate();
        }

        // True when this buy was the demo's last: every node owned and the demo's end not shown before
        // (main.gd: Demo.complete(_tree) and _save.get("demo_done", false) != true).
        public static bool DemoOver(GDict save, UpgradeTree tree)
        {
            return Demo.Complete(tree) && save.Get("demo_done", false) != true;
        }

        // True when buying `id` grows the kaiju a size: the evolution reveal plays (main.gd: effects.has("size")).
        public static bool Evolves(UpgradeTree tree, string id)
        {
            GDict def = tree.defs[id];
            GDict effects = def.Get("effects", new GDict());
            return effects.Has("size");
        }

        // ---- the evolution reveal ---------------------------------------------------------------------------

        // The reveal's headline: the node's name after its last colon ("EVOLVE: Behemoth" -> "Behemoth").
        public static string TitleOf(GDict def)
        {
            string full = Tr.T(Gd.Str(def.Get("name", ""))).Replace("：", ":");
            string[] parts = full.Split(':');
            return parts[parts.Length - 1].Trim();
        }

        static string StageName(string stage)
        {
            return stage == "baby" || stage == "adolescent" || stage == "adult" ? Tr.T(stage) : stage;
        }

        // The body before this purchase against the body after (main.gd _reveal, evolution_reveal.gd setup and
        // _swap). `tree` already holds the bought level of `id`.
        public static Reveal RevealOf(GDict save, UpgradeTree tree, string id)
        {
            GDict species = Content.SpeciesDef(Gd.Str(save.Get("species", "")));
            GDict beforeLevels = tree.levels.Duplicate();
            beforeLevels[id] = tree.Level(id) - 1;
            GDict picked = save.Get("bonuses", new GDict());
            var beforeTree = new UpgradeTree(Content.Upgrades(), beforeLevels, Gd.Str(save.Get("species", "")), picked);
            GDict after = Stats(tree, species);
            GDict before = Stats(beforeTree, species);
            // The new stage's city (D-039), so "towers up to N floors" matches the city it will face.
            GDict city = CityGrowth.ForStats(after)["city"];
            long sizeAfter = Num.I(after.Get("size", 1L));
            var o = new Reveal();
            o.stageBefore = StageFor(Num.I(before.Get("size", 1L)));
            o.stageAfter = StageFor(sizeAfter);
            o.floorsBefore = Gd.Roundi(MODEL_HEIGHT * Growth.BodyScale(before, city));
            o.floorsAfter = Gd.Roundi(MODEL_HEIGHT * Growth.BodyScale(after, city));
            o.towerFloors = System.Math.Min(sizeAfter * Num.I(city["tier_height"]), Num.I(city["max_height"]));
            GDict def = tree.defs[id];
            o.title = TitleOf(def);
            o.headline = o.title.ToUpperInvariant();
            if (o.title.Length == 0)
                o.headline = Tr.Format("%s  %s", Tr.T(Gd.Str(species["name"])).ToUpperInvariant(), StageName(o.stageAfter).ToUpperInvariant());
            o.lines = Tr.F("Stands %d floors tall (was %d)\nTowers up to %d floors now fall to you", o.floorsAfter, o.floorsBefore, o.towerFloors);
            return o;
        }
    }
}
