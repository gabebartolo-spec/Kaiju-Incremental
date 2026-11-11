// Photo mode's rules (GameLogic/PhotoRules.cs) against scenes/photo_mode.gd and tests/run_photo_tests.gd: the
// allowed space is tuning's (radius in rest distances, floor over the street), a far point comes back onto the
// sphere, a low one rises to the floor, one inside is left alone; the tilt stops at the limit; the card's rows
// are Godot's, the move row shows the player's own keys, and every name has its translation.
using System;
using System.Collections.Generic;
using System.IO;
using Kaiju.Game;
using S = Kaiju.Sim;

static class PhotoCheck
{
    static int checks, failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL photo: " + what);
    }

    static double Dist(double x, double y, double z, PhotoRules r)
    {
        double dx = x - r.cx, dy = y - r.cy, dz = z - r.cz;
        return Math.Sqrt(dx * dx + dy * dy + dz * dz);
    }

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        S.FileAccess.Root = repoRoot;
        string oldLanguage = Tr.Language;
        Tr.Load(File.ReadAllText(Path.Combine(repoRoot, "data", "i18n", "strings.csv")));
        Tr.Language = "en";
        // A binding saves the settings, so the player's folder is a throwaway one.
        string oldRoot = UserDir.Root;
        string dir = Path.Combine(Path.GetTempPath(), "kaiju_photo_check_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        UserDir.Root = dir;
        try
        {
            KeyBinds.Clear();
            Space();
            Card();
        }
        finally
        {
            KeyBinds.Clear();
            Tr.Language = oldLanguage;
            UserDir.Root = oldRoot;
            try { Directory.Delete(dir, true); } catch (IOException) { }
        }
        Console.WriteLine($"photo: {checks} checks, {failed} failed");
        return failed;
    }

    static void Space()
    {
        S.GDict cfg = S.Content.Section("photo_mode");
        double multiple = S.Num.F(cfg["radius_rest_multiple"]), minHeight = S.Num.F(cfg["min_height"]);
        Check(multiple > 1.0 && minHeight > 0.0 && S.Num.F(cfg["speed_rest_multiple"]) > 0.0, "tuning photo_mode has a radius past the gameplay camera, a floor and a speed");

        // rampage.gd photo_mode(): (camera offset x zoom).length(), so the space grows with him.
        S.GDict camera = S.Content.Section("camera");
        S.GArray<S.Variant> off = camera["offset"];
        double ox = S.Num.F(off[0]), oy = S.Num.F(off[1]), oz = S.Num.F(off[2]);
        double zoom1 = S.Num.F(camera["zoom_base"]) + S.Num.F(camera["zoom_per_scale"]);
        double rest1 = PhotoRules.Rest(camera, 1.0);
        Check(Math.Abs(rest1 - Math.Sqrt(ox * ox + oy * oy + oz * oz) * zoom1) < 1e-9, $"the rest distance is the camera offset times its zoom ({rest1:F2})");
        Check(PhotoRules.Rest(camera, 3.0) > rest1, "a bigger kaiju gives a bigger rest distance");

        // run_photo_tests.gd _check_clamp_math: feet (10, 0, -5), rest 40.
        PhotoRules r = new PhotoRules(cfg, 10, 0, -5, 40);
        Check(Math.Abs(r.radius - 40 * multiple) < 1e-9 && Math.Abs(r.floorY - (PhotoRules.GROUND_Y + minHeight)) < 1e-9,
            $"radius {r.radius:F2} and floor {r.floorY:F2} are tuning's");
        double x = 500, y = 30, z = 200;
        r.Clamp(ref x, ref y, ref z);
        Check(Math.Abs(Dist(x, y, z, r) - r.radius) < 0.01, $"a point far out comes back onto the sphere ({Dist(x, y, z, r):F2} of {r.radius:F2})");
        x = 10;
        y = -50;
        z = -5;
        r.Clamp(ref x, ref y, ref z);
        Check(y == r.floorY && r.floorY > 0.0, $"a point under the street rises to {y:F2}");
        x = 12;
        y = 9;
        z = -4;
        r.Clamp(ref x, ref y, ref z);
        Check(x == 12 && y == 9 && z == -4, "a point inside is left alone");
        x = 10;
        y = 10000;
        z = -5;
        r.Clamp(ref x, ref y, ref z);
        Check(Math.Abs(y - (r.cy + r.radius)) < 1e-9 && x == 10 && z == -5, "a point straight above stops at the top of the sphere");
        x = 10 + 1000;
        y = r.cy + r.radius * 0.6;
        z = -5;
        r.Clamp(ref x, ref y, ref z);
        Check(Math.Abs(Dist(x, y, z, r) - r.radius) < 0.01 && Math.Abs(y - (r.cy + r.radius * 0.6)) < 1e-9,
            "the height is kept and the reach along the ground shrinks to fit");

        double limit = S.Num.F(cfg["pitch_limit_deg"]);
        Check(r.ClampPitch(500) == limit && r.ClampPitch(-500) == -limit && r.ClampPitch(10) == 10, $"the tilt stops at +-{limit} degrees");
        Check(r.lookDegPerS == S.Num.F(cfg["look_deg_per_s"]) && r.mouseDegPerPx == S.Num.F(cfg["mouse_deg_per_px"]), "the turn rates are tuning's");
    }

    static void Card()
    {
        List<string[]> rows = PhotoRules.HintRows();
        string names = string.Join(",", rows.ConvertAll(row => row[0]));
        Check(names == "Move,Look,Up / down,Hide this,Back", "the card's rows in Godot's order: " + names);
        Check(rows[0][1] == "WASD / arrows" && rows[0][2] == "Left stick", "the move row shows the default keys");
        Check(rows[2][1] == "E / Q" && rows[2][2] == "RB / LB" && rows[3][1] == "H" && rows[3][2] == "X" && rows[4][1] == "Esc" && rows[4][2] == "B",
            "Godot's keys and buttons for rise, sink, hide and back");
        int labels = 0;
        foreach (string[] row in rows) labels += row.Length;
        Check(labels >= 15, $"the card has 15 texts under its header ({labels})");
        Check(KeyBinds.Bind("move_up", KeyBinds.KEYS, "I"), "a move key can be rebound");
        Check(PhotoRules.HintRows()[0][1].StartsWith("I ", StringComparison.Ordinal), "the card shows the player's move keys: " + PhotoRules.HintRows()[0][1]);
        KeyBinds.Clear();
        foreach (string text in new[] { "PHOTO MODE", "Move", "Look", "Drag mouse", "Right stick", "Up / down", "Hide this", "Back" })
        {
            Check(Tr.T(text, "es") != text, "'" + text + "' has its translation");
        }
        Check(KeyBinds.HasAction("photo_rise") && KeyBinds.HasAction("photo_sink") && KeyBinds.HasAction("photo_hint"), "photo mode's own keys are bound");
        Check(KeyBinds.Text("photo_rise", KeyBinds.KEYS) == "E" && KeyBinds.Text("photo_hint", KeyBinds.PAD) == "X", "rise on E, hide on pad X");
    }
}
