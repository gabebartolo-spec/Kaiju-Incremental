using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/controls_card.gd: the controls, keyboard and pad, on one broadcast card; the short one is shown once
// at the start of the first rampage.
public static class HudControlsCard
{
    // Extra room under the full list (px at 1080p).
    const float BOTTOM_PAD = 20f;

    public static RectTransform Create(Transform parent, bool compact)
    {
        S.GDict cfg = UiKit.Ui()["controls_card"];
        RectTransform card = UiKit.Panel(parent, null, (float)HudText.CARD_GAP);
        card.name = "ControlsCard";
        // The card never takes the mouse (Godot's MOUSE_FILTER_IGNORE).
        card.GetComponent<Graphic>().raycastTarget = false;
        UiKit.Size(card, (float)S.Num.F(cfg[compact ? "first_run_width" : "width"]), -1f);
        UiKit.Header(card, "CONTROLS", UiKit.SIZE_HEAD);
        // Godot's three-column grid: three columns side by side, the names' one taking the spare width.
        RectTransform grid = UiKit.Row(card, (float)HudText.CARD_H_GAP, "Grid");
        grid.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.UpperLeft;
        RectTransform names = UiKit.Column(grid, (float)HudText.CARD_V_GAP, "Names");
        names.gameObject.AddComponent<LayoutElement>().flexibleWidth = 1f;
        RectTransform keys = UiKit.Column(grid, (float)HudText.CARD_V_GAP, "Keyboard");
        RectTransform pad = UiKit.Column(grid, (float)HudText.CARD_V_GAP, "Pad");
        UiKit.Label(names, "", UiKit.SIZE_BODY, UiKit.WARN);
        UiKit.Label(keys, "KEYBOARD", UiKit.SIZE_BODY, UiKit.WARN);
        UiKit.Label(pad, "PAD", UiKit.SIZE_BODY, UiKit.WARN);
        List<string[]> rows = HudText.ControlRows(compact);
        foreach (string[] row in rows)
        {
            UiKit.Label(names, KeyBinds.Shown(row[0]), UiKit.SIZE_BODY, UiKit.TEXT);
            UiKit.Label(keys, KeyBinds.Shown(row[1]), UiKit.SIZE_BODY, UiKit.MUTED);
            UiKit.Label(pad, KeyBinds.Shown(row[2]), UiKit.SIZE_BODY, UiKit.MUTED);
        }
        if (!compact)
        {
            RectTransform tail = UiKit.Box(card, "Tail");
            UiKit.Size(tail, -1f, BOTTOM_PAD);
        }
        else
        {
            Text prompt = UiKit.Label(card, "PRESS ANY KEY", UiKit.SIZE_BODY, UiKit.ACCENT);
            prompt.alignment = TextAnchor.UpperCenter;
        }
        return card;
    }
}
