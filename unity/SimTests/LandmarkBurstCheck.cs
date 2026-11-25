// A landmark section's burst (GameLogic/LandmarkBurst.cs; scenes/landmark_burst.gd, scenes/carve_job.gd samples)
// against Godot's own output (golden/landmark_burst.txt, tools/unity/dump_landmark_burst_golden.gd): for real
// sections the stadium shed from its fine view and two made-up big ones, the same cells are sampled, the same chunks
// are thrown from the same places at the same speeds in the same colours and sizes, the same puffs, fragments and
// dust, and every sampled frame of the spray and the cloud stands where Godot drew it.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using N = System.Numerics;
using S = Kaiju.Sim;

static class LandmarkBurstCheck
{
    // Godot writes 9 decimals of float32 values up to a few hundred metres.
    const float TOL = 1e-4f;
    // The dump steps the burst at 60 Hz.
    const double DT = 1.0 / 60.0;
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        S.FileAccess.Root = repoRoot;
        failed = 0;
        checks = 0;
        string[] golden = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "landmark_burst.txt"));
        LandmarkBurstTuning tuning = LandmarkBurstTuning.From(S.Content.Section("landmark_burst"));
        Check(tuning.chunks == 360 && tuning.fragments == 40 && tuning.clouds == 7, "tuning read as Godot's");
        int sections = 0;
        string name = "";
        long id = 0;
        N.Vector2 middle = default;
        int w = 0, d = 0;
        N.Vector3 origin = default;
        float voxel = 0f;
        var index = new List<int>();
        var looks = new Dictionary<int, N.Vector4>();
        var wantSamples = new List<int>();
        LandmarkBurstPlan plan = null;
        int chunk = 0, cloud = 0, frag = 0, dust = 0;
        double t = 0;
        int samples = 0, samplesOk = 0, chunks = 0, chunksOk = 0, poses = 0, posesOk = 0, puffs = 0, puffsOk = 0;
        // The plan is made once every SAMPLE line of a section is read: on its first CHUNK (or later line).
        LandmarkBurstPlan Plan()
        {
            if (plan != null) return plan;
            List<BurstPart> parts = LandmarkBurst.Samples(index, w, d, origin, voxel,
                i => looks.TryGetValue(i, out N.Vector4 c) ? c : new N.Vector4(float.NaN));
            var got = new List<int>();
            foreach (BurstPart part in parts)
            {
                N.Vector3 c = (part.pos - origin) / voxel;
                got.Add((int)MathF.Round(c.X) + (int)MathF.Round(c.Z) * w + (int)MathF.Round(c.Y) * w * d);
            }
            samples += wantSamples.Count;
            for (int k = 0; k < Math.Min(got.Count, wantSamples.Count); k++)
                if (got[k] == wantSamples[k]) samplesOk++;
            Check(got.Count == wantSamples.Count, $"{name}: Godot sampled {wantSamples.Count} cells, the port {got.Count}");
            plan = LandmarkBurst.Plan(parts, middle, id, tuning);
            return plan;
        }
        void EndSection()
        {
            if (plan == null) return;
            Check(chunk == plan.chunks.Count, $"{name}: Godot threw {chunk} chunks, the port {plan.chunks.Count}");
            Check(cloud == plan.clouds.Count, $"{name}: Godot made {cloud} puffs, the port {plan.clouds.Count}");
            Check(frag == plan.fragments.Count, $"{name}: Godot sent {frag} fragments, the port {plan.fragments.Count}");
            Check(dust == 1, $"{name}: Godot raised {dust} dust puffs");
        }
        foreach (string line in golden)
        {
            string[] x = line.Split(' ');
            switch (x[0])
            {
                case "SECTION":
                    EndSection();
                    sections++;
                    id = long.Parse(x[1]);
                    middle = new N.Vector2(F(x[2]), F(x[3]));
                    name = $"section {id} ({x[5]}, {x[4]} cells)";
                    index.Clear();
                    looks.Clear();
                    wantSamples.Clear();
                    plan = null;
                    chunk = cloud = frag = dust = 0;
                    break;
                case "GRID":
                    w = int.Parse(x[1]);
                    d = int.Parse(x[2]);
                    origin = V(x, 3);
                    voxel = F(x[6]);
                    break;
                case "INDEX":
                    for (int k = 1; k < x.Length; k++) index.Add(int.Parse(x[k]));
                    break;
                case "RUN":
                    int start = int.Parse(x[1]), count = int.Parse(x[2]);
                    for (int k = 0; k < count; k++) index.Add(start + k);
                    break;
                case "SAMPLE":
                    int cell = int.Parse(x[1]);
                    wantSamples.Add(cell);
                    looks[cell] = C(x, 5);
                    break;
                case "CHUNK":
                {
                    chunks++;
                    LandmarkBurstPlan p = Plan();
                    if (chunk < p.chunks.Count)
                    {
                        BurstChunk c = p.chunks[chunk];
                        bool ok = Near(c.from, V(x, 1)) && Near(c.vel, V(x, 4)) && Near(c.color, C(x, 7)) && Near(c.size, F(x[11]));
                        if (ok) chunksOk++;
                        else if (chunksOk + 3 > chunks) Console.WriteLine($"  {name} chunk {chunk}: port {c.from} {c.vel} {c.color} {c.size}, Godot {line}");
                    }
                    chunk++;
                    break;
                }
                case "CLOUD":
                {
                    LandmarkBurstPlan p = Plan();
                    Check(cloud < p.clouds.Count && Near(p.clouds[cloud], V(x, 1)),
                        $"{name} puff {cloud}: port {(cloud < p.clouds.Count ? p.clouds[cloud].ToString() : "none")}, Godot {line}");
                    cloud++;
                    break;
                }
                case "CLOUDSIZE":
                    Check(Near(Plan().cloudSize, F(x[1])), $"{name}: cloud size {Plan().cloudSize}, Godot {x[1]}");
                    break;
                case "FRAG":
                {
                    LandmarkBurstPlan p = Plan();
                    bool ok = frag < p.fragments.Count && Near(p.fragments[frag].pos, V(x, 1))
                        && Near(p.fragments[frag].color, C(x, 4)) && Near(p.fragments[frag].away, V(x, 8));
                    Check(ok, $"{name} fragment {frag}: Godot {line}");
                    frag++;
                    break;
                }
                case "DUST":
                {
                    LandmarkBurstPlan p = Plan();
                    Check(Near(p.dustAt, V(x, 1)) && Near(p.dustSize, F(x[4])), $"{name}: dust {p.dustAt} {p.dustSize}, Godot {line}");
                    dust++;
                    break;
                }
                case "STEP":
                    // Godot's clock: frame steps of 1/60 summed in doubles, as _process sums them.
                    t = 0;
                    for (int k = int.Parse(x[1]); k > 0; k--) t += DT;
                    Check(Math.Abs(t - double.Parse(x[2], CultureInfo.InvariantCulture)) < 1e-8, $"{name} frame {x[1]}: clock {t}, Godot {x[2]}");
                    Check(LandmarkBurst.SprayAlive(t, tuning) == (x[3] == "1"), $"{name} frame {x[1]}: spray alive differs");
                    Check(LandmarkBurst.CloudK(t, tuning) < 1.0 == (x[4] == "1"), $"{name} frame {x[1]}: cloud alive differs");
                    break;
                case "SPRAY":
                {
                    poses++;
                    int i = int.Parse(x[1]);
                    LandmarkBurst.SprayPose(Plan().chunks[i], i, t, LandmarkBurst.Shrink(t, tuning), out N.Vector3 bx, out N.Vector3 by,
                        out N.Vector3 bz, out N.Vector3 at);
                    if (Near(bx, V(x, 2)) && Near(by, V(x, 5)) && Near(bz, V(x, 8)) && Near(at, V(x, 11))) posesOk++;
                    else if (posesOk + 3 > poses) Console.WriteLine($"  {name} t {t} chunk {i}: port {bx} {by} {bz} {at}, Godot {line}");
                    break;
                }
                case "PUFF":
                {
                    puffs++;
                    double k = LandmarkBurst.CloudK(t, tuning);
                    if (Near(LandmarkBurst.CloudScale(Plan().cloudSize, k), F(x[1])) && Near(LandmarkBurst.CloudAlpha(tuning, k), F(x[2])))
                        puffsOk++;
                    break;
                }
            }
        }
        EndSection();
        Check(sections == 6, $"golden has {sections} sections");
        Check(samplesOk == samples && samples > 0, $"sampled cells: {samplesOk} of {samples} as Godot's");
        Check(chunksOk == chunks && chunks > 0, $"thrown chunks: {chunksOk} of {chunks} as Godot's");
        Check(posesOk == poses && poses > 0, $"spray poses: {posesOk} of {poses} as Godot's");
        Check(puffsOk == puffs && puffs > 0, $"cloud puffs: {puffsOk} of {puffs} as Godot's");
        Console.WriteLine($"landmark burst: {sections} sections, {samples} samples, {chunks} chunks, {poses} poses, {puffs} puffs; "
            + $"{checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL landmark burst: " + what);
    }

    static float F(string s) => float.Parse(s, CultureInfo.InvariantCulture);
    static N.Vector3 V(string[] x, int at) => new N.Vector3(F(x[at]), F(x[at + 1]), F(x[at + 2]));
    static N.Vector4 C(string[] x, int at) => new N.Vector4(F(x[at]), F(x[at + 1]), F(x[at + 2]), F(x[at + 3]));
    static bool Near(float a, float b) => MathF.Abs(a - b) <= TOL;
    static bool Near(N.Vector3 a, N.Vector3 b) => Near(a.X, b.X) && Near(a.Y, b.Y) && Near(a.Z, b.Z);
    static bool Near(N.Vector4 a, N.Vector4 b) => Near(a.X, b.X) && Near(a.Y, b.Y) && Near(a.Z, b.Z) && Near(a.W, b.W);
}
