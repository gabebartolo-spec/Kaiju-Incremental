using System;
using System.Linq;
using System.Runtime.InteropServices;
using UnityEngine;

// -quiet-window: an unattended run (a dry run, a smoke run) moves its window off the screen and under every other
// window, without taking the focus, so the white "Not Responding" window of a long load is never in the way.
// The game still draws and runs (runInBackground); the taskbar button stays. Windows only; nothing without the flag.
public static class QuietWindow
{
#if UNITY_STANDALONE_WIN && !UNITY_EDITOR
    const string USER = "user32.dll", KERNEL = "kernel32.dll";
    const string UNITY_WINDOW = "UnityWndClass";
    // GetSystemMetrics: the left edge and the width of all the screens together.
    const int SM_XVIRTUALSCREEN = 76, SM_CXVIRTUALSCREEN = 78;
    // SetWindowPos: keep the size, do not activate.
    const uint SWP_NOSIZE = 0x0001, SWP_NOACTIVATE = 0x0010;
    static readonly IntPtr HWND_BOTTOM = new IntPtr(1);

    [DllImport(USER, CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string windowClass, string title);
    [DllImport(USER)] static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport(USER)] static extern int GetSystemMetrics(int index);
    [DllImport(USER)] static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int w, int h, uint flags);
    [DllImport(KERNEL)] static extern uint GetCurrentProcessId();

    static bool on;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void Early()
    {
        on = Environment.GetCommandLineArgs().Contains("-quiet-window");
        Hide();
    }

    // Again once the first scene is up: a resolution change may have put the window back.
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Late() => Hide();

    static void Hide()
    {
        if (!on) return;
        uint me = GetCurrentProcessId();
        IntPtr window = IntPtr.Zero;
        while ((window = FindWindowEx(IntPtr.Zero, window, UNITY_WINDOW, null)) != IntPtr.Zero)
        {
            GetWindowThreadProcessId(window, out uint owner);
            if (owner != me) continue;
            int right = GetSystemMetrics(SM_XVIRTUALSCREEN) + GetSystemMetrics(SM_CXVIRTUALSCREEN);
            bool moved = SetWindowPos(window, HWND_BOTTOM, right, 0, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
            Debug.Log($"quiet window: moved off screen to x={right} ok={moved}");
            return;
        }
        Debug.Log("quiet window: no window found");
    }
#endif
}
