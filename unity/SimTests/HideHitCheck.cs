// The hide hit (GameLogic/SkinHits.cs, HideEye.cs; scenes/skin_hits.gd, kaiju_model.gd hide_cast). On the repo's
// own adult croc skin in the pose Godot left it after a short walk (golden/hide_hit.txt,
// tools/unity/dump_hide_hit_golden.gd), every shot meets the same cube Godot's does, at the same point and face,
// eye hits are the same shots, and the wounds those hits leave fade to the same strengths.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using Kaiju.Game;
using Kaiju.Sim;
using N = System.Numerics;

static class HideHitCheck
{
    const float DT = 1f / 60f;
    // Godot writes 7 decimals; a world point is a lerp along a ~34-unit shot, so it carries more float noise.
    const float T_TOL = 2e-5f, POINT_TOL = 1e-3f, DIR_TOL = 1e-4f, WOUND_TOL = 1e-5f;
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        string[] golden = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "hide_hit.txt"));
        GDict tune = (GDict)Content.Section("fx")["hide_hit"];
        var hits = SkinHits.FromVskin(Gunzip(Path.Combine(repoRoot, "assets", "kaiju", "reptilian_adult.vskin")), (int)Num.F(tune["max_wounds"]));
        float voxel = hits.voxel;
        int bones = hits.Bones;
        string[] head = golden[0].Split(' ');
        Check(Math.Abs(voxel - F(head[1])) < 1e-6f && bones == int.Parse(head[3]),
            $"the skin's voxel and bones match Godot's ({voxel}, {bones} against {head[1]}, {head[3]})");
        N.Vector3 eye = HideEye.Hex(head[5]);
        N.Matrix4x4 rig = Matrix(golden[1].Split(' '), 1);
        var pose = new N.Matrix4x4[bones];
        var shots = new List<string[]>();
        var godotWounds = new List<string[]>();
        int live = -1, aged = 0;
        foreach (string line in golden)
        {
            string[] w = line.Split(' ');
            if (w[0] == "POSE") pose[int.Parse(w[1])] = Matrix(w, 2);
            else if (w[0] == "RAY") shots.Add(w);
            else if (w[0] == "WOUND") godotWounds.Add(w);
            else if (w[0] == "LIVE") { live = int.Parse(w[1]); aged = int.Parse(w[3]); }
        }
        Check(shots.Count > 0 && live >= 0, "the golden log has shots and a wound count");

        int matched = 0, hitsSeen = 0, eyes = 0, misses = 0, wounds = 0;
        foreach (string[] w in shots)
        {
            N.Vector3 from = V(w, 1), to = V(w, 4);
            bool got = hits.Cast(pose, rig, from, to, out SkinHit hit);
            bool eyeHit = got && HideEye.Is(hits, hit, eye);
            string why = Compare(w, got, hit, eyeHit);
            if (why == "") matched++;
            else if (failed < 8) Check(false, $"shot {from} -> {to}: {why}");
            if (w[7] == "MISS") misses++;
            else hitsSeen++;
            if (eyeHit) eyes++;
            if (got && !eyeHit)
            {
                hits.AddWound(hit.rest, 1f - 0.01f * wounds);
                wounds++;
            }
        }
        Check(matched == shots.Count, $"every shot meets the hide where Godot's does ({matched} of {shots.Count})");
        Check(hitsSeen > 0 && eyes > 0 && misses > 0 && wounds > SkinHits.SHADER_CAP,
            $"the shots cover hits, eye hits, misses and a full wound ring ({hitsSeen}, {eyes}, {misses}, {wounds})");

        float lifetime = (float)Num.F(tune["wound_seconds"]);
        for (int i = 0; i < aged; i++) hits.Age(DT, lifetime);
        bool sameWounds = godotWounds.Count == hits.Wounds.Length;
        for (int i = 0; sameWounds && i < godotWounds.Count; i++)
        {
            string[] g = godotWounds[i];
            var want = new N.Vector4(F(g[2]), F(g[3]), F(g[4]), F(g[5]));
            sameWounds = (want - hits.Wounds[i]).Length() < WOUND_TOL * 100f && Math.Abs(want.W - hits.Wounds[i].W) < WOUND_TOL;
        }
        Check(sameWounds, "the wound ring holds Godot's points and strengths after ageing");
        Check(hits.Live() == live, $"as many wounds still show as Godot's ({hits.Live()} against {live})");
        return Report();
    }

    // "" when the C# hit is Godot's, else what differs.
    static string Compare(string[] w, bool got, in SkinHit hit, bool eyeHit)
    {
        if (w[7] == "MISS") return got ? $"Godot missed, C# hit bone {hit.bone} cell {hit.cell}" : "";
        if (!got) return "Godot hit, C# missed";
        float t = F(w[8]);
        N.Vector3 point = V(w, 9), normal = V(w, 12), rest = V(w, 15);
        var cell = (int.Parse(w[19]), int.Parse(w[20]), int.Parse(w[21]));
        if (hit.bone != int.Parse(w[18]) || hit.cell != cell) return $"bone {hit.bone} cell {hit.cell} against {w[18]} {cell}";
        if (Math.Abs(hit.t - t) > T_TOL) return $"t {hit.t} against {t}";
        if ((hit.point - point).Length() > POINT_TOL) return $"point {hit.point} against {point}";
        if ((hit.normal - normal).Length() > DIR_TOL) return $"normal {hit.normal} against {normal}";
        if ((hit.rest - rest).Length() > DIR_TOL) return $"rest {hit.rest} against {rest}";
        if (eyeHit != (w[22] == "1")) return $"eye {eyeHit} against {w[22]}";
        return "";
    }

    // The repo's .vskin is gzipped (CrocBake gunzips it the same way for the slice).
    static byte[] Gunzip(string path)
    {
        using (var gz = new GZipStream(File.OpenRead(path), CompressionMode.Decompress))
        using (var mem = new MemoryStream())
        {
            gz.CopyTo(mem);
            return mem.ToArray();
        }
    }

    // Godot's Transform3D as basis x, y, z then origin: System.Numerics' rows.
    static N.Matrix4x4 Matrix(string[] w, int at)
    {
        N.Vector3 x = V(w, at), y = V(w, at + 3), z = V(w, at + 6), o = V(w, at + 9);
        return new N.Matrix4x4(x.X, x.Y, x.Z, 0, y.X, y.Y, y.Z, 0, z.X, z.Y, z.Z, 0, o.X, o.Y, o.Z, 1);
    }

    static N.Vector3 V(string[] w, int at) => new N.Vector3(F(w[at]), F(w[at + 1]), F(w[at + 2]));

    static float F(string s) => float.Parse(s, CultureInfo.InvariantCulture);

    static int Report()
    {
        Console.WriteLine(failed == 0 ? $"hide hit: ok ({checks} checks)" : $"hide hit: {failed} of {checks} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL hide hit: " + what);
    }
}
