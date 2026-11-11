// The HUD's and the run input's small state machines (after scenes/input_latch.gd, held_button.gd,
// hurt_vignette.gd and rampage_news.gd), as plain C# so SimTests/HudCheck.cs steps them without Unity.
using System;
using System.Collections.Generic;

namespace Kaiju.Game
{
    // Presses made while the kaiju is still rising are kept and handed over on the first free frame.
    public sealed class HudLatch
    {
        const double EPSILON = 1e-6;
        readonly double window;
        readonly Dictionary<string, double> ages = new Dictionary<string, double>();

        public HudLatch(double windowSeconds) { window = windowSeconds; }

        // `pressed` as the sim should get it this frame; while `heldBack` it is only remembered.
        public Dictionary<string, bool> Through(bool heldBack, Dictionary<string, bool> pressed, double dt)
        {
            if (heldBack)
            {
                foreach (string key in new List<string>(ages.Keys)) ages[key] += dt;
                foreach (KeyValuePair<string, bool> p in pressed) if (p.Value) ages[p.Key] = 0.0;
                return pressed;
            }
            Dictionary<string, bool> o = new Dictionary<string, bool>(pressed);
            foreach (KeyValuePair<string, double> a in ages) if (a.Value <= window + EPSILON) o[a.Key] = true;
            ages.Clear();
            return o;
        }
    }

    // The signature button as held, or as a toggle when the player asked for hold-to-toggle.
    public sealed class HudHeld
    {
        bool latched;

        public bool Read(bool down, bool pressed, bool holdToggle)
        {
            if (!holdToggle) { latched = false; return down; }
            if (pressed) latched = !latched;
            return latched;
        }
    }

    // The red at the screen's edge: how far in it reaches and how strong, from the kaiju's health.
    public sealed class HudHurt
    {
        public double Width, Strength;
        double shown, flash, beat, lastHp = -1.0;

        public void Step(double hp, double maxHp, double dt, double widthMax, double alphaMax, double easeRate,
            double heartbeatBelow, double heartbeatHz, double heartbeatDepth, double flashS, double flashAlpha)
        {
            if (lastHp >= 0.0 && hp < lastHp) flash = flashS;
            lastHp = hp;
            flash = Math.Max(0.0, flash - dt);
            shown += (HudText.Hurt(hp, maxHp) - shown) * (1.0 - Math.Exp(-easeRate * dt));
            double pulse = 1.0;
            if (HudText.Beating(hp, maxHp, heartbeatBelow))
            {
                beat += dt * heartbeatHz;
                double thump = Math.Pow(Math.Max(0.0, Math.Sin(Math.PI * 2.0 * beat)), HudText.THUMP_SHARPNESS);
                pulse = 1.0 - heartbeatDepth * (1.0 - thump);
            }
            double flashNow = flashAlpha * flash / Math.Max(0.001, flashS);
            Width = widthMax * shown;
            Strength = Math.Max(0.0, Math.Min(1.0, alphaMax * Math.Sqrt(shown) * pulse + flashNow));
            if (flashNow > 0.0) Width = Math.Max(Width, widthMax * HudText.FLASH_REACH);
        }
    }

    // The live news strip's queue and timing: one crawl at a time slides in, is read, slides out.
    public sealed class HudNewsQueue
    {
        public enum Step { None, SlideIn, SlideOut, Gone }

        public readonly List<string> Shown = new List<string>();
        public bool Muted;
        public string Current { get; private set; }
        readonly List<string> queue = new List<string>();
        readonly int max;
        readonly double slideS;
        double left, leaving;

        public HudNewsQueue(int max, double slideS) { this.max = max; this.slideS = slideS; }

        public int Waiting => queue.Count;
        public bool Visible => !Muted && (Current != null || leaving > 0.0);
        // How far through its slide out the leaving crawl is (0 none, 1 gone).
        public double Leaving => slideS <= 0.0 ? 1.0 : 1.0 - Math.Max(0.0, leaving) / slideS;

        public void Add(string line)
        {
            if (string.IsNullOrEmpty(line)) return;
            queue.Add(line);
            while (queue.Count > max) queue.RemoveAt(0);
        }

        // One frame: what the strip must do now. After SlideIn the caller says how long the crawl stays (Stay).
        public Step Tick(double dt)
        {
            if (Muted) return Step.None;
            if (Current != null)
            {
                left -= dt;
                if (left > 0.0) return Step.None;
                Current = null;
                leaving = slideS;
                return Step.SlideOut;
            }
            if (leaving > 0.0)
            {
                leaving -= dt;
                return leaving > 0.0 ? Step.None : Step.Gone;
            }
            if (queue.Count == 0) return Step.None;
            Current = queue[0];
            queue.RemoveAt(0);
            Shown.Add(Current);
            return Step.SlideIn;
        }

        public void Stay(double seconds) { left = seconds; }
    }
}
