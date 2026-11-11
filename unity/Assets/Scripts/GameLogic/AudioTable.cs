// Every sound the game can play (scenes/sfx.gd, sfx_shade.gd, audio_buses.gd; tuning "sfx", "audio", "music"),
// as plain C#: id -> file, level, pitch, gap, bus and voice category. The Unity side (Game/Audio) plays them.
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class AudioRow
    {
        public string id = "";
        public string file = "";  // under the res root: assets/sfx/<id>.ogg
        public string bus = "SFX";
        public string category = "body";
        public double db;  // tuning "sfx" "volume_db"
        public double pitch = 1.0;  // "pitch_by"
        public double pitchJitter;  // "pitch_jitter_by", else "pitch_jitter"
        public double minInterval;  // "min_interval": 0 = no gap
        public double intervalJitter;
        public double gainJitterDb;
        public double startS;
        public bool music;
        public bool direct;  // Godot plays it on a player of its own (the lab's and the menus' sounds)
    }

    public sealed class AudioTable
    {
        // scenes/sfx.gd STOMPS and STEPS.
        public const int STOMPS = 3;
        public static readonly string[] STEPS = { "footstep", "footstep_2", "footstep_1", "footstep_3" };
        public const string DEFAULT_BUS = "SFX";  // audio_buses.gd of()

        public readonly Dictionary<string, AudioRow> rows = new Dictionary<string, AudioRow>();
        public readonly List<string> ids = new List<string>();
        public GDict sfx, audio, music;

        public static AudioTable Load()
        {
            var t = new AudioTable();
            t.sfx = Content.Section("sfx");
            t.audio = Content.Section("audio");
            t.music = Content.Section("music");
            GArray<Variant> files = t.sfx["files"];
            foreach (Variant f in files) t.Add(Gd.Str(f));
            for (int k = 0; k < STOMPS; k++) t.Add("stomp_" + k);
            foreach (string step in STEPS) t.Add(step);
            foreach (string s in new[] { "thunder_beam", "thunder_beam_end", "thunder_beam_loop", "regen_loop", "heli_rotor", "crowd_panic" }) t.Add(s);
            GDict sounds = t.audio["sounds"];
            foreach (Variant k in sounds.Keys()) t.Add(Gd.Str(k));
            GDict levels = t.sfx["volume_db"];
            foreach (Variant k in levels.Keys())
            {
                string id = Gd.Str(k);
                if (id != "stomp") t.Add(id);  // "stomp" is the level of stomp_N, not a file
            }
            GDict beds = Content.Section("city_sound")["beds"];
            foreach (Variant k in beds.Keys())
                if (Gd.Str(k) != "crowd") t.Add(Gd.Str(k));  // the crowd bed trims crowd_panic
            GDict creation = Content.Section("creation");
            GDict lab = creation["sounds"];
            GArray<Variant> loops = lab["loops"];
            foreach (Variant l in loops) t.AddDirect(Gd.Str(l));
            foreach (string key in new[] { "pick", "strike", "crackle", "overload", "dive" }) t.AddDirect(Gd.Str(lab[key]));
            GDict trip = lab["trip"];
            foreach (Variant k in trip.Keys()) t.AddDirect(Gd.Str(trip[k]));
            t.AddDirect(Gd.Str(creation["crack_sound"]));
            foreach (string id in t.ids)
                if (t.rows[id].bus == "UI") t.rows[id].direct = true;  // sfx.gd ui(): the menu's own player
            GDict title = Content.Section("title")["ambience"];
            t.Add(Gd.Str(title["siren"]));
            GDict boom = title["boom"];
            t.Add(Gd.Str(boom["sound"]));
            GDict stomp = title["stomp"];
            t.Add(Gd.Str(stomp["sound"]));
            string bus = Gd.Str(t.music["bus"]);
            GArray<Variant> tracks = t.music["tracks"];
            foreach (Variant tv in tracks)
            {
                GDict track = tv;
                GArray<Variant> stems = track["stems"];
                foreach (Variant sv in stems)
                {
                    GDict stem = sv;
                    t.AddMusic(Gd.Str(track["id"]) + "_" + Gd.Str(stem["name"]), Gd.Str(stem["file"]), bus, 0.0);
                }
            }
            GDict theme = title["theme"];
            t.AddMusic("theme", Gd.Str(theme["file"]), bus, Num.F(theme["db"]));
            return t;
        }

        public AudioRow Get(string id) => rows.TryGetValue(id, out AudioRow r) ? r : null;

        public bool Has(string id) => rows.ContainsKey(id);

        // The files behind the table, each once.
        public List<string> Files()
        {
            var seen = new HashSet<string>();
            var files = new List<string>();
            foreach (string id in ids)
                if (seen.Add(rows[id].file)) files.Add(rows[id].file);
            return files;
        }

        // sfx.gd _volume: the stomps share "stomp", the steps "footstep"; a sound with no row plays at 0 dB.
        public double VolumeDb(string sound)
        {
            GDict levels = sfx["volume_db"];
            string key = sound;
            if (sound.StartsWith("stomp_") && sound != "stomp_crack") key = "stomp";
            else if (sound.StartsWith("footstep")) key = "footstep";
            return levels.Has(key) ? Num.F(levels[key]) : 0.0;
        }

        // audio_buses.gd of().
        public string BusOf(string sound)
        {
            GDict sounds = audio["sounds"];
            return sounds.Has(sound) ? Gd.Str(sounds[sound]) : DEFAULT_BUS;
        }

        // sfx_voices.gd category_of().
        public string CategoryOf(string sound)
        {
            GDict caps = sfx["voice_caps"];
            GDict sounds = caps["sounds"];
            return sounds.Has(sound) ? Gd.Str(sounds[sound]) : Gd.Str(caps["default"]);
        }

        // The tracks' ids in tier order (music_layers.gd: tracks[size_tier - 1]).
        public List<string> Tracks()
        {
            var list = new List<string>();
            GArray<Variant> tracks = music["tracks"];
            foreach (Variant tv in tracks)
            {
                GDict track = tv;
                list.Add(Gd.Str(track["id"]));
            }
            return list;
        }

        public GDict Track(string id)
        {
            GArray<Variant> tracks = music["tracks"];
            foreach (Variant tv in tracks)
            {
                GDict track = tv;
                if (Gd.Str(track["id"]) == id) return track;
            }
            return null;
        }

        // kaiju_creation.gd _play: the lab's sounds each have a player of their own.
        void AddDirect(string id)
        {
            Add(id);
            if (rows.ContainsKey(id)) rows[id].direct = true;
        }

        void Add(string id)
        {
            if (id == "" || rows.ContainsKey(id)) return;
            var r = new AudioRow { id = id };
            // sfx.gd: a distant rifle is the same shot; a dropped slab is the collapse, quieter (collapse()).
            string file = id == "rifle_far" ? "rifle" : id == "collapse_drop" ? "collapse" : id;
            r.file = "assets/sfx/" + file + ".ogg";
            r.bus = BusOf(id);
            r.category = id == "collapse_drop" ? "debris" : CategoryOf(id);
            r.db = VolumeDb(id);
            r.pitch = By("pitch_by", id, 1.0);
            r.pitchJitter = By("pitch_jitter_by", id, Num.F(sfx["pitch_jitter"]));
            r.minInterval = By("min_interval", id, 0.0);
            r.intervalJitter = By("interval_jitter", id, 0.0);
            r.gainJitterDb = By("gain_jitter_db", id, 0.0);
            r.startS = By("start_s", id, 0.0);
            rows[id] = r;
            ids.Add(id);
        }

        void AddMusic(string id, string res, string bus, double db)
        {
            if (rows.ContainsKey(id)) return;
            string file = res.StartsWith("res://") ? res.Substring(6) : res;
            rows[id] = new AudioRow { id = id, file = file, bus = bus, category = "", db = db, music = true };
            ids.Add(id);
        }

        double By(string table, string id, double fallback)
        {
            GDict d = sfx[table];
            return d.Has(id) ? Num.F(d[id]) : fallback;
        }
    }
}
