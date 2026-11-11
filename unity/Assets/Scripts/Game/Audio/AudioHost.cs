using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using Opt = Kaiju.Game.PlayerSettings;
using S = Kaiju.Sim;

// One playing sound: its source, the bus it is on and its level in dB before the buses.
public sealed class AudioChannel
{
    public AudioSource src;
    public string id = "";
    public string bus = AudioTable.DEFAULT_BUS;
    public double db;
    public bool world;  // a rampage's sound: held while the rampage is paused, stopped when it ends
    public string file = "";
    public bool waiting;  // asked to play before its file was loaded
    public float asked, startS;
    public bool loop;
    public double target, rate;  // a loop's fade: toward `target` at `rate` dB/s
    public bool stopAtTarget;
}

// The game's sound, on one object that outlives every scene (scenes/sfx.gd's players and autoload/audio_buses.gd's
// buses): a pool of voices, the menu's voices, the loops and the music. There is no mixer asset: a bus is a sum,
// so each source's volume is its own level, less the ducks on its way to Master, times the SFX slider when it
// passes through SFX. Master is AudioListener.volume. Everything is 2D, as Godot's Sfx players are.
public sealed class AudioHost : MonoBehaviour
{
    // A one-shot whose file arrives later than this is not played: a late bang is worse than none.
    const float LATE_S = 0.25f;
    const int UI_VOICES = 4;  // sfx.gd _ui_player max_polyphony
    const int METER = 256;  // samples read off a hero sound each frame for the ducks
    const double NEVER = 1e9;

    public static AudioHost I;
    public static bool Paused;  // the rampage is paused: its sounds hold (Godot pauses them with the tree)

    public AudioTable Table;
    public AudioBusMap Buses;
    public AudioVoices Voices;
    public AudioShade Shade;
    public AudioMusic Deck;
    public double SinceBreath = NEVER;

    sealed class BusInfo
    {
        public List<string> chain, ducks;
        public bool sfx;
    }

    sealed class Duck
    {
        public string sidechain;
        public double threshold, ratio, release, cut;
    }

    readonly Dictionary<string, BusInfo> buses = new Dictionary<string, BusInfo>();
    readonly Dictionary<string, Duck> ducks = new Dictionary<string, Duck>();
    readonly List<AudioChannel> all = new List<AudioChannel>();
    readonly List<AudioChannel> direct = new List<AudioChannel>();
    readonly Dictionary<string, AudioChannel> loops = new Dictionary<string, AudioChannel>();
    readonly float[] meter = new float[METER];
    AudioChannel[] voices, ui;
    int uiNext;
    bool wasPaused;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset()
    {
        I = null;
        Paused = false;
    }

    // The host, made on first use: S.FileAccess.Root must already point at the res root (GameFlow.Boot,
    // RampageGame.Load).
    public static AudioHost Ensure()
    {
        if (I != null) return I;
        var go = new GameObject("audio");
        DontDestroyOnLoad(go);
        I = go.AddComponent<AudioHost>();
        I.Build();
        return I;
    }

    void Build()
    {
        gameObject.AddComponent<AudioListener>();  // every source is 2D, so where the ears are does not matter
        Table = AudioTable.Load();
        Buses = new AudioBusMap(Table.audio);
        foreach (S.Variant k in Buses.ducks.Keys())
        {
            S.GDict d = Buses.ducks[k];
            ducks[S.Gd.Str(k)] = new Duck
            {
                sidechain = S.Gd.Str(d["sidechain"]), threshold = S.Num.F(d["threshold_db"]),
                ratio = S.Num.F(d["ratio"]), release = S.Num.F(d["release_ms"]),
            };
        }
        int count = (int)S.Num.I(Table.sfx["voices"]);
        Voices = new AudioVoices(count, (S.GDict)Table.sfx["voice_caps"]);
        Shade = new AudioShade(Table, S.Seeds.Make("sfx", 0));
        voices = new AudioChannel[count];
        for (int i = 0; i < count; i++) voices[i] = NewChannel(true);
        ui = new AudioChannel[UI_VOICES];
        for (int i = 0; i < UI_VOICES; i++) ui[i] = NewChannel(false);
        Deck = new AudioMusic(this);
        AudioListener.volume = Mathf.Clamp01((float)Opt.Volume);
        int missing = 0;
        List<string> files = Table.Files();
        foreach (string file in files)
            if (!AudioClips.OnDisk(file)) missing++;
        foreach (string id in Table.ids)
            if (!Table.Get(id).music) AudioClips.Get(Table.Get(id).file);  // the one-shots load now, in the background
        Debug.Log("audio: " + Table.ids.Count + " ids, " + files.Count + " files, " + missing + " missing");
    }

    public AudioChannel NewChannel(bool world)
    {
        var src = gameObject.AddComponent<AudioSource>();
        src.playOnAwake = false;
        src.spatialBlend = 0f;
        src.dopplerLevel = 0f;
        var c = new AudioChannel { src = src, world = world };
        all.Add(c);
        return c;
    }

    // Starts `file` on `c`, or leaves it waiting for its file.
    public void Begin(AudioChannel c, string id, string file, string bus, double db, double pitch, double startS, bool loop, bool music = false)
    {
        c.src.Stop();
        c.id = id;
        c.file = file;
        c.bus = bus;
        c.db = db;
        c.loop = loop;
        c.startS = (float)startS;
        c.src.pitch = (float)pitch;
        c.src.loop = loop;
        AudioClip clip = AudioClips.Get(file, music);
        c.waiting = clip == null && !AudioClips.Missing(file);
        c.asked = Time.unscaledTime;
        if (clip != null) Sound(c, clip);
    }

    void Sound(AudioChannel c, AudioClip clip)
    {
        c.waiting = false;
        c.src.clip = clip;
        c.src.time = Mathf.Clamp(c.startS, 0f, Mathf.Max(0f, clip.length - 0.01f));
        c.src.volume = Gain(c.bus, c.db);
        c.src.Play();
        if (Paused && c.world) c.src.Pause();
    }

    public void Halt(AudioChannel c)
    {
        c.waiting = false;
        c.src.Stop();
    }

    public bool Sounding(AudioChannel c) => c.waiting || c.src.isPlaying;

    public AudioChannel Voice(int slot) => voices[slot];

    public AudioChannel UiVoice() => ui[uiNext++ % UI_VOICES];

    // A player of its own (sfx.gd roar(), kaiju_creation.gd _play): outside the voice pool, never cut.
    public AudioChannel Direct()
    {
        foreach (AudioChannel c in direct)
            if (!Sounding(c)) return c;
        AudioChannel made = NewChannel(false);
        direct.Add(made);
        return made;
    }

    public AudioChannel LoopOf(string id, bool create, bool world = false)
    {
        if (loops.TryGetValue(id, out AudioChannel c) || !create) return c;
        c = NewChannel(world);
        loops[id] = c;
        return c;
    }

    // The rampage is over: its voices, loops and music stop and the pool is free (Godot frees the scene).
    public void StopWorld()
    {
        foreach (AudioChannel c in all)
            if (c.world) Halt(c);
        Voices.Clear();
        Paused = false;
        wasPaused = false;
    }

    // What a source on `bus` at `db` plays at, 0..1 (a level above 0 dB after the slider cannot be reached:
    // AudioSource.volume stops at 1).
    public float Gain(string bus, double db)
    {
        BusInfo info = Info(bus);
        foreach (string d in info.ducks) db -= ducks[d].cut;
        double gain = AudioMix.Linear(db);
        if (info.sfx) gain *= Opt.Sfx();
        return Mathf.Clamp01((float)gain);
    }

    BusInfo Info(string bus)
    {
        if (buses.TryGetValue(bus, out BusInfo info)) return info;
        info = new BusInfo { chain = Buses.Chain(bus), ducks = new List<string>() };
        foreach (string d in Buses.Ducks(bus))
            if (ducks.ContainsKey(d)) info.ducks.Add(d);
        info.sfx = info.chain.Contains("SFX");
        buses[bus] = info;
        return info;
    }

    void Update()
    {
        float dt = Time.unscaledDeltaTime;
        AudioListener.volume = Mathf.Clamp01((float)Opt.Volume);
        if (Paused != wasPaused)
        {
            wasPaused = Paused;
            foreach (AudioChannel c in all)
            {
                if (!c.world) continue;
                if (Paused) c.src.Pause();
                else c.src.UnPause();
            }
        }
        if (!Paused)
        {
            Voices.Advance(dt);
            Shade.Advance(dt);
            SinceBreath += dt;
        }
        Deck.Update(dt);
        DuckBuses(dt);
        foreach (AudioChannel c in all)
        {
            if (c.world && Paused) continue;
            if (c.waiting) Arrive(c);
            if (c.loop && c.rate > 0.0) Fade(c, dt);
            if (c.src.isPlaying) c.src.volume = Gain(c.bus, c.db);
        }
    }

    // A waiting sound's file has come (or will not): a loop starts whenever it does, a one-shot only if fresh.
    void Arrive(AudioChannel c)
    {
        if (AudioClips.Missing(c.file))
        {
            c.waiting = false;
            return;
        }
        AudioClip clip = AudioClips.Get(c.file);
        if (clip == null) return;
        if (c.loop || Time.unscaledTime - c.asked <= LATE_S) Sound(c, clip);
        else c.waiting = false;
    }

    void Fade(AudioChannel c, float dt)
    {
        c.db = AudioMix.MoveToward(c.db, c.target, c.rate * dt);
        if (c.db != c.target) return;
        c.rate = 0.0;
        if (c.stopAtTarget) Halt(c);
    }

    // The ducks (audio_buses.gd _duck): each listens to its sidechain bus (the hero's sounds) and turns its
    // own bus down while that is loud. Godot's compressor works per sample; this follows the peak once a frame.
    void DuckBuses(float dt)
    {
        foreach (Duck d in ducks.Values)
        {
            double peak = 0.0;
            foreach (AudioChannel c in all)
            {
                if (!c.src.isPlaying || !Info(c.bus).chain.Contains(d.sidechain)) continue;
                c.src.GetOutputData(meter, 0);
                float top = 0f;
                for (int i = 0; i < METER; i++) top = Mathf.Max(top, Mathf.Abs(meter[i]));
                // The source's output carries the SFX slider; the bus level Godot's compressor hears does not.
                double slider = Info(c.bus).sfx ? Opt.Sfx() : 1.0;
                if (slider > 0.0001) peak = System.Math.Max(peak, top / slider);
            }
            double target = peak > 0.0 ? AudioMix.DuckDb(AudioMix.Db(peak), d.threshold, d.ratio) : 0.0;
            d.cut = AudioMix.DuckStep(d.cut, target, d.release, dt);
        }
    }
}

// The music (scenes/music_layers.gd, title_ambience.gd's theme): a city track is four stems started on the same
// sample and faded in as the city falls; the theme plays its intro once and then loops from its loop point.
public sealed class AudioMusic
{
    const double FADE_FROM_DB = -60.0;  // title_ambience.gd FADE_FROM_DB
    const double LEAD_S = 0.1;  // how far ahead a start is scheduled, so every stem makes it
    const double RESCHEDULE_S = 1.0;  // the theme's next pass is queued this long before the last ends

    readonly AudioHost host;
    readonly List<AudioChannel> stems = new List<AudioChannel>();
    readonly List<S.GDict> rows = new List<S.GDict>();
    readonly AudioChannel[] theme = new AudioChannel[2];
    string track = "";
    bool pending, isTheme;
    int themeAt;
    double themeEnds, themeOffset, themeDb, themeFadeS;

    public AudioMusic(AudioHost host)
    {
        this.host = host;
    }

    public bool Known(string name) => name == "theme" || host.Table.Track(name) != null;

    public void Play(string name)
    {
        Stop();
        track = name;
        if (!Known(name)) return;
        isTheme = name == "theme";
        pending = true;
        string bus = S.Gd.Str(host.Table.music["bus"]);
        if (isTheme)
        {
            S.GDict ambience = S.Content.Section("title")["ambience"];
            S.GDict cfg = ambience["theme"];
            themeOffset = S.Num.F(cfg["loop_offset_s"]);
            themeDb = S.Num.F(cfg["db"]);
            themeFadeS = S.Num.F(ambience["fade_in_s"]);
            for (int i = 0; i < 2; i++)
            {
                if (theme[i] == null) theme[i] = host.NewChannel(false);
                theme[i].bus = bus;
                theme[i].db = FADE_FROM_DB;
            }
            AudioClips.Get(host.Table.Get("theme").file, true);
            return;
        }
        S.GDict row = host.Table.Track(name);
        S.GArray<S.Variant> list = row["stems"];
        rows.Clear();
        foreach (S.Variant sv in list) rows.Add((S.GDict)sv);
        while (stems.Count < rows.Count) stems.Add(host.NewChannel(true));
        for (int i = 0; i < rows.Count; i++)
        {
            stems[i].bus = bus;
            stems[i].db = S.Num.F(host.Table.music["silent_db"]);
            AudioClips.Get(File(i), true);
        }
    }

    public void Stop()
    {
        foreach (AudioChannel c in stems) host.Halt(c);
        foreach (AudioChannel c in theme)
            if (c != null) host.Halt(c);
        pending = false;
        track = "";
    }

    // music_layers.gd follow(): each stem moves toward its level for the city's phase.
    public void Follow(double phase, double delta)
    {
        if (isTheme || track == "" || rows.Count == 0) return;
        double silent = S.Num.F(host.Table.music["silent_db"]);
        double step = S.Num.F(host.Table.music["fade_db_per_s"]) * delta;
        for (int i = 0; i < rows.Count; i++)
        {
            double goal = AudioMix.StemDb(phase, S.Num.F(rows[i]["enter"]), S.Num.F(rows[i]["full"]), silent);
            stems[i].db = AudioMix.MoveToward(stems[i].db, goal, step);
        }
    }

    string File(int i)
    {
        string res = S.Gd.Str(rows[i]["file"]);
        return res.StartsWith("res://") ? res.Substring(6) : res;
    }

    public void Update(float dt)
    {
        if (track == "" || !Known(track)) return;
        if (isTheme) Theme(dt);
        else if (pending) StartStems();
    }

    // Every stem starts on the same audio sample once all four files are in (a missing one stays silent).
    void StartStems()
    {
        for (int i = 0; i < rows.Count; i++)
            if (!AudioClips.Settled(File(i))) return;
        pending = false;
        double at = AudioSettings.dspTime + LEAD_S;
        for (int i = 0; i < rows.Count; i++)
        {
            AudioClip clip = AudioClips.Get(File(i), true);
            if (clip == null) continue;
            AudioChannel c = stems[i];
            c.waiting = false;
            c.loop = true;
            c.rate = 0.0;
            c.src.clip = clip;
            c.src.loop = true;
            c.src.pitch = 1f;
            c.src.time = 0f;
            c.src.volume = host.Gain(c.bus, c.db);
            c.src.PlayScheduled(at);
            if (AudioHost.Paused) c.src.Pause();
        }
    }

    void Theme(float dt)
    {
        string file = host.Table.Get("theme").file;
        if (pending)
        {
            AudioClip clip = AudioClips.Get(file, true);
            if (clip == null)
            {
                if (AudioClips.Missing(file)) pending = false;
                return;
            }
            pending = false;
            themeAt = 0;
            double at = AudioSettings.dspTime + LEAD_S;
            Pass(theme[0], clip, 0.0, at);
            themeEnds = at + clip.length;
            return;
        }
        AudioChannel now = theme[themeAt];
        if (now.src.clip == null) return;
        double step = (themeDb - FADE_FROM_DB) / System.Math.Max(themeFadeS, 0.0001) * dt;
        double level = AudioMix.MoveToward(now.db, themeDb, step);
        theme[0].db = theme[1].db = level;
        // The next pass is queued on the sample the current one ends, from the loop point.
        if (AudioSettings.dspTime < themeEnds - RESCHEDULE_S) return;
        AudioClip loop = now.src.clip;
        themeAt = 1 - themeAt;
        Pass(theme[themeAt], loop, themeOffset, themeEnds);
        themeEnds += System.Math.Max(loop.length - themeOffset, RESCHEDULE_S * 2.0);
    }

    void Pass(AudioChannel c, AudioClip clip, double from, double at)
    {
        c.waiting = false;
        c.loop = false;
        c.src.clip = clip;
        c.src.loop = false;
        c.src.pitch = 1f;
        c.src.time = (float)System.Math.Min(from, System.Math.Max(0.0, clip.length - 0.01));
        c.src.volume = host.Gain(c.bus, c.db);
        c.src.PlayScheduled(at);
    }
}
