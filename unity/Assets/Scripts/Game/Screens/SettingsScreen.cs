// The settings screen (scenes/settings_menu.gd): volume, sound effects and camera motion sliders, fullscreen,
// UI scale, graphics, frame cap, time of day and weather, the CONTROLS and ACCESSIBILITY pages, and the
// graphics preview beside the card. Every change goes through PlayerSettings, which saves and raises Changed
// (SettingsApply puts it on the engine). One entry point for the title and the pause menu: it runs on
// unscaled frames and reads no rampage state, so it works while RampageGame.Paused.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using Opt = Kaiju.Game.PlayerSettings;
using S = Kaiju.Sim;

public static class SettingsScreen
{
    // settings_menu.gd: the dim over what is behind, the card's least width, the gaps above a button row and
    // above a block, the trims of the page buttons and of BACK.
    public const float DIM_ALPHA = 0.92f;
    public const float PANEL_WIDTH = 980f;
    public const float ROW_GAP = 4f;
    public const float BLOCK_GAP = 14f;
    public const float PAGE_MARGIN = 8f;
    public const float BACK_MARGIN = 10f;

    // True while the screen is up.
    public static bool IsOpen { get; private set; }
    // The player stepped the language: a screen behind this one re-labels itself (the open pages do already).
    public static event Action LanguageChanged;

    static RectTransform open;

    public static void RaiseLanguageChanged()
    {
        LanguageChanged?.Invoke();
    }

    // Shows the settings over `parent` (null: its own layer on the canvas). `onClose` runs once when the
    // player backs out (BACK, Esc, pad B), after which the focus returns to what had it before.
    public static RectTransform Show(Transform parent, Action onClose)
    {
        if (open != null) return open;
        Selectable before = UiFocus.Current;
        RectTransform root = parent != null ? UiKit.Box(parent, "Settings") : UiKit.Screen("Settings");
        UiKit.FullRect(root);
        Color dim = UiKit.BG;
        dim.a = DIM_ALPHA;
        UiKit.Fill(root, dim, "Dim").raycastTarget = true;
        OptionsLabels labels = root.gameObject.AddComponent<OptionsLabels>();

        // The card and the preview side by side, centred on the screen.
        RectTransform centre = UiKit.Row(root, UiKit.BUTTON_GAP, "Centre");
        centre.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.MiddleCenter;
        UiKit.Fit(centre);
        RectTransform card = UiKit.Panel(centre);
        Unfit(card);
        UiKit.Size(card, PANEL_WIDTH, 0f);
        Unfit(OptionsPreview.Build(centre).transform);

        Text title = UiKit.Label(card, "SETTINGS", UiKit.SIZE_TITLE, UiKit.ACCENT);
        title.alignment = TextAnchor.MiddleCenter;
        labels.Add(title, () => Tr.T("SETTINGS"));

        KitSlider volume = Slider(card, labels, "Volume", () => Opt.Volume, Opt.SetVolume);
        KitSlider effects = Slider(card, labels, "Sound effects", Opt.Sfx, Opt.SetSfxVolume);
        KitSlider motion = Slider(card, labels, "Camera motion", Opt.Motion, Opt.SetCameraMotion);

        KitButton fullscreen = Choice(card, labels, () => Opt.SetFullscreen(!Opt.Fullscreen), OptionsRows.Fullscreen);
        KitButton scale = Choice(card, labels, Opt.NextUiScale, OptionsRows.UiScale);
        ButtonRow(card, labels, "Fullscreen and UI scale", fullscreen, scale);
        KitButton graphics = Choice(card, labels, Opt.NextGraphics, OptionsRows.Graphics);
        KitButton fps = Choice(card, labels, Opt.NextFpsCap, OptionsRows.Fps);
        ButtonRow(card, labels, "Graphics and FPS", graphics, fps);
        // One playable time of day is no choice (D-359): the row is left out.
        KitButton time = null;
        if (S.TimeOfDay.HasChoice())
        {
            time = Choice(card, labels, Opt.NextTimeOfDay, OptionsRows.TimeOfDay);
            ButtonRow(card, labels, "Time of day", time);
        }
        KitButton weather = Choice(card, labels, Opt.NextWeather, OptionsRows.Weather);
        ButtonRow(card, labels, "Weather", weather);

        RectTransform pages = UiKit.Row(OptionsPage.Gap(card, BLOCK_GAP), UiKit.BUTTON_GAP, "Pages");
        Transform host = root.parent;
        KitButton controls = null, access = null;
        controls = PageButton(pages, labels, "CONTROLS", () => OptionsControls.Open(host, controls));
        access = PageButton(pages, labels, "ACCESSIBILITY", () => OptionsAccess.Open(host, access));

        KitButton back = UiKit.Button(OptionsPage.Gap(card, BLOCK_GAP), "BACK", null, UiKit.SIZE_HEAD);
        back.TrimHeight(BACK_MARGIN);
        back.name = "Back";  // the smoke run closes the settings by it
        labels.Add(back, () => Tr.T("BACK"));

        bool closed = false;
        Action close = () =>
        {
            if (closed) return;
            closed = true;
            IsOpen = false;
            open = null;
            root.gameObject.SetActive(false);
            UnityEngine.Object.Destroy(root.gameObject);
            Debug.Log($"flow: settings closed, volume {OptionsRows.Percent(Opt.Volume)}%, graphics {Opt.GraphicsLevel()}, language {Tr.Language}");
            onClose?.Invoke();
            // The opener shows its own menu again in onClose; if it lit nothing, what had the focus gets it back.
            Selectable now = UiFocus.Current;
            bool lost = now == null || !now.gameObject.activeInHierarchy;
            if (lost && before != null && before.gameObject.activeInHierarchy) UiFocus.Grab(before);
        };
        back.onClick.AddListener(() => close());
        UiFocus.OnCancel(root.gameObject, close);

        // The focus, wired by hand: the left column top to bottom, the right-hand buttons beside it.
        List<Selectable> left = new List<Selectable> { volume, effects, motion, fullscreen, graphics, time, weather, controls, back };
        UiFocus.Column(left);
        UiFocus.Row(fullscreen, scale);
        UiFocus.Row(graphics, fps);
        UiFocus.Row(controls, access);
        Selectable underFps = time != null ? time : weather;
        UiFocus.Link(scale, MoveDirection.Up, motion);
        UiFocus.Link(scale, MoveDirection.Down, fps);
        UiFocus.Link(fps, MoveDirection.Up, scale);
        UiFocus.Link(fps, MoveDirection.Down, underFps);
        UiFocus.Link(access, MoveDirection.Up, weather);
        UiFocus.Link(access, MoveDirection.Down, back);
        UiFocus.Grab(volume);

        open = root;
        IsOpen = true;
        int rows = time != null ? 7 : 6;
        Debug.Log($"flow: settings shown, {rows} rows, 2 pages, volume {OptionsRows.Percent(Opt.Volume)}%, sfx {OptionsRows.Percent(Opt.Sfx())}%, "
            + $"motion {OptionsRows.Percent(Opt.Motion())}%, fullscreen {Opt.Fullscreen}, scale {OptionsRows.Percent(Opt.UiScale)}%, "
            + $"graphics {Opt.GraphicsLevel()}, fps {Opt.Cap()}, language {Tr.Language}");
        return root;
    }

    // The card and the preview are sized by the row they stand in, not by themselves.
    static void Unfit(Transform panel)
    {
        ContentSizeFitter f = panel.GetComponent<ContentSizeFitter>();
        if (f != null) UnityEngine.Object.Destroy(f);
    }

    // A 0..100 slider on a 0..1 setting, its percent beside it; it follows the setting each frame.
    static KitSlider Slider(Transform card, OptionsLabels labels, string name, Func<double> read, Action<double> write)
    {
        KitSlider s = UiKit.SliderRow(card, name, 0f, OptionsRows.PERCENT_MAX, OptionsRows.VOLUME_STEP, OptionsRows.Percent(read()),
            v => write(OptionsRows.Share(v)), out Text shown);
        labels.AddName(s.transform.parent, () => Tr.T(name));
        labels.Add(shown, () => OptionsRows.PercentText(s.value));
        labels.Each(() =>
        {
            int now = OptionsRows.Percent(read());
            if (Mathf.RoundToInt(s.value) != now) s.SetValueWithoutNotify(now);
        });
        return s;
    }

    static KitButton Choice(Transform card, OptionsLabels labels, Action step, Func<string> value)
    {
        KitButton b = UiKit.Choice(card, "", step);
        labels.Add(b, value);
        return b;
    }

    // A named row of stepping buttons, ROW_GAP under the row above (settings_menu.gd _button_row).
    static void ButtonRow(Transform card, OptionsLabels labels, string name, params Component[] buttons)
    {
        RectTransform line = UiKit.OptionRow(OptionsPage.Gap(card, ROW_GAP), name, buttons);
        labels.AddName(line, () => Tr.T(name));
    }

    static KitButton PageButton(Transform row, OptionsLabels labels, string text, Action open)
    {
        KitButton b = UiKit.Button(row, text, open, UiKit.SIZE_BODY);
        b.TrimHeight(PAGE_MARGIN);
        UiKit.Size(b, 0f, 0f).flexibleWidth = 1f;
        labels.Add(b, () => Tr.T(text));
        return b;
    }
}
