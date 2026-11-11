// Which voice a sound gets (scenes/sfx_voices.gd, tuning "sfx" "voice_caps"): each kind of sound has a cap,
// the kaiju's own sounds are never taken by another, and a full pool gives up its quietest voice.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class AudioVoices
    {
        public int dropped, stolen, heroesStolen, heroesCut;
        public readonly int count;
        readonly GDict cfg;
        double now;
        readonly string[] category;
        readonly double[] until, db, start;
        readonly Dictionary<string, double> lastStart = new Dictionary<string, double>();

        public AudioVoices(int count, GDict cfg)
        {
            this.count = count;
            this.cfg = cfg;
            category = new string[count];
            until = new double[count];
            db = new double[count];
            start = new double[count];
            for (int i = 0; i < count; i++)
            {
                category[i] = "";
                until[i] = db[i] = start[i] = double.NegativeInfinity;
            }
        }

        public void Advance(double delta) => now += delta;

        public bool IsHero(string kind)
        {
            GDict spec = Spec(kind);
            return spec != null && spec.Has("hero") && (bool)spec["hero"];
        }

        public int Cap(string kind) => (int)Num.I(Spec(kind)["cap"]);

        public int BusyIn(string kind)
        {
            int n = 0;
            for (int i = 0; i < count; i++)
                if (Busy(i) && (kind == "" || category[i] == kind)) n++;
            return n;
        }

        // The voice for `sound` (of `kind`, at `level` dB, lasting `seconds`), or -1 when it is dropped.
        public int Take(string sound, string kind, double level, double seconds)
        {
            string key = kind + ":" + sound;
            GDict spec = Spec(kind);
            double gap = Num.F(spec.Has("retrigger_ms") ? spec["retrigger_ms"] : cfg["retrigger_ms"]) * 0.001;
            if (now - (lastStart.TryGetValue(key, out double last) ? last : double.NegativeInfinity) < gap)
            {
                dropped++;
                return -1;
            }
            int at = Pick(kind, level);
            if (at < 0)
            {
                dropped++;
                return -1;
            }
            if (Busy(at) && category[at] == kind && IsHero(kind)) heroesCut++;
            else if (Busy(at))
            {
                stolen++;
                if (IsHero(category[at])) heroesStolen++;
            }
            lastStart[key] = now;
            category[at] = kind;
            until[at] = now + Math.Max(seconds, 0.0);
            db[at] = level;
            start[at] = now;
            return at;
        }

        // Every voice is free again (a new scene: Godot frees the Sfx node and its players).
        public void Clear()
        {
            for (int i = 0; i < count; i++) until[i] = double.NegativeInfinity;
            lastStart.Clear();
        }

        int Pick(string kind, double level)
        {
            bool hero = IsHero(kind);
            if (BusyIn(kind) >= Cap(kind)) return hero ? OldestOwn(kind) : Quieter(level, kind);
            if (!hero)
            {
                long share = count - Num.I(cfg["reserve_hero"]);
                if (BusyOthers() >= share) return Quieter(level, "");
            }
            for (int i = 0; i < count; i++)
                if (!Busy(i)) return i;
            return Quieter(hero ? double.PositiveInfinity : level, "");
        }

        int OldestOwn(string kind)
        {
            int best = -1;
            double after = Num.F(cfg["hero_cut_after_s"]);
            for (int i = 0; i < count; i++)
                if (Busy(i) && category[i] == kind && now - start[i] >= after)
                    if (best < 0 || start[i] < start[best]) best = i;
            return best;
        }

        int Quieter(double level, string kind)
        {
            int best = -1;
            for (int i = 0; i < count; i++)
            {
                if (!Busy(i) || IsHero(category[i])) continue;
                if (kind != "" && category[i] != kind) continue;
                if (best < 0 || db[i] < db[best] || (db[i] == db[best] && start[i] < start[best])) best = i;
            }
            return best >= 0 && level >= db[best] ? best : -1;
        }

        int BusyOthers()
        {
            int n = 0;
            for (int i = 0; i < count; i++)
                if (Busy(i) && !IsHero(category[i])) n++;
            return n;
        }

        bool Busy(int i) => now < until[i];

        GDict Spec(string kind)
        {
            GDict categories = cfg["categories"];
            return categories.Has(kind) ? (GDict)categories[kind] : null;
        }
    }
}
