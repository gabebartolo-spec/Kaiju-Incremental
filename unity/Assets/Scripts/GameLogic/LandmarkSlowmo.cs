// Slow motion only when a landmark falls (scenes/landmark_slowmo.gd, D-259: "Only when a landmark falls"; the VIP
// kill and the end beat have none, D-243). When the sim reports landmark_felled (RunNews) the world slows to tuning
// "slowmo" scale for hold_s real seconds, then eases back to normal speed over ease_s. A second fall while it plays
// restarts the clock; it never stacks. Never during his death, the end beat or a finished run.
//
// Presentation only, and the sim is never told: RampageGame sets Time.timeScale to Speed, which shrinks the frame's
// delta, and its accumulator still steps the sim by whole TICKs, just on fewer frames (Godot's sim_dt). The sim sees
// the same steps in the same order with this on or off; the run just takes longer on the wall clock. The clock is
// moved by the frame's own delta over the speed it ran at (Advance), never read from the machine's clock, so a
// capture at a fixed frame rate is the same every replay. Plain C#, so SimTests/SlowmoCheck.cs steps it.
using System;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class LandmarkSlowmo
    {
        // The speed never goes below this, whatever the tuning says.
        public const double FLOOR = 0.05;
        // The slowed clock within this of its end has ended: 120 frames of 1/60 s add up a hair short of 2.0 s, and
        // the ease reads exactly 1.0 there, so it would sit active one frame at full speed.
        public const double CLOCK_SLACK = 1.0e-9;

        // False: a fall does nothing. The checks run the same rampage with and without to compare the sim.
        public bool Enabled = true;
        // The speed of the world now: Time.timeScale.
        public double Speed { get; private set; } = 1.0;

        readonly GDict cfg;
        // His death playing, the end beat up or the run over (RampageGame's own reading of the sim and the HUD).
        readonly Func<bool> suppressed;
        // Real seconds the slow motion in play has run; negative when none is.
        double age = -1.0;

        public LandmarkSlowmo(GDict tuning, Func<bool> suppressed)
        {
            cfg = tuning ?? Content.Section("slowmo");
            this.suppressed = suppressed ?? (() => false);
        }

        // The speed of the world `age` real seconds after a fall: the scale for hold_s, then eased back up to 1.0
        // over ease_s (smoothstep), then whole. Negative age: no slow motion.
        public static double SpeedAt(double age, GDict cfg)
        {
            if (age < 0.0) return 1.0;
            double low = Math.Clamp(Num.F(cfg["scale"]), FLOOR, 1.0);
            double hold = Math.Max(0.0, Num.F(cfg["hold_s"]));
            double ease = Math.Max(0.0, Num.F(cfg["ease_s"]));
            if (age < hold) return low;
            if (age >= hold + ease) return 1.0;
            double t = Math.Clamp((age - hold) / ease, 0.0, 1.0);
            return low + (1.0 - low) * t * t * (3.0 - 2.0 * t);
        }

        // True while slow motion is in play.
        public bool Active => age >= 0.0;

        // One sim event: a landmark's fall slows the world (nothing else does: the towers, the VIP's kill).
        public void OnEvent(GDict e)
        {
            if (Gd.Str(e.Get("type", "")) == "landmark_felled") Trigger();
        }

        // A landmark has fallen: slow the world now (a fall already playing starts over).
        public void Trigger()
        {
            if (!Enabled || suppressed()) return;
            age = 0.0;
            Apply();
        }

        // Moves the slowed clock on by `real` seconds of real time.
        public void Advance(double real)
        {
            if (age < 0.0) return;
            if (suppressed())
            {
                Stop();
                return;
            }
            age += real;
            if (age + CLOCK_SLACK >= Num.F(cfg["hold_s"]) + Num.F(cfg["ease_s"]))
            {
                Stop();
                return;
            }
            Apply();
        }

        // A frame's delta `scaledDt` was shrunk by `speedThen`: the real seconds it stands for.
        public static double Real(double scaledDt, double speedThen) => scaledDt / Math.Max(speedThen, FLOOR);

        // Back to normal speed now.
        public void Stop()
        {
            age = -1.0;
            Speed = 1.0;
        }

        void Apply() { Speed = SpeedAt(age, cfg); }
    }
}
