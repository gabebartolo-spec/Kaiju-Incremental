// The player's settings (autoload/player_settings.gd): volume (overall and sound effects), camera motion,
// fullscreen, UI scale, the frame cap, graphics, time of day, weather, held moves, reduce flashing, rumble, gore,
// language and the key bindings (KeyBinds), kept in settings.json apart from the save. Plain C#: putting them on
// the engine (audio gains, window, UI scale, frame rate) is the Unity side's job, which listens to Changed.
using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public static class PlayerSettings
    {
        public const string FILE = "settings.json";
        // The display section's version. 2: fps_cap is the player's own choice (-1 = the default for this
        // screen); an older file saved the resolved cap, so its fps_cap is ignored.
        public const int DISPLAY_VERSION = 2;
        // UI scale steps on top of the 1080p canvas (D-027). Every screen fits at the largest step.
        public static readonly double[] UI_SCALES = { 1.0, 1.15, 1.25 };
        // The controls list the settings screen shows: action, keyboard, pad, and for a species-only row that
        // species's id (hidden while Demo.Allows() says it is not playable).
        public static readonly string[][] CONTROLS =
        {
            new[] { "Move", "WASD / arrows", "Left stick" },
            new[] { "Signature attack", "Space", "A" },
            new[] { "Breath (croc)", "Q", "X", "reptilian" },
            new[] { "Leap", "Shift", "B" },
            new[] { "Ultimate", "E", "Y" },
            new[] { "Pause", "Esc / P", "Start" },
            new[] { "Fullscreen", "F11", "-" },
            new[] { "Confirm", "Enter / Space", "A" },
            new[] { "Back", "Esc", "B" },
        };
        // The languages the game is translated into (data/i18n/strings.csv columns), in the order the Language
        // button steps through them, each with its name as its own speakers write it.
        public static readonly string[][] LANGUAGES =
        {
            new[] { "en", "ENGLISH" },
            new[] { "es", "ESPAÑOL" },
            new[] { "fr", "FRANÇAIS" },
            new[] { "it", "ITALIANO" },
            new[] { "de", "DEUTSCH" },
            new[] { "ru", "РУССКИЙ" },
            new[] { "zh_CN", "简体中文" },
        };

        public static double Volume = 0.8;
        // The SFX volume (0..1); -1 = tuning "sfx" default_volume.
        public static double SfxVolume = -1.0;
        // Camera motion (0..1): scales the shake, the footfall dip and the breath swing together; -1 = tuning
        // "camera_shake" default_motion.
        public static double CameraMotion = -1.0;
        public static bool Fullscreen;
        public static double UiScale = 1.0;
        // Frames a second at most in play (0 = unlimited); -1 = tuning "display" fps_default.
        public static int FpsCap = -1;
        // True while a rampage is on screen; menus and pause run at tuning menu_fps at most.
        public static bool InPlay;
        // The graphics preview is open: menus run at the player's own cap, so the rate it shows is the real one.
        public static bool Previewing;
        // Graphics quality, a key of tuning "display" graphics; "" = graphics_default for this screen.
        public static string Graphics = "";
        // True once the controls card has shown at the start of a rampage (once, then they live in Settings).
        public static bool ControlsSeen;
        // The time of day every rampage plays (D-145): "" (Random, the default) or a time's id.
        public static string TimeOfDay = S.TimeOfDay.RANDOM;
        // The weather every rampage plays (D-155): "" (Random, the default) or a weather's id.
        public static string Weather = S.Weather.RANDOM;
        // Held moves (D-259): false = hold the button, true = one press holds the move on, the next lets it go.
        public static bool HoldToggle;
        // Reduce flashing (D-259): flashes at tuning "accessibility" flash_scale, no colour fringe.
        public static bool ReduceFlashing;
        // Pad rumble (D-259), on by default.
        public static bool Rumble = true;
        // Gore (D-259): false = splatter and blood mist become dust.
        public static bool Gore = true;
        // The game's language, a code of LANGUAGES (D-392); "" = the system's when the game has it, else English.
        public static string Language = "";

        // What the host knows and plain C# cannot ask: the system's language (a locale or Unity's SystemLanguage
        // name) and the screen's height in pixels (0 = no screen, as in a headless run).
        public static string SystemLanguage = "";
        public static int ScreenHeight;

        // Raised after any setting or binding changes (and after LoadSaved): the Unity side applies them.
        public static event Action Changed;

        // Every setting back to what a first start has (tests; nothing is saved).
        public static void ResetDefaults()
        {
            Volume = 0.8;
            SfxVolume = -1.0;
            CameraMotion = -1.0;
            Fullscreen = false;
            UiScale = 1.0;
            FpsCap = -1;
            InPlay = false;
            Previewing = false;
            Graphics = "";
            ControlsSeen = false;
            TimeOfDay = S.TimeOfDay.RANDOM;
            Weather = S.Weather.RANDOM;
            HoldToggle = false;
            ReduceFlashing = false;
            Rumble = true;
            Gore = true;
            Language = "";
            KeyBinds.Clear();
        }

        public static void SetVolume(double value)
        {
            Volume = Clamp01(value);
            Save();
        }

        public static void SetSfxVolume(double value)
        {
            SfxVolume = Clamp01(value);
            Save();
        }

        public static void SetCameraMotion(double value)
        {
            CameraMotion = Clamp01(value);
            Save();
        }

        // The camera-motion setting in use, its tuning default until the player sets one.
        public static double Motion()
        {
            return CameraMotion < 0.0 ? S.Num.F(S.Content.Section("camera_shake")["default_motion"]) : CameraMotion;
        }

        // The sound-effects volume, its tuning default until the player sets one.
        public static double Sfx()
        {
            return SfxVolume < 0.0 ? S.Num.F(S.Content.Section("sfx")["default_volume"]) : SfxVolume;
        }

        public static void MarkControlsSeen()
        {
            ControlsSeen = true;
            Save();
        }

        public static void SetFullscreen(bool on)
        {
            Fullscreen = on;
            Save();
        }

        // Steps the UI scale to the next of UI_SCALES (wrapping round).
        public static void NextUiScale()
        {
            UiScale = UI_SCALES[(ScaleAt(UiScale) + 1) % UI_SCALES.Length];
            Save();
        }

        // Steps the frame cap to the next of tuning "display" fps_caps (wrapping round).
        public static void NextFpsCap()
        {
            List<int> caps = Caps();
            FpsCap = caps[(caps.IndexOf(Cap()) + 1) % caps.Count];
            Save();
        }

        // tuning "display" fps_caps as ints.
        public static List<int> Caps()
        {
            List<int> o = new List<int>();
            S.GArray<S.Variant> caps = S.Content.Section("display")["fps_caps"];
            foreach (S.Variant value in caps) o.Add((int)S.Num.I(value));
            return o;
        }

        // The player's frame cap in play (0 = unlimited); on a large (4K) screen the default is tuning
        // "display" graphics_default large_fps.
        public static int Cap()
        {
            if (FpsCap >= 0) return FpsCap;
            S.GDict display = S.Content.Section("display");
            if (Large()) return (int)S.Num.I(display["graphics_default"]["large_fps"]);
            return (int)S.Num.I(display["fps_default"]);
        }

        // The graphics quality in use: the player's, else the default for this screen size.
        public static string GraphicsLevel()
        {
            if (Levels().Contains(Graphics)) return Graphics;
            S.GDict defaults = S.Content.Section("display")["graphics_default"];
            return S.Gd.Str(Large() ? defaults["large"] : defaults["small"]);
        }

        // Steps the graphics quality to the next level (wrapping round).
        public static void NextGraphics()
        {
            List<string> levels = Levels();
            Graphics = levels[(levels.IndexOf(GraphicsLevel()) + 1) % levels.Count];
            Save();
        }

        // Steps the weather setting to the next of Weather.Settings() (wrapping round).
        public static void NextWeather()
        {
            Weather = S.Weather.Next(Weather);
            Save();
        }

        // Steps the time-of-day setting to the next of TimeOfDay.Settings() (wrapping round).
        public static void NextTimeOfDay()
        {
            TimeOfDay = S.TimeOfDay.Next(TimeOfDay);
            Save();
        }

        public static void ToggleHold()
        {
            HoldToggle = !HoldToggle;
            Save();
        }

        public static void ToggleFlashing()
        {
            ReduceFlashing = !ReduceFlashing;
            Save();
        }

        public static void ToggleRumble()
        {
            Rumble = !Rumble;
            Save();
        }

        public static void ToggleGore()
        {
            Gore = !Gore;
            Save();
        }

        // The language in use: the player's, else the system's, else English.
        public static string LanguageCode()
        {
            return SettingsLanguage.Code(SystemLanguage);
        }

        // The name of the language in use, as its own speakers write it.
        public static string LanguageName()
        {
            return SettingsLanguage.ShownName(SystemLanguage);
        }

        // Steps the language to the next of LANGUAGES (wrapping round) and switches the game to it.
        public static void NextLanguage()
        {
            List<string> codes = SettingsLanguage.Codes();
            Language = codes[(codes.IndexOf(LanguageCode()) + 1) % codes.Count];
            ApplyLanguage();
            Save();
        }

        // Switches every translated text (Tr) to the language in use.
        public static void ApplyLanguage()
        {
            Tr.Language = LanguageCode();
        }

        // How bright a flash of light is drawn: 1, or tuning "accessibility" flash_scale under Reduce flashing.
        public static double FlashScale()
        {
            return ReduceFlashing ? S.Num.F(S.Content.Section("accessibility")["flash_scale"]) : 1.0;
        }

        // True while the colour fringe may show (off under Reduce flashing).
        public static bool FringeOn()
        {
            return !ReduceFlashing;
        }

        // True while full gore shows (splatter and blood mist); false: dust instead.
        public static bool GoreOn()
        {
            return Gore;
        }

        // The graphics levels, in tuning's order.
        public static List<string> Levels()
        {
            List<string> o = new List<string>();
            S.GDict table = S.Content.Section("display")["graphics"];
            foreach (S.Variant key in table.Keys()) o.Add(S.Gd.Str(key));
            return o;
        }

        // A screen at least graphics_default min_height tall (4K); never without a screen.
        static bool Large()
        {
            if (ScreenHeight <= 0) return false;
            return ScreenHeight >= S.Num.I(S.Content.Section("display")["graphics_default"]["min_height"]);
        }

        // The row of tuning "display" graphics in use.
        public static S.GDict GraphicsRow()
        {
            S.GDict table = S.Content.Section("display")["graphics"];
            return table[GraphicsLevel()];
        }

        // The frame cap right now: the player's in an unpaused rampage, never above tuning menu_fps in menus or
        // pause, so an idle screen does not spin the graphics card.
        public static int FrameCap(bool paused)
        {
            int menu = (int)S.Num.I(S.Content.Section("display")["menu_fps"]);
            if ((InPlay && !paused) || Previewing) return Cap();
            return Cap() == 0 ? menu : Math.Min(Cap(), menu);
        }

        // Writes settings.json (the sections and keys of Godot's settings.cfg) and tells the listeners.
        public static void Save()
        {
            S.GDict root = new S.GDict
            {
                {
                    "audio", new S.GDict
                    {
                        { "volume", Volume },
                        { "sfx_volume", SfxVolume }, // raw: -1 keeps the tuning default
                    }
                },
                {
                    "display", new S.GDict
                    {
                        { "camera_motion", CameraMotion },
                        { "fullscreen", Fullscreen },
                        { "ui_scale", UiScale },
                        { "version", (long)DISPLAY_VERSION },
                        { "fps_cap", (long)FpsCap },
                        { "graphics", Graphics },
                        { "time_of_day", S.TimeOfDay.Clean(TimeOfDay) },
                        { "weather", S.Weather.Clean(Weather) },
                    }
                },
                {
                    "ui", new S.GDict
                    {
                        { "controls_seen", ControlsSeen },
                        { "language", Language },
                    }
                },
                {
                    "access", new S.GDict
                    {
                        { "hold_toggle", HoldToggle },
                        { "reduce_flashing", ReduceFlashing },
                        { "rumble", Rumble },
                        { "gore", Gore },
                    }
                },
                { "bindings", KeyBinds.Write() },
            };
            UserDir.WriteText(FILE, Json.Stringify(root, "\t"));
            Changed?.Invoke();
        }

        // Reads settings.json (missing keys keep their defaults; `startFull` is the default window mode). A
        // missing or unreadable file leaves every default in place.
        public static void LoadSaved(bool startFull)
        {
            Fullscreen = startFull;
            KeyBinds.Clear();
            S.GDict cfg = ReadFile();
            if (cfg != null)
            {
                S.GDict audio = Part(cfg, "audio"), display = Part(cfg, "display"), ui = Part(cfg, "ui"), access = Part(cfg, "access");
                Volume = Clamp01(S.Num.F(audio.Get("volume", Volume)));
                SfxVolume = UnitOrDefault(audio.Get("sfx_volume", -1.0));
                CameraMotion = UnitOrDefault(display.Get("camera_motion", -1.0));
                Fullscreen = display.Get("fullscreen", Fullscreen) == true;
                ControlsSeen = ui.Get("controls_seen", false) == true;
                int scale = ScaleAt(S.Num.F(display.Get("ui_scale", UiScale)));
                UiScale = UI_SCALES[Math.Max(scale, 0)];
                int savedCap = (int)S.Num.I(display.Get("fps_cap", -1L));
                bool current = S.Num.I(display.Get("version", 1L)) >= DISPLAY_VERSION;
                FpsCap = current && Caps().Contains(savedCap) ? savedCap : -1;
                string saved = S.Gd.Str(display.Get("graphics", Graphics));
                // A level renamed since (tuning "display" graphics_renamed: balanced is now medium).
                S.GDict renamed = S.Content.Section("display")["graphics_renamed"];
                saved = S.Gd.Str(renamed.Get(saved, saved));
                Graphics = Levels().Contains(saved) ? saved : "";
                // An unknown time or weather (since renamed) counts as Random.
                TimeOfDay = S.TimeOfDay.Clean(S.Gd.Str(display.Get("time_of_day", S.TimeOfDay.RANDOM)));
                Weather = S.Weather.Clean(S.Gd.Str(display.Get("weather", S.Weather.RANDOM)));
                HoldToggle = access.Get("hold_toggle", false) == true;
                ReduceFlashing = access.Get("reduce_flashing", false) == true;
                Rumble = access.Get("rumble", true) != false;
                Gore = access.Get("gore", true) != false;
                Language = S.Gd.Str(ui.Get("language", ""));
                KeyBinds.Read(Part(cfg, "bindings"));
            }
            ApplyLanguage();
            Changed?.Invoke();
        }

        static S.GDict ReadFile()
        {
            string text = UserDir.ReadText(FILE);
            if (string.IsNullOrEmpty(text)) return null;
            try
            {
                S.Variant parsed = S.JSON.ParseString(text);
                return parsed.Type == S.Gd.TYPE_DICTIONARY ? (S.GDict)parsed : null;
            }
            catch (Exception)
            {
                return null; // a broken file is a first start, never a crash
            }
        }

        static S.GDict Part(S.GDict cfg, string section)
        {
            S.Variant part = cfg.Get(section, new S.GDict());
            return part.Type == S.Gd.TYPE_DICTIONARY ? (S.GDict)part : new S.GDict();
        }

        // A saved 0..1 setting, or -1 (the tuning default) when it was saved negative.
        static double UnitOrDefault(S.Variant saved)
        {
            double v = S.Num.F(saved);
            return v < 0.0 ? -1.0 : Clamp01(v);
        }

        static double Clamp01(double v)
        {
            return v < 0.0 ? 0.0 : v > 1.0 ? 1.0 : v;
        }

        // Where a scale sits in UI_SCALES (-1 = not one of them); a hair of JSON rounding still matches.
        static int ScaleAt(double scale)
        {
            for (int i = 0; i < UI_SCALES.Length; i++)
            {
                if (Math.Abs(UI_SCALES[i] - scale) < 1e-6) return i;
            }
            return -1;
        }
    }
}
