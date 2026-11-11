using System;
using System.Collections.Generic;
using UnityEngine;
using Kaiju.Game;

// The game's input actions (autoload/settings.gd): keyboard and mouse through the legacy UnityEngine.Input
// with the key names KeyBinds holds, the pad through XInput. Static; GameFlow calls Poll() once a frame, and a
// query in a frame nobody polled polls first, so the standalone rampage needs no wiring.
public static class Inputs
{
    public enum Device { Keys, Pad }

    // The stick's dead centre, as every Godot action had (settings.gd DEADZONE).
    public const float DEADZONE = 0.2f;
    // A trigger reads as a pressed button past this share of its travel.
    public const float TRIGGER_PRESS = 0.5f;

    // What the player last touched, for the prompts (keys or pad glyphs).
    public static Device LastDevice { get; private set; } = Device.Keys;
    public static bool PadConnected => pad.connected;

    // Pad button names as KeyBinds stores them (KeyBinds.PAD_BUTTONS), each with its XInput bit.
    static readonly (string name, int bit)[] PAD_BUTTONS =
    {
        ("A", XInput.A), ("B", XInput.B), ("X", XInput.X), ("Y", XInput.Y),
        ("LB", XInput.LB), ("RB", XInput.RB), ("LT", XInput.LT), ("RT", XInput.RT),
        ("Start", XInput.START), ("Back", XInput.BACK), ("LS", XInput.L3), ("RS", XInput.R3),
        ("DpadUp", XInput.DPAD_UP), ("DpadDown", XInput.DPAD_DOWN),
        ("DpadLeft", XInput.DPAD_LEFT), ("DpadRight", XInput.DPAD_RIGHT),
    };

    // Actions a stick drives (settings.gd _axis_action): right stick?, x axis?, sign.
    static readonly Dictionary<string, (bool right, bool x, float sign)> AXES = new Dictionary<string, (bool, bool, float)>
    {
        { "move_left", (false, true, -1f) }, { "move_right", (false, true, 1f) },
        { "move_up", (false, false, 1f) }, { "move_down", (false, false, -1f) },
        { "photo_look_left", (true, true, -1f) }, { "photo_look_right", (true, true, 1f) },
        { "photo_look_up", (true, false, 1f) }, { "photo_look_down", (true, false, -1f) },
    };

    // An action's keys and pad bits, read from KeyBinds once and again after any setting or binding changes.
    sealed class Bound
    {
        public KeyCode[] keys;
        public int bits;
    }

    static readonly Dictionary<string, Bound> bound = new Dictionary<string, Bound>();
    static readonly HashSet<string> unknownNames = new HashSet<string>();
    static KeyCode[] captureKeys;

    // The sticks as read (raw); move and look are the same with Godot's dead centre taken out.
    static XInput.Pad pad, padBefore;
    static Vector2 move, look;
    static int buttons, buttonsBefore;
    static int polledFrame = -1;
    static float rumbleUntil = -1f;
    // Rebinding: while a capture waits, and for the frame its press lands in, no action reads as pressed.
    static bool capturing;
    static int captureFrom = -1, quietFrame = -1;
    // The slot the waiting cell fills (KeyBinds.KEYS or PAD); null takes either.
    static string captureSlot;

    // Rumbles asked for and those a pad took, for a run's proof line.
    public static int RumblesAsked, RumblesSent;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Boot()
    {
        polledFrame = -1;
        capturing = false;
        bound.Clear();
        KeyBinds.KeyKnown = name => KeyOf(name) != KeyCode.None;
        PlayerSettings.Changed -= Rebound;
        PlayerSettings.Changed += Rebound;
        Application.quitting -= StopRumble;
        Application.quitting += StopRumble;  // a pad left buzzing outlives the game
    }

    // Reads the pad once a frame (GameFlow.Update, before any screen asks).
    public static void Poll()
    {
        if (polledFrame == Time.frameCount) return;
        polledFrame = Time.frameCount;
        padBefore = pad;
        buttonsBefore = buttons;
        // A pad on the desk must not drive a window the player is not in.
        pad = Application.isFocused ? XInput.Read() : new XInput.Pad();
        move = Dead(pad.left);
        look = Dead(pad.right);
        buttons = pad.buttons;
        if (pad.leftTrigger > TRIGGER_PRESS) buttons |= XInput.LT;
        if (pad.rightTrigger > TRIGGER_PRESS) buttons |= XInput.RT;
        if (rumbleUntil >= 0f && Time.unscaledTime >= rumbleUntil) StopRumble();
        if ((buttons & ~buttonsBefore) != 0 || move != Vector2.zero || look != Vector2.zero) LastDevice = Device.Pad;
        else if (Input.anyKeyDown) LastDevice = Device.Keys;
    }

    // True in the frame `action` went down (key, mouse button, pad button, or its stick direction).
    public static bool Down(string action)
    {
        if (Quiet()) return false;
        foreach (KeyCode k in Keys(action)) if (Input.GetKeyDown(k)) return true;
        int bits = PadBits(action);
        if ((buttons & bits) != 0 && (buttonsBefore & bits) == 0) return true;
        return AxisOn(action, pad) && !AxisOn(action, padBefore);
    }

    // True while `action` is held.
    public static bool Held(string action)
    {
        if (Quiet()) return false;
        foreach (KeyCode k in Keys(action)) if (Input.GetKey(k)) return true;
        return (buttons & PadBits(action)) != 0 || AxisOn(action, pad);
    }

    // The move direction, x right and y up (W = +y), length at most 1: the move keys, else the left stick.
    public static Vector2 Move()
    {
        if (Quiet()) return Vector2.zero;
        float x = (KeyHeld("move_right") ? 1f : 0f) - (KeyHeld("move_left") ? 1f : 0f);
        float y = (KeyHeld("move_up") ? 1f : 0f) - (KeyHeld("move_down") ? 1f : 0f);
        var keys = new Vector2(x, y);
        if (keys != Vector2.zero) return keys.normalized;
        return move;
    }

    // The right stick (photo mode's look), x right and y up, dead centre removed.
    public static Vector2 Look()
    {
        return Quiet() ? Vector2.zero : look;
    }

    // Menus: A, Enter or Space confirms; B or Esc backs out (settings.gd ui_accept / ui_cancel).
    public static bool Confirm()
    {
        if (Quiet()) return false;
        return Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter) || Input.GetKeyDown(KeyCode.Space) || PadDown(XInput.A);
    }

    public static bool Cancel()
    {
        if (Quiet()) return false;
        return Input.GetKeyDown(KeyCode.Escape) || PadDown(XInput.B);
    }

    // Any key, mouse button or pad button went down this frame (PRESS ANY KEY, skipping the rise).
    public static bool AnyDown()
    {
        if (Quiet()) return false;
        return Input.anyKeyDown || (buttons & ~buttonsBefore) != 0;
    }

    // A pad button by its XInput bit, this frame's press: for the fixed menu moves (the D-pad, Start).
    public static bool PadDown(int bit)
    {
        Ensure();
        return (buttons & bit) != 0 && (buttonsBefore & bit) == 0;
    }

    public static bool PadHeld(int bit)
    {
        Ensure();
        return (buttons & bit) != 0;
    }

    // Shakes the pad: low = the heavy motor, high = the light one (0..1), stopped after `seconds`.
    // Godot's start_joy_vibration(weak, strong, s) is Rumble(strong, weak, s). A new call replaces the last.
    public static void Rumble(float low, float high, float seconds)
    {
        Ensure();
        RumblesAsked++;
        if (seconds <= 0f || !XInput.SetMotors(low, high)) return;
        RumblesSent++;
        rumbleUntil = Time.unscaledTime + seconds;
    }

    public static void StopRumble()
    {
        if (rumbleUntil < 0f) return;
        rumbleUntil = -1f;
        XInput.SetMotors(0f, 0f);
    }

    // Rebinding (scenes/controls_menu.gd PRESS A KEY / PRESS A BUTTON): BeginCapture, then NextPress each
    // frame until it gives a name. The press that opened the capture is not taken. `slot` is the cell that
    // waits (KeyBinds.KEYS or PAD): a press of the other kind is passed over and the capture goes on waiting
    // (controls_menu.gd _input), but Esc always comes back, as the cancel.
    public static void BeginCapture(string slot = null)
    {
        captureSlot = slot;
        capturing = true;
        captureFrom = Time.frameCount;
    }

    public static void EndCapture()
    {
        if (!capturing) return;
        capturing = false;
        quietFrame = Time.frameCount;  // the press that ended it does nothing else this frame
    }

    public static bool Capturing => capturing;

    // The slot the waiting capture fills (null: either, or none waits).
    public static string CaptureSlot => capturing ? captureSlot : null;

    // The next key, mouse button or pad button pressed, by the name KeyBinds stores ("" until one is);
    // `isPad` says which slot it fills. Ends the capture when it returns a name.
    public static string NextPress(out bool isPad)
    {
        isPad = false;
        if (!capturing) BeginCapture();
        Poll();
        if (Time.frameCount <= captureFrom) return "";
        int fresh = buttons & ~buttonsBefore;
        if (fresh != 0 && captureSlot != KeyBinds.KEYS)
        {
            foreach ((string name, int bit) in PAD_BUTTONS)
            {
                if ((fresh & bit) == 0) continue;
                isPad = true;
                EndCapture();
                return name;
            }
        }
        if (!Input.anyKeyDown) return "";
        foreach (KeyCode k in CaptureKeys())
        {
            if (!Input.GetKeyDown(k)) continue;
            if (captureSlot == KeyBinds.PAD && k != KeyCode.Escape) continue;
            EndCapture();
            return k.ToString();
        }
        return "";
    }

    public static string NextPress() => NextPress(out _);

    // ---- names and bindings ----

    // The key a stored name means (a KeyCode's own name, as KeyBinds stores it); None for anything else. The
    // legacy joystick codes are not keys here: the pad is XInput's.
    public static KeyCode KeyOf(string name)
    {
        // A bare number would parse as an enum VALUE, so only names go to the parser.
        if (string.IsNullOrEmpty(name) || !char.IsLetter(name[0])) return KeyCode.None;
        if (!Enum.TryParse(name, false, out KeyCode code) || !Enum.IsDefined(typeof(KeyCode), code)) return KeyCode.None;
        return code < KeyCode.JoystickButton0 ? code : KeyCode.None;
    }

    // The XInput bit a stored pad button name means (0 = unknown).
    public static int PadBit(string name)
    {
        foreach ((string n, int bit) in PAD_BUTTONS) if (n == name) return bit;
        return 0;
    }

    static void Rebound() => bound.Clear();

    // The one place Inputs reads KeyBinds. An unknown name is skipped and logged once.
    static Bound Of(string action)
    {
        if (bound.TryGetValue(action, out Bound hit)) return hit;
        var keys = new List<KeyCode>();
        foreach (string name in KeyBinds.Events(action, KeyBinds.KEYS))
        {
            KeyCode k = KeyOf(name);
            if (k != KeyCode.None) keys.Add(k);
            else if (unknownNames.Add(name)) Debug.LogWarning($"input: unknown key name '{name}' on {action}");
        }
        int bits = 0;
        foreach (string name in KeyBinds.Events(action, KeyBinds.PAD))
        {
            int bit = PadBit(name);
            bits |= bit;
            if (bit == 0 && unknownNames.Add("pad:" + name)) Debug.LogWarning($"input: unknown pad button '{name}' on {action}");
        }
        if (!KeyBinds.HasAction(action) && !AXES.ContainsKey(action) && unknownNames.Add("action:" + action))
            Debug.LogWarning($"input: unknown action '{action}'");
        var made = new Bound { keys = keys.ToArray(), bits = bits };
        bound[action] = made;
        return made;
    }

    static KeyCode[] Keys(string action) => Of(action).keys;

    static int PadBits(string action) => Of(action).bits;

    // ---- inner ----

    static bool KeyHeld(string action)
    {
        foreach (KeyCode k in Keys(action)) if (Input.GetKey(k)) return true;
        return false;
    }

    static bool AxisOn(string action, XInput.Pad p)
    {
        if (!AXES.TryGetValue(action, out var axis)) return false;
        Vector2 stick = axis.right ? p.right : p.left;
        return (axis.x ? stick.x : stick.y) * axis.sign >= DEADZONE;  // an action is pressed past its own dead zone
    }

    // Polls if nobody has this frame; true while a rebind capture swallows every press.
    static bool Quiet()
    {
        Ensure();
        return capturing || quietFrame == Time.frameCount;
    }

    static void Ensure()
    {
        if (polledFrame != Time.frameCount) Poll();
    }

    // Godot's Input.get_vector (run_input.gd reads the move with it): a round dead centre on the stick's length,
    // and the rest of its travel stretched to 0..1, so the pull starts from nothing at the edge.
    public static Vector2 Dead(Vector2 stick)
    {
        float length = stick.magnitude;
        if (length <= DEADZONE) return Vector2.zero;
        if (length > 1f) return stick / length;
        return stick * (Mathf.InverseLerp(DEADZONE, 1f, length) / length);
    }

    // Every key and mouse button a rebind may take: the legacy joystick codes are left out (the pad is XInput's).
    static KeyCode[] CaptureKeys()
    {
        if (captureKeys != null) return captureKeys;
        var list = new List<KeyCode>();
        foreach (KeyCode k in Enum.GetValues(typeof(KeyCode)))
            if (k != KeyCode.None && k < KeyCode.JoystickButton0 && !list.Contains(k)) list.Add(k);
        captureKeys = list.ToArray();
        return captureKeys;
    }
}
