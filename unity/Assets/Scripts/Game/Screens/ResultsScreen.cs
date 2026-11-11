// The results screen (scenes/results_screen.gd): the rampage report over the wrecked city. The headline by how
// it ended, the verdict against the best before it, the rows counting up one after another, NEW RECORD stamps
// on beaten rows, the news crawl along the bottom and the way on. What it says is built in plain C#
// (GameLogic/ResultsRows.cs); this only draws it. The count is ResultsCount.
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

public static class ResultsScreen
{
    // Godot's layout numbers (px at 1080p).
    const float CARD_WIDTH = 1300f;
    const float CARD_GAP = 10f;
    const float COLUMN_GAP = 48f;
    const float SECTION_GAP = 4f;
    const float H_GAP = 24f;
    const float V_GAP = 8f;
    const float VALUE_WIDTH = 150f;
    const float BADGE_WIDTH = 200f;
    const float GO_HEIGHT = 80f;
    const float BOTTOM_PAD = 20f;
    const float DIM = 0.6f;
    // The stamp's box: its edge, and the room between it and the words.
    public const float STAMP_BORDER = 3f;
    public const float STAMP_MARGIN = 4f;
    // Godot turns clockwise for a positive angle, Unity the other way: -6 there is +6 here.
    public const float STAMP_TILT = 6f;

    // previousBest: the save's best before this rampage ({} on a first one), as SaveFile.Bank returns it.
    // goLabel: the button's text once the count is done ("EVOLVE  >", or "BACK  >" from an endless run).
    // The button is named Go: its first press while the rows count skips the count, the next calls onContinue.
    public static RectTransform Show(S.GDict result, S.GDict previousBest, string goLabel, Action onContinue)
    {
        ResultsModel m = ResultsRows.Build(result, previousBest);
        RectTransform screen = UiKit.Screen("Results");
        ResultsCount count = screen.gameObject.AddComponent<ResultsCount>();
        count.model = m;
        count.goLabel = Tr.T(string.IsNullOrEmpty(goLabel) ? ResultsRows.GO_LABEL : goLabel);
        count.onContinue = onContinue;
        // The dim also keeps the mouse off the city behind.
        UiKit.Fill(screen, new Color(0f, 0f, 0f, DIM), "Dim").raycastTarget = true;
        RectTransform centre = UiKit.Box(screen, "Centre");
        UiKit.FullRect(centre);
        centre.offsetMin = new Vector2(0f, NewsTicker.HEIGHT);
        RectTransform card = UiKit.Panel(centre, null, CARD_GAP);
        UiKit.Size(card, CARD_WIDTH, 0f);
        UiKit.Header(card, m.headline);
        Text verdict = UiKit.Label(card, m.verdict, UiKit.SIZE_HEAD, UiKit.WARN);
        verdict.alignment = TextAnchor.MiddleCenter;
        count.verdict = verdict.gameObject.AddComponent<CanvasGroup>();
        // Biomass across the top, then the destruction tally beside the body count.
        RectTransform top = Centred(card, 0f, "Top");
        Section(top, m, m.groups[0], count);
        RectTransform pair = Centred(card, COLUMN_GAP, "Pair");
        for (int g = 1; g < m.groups.Count; g++) Section(pair, m, m.groups[g], count);
        // The confirm that ended the beat must not press Go too (rampage_hud.gd set_input_as_handled, grab_focus deferred).
        int shownFrame = Time.frameCount;
        count.go = UiKit.Button(card, ResultsRows.SKIP_LABEL, () => { if (Time.frameCount != shownFrame) count.Press(); }, UiKit.SIZE_HEAD);
        count.go.name = "Go";
        UiKit.Size(count.go, 0f, GO_HEIGHT);
        // Space under the button, inside the card.
        UiKit.Box(card, "Pad").gameObject.AddComponent<LayoutElement>().minHeight = BOTTOM_PAD;
        NewsTicker.Create(screen, m.news);
        UiKit.Focus(count.go);
        count.ShowFrame();
        Debug.Log("flow: results screen shown, reason " + m.reason + ", headline '" + m.headline + "', verdict '" + m.verdict
            + "', biomass " + m.rows[0].Shown(m.rows[0].target) + ", rows " + m.rows.Count + ", records " + m.records.Count
            + ", news " + m.news.Count + ", count " + m.TotalFrames + " frames (" + m.TotalSeconds.ToString("0.00") + " s)");
        return screen;
    }

    // True while the rows of a screen Show made are still counting up.
    public static bool Counting(RectTransform screen)
    {
        ResultsCount count = screen != null ? screen.GetComponent<ResultsCount>() : null;
        return count != null && count.Counting;
    }

    // Lands every row of a screen Show made at once (what the first press of Go does).
    public static void Skip(RectTransform screen)
    {
        ResultsCount count = screen != null ? screen.GetComponent<ResultsCount>() : null;
        if (count != null) count.Skip();
    }

    // A row that keeps its children at their own size, in the middle of the card.
    static RectTransform Centred(Transform parent, float gap, string name)
    {
        RectTransform row = UiKit.Row(parent, gap, name);
        row.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.UpperCenter;
        return row;
    }

    // A group: its heading over lines of `perLine` rows side by side, each a name, a value and a best badge.
    // Cells in one grid column share a width, as Godot's GridContainer gave them.
    static void Section(Transform parent, ResultsModel m, ResultsGroup g, ResultsCount count)
    {
        RectTransform box = UiKit.Column(parent, SECTION_GAP, g.id);
        UiKit.Label(box, g.heading, UiKit.SIZE_BODY, UiKit.ACCENT);
        RectTransform grid = UiKit.Column(box, V_GAP, "Grid");
        int per = Mathf.Max(g.perLine, 1);
        float[] nameWidth = new float[per], valueWidth = new float[per], badgeWidth = new float[per];
        List<Text> names = new List<Text>(), values = new List<Text>();
        List<RectTransform> badges = new List<RectTransform>();
        RectTransform line = null;
        for (int i = 0; i < g.rows.Count; i++)
        {
            int n = g.rows[i], c = i % per;
            ResultsRow row = m.rows[n];
            if (c == 0) line = UiKit.Row(grid, H_GAP, "Line");
            Text name = UiKit.Label(line, row.label, UiKit.SIZE_BODY, UiKit.MUTED);
            name.alignment = TextAnchor.MiddleLeft;
            Text value = UiKit.Label(line, row.Shown(row.target), UiKit.SIZE_HEAD, UiKit.TEXT);
            value.alignment = TextAnchor.MiddleRight;
            // The badge: the best before this rampage, or the stamp over it once the row beat it.
            RectTransform cell = UiKit.Box(line, "Badge");
            RectTransform tilt = UiKit.Box(cell, "Tilt");
            UiKit.FullRect(tilt);
            HazardBox frame = UiKit.Hazard(tilt, Color.clear, UiKit.ALERT, STAMP_BORDER, HazardBox.Band.None, "Stamp");
            UiKit.FullRect(frame.rectTransform);
            frame.enabled = false;
            Text badge = UiKit.Label(tilt, row.bestText, UiKit.SIZE_BODY, UiKit.MUTED);
            badge.alignment = TextAnchor.MiddleLeft;
            UiKit.FullRect(badge.rectTransform);
            float stampWidth = 0f;
            if (row.stamp)
            {
                string best = badge.text;
                badge.text = Tr.T(ResultsRows.STAMP_TEXT);
                stampWidth = badge.preferredWidth + 2f * (STAMP_MARGIN + STAMP_BORDER);
                badge.text = best;
            }
            nameWidth[c] = Mathf.Max(nameWidth[c], name.preferredWidth);
            valueWidth[c] = Mathf.Max(valueWidth[c], VALUE_WIDTH, value.preferredWidth);
            badgeWidth[c] = Mathf.Max(badgeWidth[c], BADGE_WIDTH, Mathf.Max(badge.preferredWidth, stampWidth));
            UiKit.Size(cell, 0f, value.preferredHeight);
            names.Add(name);
            values.Add(value);
            badges.Add(cell);
            count.values[n] = value;
            count.badges[n] = cell.gameObject.AddComponent<CanvasGroup>();
            count.badgeTexts[n] = badge;
            count.frames[n] = frame;
            count.tilts[n] = tilt;
        }
        for (int i = 0; i < names.Count; i++)
        {
            int c = i % per;
            UiKit.Size(names[i], Mathf.Ceil(nameWidth[c]), 0f);
            UiKit.Size(values[i], Mathf.Ceil(valueWidth[c]), 0f);
            UiKit.Size(badges[i], Mathf.Ceil(badgeWidth[c]), 0f);
        }
    }
}
