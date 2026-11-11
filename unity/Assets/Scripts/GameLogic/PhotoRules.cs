// Photo mode's rules (scenes/photo_mode.gd, D-259 "Photo mode: Yes, simple") as plain C#, so SimTests/PhotoCheck.cs
// holds them without Unity: the allowed space round the kaiju (tuning photo_mode: a radius in multiples of the
// gameplay camera's distance, so it grows with him, and a floor over the street), the flying speed, the turn
// rates and the controls card's rows. Any y-up axes do: the sphere and the floor read the same in Godot's and
// Unity's.
using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class PhotoRules
    {
        // The street's level (photo_mode.gd GROUND_Y).
        public const double GROUND_Y = 0.0;
        // The card's rows after the move row: name, keyboard, pad (photo_mode.gd HINT_ROWS).
        public static readonly string[][] HINT_ROWS =
        {
            new[] { "Look", "Drag mouse", "Right stick" },
            new[] { "Up / down", "E / Q", "RB / LB" },
            new[] { "Hide this", "H", "X" },
            new[] { "Back", "Esc", "B" },
        };

        // The kaiju's feet: the centre of the camera's allowed sphere.
        public readonly double cx, cy, cz;
        // How far from the centre the camera may fly, and how fast (units a second).
        public readonly double radius, speed;
        // The lowest the camera may sink (world y).
        public readonly double floorY;
        public readonly double lookDegPerS, mouseDegPerPx, pitchLimitDeg;

        // cfg: tuning photo_mode; (x, y, z): the kaiju's feet; rest: the gameplay camera's distance from them now.
        public PhotoRules(S.GDict cfg, double x, double y, double z, double rest)
        {
            cx = x;
            cy = y;
            cz = z;
            radius = rest * S.Num.F(cfg["radius_rest_multiple"]);
            speed = rest * S.Num.F(cfg["speed_rest_multiple"]);
            floorY = GROUND_Y + S.Num.F(cfg["min_height"]);
            lookDegPerS = S.Num.F(cfg["look_deg_per_s"]);
            mouseDegPerPx = S.Num.F(cfg["mouse_deg_per_px"]);
            pitchLimitDeg = S.Num.F(cfg["pitch_limit_deg"]);
        }

        // rampage.gd photo_mode(): the gameplay camera's rest distance at this body size, (camera offset x
        // CameraTuning.zoom).length(); camera is tuning camera.
        public static double Rest(S.GDict camera, double bodyScale)
        {
            S.GArray<S.Variant> off = camera["offset"];
            double x = S.Num.F(off[0]), y = S.Num.F(off[1]), z = S.Num.F(off[2]);
            double zoom = S.Num.F(camera["zoom_base"]) + S.Num.F(camera["zoom_per_scale"]) * bodyScale;
            return Math.Sqrt(x * x + y * y + z * z) * Math.Abs(zoom);
        }

        // photo_mode.gd clamp_eye: the point pulled back inside the allowed space, no lower than floorY, no
        // further than radius from the feet (the height first, then the reach along the ground at that height).
        public void Clamp(ref double x, ref double y, ref double z)
        {
            y = Math.Min(Math.Max(y, floorY), Math.Max(floorY, cy + radius));
            double rise = y - cy;
            double reach = Math.Sqrt(Math.Max(radius * radius - rise * rise, 0.0));
            double fx = x - cx, fz = z - cz;
            double flat = Math.Sqrt(fx * fx + fz * fz);
            if (flat > reach)
            {
                double k = reach / flat;  // flat > reach >= 0, so never a division by zero
                fx *= k;
                fz *= k;
            }
            x = cx + fx;
            z = cz + fz;
        }

        // The pitch kept inside +-pitch_limit_deg.
        public double ClampPitch(double pitchDeg)
        {
            return Math.Min(Math.Max(pitchDeg, -pitchLimitDeg), pitchLimitDeg);
        }

        // photo_mode.gd hint_rows: the Controls list's Move row with the player's keys, then HINT_ROWS.
        public static List<string[]> HintRows()
        {
            List<string[]> o = new List<string[]>();
            foreach (string[] entry in PlayerSettings.CONTROLS)
            {
                if (entry[0] == "Move") o.Add(KeyBinds.RowText(entry));
            }
            o.AddRange(HINT_ROWS);
            return o;
        }
    }
}
