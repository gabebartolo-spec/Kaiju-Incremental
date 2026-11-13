using System;
using System.Collections.Generic;
using System.Linq;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

// The game's sounds by id (scenes/sfx.gd): the ids, files, levels, gaps and buses are the sound table's
// (GameLogic/AudioTable.cs, from tuning), AudioHost plays them. Every sound that plays is counted, so a run can
// prove which it made; `-audio-log` on the command line logs each one.
public static class Sfx
{
    // Sounds so far by id ("ui:" in front of a menu sound, "loop:" of a loop), for the flow's proof lines.
    public static readonly Dictionary<string, int> Counts = new Dictionary<string, int>();
    public static int Calls;
    // Closed while a rampage's first frames settle (scenes/sfx_gate.gd): a closed gate plays no game sound.
    public static bool Live = true;
    static readonly HashSet<string> unknown = new HashSet<string>();
    static bool? logging;
    static bool hasListener;
    static Vector3 listener;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset()
    {
        Counts.Clear();
        unknown.Clear();
        Calls = 0;
        Live = true;
        hasListener = false;
    }

    public static bool Logging
    {
        get
        {
            if (logging == null) logging = Environment.GetCommandLineArgs().Contains("-audio-log");
            return logging.Value;
        }
    }

    // A game sound (sfx.gd play()): too soon after its last is skipped, the level swings and the pitch shifts
    // by the sound dice, and it takes a voice by its kind. A sound that Godot plays on a player of its own
    // (the lab's, the menus') goes straight out at its table level.
    public static void Play(string id) => Play(id, 0.0);

    public static void Play(string id, double extraDb, double pitch = 1.0, string bus = null, string category = null)
    {
        AudioHost host = AudioHost.Ensure();
        AudioRow row = Row(host, id);
        if (row == null) return;
        if (row.direct)
        {
            Direct(id, row.db + extraDb, pitch);
            return;
        }
        if (!Live || host.Shade.TooSoon(id)) return;
        if (id == "breath") host.SinceBreath = 0.0;
        double db = row.db + extraDb + host.Shade.Swing(id);
        double pitched = host.Shade.Pitched(id, pitch);
        double seconds = (AudioClips.Length(row.file, 1f) - row.startS) / Math.Max(pitched, 0.01);
        int voice = host.Voices.Take(id, category ?? row.category, db, seconds);
        if (voice < 0) return;
        host.Begin(host.Voice(voice), id, row.file, bus ?? row.bus, db, pitched, row.startS, false);
        Note(id, "sfx: " + id);
    }

    // The rampage's ears, in the sim's axes (x, height, sim y); null when there are none.
    public static void Listener(Vector3? at)
    {
        hasListener = at != null;
        if (at != null) listener = at.Value;
    }

    // sfx.gd _distance_db: 0 dB within "near_distance", -6 dB a doubling, never under "far_floor_db".
    public static double DistanceDb(Vector3 at)
    {
        if (!hasListener) return 0.0;
        S.GDict tune = AudioHost.Ensure().Table.sfx;
        return AudioMix.DistanceDb(Vector3.Distance(listener, at), S.Num.F(tune["near_distance"]), S.Num.F(tune["far_floor_db"]));
    }

    // A sound out in the city, quieter the further it is from the ears (sfx.gd play_at; `at` in the sim's axes).
    public static void PlayAt(string id, Vector3 at, double extraDb = 0.0) => Play(id, DistanceDb(at) + extraDb);

    // sfx.gd play_near: the close sound within "crack_within" of `centre` (flat), its "_far" twin beyond.
    public static void PlayNear(string id, Vector3 at, Vector3 centre)
    {
        S.GDict within = AudioHost.Ensure().Table.sfx["crack_within"];
        double reach = within.Has(id) ? S.Num.F(within[id]) : double.PositiveInfinity;
        bool near = new Vector2(at.x - centre.x, at.z - centre.z).magnitude <= reach;
        PlayAt(near ? id : id + "_far", at);
    }

    // A sound on a player of its own at `db`: no gap, swing, pitch dice, voice cap or gate.
    public static void Direct(string id, double db, double pitch = 1.0)
    {
        AudioHost host = AudioHost.Ensure();
        AudioRow row = Row(host, id);
        if (row == null) return;
        host.Begin(host.Direct(), id, row.file, row.bus, db, pitch, 0.0, false);
        Note(id, "sfx: " + id);
    }

    // The titan's roar at once (sfx.gd roar()): the rampage's cue, the evolution reveal, the demo end card.
    public static void Roar()
    {
        AudioHost host = AudioHost.Ensure();
        Direct("roar", host.Table.VolumeDb("roar"));
    }

    // A menu sound (sfx.gd ui(); scenes/ui_button.gd Sfx.ui("ui_click")).
    public static void Ui(string id)
    {
        AudioHost host = AudioHost.Ensure();
        AudioRow row = Row(host, id);
        if (row != null) host.Begin(host.UiVoice(), id, row.file, row.bus, row.db, 1.0, 0.0, false);
        Note("ui:" + id, "sfx: " + id + " (ui)");
    }

    // A sound that holds until Stop(id), at its table level; asking twice is one loop.
    public static void Loop(string id) => Loop(id, double.NaN, 0.0);

    // The same at `db` (NaN: the table's), faded in from silence over `fadeInS`; `world`: a rampage's loop.
    public static void Loop(string id, double db, double fadeInS, bool world = false)
    {
        AudioHost host = AudioHost.Ensure();
        AudioChannel c = host.LoopOf(id, false);
        if (c != null && c.loop && host.Sounding(c) && !c.stopAtTarget) return;
        AudioRow row = Row(host, id);
        if (row == null) return;
        if (double.IsNaN(db)) db = row.db;
        c = host.LoopOf(id, true, world);
        c.world = world;
        bool carrying = host.Sounding(c);  // fading out: it carries straight on
        double from = carrying ? c.db : fadeInS > 0.0 ? SILENT_DB : db;
        if (!carrying) host.Begin(c, id, row.file, row.bus, from, 1.0, 0.0, true);
        c.db = from;
        c.target = db;
        c.rate = fadeInS > 0.0 ? Math.Abs(db - from) / fadeInS : 0.0;
        if (c.rate <= 0.0) c.db = db;
        c.stopAtTarget = false;
        Note("loop:" + id, "sfx: " + id + " (loop)");
    }

    public const double SILENT_DB = -60.0;  // title_ambience.gd FADE_FROM_DB, sfx_beam.gd SILENT_DB

    // A playing loop's level, now.
    public static void LoopLevel(string id, double db)
    {
        AudioChannel c = AudioHost.Ensure().LoopOf(id, false);
        if (c == null) return;
        c.db = db;
        c.rate = 0.0;
    }

    // A playing loop fades to `db` over `seconds`, and stops there when `stop`.
    public static void LoopFade(string id, double db, double seconds, bool stop = false)
    {
        AudioHost host = AudioHost.Ensure();
        AudioChannel c = host.LoopOf(id, false);
        if (c == null || !host.Sounding(c)) return;
        c.target = db;
        c.rate = Math.Abs(db - c.db) / Math.Max(seconds, 0.0001);
        c.stopAtTarget = stop;
        if (c.rate <= 0.0 && stop) host.Halt(c);
    }

    public static void Stop(string id)
    {
        AudioHost host = AudioHost.Ensure();
        AudioChannel c = host.LoopOf(id, false);
        if (c == null || !host.Sounding(c)) return;
        host.Halt(c);
        if (Logging) Debug.Log("sfx: " + id + " (stop)");
    }

    public static bool Looping(string id)
    {
        if (AudioHost.I == null) return false;
        AudioChannel c = AudioHost.I.LoopOf(id, false);
        return c != null && AudioHost.I.Sounding(c);
    }

    public static int Count(string id) => Counts.TryGetValue(id, out int n) ? n : 0;

    // A new run: the sound dice are the run's own "sfx" stream (rampage.gd: Seeds.make("sfx", run_index)), never
    // the sim's, and steps and stomps are pitched for the kaiju's size.
    public static void Seed(long runIndex, int sizeTier)
    {
        AudioHost host = AudioHost.Ensure();
        host.Shade = new AudioShade(host.Table, S.Seeds.Make("sfx", runIndex));
        host.Shade.SetSizeTier(sizeTier);
        host.SinceBreath = 0.0;
    }

    // The title's bed (scenes/title_ambience.gd): the far crowd and siren fading in, and the theme. The
    // gunfire, far booms and footfalls it scatters on top play from TitleCityView (TitleClock).
    public static void TitleBed(bool on)
    {
        S.GDict cfg = S.Content.Section("title")["ambience"];
        string siren = S.Gd.Str(cfg["siren"]);
        if (!on)
        {
            Stop("crowd_panic");
            Stop(siren);
            if (Music.Track == "theme") Music.Stop();
            return;
        }
        double fade = S.Num.F(cfg["fade_in_s"]);
        Loop("crowd_panic", S.Num.F(cfg["crowd_db"]), fade);
        Loop(siren, S.Num.F(cfg["siren_db"]), fade);
        Music.Play("theme");
    }

    static AudioRow Row(AudioHost host, string id)
    {
        AudioRow row = host.Table.Get(id);
        if (row == null && unknown.Add(id)) Debug.LogWarning("audio: no sound \"" + id + "\" in the table");
        return row;
    }

    internal static void Note(string key, string line)
    {
        Calls++;
        Counts[key] = Count(key) + 1;
        if (Logging) Debug.Log(line);
    }
}

// The music: one track at a time. "theme" is the title's; "city_1".."city_3" a rampage's four stems (tuning
// "music"), which Follow() fades in as the city falls. Godot cuts between them with the scene; so does this.
public static class Music
{
    public static string Track = "";
    public static int Calls;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset()
    {
        Track = "";
        Calls = 0;
    }

    public static void Play(string track)
    {
        if (track == Track) return;
        if (string.IsNullOrEmpty(track))
        {
            Stop();
            return;
        }
        Track = track;
        Calls++;
        AudioHost host = AudioHost.Ensure();
        if (!host.Deck.Known(track)) Debug.LogWarning("audio: no music \"" + track + "\" in the table");
        host.Deck.Play(track);
        if (Sfx.Logging) Debug.Log("music: " + Track);
    }

    // scenes/music_layers.gd follow(): `phase` is how far the city has fallen (AudioMix.Phase), 0..1.
    public static void Follow(double phase, double delta)
    {
        if (Track != "" && AudioHost.I != null) AudioHost.I.Deck.Follow(phase, delta);
    }

    public static void Stop()
    {
        if (Track == "") return;
        Track = "";
        if (AudioHost.I != null) AudioHost.I.Deck.Stop();
        if (Sfx.Logging) Debug.Log("music: stop");
    }
}
