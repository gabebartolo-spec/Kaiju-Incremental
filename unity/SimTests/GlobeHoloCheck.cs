// The hologram globe's motion and screen maths (GameLogic/GlobeOrbit.cs) against Godot's globe (scenes/globe_view.gd),
// number for number from golden/globe.txt (tools/unity/dump_globe_golden.gd, headless): the idle spin, each
// continent's fly-to target and the flight there and back, continent_at over a screen grid, the markers' places, fades
// and hiding at six yaws, a drag and a click. Player-effect fixture "globe.hologram": spin on turns the globe, off
// holds it; a press that drags past the slop turns the globe and picks nothing, one that stays inside it picks the
// continent under it; a pick flies the camera in and brings the continent to the centre of the screen.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using Kaiju.Sim;

static class GlobeHoloCheck
{
    const string GOLDEN = "unity/SimTests/golden/globe.txt";
    const string MASK = "assets/overworld/tellus_nova_mask.png";
    // tools/unity/dump_globe_golden.gd's run.
    const double DT = 1.0 / 60.0, START_YAW = 0.4, GRID_YAW = 0.7;
    const int IDLE_STEPS = 60, EVERY = 10, FLY_STEPS = 50, FLY_EVERY = 7, GRID_STEP = 30;
    static readonly double[][] DRAG = { new[] { 30.0, 0.0 }, new[] { 0.0, 20.0 }, new[] { -12.0, -9.0 } };
    static readonly double[] NUDGE = { 2.0, 1.0 };
    // Godot's Vector3 is float: its numbers agree with these doubles to about 1e-6 of their size.
    const double EPS = 1e-4, PX = 0.01, CENTRE_PX = 0.5;

    static int checks, failed;
    static byte[] mask;
    static int maskW, maskH;
    static readonly List<string> ids = new List<string>();
    static double[][] anchors;
    static GDict states;

    public static int Run(string repoRoot)
    {
        Kaiju.Sim.FileAccess.Root = repoRoot;
        checks = failed = 0;
        mask = GlobeCheck.Png(Path.Combine(repoRoot, MASK), out maskW, out maskH);
        ids.Clear();
        foreach (GDict def in Content.Continents()) ids.Add(Gd.Str(def["id"]));
        Anchors();
        states = GlobeMissions.States(new GDict { { "conquered", Gd.Arr("ostia_minor") }, { "threat", 10.0 } });
        string[] lines = File.ReadAllLines(Path.Combine(repoRoot, GOLDEN));
        GlobeOrbit orbit = new GlobeOrbit();
        string[] v = lines[0].Split(' ');
        orbit.Width = D(v[1]);
        orbit.Height = D(v[2]);
        Idle(orbit, lines);
        foreach (string id in ids) Flight(orbit, lines, id);
        Grid(orbit, lines);
        Markers(orbit, lines);
        Drag(orbit, lines);
        Fixture(orbit);
        Console.WriteLine($"globe hologram: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL globe hologram: " + what);
    }

    static double D(string s) => double.Parse(s, CultureInfo.InvariantCulture);

    static void Anchors()
    {
        double[][] uvs = GlobeMath.AnchorUvs(mask, maskW, maskH, ids.Count);
        anchors = new double[uvs.Length][];
        for (int n = 1; n < uvs.Length; n++)
        {
            GlobeMath.PointOf(uvs[n][0], uvs[n][1], out double x, out double y, out double z);
            anchors[n] = new[] { x, y, z };
        }
    }

    static List<string[]> Rows(string[] lines, string tag, string id = null)
    {
        var rows = new List<string[]>();
        foreach (string line in lines)
        {
            string[] t = line.Split(' ');
            if (t[0] == tag && (id == null || t[1] == id)) rows.Add(t);
        }
        return rows;
    }

    static void Pose(GlobeOrbit o, string[] t, int at, string what)
    {
        bool ok = Math.Abs(o.Yaw - D(t[at])) < EPS && Math.Abs(o.Tilt - D(t[at + 1])) < EPS && Math.Abs(o.Distance - D(t[at + 2])) < EPS;
        Check(ok, $"{what}: yaw {o.Yaw:F6} tilt {o.Tilt:F6} distance {o.Distance:F6}, Godot {t[at]} {t[at + 1]} {t[at + 2]}");
    }

    // globe_view.gd _process with nothing selected: IDLE_SPIN rad/s.
    static void Idle(GlobeOrbit o, string[] lines)
    {
        o.Reset(0.0);
        List<string[]> rows = Rows(lines, "I");
        int row = 0;
        for (int s = 0; s <= IDLE_STEPS; s++)
        {
            if (s % EVERY == 0) Pose(o, rows[row++], 2, $"idle step {s}");
            o.Step(DT);
        }
    }

    // globe_view.gd fly_to then fly_out: the target, then the eased flight in and back out.
    static void Flight(GlobeOrbit o, string[] lines, string id)
    {
        o.Reset(START_YAW);
        double[] a = anchors[ids.IndexOf(id) + 1];
        o.FlyTo(id, a[0], a[1], a[2]);
        string[] target = Rows(lines, "T", id)[0];
        double[] to = o.Target;
        Check(Math.Abs(to[0] - D(target[2])) < EPS && Math.Abs(to[1] - D(target[3])) < EPS && Math.Abs(to[2] - D(target[4])) < EPS,
            $"{id} fly-to target {to[0]:F6} {to[1]:F6} {to[2]:F6}, Godot {target[2]} {target[3]} {target[4]}");
        foreach (string tag in new[] { "F", "O" })
        {
            if (tag == "O") o.FlyOut();
            List<string[]> rows = Rows(lines, tag, id);
            int row = 0;
            for (int s = 0; s < FLY_STEPS; s++)
            {
                o.Step(DT);
                if (s % FLY_EVERY != 0 && s != FLY_STEPS - 1) continue;
                string[] t = rows[row++];
                Pose(o, t, 3, $"{id} {tag} step {s}");
                Check((o.Flying ? "1" : "0") == t[6], $"{id} {tag} step {s}: flying {o.Flying}, Godot {t[6]}");
            }
        }
    }

    // globe_view.gd continent_at over a grid of screen points.
    static void Grid(GlobeOrbit o, string[] lines)
    {
        o.Reset(GRID_YAW);
        foreach (string[] t in Rows(lines, "G"))
        {
            int y = int.Parse(t[1], CultureInfo.InvariantCulture);
            var row = new char[t[2].Length];
            for (int i = 0; i < row.Length; i++) row[i] = (char)('0' + o.ValueAt(mask, maskW, maskH, i * GRID_STEP, y));
            string got = new string(row);
            Check(got == t[2], $"continent_at row y {y}: {got}, Godot {t[2]}");
        }
    }

    // globe_view.gd _place_markers: shown on the near side at the projected anchor, faded toward the edge.
    static void Markers(GlobeOrbit o, string[] lines)
    {
        foreach (string[] t in Rows(lines, "M"))
        {
            o.Reset(D(t[1]));
            int n = int.Parse(t[2], CultureInfo.InvariantCulture);
            double[] a = anchors[n + 1];
            bool shown = o.Marker(a[0], a[1], a[2], out double sx, out double sy, out double alpha);
            string what = $"marker {ids[n]} at yaw {t[1]}";
            Check(shown == (t[3] == "1"), $"{what}: shown {shown}, Godot {t[3]}");
            if (!shown) continue;  // Godot leaves a hidden marker's place and fade as they were
            Check(Math.Abs(sx - D(t[4])) < PX && Math.Abs(sy - D(t[5])) < PX && Math.Abs(alpha - D(t[6])) < EPS,
                $"{what}: {sx:F4} {sy:F4} alpha {alpha:F6}, Godot {t[4]} {t[5]} {t[6]}");
        }
    }

    // A press, moves and release as _unhandled_input takes them: a click picks the open continent under it.
    static string Gesture(GlobeOrbit o, double x, double y, double[][] moves)
    {
        o.Press();
        foreach (double[] m in moves)
        {
            x += m[0];
            y += m[1];
            o.Move(m[0], m[1]);
        }
        if (!o.Release()) return "";
        int value = o.ValueAt(mask, maskW, maskH, x, y);
        string id = value >= 1 && value <= ids.Count ? ids[value - 1] : "";
        if (GlobeMissions.Locked(states, id)) return "";
        double[] a = anchors[value];
        o.FlyTo(id, a[0], a[1], a[2]);
        return id;
    }

    static void Drag(GlobeOrbit o, string[] lines)
    {
        List<string[]> rows = Rows(lines, "D");
        o.Reset(START_YAW);
        Gesture(o, o.Width / 2.0, o.Height / 2.0, DRAG);
        Same(o, rows[0], "drag");
        o.Reset(START_YAW);
        double px = 0.0, py = 0.0;
        foreach (string id in ids)
        {
            double[] a = anchors[ids.IndexOf(id) + 1];
            if (!GlobeMissions.Locked(states, id) && o.Marker(a[0], a[1], a[2], out px, out py, out _))
                break;
        }
        Gesture(o, px, py, new[] { NUDGE });
        Same(o, rows[1], "click");
    }

    static void Same(GlobeOrbit o, string[] t, string what)
    {
        Pose(o, t, 2, what);
        string selected = o.Selected == "" ? "-" : o.Selected;
        Check(selected == t[5] && (o.Flying ? "1" : "0") == t[6], $"{what}: selected {selected} flying {o.Flying}, Godot {t[5]} {t[6]}");
    }

    // Player effect: what the player sees change, on against off.
    static void Fixture(GlobeOrbit o)
    {
        o.Reset(START_YAW);
        o.Spin = false;
        o.Step(1.0);
        Check(o.Yaw == START_YAW, "spin off: the globe holds still");
        o.Spin = true;
        o.Step(1.0);
        Check(Math.Abs(o.Yaw - START_YAW - GlobeOrbit.IDLE_SPIN) < EPS, "spin on: the globe turns IDLE_SPIN in a second");
        foreach (string id in ids)
        {
            o.Reset(START_YAW);
            double[] a = anchors[ids.IndexOf(id) + 1];
            o.Marker(a[0], a[1], a[2], out double bx, out double by, out _);
            o.FlyTo(id, a[0], a[1], a[2]);
            for (int s = 0; s < FLY_STEPS; s++) o.Step(DT);
            o.Marker(a[0], a[1], a[2], out double sx, out double sy, out _);
            bool clamped = Math.Abs(Math.Asin(a[1])) > GlobeOrbit.TILT_LIMIT;
            bool centred = Math.Abs(sx - o.Width / 2.0) < CENTRE_PX && (clamped || Math.Abs(sy - o.Height / 2.0) < CENTRE_PX);
            Check(!o.Flying && o.Distance == GlobeOrbit.ZOOM_DISTANCE && centred,
                $"a pick on {id} flies in and centres it: from {bx:F1} {by:F1} to {sx:F1} {sy:F1}, distance {o.Distance}");
        }
    }
}
