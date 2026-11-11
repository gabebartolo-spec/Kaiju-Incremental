using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

// Sound stub (U5 architecture: stubs first, real audio in the audio wave). Every call is counted, so a run
// can prove which sounds it asked for; nothing plays. `-audio-log` on the command line logs each call.
public static class Sfx
{
    // Calls so far by id ("ui:" in front of a menu sound, "loop:" of a loop), for the flow's proof lines.
    public static readonly Dictionary<string, int> Counts = new Dictionary<string, int>();
    public static int Calls;
    static readonly HashSet<string> loops = new HashSet<string>();
    static bool? logging;

    public static bool Logging
    {
        get
        {
            if (logging == null) logging = Environment.GetCommandLineArgs().Contains("-audio-log");
            return logging.Value;
        }
    }

    // A game sound (assets/sfx/<id>.ogg in the audio wave).
    public static void Play(string id) => Note(id, "sfx: " + id);

    // A menu sound (scenes/ui_button.gd Sfx.ui("ui_click")).
    public static void Ui(string id) => Note("ui:" + id, "sfx: " + id + " (ui)");

    // A sound that holds until Stop(id); asking twice is one loop.
    public static void Loop(string id)
    {
        if (!loops.Add(id)) return;
        Note("loop:" + id, "sfx: " + id + " (loop)");
    }

    public static void Stop(string id)
    {
        if (!loops.Remove(id)) return;
        if (Logging) Debug.Log("sfx: " + id + " (stop)");
    }

    public static bool Looping(string id) => loops.Contains(id);

    public static int Count(string id) => Counts.TryGetValue(id, out int n) ? n : 0;

    internal static void Note(string key, string line)
    {
        Calls++;
        Counts[key] = Count(key) + 1;
        if (Logging) Debug.Log(line);
    }
}

// Music stub: one track at a time.
public static class Music
{
    public static string Track = "";
    public static int Calls;

    public static void Play(string track)
    {
        if (track == Track) return;
        Track = track ?? "";
        Calls++;
        if (Sfx.Logging) Debug.Log("music: " + Track);
    }

    public static void Stop()
    {
        if (Track == "") return;
        Track = "";
        if (Sfx.Logging) Debug.Log("music: stop");
    }
}
