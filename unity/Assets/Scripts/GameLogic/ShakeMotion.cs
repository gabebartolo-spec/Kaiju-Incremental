// The camera shake's size on screen (scenes/camera_shake.gd max_turn, turn) as plain C#, so SimTests/MotionCheck.cs
// holds it without Unity: full trauma turns the camera deg_per_root_scale x sqrt(body scale) degrees, at most
// max_deg, times the shake shown now, times the player's camera-motion setting (PlayerSettings.Motion(), 0..1),
// which scales the footfall nod the same way. Rampage/CameraShake.cs draws the noise; this sizes it.
using System;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public static class ShakeMotion
    {
        const double DEG_TO_RAD = Math.PI / 180.0;

        // The largest turn (radians) full trauma gives a body of `scale`, before the player's setting.
        public static double MaxTurn(S.GDict cfg, double scale)
        {
            double deg = S.Num.F(cfg["deg_per_root_scale"]) * Math.Sqrt(Math.Max(scale, 0.0));
            return Math.Min(S.Num.F(cfg["max_deg"]), deg) * DEG_TO_RAD;
        }

        // This frame's shake amplitude (radians): the max turn times the shake shown (trauma squared, eased)
        // times the motion setting.
        public static double Amplitude(S.GDict cfg, double scale, double shown, double motion)
        {
            return MaxTurn(cfg, scale) * shown * Clamp01(motion);
        }

        // The footfall kick's pitch now (radians, 0 or more): `kick` eased out by its share of time left, times
        // the motion setting.
        public static double Nod(double kick, double share, double motion)
        {
            double s = Clamp01(share);
            return kick * s * s * Clamp01(motion);
        }

        static double Clamp01(double v) => v < 0.0 ? 0.0 : v > 1.0 ? 1.0 : v;
    }
}
