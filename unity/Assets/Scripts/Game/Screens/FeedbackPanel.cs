// The pause menu's bug / feedback panel (scenes/feedback_panel.gd, D-145): a text box with SEND and CANCEL. SEND
// writes the report folder (GameLogic FeedbackReport) and the panel says where it went, with OPEN FOLDER and DONE.
// It runs over the stopped rampage; the box takes every key typed into it (the menu focus is held off while it has the
// caret), so nothing reaches the menus or the rampage. Cancel (Esc, pad B) or CANCEL closes without writing anything.
// A pad cannot type: its down or A in the box hands focus to SEND (FeedbackKeys). Nothing here touches the network.
using System;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

public static class FeedbackPanel
{
    // feedback_panel.gd's layout numbers (px at 1080p): the column's gap, a button's size, the box's line height over
    // the body size and the text's inset in the box, the box's fill.
    const float GAP = 16f;
    const float BUTTON_WIDTH = 300f;
    const float BUTTON_HEIGHT = 76f;
    const float LINE_EXTRA = 10f;
    const float TEXT_INSET = 10f;
    const float BOX_ALPHA = 0.75f;
    const float SELECTION_ALPHA = 0.35f;

    // Opens the panel under `parent` (the pause screen). It first takes the picture with `hideForShot` hidden (the
    // pause's dim) so the rampage is shown as it stood, then shows them again and opens. The caller hides its own
    // menu card first. `onClosed` runs on CANCEL, DONE or cancel. `sim` and `speciesId`: what the report says about
    // the run.
    public static RectTransform Show(Transform parent, S.RampageSim sim, string speciesId, Action onClosed, params GameObject[] hideForShot)
    {
        RectTransform root = UiKit.Box(parent, "FeedbackPanel");
        UiKit.FullRect(root);
        FeedbackKeys keys = root.gameObject.AddComponent<FeedbackKeys>();
        keys.sim = sim;
        keys.speciesId = speciesId ?? "";
        keys.onClosed = onClosed;
        keys.hideForShot = hideForShot ?? new GameObject[0];
        keys.StartCoroutine(keys.Open());
        return root;
    }

    // -flow-smoke: types `typed` into the open panel under `under` and presses SEND. Null when no panel is built yet.
    public static FeedbackResult SmokeSend(Transform under, string typed)
    {
        FeedbackKeys keys = under != null ? under.GetComponentInChildren<FeedbackKeys>() : null;
        if (keys == null || keys.box == null || keys.send == null) return null;
        keys.box.text = typed;
        keys.send.onClick.Invoke();
        return keys.result;
    }

    // The panel itself, once the picture is taken (feedback_panel.gd _ready).
    internal static void Build(FeedbackKeys keys)
    {
        S.GDict cfg = FeedbackReport.Cfg();
        float boxWidth = (float)S.Num.F(cfg["box_width"]);
        RectTransform centre = UiKit.Box(keys.transform, "Centre");
        UiKit.FullRect(centre);
        RectTransform card = UiKit.Panel(centre, null, GAP);
        Text title = UiKit.Label(card, S.Gd.Str(cfg["title"]), UiKit.SIZE_HEAD, UiKit.ACCENT);
        title.alignment = TextAnchor.MiddleCenter;
        keys.prompt = UiKit.Label(card, S.Gd.Str(cfg["prompt"]), UiKit.SIZE_BODY, UiKit.MUTED).gameObject;
        keys.box = TextBox(card, cfg, boxWidth, out keys.frame);
        keys.status = UiKit.Paragraph(card, "", UiKit.SIZE_BODY);
        UiKit.Size(keys.status, boxWidth, 0f);
        keys.status.gameObject.SetActive(false);
        RectTransform write = ButtonRow(card, "Write");
        keys.writeRow = write.gameObject;
        keys.send = PanelButton(write, S.Gd.Str(cfg["send"]), UiKit.ACCENT, keys.Send, "Send");
        keys.cancel = PanelButton(write, S.Gd.Str(cfg["cancel"]), UiKit.PANEL_EDGE, keys.Close, "Cancel");
        UiFocus.Row(keys.send, keys.cancel);
        // A pad's up from a button returns to the box.
        UiFocus.Link(keys.send, UnityEngine.EventSystems.MoveDirection.Up, keys.box);
        UiFocus.Link(keys.cancel, UnityEngine.EventSystems.MoveDirection.Up, keys.box);
        RectTransform doneRow = ButtonRow(card, "DoneRow");
        keys.doneRow = doneRow.gameObject;
        keys.open = PanelButton(doneRow, S.Gd.Str(cfg["open_folder"]), UiKit.ACCENT, keys.OpenFolder, "OpenFolder");
        keys.done = PanelButton(doneRow, S.Gd.Str(cfg["done"]), UiKit.PANEL_EDGE, keys.Close, "Done");
        UiFocus.Row(keys.open, keys.done);
        keys.doneRow.SetActive(false);
        UiFocus.OnCancel(keys.gameObject, keys.Close);
        UiKit.Focus(keys.box);
    }

    // The multi-line box: Enter is a new line, at most max_chars, its edge yellow while it has the caret.
    static InputField TextBox(Transform parent, S.GDict cfg, float width, out HazardBox frame)
    {
        frame = UiKit.Hazard(parent, new Color(0f, 0f, 0f, BOX_ALPHA), UiKit.PANEL_EDGE, 2f, HazardBox.Band.None, "Box");
        frame.raycastTarget = true;
        UiKit.Size(frame, width, (float)S.Num.F(cfg["box_lines"]) * (UiKit.SIZE_BODY + LINE_EXTRA));
        RectTransform area = UiKit.Box(frame.transform, "Text");
        area.anchorMin = Vector2.zero;
        area.anchorMax = Vector2.one;
        area.offsetMin = new Vector2(TEXT_INSET, TEXT_INSET);
        area.offsetMax = new Vector2(-TEXT_INSET, -TEXT_INSET);
        Text text = area.gameObject.AddComponent<Text>();
        text.font = UiKit.Font(UiKit.SIZE_BODY);
        text.fontSize = UiKit.SIZE_BODY;
        text.color = UiKit.TEXT;
        text.alignment = TextAnchor.UpperLeft;
        text.horizontalOverflow = HorizontalWrapMode.Wrap;
        text.verticalOverflow = VerticalWrapMode.Truncate;
        text.supportRichText = false;
        text.raycastTarget = false;
        InputField field = frame.gameObject.AddComponent<InputField>();
        field.textComponent = text;
        field.targetGraphic = frame;
        field.transition = Selectable.Transition.None;
        field.lineType = InputField.LineType.MultiLineNewline;
        field.characterLimit = (int)S.Num.I(cfg["max_chars"]);
        field.customCaretColor = true;
        field.caretColor = UiKit.ACCENT;
        field.selectionColor = new Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, SELECTION_ALPHA);
        // The box keeps every arrow for its caret; FeedbackKeys moves a pad out of it.
        field.navigation = new Navigation { mode = Navigation.Mode.None };
        return field;
    }

    static RectTransform ButtonRow(Transform parent, string name)
    {
        RectTransform row = UiKit.Row(parent, GAP, name);
        row.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.MiddleCenter;
        return row;
    }

    static KitButton PanelButton(Transform row, string text, Color fill, Action onPress, string name)
    {
        KitButton b = UiKit.Button(row, text, onPress, UiKit.SIZE_HEAD, fill);
        b.name = name;
        UiKit.Size(b, BUTTON_WIDTH, BUTTON_HEIGHT);
        return b;
    }
}
