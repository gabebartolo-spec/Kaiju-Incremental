// The crushed props and the trample box (GameLogic/PropCrush.cs, KaijuFootprint.cs; scenes/prop_field.gd
// _crush_group, _fallen, crush_box and scenes/kaiju_footprint.gd of). Against Godot's own output
// (golden/prop_crush.txt, tools/unity/dump_prop_crush_golden.gd): every species' ground box at every size tier and
// share, every cell a stomp flattened or folded lies where Godot drew it, a walking body's box takes the same
// props Godot's crush_box takes, and a felled tree (GameLogic/TreeBurst.cs; prop_field.gd _burst, debris_field.gd
// _spawn_now) keeps the same stump and throws the same pieces from the same places at the same speeds.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using N = System.Numerics;
using S = Kaiju.Sim;

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
        // prop_field.gd's streams: where leaves start, and each debris field's own draws.
        S.RandomNumberGenerator burstRng = S.Seeds.Make("tree_burst"), leafRng = S.Seeds.Make("tree_leaf"),
            barkRng = S.Seeds.Make("tree_bark");
        BurstTuning tuning = default;
        float leafScale = 0f, barkScale = 0f, debrisVoxel = 0f;
        N.Vector3 treeBase = default, blow = default;
        var treeCells = new List<BurstCell>();
        var thrown = new List<BurstPiece>();
        int bursts = 0, tcells = 0, tcellsOk = 0, pieces = 0, piecesOk = 0, spawns = 0, spawnsOk = 0, next = -1;
        bool pieceBark = false;
        N.Vector3 pieceFrom = default, pieceAway = default;
        void EndBurst()
        {
            if (next >= 0) Check(next == thrown.Count, $"tree at {treeBase}: Godot threw {next} pieces, the port {thrown.Count}");
            next = -1;
        }
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
                case "TREES":
                    tuning = new BurstTuning { throwSpeed = F(w[1]), leafSpeed = F(w[2]), leafSpread = F(w[3]) };
                    leafScale = F(w[4]);
                    barkScale = F(w[5]);
                    debrisVoxel = F(w[6]);
                    break;
                case "BURST":
                    EndBurst();
                    bursts++;
                    treeBase = V(w, 1);
                    blow = V(w, 4);
                    treeCells.Clear();
                    thrown.Clear();
                    break;
                case "TCELL":
                    tcells++;
                    int height = int.Parse(w[4]);
                    treeCells.Add(new BurstCell { origin = V(w, 1), height = height, bark = w[5] == "1" });
                    if (TreeBurst.Stands(height) == (w[6] == "0") && TreeBurst.CutTop(height) == (w[7] == "1")) tcellsOk++;
                    else if (failed < 8) Check(false, $"tree cell {V(w, 1)} height {height}: hidden {w[6]}, cut {w[7]} in Godot");
                    break;
                case "PIECE":
                    if (next < 0)
                    {
                        TreeBurst.Burst(treeCells, treeBase, blow, voxel, tuning, burstRng, thrown);
                        next = 0;
                    }
                    pieces++;
                    pieceFrom = V(w, 1);
                    pieceBark = w[4] == "1";
                    pieceAway = V(w, 5);
                    BurstPiece mine = next < thrown.Count ? thrown[next] : default;
                    next++;
                    if (mine.bark == pieceBark && Near(mine.from, pieceFrom) && Near(mine.away, pieceAway)) piecesOk++;
                    else if (failed < 8)
                        Check(false, $"piece {next - 1} of the tree at {treeBase}: {mine.from} away {mine.away} (bark {mine.bark}), "
                            + $"Godot {pieceFrom} away {pieceAway} (bark {pieceBark})");
                    break;
                case "SPAWN":
                    spawns++;
                    DebrisPiece spawned = DebrisSpawn.Draw(pieceBark ? barkRng : leafRng, pieceBark ? barkScale : leafScale, pieceAway);
                    if (Near(spawned.size, F(w[1])) && Near(pieceFrom, V(w, 2)) && Near(spawned.velocity, V(w, 5))
                        && Near(spawned.angular, V(w, 8)) && Near(spawned.life, F(w[11])))
                        spawnsOk++;
                    else if (failed < 8)
                        Check(false, $"spawn {spawns}: size {spawned.size} at {pieceFrom} velocity {spawned.velocity} spin "
                            + $"{spawned.angular} life {spawned.life}, Godot {w[1]} at {V(w, 2)} velocity {V(w, 5)} spin {V(w, 8)} life {w[11]}");
                    break;
            }
        }
        EndBurst();
        Check(debrisVoxel == DebrisSpawn.VOXEL, $"debris voxel {DebrisSpawn.VOXEL}, Godot {debrisVoxel}");
        Check(bursts > 0 && tcells > 0 && pieces > 0 && spawns == pieces,
            $"the golden log has felled trees, their cells and pieces ({bursts}, {tcells}, {pieces}, {spawns})");
        Check(tcellsOk == tcells, $"{tcellsOk} of {tcells} tree cells stand, hide and show cut wood as in Godot");
        Check(piecesOk == pieces, $"{piecesOk} of {pieces} tree pieces start where Godot threw them, at its push");
        Check(spawnsOk == spawns, $"{spawnsOk} of {spawns} debris pieces take Godot's size, start, velocity, spin and life");
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
