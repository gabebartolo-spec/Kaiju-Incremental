// The croc's death pieces (Rampage/DeathPieces.cs, scenes/death_chunks.gd): the baked stone chunks
// (assets/death/chunk_*.obj) parse whole and wound one way for the z mirror; a launched piece flies, tumbles and
// comes to rest on its lowest corner on the street as rubble (on), while a piece never launched stays exactly where
// it was placed (off); a turn is Godot's Basis(axis, angle); and the same launch lands the same way twice.
using System;
using System.IO;
using N = System.Numerics;

static class DeathCheck
{
    const float EPS = 1e-3f, DT = 1f / 60f, GRAVITY = 30f;
    const int STEPS = 600;
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        N.Vector3[][] corners = Chunks(repoRoot);
        TurnMatchesGodot();
        if (corners.Length > 0)
        {
            Falls(corners);
            StaysUnlaunched(corners);
            Repeats(corners);
        }
        Console.WriteLine(failed == 0 ? $"death pieces: ok ({checks} checks)" : $"death pieces: {failed} of {checks} failed");
        return failed;
    }

    static N.Vector3[][] Chunks(string repoRoot)
    {
        string dir = Path.Combine(repoRoot, "assets", "death");
        var all = new System.Collections.Generic.List<N.Vector3[]>();
        for (int k = 0; File.Exists(Path.Combine(dir, $"chunk_{k}.obj")); k++)
        {
            var obj = new ObjChunk(File.ReadAllText(Path.Combine(dir, $"chunk_{k}.obj")));
            Check(obj.corners.Length >= 4, $"chunk {k} has {obj.corners.Length} corners");
            Check(obj.triangles.Count > 0 && obj.triangles.Count % 3 == 0, $"chunk {k} has {obj.triangles.Count} triangle corners");
            int wrong = 0;
            for (int t = 0; t < obj.triangles.Count; t += 3)
            {
                N.Vector3 a = obj.points[obj.triangles[t]], b = obj.points[obj.triangles[t + 1]], c = obj.points[obj.triangles[t + 2]];
                if (N.Vector3.Dot(N.Vector3.Cross(b - a, c - a), obj.normals[obj.triangles[t]]) > EPS) wrong++;
            }
            Check(wrong == 0, $"chunk {k}: {wrong} triangles wound the wrong way for the z mirror");
            N.Vector3 lo = new N.Vector3(float.MaxValue), hi = new N.Vector3(float.MinValue);
            foreach (N.Vector3 v in obj.corners)
            {
                lo = N.Vector3.Min(lo, v);
                hi = N.Vector3.Max(hi, v);
            }
            N.Vector3 span = hi - lo;
            float longest = MathF.Max(span.X, MathF.Max(span.Y, span.Z));
            Check(MathF.Abs(longest - 1f) < 0.05f, $"chunk {k}'s longest side is {longest:F3}, baked as 1");
            all.Add(obj.corners);
        }
        Check(all.Count == 8, $"{all.Count} chunks in assets/death (tuning death.look.chunks names 8)");
        return all.ToArray();
    }

    static void TurnMatchesGodot()
    {
        // Godot: Basis(Vector3.UP, PI / 2) * Vector3.RIGHT == Vector3(0, 0, -1).
        N.Vector3 v = Turn.About(N.Vector3.UnitY, MathF.PI / 2f).Apply(N.Vector3.UnitX);
        Check(N.Vector3.Distance(v, new N.Vector3(0, 0, -1)) < EPS, $"a quarter turn about up takes x to {v}, Godot gives (0, 0, -1)");
        Turn t = Turn.About(N.Vector3.Normalize(new N.Vector3(1, 2, 3)), 1.1f);
        Check(MathF.Abs(t.Apply(new N.Vector3(0.3f, -0.4f, 2f)).Length() - new N.Vector3(0.3f, -0.4f, 2f).Length()) < EPS, "a turn keeps lengths");
    }

    static DeathPieces Make(N.Vector3[][] corners, int n)
    {
        var kinds = new int[n];
        var sizes = new float[n];
        var lie = new Turn[n];
        for (int i = 0; i < n; i++)
        {
            kinds[i] = i % corners.Length;
            sizes[i] = 0.3f + 0.2f * i;
            lie[i] = Turn.About(N.Vector3.Normalize(new N.Vector3(1 + i, 2, -1)), 0.7f * i);
        }
        return new DeathPieces(corners, kinds, sizes, lie);
    }

    static void Launch(DeathPieces p)
    {
        for (int i = 0; i < p.Count; i++)
            p.Launch(i, new N.Vector3(i, 6f + i, -i), new N.Vector3(4f - i, 8f, 2f), N.Vector3.Normalize(new N.Vector3(1, i, 2)) * (3f + i));
    }

    // On: launched pieces fly, then lie still on their lowest corner at street level.
    static void Falls(N.Vector3[][] corners)
    {
        DeathPieces p = Make(corners, 8);
        Launch(p);
        N.Vector3 start = p.drawAt[0];
        p.Fall(DT, GRAVITY);
        Check(p.drawAt[0] != start, "a launched piece moves on its first step");
        for (int s = 0; s < STEPS; s++) p.Fall(DT, GRAVITY);
        for (int i = 0; i < p.Count; i++)
        {
            Check(!p.Moving(i), $"piece {i} still moving after {STEPS} steps");
            float low = float.PositiveInfinity;
            foreach (N.Vector3 c in corners[p.kind[i]]) low = MathF.Min(low, p.drawTurn[i].Apply(c * p.size[i]).Y + p.drawAt[i].Y);
            Check(MathF.Abs(low) < 0.02f * p.size[i] + EPS, $"piece {i}'s lowest corner rests at {low:F4}, not on the street");
        }
    }

    // Off: a piece placed and never launched stays exactly where it was put.
    static void StaysUnlaunched(N.Vector3[][] corners)
    {
        DeathPieces p = Make(corners, 3);
        var at = new N.Vector3(5f, 4f, -2f);
        p.Place(1, p.lie[1], at);
        for (int s = 0; s < STEPS; s++) p.Fall(DT, GRAVITY);
        Check(p.drawAt[1] == at && !p.Moving(1), $"an unlaunched piece moved to {p.drawAt[1]}");
    }

    static void Repeats(N.Vector3[][] corners)
    {
        DeathPieces a = Make(corners, 8), b = Make(corners, 8);
        Launch(a);
        Launch(b);
        for (int s = 0; s < STEPS; s++)
        {
            a.Fall(DT, GRAVITY);
            b.Fall(DT, GRAVITY);
        }
        bool same = true;
        for (int i = 0; i < a.Count; i++) same &= a.drawAt[i] == b.drawAt[i] && a.drawTurn[i].x == b.drawTurn[i].x;
        Check(same, "the same launch lands differently twice");
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL death pieces: " + what);
    }
}
