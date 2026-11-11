using System;
using System.Globalization;
using UnityEngine;
using Opt = Kaiju.Game.PlayerSettings;

// Puts the player's settings (Kaiju.Game.PlayerSettings) on the engine: what PlayerSettings.apply() and the
// Settings autoload did in Godot (autoload/player_settings.gd, autoload/settings.gd). GameFlow calls Boot() once
// the tuning is loaded and Tick(paused) every frame; a change of any setting re-applies by itself.
public static class SettingsApply
{
    // Reduce flashing (D-259), for the effects to read: every flash of light is drawn at FlashScale of its
    // brightness, and the colour fringe shows only while FringeOn. 1 and true until the settings are loaded.
    public static float FlashScale = 1f;
    public static bool FringeOn = true;
    // The player's UI scale on top of the 1080p canvas (UiKit multiplies its CanvasScaler by it).
    public static float UiScale = 1f;

    // A window an unattended run opens (D-339: 1080p is the baseline).
    const int WINDOW_WIDTH = 1920, WINDOW_HEIGHT = 1080;
    // The most frames vSync may skip (QualitySettings.vSyncCount's own limit).
    const int VSYNC_MAX = 4;

    // Any -rampage-* flag: the standalone capture run, whose frame pacing stays as RampageGame set it.
    public static bool Standalone { get; private set; }
    // -rampage-clip: frames are being filmed at a fixed step.
    public static bool Filming { get; private set; }
    // -windowed, -flow-smoke or a standalone run: never fullscreen, so an unattended run does not grab the screen.
    public static bool ForcedWindowed { get; private set; }
    public static bool Booted { get; private set; }

    static string graphicsNow, lineNow;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ReadFlags()
    {
        Booted = false;
        graphicsNow = null;
        lineNow = null;
        FlashScale = 1f;
        FringeOn = true;
        UiScale = 1f;
        Standalone = Filming = ForcedWindowed = false;
        foreach (string arg in Environment.GetCommandLineArgs())
        {
            if (arg.StartsWith("-rampage-", StringComparison.Ordinal)) Standalone = true;
            if (arg == "-rampage-clip") Filming = true;
            if (arg == "-windowed" || arg == "-flow-smoke") ForcedWindowed = true;
        }
        ForcedWindowed |= Standalone;
    }

    // Loads settings.json and applies it. Call once S.Content holds the tuning and UserDir.Root is set; a
    // second call (the scene reloads around a rampage) only re-applies.
    public static void Boot()
    {
        if (!Booted)
        {
            Booted = true;
            Opt.ScreenHeight = Application.isBatchMode ? 0 : Display.main.systemHeight;
            Opt.SystemLanguage = Application.systemLanguage.ToString();
            Opt.Changed -= Apply;
            Opt.Changed += Apply;
            // The shipped game starts fullscreen (D-027); editor runs stay windowed.
            Opt.LoadSaved(!Application.isEditor);  // raises Changed, so Apply has run
            return;
        }
        Apply();
    }

    // Every setting that is not per-frame, onto the engine.
    public static void Apply()
    {
        FlashScale = (float)Opt.FlashScale();
        FringeOn = Opt.FringeOn();
        UiScale = (float)Opt.UiScale;
        AudioListener.volume = Mathf.Clamp01((float)Opt.Volume);
        Opt.ApplyLanguage();
        Window();
        string level = Opt.GraphicsLevel();
        if (level != graphicsNow)
        {
            graphicsNow = level;
            // The Godot rows (scale, MSAA, shadows, SSAO...) have no ruled HDRP meaning yet: nothing is applied.
            Debug.Log($"settings: graphics level {level} (HDRP table not ruled yet)");
        }
        // Volume is left out of the change test: a dragged slider would log every step.
        string line = string.Format(CultureInfo.InvariantCulture,
            "fullscreen {0} windowed_forced {1} ui_scale {2:F2} fps {3} graphics {4} flash {5:F2} fringe {6} rumble {7} gore {8} language {9}",
            Opt.Fullscreen, ForcedWindowed, UiScale, Opt.Cap(), level, FlashScale, FringeOn ? 1 : 0, Opt.Rumble ? 1 : 0,
            Opt.GoreOn() ? 1 : 0, Opt.LanguageCode());
        if (line == lineNow) return;
        lineNow = line;
        Debug.Log(string.Format(CultureInfo.InvariantCulture, "settings: volume {0:F2} {1}", Opt.Volume, line));
    }

    // Once a frame (GameFlow.Update): F11, and the frame cap (the player's in an unpaused rampage, tuning
    // menu_fps at most in menus and pause). `paused` is the rampage's pause.
    public static void Tick(bool paused)
    {
        if (!Booted) return;
        if (!ForcedWindowed && Inputs.Down("toggle_fullscreen")) Opt.SetFullscreen(!Opt.Fullscreen);
        // A standalone run measures and films at RampageGame's own pacing: no cap, no vSync change.
        if (Standalone || Filming) return;
        int cap = Opt.FrameCap(paused);
        int refresh = Mathf.RoundToInt((float)Screen.currentResolution.refreshRateRatio.value);
        // vSync where it can hold the cap by itself (Godot ran vSync with max_fps on top): no cap, a cap at or
        // above the screen's rate, or a whole share of it (60 on a 120 Hz screen). Otherwise the cap alone,
        // since Unity ignores targetFrameRate while vSync is on.
        int sync = 0;
        if (cap == 0 || (refresh > 0 && cap >= refresh)) sync = 1;
        else if (refresh > 0 && refresh % cap == 0 && refresh / cap <= VSYNC_MAX) sync = refresh / cap;
        int target = sync > 0 ? -1 : cap;
        // Compared with the engine, not a remembered value: RampageGame.Start uncaps on every scene load.
        if (QualitySettings.vSyncCount == sync && Application.targetFrameRate == target) return;
        QualitySettings.vSyncCount = sync;
        Application.targetFrameRate = target;
        Debug.Log($"settings: frame cap {cap} (vsync {sync}, target {target}, screen {refresh} Hz, paused {paused}, in_play {Opt.InPlay})");
    }

    static void Window()
    {
        if (Application.isBatchMode || Application.isEditor) return;  // no window of the game's own to change
        bool full = Opt.Fullscreen && !ForcedWindowed;
        if (full)
        {
            if (Screen.fullScreenMode == FullScreenMode.FullScreenWindow) return;
            Screen.SetResolution(Display.main.systemWidth, Display.main.systemHeight, FullScreenMode.FullScreenWindow);
            Debug.Log($"settings: window fullscreen {Display.main.systemWidth}x{Display.main.systemHeight}");
            return;
        }
        bool sized = !ForcedWindowed || (Screen.width == WINDOW_WIDTH && Screen.height == WINDOW_HEIGHT);
        if (Screen.fullScreenMode == FullScreenMode.Windowed && sized) return;
        Screen.SetResolution(WINDOW_WIDTH, WINDOW_HEIGHT, FullScreenMode.Windowed);
        Debug.Log($"settings: window windowed {WINDOW_WIDTH}x{WINDOW_HEIGHT}{(ForcedWindowed ? " (forced)" : "")}");
    }
}

// Leaving the game (scenes/quit_game.gd): the one way out, for the title's exit, the end card and the flow.
public static class Quit
{
    public static bool Quitting { get; private set; }

    public static void Now()
    {
        if (Quitting) return;
        Quitting = true;
        Inputs.StopRumble();
        // Only settings that were loaded are written: a standalone run never loaded the player's file.
        if (SettingsApply.Booted)
        {
            try { Opt.Save(); }
            catch (Exception e) { Debug.LogWarning($"quit: settings not saved ({e.Message})"); }
        }
        Debug.Log("quit: now");
        Application.Quit();
    }
}
