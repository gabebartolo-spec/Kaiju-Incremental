// The pause menu (scenes/pause_menu.gd) and its "Are you sure?" (scenes/end_confirm.gd, D-155): RESUME,
// SETTINGS and END RAMPAGE over the stopped rampage. Pause (Esc, Start) or cancel (Esc, pad B) resumes while
// the menu's own card is up; behind the settings or the confirm they belong to those. Photo mode and the
// feedback report are a later wave: their rows are not here.
using System;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

public static class PauseMenu
{
    // Godot's layout numbers (px at 1080p).
    const float CARD_WIDTH = 600f;
    const float GAP = 16f;
    const float BUTTON_HEIGHT = 76f;
    const float CONFIRM_BUTTON_WIDTH = 380f;
    const float DIM = 0.6f;

    // onResume: RESUME, pause or cancel. onSettings: SETTINGS; the card hides itself first, so call
    // SettingsClosed when the settings page closes. onEndRun: END RAMPAGE then YES, END IT (the caller unpauses
    // and ends the sim's run). onQuit: never called; Godot's pause menu has no quit-to-menu row.
    public static RectTransform Show(Action onResume, Action onSettings, Action onEndRun, Action onQuit)
    {
        RectTransform screen = UiKit.Screen("Pause");
        PauseKeys keys = screen.gameObject.AddComponent<PauseKeys>();
        keys.onResume = onResume;
        keys.onEndRun = onEndRun;
        keys.shownFrame = Time.frameCount;
        // The dim also keeps the mouse off the game behind.
        UiKit.Fill(screen, new Color(0f, 0f, 0f, DIM), "Dim").raycastTarget = true;
        RectTransform centre = UiKit.Box(screen, "Centre");
        UiKit.FullRect(centre);
        RectTransform card = UiKit.Panel(centre, null, GAP);
        keys.card = card.gameObject;
        UiKit.Size(card, CARD_WIDTH, 0f);
        UiKit.Header(card, "PAUSED");
        KitButton resume = MenuButton(card, "RESUME", UiKit.ACCENT, keys.Resume, "Resume");
        KitButton settings = MenuButton(card, "SETTINGS", UiKit.PANEL_EDGE, () =>
        {
            if (onSettings == null) return;
            // The buttons take no click or key while the settings are up.
            card.gameObject.SetActive(false);
            Debug.Log("flow: pause settings opened");
            onSettings();
        }, "Settings");
        KitButton end = MenuButton(card, "END RAMPAGE", UiKit.PANEL_EDGE, () => Confirm(keys), "End");
        Text note = UiKit.Label(card, "You keep the biomass", UiKit.SIZE_BODY, UiKit.MUTED);
        note.alignment = TextAnchor.MiddleCenter;
        keys.resume = resume;
        UiFocus.Column(resume, settings, end);
        // On the card, so cancel is the settings' or the confirm's while the card is hidden.
        UiFocus.OnCancel(card.gameObject, keys.Resume);
        UiKit.Focus(resume);
        Debug.Log("flow: pause shown, 3 buttons (Resume, Settings, End)");
        return screen;
    }

    // The settings page opened from SETTINGS closed: the card comes back with RESUME in focus.
    public static void SettingsClosed(RectTransform screen)
    {
        PauseKeys keys = screen != null ? screen.GetComponent<PauseKeys>() : null;
        if (keys != null) keys.Restore();
    }

    static KitButton MenuButton(Transform parent, string text, Color fill, Action onPress, string name)
    {
        KitButton b = UiKit.Button(parent, text, onPress, UiKit.SIZE_HEAD, fill);
        b.name = name;
        UiKit.Size(b, 0f, BUTTON_HEIGHT);
        return b;
    }

    // "Are you sure?" before End Rampage: KEEP PLAYING (in focus) or YES, END IT; cancel keeps playing.
    static void Confirm(PauseKeys keys)
    {
        if (keys.confirm != null) return;
        S.GDict cfg = S.Content.Section("pause");
        keys.card.SetActive(false);
        RectTransform root = UiKit.Box(keys.transform, "EndConfirm");
        UiKit.FullRect(root);
        keys.confirm = root.gameObject;
        RectTransform card = UiKit.Panel(root, null, GAP);
        Text title = UiKit.Label(card, S.Gd.Str(cfg["end_title"]), UiKit.SIZE_HEAD, UiKit.ACCENT);
        title.alignment = TextAnchor.MiddleCenter;
        Text line = UiKit.Label(card, S.Gd.Str(cfg["end_line"]), UiKit.SIZE_BODY, UiKit.MUTED);
        line.alignment = TextAnchor.MiddleCenter;
        RectTransform row = UiKit.Row(card, GAP, "Buttons");
        row.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.MiddleCenter;
        KitButton keep = UiKit.Button(row, S.Gd.Str(cfg["end_keep"]), keys.CloseConfirm, UiKit.SIZE_HEAD, UiKit.ACCENT);
        keep.name = "Keep";
        UiKit.Size(keep, CONFIRM_BUTTON_WIDTH, BUTTON_HEIGHT);
        KitButton yes = UiKit.Button(row, S.Gd.Str(cfg["end_yes"]), keys.EndRun, UiKit.SIZE_HEAD, UiKit.PANEL_EDGE);
        yes.name = "Yes";
        UiKit.Size(yes, CONFIRM_BUTTON_WIDTH, BUTTON_HEIGHT);
        UiFocus.Row(keep, yes);
        UiFocus.OnCancel(root.gameObject, keys.CloseConfirm);
        UiKit.Focus(keep);
        Debug.Log("flow: pause end asked, 2 buttons (Keep, Yes)");
    }
}
