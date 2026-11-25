// A blast's break (GameLogic/BlastBreak.cs; scenes/blast_break.gd, BuildingView.chip, scenes/blast_fx.gd _throw)
// against Godot's own output (golden/blast_break.txt, tools/unity/dump_blast_break_golden.gd): on real building
// views of a stage-2 run, with Godot's chunk states and samples, the same blasts take the same chunks (or don't: a
// far blast, a shut window), break them top floor first in the same steps, bite the same neighbours, throw the same
// debris from the same places the same way in the same colours and puff the same dust; and each kind of site throws
// the same skin.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using N = System.Numerics;
using S = Kaiju.Sim;

static class BlastBreakCheck
{
    // Godot writes 9 decimals of float32 values up to a few hundred metres.
    const float TOL = 1e-4f;
    // A state goes through Godot's R8 image (0.7 comes back 178/255).
    const float STATE_TOL = 0.005f;
    static int failed, checks;

    // One building as the golden wrote it down.
    sealed class GoldenSite : IBlastSite
    {
        public double x, z;
        public long w, d, height, ground;
        public bool landmark;
        public readonly Dictionary<S.Vector3i, float> states = new Dictionary<S.Vector3i, float>();
        public readonly Dictionary<S.Vector3i, List<BurstPart>> parts = new Dictionary<S.Vector3i, List<BurstPart>>();

        public bool Valid => true;
        public long W => w;
        public long D => d;
        public long Height => height;
        public bool Landmark => landmark;
        // A chunk the golden left out is on a floor no case touches: standing.
        public float State(S.Vector3i c) => states.TryGetValue(c, out float s) ? s : 1f;
        public void SetState(S.Vector3i c, float s) => states[c] = s;
        public List<BurstPart> Parts(S.Vector3i c) =>
            parts.TryGetValue(c, out List<BurstPart> list) ? list : throw new InvalidOperationException($"no parts for {c.x} {c.y} {c.z}");
        // RampageSim.Building.chunk_world.
        public N.Vector3 ChunkWorld(S.Vector3i c) => new N.Vector3(
            (float)(x - w * 0.5 + c.x + 0.5), (float)(c.y + 0.5 + ground), (float)(z - d * 0.5 + c.z + 0.5));
    }

    public static int Run(string repoRoot)
    {
        S.FileAccess.Root = repoRoot;
        failed = 0;
        checks = 0;
        string[] golden = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "blast_break.txt"));
        BlastBreakTuning tuning = BlastBreakTuning.From(S.Content.Section("blast_fx"));
        string name = "";
        BlastBreak bb = null;
        GoldenSite site = null;
        bool ended = false;
        var cases = new List<string>();
        // What the port made for the last call, in the dump's order (every step's debris, then every step's dust).
        var made = new List<string[]>();
        int next = 0;
        S.Vector3i lastParts = default;
        int frags = 0, fragsOk = 0, dusts = 0, dustsOk = 0, states = 0, statesOk = 0, throws = 0;
        string throwKind = "";
        long throwSeed = 0;
        N.Vector3 throwCentre = default, throwHalf = default;
        int throwColours = 0;
        var colours = new List<N.Vector4>();

        // Steps the port made for a call (the caller settled the call before).
        void Made(List<BlastBreakShot> shots)
        {
            foreach (BlastBreakShot shot in shots)
                foreach (BurstFragment f in shot.debris) made.Add(new[] { "FRAG", Vec(f.pos), Col(f.color), Vec(f.away) });
            foreach (BlastBreakShot shot in shots)
                if (shot.dust) made.Add(new[] { "DUST", Vec(shot.dustAt), R(shot.dustSize) });
        }
        // Everything the port made for the call before was in Godot's lines too.
        void Settle()
        {
            Check(next == made.Count, $"{name}: the port made {made.Count} pieces and puffs, Godot {next}");
            made.Clear();
            next = 0;
        }
        foreach (string line in golden)
        {
            string[] x = line.Split(' ');
            switch (x[0])
            {
                case "TUNING":
                    Check(tuning.slices == int.Parse(x[2]) && tuning.windowFrames == int.Parse(x[4])
                        && tuning.perChunk == int.Parse(x[6]) && Near(tuning.push, F(x[8])) && Near(tuning.up, F(x[10]))
                        && tuning.debris == int.Parse(x[12]), $"tuning read as Godot's: {line}");
                    break;
                case "CASE":
                    Settle();
                    name = x[1];
                    cases.Add(name);
                    var rng = new S.RandomNumberGenerator { seed = long.Parse(x[2]) };
                    bb = new BlastBreak(tuning, rng);
                    site = new GoldenSite();
                    ended = false;
                    break;
                case "SITE":
                    site.x = D(x[2]);
                    site.z = D(x[3]);
                    site.ground = long.Parse(x[4]);
                    site.w = long.Parse(x[5]);
                    site.d = long.Parse(x[6]);
                    site.height = long.Parse(x[7]);
                    site.landmark = x[8] == "1";
                    break;
                case "STATE":
                {
                    var c = new S.Vector3i(long.Parse(x[1]), long.Parse(x[2]), long.Parse(x[3]));
                    if (!ended)
                    {
                        site.states[c] = F(x[4]);
                        break;
                    }
                    states++;
                    if (MathF.Abs(site.State(c) - F(x[4])) <= STATE_TOL) statesOk++;
                    else Console.WriteLine($"  {name} chunk {c.x} {c.y} {c.z}: port {site.State(c)}, Godot {x[4]}");
                    break;
                }
                case "PARTS":
                {
                    var c = new S.Vector3i(long.Parse(x[1]), long.Parse(x[2]), long.Parse(x[3]));
                    site.parts[c] = new List<BurstPart>();
                    lastParts = c;
                    break;
                }
                case "PART":
                    site.parts[lastParts].Add(new BurstPart { pos = V(x, 1), color = C(x, 4) });
                    break;
                case "BLEW":
                    Settle();
                    bb.Blew(V(x, 1), D(x[4]));
                    break;
                case "TAKES":
                {
                    Settle();
                    int n = int.Parse(x[3]);
                    var cells = new List<S.Vector3i>();
                    for (int k = 0; k < n; k++)
                        cells.Add(new S.Vector3i(long.Parse(x[4 + 3 * k]), long.Parse(x[5 + 3 * k]), long.Parse(x[6 + 3 * k])));
                    var shots = new List<BlastBreakShot>();
                    bool took = bb.Takes(D(x[1]), D(x[2]), cells, site, shots);
                    made.Add(new[] { "TOOK", took ? "1" : "0" });
                    Made(shots);
                    break;
                }
                case "TOOK":
                    Check(next < made.Count && made[next][0] == "TOOK" && made[next][1] == x[1],
                        $"{name}: Godot's blast took the chunks: {x[1]}");
                    next++;
                    break;
                case "PROCESS":
                {
                    Settle();
                    var shots = new List<BlastBreakShot>();
                    bb.Process(shots);
                    Made(shots);
                    break;
                }
                case "FRAG":
                {
                    if (throwColours > 0 && colours.Count == throwColours && made.Count == 0) MakeThrow();
                    frags++;
                    if (next < made.Count && made[next][0] == "FRAG" && SameFrag(made[next], x)) fragsOk++;
                    else if (fragsOk + 3 > frags)
                        Console.WriteLine($"  {name} piece {frags}: port {(next < made.Count ? string.Join(" ", made[next]) : "none")}, Godot {line}");
                    next++;
                    break;
                }
                case "DUST":
                    dusts++;
                    if (next < made.Count && made[next][0] == "DUST" && NearDust(made[next], x)) dustsOk++;
                    else Console.WriteLine($"  {name} dust: port {(next < made.Count ? string.Join(" ", made[next]) : "none")}, Godot {line}");
                    next++;
                    break;
                case "END":
                    Settle();
                    ended = true;
                    break;
                case "THROW":
                    Settle();
                    throws++;
                    name = "throw " + x[1];
                    throwKind = x[1];
                    throwSeed = long.Parse(x[2]);
                    throwCentre = V(x, 3);
                    throwHalf = V(x, 6);
                    throwColours = int.Parse(x[9]);
                    colours.Clear();
                    break;
                case "COLOUR":
                    colours.Add(C(x, 1));
                    break;
            }
        }
        Settle();
        void MakeThrow()
        {
            var rng = new S.RandomNumberGenerator { seed = throwSeed };
            foreach (BurstFragment f in BlastBreak.Throw(throwCentre, throwHalf, colours, tuning, rng))
                made.Add(new[] { "FRAG", Vec(f.pos), Col(f.color), Vec(f.away) });
            Check(made.Count == tuning.debris, $"{throwKind}: the port threw {made.Count} pieces");
        }

        // The port's own samples of a chunk (Unity has no chunk mesher): up to twelve of its voxels, evenly along it.
        var run = new List<int>();
        for (int i = 0; i < 30; i++) run.Add(100 + i * 3);
        List<BurstPart> twelve = BlastBreak.ChunkSamples(run, 8, 4, new N.Vector3(1f, 2f, 3f), 0.125f, i => new N.Vector4(i));
        Check(twelve.Count == BlastBreak.SAMPLES && twelve[0].color.X == 100f && twelve[1].color.X == 106f
            && twelve[11].color.X == 100f + 27 * 3, "a big chunk gives twelve samples spread along its voxels");
        // Voxel 100 of an 8 x 4 plan: x 4, y 3, z 0.
        Check(Near(twelve[0].pos, new N.Vector3(1f + 4 * 0.125f, 2f + 3 * 0.125f, 3f)), $"sample 0 at {twelve[0].pos}");
        Check(BlastBreak.ChunkSamples(run.GetRange(0, 5), 8, 4, N.Vector3.Zero, 0.125f, i => N.Vector4.One).Count == 5,
            "a chunk of five voxels gives five samples");
        Check(string.Join(",", cases) == "blast,two,expired,landmark", $"golden has cases {string.Join(",", cases)}");
        Check(throws == 3, $"golden has {throws} throws");
        Check(fragsOk == frags && frags > 0, $"debris: {fragsOk} of {frags} as Godot's");
        Check(dustsOk == dusts && dusts > 0, $"dust: {dustsOk} of {dusts} as Godot's");
        Check(statesOk == states && states > 0, $"chunk states after: {statesOk} of {states} as Godot's");
        Console.WriteLine($"blast break: {cases.Count} cases, {throws} throws, {frags} pieces, {dusts} dust puffs, {states} states; "
            + $"{checks} checks, {failed} failed");
        return failed;
    }

    static bool SameFrag(string[] port, string[] x)
    {
        N.Vector3 pos = ParseVec(port[1]), away = ParseVec(port[3]);
        N.Vector4 col = ParseCol(port[2]);
        return Near(pos, V(x, 1)) && Near(col, C(x, 4)) && Near(away, V(x, 8));
    }

    static bool NearDust(string[] port, string[] x) =>
        Near(ParseVec(port[1]), V(x, 1)) && Near(float.Parse(port[2], CultureInfo.InvariantCulture), F(x[4]));

    static string Vec(N.Vector3 v) => string.Join(" ", R(v.X), R(v.Y), R(v.Z));
    static string Col(N.Vector4 c) => string.Join(" ", R(c.X), R(c.Y), R(c.Z), R(c.W));
    static string R(float f) => f.ToString("R", CultureInfo.InvariantCulture);
    static N.Vector3 ParseVec(string s) { string[] p = s.Split(' '); return V(p, 0); }
    static N.Vector4 ParseCol(string s) { string[] p = s.Split(' '); return C(p, 0); }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL blast break: " + what);
    }

    static float F(string s) => float.Parse(s, CultureInfo.InvariantCulture);
    static double D(string s) => double.Parse(s, CultureInfo.InvariantCulture);
    static N.Vector3 V(string[] x, int at) => new N.Vector3(F(x[at]), F(x[at + 1]), F(x[at + 2]));
    static N.Vector4 C(string[] x, int at) => new N.Vector4(F(x[at]), F(x[at + 1]), F(x[at + 2]), F(x[at + 3]));
    static bool Near(float a, float b) => MathF.Abs(a - b) <= TOL;
    static bool Near(N.Vector3 a, N.Vector3 b) => Near(a.X, b.X) && Near(a.Y, b.Y) && Near(a.Z, b.Z);
    static bool Near(N.Vector4 a, N.Vector4 b) => Near(a.X, b.X) && Near(a.Y, b.Y) && Near(a.Z, b.Z) && Near(a.W, b.W);
}
