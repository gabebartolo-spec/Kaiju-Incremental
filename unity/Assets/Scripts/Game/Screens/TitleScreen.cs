// The title screen (scenes/title_screen.gd with scenes/slot_list.gd): the logo top-left with Continue and
// New Kaiju under it, as wide as the logo; the settings gear in the top-left corner and "Run for your life!?"
// (it quits) bottom-right above the news crawl. Continue and New Kaiju? open the save slots in the same column;
// with every slot empty New Kaiju starts in slot 1 at once. It reports the choice through the delegates;
// GameFlow owns the saves. The rules and numbers are GameLogic/TitleMenu.cs.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public static class TitleScreen
{
    enum Page { Main, Slots, Asking }

    // One title on screen: what it was given and what it built.
    sealed class View
    {
        public RectTransform screen, column, inset, corners, buttons;
        public NewsTicker crawl;
        public KitButton gear, exit;
        public List<SlotInfo> slots;
        public int latest;
        public string summary;
        public float rowWidth;
        public Page page;
        public SlotMode mode;
        public bool settingsOpen;
        public Action<int> onContinue, onNew, onDelete;
        public Action<Action> onSettings;
    }

    static View view;

    // slots: every slot as SaveFile reads it; latest: the slot Continue resumes (0: none).
    // onContinue(n) / onNew(n): the player picked slot n (a start-over is already confirmed).
    // onDelete(n): the player confirmed deleting slot n; delete it, then call Refresh with the slots read anew.
    // onSettings(closed): open the settings over the title and call `closed` when they close.
    // onQuit: the exit button. The buttons are named Continue, NewKaiju, Gear, Exit, Slot<n>, Delete<n>, Back,
    // Keep and Yes.
    public static RectTransform Show(List<SlotInfo> slots, int latest, Action<int> onContinue, Action<int> onNew,
        Action<int> onDelete, Action<Action> onSettings, Action onQuit)
    {
        View v = new View
        {
            slots = slots, latest = latest, summary = TitleMenu.SummaryOf(slots, latest),
            onContinue = onContinue, onNew = onNew, onDelete = onDelete, onSettings = onSettings,
        };
        view = v;
        v.screen = UiKit.Screen("Title");
        UiKit.Backdrop(v.screen);
        TitleBackdrop art = TitleBackdrop.Create(v.screen);
        List<string> news = TitleMenu.NewsLines(slots, latest, v.summary);
        v.crawl = NewsTicker.Create(v.screen, news);

        // The logo and the row under it: a safe margin in from the left, from COLUMN_TOP down to the crawl.
        Vector2 safe = UiKit.SafeMargin();
        v.column = UiKit.Box(v.screen, "Column");
        v.column.anchorMin = new Vector2(0f, 0f);
        v.column.anchorMax = new Vector2(0f, 1f - TitleMenu.COLUMN_TOP);
        v.column.offsetMin = new Vector2(safe.x, NewsTicker.HEIGHT);
        v.column.offsetMax = new Vector2(safe.x + TitleMenu.COLUMN_WIDTH, 0f);
        Stack(v.column, TitleMenu.LOGO_GAP, 0);

        AddCorners(v, safe, onQuit);

        Text logo = UiKit.Label(v.column, TitleMenu.LOGO, TitleMenu.LOGO_SIZE, UiKit.ACCENT);
        logo.name = "Logo";
        // The row ends where the logo does and starts at the logo's yellow, ROW_INSET in.
        v.inset = UiKit.Box(v.column, "Inset");
        Stack(v.inset, 0f, Mathf.RoundToInt(TitleMenu.ROW_INSET));
        float logoWidth = logo.preferredWidth;
        v.rowWidth = (logoWidth > TitleMenu.ROW_INSET ? logoWidth : TitleMenu.COLUMN_WIDTH) - TitleMenu.ROW_INSET;

        UiFocus.OnCancel(v.screen.gameObject, () => Cancel(v));
        ShowMain(v);
        int taken = 0;
        foreach (SlotInfo info in slots) if (info.Taken) taken++;
        Debug.Log($"flow: title shown, {slots.Count} slots, {taken} taken, continue slot {latest}, {news.Count} news lines, "
            + $"row {v.rowWidth:0} px, art {(art.artFound ? "found" : "missing")}");
        return v.screen;
    }

    // After a slot was deleted: the new slots, with the slot list open again in the mode it was in
    // (title_screen.gd refresh, called by main.gd _delete_slot).
    public static void Refresh(List<SlotInfo> slots, int latest)
    {
        View v = view;
        if (v == null || v.screen == null)
        {
            Debug.LogWarning("title: Refresh with no title on screen");
            return;
        }
        v.slots = slots;
        v.latest = latest;
        v.summary = TitleMenu.SummaryOf(slots, latest);
        ShowSlots(v, v.mode);
    }

    // ---- the main row -------------------------------------------------------------------------------------

    static void ShowMain(View v)
    {
        Clear(v, 0f);
        v.page = Page.Main;
        RectTransform row = UiKit.Row(v.buttons, TitleMenu.ROW_GAP, "MainRow");
        KitButton cont = null, fresh;
        if (v.summary != "")
        {
            cont = Add(row, TitleMenu.ContinueLabel(v.summary), UiKit.ACCENT, () => ShowSlots(v, SlotMode.Continue), "Continue");
            fresh = Add(row, "NEW KAIJU?", UiKit.PANEL_EDGE, () => OnNew(v), "NewKaiju");
            float[] widths = TitleMenu.Shares(v.rowWidth, TitleMenu.ROW_GAP, new[] { TitleMenu.CONTINUE_SHARE, 1f },
                new[] { Natural(cont), Natural(fresh) });
            UiKit.Size(cont, widths[0], TitleMenu.BUTTON_HEIGHT);
            UiKit.Size(fresh, widths[1], TitleMenu.BUTTON_HEIGHT);
        }
        else
        {
            fresh = Add(row, "NEW KAIJU", UiKit.ACCENT, () => OnNew(v), "NewKaiju");
            UiKit.Size(fresh, Mathf.Max(Natural(fresh), TitleMenu.AloneWidth(v.rowWidth)), TitleMenu.ALONE_HEIGHT);
        }
        // title_screen.gd _wire_focus: the gear above, the exit below.
        KitButton first = cont != null ? cont : fresh;
        ResetCorners(v);
        foreach (KitButton b in new[] { cont, fresh })
        {
            UiFocus.Link(b, MoveDirection.Up, v.gear);
            UiFocus.Link(b, MoveDirection.Down, v.exit);
        }
        UiFocus.Link(cont, MoveDirection.Right, fresh);
        if (cont != null) UiFocus.Link(fresh, MoveDirection.Left, cont);
        UiFocus.Link(v.gear, MoveDirection.Down, first);
        UiFocus.Link(v.gear, MoveDirection.Right, fresh);
        UiFocus.Link(v.exit, MoveDirection.Up, fresh);
        UiFocus.Link(v.exit, MoveDirection.Left, first);
        UiKit.Focus(first);
    }

    // New Kaiju: the slots to pick from, or slot 1 at once when every slot is empty.
    static void OnNew(View v)
    {
        if (TitleMenu.AllEmpty(v.slots))
        {
            v.onNew?.Invoke(1);
            return;
        }
        ShowSlots(v, SlotMode.New);
    }

    // ---- the save slots (slot_list.gd) --------------------------------------------------------------------

    static void ShowSlots(View v, SlotMode mode)
    {
        Clear(v, TitleMenu.ROW_GAP);
        v.page = Page.Slots;
        v.mode = mode;
        Note(v, TitleMenu.PickNote(mode));
        int focusSlot = TitleMenu.FocusSlot(mode, v.slots, v.latest);
        List<Selectable> plates = new List<Selectable>(), deletes = new List<Selectable>();
        KitButton focus = null;
        int off = 0;
        foreach (SlotInfo info in v.slots)
        {
            SlotInfo slot = info;
            RectTransform row = UiKit.Row(v.buttons, TitleMenu.ROW_GAP, "Row" + slot.Slot);
            KitButton plate = Add(row, TitleMenu.PlateText(slot), slot.Taken ? UiKit.ACCENT : UiKit.PANEL_EDGE,
                () => OnPlate(v, slot), "Slot" + slot.Slot, TitleMenu.ROW_HEIGHT);
            KitButton del = null;
            float least = 0f;
            if (slot.Taken)
            {
                del = Add(row, "DELETE", UiKit.PANEL_EDGE, () => AskDelete(v, slot), "Delete" + slot.Slot, TitleMenu.ROW_HEIGHT);
                least = Natural(del);
            }
            float[] widths = TitleMenu.Shares(v.rowWidth, TitleMenu.ROW_GAP, new[] { TitleMenu.SLOT_SHARE, 1f }, new[] { Natural(plate), least });
            UiKit.Size(plate, widths[0], TitleMenu.ROW_HEIGHT);
            // An empty slot keeps the gap, so every plate is the same width.
            if (del != null) UiKit.Size(del, widths[1], TitleMenu.ROW_HEIGHT);
            else UiKit.Size(UiKit.Box(row, "Gap"), widths[1], 0f);
            // The pad steps over a slot it cannot pick: an off plate is left out of the wiring.
            bool isOff = TitleMenu.PlateOff(mode, slot);
            plate.interactable = !isOff;
            if (isOff) off++;
            else
            {
                plates.Add(plate);
                if (slot.Slot == focusSlot) focus = plate;
                if (del != null)
                {
                    UiFocus.Link(plate, MoveDirection.Right, del);
                    UiFocus.Link(del, MoveDirection.Left, plate);
                }
            }
            if (del != null) deletes.Add(del);
        }
        // BACK keeps its own width at the row's left (shrink-begin).
        RectTransform backRow = UiKit.Row(v.buttons, 0f, "BackRow");
        KitButton back = Add(backRow, "BACK", UiKit.PANEL_EDGE, () => ShowMain(v), "Back", TitleMenu.BACK_HEIGHT);

        // Down the plates to BACK, and down the DELETEs to BACK; BACK goes up to the last plate (or DELETE).
        plates.Add(back);
        UiFocus.Column(plates);
        Selectable aboveBack = plates.Count > 1 ? plates[plates.Count - 2] : deletes.Count > 0 ? deletes[deletes.Count - 1] : null;
        deletes.Add(back);
        UiFocus.Column(deletes);
        UiFocus.Link(back, MoveDirection.Up, aboveBack);
        Selectable top = plates[0];
        ResetCorners(v);
        // With no plate to pick, BACK is the top of its column but still goes up to the last DELETE.
        if (top != back || aboveBack == null) UiFocus.Link(top, MoveDirection.Up, v.gear);
        if (deletes.Count > 1) UiFocus.Link(deletes[0], MoveDirection.Up, v.gear);
        UiFocus.Link(v.gear, MoveDirection.Down, top);
        UiFocus.Link(v.gear, MoveDirection.Right, top);
        UiFocus.Link(back, MoveDirection.Down, v.exit);
        UiFocus.Link(v.exit, MoveDirection.Up, back);
        UiFocus.Link(v.exit, MoveDirection.Left, back);
        UiKit.Focus(focus != null ? focus : back);
        Debug.Log($"title: slots shown, mode {mode}, {v.slots.Count} plates, {off} off, focus {(focus != null ? focus.name : back.name)}");
    }

    static void OnPlate(View v, SlotInfo info)
    {
        if (!TitleMenu.NeedsConfirm(v.mode, info))
        {
            Picked(v, info.Slot);
            return;
        }
        Ask(v, TitleMenu.StartOverQuestion(info), "YES, START OVER", () => Picked(v, info.Slot));
    }

    static void Picked(View v, int n)
    {
        if (v.mode == SlotMode.Continue) v.onContinue?.Invoke(n);
        else v.onNew?.Invoke(n);
    }

    static void AskDelete(View v, SlotInfo info)
    {
        Ask(v, TitleMenu.DeleteQuestion(info), "YES, DELETE", () =>
        {
            if (v.onDelete == null) Debug.LogWarning("title: no delete handler, slot " + info.Slot + " is kept");
            else v.onDelete(info.Slot);
        });
    }

    // "Are you sure?": the question, KEEP MY KAIJU (focused, so a stray press keeps it) and the yes.
    static void Ask(View v, string question, string yesText, Action yes)
    {
        Clear(v, TitleMenu.ROW_GAP);
        v.page = Page.Asking;
        Note(v, question);
        KitButton keep = Add(v.buttons, "KEEP MY KAIJU", UiKit.ACCENT, () => ShowSlots(v, v.mode), "Keep", TitleMenu.ROW_HEIGHT);
        KitButton sure = Add(v.buttons, yesText, UiKit.BAD, yes, "Yes", TitleMenu.ROW_HEIGHT);
        UiFocus.Column(keep, sure);
        ResetCorners(v);
        UiFocus.Link(keep, MoveDirection.Up, v.gear);
        UiFocus.Link(sure, MoveDirection.Down, v.exit);
        UiFocus.Link(v.gear, MoveDirection.Down, keep);
        UiFocus.Link(v.gear, MoveDirection.Right, keep);
        UiFocus.Link(v.exit, MoveDirection.Up, sure);
        UiFocus.Link(v.exit, MoveDirection.Left, sure);
        UiKit.Focus(keep);
        Debug.Log("title: asking, " + yesText);
    }

    // Esc or pad B: a question goes back to the slots, the slots to the main row (slot_list.gd ui_cancel).
    static void Cancel(View v)
    {
        if (v.settingsOpen) return;
        if (v.page == Page.Asking) ShowSlots(v, v.mode);
        else if (v.page == Page.Slots) ShowMain(v);
    }

    // ---- the corners --------------------------------------------------------------------------------------

    // The settings gear top-left and the exit button bottom-right, above the ticker.
    static void AddCorners(View v, Vector2 safe, Action onQuit)
    {
        v.corners = UiKit.Box(v.screen, "Corners");
        UiKit.FullRect(v.corners);
        v.gear = UiKit.Button(v.corners, "", () => OpenSettings(v), UiKit.SIZE_BODY, UiKit.PANEL_EDGE, false);
        v.gear.name = "Gear";
        RectTransform g = (RectTransform)v.gear.transform;
        g.anchorMin = g.anchorMax = g.pivot = new Vector2(0f, 1f);
        g.anchoredPosition = new Vector2(TitleMenu.GEAR_CORNER, -TitleMenu.GEAR_CORNER);
        g.sizeDelta = new Vector2(TitleMenu.GEAR_SIZE, TitleMenu.GEAR_SIZE);
        GearIcon icon = UiKit.Gear(g, TitleMenu.GEAR_SIZE, UiKit.TEXT);
        icon.raycastTarget = false;
        // The plate lays out its label, not the picture: the gear fills the plate less its insets.
        icon.GetComponent<LayoutElement>().ignoreLayout = true;
        icon.rectTransform.anchorMin = Vector2.zero;
        icon.rectTransform.anchorMax = Vector2.one;
        icon.rectTransform.offsetMin = new Vector2(TitleMenu.GEAR_LEFT, TitleMenu.GEAR_BOTTOM);
        icon.rectTransform.offsetMax = new Vector2(-TitleMenu.GEAR_RIGHT, -TitleMenu.GEAR_TOP);

        v.exit = UiKit.Button(v.corners, TitleMenu.EXIT_TEXT, onQuit, UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
        v.exit.name = "Exit";
        RectTransform e = (RectTransform)v.exit.transform;
        e.anchorMin = e.anchorMax = e.pivot = new Vector2(1f, 0f);
        // The plate's face, not its shadow, ends on the row's line.
        e.anchoredPosition = new Vector2(-(safe.x + TitleMenu.ROW_INSET - HazardBox.PLATE_SHADOW.x), NewsTicker.HEIGHT + TitleMenu.EXIT_LIFT);
        UiKit.Fit(v.exit);
    }

    // Nothing behind the settings can take focus, nor show dimmed under their panel (_open_settings).
    static void OpenSettings(View v)
    {
        if (v.onSettings == null)
        {
            Debug.LogWarning("title: no settings handler");
            return;
        }
        Hidden(v, true);
        Debug.Log("title: settings opened");
        v.onSettings(() =>
        {
            if (v.screen == null || !v.settingsOpen) return;
            Hidden(v, false);
            ShowMain(v);
            Debug.Log("title: settings closed");
        });
    }

    static void Hidden(View v, bool hidden)
    {
        v.settingsOpen = hidden;
        v.column.gameObject.SetActive(!hidden);
        v.corners.gameObject.SetActive(!hidden);
        v.crawl.gameObject.SetActive(!hidden);
    }

    // The corners' neighbours start anew on each page, so none points at a button that is gone.
    static void ResetCorners(View v)
    {
        v.gear.navigation = new Navigation { mode = Navigation.Mode.Explicit };
        v.exit.navigation = new Navigation { mode = Navigation.Mode.Explicit };
    }

    // ---- building -----------------------------------------------------------------------------------------

    // Empties the button column: a fresh one, `gap` px between its rows, at least as wide as the row.
    static void Clear(View v, float gap)
    {
        if (v.buttons != null)
        {
            // Out of the screen at once, so neither the layout nor a search by name meets the old buttons.
            v.buttons.gameObject.SetActive(false);
            v.buttons.SetParent(null, false);
            UnityEngine.Object.Destroy(v.buttons.gameObject);
        }
        v.buttons = UiKit.Column(v.inset, gap, "Buttons");
        v.buttons.gameObject.AddComponent<LayoutElement>().minWidth = v.rowWidth;
    }

    // One button without the focus pointer, `height` px at least (title_screen.gd _add, slot_list.gd _button).
    static KitButton Add(Transform into, string text, Color fill, Action action, string name, float height = TitleMenu.BUTTON_HEIGHT)
    {
        KitButton b = UiKit.Button(into, text, action, UiKit.SIZE_BODY, fill);
        b.name = name;
        b.DropPointer();
        UiKit.Size(b, 0f, height);
        return b;
    }

    // The muted line above the slots or the question, wrapped inside the row.
    static void Note(View v, string text)
    {
        Text note = UiKit.Paragraph(v.buttons, text, TitleMenu.NOTE_SIZE, UiKit.MUTED);
        note.name = "Note";
        note.alignment = TextAnchor.UpperLeft;
        UiKit.Size(note, v.rowWidth, 0f);
    }

    // A button's own width: its text and the room around it.
    static float Natural(KitButton b)
    {
        RectTransform rt = (RectTransform)b.transform;
        LayoutRebuilder.ForceRebuildLayoutImmediate(rt);
        return LayoutUtility.GetPreferredWidth(rt);
    }

    // A column whose children keep their own width at its left.
    static void Stack(RectTransform rt, float gap, int left)
    {
        VerticalLayoutGroup g = rt.gameObject.AddComponent<VerticalLayoutGroup>();
        g.spacing = gap;
        g.padding = new RectOffset(left, 0, 0, 0);
        g.childAlignment = TextAnchor.UpperLeft;
        g.childControlWidth = g.childControlHeight = true;
        g.childForceExpandWidth = g.childForceExpandHeight = false;
    }

    // The editor keeps statics between plays.
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Boot()
    {
        view = null;
    }
}
