// The evolution tree without the screen: the map (tests/lib/tree_map.gd line for line: every node inside its
// stage's ring, none touching, the camera's zoom and pan clamps), each node's state and words, the side panel's
// lines, a buy through the sim's tree into a save file, the demo's end and the evolution reveal's numbers.
using System;
using System.Collections.Generic;
using System.IO;
using Kaiju.Game;
using Kaiju.Sim;

static class TreeCheck
{
    const string CROC = "reptilian";
    const int CROC_NODES = 58;
    static readonly Vector2 SCREEN = new Vector2(1920, 1080);
    // The map beside the side panel at 1080p, smaller than the screen (a fit there fits the screen).
    static readonly Vector2 AREA = new Vector2(1300, 1000);

    static int checks, failed;
    static double fit;

    public static int Run(string repoRoot)
    {
        Kaiju.Sim.FileAccess.Root = repoRoot;
        checks = failed = 0;
        string oldRoot = UserDir.Root, oldLanguage = Tr.Language;
        int oldSlot = SaveFile.Slot;
        string temp = Path.Combine(Path.GetTempPath(), "kaiju_treecheck_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temp);
        try
        {
            UserDir.Root = temp;
            Tr.Load(File.ReadAllText(Path.Combine(repoRoot, "data", "i18n", "strings.csv")));
            Tr.Language = "en";
            GDict view = Content.Section("tree")["view"];
            fit = Num.F(view["fit_margin"]);
            MapRings();
            MapOverlap();
            MapFit();
            ViewZoomClamp();
            ViewPanClamp();
            ViewZoomCursor();
            OpensOnNewest();
            NodeWords();
            PanelWords();
            Buying();
            DemoEnd();
            Reveal();
        }
        finally
        {
            UserDir.Root = oldRoot;
            Tr.Language = oldLanguage;
            SaveFile.Slot = oldSlot;
            try { Directory.Delete(temp, true); } catch (IOException) { }
        }
        Console.WriteLine($"tree: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL tree: " + what);
    }

    static UpgradeTree Tree(GDict levels = null)
    {
        return new UpgradeTree(Content.Upgrades(), levels ?? new GDict(), CROC);
    }

    // The croc's map, capstones marked as the upgrade screen marks them.
    static TreeLayout Map()
    {
        UpgradeTree tree = Tree();
        return TreeLayout.Build(tree, TreeText.Ultimates(tree));
    }

    static bool Encloses(Rect2 outer, Rect2 inner)
    {
        return inner.position.x >= outer.position.x && inner.position.y >= outer.position.y
            && inner.end.x <= outer.end.x && inner.end.y <= outer.end.y;
    }

    // D-275 bar 5: every node's box lies inside its own ring's band, and the bands never overlap.
    static void MapRings()
    {
        var bad = new List<string>();
        UpgradeTree tree = Tree();
        TreeLayout map = Map();
        foreach (string id in tree.order)
        {
            int r = (int)tree.Ring(id);
            Rect2 box = map.Rect(id);
            Vector2[] corners = { box.position, box.end, new Vector2(box.end.x, box.position.y), new Vector2(box.position.x, box.end.y) };
            foreach (Vector2 corner in corners)
            {
                double off = Math.Abs(corner.Length() - map.radii[r - 1]);
                if (off > map.halfDepth[r - 1] + 0.01) bad.Add($"{id} leaves ring {r} by {off:F0}");
            }
        }
        for (int k = 0; k < map.radii.Count - 1; k++)
            if (map.radii[k] + map.halfDepth[k] >= map.radii[k + 1] - map.halfDepth[k + 1]) bad.Add($"rings {k + 1} and {k + 2} overlap");
        Check(bad.Count == 0, "every node inside its own stage ring: " + string.Join("; ", bad));
        Check(map.radii.Count == 4, $"the croc map has {map.radii.Count} rings");
        Console.WriteLine($"tree: rings at radius {string.Join(", ", map.radii.ConvertAll(x => x.ToString("F1")))}, bounds {map.bounds}");
    }

    // D-275 bar 5: no two nodes' boxes overlap.
    static void MapOverlap()
    {
        var bad = new List<string>();
        TreeLayout map = Map();
        for (int a = 0; a < map.placed.Count; a++)
            for (int b = a + 1; b < map.placed.Count; b++)
                if (map.Rect(map.placed[a]).Intersects(map.Rect(map.placed[b]))) bad.Add(map.placed[a] + " and " + map.placed[b]);
        Check(bad.Count == 0, "no two nodes overlap: " + string.Join("; ", bad));
        // Twice built, the same map: a node never moves between two openings of the screen.
        TreeLayout again = Map();
        bool same = true;
        foreach (string id in map.placed) same &= map.centres[id] == again.centres[id];
        Check(same, "the map is the same on every build");
        int requires = 0;
        UpgradeTree tree = Tree();
        foreach (string id in tree.order) requires += TreeLayout.Requires(tree, id).Count;
        Check(map.links.Count == requires && requires > 0, $"one link per requirement: {map.links.Count} of {requires}");
        bool known = true;
        foreach (TreeLayout.Link link in map.links) known &= map.centres.ContainsKey(link.from) && map.centres.ContainsKey(link.to);
        Check(known, "every link joins two placed nodes");
    }

    // D-275 bar 1: zoomed all the way out, all 58 croc nodes sit inside the 16:9 screen and the map area.
    static void MapFit()
    {
        TreeLayout map = Map();
        Check(map.centres.Count == CROC_NODES, $"the croc map has {map.centres.Count} nodes");
        foreach (Vector2 viewSize in new[] { SCREEN, AREA })
        {
            var view = new TreeView(map.bounds, viewSize, fit);
            view.SetZoom(0.0);
            var outside = new List<string>();
            foreach (string id in map.placed)
            {
                Rect2 box = map.Rect(id);
                var shown = new Rect2(view.ToScreen(box.position), box.size * view.zoom);
                if (!Encloses(new Rect2(Vector2.ZERO, viewSize), shown)) outside.Add(id);
            }
            Check(Gd.IsEqualApprox(view.zoom, view.FitZoom()) && outside.Count == 0,
                $"at zoom {view.zoom:F3} every node fits {viewSize}: {string.Join(",", outside)}");
        }
    }

    // D-275 bar 1: zoom never goes past the default nor out past the whole tree.
    static void ViewZoomClamp()
    {
        var view = new TreeView(Map().bounds, SCREEN, fit);
        Check(view.FitZoom() < TreeView.DEFAULT_ZOOM, "the croc tree needs zooming out to fit");
        view.ZoomAt(SCREEN * 0.3, 1000.0);
        Check(Gd.IsEqualApprox(view.zoom, TreeView.DEFAULT_ZOOM), "zoom in stops at the default");
        view.ZoomAt(SCREEN * 0.7, 0.001);
        Check(Gd.IsEqualApprox(view.zoom, view.FitZoom()), "zoom out stops at the whole tree");
        view.SetZoom(9.0);
        Check(Gd.IsEqualApprox(view.zoom, TreeView.DEFAULT_ZOOM), "set_zoom stops at the default");
        view.SetZoom(0.0);
        view.Resize(SCREEN * 0.5);
        Check(view.zoom >= view.FitZoom() - 0.0001, "a smaller view keeps zoom inside its limits");
    }

    // D-275 bar 3: however far it pans, the tree never leaves the screen.
    static void ViewPanClamp()
    {
        TreeLayout map = Map();
        var view = new TreeView(map.bounds, SCREEN, fit);
        var bad = new List<string>();
        Vector2[] pushes = { new Vector2(1e6, 0), new Vector2(-1e6, 0), new Vector2(0, 1e6), new Vector2(0, -1e6), new Vector2(1e6, 1e6) };
        foreach (Vector2 push in pushes)
        {
            view.PanBy(push);
            var seen = new Rect2(view.ToTree(Vector2.ZERO), SCREEN / view.zoom);
            if (!Encloses(map.bounds.Grow(0.01), seen)) bad.Add($"pan {push} shows {seen} past the tree {map.bounds}");
        }
        view.LookAt(new Vector2(-1e6, 1e6));
        if (!map.bounds.HasPoint(view.centre)) bad.Add($"look_at leaves the centre at {view.centre}");
        view.SetZoom(0.0);
        view.PanBy(new Vector2(5000, -5000));
        if (view.centre.DistanceTo(map.bounds.GetCenter()) > 0.01) bad.Add($"zoomed out, the tree moves off centre to {view.centre}");
        Check(bad.Count == 0, "the tree never leaves the screen: " + string.Join("; ", bad));
    }

    // D-275 bar 2: the wheel zooms toward the cursor: the tree point under it stays under it.
    static void ViewZoomCursor()
    {
        TreeLayout map = Map();
        var view = new TreeView(map.bounds, SCREEN, fit);
        view.SetZoom(0.5);
        view.LookAt(map.bounds.GetCenter());
        var cursor = new Vector2(1100, 600);
        Vector2 under = view.ToTree(cursor);
        view.ZoomAt(cursor, 1.2);
        Check(Gd.IsEqualApprox(view.zoom, 0.6), $"the wheel zooms by its step ({view.zoom:F3})");
        Check(view.ToTree(cursor).DistanceTo(under) < 0.01, $"the point under the cursor stays put ({under} -> {view.ToTree(cursor)})");
    }

    // tests/lib/ui_tree.gd _tree_layout: with 400 biomass the screen opens at the default zoom on a node that
    // can be bought.
    static void OpensOnNewest()
    {
        UpgradeTree tree = Tree();
        string newest = TreeText.NewestBuyable(tree, 400);
        Check(tree.CanBuy(newest, 400), newest + " is buyable with 400");
        TreeLayout map = Map();
        var view = new TreeView(map.bounds, AREA, fit);
        view.LookAt(map.centres[newest]);
        Check(Gd.IsEqualApprox(view.zoom, TreeView.DEFAULT_ZOOM), "the view opens at the default zoom");
        Rect2 box = map.Rect(newest);
        Check(Encloses(new Rect2(Vector2.ZERO, AREA), new Rect2(view.ToScreen(box.position), box.size * view.zoom)), newest + " is on screen when the tree opens");
        Check(TreeText.NewestBuyable(tree, 0) != "" && !tree.CanBuy(TreeText.NewestBuyable(tree, 0), 0), "with no biomass it opens on a node still to buy");
        Console.WriteLine($"tree: opens on {newest} at {map.centres[newest]}, view centre {view.centre}");
    }

    // upgrade_node.gd: a node's state and words.
    static void NodeWords()
    {
        UpgradeTree tree = Tree();
        long cost = tree.Cost("claws");
        Check(cost == 60, $"the croc's first Swinging Tail level costs 60 ({cost})");
        Check(TreeText.StateOf(tree, "claws", 400) == "buy", "claws can be bought with 400");
        Check(TreeText.StateOf(tree, "claws", 59) == "poor", "claws is too dear with 59");
        Check(TreeText.StateOf(tree, "evolve1", 99999) == "locked", "the evolution is locked on a new croc");
        Check(TreeText.NodeText(tree, "claws", 400) == "Swinging Tail\n0/5 BUY 60", "claws reads: " + TreeText.NodeText(tree, "claws", 400));
        Check(TreeText.NodeText(tree, "claws", 59) == "Swinging Tail\n0/5 60", "claws too dear reads: " + TreeText.NodeText(tree, "claws", 59));
        Check(TreeText.NodeText(tree, "evolve1", 400) == "EVOLVE: Behemoth\n0/1 ", "the locked evolution reads: " + TreeText.NodeText(tree, "evolve1", 400));
        Check(TreeText.ShortPrice(9999) == "9999" && TreeText.ShortPrice(10000) == "10k" && TreeText.ShortPrice(24600) == "24k", "prices from 10 000 read in thousands");
        Check(TreeText.RoleOf(tree, "claws") == "plain" && TreeText.RoleOf(tree, "evolve1") == "evolve" && TreeText.RoleOf(tree, "r_beam") == "ultimate", "roles: plain, evolve, ultimate");
        Check(TreeText.Ultimates(tree).Count == 1 && TreeText.Ultimates(tree)[0] == "r_beam", "the croc has one ultimate");
        Check(TreeText.Hidden(tree, "r_beam") && !TreeText.Hidden(tree, "claws"), "ring 4 is hidden on a new croc, ring 1 shown");
        int shown = 0, shapes = 0;
        foreach (string id in tree.order)
        {
            if (!TreeText.Hidden(tree, id)) shown++;
            if (TreeText.ShapeOnly(tree, id)) { shapes++; Check(TreeText.NodeText(tree, id, 400) == "?" && TreeText.StatusLine(tree, id, 400) == "" && TreeText.Title(tree, id) == "?", id + " keeps its secret"); }
        }
        Check(shown > 0 && shown < CROC_NODES, $"a new croc sees {shown} of {CROC_NODES} nodes, {shapes} as shapes");

        var levels = new GDict { { "claws", 5L } };
        UpgradeTree maxed = Tree(levels);
        Check(TreeText.StateOf(maxed, "claws", 0) == "maxed" && TreeText.NodeText(maxed, "claws", 0) == "Swinging Tail\n5/5 MAXED", "a maxed node reads: " + TreeText.NodeText(maxed, "claws", 0));
        Check(TreeText.Liquid(maxed, "claws") == 1.0 && TreeText.Liquid(tree, "claws") == 0.0, "the cell fills with the level");

        UpgradeTree full = Full();
        Check(TreeText.NodeText(full, "r_beam", 0) == "ULTIMATE: Thunder Beam\n3/3 MAXED\n[E / Y]", "the ultimate reads: " + TreeText.NodeText(full, "r_beam", 0));
    }

    // upgrade_screen.gd _select and upgrade_readout.gd: the side panel.
    static void PanelWords()
    {
        UpgradeTree tree = Tree();
        GDict species = Content.SpeciesDef(CROC);
        Check(TreeText.Biomass(400) == "BIOMASS  400", TreeText.Biomass(400));
        string specimen = TreeText.Specimen(tree, species);
        Check(specimen == "SPECIMEN  " + Gd.Str(species["name"]).ToUpperInvariant() + "   STAGE 1 / 3", specimen);
        Check(TreeText.Title(tree, "claws") == "Swinging Tail" && TreeText.RoleText(tree, "claws") == "", "a plain node has a name and no role");
        Check(TreeText.RoleText(tree, "evolve1") == "EVOLUTION", "the evolution's role line");
        Check(TreeText.StatusLine(tree, "claws", 400) == "Level 0 / 5   Cost 60\nYou have 400 biomass\nEnter / pad A to buy", TreeText.StatusLine(tree, "claws", 400));
        Check(TreeText.StatusLine(tree, "claws", 10) == "Level 0 / 5   Cost 60\nYou have 10 biomass\n50 more needed", TreeText.StatusLine(tree, "claws", 10));
        string needs = TreeText.StatusLine(tree, "evolve1", 400);
        Check(needs.StartsWith("Level 0 / 1   Needs: Swinging Tail, Thick Hide, "), needs);
        string body = TreeText.Body(tree, "evolve1", species);
        Check(body.EndsWith("\nGrows into the adolescent.\nTowers one tier taller now fall to you."), "the evolution's words: " + body);
        Check(TreeText.Body(tree, "claws", species) == Gd.Str(((GDict)tree.defs["claws"])["desc"]), "a plain node shows its description alone");

        List<TreeText.StatRow> rows = TreeText.StatRows(tree, "claws", species);
        GDict stats = TreeText.Stats(tree, species);
        double damage = Num.F(stats["sweep_damage"]), width = Num.F(stats["sweep_width"]);
        Check(rows.Count == 2, $"Swinging Tail changes two stats ({rows.Count})");
        if (rows.Count == 2)
        {
            Check(rows[0].line == "Tail sweeps and lashes hit harder:" && rows[0].was == Tr.Format("%.0f", damage) && rows[0].after == Tr.Format("%.0f", damage + 5.0),
                $"{rows[0].line} {rows[0].was} -> {rows[0].after}");
            Check(rows[1].line == "Tail sweeps reach further:" && rows[1].was == Tr.Format("%.1f", width) && rows[1].after == Tr.Format("%.1f", width + 0.6),
                $"{rows[1].line} {rows[1].was} -> {rows[1].after}");
            Console.WriteLine($"tree: claws rows: {rows[0].line} {rows[0].was} -> {rows[0].after}; {rows[1].line} {rows[1].was} -> {rows[1].after}");
        }
        // The evolution's "size" is hidden: only what the player reads is listed.
        foreach (TreeText.StatRow row in TreeText.StatRows(tree, "evolve1", species)) Check(row.line != "size:", "a hidden stat is not listed");
        UpgradeTree maxed = Tree(new GDict { { "claws", 5L } });
        List<TreeText.StatRow> done = TreeText.StatRows(maxed, "claws", species);
        Check(done.Count == 2 && done[0].after == null, "a maxed node shows the value now and no arrow");
        Check(TreeText.StatusLine(maxed, "claws", 0) == "Level 5 / 5   MAXED", TreeText.StatusLine(maxed, "claws", 0));

        var inv = new GDict { { "fmt", "inv" }, { "unit", " a second" } };
        Check(TreeText.Fmt(inv, 0.5, true) == "2.0 a second" && TreeText.Fmt(inv, 0.5, false) == "2.0" && TreeText.Fmt(inv, 0.0, false) == "10.0", "a rate shows 1 / value: " + TreeText.Fmt(inv, 0.5, true));
        Check(TreeText.Fmt(new GDict { { "fmt", "%d" }, { "unit", " seconds" } }, 44.5, true) == "45 seconds", "a whole number rounds half up");
        Check(TreeText.Fmt(new GDict { { "fmt", "x%.2f" } }, 1.5, true) == "x1.50" && TreeText.Fmt(new GDict(), 2.26, true) == "2.3", "a share keeps two places; no format means one place: " + TreeText.Fmt(new GDict { { "fmt", "x%.2f" } }, 1.5, true) + " " + TreeText.Fmt(new GDict(), 2.26, true));

        UpgradeTree full = Full();
        string ultimate = TreeText.Body(full, "r_beam", species);
        long cooldown = Gd.Roundi(Num.F(Content.Section("powers")["ultimate_cooldown"]));
        Check(ultimate.EndsWith($"\nPress E / pad Y in a rampage; recharges in {cooldown}s."), "the ultimate says how it is fired: " + ultimate);
        Check(TreeText.RoleText(full, "r_beam") == "ULTIMATE" && TreeText.Title(full, "r_beam") == "ULTIMATE: Thunder Beam", "the ultimate's title and role");
        Check(TreeText.Specimen(full, species).EndsWith("STAGE 3 / 3"), TreeText.Specimen(full, species));
    }

    // upgrade_screen.gd _on_node_pressed and main.gd _on_bought: the buy, its sounds and the save.
    static void Buying()
    {
        SaveFile.Slot = 1;
        GDict save = SaveFile.NewSave(CROC, 7);
        save["rubble"] = 400L;
        UpgradeTree tree = TreeText.TreeOf(save);
        long rubble = Num.I(save["rubble"]);
        Check(tree.Buy("evolve1", rubble) == 0, "a locked node costs nothing and is not bought");
        long rings = TreeText.RingsOpen(tree);
        Check(rings == 1, $"a new croc has ring {rings} open");
        long price = tree.Buy("claws", rubble);
        rubble -= price;
        List<string> sounds = TreeText.BoughtSounds(tree, "claws", rings);
        Check(price == 60 && rubble == 340 && tree.Level("claws") == 1, $"claws costs 60 of 400: {price}, {rubble} left, level {tree.Level("claws")}");
        Check(sounds.Count == 1 && sounds[0] == "tree_buy", "a level bought sounds tree_buy: " + string.Join(",", sounds));
        TreeText.Bank(save, tree, rubble);
        Check(SaveFile.SaveGame(save), "the buy is saved");
        GDict disk = SaveFile.LoadGame();
        GDict levels = disk.Get("levels", new GDict());
        Check(Num.I(disk.Get("rubble", 0L)) == 340 && Num.I(levels.Get("claws", 0L)) == 1, $"the file holds 340 biomass and claws 1: {Gd.Str(disk.Get("rubble", 0L))}, {Gd.Str(levels.Get("claws", 0L))}");
        Check(!TreeText.DemoOver(save, tree), "one node does not end the demo");
        Check(!TreeText.Evolves(tree, "claws") && TreeText.Evolves(tree, "evolve1"), "only an evolution plays the reveal");
        Check(TreeText.NodeText(tree, "claws", rubble) == "Swinging Tail\n1/5 BUY " + tree.Cost("claws"), "the node shows the next price: " + TreeText.NodeText(tree, "claws", rubble));
        Check(tree.Buy("claws", 0) == 0 && tree.Level("claws") == 1, "no biomass, no buy");
        // The last level of a node sounds tree_maxed.
        UpgradeTree four = Tree(new GDict { { "claws", 4L } });
        long before = TreeText.RingsOpen(four);
        Check(four.Buy("claws", 100000) > 0 && TreeText.BoughtSounds(four, "claws", before)[0] == "tree_maxed", "the last level sounds tree_maxed");
        // An evolution sounds tree_evolve, and tree_ring_open when it opens the next ring.
        UpgradeTree ring1 = Tree(AllBut("evolve1", 1));
        before = TreeText.RingsOpen(ring1);
        long evolve = ring1.Buy("evolve1", 1000000);
        List<string> evolveSounds = TreeText.BoughtSounds(ring1, "evolve1", before);
        Check(evolve > 0 && evolveSounds[0] == "tree_evolve", "an evolution sounds tree_evolve: " + string.Join(",", evolveSounds));
        Check(TreeText.RingsOpen(ring1) == before + 1 == evolveSounds.Contains("tree_ring_open"), $"a ring opening sounds tree_ring_open (rings {before} -> {TreeText.RingsOpen(ring1)}: {string.Join(",", evolveSounds)})");
        Console.WriteLine($"tree: evolve1 costs {evolve}, rings open {before} -> {TreeText.RingsOpen(ring1)}, sounds {string.Join(",", evolveSounds)}");
    }

    // Every node of ring `ring` and inside it at its top level, but `skip` one short.
    static GDict AllBut(string skip, long ring)
    {
        UpgradeTree tree = Tree();
        var levels = new GDict();
        foreach (string id in tree.order)
        {
            if (tree.Ring(id) > ring) continue;
            levels[id] = id == skip ? tree.MaxLevel(id) - 1 : tree.MaxLevel(id);
        }
        return levels;
    }

    static UpgradeTree Full()
    {
        return Tree(AllBut("", 99));
    }

    // main.gd _on_bought: the demo is over when the buy leaves every node owned, once.
    static void DemoEnd()
    {
        GDict save = SaveFile.NewSave(CROC, 7);
        save["levels"] = AllBut("r_beam", 99);
        save["rubble"] = 10000000L;
        UpgradeTree tree = TreeText.TreeOf(save);
        Check(tree.LevelsOwned() == tree.LevelsTotal() - 1 && !TreeText.DemoOver(save, tree), $"one level short is not the end ({tree.LevelsOwned()} of {tree.LevelsTotal()})");
        long price = tree.Buy("r_beam", Num.I(save["rubble"]));
        Check(price > 0, "the last level can be bought");
        TreeText.Bank(save, tree, Num.I(save["rubble"]) - price);
        Check(Demo.Enabled() && TreeText.DemoOver(save, tree), "the last level bought ends the demo");
        save["demo_done"] = true;
        Check(!TreeText.DemoOver(save, tree), "the demo ends once: not again with demo_done set");
        Console.WriteLine($"tree: demo ends at {tree.LevelsOwned()} of {tree.LevelsTotal()} levels, last price {price}");
    }

    // evolution_reveal.gd: the body before the purchase against the body after.
    static void Reveal()
    {
        GDict save = SaveFile.NewSave(CROC, 7);
        GDict levels = AllBut("evolve1", 1);
        levels["evolve1"] = 1L;
        save["levels"] = levels;
        UpgradeTree tree = TreeText.TreeOf(save);
        TreeText.Reveal r = TreeText.RevealOf(save, tree, "evolve1");
        Check(r.title == "Behemoth" && r.headline == "BEHEMOTH", $"the reveal names the stage: {r.title} / {r.headline}");
        Check(r.stageBefore == "baby" && r.stageAfter == "adolescent", $"young croc to Behemoth: {r.stageBefore} -> {r.stageAfter}");
        Check(r.floorsAfter > r.floorsBefore && r.floorsBefore > 0, $"the body grows: {r.floorsBefore} -> {r.floorsAfter} floors");
        Check(r.towerFloors > 0, $"towers up to {r.towerFloors} floors");
        Check(r.lines == $"Stands {r.floorsAfter} floors tall (was {r.floorsBefore})\nTowers up to {r.towerFloors} floors now fall to you", r.lines);
        Check(TreeText.TitleOf(new GDict { { "name", "EVOLVE：  Colossus " } }) == "Colossus" && TreeText.TitleOf(new GDict { { "name", "Plain" } }) == "Plain", "the title is what follows the last colon");
        Console.WriteLine("tree: reveal " + r.headline + ": " + r.lines.Replace("\n", " / "));
    }
}
