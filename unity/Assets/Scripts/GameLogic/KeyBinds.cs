// The player's own keys and pad buttons (autoload/key_binds.gd, D-259), with the defaults autoload/settings.gd
// built. An input is a name: a Unity KeyCode name in the "keys" slot ("Space", "LeftShift", "Mouse0"), a pad
// button name in the "pad" slot (PAD_BUTTONS). Binding a new input replaces the whole slot and takes that input
// off every other rebindable action, so one press never does two things. Sticks are not bindings: the moves
// stay on the left stick and photo mode's look on the right (Inputs reads them). Plain C#, no engine.
using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public static class KeyBinds
    {
        public const string KEYS = "keys";
        public const string PAD = "pad";
        // Fixed actions whose keys a rebind may not take: F11 would toggle fullscreen too.
        public static readonly string[] RESERVED = { "toggle_fullscreen" };

        // One row of the Controls page: the action, the name it shows, whether its pad slot takes a button.
        public sealed class Row
        {
            public readonly string Action, Name;
            public readonly bool PadButton;
            public Row(string action, string name, bool padButton) { Action = action; Name = name; PadButton = padButton; }
        }

        // The actions the player can rebind, in the Controls page's order.
        public static readonly Row[] ACTIONS =
        {
            new Row("move_up", "Move up", false),
            new Row("move_down", "Move down", false),
            new Row("move_left", "Move left", false),
            new Row("move_right", "Move right", false),
            new Row("signature", "Signature attack", true),
            new Row("breath", "Breath", true),
            new Row("dash", "Leap", true),
            new Row("ultimate", "Ultimate", true),
            new Row("pause", "Pause", true),
        };

        // The Controls list's rows (PlayerSettings.CONTROLS) that a rebind changes, and the actions each shows.
        public static readonly Dictionary<string, string[]> ROWS = new Dictionary<string, string[]>
        {
            { "Move", new[] { "move_up", "move_left", "move_down", "move_right" } },
            { "Signature attack", new[] { "signature" } },
            { "Breath (croc)", new[] { "breath" } },
            { "Leap", new[] { "dash" } },
            { "Ultimate", new[] { "ultimate" } },
            { "Pause", new[] { "pause" } },
        };

        // Every pad button a binding may name.
        public static readonly string[] PAD_BUTTONS =
        {
            "A", "B", "X", "Y", "LB", "RB", "LT", "RT", "Start", "Back", "LS", "RS",
            "DpadUp", "DpadDown", "DpadLeft", "DpadRight",
        };

        // What the player reads for a key or button whose name is not already it. The names with a row in
        // strings.csv are translated on top (Shown).
        static readonly Dictionary<string, string> KEY_NAMES = new Dictionary<string, string>
        {
            { "Escape", "Esc" }, { "LeftShift", "Shift" }, { "RightShift", "Shift" }, { "LeftControl", "Ctrl" },
            { "RightControl", "Ctrl" }, { "LeftAlt", "Alt" }, { "RightAlt", "Alt" }, { "Return", "Enter" },
            { "LeftArrow", "Left" }, { "RightArrow", "Right" }, { "UpArrow", "Up" }, { "DownArrow", "Down" },
            { "Mouse0", "Left click" }, { "Mouse1", "Right click" }, { "Mouse2", "Middle click" },
            { "Mouse3", "Mouse 4" }, { "Mouse4", "Mouse 5" },
        };
        // The two sides of a key Godot reads as one (KEY_SHIFT, KEY_CTRL, KEY_ALT).
        static readonly Dictionary<string, string> TWINS = new Dictionary<string, string>
        {
            { "LeftShift", "RightShift" }, { "RightShift", "LeftShift" }, { "LeftControl", "RightControl" },
            { "RightControl", "LeftControl" }, { "LeftAlt", "RightAlt" }, { "RightAlt", "LeftAlt" },
        };
        static readonly Dictionary<string, string> PAD_NAMES = new Dictionary<string, string>
        {
            { "LS", "L3" }, { "RS", "R3" }, { "DpadUp", "D-pad up" }, { "DpadDown", "D-pad down" },
            { "DpadLeft", "D-pad left" }, { "DpadRight", "D-pad right" },
        };

        // The bindings the game starts with (autoload/settings.gd): action, its keys, its pad buttons.
        static readonly (string action, string[] keys, string[] pad)[] DEFAULTS =
        {
            ("move_left", new[] { "A", "LeftArrow" }, new string[0]),
            ("move_right", new[] { "D", "RightArrow" }, new string[0]),
            ("move_up", new[] { "W", "UpArrow" }, new string[0]),
            ("move_down", new[] { "S", "DownArrow" }, new string[0]),
            ("signature", new[] { "Space" }, new[] { "A" }),
            ("ultimate", new[] { "E" }, new[] { "Y" }),
            ("breath", new[] { "Q" }, new[] { "X" }), // the lash took the signature (D-280)
            ("dash", new[] { "LeftShift", "RightShift" }, new[] { "B" }), // Godot's one Shift is both of Unity's
            ("pause", new[] { "Escape", "P" }, new[] { "Start" }),
            ("toggle_fullscreen", new[] { "F11" }, new string[0]),
            // Photo mode's own keys (D-259): it moves on the move keys and turns on the mouse or right stick.
            ("photo_rise", new[] { "E" }, new[] { "RB" }),
            ("photo_sink", new[] { "Q" }, new[] { "LB" }),
            ("photo_hint", new[] { "H" }, new[] { "X" }),
            ("photo_look_left", new string[0], new string[0]),
            ("photo_look_right", new string[0], new string[0]),
            ("photo_look_up", new string[0], new string[0]),
            ("photo_look_down", new string[0], new string[0]),
        };

        // Whether a key name is one the engine knows; the Unity side sets it (a KeyCode parse). Unset: any name.
        public static Func<string, bool> KeyKnown;

        // action -> slot -> inputs: the bindings in force.
        static readonly Dictionary<string, Dictionary<string, List<string>>> map = Fresh();
        // action -> slot -> inputs: the slots the player has set (what settings.json keeps).
        static readonly Dictionary<string, Dictionary<string, List<string>>> changed =
            new Dictionary<string, Dictionary<string, List<string>>>();

        static Dictionary<string, Dictionary<string, List<string>>> Fresh()
        {
            var o = new Dictionary<string, Dictionary<string, List<string>>>();
            foreach (var row in DEFAULTS)
            {
                o[row.action] = new Dictionary<string, List<string>>
                {
                    { KEYS, new List<string>(row.keys) },
                    { PAD, new List<string>(row.pad) },
                };
            }
            return o;
        }

        // The rebindable rows.
        public static Row[] Actions()
        {
            return ACTIONS;
        }

        // Every action that has bindings, the fixed ones too (Inputs reads them all).
        public static List<string> AllActions()
        {
            List<string> o = new List<string>();
            foreach (var row in DEFAULTS) o.Add(row.action);
            return o;
        }

        public static bool HasAction(string action)
        {
            return action != null && map.ContainsKey(action);
        }

        // Binds `input` alone to `action`'s slot and takes it off every other rebindable action; saved.
        // False when it is refused: an unknown action, slot or input, or a key a fixed action uses (F11).
        public static bool Bind(string action, string slot, string input)
        {
            if (!HasAction(action) || !Valid(slot, input) || Reserved(slot, input)) return false;
            // Godot's Shift, Ctrl and Alt are one key each: both of Unity's sides are bound and taken together.
            List<string> taken = new List<string> { input };
            if (slot == KEYS && TWINS.TryGetValue(input, out string twin) && Valid(slot, twin)) taken.Add(twin);
            taken.Sort(StringComparer.Ordinal); // Left before Right, as the defaults
            foreach (Row row in ACTIONS)
            {
                if (row.Action == action) continue;
                List<string> kept = new List<string>(map[row.Action][slot]);
                if (kept.RemoveAll(e => taken.Contains(e)) == 0) continue;
                SetSlot(row.Action, slot, kept);
            }
            SetSlot(action, slot, taken);
            PlayerSettings.Save();
            return true;
        }

        // Every binding back to the game's defaults; saved.
        public static void Reset()
        {
            Clear();
            PlayerSettings.Save();
        }

        // The defaults back in force without saving (PlayerSettings, before it reads the file).
        public static void Clear()
        {
            map.Clear();
            foreach (KeyValuePair<string, Dictionary<string, List<string>>> each in Fresh()) map[each.Key] = each.Value;
            changed.Clear();
        }

        // The inputs of `action` in `slot` (a copy).
        public static List<string> Events(string action, string slot)
        {
            if (!HasAction(action) || !map[action].TryGetValue(slot ?? "", out List<string> list)) return new List<string>();
            return new List<string>(list);
        }

        // What `action`'s slot shows: its inputs by name ("Space / Left click"), "-" when it has none.
        public static string Text(string action, string slot)
        {
            List<string> names = new List<string>();
            foreach (string e in Events(action, slot))
            {
                string name = InputName(slot, e);
                if (!names.Contains(name)) names.Add(name); // both Shifts read "Shift" once
            }
            return names.Count > 0 ? string.Join(" / ", names) : "-";
        }

        // An input's name as the player knows it.
        public static string InputName(string slot, string input)
        {
            if (slot == PAD) return PAD_NAMES.TryGetValue(input, out string pad) ? Shown(pad) : input;
            if (KEY_NAMES.TryGetValue(input, out string key)) return Shown(key);
            // Unity's further mouse buttons count from 0, the player's from 1.
            if (input.StartsWith("Mouse", StringComparison.Ordinal) && int.TryParse(input.Substring(5), out int button))
            {
                return Tr.F("Mouse %d", button + 1);
            }
            // The number row is "Alpha1", the number pad "Keypad1".
            if (input.StartsWith("Alpha", StringComparison.Ordinal) && input.Length == 6) return input.Substring(5);
            return input;
        }

        // A name of ACTIONS, PlayerSettings.CONTROLS or an input in the player's language (the English text is
        // the key). Key and button names ("E", "Esc / P", "RB") have no row in strings.csv and stay as they are.
        public static string Shown(string text)
        {
            return Tr.T(text);
        }

        // The keyboard and pad text of a Controls list row `entry` ([name, keyboard, pad, ...]) with the player's
        // bindings in place of the defaults' text, for each slot the player changed.
        public static string[] RowText(string[] entry)
        {
            string[] o = (string[])entry.Clone();
            if (!ROWS.TryGetValue(entry[0], out string[] acts)) return o;
            if (AnyChanged(acts, KEYS))
            {
                List<string> keys = new List<string>();
                foreach (string action in acts) keys.Add(Text(action, KEYS));
                o[1] = string.Join(acts.Length > 1 ? " " : " / ", keys);
            }
            if (acts.Length == 1 && AnyChanged(acts, PAD)) o[2] = Text(acts[0], PAD);
            return o;
        }

        // Whether the player has set this slot (it differs from what the game started with).
        public static bool IsChanged(string action, string slot)
        {
            return changed.TryGetValue(action ?? "", out Dictionary<string, List<string>> slots) && slots.ContainsKey(slot ?? "");
        }

        static bool AnyChanged(string[] acts, string slot)
        {
            foreach (string action in acts)
            {
                if (IsChanged(action, slot)) return true;
            }
            return false;
        }

        // The player's slots as settings.json's "bindings": {action: {slot: [input names]}}.
        public static S.GDict Write()
        {
            S.GDict o = new S.GDict();
            foreach (KeyValuePair<string, Dictionary<string, List<string>>> each in changed)
            {
                S.GDict slots = new S.GDict();
                foreach (KeyValuePair<string, List<string>> slot in each.Value)
                {
                    S.GArray<S.Variant> names = new S.GArray<S.Variant>();
                    foreach (string e in slot.Value) names.Add(e);
                    slots[slot.Key] = names;
                }
                o[each.Key] = slots;
            }
            return o;
        }

        // Puts settings.json's "bindings" over the defaults; an unknown action, slot or input is skipped.
        public static void Read(S.GDict saved)
        {
            Clear();
            if (saved == null) return;
            foreach (S.Variant actionKey in saved.Keys())
            {
                string action = S.Gd.Str(actionKey);
                S.Variant value = saved[actionKey];
                if (!HasAction(action) || value.Type != S.Gd.TYPE_DICTIONARY) continue;
                S.GDict slots = value;
                foreach (S.Variant slotKey in slots.Keys())
                {
                    string slot = S.Gd.Str(slotKey);
                    S.Variant codes = slots[slotKey];
                    if ((slot != KEYS && slot != PAD) || codes.Type != S.Gd.TYPE_ARRAY) continue;
                    List<string> list = new List<string>();
                    S.GArray<S.Variant> names = codes;
                    foreach (S.Variant code in names)
                    {
                        string input = code.Type == S.Gd.TYPE_STRING ? S.Gd.Str(code) : "";
                        if (Valid(slot, input) && !list.Contains(input)) list.Add(input);
                    }
                    SetSlot(action, slot, list);
                }
            }
        }

        static void SetSlot(string action, string slot, List<string> list)
        {
            map[action][slot] = list;
            if (!changed.TryGetValue(action, out Dictionary<string, List<string>> slots))
            {
                slots = new Dictionary<string, List<string>>();
                changed[action] = slots;
            }
            slots[slot] = new List<string>(list);
        }

        // Whether `input` is something `slot` can hold.
        static bool Valid(string slot, string input)
        {
            if (string.IsNullOrEmpty(input)) return false;
            if (slot == PAD) return Array.IndexOf(PAD_BUTTONS, input) >= 0;
            if (slot == KEYS) return KeyKnown == null || KeyKnown(input);
            return false;
        }

        // Whether `input` is one a fixed action (RESERVED) already uses: such a rebind is refused.
        static bool Reserved(string slot, string input)
        {
            foreach (string r in RESERVED)
            {
                if (map[r][slot].Contains(input)) return true;
            }
            return false;
        }
    }
}
