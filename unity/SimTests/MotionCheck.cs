// The camera-motion setting reaches the shake (GameLogic/ShakeMotion.cs, Rampage/CameraShake.cs, after
// scenes/camera_shake.gd turn and autoload/player_settings.gd motion): a player-effect fixture, the slider at 0
// against 1. At 0 a full-trauma hit and a footfall kick turn the camera not at all; at 1 the shake is tuning's full
// size (deg_per_root_scale x sqrt(scale) degrees, capped at max_deg) and the kick its full pitch; unset is tuning
// default_motion; half is half; the slider's own setter clamps out-of-range values.
using System;
using System.IO;
using Kaiju.Game;
using S = Kaiju.Sim;
using Opt = Kaiju.Game.PlayerSettings;

static class MotionCheck
{
    static int checks, failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL motion: " + what);
    }

    static bool Near(double a, double b) => Math.Abs(a - b) <= 1e-9 * Math.Max(1.0, Math.Abs(b));

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        S.FileAccess.Root = repoRoot;
        // The slider saves the settings, so the player's folder is a throwaway one.
        string oldRoot = UserDir.Root;
        string dir = Path.Combine(Path.GetTempPath(), "kaiju_motion_check_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        UserDir.Root = dir;
        try
        {
            S.GDict tuning = S.JSON.ParseString(File.ReadAllText(Path.Combine(repoRoot, "data", "tuning.json")));
            S.GDict cfg = (S.GDict)tuning["camera_shake"];
            double degPerRoot = S.Num.F(cfg["deg_per_root_scale"]), maxDeg = S.Num.F(cfg["max_deg"]);
            // A small body under the cap and a big one past it, both at full trauma (shown = 1).
            double small = Math.Pow(maxDeg / degPerRoot, 2.0) / 4.0, big = Math.Pow(maxDeg / degPerRoot, 2.0) * 4.0;
            double fullSmall = degPerRoot * Math.Sqrt(small) * Math.PI / 180.0, fullBig = maxDeg * Math.PI / 180.0;
            double kick = S.Num.F(cfg["kick_s"]);

            Opt.ResetDefaults();
            double unset = Opt.Motion();
            Check(Near(unset, S.Num.F(cfg["default_motion"])), "unset motion is tuning default_motion");

            Opt.SetCameraMotion(0.0);
            double offSmall = ShakeMotion.Amplitude(cfg, small, 1.0, Opt.Motion());
            double offBig = ShakeMotion.Amplitude(cfg, big, 1.0, Opt.Motion());
            double offNod = ShakeMotion.Nod(kick, 1.0, Opt.Motion());
            Check(offSmall == 0.0 && offBig == 0.0, $"motion 0: full trauma turns {offSmall}, {offBig} rad, want 0");
            Check(offNod == 0.0, $"motion 0: the footfall kick pitches {offNod} rad, want 0");

            Opt.SetCameraMotion(1.0);
            double onSmall = ShakeMotion.Amplitude(cfg, small, 1.0, Opt.Motion());
            double onBig = ShakeMotion.Amplitude(cfg, big, 1.0, Opt.Motion());
            double onNod = ShakeMotion.Nod(kick, 1.0, Opt.Motion());
            Check(Near(onSmall, fullSmall), $"motion 1: small body turns {onSmall} rad, want {fullSmall}");
            Check(Near(onBig, fullBig), $"motion 1: big body turns {onBig} rad, want the max_deg cap {fullBig}");
            Check(Near(onNod, kick), $"motion 1: the kick pitches {onNod} rad, want {kick}");

            Opt.SetCameraMotion(0.5);
            Check(Near(ShakeMotion.Amplitude(cfg, small, 1.0, Opt.Motion()), fullSmall * 0.5), "motion 0.5 halves the shake");
            Check(Near(ShakeMotion.Amplitude(cfg, small, 0.25, Opt.Motion()), fullSmall * 0.125), "the shake scales with the shake shown");

            Opt.SetCameraMotion(2.0);
            Check(Near(Opt.Motion(), 1.0), "the slider clamps above 1");
            Opt.SetCameraMotion(-3.0);
            Check(Near(Opt.Motion(), 0.0), "the slider clamps below 0");

            Console.WriteLine($"motion fixture: off {offSmall:F5}/{offBig:F5} rad, on {onSmall:F5}/{onBig:F5} rad (default "
                + $"{fullSmall:F5}/{fullBig:F5}), kick off {offNod:F3} on {onNod:F3}");
        }
        finally
        {
            Opt.ResetDefaults();
            UserDir.Root = oldRoot;
            try { Directory.Delete(dir, true); } catch (IOException) { }
        }
        Console.WriteLine($"motion: {checks} checks, {failed} failed");
        return failed;
    }
}
