// The mixer as sums (autoload/audio_buses.gd, scenes/sfx.gd distance_db, sfx_crowd.gd, city_curve.gd,
// music_layers.gd): decibels, the bus chains of tuning "audio", the ducks, and the level curves.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public static class AudioMix
    {
        public static double Linear(double db) => Math.Pow(10.0, db / 20.0);

        public static double Db(double linear) => linear <= 0.0 ? double.NegativeInfinity : 20.0 * Math.Log10(linear);

        public static double MoveToward(double from, double to, double step)
        {
            return Math.Abs(to - from) <= step ? to : from + Math.Sign(to - from) * step;
        }

        static double Clamp01(double v) => v < 0.0 ? 0.0 : v > 1.0 ? 1.0 : v;

        static double Lerp(double a, double b, double t) => a + (b - a) * t;

        // sfx.gd distance_db: full within `near`, -6 dB each doubling beyond, never under `floor`.
        public static double DistanceDb(double distance, double near, double floor)
        {
            return Math.Max(floor, -20.0 * Math.Log10(Math.Max(1.0, distance / near)));
        }

        // AudioStreamPlayer3D (rail_view.gd, inverse distance): 0 dB at `unit` units, capped at the player's
        // default max_db of 3.
        public static double UnitDb(double distance, double unit)
        {
            return Math.Min(3.0, -20.0 * Math.Log10(Math.Max(distance, 0.0001) / unit));
        }

        // sfx_crowd.gd target().
        public static double CrowdTarget(GDict cfg, double fullDb, double intensity, bool ducked)
        {
            if (intensity <= Num.F(cfg["min_intensity"])) return Num.F(cfg["silent_db"]);
            double db = Lerp(Num.F(cfg["quiet_db"]), fullDb, Clamp01(intensity));
            return db - (ducked ? Num.F(cfg["duck_db"]) : 0.0);
        }

        // sfx_crowd.gd update(): how loud the panic should be from the people running and the city breaking.
        public static double CrowdIntensity(GDict cfg, double panicking, double chunkRate)
        {
            return Clamp01(panicking / Num.F(cfg["full_panic"])) * 0.7 + Clamp01(chunkRate / Num.F(cfg["full_rate"])) * 0.3;
        }

        // city_curve.gd phase(): how far the city has fallen, 0 calm to 1 dead.
        public static double Phase(GDict cfg, double destruction, double fled, double population)
        {
            double byCity = Clamp01(destruction / Num.F(cfg["destruction_full"]));
            double byPeople = Clamp01(fled / Math.Max(1.0, population) / Num.F(cfg["fled_full"]));
            double w = Num.F(cfg["destruction_weight"]);
            return byCity * w + byPeople * (1.0 - w);
        }

        // city_curve.gd along(): flat before the first point and after the last, straight between.
        public static double Along(GArray<Variant> curve, double at)
        {
            int n = (int)curve.Size();
            if (n == 0) return 0.0;
            GArray<Variant> first = curve[0];
            if (at <= Num.F(first[0])) return Num.F(first[1]);
            for (int i = 1; i < n; i++)
            {
                GArray<Variant> a = curve[i - 1];
                GArray<Variant> b = curve[i];
                if (at > Num.F(b[0])) continue;
                double span = Math.Max(Num.F(b[0]) - Num.F(a[0]), 0.0001);
                return Lerp(Num.F(a[1]), Num.F(b[1]), (at - Num.F(a[0])) / span);
            }
            GArray<Variant> last = curve[n - 1];
            return Num.F(last[1]);
        }

        // music_layers.gd stem_db(): silent until `enter`, full (0 dB) from `full`.
        public static double StemDb(double phase, double enter, double full, double silentDb)
        {
            return Lerp(silentDb, 0.0, Clamp01((phase - enter) / Math.Max(full - enter, 0.0001)));
        }

        // music_layers.gd track_seconds().
        public static double TrackSeconds(GDict track)
        {
            return Num.F(track["bars"]) * Num.F(track["beats_per_bar"]) * 60.0 / Num.F(track["bpm"]);
        }

        // A compressor's cut for a sidechain at `levelDb` (audio_buses.gd _duck: threshold and ratio).
        public static double DuckDb(double levelDb, double thresholdDb, double ratio)
        {
            if (levelDb <= thresholdDb || ratio <= 0.0) return 0.0;
            return (levelDb - thresholdDb) * (1.0 - 1.0 / ratio);
        }

        // The cut one frame on: straight down to a deeper target (the attack is 0.5 ms), easing back over
        // `releaseMs`.
        public static double DuckStep(double cut, double target, double releaseMs, double delta)
        {
            if (target >= cut) return target;
            double tau = Math.Max(releaseMs * 0.001, 0.0001);
            return target + (cut - target) * Math.Exp(-delta / tau);
        }
    }

    // The bus layout (tuning "audio" "buses"): who sends to whom and which bus a duck sits on.
    public sealed class AudioBusMap
    {
        public const string MASTER = "Master";
        readonly Dictionary<string, string> send = new Dictionary<string, string>();
        readonly Dictionary<string, string> duck = new Dictionary<string, string>();
        public readonly List<string> names = new List<string>();
        public readonly GDict ducks;

        public AudioBusMap(GDict audio)
        {
            GArray<Variant> buses = audio["buses"];
            foreach (Variant bv in buses)
            {
                GDict b = bv;
                string name = Gd.Str(b["name"]);
                names.Add(name);
                send[name] = Gd.Str(b["send"]);
                if (b.Has("duck")) duck[name] = Gd.Str(b["duck"]);
            }
            ducks = audio["ducks"];
        }

        // `bus` and every bus it passes through on the way to Master (Master last). An unknown bus plays on
        // Master, as Godot does.
        public List<string> Chain(string bus)
        {
            var chain = new List<string>();
            string at = bus;
            while (send.ContainsKey(at) && chain.Count <= names.Count)
            {
                chain.Add(at);
                at = send[at];
            }
            chain.Add(MASTER);
            return chain;
        }

        public bool Under(string bus, string parent) => Chain(bus).Contains(parent);

        // The ducks a sound on `bus` passes through ("music", "bed").
        public List<string> Ducks(string bus)
        {
            var list = new List<string>();
            foreach (string b in Chain(bus))
                if (duck.TryGetValue(b, out string d)) list.Add(d);
            return list;
        }
    }
}
