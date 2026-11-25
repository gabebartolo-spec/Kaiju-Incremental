// The body's bite (GameLogic/BodyBite.cs; scenes/body_bite.gd, BuildingView.chip) against Godot's own output
// (golden/body_bite.txt, tools/unity/dump_body_bite_golden.gd): on real building views of a stage-2 run, with Godot's
// chunk states and samples, the same bites chip the same neighbours and throw the same chipped debris, the torn
// piece falls along the same path turning the same way, lands on the same frame and bursts into the same debris.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using N = System.Numerics;
using S = Kaiju.Sim;

static class BodyBiteCheck
{
    // Godot writes 9 decimals of float32 values up to a few hundred metres.
    const float TOL = 1e-4f;
    // A state goes through Godot's R8 image (0.7 comes back 178/255).
    const float STATE_TOL = 0.005f;
    // The dump steps the piece's tween 1/60 s at a time.
    const double STEP = 1.0 / 60.0;
    static int failed, checks;

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
        // A chunk the golden left out is on a floor the bite cannot reach: standing.
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
        string[] golden = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "body_bite.txt"));
        double gravity = S.Num.F(S.Content.Section("city")["fall_gravity"]);
        string name = "";
        S.RandomNumberGenerator rng = null;
        GoldenSite site = null;
        BodyBiteTear tear = null;
        List<BurstPart> piece = null;
        List<BurstFragment> expect = new List<BurstFragment>();
        int next = 0;
        bool ended = false;
        S.Vector3i lastParts = default;
        int frags = 0, fragsOk = 0, poses = 0, posesOk = 0, states = 0, statesOk = 0, cases = 0;

        // Every piece the port threw for the call before was in Godot's lines too.
        void Settle()
        {
            Check(next == expect.Count, $"{name}: the port threw {expect.Count} pieces, Godot {next}");
            expect.Clear();
            next = 0;
        }
        foreach (string line in golden)
        {
            string[] x = line.Split(' ');
            switch (x[0])
            {
                case "TUNING":
                    Check(Math.Abs(gravity - D(x[2])) < 1e-9, $"fall_gravity read as Godot's: {line}");
                    break;
                case "CASE":
                    Settle();
                    cases++;
                    name = x[1];
                    rng = new S.RandomNumberGenerator { seed = long.Parse(x[2]) };
                    site = new GoldenSite();
                    piece = null;
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
                    // The bite's own cells are the piece's (the view hides them); the port's chip leaves them be.
                    float port = tear != null && Bit(c) ? 0f : site.State(c);
                    if (MathF.Abs(port - F(x[4])) <= STATE_TOL) statesOk++;
                    else Console.WriteLine($"  {name} chunk {c.x} {c.y} {c.z}: port {port}, Godot {x[4]}");
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
                    if (piece != null) piece.Add(new BurstPart { pos = V(x, 1), color = C(x, 4) });
                    else site.parts[lastParts].Add(new BurstPart { pos = V(x, 1), color = C(x, 4) });
                    break;
                case "BITE":
                {
                    Settle();
                    int n = int.Parse(x[4]);
                    bite.Clear();
                    for (int k = 0; k < n; k++)
                        bite.Add(new S.Vector3i(long.Parse(x[5 + 3 * k]), long.Parse(x[6 + 3 * k]), long.Parse(x[7 + 3 * k])));
                    tear = BodyBite.Tear(site, bite, V(x, 1), gravity, rng);
                    expect.AddRange(tear.chipped);
                    break;
                }
                case "PIECE":
                    Settle();
                    piece = new List<BurstPart>();
                    break;
                case "POSE":
                {
                    poses++;
                    double t = D(x[1]);
                    N.Vector3 at = BodyBite.Position(tear, t), turn = BodyBite.Rotation(tear, t);
                    bool ok = !BodyBite.Landed(tear, t) && Near(at, V(x, 2)) && Near(turn, V(x, 5));
                    if (ok) posesOk++;
                    else if (posesOk + 3 > poses)
                        Console.WriteLine($"  {name} pose at {x[1]}: port {Vec(at)} {Vec(turn)}, Godot {line}");
                    break;
                }
                case "LAND":
                {
                    double t = D(x[1]);
                    Check(BodyBite.Landed(tear, t) && !BodyBite.Landed(tear, t - STEP),
                        $"{name}: the piece lands on Godot's frame ({x[1]} s; port falls {tear.seconds} s)");
                    Check(piece.Count > 0, $"{name}: the piece has samples");
                    expect.AddRange(BodyBite.Landing(tear, piece));
                    break;
                }
                case "FRAG":
                {
                    frags++;
                    if (next < expect.Count && SameFrag(expect[next], x)) fragsOk++;
                    else if (fragsOk + 3 > frags)
                        Console.WriteLine($"  {name} piece {frags}: port {(next < expect.Count ? Frag(expect[next]) : "none")}, Godot {line}");
                    next++;
                    break;
                }
                case "END":
                    Settle();
                    ended = true;
                    break;
            }
        }
        Settle();
        Check(cases == 3, $"three cases in the golden ({cases})");
        Check(frags > 0 && fragsOk == frags, $"debris: {fragsOk}/{frags} as Godot threw it");
        Check(poses > 0 && posesOk == poses, $"fall: {posesOk}/{poses} poses as Godot's");
        Check(states > 0 && statesOk == states, $"chunk states after: {statesOk}/{states} as Godot's");

        // A ground-floor bite still falls MIN_DROP's time.
        var low = new GoldenSite { w = 1, d = 1, height = 1, landmark = true };
        BodyBiteTear lowTear = BodyBite.Tear(low, new List<S.Vector3i> { new S.Vector3i(0, 0, 0) },
            new N.Vector3(-3f, 0f, 0f), 30.0, new S.RandomNumberGenerator { seed = 7 });
        Check(Math.Abs(lowTear.seconds - Math.Sqrt(2.0 * 0.5 / 30.0)) < 1e-9 && lowTear.away == N.Vector3.UnitX,
            $"a ground-floor bite falls from its own height away from the kaiju ({lowTear.seconds} s)");
        // The kaiju right over a bite's middle: no way out, the piece drops straight down.
        BodyBiteTear under = BodyBite.Tear(low, new List<S.Vector3i> { new S.Vector3i(0, 0, 0) },
            N.Vector3.Zero, 30.0, new S.RandomNumberGenerator { seed = 7 });
        Check(under.away == N.Vector3.Zero && under.land == new N.Vector3(0f, BodyBite.MIN_DROP * 0.5f, 0f),
            $"a bite under the kaiju drops straight down ({Vec(under.land)})");

        Console.WriteLine($"body bite: {cases} cases, {frags} pieces, {poses} poses, {states} states; {checks} checks, {failed} failed");
        return failed;
    }

    static readonly List<S.Vector3i> bite = new List<S.Vector3i>();

    static bool Bit(S.Vector3i c)
    {
        foreach (S.Vector3i b in bite)
            if (b.x == c.x && b.y == c.y && b.z == c.z) return true;
        return false;
    }

    static bool SameFrag(BurstFragment f, string[] x) =>
        Near(f.pos, V(x, 1)) && Near(f.color, C(x, 4)) && Near(f.away, V(x, 8));

    static string Frag(BurstFragment f) => $"{Vec(f.pos)} {f.color} {Vec(f.away)}";

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL BodyBiteCheck: " + what);
    }

    static bool Near(N.Vector3 a, N.Vector3 b) => N.Vector3.Distance(a, b) <= TOL;
    static bool Near(N.Vector4 a, N.Vector4 b) => N.Vector4.Distance(a, b) <= TOL;
    static float F(string s) => float.Parse(s, CultureInfo.InvariantCulture);
    static double D(string s) => double.Parse(s, CultureInfo.InvariantCulture);
    static N.Vector3 V(string[] x, int i) => new N.Vector3(F(x[i]), F(x[i + 1]), F(x[i + 2]));
    static N.Vector4 C(string[] x, int i) => new N.Vector4(F(x[i]), F(x[i + 1]), F(x[i + 2]), F(x[i + 3]));
    static string Vec(N.Vector3 v) => string.Format(CultureInfo.InvariantCulture, "{0:F6} {1:F6} {2:F6}", v.X, v.Y, v.Z);
}
