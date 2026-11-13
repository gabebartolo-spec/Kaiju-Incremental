// -flow-still <dir>: a 1080p PNG of each flow screen as it is shown, <dir>/<screen>.png (title, settings,
// creation, globe, loading, results, tree, demo_end), what Godot's tools/capture/capture_screens.gd,
// capture_title.gd, capture_results.gd and capture_tree.gd saved. Meant for -flow-smoke, which walks every screen
// and waits while a still is owed (Busy), so it never presses on past a screen before its shot.
// Each screen is taken once, the first time it is on show and settled: SETTLE frames, as capture_screens.gd and
// capture_tree.gd wait, then whatever else the screen asks for (the results' count landed, as
// capture_results.gd). The loading screen is taken the frame it is drawn: the load blocks the frames after.
// A window that is not 1920x1080 is scaled to it (logged), so every still is 1080p (D-339).
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

public sealed class FlowStills : MonoBehaviour
{
    public const string FLAG = "-flow-still";
    // capture_screens.gd / capture_tree.gd SETTLE: frames a screen is on show before its shot.
    public const int SETTLE = 20;
    // Seconds a still waits to settle before it is given up (the smoke run is not held past it).
    const float GIVE_UP = 60f;
    const int WIDTH = 1920, HEIGHT = 1080;
    public static readonly string[] SCREENS = { "title", "settings", "creation", "globe", "loading", "results", "tree", "demo_end" };

    sealed class Ask
    {
        public string name;
        public int frame;
        public float since;
        public Func<bool> on, ready;
    }

    static string dir;
    static FlowStills host;
    static readonly HashSet<string> taken = new HashSet<string>();
    static readonly List<Ask> owed = new List<Ask>();
    static bool taking;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset()
    {
        Application.quitting -= Report;
        dir = null;
        host = null;
        taken.Clear();
        owed.Clear();
        taking = false;
    }

    // True when -flow-still was given a folder.
    public static bool On => dir != null;
    // True while a still is owed: the smoke run waits.
    public static bool Busy => owed.Count > 0;
    public static bool Taken(string name) => taken.Contains(name);

    // Reads -flow-still <dir> once; the folder is made and the stills' host outlives scene reloads.
    public static void Boot(string[] args)
    {
        if (host != null) return;
        int i = Array.IndexOf(args, FLAG);
        if (i < 0) return;
        if (i + 1 >= args.Length || args[i + 1].StartsWith("-", StringComparison.Ordinal))
        {
            Debug.LogWarning($"flow: {FLAG} needs a folder, no stills");
            return;
        }
        try
        {
            dir = Path.GetFullPath(args[i + 1]);
            Directory.CreateDirectory(dir);
        }
        catch (Exception e)
        {
            Debug.LogWarning($"flow: no stills, folder {args[i + 1]} not made ({e.Message})");
            dir = null;
            return;
        }
        GameObject go = new GameObject("FlowStills");
        DontDestroyOnLoad(go);
        host = go.AddComponent<FlowStills>();
        Application.quitting += Report;
        Debug.Log($"flow: stills on, {SCREENS.Length} screens into {dir}");
    }

    // The still of the flow state just entered (the rampage has none; results are asked for by name).
    public static void Want(GameFlow.State state)
    {
        string name;
        switch (state)
        {
            case GameFlow.State.Title: name = "title"; break;
            case GameFlow.State.Creation: name = "creation"; break;
            case GameFlow.State.Globe: name = "globe"; break;
            case GameFlow.State.Tree: name = "tree"; break;
            case GameFlow.State.DemoEnd: name = "demo_end"; break;
            default: return;
        }
        // The title's own still is the title alone, never the settings over it, once its city stands
        // (capture_title.gd waits for TitleBackdrop.is_loaded).
        Want(name, () => GameFlow.Now == state && !SettingsScreen.IsOpen, SETTLE, () => state != GameFlow.State.Title || TitleCityView.Settled);
    }

    // A still of `name` once `settle` frames have passed and `ready` holds, if `on` still holds then (the screen
    // is still on show; otherwise it is asked again the next time it shows). Taken once per name.
    public static void Want(string name, Func<bool> on, int settle = SETTLE, Func<bool> ready = null)
    {
        if (!On || taken.Contains(name) || owed.Any(a => a.name == name)) return;
        owed.Add(new Ask { name = name, frame = Time.frameCount + settle, since = Time.realtimeSinceStartup, on = on, ready = ready });
    }

    void LateUpdate()
    {
        if (taking || owed.Count == 0) return;
        Ask ask = owed[0];
        if (!Holds(ask.on))
        {
            Debug.Log($"flow: still {ask.name} missed, the screen went before it settled");
            owed.RemoveAt(0);
            return;
        }
        if (Time.frameCount < ask.frame) return;
        if (ask.ready != null && !Holds(ask.ready))
        {
            if (Time.realtimeSinceStartup - ask.since < GIVE_UP) return;
            Debug.LogWarning($"flow: still {ask.name} missed, not settled in {GIVE_UP:F0} s");
            owed.RemoveAt(0);
            return;
        }
        taking = true;
        StartCoroutine(Take(ask));
    }

    // A predicate that throws (a screen torn down under it) is a screen no longer on show.
    static bool Holds(Func<bool> test)
    {
        if (test == null) return true;
        try { return test(); }
        catch (Exception) { return false; }
    }

    IEnumerator Take(Ask ask)
    {
        yield return new WaitForEndOfFrame();
        Texture2D shot = null, png = null;
        RenderTexture rt = null;
        try
        {
            shot = ScreenCapture.CaptureScreenshotAsTexture();
            int w = shot.width, h = shot.height;
            // Always through a 1080p target: the size is fixed and any alpha the back buffer holds is dropped.
            rt = RenderTexture.GetTemporary(WIDTH, HEIGHT, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
            Graphics.Blit(shot, rt);
            RenderTexture before = RenderTexture.active;
            RenderTexture.active = rt;
            png = new Texture2D(WIDTH, HEIGHT, TextureFormat.RGB24, false);
            png.ReadPixels(new Rect(0, 0, WIDTH, HEIGHT), 0, 0, false);
            png.Apply(false);
            RenderTexture.active = before;
            string path = Path.Combine(dir, ask.name + ".png");
            File.WriteAllBytes(path, png.EncodeToPNG());
            taken.Add(ask.name);
            string scaled = w != WIDTH || h != HEIGHT ? $" (window {w}x{h}, scaled to {WIDTH}x{HEIGHT})" : "";
            Debug.Log($"flow: still {path}{scaled}");
        }
        catch (Exception e)
        {
            // A warning, not an exception: the smoke run fails on any exception in the log.
            Debug.LogWarning($"flow: still {ask.name} not saved ({e.Message})");
        }
        finally
        {
            if (rt != null) RenderTexture.ReleaseTemporary(rt);
            if (shot != null) Destroy(shot);
            if (png != null) Destroy(png);
            owed.Remove(ask);
            taking = false;
        }
    }

    // The last line: which screens have a still.
    static void Report()
    {
        string[] missing = SCREENS.Where(s => !taken.Contains(s)).ToArray();
        Debug.Log($"flow: stills {SCREENS.Length - missing.Length} of {SCREENS.Length} saved in {dir}{(missing.Length > 0 ? ", missing " + string.Join(", ", missing) : "")}");
    }
}
