// The demo's thanks card (scenes/demo_end.gd, D-050, D-145, D-152, D-156), shown after the final upgrade: the
// demo lines, the rampage totals (Demo.Rows, counted by the sim) and three buttons. LEAVE FEEDBACK opens the
// data's Itch page (D-148, D-395), TRY ENDLESS MODE starts Endless mode, KEEP PLAYING returns to the tree. What
// it says is built in plain C# (GameLogic/DemoCard.cs); this only draws it. The save is untouched.
// First version (D-476): the words, totals and buttons at Godot's sizes, centred on the backdrop. The adult on
// the reveal's set beside its tower (RevealStage) and its clip roar every 360 frames come with the 3D reveal.
using System;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using S = Kaiju.Sim;

public static class DemoEndScreen
{
    // demo_end.gd's layout numbers (px at 1080p): button width, a figure's least width, the column gap, the
    // stats grid's gaps and the button row's gap.
    const float BUTTON_WIDTH = 400f;
    const float STAT_WIDTH = 220f;
    const float GAP = 12f;
    const float H_GAP = 40f;
    const float V_GAP = 6f;
    const float BUTTON_GAP = 24f;
    // Label and figure pairs on one line (demo_end.gd _stats_grid: four grid columns).
    const int PAIRS = 2;

    // Opens a URL (demo_end.gd opener: the smoke run swaps it so no browser opens).
    public static Action<string> Opener = Application.OpenURL;

    // save: the save in play (its species and demo totals). Buttons: Endless and Keep; Feedback opens the link.
    public static RectTransform Show(S.GDict save, Action onEndless, Action onKeep)
    {
        DemoCardModel m = DemoCard.Build(save);
        RectTransform screen = UiKit.Screen("DemoEnd");
        UiKit.Backdrop(screen);
        RectTransform col = UiKit.Column(screen, GAP, "Card");
        col.anchorMin = col.anchorMax = col.pivot = new Vector2(0.5f, 0.5f);
        UiKit.Fit(col);
        Text headline = UiKit.Label(col, "", UiKit.SIZE_TITLE, UiKit.ACCENT);
        headline.text = m.title;
        headline.alignment = TextAnchor.MiddleCenter;
        Text line = UiKit.Label(col, "", UiKit.SIZE_HEAD, UiKit.TEXT);
        line.text = m.line;
        line.alignment = TextAnchor.MiddleCenter;
        StatsGrid(col, m);
        RectTransform row = UiKit.Row(col, BUTTON_GAP, "Buttons");
        row.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.MiddleCenter;
        Selectable[] buttons = new Selectable[m.buttons.Count];
        KitButton first = null;
        for (int i = 0; i < m.buttons.Count; i++)
        {
            DemoCardButton def = m.buttons[i];
            Action press = def.id == DemoCard.FEEDBACK ? () => Opener(m.feedbackUrl)
                : def.id == DemoCard.ENDLESS ? onEndless : onKeep;
            Color fill = def.id == DemoCard.ENDLESS ? UiKit.ACCENT : UiKit.PANEL_EDGE;
            KitButton b = UiKit.Button(row, def.label, press, UiKit.SIZE_HEAD, fill);
            b.name = def.id;
            UiKit.Size(b, BUTTON_WIDTH, 0f);
            buttons[i] = b;
            if (def.id == m.focus) first = b;
        }
        UiFocus.Row(buttons);
        UiKit.Focus(first);
        string rows = string.Join(", ", m.rows.ConvertAll(r => r.key + " " + r.value));
        Debug.Log($"flow: demo end shown, species {m.speciesId}, stage {m.stage}, title '{m.title}', line '{m.line}', "
            + $"rows {m.rows.Count} ({rows}), buttons {string.Join("/", m.buttons.ConvertAll(b => b.id))}, focus {m.focus}, feedback {m.feedbackUrl}");
        return screen;
    }

    // The rampage totals, label left and figure right, two pairs a line; cells in one grid column share a width.
    static void StatsGrid(Transform parent, DemoCardModel m)
    {
        RectTransform grid = UiKit.Column(parent, V_GAP, "Stats");
        grid.GetComponent<VerticalLayoutGroup>().childForceExpandWidth = false;
        Text[] names = new Text[m.rows.Count], values = new Text[m.rows.Count];
        float[] width = new float[2 * PAIRS];
        RectTransform line = null;
        for (int i = 0; i < m.rows.Count; i++)
        {
            int c = i % PAIRS;
            if (c == 0) line = UiKit.Row(grid, H_GAP, "Line");
            Text name = UiKit.Label(line, "", UiKit.SIZE_BODY, UiKit.MUTED);
            name.text = m.rows[i].label;
            name.alignment = TextAnchor.MiddleLeft;
            Text value = UiKit.Label(line, "", UiKit.SIZE_HEAD, UiKit.TEXT);
            value.text = m.rows[i].value;
            value.alignment = TextAnchor.MiddleRight;
            width[2 * c] = Mathf.Max(width[2 * c], name.preferredWidth);
            width[2 * c + 1] = Mathf.Max(width[2 * c + 1], STAT_WIDTH, value.preferredWidth);
            names[i] = name;
            values[i] = value;
        }
        for (int i = 0; i < m.rows.Count; i++)
        {
            int c = i % PAIRS;
            UiKit.Size(names[i], Mathf.Ceil(width[2 * c]), 0f);
            UiKit.Size(values[i], Mathf.Ceil(width[2 * c + 1]), 0f);
        }
    }
}
