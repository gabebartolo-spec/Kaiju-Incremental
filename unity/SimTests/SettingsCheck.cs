// The settings, the key table and the text table (GameLogic/PlayerSettings.cs, KeyBinds.cs, Tr.cs,
// SettingsLanguage.cs, after autoload/player_settings.gd, key_binds.gd, settings.gd and settings_language.gd) are
// plain C#, so they are held here: the defaults are Godot's (tuning.json read on its own), a save reads back the
// same, each stepper walks Godot's values, a bind takes the input off the other action, F11 is refused, reset
// restores, and the text table gives the right language or the key.
using System;
using System.Collections.Generic;
using System.IO;
using Kaiju.Game;
using S = Kaiju.Sim;
using Opt = Kaiju.Game.PlayerSettings;

static class SettingsCheck
{
    static int checks, failed;

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        S.FileAccess.Root = repoRoot;
        string oldRoot = UserDir.Root;
        string dir = Path.Combine(Path.GetTempPath(), "kaiju_settings_check_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        UserDir.Root = dir;
        try
        {
            S.GDict tuning = S.JSON.ParseString(File.ReadAllText(Path.Combine(repoRoot, "data", "tuning.json")));
            S.GDict looks = S.JSON.ParseString(File.ReadAllText(Path.Combine(repoRoot, "data", "looks.json")));
            Defaults(tuning);
            Steppers(tuning, looks);
            RoundTrip();
            OldFiles();
            Binds();
            Language();
            Text(File.ReadAllText(Path.Combine(repoRoot, "data", "i18n", "strings.csv")));
        }
        finally
        {
            Opt.ResetDefaults();
            Opt.SystemLanguage = "";
            Opt.ScreenHeight = 0;
            Tr.Language = "en";
            UserDir.Root = oldRoot;
            try { Directory.Delete(dir, true); } catch (IOException) { }
        }
        Console.WriteLine($"settings: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL settings: " + what);
    }

    static void Same<T>(T got, T want, string what)
    {
        Check(EqualityComparer<T>.Default.Equals(got, want), $"{what}: got {got}, want {want}");
    }

    static void Near(double got, double want, string what)
    {
        Check(Math.Abs(got - want) < 1e-9, $"{what}: got {got}, want {want}");
    }

    // A first start: Godot's code defaults, and tuning's where Godot reads tuning.
    static void Defaults(S.GDict tuning)
    {
        Opt.ResetDefaults();
        Opt.ScreenHeight = 1080;
        Opt.LoadSaved(false); // no file yet
        S.GDict display = tuning["display"];
        Near(Opt.Volume, 0.8, "default volume");
        Near(Opt.SfxVolume, -1.0, "default sfx_volume is unset");
        Near(Opt.Sfx(), S.Num.F(tuning["sfx"]["default_volume"]), "default sfx volume is tuning sfx.default_volume");
        Near(Opt.CameraMotion, -1.0, "default camera_motion is unset");
        Near(Opt.Motion(), S.Num.F(tuning["camera_shake"]["default_motion"]), "default motion is tuning camera_shake.default_motion");
        Same(Opt.Fullscreen, false, "default fullscreen follows start_full false");
        Near(Opt.UiScale, 1.0, "default ui scale");
        Same(Opt.FpsCap, -1, "default fps_cap is unset");
        Same(Opt.Cap(), (int)S.Num.I(display["fps_default"]), "default cap is tuning display.fps_default");
        Same(Opt.Graphics, "", "default graphics is unset");
        Same(Opt.GraphicsLevel(), S.Gd.Str(display["graphics_default"]["small"]), "default graphics level is graphics_default.small");
        Same(Opt.ControlsSeen, false, "default controls_seen");
        Same(Opt.TimeOfDay, "", "default time of day is Random");
        Same(Opt.Weather, "", "default weather is Random");
        Same(Opt.HoldToggle, false, "default hold_toggle");
        Same(Opt.ReduceFlashing, false, "default reduce_flashing");
        Same(Opt.Rumble, true, "default rumble");
        Same(Opt.Gore, true, "default gore");
        Same(Opt.Language, "", "default language is unset");
        Near(Opt.FlashScale(), 1.0, "flash scale 1 with Reduce flashing off");
        Same(Opt.FringeOn(), true, "fringe on with Reduce flashing off");
        Same(Opt.GoreOn(), true, "gore on by default");
        Same(UserDir.Exists(Opt.FILE), false, "reading the defaults writes no file");

        // A 4K screen takes the large defaults.
        Opt.ScreenHeight = (int)S.Num.I(display["graphics_default"]["min_height"]);
        Same(Opt.Cap(), (int)S.Num.I(display["graphics_default"]["large_fps"]), "4K default cap is graphics_default.large_fps");
        Same(Opt.GraphicsLevel(), S.Gd.Str(display["graphics_default"]["large"]), "4K default graphics is graphics_default.large");
        Opt.ScreenHeight = 1080;

        // The frame cap: the player's in play, never above menu_fps in menus or pause.
        int menu = (int)S.Num.I(display["menu_fps"]);
        Opt.InPlay = false;
        Same(Opt.FrameCap(false), Math.Min(Opt.Cap(), menu), "menu frame cap");
        Opt.InPlay = true;
        Same(Opt.FrameCap(false), Opt.Cap(), "frame cap in play");
        Same(Opt.FrameCap(true), Math.Min(Opt.Cap(), menu), "frame cap paused");
        Opt.FpsCap = 0;
        Same(Opt.FrameCap(false), 0, "unlimited in play");
        Same(Opt.FrameCap(true), menu, "unlimited is menu_fps when paused");
        Opt.InPlay = false;
        Opt.Previewing = true;
        Same(Opt.FrameCap(false), 0, "the preview lifts the menu cap");
        Opt.Previewing = false;
        Opt.FpsCap = -1;

        Opt.ReduceFlashing = true;
        Near(Opt.FlashScale(), S.Num.F(tuning["accessibility"]["flash_scale"]), "flash scale is tuning accessibility.flash_scale under Reduce flashing");
        Same(Opt.FringeOn(), false, "no fringe under Reduce flashing");
        Opt.ReduceFlashing = false;

        // The default bindings (autoload/settings.gd).
        Same(string.Join(",", KeyBinds.Events("move_left", KeyBinds.KEYS)), "A,LeftArrow", "move_left keys");
        Same(string.Join(",", KeyBinds.Events("move_right", KeyBinds.KEYS)), "D,RightArrow", "move_right keys");
        Same(string.Join(",", KeyBinds.Events("move_up", KeyBinds.KEYS)), "W,UpArrow", "move_up keys");
        Same(string.Join(",", KeyBinds.Events("move_down", KeyBinds.KEYS)), "S,DownArrow", "move_down keys");
        Same(Both("signature"), "Space|A", "signature");
        Same(Both("ultimate"), "E|Y", "ultimate");
        Same(Both("breath"), "Q|X", "breath");
        Same(Both("dash"), "LeftShift,RightShift|B", "dash");
        Same(Both("pause"), "Escape,P|Start", "pause");
        Same(Both("toggle_fullscreen"), "F11|", "toggle_fullscreen");
        Same(Both("photo_rise"), "E|RB", "photo_rise");
        Same(Both("photo_sink"), "Q|LB", "photo_sink");
        Same(Both("photo_hint"), "H|X", "photo_hint");
        Same(KeyBinds.HasAction("photo_look_left"), true, "photo_look_left exists");
        Same(KeyBinds.HasAction("stomp"), false, "no stomp action");
        Same(KeyBinds.Text("pause", KeyBinds.KEYS), "Esc / P", "pause shows Esc / P");
        Same(KeyBinds.Text("dash", KeyBinds.KEYS), "Shift", "dash shows Shift once");
        Same(KeyBinds.Text("move_up", KeyBinds.PAD), "-", "an empty slot shows -");
    }

    static string Both(string action)
    {
        return string.Join(",", KeyBinds.Events(action, KeyBinds.KEYS)) + "|" + string.Join(",", KeyBinds.Events(action, KeyBinds.PAD));
    }

    // Each stepper walks the values Godot's does, in order, and wraps.
    static void Steppers(S.GDict tuning, S.GDict looks)
    {
        Opt.ResetDefaults();
        Opt.ScreenHeight = 1080;
        Opt.SystemLanguage = "";
        S.GDict display = tuning["display"];

        List<string> got = new List<string>();
        for (int i = 0; i < 4; i++) { Opt.NextUiScale(); got.Add(S.Gd.Str(Opt.UiScale)); }
        Same(string.Join(" ", got), "1.15 1.25 1.0 1.15", "ui scale steps");

        // From the default cap: the next of tuning fps_caps after it, wrapping.
        List<int> caps = new List<int>();
        S.GArray<S.Variant> rawCaps = display["fps_caps"];
        foreach (S.Variant c in rawCaps) caps.Add((int)S.Num.I(c));
        int at = caps.IndexOf((int)S.Num.I(display["fps_default"]));
        List<string> want = new List<string>();
        got.Clear();
        for (int i = 0; i < caps.Count + 1; i++)
        {
            at = (at + 1) % caps.Count;
            want.Add(caps[at].ToString());
            Opt.NextFpsCap();
            got.Add(Opt.FpsCap.ToString());
        }
        Same(string.Join(" ", got), string.Join(" ", want), "fps cap steps");
        Same(string.Join(" ", got), "0 60 120 0", "fps cap steps as Godot's today (120 default: unlimited, 60, 120)");

        List<string> levels = new List<string>();
        S.GDict table = display["graphics"];
        foreach (S.Variant k in table.Keys()) levels.Add(S.Gd.Str(k));
        at = levels.IndexOf(S.Gd.Str(display["graphics_default"]["small"]));
        want.Clear();
        got.Clear();
        for (int i = 0; i < levels.Count + 1; i++)
        {
            at = (at + 1) % levels.Count;
            want.Add(levels[at]);
            Opt.NextGraphics();
            got.Add(Opt.Graphics);
        }
        Same(string.Join(" ", got), string.Join(" ", want), "graphics steps");
        Same(string.Join(" ", got), "max potato low medium high max", "graphics steps as Godot's today");

        // Weather: Random, then each of looks.json weather order. Time of day: Random, then each playable time.
        want.Clear();
        got.Clear();
        S.GArray<S.Variant> weathers = looks["weather"]["order"];
        foreach (S.Variant w in weathers) want.Add(S.Gd.Str(w));
        want.Add("");
        for (int i = 0; i < want.Count; i++) { Opt.NextWeather(); got.Add(Opt.Weather); }
        Same(string.Join(" ", got), string.Join(" ", want), "weather steps");
        want.Clear();
        got.Clear();
        S.GDict times = looks["times"];
        S.GArray<S.Variant> play = times.Get("play", times["order"]);
        foreach (S.Variant t in play) want.Add(S.Gd.Str(t));
        want.Add("");
        for (int i = 0; i < want.Count; i++) { Opt.NextTimeOfDay(); got.Add(Opt.TimeOfDay); }
        Same(string.Join(" ", got), string.Join(" ", want), "time of day steps");

        got.Clear();
        for (int i = 0; i < 7; i++) { Opt.NextLanguage(); got.Add(Opt.Language); }
        Same(string.Join(" ", got), "es fr it de ru zh_CN en", "language steps");
        Same(Tr.Language, "en", "the language step switches the text table");

        Opt.ToggleHold();
        Opt.ToggleFlashing();
        Opt.ToggleRumble();
        Opt.ToggleGore();
        Same($"{Opt.HoldToggle} {Opt.ReduceFlashing} {Opt.Rumble} {Opt.Gore}", "True True False False", "toggles flip");
        Same(Opt.GoreOn(), false, "gore off reads off");
        Opt.ToggleHold();
        Opt.ToggleFlashing();
        Opt.ToggleRumble();
        Opt.ToggleGore();
        Same($"{Opt.HoldToggle} {Opt.ReduceFlashing} {Opt.Rumble} {Opt.Gore}", "False False True True", "toggles flip back");

        Opt.SetVolume(1.7);
        Near(Opt.Volume, 1.0, "volume clamps high");
        Opt.SetSfxVolume(-3.0);
        Near(Opt.SfxVolume, 0.0, "sfx volume clamps low");
        Opt.SetCameraMotion(0.4);
        Near(Opt.Motion(), 0.4, "camera motion set");

        int raised = 0;
        Action count = () => raised++;
        Opt.Changed += count;
        Opt.ToggleGore();
        Opt.ToggleGore();
        Opt.Changed -= count;
        Same(raised, 2, "Changed is raised once per change");
    }

    // Every field set away from its default, saved, forgotten and read back.
    static void RoundTrip()
    {
        Opt.ResetDefaults();
        UserDir.Delete(Opt.FILE);
        Opt.SetVolume(0.35);
        Opt.SetSfxVolume(0.6);
        Opt.SetCameraMotion(0.25);
        Opt.SetFullscreen(true);
        Opt.NextUiScale(); // 1.15
        Opt.FpsCap = 60;
        Opt.Graphics = "low";
        Opt.MarkControlsSeen();
        Opt.TimeOfDay = "dusk";
        Opt.Weather = "rain";
        Opt.ToggleHold();
        Opt.ToggleFlashing();
        Opt.ToggleRumble();
        Opt.ToggleGore();
        Opt.Language = "de";
        Check(KeyBinds.Bind("breath", KeyBinds.KEYS, "F"), "breath binds to F");
        Check(KeyBinds.Bind("breath", KeyBinds.PAD, "RT"), "breath binds to RT");
        Opt.Save();
        Same(UserDir.Exists(Opt.FILE), true, "settings.json written");
        string text = UserDir.ReadText(Opt.FILE);
        S.GDict file = S.JSON.ParseString(text);
        Same(S.Num.I(file["display"]["version"]), 2L, "display version 2 written");
        Check(text.Contains("\"fps_cap\": 60") && !text.Contains("\"fps_cap\": 60.0"), "fps_cap is written as an int");
        Same(S.Gd.Str(file["bindings"]["breath"]["keys"][0]), "F", "the binding is written by name");

        Opt.ResetDefaults();
        Near(Opt.Volume, 0.8, "reset forgets the volume");
        Same(Both("breath"), "Q|X", "reset forgets the binding");
        Opt.LoadSaved(false);
        Near(Opt.Volume, 0.35, "volume round trip");
        Near(Opt.SfxVolume, 0.6, "sfx volume round trip");
        Near(Opt.CameraMotion, 0.25, "camera motion round trip");
        Same(Opt.Fullscreen, true, "fullscreen round trip");
        Same(Opt.UiScale, 1.15, "ui scale round trip (exactly a UI_SCALES step)");
        Same(Opt.FpsCap, 60, "fps cap round trip");
        Same(Opt.Graphics, "low", "graphics round trip");
        Same(Opt.ControlsSeen, true, "controls_seen round trip");
        Same(Opt.TimeOfDay, "dusk", "time of day round trip");
        Same(Opt.Weather, "rain", "weather round trip");
        Same(Opt.HoldToggle, true, "hold_toggle round trip");
        Same(Opt.ReduceFlashing, true, "reduce_flashing round trip");
        Same(Opt.Rumble, false, "rumble round trip");
        Same(Opt.Gore, false, "gore round trip");
        Same(Opt.Language, "de", "language round trip");
        Same(Tr.Language, "de", "loading switches the text table");
        Same(Both("breath"), "F|RT", "binding round trip");
        Same(Both("signature"), "Space|A", "an unbound action keeps its defaults after a load");

        // Unset values stay unset through a save (-1 keeps the tuning default).
        Opt.ResetDefaults();
        Opt.Save();
        Opt.Volume = 0.1;
        Opt.LoadSaved(true);
        Near(Opt.Volume, 0.8, "default volume round trip");
        Near(Opt.SfxVolume, -1.0, "unset sfx volume round trip");
        Near(Opt.CameraMotion, -1.0, "unset camera motion round trip");
        Same(Opt.FpsCap, -1, "unset fps cap round trip");
        Same(Opt.Fullscreen, false, "a saved windowed choice beats start_full");
        Same(Opt.Rumble, true, "rumble default round trip");
    }

    // Files a hand or an older build wrote.
    static void OldFiles()
    {
        Opt.ResetDefaults();
        UserDir.WriteText(Opt.FILE, "{\"display\": {\"fps_cap\": 60, \"graphics\": \"balanced\", \"ui_scale\": 1.2, \"time_of_day\": \"night\", \"weather\": \"hail\"},"
            + " \"audio\": {\"volume\": 7}, \"junk\": 3, \"bindings\": {\"breath\": {\"keys\": [\"F\", 3], \"pad\": [\"Nope\"], \"feet\": [\"G\"]}, \"stomp\": {\"keys\": [\"G\"]}, \"dash\": 4}}");
        Opt.LoadSaved(true);
        Same(Opt.FpsCap, -1, "a display section without version 2 loses its fps_cap");
        Same(Opt.Graphics, "medium", "balanced loads as medium (graphics_renamed)");
        Near(Opt.UiScale, 1.0, "an unknown ui scale is the first step");
        Same(Opt.TimeOfDay, "", "a time that is not playable is Random");
        Same(Opt.Weather, "", "an unknown weather is Random");
        Near(Opt.Volume, 1.0, "a saved volume is clamped");
        Same(Opt.Fullscreen, true, "a file without fullscreen keeps start_full");
        Same(Opt.Rumble, true, "a file without rumble keeps it on");
        Same(Both("breath"), "F|", "unknown inputs and slots are skipped");
        Same(Both("dash"), "LeftShift,RightShift|B", "a binding that is not a table is skipped");
        Same(KeyBinds.HasAction("stomp"), false, "an unknown action is skipped");

        UserDir.WriteText(Opt.FILE, "{\"display\": {\"version\": 2, \"fps_cap\": 75}}");
        Opt.LoadSaved(false);
        Same(Opt.FpsCap, -1, "a cap that is not one of fps_caps is unset");

        Opt.ResetDefaults();
        UserDir.WriteText(Opt.FILE, "{\"audio\": {\"volume\": 0.2");
        Opt.LoadSaved(true);
        Near(Opt.Volume, 0.8, "a broken file leaves the defaults");
        Same(Opt.Fullscreen, true, "a broken file keeps start_full");
        UserDir.WriteText(Opt.FILE, "[1, 2]");
        Opt.LoadSaved(false);
        Near(Opt.Volume, 0.8, "a file that is not a table leaves the defaults");
        UserDir.Delete(Opt.FILE);
    }

    static void Binds()
    {
        Opt.ResetDefaults();
        UserDir.Delete(Opt.FILE);

        // Binding takes the input off the action that had it.
        Check(KeyBinds.Bind("signature", KeyBinds.KEYS, "Q"), "signature binds to Q");
        Same(Both("signature"), "Q|A", "signature now on Q, its pad untouched");
        Same(Both("breath"), "|X", "breath lost Q (bind steals)");
        Same(KeyBinds.Text("breath", KeyBinds.KEYS), "-", "breath's keys show -");
        Same(Both("photo_sink"), "Q|LB", "a fixed action keeps its key");
        Same(UserDir.Exists(Opt.FILE), true, "a bind saves at once");
        Check(KeyBinds.IsChanged("breath", KeyBinds.KEYS) && !KeyBinds.IsChanged("breath", KeyBinds.PAD), "the robbed slot counts as changed");

        // One of two keys taken: the other stays.
        Check(KeyBinds.Bind("ultimate", KeyBinds.KEYS, "P"), "ultimate binds to P");
        Same(Both("pause"), "Escape|Start", "pause keeps Esc, loses P");
        Check(KeyBinds.Bind("dash", KeyBinds.PAD, "A"), "dash pad binds to A");
        Same(Both("signature"), "Q|", "signature lost pad A");
        Same(Both("dash"), "LeftShift,RightShift|A", "dash pad is A, B replaced");
        // Key "A" and pad "A" are different inputs.
        Same(Both("move_left"), "A,LeftArrow|", "pad A does not take the A key");

        // F11 belongs to a fixed action.
        Same(KeyBinds.Bind("signature", KeyBinds.KEYS, "F11"), false, "F11 is refused");
        Same(Both("signature"), "Q|", "a refused bind changes nothing");
        Same(Both("toggle_fullscreen"), "F11|", "fullscreen keeps F11");
        Same(KeyBinds.Bind("signature", KeyBinds.PAD, "Space"), false, "a key is no pad button");
        Same(KeyBinds.Bind("stomp", KeyBinds.KEYS, "G"), false, "an unknown action is refused");
        Same(KeyBinds.Bind("signature", "feet", "G"), false, "an unknown slot is refused");
        KeyBinds.KeyKnown = name => name != "Wibble";
        Same(KeyBinds.Bind("signature", KeyBinds.KEYS, "Wibble"), false, "a key the engine does not know is refused");
        KeyBinds.KeyKnown = null;

        // The Controls list shows the player's keys for the slots that changed.
        string[] row = KeyBinds.RowText(Opt.CONTROLS[1]);
        Same(row[1] + "|" + row[2], "Q|-", "the signature row shows the new key and the emptied pad");
        row = KeyBinds.RowText(Opt.CONTROLS[0]);
        Same(row[1] + "|" + row[2], "WASD / arrows|Left stick", "an untouched row keeps its text");
        Check(KeyBinds.Bind("move_up", KeyBinds.KEYS, "I"), "move_up binds to I");
        row = KeyBinds.RowText(Opt.CONTROLS[0]);
        Same(row[1], "I A / Left S / Down D / Right", "the move row lists its four actions");
        Check(KeyBinds.Bind("ultimate", KeyBinds.KEYS, "Mouse1"), "ultimate binds to the right mouse button");
        Same(KeyBinds.Text("ultimate", KeyBinds.KEYS), "Right click", "a mouse button shows by name");
        Same(KeyBinds.InputName(KeyBinds.KEYS, "Mouse5"), "Mouse 6", "a further mouse button shows by number");
        Same(KeyBinds.InputName(KeyBinds.PAD, "DpadUp"), "D-pad up", "a d-pad button shows by name");
        Same(KeyBinds.InputName(KeyBinds.PAD, "LS"), "L3", "the stick click shows as L3");

        // Shift is one key, as Godot's KEY_SHIFT: either side takes both off Leap and binds both.
        Check(KeyBinds.Bind("signature", KeyBinds.KEYS, "LeftShift"), "signature binds to Shift");
        Same(Both("signature"), "LeftShift,RightShift|", "one Shift pressed binds both sides");
        Same(KeyBinds.Text("signature", KeyBinds.KEYS), "Shift", "and shows Shift once");
        Same(KeyBinds.Text("dash", KeyBinds.KEYS), "-", "Leap lost both Shifts");
        Check(KeyBinds.Bind("dash", KeyBinds.KEYS, "RightControl"), "leap binds to Ctrl");
        Same(Both("dash"), "LeftControl,RightControl|A", "one Ctrl pressed binds both sides");

        // Reset: the defaults back, and the file with them.
        KeyBinds.Reset();
        Same(Both("signature"), "Space|A", "reset restores signature");
        Same(Both("breath"), "Q|X", "reset restores breath");
        Same(Both("pause"), "Escape,P|Start", "reset restores pause");
        Same(Both("dash"), "LeftShift,RightShift|B", "reset restores dash");
        Same(Both("move_up"), "W,UpArrow|", "reset restores move_up");
        Opt.LoadSaved(false);
        Same(Both("signature"), "Space|A", "the reset was saved");
        Same(KeyBinds.Actions().Length, 9, "nine rebindable actions (no stomp)");
    }

    static void Language()
    {
        Opt.ResetDefaults();
        Same(SettingsLanguage.Code(""), "en", "no system language: English");
        Same(SettingsLanguage.Code("es_MX"), "es", "a Spanish system: Spanish");
        Same(SettingsLanguage.Code("zh_TW"), "zh_CN", "any Chinese system: Simplified Chinese");
        Same(SettingsLanguage.Code("zh-Hans-CN"), "zh_CN", "a dashed locale reads the same");
        Same(SettingsLanguage.Code("ja_JP"), "en", "a language the game lacks: English");
        Same(SettingsLanguage.Code("German"), "de", "Unity's language name is read");
        Same(SettingsLanguage.Code("ChineseTraditional"), "zh_CN", "Unity's Chinese names are read");
        Same(SettingsLanguage.ShownName("ru_RU"), "РУССКИЙ", "the language's own name");
        Opt.Language = "fr";
        Same(SettingsLanguage.Code("es_ES"), "fr", "the player's choice beats the system");
        Opt.Language = "xx";
        Same(SettingsLanguage.Code("es_ES"), "es", "an unknown saved language falls to the system");
        Opt.Language = "";
        Opt.SystemLanguage = "it_IT";
        Same(Opt.LanguageCode(), "it", "PlayerSettings reads the host's system language");
        Same(Opt.LanguageName(), "ITALIANO", "and names it");
        Opt.NextLanguage();
        Same(Opt.Language, "de", "the step goes on from the language in use");
        Opt.SystemLanguage = "";
        Opt.Language = "";
        UserDir.Delete(Opt.FILE);
    }

    static void Text(string csv)
    {
        List<string[]> rows = Tr.Parse(csv);
        int bad = 0;
        string first = "";
        foreach (string[] row in rows)
        {
            if (row.Length == 8) continue;
            bad++;
            if (first == "") first = row[0];
        }
        Check(rows.Count > 300, $"strings.csv has its rows (got {rows.Count})");
        Check(bad == 0, $"every CSV row has 8 columns ({bad} do not, first \"{first}\")");
        Same(string.Join(",", rows[0]), "keys,en,es,fr,it,de,ru,zh_CN", "the header row");

        Tr.Load(csv);
        Same(Tr.Count, rows.Count - 1, "every row is a key");
        Same(string.Join(",", Tr.Languages), string.Join(",", SettingsLanguage.Codes()), "the columns are PlayerSettings.LANGUAGES");
        Tr.Language = "es";
        Same(Tr.T("SETTINGS"), "AJUSTES", "es SETTINGS");
        Same(Tr.T("BACK"), "VOLVER", "es BACK");
        Same(Tr.T("Leap"), "Salto", "es Leap");
        Same(Tr.T("NO SUCH TEXT 123"), "NO SUCH TEXT 123", "an unknown key is itself");
        Same(Tr.F("Mouse %d", 4), "Ratón 4", "es Mouse %d filled");
        Same(KeyBinds.InputName(KeyBinds.PAD, "DpadUp"), Tr.T("D-pad up"), "input names follow the language");
        Tr.Language = "zh_CN";
        Same(Tr.T("SETTINGS"), "设置", "zh_CN SETTINGS");
        Same(Tr.T("BACK"), "返回", "zh_CN BACK");
        Same(Tr.T("Leap"), "跳跃", "zh_CN Leap");
        Same(Tr.T("NO SUCH TEXT 123"), "NO SUCH TEXT 123", "an unknown key is itself in zh_CN");
        Tr.Language = "ru";
        Same(Tr.T("BIGGER THAN EVER"), "КРУПНЕЕ, ЧЕМ КОГДА-ЛИБО", "a quoted cell keeps its comma");
        Tr.Language = "es";
        Same(Tr.F("CONTINUE GAME\n%s", "K-01"), "CONTINUAR\nK-01", "a cell with a line break is one key");
        Same(Tr.F("BIGGER THAN LAST TIME  +%d%% BIOMASS", 12), "MÁS GRANDE QUE LA ÚLTIMA VEZ  +12% BIOMASA", "%d and %% fill");
        Same(Tr.T(" a second"), " un segundo", "a leading space is part of the key");
        Tr.Language = "en";
        Same(Tr.T("SETTINGS"), "SETTINGS", "en is the key");
        Tr.Language = "xx";
        Same(Tr.T("SETTINGS"), "SETTINGS", "an unknown language gives the key");
        Tr.Language = "en";

        Same(Tr.Format("%02d:%02d", 3, 7), "03:07", "%02d pads");
        Same(Tr.Format("%s has %d (%d%%)", "croc", 5L, 2.9), "croc has 5 (2%)", "%s, %d and %% together; %d cuts a float");
        Same(Tr.Format("%.1f x", 1.25), "1.2 x".Replace("1.2", (1.25).ToString("F1", System.Globalization.CultureInfo.InvariantCulture)), "%.1f");
        Same(Tr.Format("100% sure"), "100% sure", "a lone % is shown");

        List<string[]> odd = Tr.Parse("a,\"b \"\"q\"\", c\",\r\n\r\n\"two\nlines\",x,y\n");
        Same(odd.Count, 2, "blank lines are no rows");
        Same(odd[0].Length == 3 ? odd[0][1] + "|" + odd[0][2] : "?", "b \"q\", c|", "doubled quotes, a comma in quotes, an empty last cell");
        Same(odd[1][0], "two\nlines", "a line break inside quotes");
    }
}
