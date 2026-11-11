// What the settings screens show (scenes/settings_menu.gd _refresh, access_menu.gd, controls_menu.gd): each
// row's value as text, the controls page's rows, and what a press does to a binding that waits. Plain C#, no
// engine: the Unity screens (Game/Screens/Settings*.cs, Options*.cs) only lay these out.
using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public static class OptionsRows
    {
        // The sliders run 0..100 in steps of ten (settings_menu.gd VOLUME_STEP).
        public const int PERCENT_MAX = 100;
        public const int VOLUME_STEP = 10;
        // A binding's text while it waits, in English (controls_menu.gd WAIT_KEYS, WAIT_PAD).
        public const string WAIT_KEYS = "PRESS A KEY";
        public const string WAIT_PAD = "PRESS A BUTTON";
        // The Controls list rows shown as text: not rebindable (controls_menu.gd FIXED).
        public static readonly string[] FIXED = { "Fullscreen", "Confirm", "Back" };
        // Capture gives Esc by its key name: it keeps the old binding.
        public const string CANCEL_KEY = "Escape";

        // A share 0..1 as the slider's whole percent.
        public static int Percent(double share)
        {
            return (int)Math.Round(share * PERCENT_MAX, MidpointRounding.AwayFromZero);
        }

        // The slider's value back as a share.
        public static double Share(double percent)
        {
            return percent / PERCENT_MAX;
        }

        public static string PercentText(double percent)
        {
            return Tr.Format("%d%%", (int)Math.Round(percent, MidpointRounding.AwayFromZero));
        }

        // A stepping button's text: "< value >" says a press steps it. `value` is already in the player's language.
        public static string Cycle(string value)
        {
            return "< " + value + " >";
        }

        public static string OnOff(bool on)
        {
            return Cycle(Tr.T(on ? "ON" : "OFF"));
        }

        public static string Fullscreen()
        {
            return OnOff(PlayerSettings.Fullscreen);
        }

        public static string UiScale()
        {
            return Cycle(PercentText(PlayerSettings.UiScale * PERCENT_MAX));
        }

        // The frame cap: 0 is no cap.
        public static string FpsText(int cap)
        {
            return cap <= 0 ? Tr.T("UNLIMITED") : Tr.F("%d FPS", cap);
        }

        public static string Fps()
        {
            return Cycle(FpsText(PlayerSettings.Cap()));
        }

        // A graphics level's name: its id in capitals is the text key (POTATO, LOW, MEDIUM, HIGH, MAX).
        public static string LevelName(string level)
        {
            return Tr.T((level ?? "").ToUpperInvariant());
        }

        public static string Graphics()
        {
            return Cycle(LevelName(PlayerSettings.GraphicsLevel()));
        }

        public static string TimeOfDay()
        {
            return Cycle(Tr.T(S.TimeOfDay.Label(PlayerSettings.TimeOfDay)).ToUpperInvariant());
        }

        public static string Weather()
        {
            return Cycle(Tr.T(S.Weather.Label(PlayerSettings.Weather)).ToUpperInvariant());
        }

        public static string Held()
        {
            return Cycle(Tr.T(PlayerSettings.HoldToggle ? "TOGGLE" : "HOLD"));
        }

        public static string Gore()
        {
            return Cycle(Tr.T(PlayerSettings.Gore ? "ON" : "REDUCED"));
        }

        // Each language's name is shown as its own speakers write it, never translated.
        public static string Language()
        {
            return Cycle(PlayerSettings.LanguageName());
        }

        // The line under the graphics preview (graphics_preview.gd): the level and the frame rate.
        public static string PreviewText(string level, double fps)
        {
            return Tr.Format("%s · %d FPS", (level ?? "").ToUpperInvariant(), (int)Math.Round(fps, MidpointRounding.AwayFromZero));
        }

        // One line of the controls page. Action is null on a fixed row (its Keys and Pad are the text shown).
        public sealed class ControlRow
        {
            public string Name, Action, Keys, Pad;
            public bool PadButton;
        }

        // The controls page top to bottom: every rebindable action, then the fixed rows a demo build may show.
        // Name, Keys and Pad are English: show them through KeyBinds.Shown.
        public static List<ControlRow> Controls()
        {
            List<ControlRow> rows = new List<ControlRow>();
            foreach (KeyBinds.Row a in KeyBinds.Actions())
            {
                rows.Add(new ControlRow { Name = a.Name, Action = a.Action, PadButton = a.PadButton, Pad = a.PadButton ? null : "Left stick" });
            }
            foreach (string[] entry in PlayerSettings.CONTROLS)
            {
                if (Array.IndexOf(FIXED, entry[0]) < 0) continue;
                if (entry.Length > 3 && !S.Demo.Allows(entry[3])) continue;
                rows.Add(new ControlRow { Name = entry[0], Keys = entry[1], Pad = entry[2] });
            }
            return rows;
        }

        // What a binding's button reads: the wait text while it is the one that waits, else its inputs.
        public static string Cell(string action, string slot, string waitAction, string waitSlot)
        {
            if (action == waitAction && slot == waitSlot) return Tr.T(slot == KeyBinds.KEYS ? WAIT_KEYS : WAIT_PAD);
            return KeyBinds.Text(action, slot);
        }

        public enum Press { Ignore, Cancel, Bind }

        // What the press `input` does to the binding waiting in `slot` (controls_menu.gd _input): Esc keeps the
        // old one, a press of the other kind is passed over, anything else is the new binding.
        public static Press Take(string slot, string input, bool isPad)
        {
            if (string.IsNullOrEmpty(input)) return Press.Ignore;
            if (!isPad && input == CANCEL_KEY) return Press.Cancel;
            return isPad == (slot == KeyBinds.PAD) ? Press.Bind : Press.Ignore;
        }
    }
}
