// The demo's thanks card (scenes/demo_end.gd, D-050, D-145, D-152, D-156), shown after the final upgrade: the
// demo lines, the rampage totals (Demo.Rows, counted by the sim) and three buttons. LEAVE FEEDBACK opens the
// data's Itch page (D-148, D-395), TRY ENDLESS MODE starts Endless mode, KEEP PLAYING returns to the tree. What
// it says is built in plain C# (GameLogic/DemoCard.cs); this only draws it. The save is untouched.
// Above the words, in the reveal's hazard frame (EvolutionReveal.frame_view / frame_around): the adult on the
// reveal's set beside the tallest tower it topples (RevealStageView), roaring its clip on arrival and every
// ROAR_EVERY frames after.
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
    // evolution_reveal.gd: the column's top and bottom margin and the frame's room round the view; demo_end.gd:
    // the height kept for the words under it, the set's camera pulled back and moved over, the roar's pace.
    const float EDGE_MARGIN = 48f, FRAME_EXTRA = 56f, TEXT_RESERVE = 480f, VIEW_BACK = 1.25f, VIEW_SHIFT = 0.1f;
    const int ROAR_EVERY = 360;
    // evolution_reveal.gd frame_around: the tape-topped frame's edge and its content margin.
    const float FRAME_BORDER = 3f, FRAME_PAD = 8f;

    // The set in the frame (the smoke reads its roars).
    public static RevealStageView View { get; private set; }

    // Opens a URL (demo_end.gd opener: the smoke run swaps it so no browser opens).
    public static Action<string> Opener = Application.OpenURL;

    // save: the save in play (its species and demo totals). Buttons: Endless and Keep; Feedback opens the link.
    public static RectTransform Show(S.GDict save, Action onEndless, Action onKeep)
    {
        DemoCardModel m = DemoCard.Build(save);
        RectTransform screen = UiKit.Screen("DemoEnd");
        UiKit.Backdrop(screen);
        RectTransform col = UiKit.Column(screen, GAP, "Card");
        UiKit.FullRect(col);
        col.offsetMin = new Vector2(0f, EDGE_MARGIN);
        col.offsetMax = new Vector2(0f, -EDGE_MARGIN);
        col.GetComponent<VerticalLayoutGroup>().childForceExpandWidth = false;
        View = Frame(col, screen);
        Text headline = UiKit.Label(col, "", UiKit.SIZE_TITLE, UiKit.ACCENT);
        headline.text = m.title;
        headline.alignment = TextAnchor.MiddleCenter;
        Text line = UiKit.Label(col, "", UiKit.SIZE_HEAD, UiKit.TEXT);
        line.text = m.line;
        line.alignment = TextAnchor.MiddleCenter;
        StatsGrid(col, m);
        Buttons(col, m, onEndless, onKeep);
        string rows = string.Join(", ", m.rows.ConvertAll(r => r.key + " " + r.value));
        Debug.Log($"flow: demo end shown, species {m.speciesId}, stage {m.stage}, title '{m.title}', line '{m.line}', "
            + $"rows {m.rows.Count} ({rows}), view {View.Stage}, buttons {string.Join("/", m.buttons.ConvertAll(b => b.id))}, focus {m.focus}, feedback {m.feedbackUrl}");
        return screen;
    }

    // LEAVE FEEDBACK, TRY ENDLESS MODE (focused) and KEEP PLAYING, centred in a row.
    static void Buttons(Transform col, DemoCardModel m, Action onEndless, Action onKeep)
    {
        RectTransform row = UiKit.Row(col, BUTTON_GAP, "Buttons");
        row.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.MiddleCenter;
        // The column fills the screen now: the row keeps its buttons' own size instead of taking the rest of it
        // (Godot's HBoxContainer in a VBox does not grow without an expand flag).
        LayoutElement keep = row.gameObject.AddComponent<LayoutElement>();
        keep.flexibleWidth = keep.flexibleHeight = 0f;
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
    }

    // evolution_reveal.gd frame_view and frame_around: the view as tall as the screen leaves room for (at most
    // VIEW_MAX), at VIEW_MAX's aspect, in a frame of hazard tape on top and a yellow edge, centred.
    static RevealStageView Frame(Transform col, RectTransform screen)
    {
        Canvas.ForceUpdateCanvases();
        Vector2 max = RevealStageView.VIEW_MAX;
        float h = Mathf.Min(max.y, screen.rect.height - 2f * EDGE_MARGIN - TEXT_RESERVE - FRAME_EXTRA);
        HazardBox frame = UiKit.Hazard(col, UiKit.BG, UiKit.ACCENT, FRAME_BORDER, HazardBox.Band.Top, "Frame");
        VerticalLayoutGroup g = frame.gameObject.AddComponent<VerticalLayoutGroup>();
        int pad = Mathf.RoundToInt(FRAME_PAD);
        g.padding = new RectOffset(pad, pad, Mathf.RoundToInt(UiKit.PANEL_BAND + FRAME_PAD), pad);
        g.childControlWidth = g.childControlHeight = true;
        g.childForceExpandWidth = g.childForceExpandHeight = false;
        RectTransform holder = UiKit.Box(frame.transform, "View");
        UiKit.Size(holder, h * max.x / max.y, h);
        RevealStageView view = RevealStageView.Create(holder, DemoCard.StageStats(), VIEW_BACK, VIEW_SHIFT);
        view.RoarEvery = ROAR_EVERY;
        return view;
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
