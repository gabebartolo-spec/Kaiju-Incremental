// One of every kit widget on one screen (GameFlow opens it under -ui-gallery): the proof the kit builds,
// and the page to look at when a widget's look is judged.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public static class UiGallery
{
    // The card's least width (the settings card's) and the gear's side.
    const float CARD_WIDTH = 980f;
    const float GEAR_SIDE = 48f;
    // The demo slider: 0 to 100 in tens, as the volume rows.
    const float SLIDER_MAX = 100f, SLIDER_STEP = 10f, SLIDER_START = 70f;
    const int CELLS = 10, CELLS_LIT = 6;
    const float BAR_VALUE = 0.6f;
    static readonly string[] CYCLE_VALUES = { "Low", "Medium", "High" };
    static readonly string[] HEADLINES = { "GIANT REPTILE SIGHTED IN THE HARBOUR", "CITY URGES CALM", "ARMY ON ITS WAY" };

    static int cycleAt;

    public static RectTransform Show()
    {
        int widgets = 0;
        RectTransform screen = UiKit.Screen("Gallery");
        UiKit.Backdrop(screen); widgets++;
        RectTransform safe = UiKit.SafeArea(screen);
        RectTransform card = UiKit.Panel(safe); widgets++;
        UiKit.Size(card, CARD_WIDTH, 0f);

        UiKit.Header(card, "UI KIT", UiKit.SIZE_TITLE); widgets++;
        UiKit.Header(card, "Head strip", UiKit.SIZE_HEAD); widgets++;
        UiKit.Label(card, "Title 72", UiKit.SIZE_TITLE, UiKit.ACCENT); widgets++;
        UiKit.Label(card, "Head 36", UiKit.SIZE_HEAD); widgets++;
        UiKit.Label(card, "Body 24", UiKit.SIZE_BODY); widgets++;
        UiKit.Label(card, "Small 20, muted", UiKit.SIZE_SMALL, UiKit.MUTED); widgets++;

        RectTransform buttons = UiKit.Row(card);
        KitButton primary = UiKit.Button(buttons, "Primary", () => Debug.Log("ui: gallery pressed Primary")); widgets++;
        KitButton dark = UiKit.Button(buttons, "Dark", () => Debug.Log("ui: gallery pressed Dark"), UiKit.SIZE_BODY, UiKit.PANEL_EDGE); widgets++;
        KitButton plain = UiKit.Button(buttons, "No tape", () => Debug.Log("ui: gallery pressed No tape"), UiKit.SIZE_BODY, UiKit.ACCENT, false); widgets++;
        KitButton off = UiKit.Button(buttons, "Disabled", null); widgets++;
        off.interactable = false;

        KitButton cycle = null;
        cycle = UiKit.Cycle(card, CYCLE_VALUES[0], () =>
        {
            cycleAt = (cycleAt + 1) % CYCLE_VALUES.Length;
            UiKit.SetCycle(cycle, CYCLE_VALUES[cycleAt]);
        });
        cycleAt = 0;
        UiKit.OptionRow(card, "Cycle", cycle); widgets++;

        Text shown = null;
        KitSlider slider = UiKit.SliderRow(card, "Slider", 0f, SLIDER_MAX, SLIDER_STEP, SLIDER_START,
            v => { if (shown != null) shown.text = Mathf.RoundToInt(v).ToString(); }, out shown);
        shown.text = Mathf.RoundToInt(SLIDER_START).ToString();
        widgets++;

        UiKit.Tape(card); widgets++;
        UiKit.Bar(card, UiKit.ALERT).Value = BAR_VALUE; widgets++;
        UiKit.Bar(card, UiKit.ACCENT, 26f, true, false).Value = BAR_VALUE; widgets++;
        RectTransform marks = UiKit.Row(card);
        UiKit.Cells(marks, CELLS, CELLS_LIT); widgets++;
        UiKit.Gear(marks, GEAR_SIDE, UiKit.TEXT); widgets++;

        NewsTicker.Create(screen, new List<string>(HEADLINES)); widgets++;

        UiFocus.Row(primary, dark, plain);
        UiFocus.Column(primary, cycle, slider);
        UiFocus.Link(dark, UnityEngine.EventSystems.MoveDirection.Down, cycle);
        UiFocus.Link(plain, UnityEngine.EventSystems.MoveDirection.Down, cycle);
        UiFocus.OnCancel(screen.gameObject, () => Debug.Log("ui: gallery cancel"));
        UiKit.Focus(primary);
        Selectable at = UiFocus.Current;
        Debug.Log("ui: gallery shown, " + widgets + " widgets, focus on " + (at != null ? at.name + " \"" + primary.text + "\"" : "nothing")
            + (UiKit.FontsFound() ? "" : ", fallback font"));
        return screen;
    }
}
