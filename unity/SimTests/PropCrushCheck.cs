// The crushed props and the trample box (GameLogic/PropCrush.cs, KaijuFootprint.cs; scenes/prop_field.gd
// _crush_group, _fallen, crush_box and scenes/kaiju_footprint.gd of). Against Godot's own output
// (golden/prop_crush.txt, tools/unity/dump_prop_crush_golden.gd): every species' ground box at every size tier and
// share, every cell a stomp flattened or folded lies where Godot drew it, and a walking body's box takes the same
// props Godot's crush_box takes.
using System;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using N = System.Numerics;

static class PropCrushCheck
{
    // Godot writes 7 decimals.
    const float TOL = 2e-5f;
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        string[] golden = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "prop_crush.txt"));
        byte[] Read(string path)
        {
            string file = Path.Combine(repoRoot, path);
            return File.Exists(file) ? File.ReadAllBytes(file) : null;
        }
        float voxel = 0f;
        N.Vector3 stomp = default, outward = default, foot = default;
        N.Matrix4x4 body = default;
        FootRect box = default;
        int feet = 0, cells = 0, cellsOk = 0, bases = 0, basesOk = 0, under = 0;
        foreach (string line in golden)
        {
            string[] w = line.Split(' ');
            switch (w[0])
            {
                case "VOXEL":
                    voxel = F(w[1]);
                    break;
                case "FOOT":
                    feet++;
                    FootRect got = KaijuFootprint.Of(Read, w[1], long.Parse(w[2]), double.Parse(w[3], CultureInfo.InvariantCulture),
                        () => { Check(false, $"{w[1]} has no sculpt"); return default; });
                    FootRect want = Rect(w, 4);
                    if (!Near(got, want)) Check(false, $"{w[1]} tier {w[2]} share {w[3]}: box {Show(got)}, Godot {Show(want)}");
                    break;
                case "STOMP":
                    stomp = V(w, 1);
                    break;
                case "PROP":
                    N.Vector3 at = V(w, 1);
                    outward = PropCrush.Out(at, stomp);
                    foot = PropCrush.Foot(at, voxel);
                    N.Vector3 offset = new N.Vector3(int.Parse(w[4]), 0, int.Parse(w[5])) * voxel;
                    Check(Near(foot, offset), $"prop at {at}: foot {foot}, Godot offset {offset}");
                    break;
                case "CELL":
                    cells++;
                    CellPose pose = PropCrush.Cell(V(w, 1), w[4] == "1", foot, outward, voxel);
                    if (Near(pose.scale, V(w, 5)) && Near(pose.origin, V(w, 8))) cellsOk++;
                    else if (failed < 8)
                        Check(false, $"cell {V(w, 1)} folds {w[4]}: {pose.scale} at {pose.origin}, Godot {V(w, 5)} at {V(w, 8)}");
                    break;
                case "BODY":
                    N.Vector3 x = V(w, 1), y = V(w, 4), z = V(w, 7), o = V(w, 10);
                    body = new N.Matrix4x4(x.X, x.Y, x.Z, 0, y.X, y.Y, y.Z, 0, z.X, z.Y, z.Z, 0, o.X, o.Y, o.Z, 1);
                    box = Rect(w, 13);
                    break;
                case "BASE":
                    bases++;
                    N.Vector3 b = V(w, 1);
                    bool took = PropCrush.Under(body, box, b), godot = w[4] == "1";
                    if (godot) under++;
                    float reach = PropCrush.Reach(body, box);
                    bool inReach = !godot || new N.Vector2(b.X - body.M41, b.Z - body.M43).Length() <= reach + TOL;
                    if (took == godot && inReach) basesOk++;
                    else if (failed < 8) Check(false, $"base {b}: under {took} (reach {inReach}), Godot {godot}");
                    break;
            }
        }
        Check(voxel > 0f && feet > 0 && cells > 0 && bases > 0 && under > 0 && under < bases,
            $"the golden log has a voxel, boxes, cells and bases both in and out ({feet}, {cells}, {under}/{bases})");
        Check(cellsOk == cells, $"{cellsOk} of {cells} crushed cells lie where Godot drew them");
        Check(basesOk == bases, $"{basesOk} of {bases} prop bases fall in or out of the box as in Godot");
        return Report();
    }

    static bool Near(float a, float b) => Math.Abs(a - b) <= TOL;

    static bool Near(N.Vector3 a, N.Vector3 b) => Near(a.X, b.X) && Near(a.Y, b.Y) && Near(a.Z, b.Z);

    static bool Near(FootRect a, FootRect b) =>
        Near(a.position.X, b.position.X) && Near(a.position.Y, b.position.Y) && Near(a.size.X, b.size.X) && Near(a.size.Y, b.size.Y);

    static string Show(FootRect r) => $"({r.position.X}, {r.position.Y}, {r.size.X}, {r.size.Y})";

    static FootRect Rect(string[] w, int at) =>
        new FootRect(new N.Vector2(F(w[at]), F(w[at + 1])), new N.Vector2(F(w[at + 2]), F(w[at + 3])));

    static N.Vector3 V(string[] w, int at) => new N.Vector3(F(w[at]), F(w[at + 1]), F(w[at + 2]));

    static float F(string s) => float.Parse(s, CultureInfo.InvariantCulture);

    static int Report()
    {
        Console.WriteLine(failed == 0 ? $"prop crush: ok ({checks} checks)" : $"prop crush: {failed} of {checks} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL prop crush: " + what);
    }
}
