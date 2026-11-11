// A page opened from Settings (scenes/options_page.gd): an opaque dim, a centred card with a title, rows of a
// name and its buttons, and a foot row ending in BACK. Cancel (Esc, pad B) closes it and the focus goes back
// to the button that opened it. Its texts are re-read every frame (OptionsLabels), so a language change
// re-labels it while it is open.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public sealed class OptionsPage : MonoBehaviour
{
    // options_page.gd: the card's least width, the gap above the foot row, BACK's trim.
    public const float PANEL_WIDTH = 980f;
    public const float BLOCK_GAP = 14f;
    public const float BACK_MARGIN = 10f;

    public RectTransform Card;
    public OptionsLabels Labels;
    public KitButton Back;

    readonly List<Selectable[]> grid = new List<Selectable[]>();
    readonly List<(string text, Action press)> feet = new List<(string, Action)>();
    Selectable opener;
    bool closing;

    // A new page over `host` (null: its own layer on the canvas). `title` is the English text.
    public static OptionsPage Open(string name, string title, Transform host, Selectable opener)
    {
        RectTransform root = host != null ? UiKit.Box(host, name) : UiKit.Screen(name);
        UiKit.FullRect(root);
        UiKit.Fill(root, UiKit.BG, "Dim").raycastTarget = true;
        OptionsPage page = root.gameObject.AddComponent<OptionsPage>();
        page.opener = opener;
        page.Labels = root.gameObject.AddComponent<OptionsLabels>();
        page.Card = UiKit.Panel(root);
        UiKit.Size(page.Card, PANEL_WIDTH, 0f);
        Text head = UiKit.Label(page.Card, title, UiKit.SIZE_TITLE, UiKit.ACCENT);
        head.alignment = TextAnchor.MiddleCenter;
        page.Labels.Add(head, () => Tr.T(title));
        UiFocus.OnCancel(root.gameObject, page.Close);
        return page;
    }

    // A dark button for a row; its text is set by the caller through Labels.
    public KitButton Choice(Action onPress)
    {
        return UiKit.Choice(Card, "", onPress);
    }

    // A grey text in a row's span (a head, a binding nobody changes); `text` is English.
    public Text Note(string text)
    {
        Text t = UiKit.Label(Card, text, UiKit.SIZE_BODY, UiKit.MUTED);
        t.alignment = TextAnchor.MiddleLeft;
        Labels.Add(t, () => KeyBinds.Shown(text));
        return t;
    }

    // A row: `name` (English) and its items side by side in the span.
    public RectTransform Row(string name, params Component[] items)
    {
        RectTransform line = UiKit.OptionRow(Card, name, items);
        Labels.AddName(line, () => KeyBinds.Shown(name));
        Selectable[] cells = new Selectable[items.Length];
        bool any = false;
        for (int i = 0; i < items.Length; i++)
        {
            cells[i] = items[i] != null ? items[i].GetComponent<Selectable>() : null;
            any |= cells[i] != null;
        }
        if (any) grid.Add(cells);
        return line;
    }

    // A foot button left of BACK (options_page.gd _foot_buttons).
    public void Foot(string text, Action onPress)
    {
        feet.Add((text, onPress));
    }

    // Adds the foot row, wires the focus by hand and lights the first button (BACK when the page has none).
    public void Finish()
    {
        RectTransform line = UiKit.Row(Gap(Card, BLOCK_GAP), UiKit.BUTTON_GAP, "Foot");
        line.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.MiddleCenter;
        List<Selectable> foot = new List<Selectable>();
        foreach ((string text, Action press) in feet) foot.Add(FootButton(line, text, press));
        Back = FootButton(line, "BACK", Close);
        foot.Add(Back);

        int columns = 0;
        foreach (Selectable[] cells in grid)
        {
            UiFocus.Row(cells);
            columns = Mathf.Max(columns, cells.Length);
        }
        UiFocus.Row(foot);
        for (int c = columns - 1; c >= 0; c--)
        {
            // The first column runs on into the foot's first button, the others into its last (BACK).
            List<Selectable> down = new List<Selectable>();
            foreach (Selectable[] cells in grid) if (c < cells.Length && cells[c] != null) down.Add(cells[c]);
            if (down.Count == 0) continue;
            Selectable end = c == 0 ? foot[0] : foot[foot.Count - 1];
            Selectable last = down[down.Count - 1];
            if (c == 0 || foot.Count > 1)
            {
                down.Add(end);
                UiFocus.Column(down);
            }
            else
            {
                UiFocus.Column(down);
                UiFocus.Link(last, MoveDirection.Down, end);
            }
        }
        UiFocus.Grab(grid.Count > 0 ? First(grid[0]) : Back);
    }

    KitButton FootButton(Transform line, string text, Action press)
    {
        KitButton b = UiKit.Button(line, text, press, UiKit.SIZE_HEAD);
        b.TrimHeight(BACK_MARGIN);
        Labels.Add(b, () => Tr.T(text));
        return b;
    }

    static Selectable First(Selectable[] cells)
    {
        foreach (Selectable s in cells) if (s != null) return s;
        return null;
    }

    // `top` px of room above whatever is put in the box returned (settings_menu.gd _gap).
    public static RectTransform Gap(Transform parent, float top)
    {
        RectTransform box = UiKit.Column(parent, 0f, "Gap");
        box.GetComponent<VerticalLayoutGroup>().padding = new RectOffset(0, 0, Mathf.RoundToInt(top), 0);
        return box;
    }

    public void Close()
    {
        if (closing) return;
        closing = true;
        gameObject.SetActive(false);
        Destroy(gameObject);
        UiFocus.Grab(opener);
    }
}
