// Kaiju Creation's steps (scenes/kaiju_creation.gd): pick a genome from the rack, it is poured into the dish; inject
// Special K, the takeover, the camera's dive to black, the egg's cracks, then the species is made. Paced in fixed
// 60 Hz ticks (tuning "creation" "timing"), so every run shows the same frames. Plain C#: the screen calls Pick,
// Inject and Tick, plays what Sounds holds and draws Lab, Black and White.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public enum CreationStep { Rack, Place, Dish, Inject, Takeover, Zoom, Black, Done }

    // One thing for the screen's audio to do: play a one-shot, start a loop, or stop a sound.
    public struct CreationSound
    {
        public enum Kind { Play, Loop, Stop }

        public Kind What;
        public string Id;
        // An egg crack is a cut of its file: from From seconds for Len seconds (0: the whole file).
        public double From, Len;
    }

    public sealed class CreationSteps
    {
        public CreationStep Step = CreationStep.Rack;
        // The sound cues reached so far, in order (loops too).
        public readonly List<string> Cues = new List<string>();
        // What the screen has still to play; it empties this as it does.
        public readonly List<CreationSound> Sounds = new List<CreationSound>();
        public readonly List<CreationTitan> Titans;
        public readonly CreationLab Lab;
        public int Picked = -1;
        // How black the screen is (0..1): the zoom ends in full black, where the egg cracks.
        public double Black;
        // The species made, once Step is Done.
        public string Species = "";

        readonly Dictionary<CreationStep, int> ticks = new Dictionary<CreationStep, int>();
        readonly double blackFrom;
        readonly List<string> loops = new List<string>(), shots = new List<string>();
        string crackle;
        int tick, phase = -1;

        // save: the save on disk (empty for none); the rack reads which titans it has unlocked.
        public CreationSteps(GDict save)
        {
            Titans = CreationRack.Shown(save);
            if (Titans.Count == 0) Titans = CreationRack.Shown(new GDict());
            GDict cfg = Content.Section("creation");
            GDict timing = cfg["timing"];
            Time(timing, CreationStep.Place, "place_s");
            Time(timing, CreationStep.Inject, "inject_s");
            Time(timing, CreationStep.Takeover, "takeover_s");
            Time(timing, CreationStep.Zoom, "zoom_s");
            Time(timing, CreationStep.Black, "black_s");
            GDict zoom = CreationLab.Cfg()["zoom"];
            blackFrom = Num.F(zoom["black_from"]);
            Lab = new CreationLab(Titans.Count);
            GArray<Variant> room = SoundCfg()["loops"];
            foreach (Variant sound in room)
            {
                loops.Add(Gd.Str(sound));
                Play(Gd.Str(sound), true);
            }
        }

        void Time(GDict timing, CreationStep step, string key)
        {
            ticks[step] = Math.Max(1, CreationLab.Round(Num.F(timing[key]) * CreationLab.TICKS_PER_SECOND));
        }

        // How many ticks `step` lasts (0: it waits for the player).
        public int Ticks(CreationStep step) => ticks.TryGetValue(step, out int n) ? n : 0;

        // Esc / B goes back until the injection.
        public bool CanBack => Step == CreationStep.Rack || Step == CreationStep.Dish;

        static GDict SoundCfg() => Content.Section("creation")["sounds"];

        // The player picks titan `index` off the rack.
        public void Pick(int index)
        {
            if (Step != CreationStep.Rack || index < 0 || index >= Titans.Count) return;
            Picked = index;
            Play(Gd.Str(SoundCfg()["pick"]));
            Begin(CreationStep.Place);
        }

        // The player presses INJECT SPECIAL K.
        public void Inject()
        {
            if (Step != CreationStep.Dish) return;
            Begin(CreationStep.Inject);
        }

        void Begin(CreationStep next)
        {
            Step = next;
            tick = 0;
            phase = -1;
            GDict s = SoundCfg();
            if (next == CreationStep.Takeover)
            {
                Play(Gd.Str(s["strike"]));
                crackle = Gd.Str(s["crackle"]);
                Play(crackle, true);
            }
            else if (next == CreationStep.Zoom)
            {
                shots.Add(Gd.Str(s["dive"]));
                Play(Gd.Str(s["dive"]));
            }
            else if (next == CreationStep.Black)
            {
                // The room and the takeover's one-shots are cut at the black, so the egg crack is heard alone.
                foreach (string id in loops) Sounds.Add(new CreationSound { What = CreationSound.Kind.Stop, Id = id });
                foreach (string id in shots) Sounds.Add(new CreationSound { What = CreationSound.Kind.Stop, Id = id });
            }
        }

        // One 60 Hz tick.
        public void Tick()
        {
            if (!ticks.ContainsKey(Step)) return;
            tick++;
            int length = ticks[Step];
            double t = Math.Min((double)tick / length, 1.0);
            switch (Step)
            {
                case CreationStep.Place:
                    Lab.Place(Picked, t);
                    TripCue(t, "place");
                    break;
                case CreationStep.Inject:
                    Lab.Inject(t);
                    TripCue(t, "inject");
                    break;
                case CreationStep.Takeover:
                    Lab.Takeover(t);
                    OverloadCue(t);
                    break;
                case CreationStep.Zoom:
                    Lab.Zoom(t);
                    Black = CreationLab.Smoothstep(blackFrom, 1.0, t);
                    break;
                case CreationStep.Black:
                    CracksDue();
                    break;
            }
            if (tick >= length) Advance();
        }

        void Advance()
        {
            switch (Step)
            {
                case CreationStep.Place: Begin(CreationStep.Dish); break;
                case CreationStep.Inject: Begin(CreationStep.Takeover); break;
                case CreationStep.Takeover: Begin(CreationStep.Zoom); break;
                case CreationStep.Zoom:
                    Black = 1.0;
                    Begin(CreationStep.Black);
                    CracksDue();
                    break;
                case CreationStep.Black:
                    Begin(CreationStep.Done);
                    Species = Titans[Picked].Species;
                    break;
            }
        }

        // The egg's cracks in the black (tuning "creation" "cracks", each a cut of "crack_sound": from from_s for
        // len_s, at_s seconds into the black), each on the tick it falls due.
        void CracksDue()
        {
            GDict cfg = Content.Section("creation");
            string sound = Gd.Str(cfg["crack_sound"]);
            int played = Cues.FindAll(c => c == sound).Count;
            GArray<Variant> cracks = cfg["cracks"];
            if (played >= (int)cracks.Size()) return;
            GDict next = cracks[played];
            if (tick < CreationLab.Round(Num.F(next["at_s"]) * CreationLab.TICKS_PER_SECOND)) return;
            Cues.Add(sound);
            Sounds.Add(new CreationSound { What = CreationSound.Kind.Play, Id = sound, From = Num.F(next["from_s"]), Len = Num.F(next["len_s"]) });
        }

        // The injector's cue for each trip phase it enters (servo swings, the draw, the dispense).
        void TripCue(double t, string key)
        {
            int p = CreationLab.Phase(t, key);
            if (p == phase) return;
            phase = p;
            GDict trip = SoundCfg()["trip"];
            string name = p.ToString(System.Globalization.CultureInfo.InvariantCulture);
            if (trip.Has(name)) Play(Gd.Str(trip[name]));
        }

        // The crackle stops and the overload bangs at the second hit-stop.
        void OverloadCue(double t)
        {
            GDict timing = Content.Section("creation")["timing"];
            double lead = Num.F(SoundCfg()["overload_lead_s"]) / Num.F(timing["takeover_s"]);
            if (crackle == null || t < Num.F(CreationLab.Cfg()["overload_at"]) - lead) return;
            Sounds.Add(new CreationSound { What = CreationSound.Kind.Stop, Id = crackle });
            crackle = null;
            string overload = Gd.Str(SoundCfg()["overload"]);
            shots.Add(overload);
            Play(overload);
        }

        void Play(string sound, bool loop = false)
        {
            Cues.Add(sound);
            Sounds.Add(new CreationSound { What = loop ? CreationSound.Kind.Loop : CreationSound.Kind.Play, Id = sound });
        }

        // Every loop still held (the screen stops them when it closes, as Godot's die with the screen).
        public List<string> Held()
        {
            var held = new List<string>(loops);
            if (crackle != null) held.Add(crackle);
            return held;
        }
    }
}
