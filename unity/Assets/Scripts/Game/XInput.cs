using System;
using System.Runtime.InteropServices;
using UnityEngine;

// The pad, read straight from Windows (xinput1_4.dll): the legacy Input Manager has no rumble and no
// reliable button names, and the Input System package is not installed (U5 architecture). First connected
// pad of the four. A missing DLL or entry point never throws: the pad reads as absent, logged once.
public static class XInput
{
    // wButtons bits (XINPUT_GAMEPAD_*). LT and RT are not bits in XInput: Inputs adds them from the triggers.
    public const int DPAD_UP = 0x0001, DPAD_DOWN = 0x0002, DPAD_LEFT = 0x0004, DPAD_RIGHT = 0x0008;
    public const int START = 0x0010, BACK = 0x0020, L3 = 0x0040, R3 = 0x0080, LB = 0x0100, RB = 0x0200;
    public const int A = 0x1000, B = 0x2000, X = 0x4000, Y = 0x8000;
    // Inputs' own bits for the triggers read as buttons (free bits of the 16-bit word's upper neighbour).
    public const int LT = 0x10000, RT = 0x20000;

    const string DLL = "xinput1_4.dll";
    const int SLOTS = 4;
    // An empty slot costs a device scan in XInputGetState, so absent pads are looked for this often, not each frame.
    const float RESCAN_SECONDS = 1f;

    [StructLayout(LayoutKind.Sequential)]
    struct Gamepad
    {
        public ushort buttons;
        public byte leftTrigger, rightTrigger;
        public short lx, ly, rx, ry;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct State
    {
        public uint packet;
        public Gamepad pad;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct Vibration
    {
        public ushort low, high;
    }

    [DllImport(DLL)] static extern uint XInputGetState(uint index, out State state);
    [DllImport(DLL)] static extern uint XInputSetState(uint index, ref Vibration vibration);

    // What one read of the pad gives: sticks -1..1 (y up), triggers 0..1, the button word.
    public struct Pad
    {
        public bool connected;
        public int buttons;
        public Vector2 left, right;
        public float leftTrigger, rightTrigger;
    }

    static bool dead;        // the DLL is missing: never call it again
    static int slot = -1;    // the connected pad's slot, -1 = none
    static float nextScan;   // Time.unscaledTime of the next look for a pad

    public static bool Available => !dead;
    public static int Slot => slot;

    // The first connected pad's state now; `connected` false when there is none.
    public static Pad Read()
    {
        var none = new Pad();
        if (dead) return none;
        try
        {
            State s;
            if (slot >= 0)
            {
                if (XInputGetState((uint)slot, out s) == 0) return From(s);
                Debug.Log($"input: pad {slot} disconnected");
                slot = -1;
                nextScan = 0f;
            }
            float now = Time.unscaledTime;
            if (now < nextScan) return none;
            nextScan = now + RESCAN_SECONDS;
            for (int i = 0; i < SLOTS; i++)
            {
                if (XInputGetState((uint)i, out s) != 0) continue;
                slot = i;
                Debug.Log($"input: pad {i} connected");
                return From(s);
            }
        }
        catch (Exception e) when (e is DllNotFoundException || e is EntryPointNotFoundException || e is BadImageFormatException)
        {
            Kill(e);
        }
        return none;
    }

    // Motor speeds 0..1: low = the heavy left motor, high = the light right motor. False when no pad took it.
    public static bool SetMotors(float low, float high)
    {
        if (dead || slot < 0) return false;
        try
        {
            var v = new Vibration { low = Word(low), high = Word(high) };
            return XInputSetState((uint)slot, ref v) == 0;
        }
        catch (Exception e) when (e is DllNotFoundException || e is EntryPointNotFoundException || e is BadImageFormatException)
        {
            Kill(e);
            return false;
        }
    }

    static void Kill(Exception e)
    {
        dead = true;
        slot = -1;
        Debug.Log($"input: no pad support ({DLL}: {e.GetType().Name}); keyboard and mouse only");
    }

    static ushort Word(float share) => (ushort)Mathf.RoundToInt(Mathf.Clamp01(share) * 65535f);

    static Pad From(State s)
    {
        return new Pad
        {
            connected = true,
            buttons = s.pad.buttons,
            left = new Vector2(Axis(s.pad.lx), Axis(s.pad.ly)),
            right = new Vector2(Axis(s.pad.rx), Axis(s.pad.ry)),
            leftTrigger = s.pad.leftTrigger / 255f,
            rightTrigger = s.pad.rightTrigger / 255f,
        };
    }

    // -32768..32767 to -1..1.
    static float Axis(short raw) => Mathf.Max(raw / 32767f, -1f);
}
