// Between-rampage screen (scenes/upgrade_screen.gd, D-275): the evolution tree as a map that zooms and pans,
// a side panel with the selected node's words (what it does, each stat now and after the next level, level,
// cost), the biomass banked, and the way back to a rampage. A buy goes through the sim's tree and is saved
// in main.gd's order (_on_bought); an evolution plays the growth reveal; the last level ends the demo.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using S = Kaiju.Sim;

public static class TreeScreen
{
    // upgrade_screen.gd: the screen's margin, its gaps, the title's size, the stat rows' "now" column.
    const float MARGIN = 32f, COLUMN_GAP = 16f, ROW_GAP = 24f, SIDE_GAP = 12f;
    const int TITLE_SIZE = 48;
    const float NOW_WIDTH = 64f, STAT_GAP = 2f, VALUE_GAP = 10f;
    const float GO_HEIGHT = 80f, ENDLESS_HEIGHT = 64f;

    // One open tree screen: what a press, a hover or a buy needs.
    sealed class Open
    {
        public RectTransform screen;
        public S.GDict save, species;
        public S.UpgradeTree tree;
        public long rubble;
        public string selected = "";
        public TreePlate plate;
        public Text biomass, specimen, title, role, body, status;
        public RectTransform stats;
        public KitButton go, endless, menu;
        public Action onDemoEnd;
    }

    // Buttons: "Rampage", "Endless" (only when `onEndless` is given: the demo is done), "Menu"; one
    // TreeNodeButton per node, named "Node_<id>". `onDemoEnd` runs once, when a buy leaves every node owned.
    public static RectTransform Show(S.GDict save, Action onRampage, Action onEndless, Action onMenu, Action onDemoEnd)
    {
        var o = new Open { save = save, onDemoEnd = onDemoEnd };
        o.tree = TreeText.TreeOf(save);
        o.species = S.Content.SpeciesDef(S.Gd.Str(save.Get("species", "")));
        o.rubble = S.Num.I(save.Get("rubble", 0L));
        o.screen = UiKit.Screen("Tree");
        UiKit.Backdrop(o.screen);
        RectTransform inner = UiKit.Box(o.screen, "Margin");
        UiKit.FullRect(inner);
        inner.offsetMin = new Vector2(MARGIN, MARGIN);
        inner.offsetMax = new Vector2(-MARGIN, -MARGIN);
        RectTransform col = UiKit.Column(inner, COLUMN_GAP);
        UiKit.FullRect(col);

        RectTransform header = UiKit.Row(col, ROW_GAP, "Header");
        Text heading = UiKit.Label(header, "EVOLUTION TREE", TITLE_SIZE, UiKit.ACCENT);
        Flex(heading, 1f, 0f);
        o.biomass = UiKit.Label(header, "", UiKit.SIZE_HEAD, UiKit.WARN);
        o.menu = UiKit.Button(header, "MENU", onMenu, UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
        o.menu.name = "Menu";

        RectTransform bodyRow = UiKit.Row(col, ROW_GAP, "Body");
        bodyRow.GetComponent<HorizontalLayoutGroup>().childForceExpandHeight = true;
        Flex(bodyRow, 0f, 1f);
        RectTransform area = UiKit.Box(bodyRow, "TreeArea");
        Flex(area, 1f, 1f);
        // Nodes and tubes past the area's edge are cut off (Godot's clip_contents).
        area.gameObject.AddComponent<RectMask2D>();
        RectTransform plateRect = UiKit.Box(area, "Plate");
        UiKit.FullRect(plateRect);
        o.plate = plateRect.gameObject.AddComponent<TreePlate>();
        o.plate.raycastTarget = true;
        BuildSide(o, bodyRow, onRampage, onEndless);

        o.plate.Setup(o.tree, id =>
        {
            Vector2 size = new Vector2((float)o.plate.layout.sizes[id].x, (float)o.plate.layout.sizes[id].y);
            TreeNodeButton b = TreeNodeButton.Make(o.plate.transform, id, TreeText.RoleOf(o.tree, id), o.tree.Kind(id), size);
            b.pressed = pressedId => Press(o, pressedId);
            b.hovered = hoveredId => Select(o, hoveredId);
            b.focused = focusedId =>
            {
                Select(o, focusedId);
                // A click's focus recentres after the release, so the node is still under the mouse for its buy
                // (Godot's button buys on release where it was pressed, then the view has moved).
                if (Input.GetMouseButton(0)) o.plate.StartCoroutine(FocusAfterRelease(o, focusedId));
                else o.plate.Focused(focusedId);
                // The way back from the side buttons is the node last in focus.
                UiFocus.Link(o.go, MoveDirection.Left, o.plate.buttons[focusedId]);
                UiFocus.Link(o.menu, MoveDirection.Left, o.plate.buttons[focusedId]);
            };
            return b;
        });
        o.selected = o.tree.order[0];
        Refresh(o);
        string newest = TreeText.NewestBuyable(o.tree, o.rubble);
        o.plate.CentreOn(newest);
        LayoutRebuilder.ForceRebuildLayoutImmediate(o.screen);
        o.plate.Place();
        // Godot's tree has no way out on cancel: Esc and B do nothing here (and reach no screen below).
        UiFocus.OnCancel(o.screen.gameObject, () => { });
        UiKit.Focus(o.go);

        int shown = 0, buyable = 0;
        foreach (string id in o.tree.order)
        {
            if (!TreeText.Hidden(o.tree, id)) shown++;
            if (o.tree.CanBuy(id, o.rubble)) buyable++;
        }
        Debug.Log($"flow: tree shown, biomass {o.rubble}, nodes {o.tree.order.Size()}, shown {shown}, buyable {buyable}, "
            + $"links {o.plate.layout.links.Count}, opens on {newest}, zoom {o.plate.view.zoom:F2}, area {o.plate.Size.x:F0}x{o.plate.Size.y:F0}");
        return o.screen;
    }

    static void Flex(Component c, float width, float height)
    {
        LayoutElement e = c.GetComponent<LayoutElement>();
        if (e == null) e = c.gameObject.AddComponent<LayoutElement>();
        e.flexibleWidth = width;
        e.flexibleHeight = height;
    }

    static void BuildSide(Open o, RectTransform bodyRow, Action onRampage, Action onEndless)
    {
        RectTransform side = UiKit.Column(bodyRow, SIDE_GAP, "Side");
        UiKit.Size(side, (float)S.Num.F(UiKit.Ui()["tooltip_width"]), 0f);
        RectTransform info = UiKit.Panel(side);
        // The panel fills the column instead of fitting its words.
        info.GetComponent<ContentSizeFitter>().enabled = false;
        Flex(info, 0f, 1f);
        // The readout's head (D-396): the specimen line and its rule, then the node's name, role and words.
        o.specimen = UiKit.Paragraph(info, "", UiKit.SIZE_BODY, UiKit.ACCENT);
        Image rule = UiKit.Fill(info, new Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5f), "Rule");
        UiKit.Size(rule, 0f, 2f);
        o.title = UiKit.Paragraph(info, "", UiKit.SIZE_HEAD, UiKit.TEXT);
        o.role = UiKit.Paragraph(info, "", UiKit.SIZE_BODY, UiKit.WARN);
        o.body = UiKit.Paragraph(info, "", UiKit.SIZE_BODY, UiKit.Lightened(UiKit.MUTED, 0.2f));
        // The node's stats sit half a line below its words, in columns: the arrows line up (D-077).
        UiKit.Size(UiKit.Box(info, "Gap"), 0f, UiKit.SIZE_BODY / 2f);
        o.stats = UiKit.Column(info, STAT_GAP, "Stats");
        // Level, cost and the buy line stay on the panel's bottom edge on every node.
        Flex(UiKit.Box(info, "Push"), 0f, 1f);
        o.status = UiKit.Paragraph(info, "", UiKit.SIZE_BODY, UiKit.TEXT);

        o.go = UiKit.Button(side, "RAMPAGE  >", onRampage, UiKit.SIZE_HEAD);
        o.go.name = "Rampage";
        UiKit.Size(o.go, 0f, GO_HEIGHT);
        // The final upgrade unlocks Endless mode (D-156): its button sits under RAMPAGE.
        if (onEndless != null)
        {
            o.endless = UiKit.Button(side, "ENDLESS MODE", onEndless, UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
            o.endless.name = "Endless";
            UiKit.Size(o.endless, 0f, ENDLESS_HEIGHT);
        }
        UiFocus.Column(o.menu, o.go, o.endless);
    }

    // upgrade_screen.gd _on_node_pressed: the buy, its sounds, then main.gd's _on_bought.
    static System.Collections.IEnumerator FocusAfterRelease(Open o, string id)
    {
        while (Input.GetMouseButton(0)) yield return null;
        if (o.plate != null) o.plate.Focused(id);
    }

    static void Press(Open o, string id)
    {
        long ringsBefore = TreeText.RingsOpen(o.tree);
        long price = o.tree.Buy(id, o.rubble);
        if (price <= 0)
        {
            Sfx.Ui("ui_deny");
        }
        else
        {
            o.rubble -= price;
            foreach (string sound in TreeText.BoughtSounds(o.tree, id, ringsBefore)) Sfx.Ui(sound);
            Debug.Log($"flow: tree bought {id} level {o.tree.Level(id)} for {price}, biomass {o.rubble}");
            Bought(o, id);
        }
        Select(o, id);
        Refresh(o);
    }

    // main.gd _on_bought: bank and save; the last level ends the demo (once); an evolution plays the reveal.
    static void Bought(Open o, string id)
    {
        TreeText.Bank(o.save, o.tree, o.rubble);
        SaveFile.SaveGame(o.save);
        bool last = TreeText.DemoOver(o.save, o.tree);
        if (last)
        {
            o.save["demo_done"] = true;
            SaveFile.SaveGame(o.save);
            Debug.Log("flow: tree demo over, every node owned");
        }
        if (TreeText.Evolves(o.tree, id))
        {
            o.plate.live = false;
            TreeReveal.Show(o.screen, TreeText.RevealOf(o.save, o.tree, id), () =>
            {
                o.plate.live = true;
                if (last) o.onDemoEnd?.Invoke();
                else UiFocus.Grab(o.plate.buttons[id]);
            });
        }
        else if (last)
        {
            o.plate.Defer(() => o.onDemoEnd?.Invoke());
        }
    }

    // The side panel shows node `id` (upgrade_screen.gd _select).
    static void Select(Open o, string id)
    {
        o.selected = id;
        TreeNodeButton b = o.plate.buttons[id];
        // A node in the next ring out keeps its secret: the panel shows its shape's "?" and nothing else.
        bool shape = b.shapeOnly;
        o.title.text = shape ? TreeText.SHAPE_TEXT : TreeText.Title(o.tree, id);
        string role = shape ? "" : TreeText.RoleText(o.tree, id);
        o.role.text = role;
        o.role.gameObject.SetActive(role != "");
        o.body.text = shape ? "" : TreeText.Body(o.tree, id, o.species);
        ShowStats(o, shape ? new List<TreeText.StatRow>() : TreeText.StatRows(o.tree, id, o.species));
        o.status.text = shape ? "" : TreeText.StatusLine(o.tree, id, o.rubble);
        o.status.color = b.state == "buy" ? UiKit.GOOD : b.state == "poor" ? UiKit.BAD : b.state == "maxed" ? UiKit.WARN : UiKit.MUTED;
    }

    // upgrade_readout.gd show_stats: the words, then the value now, an arrow and the value after.
    static void ShowStats(Open o, List<TreeText.StatRow> rows)
    {
        for (int i = o.stats.childCount - 1; i >= 0; i--)
        {
            Transform child = o.stats.GetChild(i);
            child.SetParent(null, false);
            UnityEngine.Object.Destroy(child.gameObject);
        }
        foreach (TreeText.StatRow row in rows)
        {
            UiKit.Paragraph(o.stats, "", UiKit.SIZE_BODY, UiKit.MUTED).text = row.line;
            RectTransform line = UiKit.Row(o.stats, VALUE_GAP, "Values");
            Text was = UiKit.Label(line, "", UiKit.SIZE_BODY, UiKit.MUTED);
            was.text = row.was;
            LayoutElement e = was.gameObject.AddComponent<LayoutElement>();
            e.minWidth = NOW_WIDTH;
            e.preferredWidth = Mathf.Max(NOW_WIDTH, was.preferredWidth);
            if (row.after == null) continue;
            // Godot draws the kit's arrow picture here; a plain mark stands in until the kit has it.
            UiKit.Label(line, "", UiKit.SIZE_BODY, UiKit.GOOD).text = ">";
            UiKit.Label(line, "", UiKit.SIZE_BODY, UiKit.TEXT).text = row.after;
        }
        o.stats.gameObject.SetActive(rows.Count > 0);
    }

    // upgrade_screen.gd _refresh: the counter, every node's state, the specimen line, the selected node.
    static void Refresh(Open o)
    {
        o.biomass.text = TreeText.Biomass(o.rubble);
        foreach (string id in o.tree.order) o.plate.buttons[id].ShowState(o.tree, o.rubble);
        o.specimen.text = TreeText.Specimen(o.tree, o.species);
        o.plate.Redraw();
        Wire(o);
        if (o.selected != "") Select(o, o.selected);
    }

    // The arrows, D-pad and left stick step to the nearest shown node that way (Godot finds a Control's
    // neighbours the same way); off the right edge of the tree they reach RAMPAGE.
    static void Wire(Open o)
    {
        var shown = new List<string>();
        foreach (string id in o.tree.order) if (o.plate.buttons[id].gameObject.activeSelf) shown.Add(id);
        MoveDirection[] ways = { MoveDirection.Left, MoveDirection.Right, MoveDirection.Up, MoveDirection.Down };
        foreach (string id in shown)
        {
            S.Vector2 at = o.plate.layout.centres[id];
            foreach (MoveDirection way in ways)
            {
                string best = null;
                double bestAway = double.MaxValue;
                foreach (string other in shown)
                {
                    if (other == id) continue;
                    S.Vector2 to = o.plate.layout.centres[other];
                    double dx = to.x - at.x, dy = to.y - at.y;
                    // The tree's y runs down the screen.
                    double along = way == MoveDirection.Left ? -dx : way == MoveDirection.Right ? dx : way == MoveDirection.Up ? -dy : dy;
                    double across = way == MoveDirection.Left || way == MoveDirection.Right ? Math.Abs(dy) : Math.Abs(dx);
                    if (along <= 0.0 || across > along) continue;
                    double away = dx * dx + dy * dy;
                    if (away < bestAway)
                    {
                        bestAway = away;
                        best = other;
                    }
                }
                Selectable next = best != null ? o.plate.buttons[best] : way == MoveDirection.Right ? o.go : null;
                UiFocus.Link(o.plate.buttons[id], way, next);
            }
        }
        string back = o.selected != "" && o.plate.buttons[o.selected].gameObject.activeSelf ? o.selected : shown.Count > 0 ? shown[0] : null;
        if (back == null) return;
        UiFocus.Link(o.go, MoveDirection.Left, o.plate.buttons[back]);
        UiFocus.Link(o.menu, MoveDirection.Left, o.plate.buttons[back]);
        if (o.endless != null) UiFocus.Link(o.endless, MoveDirection.Left, o.plate.buttons[back]);
    }
}
