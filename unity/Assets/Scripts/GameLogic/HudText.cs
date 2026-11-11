// Every text, number and threshold the rampage HUD shows (after scenes/rampage_hud.gd, hud_clock.gd,
// hud_counts.gd, threat_bar.gd, hud_ring.gd, hurt_vignette.gd, rampage_news.gd, controls_card.gd, breath_aim.gd
// and pad_rumble.gd), as plain C# so SimTests/HudCheck.cs holds it without Unity.
using System;
using System.Collections.Generic;
using System.Globalization;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public static class HudText
    {
        // rampage_hud.gd: the end beat lasts 150 frames at 60 fps and can be skipped after 40.
        public const double BEAT_SECONDS = 150.0 / 60.0;
        public const double BEAT_MIN_SECONDS = 40.0 / 60.0;
        public const int BEAT_SIZE = 128;
        public const double BEAT_TOP = 64.0;
        // hud_end_beat.gd: the flash's colour, strength and fade, and the headline's landing.
        public const double BEAT_FLASH_R = 1.0, BEAT_FLASH_G = 0.55, BEAT_FLASH_B = 0.25, BEAT_FLASH_ALPHA = 0.45;
        public const double BEAT_FLASH_SECONDS = 0.6;
        public const double BEAT_LAND_SCALE = 2.4, BEAT_LAND_SECONDS = 0.35;
        // The rolling biomass figure snaps when this close.
        public const double ROLL_SNAP = 0.5;
        // The controls card ignores presses this long, so the press that started the run does not close it.
        public const double CARD_MIN_SHOWN = 0.6;
        public const double CLOCK_MIN_WIDTH = 96.0;
        // hud_ring.gd.
        public const double ICON_SHARE = 0.9;
        public const int RING_SEGMENTS = 64;
        public const double RING_OUTLINE = 1.0;
        public const double RING_DISC_ALPHA = 0.55;
        public const double RING_IDLE_DARKEN = 0.25;
        // hurt_vignette.gd.
        public const double THUMP_SHARPNESS = 4.0;
        public const double FLASH_REACH = 0.5;
        // breath_aim.gd.
        public const int AIM_SEGMENTS = 24;
        public const double AIM_EDGE = 0.04, AIM_FILL_ALPHA = 0.22, AIM_LINE_ALPHA = 0.6, AIM_LIFT = 0.15;
        public const double AIM_PULSE_HZ = 1.2, AIM_PULSE = 0.05, AIM_BASE = 0.95, AIM_LIGHTEN = 0.4, AIM_MIDDLE = 0.6;
        // controls_card.gd.
        public static readonly string[] FIRST_RUN = { "Move", "Signature attack", "Leap" };
        public const double CARD_GAP = 12.0, CARD_H_GAP = 32.0, CARD_V_GAP = 6.0;
        // Godot's TRANS_BACK overshoot.
        const double BACK = 1.70158;

        static readonly Dictionary<string, string[]> HEADLINES = new Dictionary<string, string[]>
        {
            { "defeated", new[] { "BROUGHT DOWN", "The army got you this time" } },
            { "time", new[] { "AIRSTRIKE", "The army ran out of patience" } },
            { "city_fallen", new[] { "THE CITY HAS FALLEN", "Nothing left standing" } },
            { "ended", new[] { "RAMPAGE ENDED", "You called it off" } },
        };

        // The end beat's headline and subline for a run-over reason, in the player's language.
        public static string[] Headline(string reason)
        {
            string[] lines = HEADLINES.TryGetValue(reason ?? "", out string[] found) ? found : new[] { "RAMPAGE OVER", "" };
            return new[] { Tr.T(lines[0]), Tr.T(lines[1]) };
        }

        // ---- clock --------------------------------------------------------------------------------------

        public static long Second(double timeLeft)
        {
            return (long)Math.Ceiling(Math.Max(0.0, timeLeft));
        }

        // The clock's text: whole seconds left, or the minutes and seconds survived in Endless.
        public static string Clock(double timeLeft, double elapsed, bool endless)
        {
            if (!endless) return Second(timeLeft).ToString(CultureInfo.InvariantCulture);
            long s = (long)elapsed;
            return (s / 60).ToString(CultureInfo.InvariantCulture) + ":" + (s % 60).ToString("00", CultureInfo.InvariantCulture);
        }

        public static bool Hurry(double timeLeft, bool endless, double hurrySeconds)
        {
            return timeLeft < hurrySeconds && !endless;
        }

        // The clock thumps once on each new second of the last ten.
        public static bool HurryPulse(bool hurry, long second, long lastSecond, bool over)
        {
            return hurry && second != lastSecond && lastSecond >= 0 && !over;
        }

        // ---- biomass ------------------------------------------------------------------------------------

        // The figure on show one frame on, rolling toward `target`.
        public static double Roll(double shown, double target, double rate, double dt)
        {
            if (Math.Abs(target - shown) < ROLL_SNAP) return target;
            return shown + (target - shown) * (1.0 - Math.Exp(-rate * dt));
        }

        public static string Biomass(double shown)
        {
            return ((long)Math.Floor(shown)).ToString(CultureInfo.InvariantCulture);
        }

        public static bool Pops(double gain, double popGain)
        {
            return gain >= popGain;
        }

        // ---- rings --------------------------------------------------------------------------------------

        // How full a cooldown ring is (1 is ready).
        public static double Ratio(double readyIn, double cooldown, double floor)
        {
            return Clamp01(1.0 - readyIn / Math.Max(floor, cooldown));
        }

        // The breath ring follows the breath's own cooldown on a body whose signature is the lash.
        public static double BreathIn(string abilityType, double breathReadyIn, double abilityReadyIn)
        {
            return abilityType == "lash" ? breathReadyIn : abilityReadyIn;
        }

        public static double RingSide(double radius, double width)
        {
            return 2.0 * (radius + width * 0.5 + RING_OUTLINE + 1.0);
        }

        public static double IconHalf(double radius, double width)
        {
            return (radius - width * 0.5) * ICON_SHARE;
        }

        // The key or button a ring's action is on, for the device last touched.
        public static string Prompt(string action, bool pad)
        {
            return KeyBinds.Text(action, pad ? KeyBinds.PAD : KeyBinds.KEYS);
        }

        // ---- threat bar ---------------------------------------------------------------------------------

        public static long ThreatFilled(long level, long segments)
        {
            return level < segments ? level - 1 : segments;
        }

        public static double ThreatPartial(long level, long segments, double progress)
        {
            return level < segments ? progress : 0.0;
        }

        public static bool ThreatAlert(long level, long alertFrom)
        {
            return level >= alertFrom;
        }

        public static double ThreatSegment(double width, double gap, long segments)
        {
            return (width - gap * (segments - 1)) / segments;
        }

        // ---- layout -------------------------------------------------------------------------------------

        // How far a bottom widget sits above the safe area's floor.
        public static double Lift(double bottomMargin, double safeY, double figureGap = 0.0)
        {
            return Math.Max(0.0, Math.Round(bottomMargin - safeY - figureGap, MidpointRounding.AwayFromZero));
        }

        // Godot's TRANS_BACK ease-out from `from` to `to`, `t` of `seconds` in.
        public static double BackOut(double from, double to, double t, double seconds)
        {
            if (seconds <= 0.0 || t >= seconds) return to;
            double u = Math.Max(0.0, t) / seconds - 1.0;
            return from + (to - from) * (u * u * ((BACK + 1.0) * u + BACK) + 1.0);
        }

        public static double Linear(double from, double to, double t, double seconds)
        {
            if (seconds <= 0.0 || t >= seconds) return to;
            return from + (to - from) * Math.Max(0.0, t) / seconds;
        }

        // ---- hurt vignette ------------------------------------------------------------------------------

        public static double Hurt(double hp, double maxHp)
        {
            return maxHp <= 0.0 ? 0.0 : Clamp01(1.0 - hp / maxHp);
        }

        public static bool Beating(double hp, double maxHp, double below)
        {
            return maxHp > 0.0 && hp / maxHp < below;
        }

        // The vignette's alpha at a point of the screen (`u`, `v` 0..1), as hurt_vignette's shader has it.
        public static double VignetteAlpha(double u, double v, double width, double strength)
        {
            double dx = Math.Abs(u - 0.5) * 2.0, dy = Math.Abs(v - 0.5) * 2.0;
            double edge = (Math.Max(dx, dy) + Math.Sqrt(dx * dx + dy * dy) * 0.7071) * 0.5;
            return strength * Smooth(1.0 - width, 1.0, edge);
        }

        static double Smooth(double a, double b, double x)
        {
            if (b <= a) return x < a ? 0.0 : 1.0;
            double t = Clamp01((x - a) / (b - a));
            return t * t * (3.0 - 2.0 * t);
        }

        // ---- news ---------------------------------------------------------------------------------------

        // The headline a sim event puts on the strip ("" for none), from tuning news.live.
        public static string NewsLine(S.GDict e, S.GDict live)
        {
            string type = e.Get("type", "");
            if (type == "landmark_felled")
            {
                S.GDict marks = live["landmarks"];
                return Tr.T((string)marks.Get(e.Get("landmark", ""), marks["landmark"]));
            }
            if (type == "towers_toppled")
            {
                string n = S.Num.I(e.Get("count", 0L)).ToString(CultureInfo.InvariantCulture);
                return Tr.T((string)live["towers"]).Replace("{n}", n);
            }
            S.GDict vip = live["vip"];
            return Tr.T((string)vip.Get(type, ""));
        }

        // How long a crawl of `headlinesWidth` px stays up.
        public static double NewsSeconds(double headlinesWidth, double speed, double readS, double minS)
        {
            return Math.Max(minS, headlinesWidth / speed + readS);
        }

        // ---- controls card ------------------------------------------------------------------------------

        // The card's rows as [name, keyboard, pad], untranslated: a species' row only when the build has it,
        // the first-run card only its three.
        public static List<string[]> ControlRows(bool firstRun)
        {
            List<string[]> rows = new List<string[]>();
            foreach (string[] entry in PlayerSettings.CONTROLS)
            {
                if (entry.Length > 3 && !S.Demo.Allows(entry[3])) continue;
                if (firstRun && Array.IndexOf(FIRST_RUN, entry[0]) < 0) continue;
                rows.Add(KeyBinds.RowText(entry));
            }
            return rows;
        }

        // ---- rumble -------------------------------------------------------------------------------------

        // The rumble row a staged cue ("footfall", "stomp") uses at a size tier.
        public static S.GDict StagedRumble(S.GDict cfg, string key, long sizeTier)
        {
            S.GArray<S.Variant> rows = cfg[key];
            long at = Math.Max(0L, Math.Min(rows.Size() - 1, sizeTier - 1));
            return rows[(int)at];
        }

        // The rumble a sim event asks for as {weak, strong, seconds}; null for none.
        public static S.GDict EventRumble(S.GDict cfg, S.GDict e)
        {
            string type = e.Get("type", "");
            if (type == "fall_land" && (string)e.Get("kind", "") == "topple") return cfg["collapse"];
            if (type == "ability" && (string)e.Get("kind", "") == "cone") return cfg["breath"];
            if (type == "beam_start")
            {
                S.GDict row = cfg["breath"];
                return new S.GDict { { "weak", row["weak"] }, { "strong", row["strong"] }, { "seconds", e.Get("seconds", row["seconds"]) } };
            }
            return null;
        }

        // ---- breath aim ---------------------------------------------------------------------------------

        // The breath can be aimed now: a body that has one, off cooldown, risen and alive.
        public static bool AimShowing(string abilityType, double breathReadyIn, double abilityReadyIn, bool over, bool emerging)
        {
            bool own = abilityType == "lash";
            bool ready = (own ? breathReadyIn : abilityReadyIn) <= 0.0 && !over;
            return (own || abilityType == "cone") && ready && !emerging;
        }

        public static double AimAlpha(double age, double shown)
        {
            return (AIM_BASE + AIM_PULSE * Math.Sin(age * Math.PI * 2.0 * AIM_PULSE_HZ)) * shown;
        }

        // The wedge on the ground as triangles: x across, z along the facing, three (x, z, line) per corner
        // where line is 1 for the bright edge and 0 for the fill.
        public static List<double[]> Wedge(double reach, double half)
        {
            List<double[]> tris = new List<double[]>();
            double width = reach * AIM_EDGE;
            double[][] arc = new double[AIM_SEGMENTS + 1][];
            for (int k = 0; k <= AIM_SEGMENTS; k++)
            {
                double a = -half + 2.0 * half * k / AIM_SEGMENTS;
                arc[k] = new[] { Math.Sin(a) * reach, Math.Cos(a) * reach };
            }
            double[] zero = { 0.0, 0.0 };
            for (int k = 0; k < AIM_SEGMENTS; k++)
            {
                tris.Add(new[] { 0.0, 0.0, 0.0 });
                tris.Add(new[] { arc[k][0], arc[k][1], 0.0 });
                tris.Add(new[] { arc[k + 1][0], arc[k + 1][1], 0.0 });
                Strip(tris, arc[k], arc[k + 1], width);
            }
            Strip(tris, zero, arc[0], width);
            Strip(tris, zero, arc[AIM_SEGMENTS], width);
            Strip(tris, zero, new[] { 0.0, reach }, width * AIM_MIDDLE);
            return tris;
        }

        // A flat strip from a to b, `width` wide (breath_aim.gd _strip: side = (b - a) x UP).
        static void Strip(List<double[]> tris, double[] a, double[] b, double width)
        {
            double dx = b[0] - a[0], dz = b[1] - a[1];
            double len = Math.Sqrt(dx * dx + dz * dz);
            if (len <= 0.0) return;
            double sx = -dz / len * width * 0.5, sz = dx / len * width * 0.5;
            double[] a0 = { a[0] - sx, a[1] - sz, 1.0 }, a1 = { a[0] + sx, a[1] + sz, 1.0 };
            double[] b0 = { b[0] - sx, b[1] - sz, 1.0 }, b1 = { b[0] + sx, b[1] + sz, 1.0 };
            tris.Add(a0); tris.Add(a1); tris.Add(b1);
            tris.Add(a0); tris.Add(b1); tris.Add(b0);
        }

        static double Clamp01(double v)
        {
            return Math.Max(0.0, Math.Min(1.0, v));
        }
    }
}
