// What keeps a repeated sound from sounding copied (scenes/sfx_shade.gd): a gap between plays, a swing in
// level, a shifted pitch. Its dice are the "sfx" stream's (Seeds), never the sim's.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class AudioShade
    {
        readonly AudioTable table;
        readonly RandomNumberGenerator rng;
        readonly Dictionary<string, double> since = new Dictionary<string, double>();
        readonly List<string> keys = new List<string>();
        double sizePitch = 1.0;

        public AudioShade(AudioTable table, RandomNumberGenerator rng)
        {
            this.table = table;
            this.rng = rng;
        }

        public void Advance(double delta)
        {
            keys.Clear();
            keys.AddRange(since.Keys);
            foreach (string k in keys) since[k] += delta;
        }

        // Footsteps and stomps drop in pitch as the kaiju grows (tuning "sfx" "size_pitch").
        public void SetSizeTier(int tier)
        {
            GArray<Variant> pitches = table.sfx["size_pitch"];
            int at = Math.Max(0, Math.Min(tier - 1, (int)pitches.Size() - 1));
            sizePitch = Num.F(pitches[at]);
        }

        // Whether `sound` played too recently; when it may play, its next gap is stretched by the dice.
        public bool TooSoon(string sound)
        {
            AudioRow row = table.Get(sound);
            if (row == null || row.minInterval <= 0.0) return false;
            if ((since.TryGetValue(sound, out double s) ? s : double.PositiveInfinity) < row.minInterval) return true;
            since[sound] = -row.minInterval * row.intervalJitter * rng.Randf();
            return false;
        }

        // The dice roll even at no swing, as Godot's do, so the stream stays in step with it.
        public double Swing(string sound)
        {
            AudioRow row = table.Get(sound);
            double amount = row != null ? row.gainJitterDb : 0.0;
            return rng.RandfRange(-amount, amount);
        }

        public double Pitched(string sound, double basePitch)
        {
            AudioRow row = table.Get(sound);
            double jitter = row != null ? row.pitchJitter : Num.F(table.sfx["pitch_jitter"]);
            double pitch = basePitch * (row != null ? row.pitch : 1.0);
            if (sound.StartsWith("footstep") || sound.StartsWith("stomp")) pitch *= sizePitch;
            return pitch * (1.0 + rng.RandfRange(-jitter, jitter));
        }
    }
}
