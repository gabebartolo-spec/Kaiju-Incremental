// The kaiju's hide (GameLogic/KaijuHide.cs; scenes/kaiju_hide.gd, scenes/city_falls.gd _shatter) against Godot's own
// output (golden/kaiju_hide.txt, tools/unity/dump_kaiju_hide_golden.gd): posed young and grown, ashore, mid-rise and
// on a roof, the port's hide is Godot's capsule and collision shape and moves the same points clear of him; and a
// falling part that reached him or a neighbour breaks up into the same fragments, picked in the same order, thrown
// the same way from the same places outside his hide.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using N = System.Numerics;
using S = Kaiju.Sim;

static class KaijuHideCheck
{
    // Godot writes 9 decimals of float32 values up to a few hundred metres.
    const float TOL = 1e-4f;
    // The dump's stage (its stats' size).
    const double STAGE = 2.0;
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        S.FileAccess.Root = repoRoot;
        failed = 0;
        checks = 0;
        string[] golden = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "kaiju_hide.txt"));
        S.GDict stats = S.UpgradeTree.RunStats(S.Content.Section("kaiju"), S.Content.SpeciesDef("reptilian"),
            new S.UpgradeTree(S.Content.Upgrades()));
        stats["size"] = STAGE;
        var sim = new S.RampageSim(stats, S.CityGrowth.ForStats(stats), new S.GArray<S.GDict>(), S.Seeds.Make("army", 0));
        S.GDict cfg = S.Content.Section("fall_contact");
        float margin = (float)S.Num.F(cfg["fragment_margin"]);
        HideCapsule cap = default;
        string name = "";
        S.RandomNumberGenerator rng = null;
        bool onKaiju = false;
        PieceXf xf = default;
        N.Vector3 pivot = N.Vector3.Zero;
        var parts = new List<BurstPart>();
        int partsDue = 0;
        HideShatter shatter = null;
        int next = 0;
        int poses = 0, posesOk = 0, outs = 0, outsOk = 0, frags = 0, fragsOk = 0, shatters = 0;

        // Every fragment the port threw for the break-up before was in Godot's lines too.
        void Settle()
        {
            if (shatter == null) return;
            Check(next == shatter.fragments.Count, $"{name}: the port threw {shatter.fragments.Count} fragments, Godot {next}");
            shatter = null;
            next = 0;
        }
        foreach (string line in golden)
        {
            string[] x = line.Split(' ');
            switch (x[0])
            {
                case "TUNING":
                    Check(MathF.Abs((float)S.Num.F(cfg["hide_radius"]) - F(x[1])) < 1e-9f
                        && MathF.Abs((float)S.Num.F(cfg["hide_height"]) - F(x[2])) < 1e-9f
                        && MathF.Abs(margin - F(x[3])) < 1e-9f
                        && MathF.Abs((float)S.Num.F(sim.powersCfg["body_radius"]) - F(x[4])) < 1e-9f,
                        $"fall_contact and body_radius read as Godot's: {line}");
                    break;
                case "POSE":
                    Settle();
                    sim.stats["size"] = D(x[1]);
                    sim.stats["growth"] = D(x[2]);
                    sim.kaijuPos = new S.Vector2(D(x[3]), D(x[4]));
                    sim.standY = D(x[5]);
                    cap = KaijuHide.Of(S.FallContact.Hide(sim, cfg));
                    break;
                case "CAP":
                {
                    poses++;
                    bool ok = Math.Abs(sim.BodyScale() - D(x[1])) < 1e-6 && Math.Abs(sim.ReachHeight() - D(x[2])) < 1e-5
                        && Near(cap.foot, V(x, 3)) && Near(cap.head, V(x, 6)) && MathF.Abs(cap.radius - F(x[9])) <= TOL;
                    if (ok) posesOk++;
                    else Console.WriteLine($"  capsule: port {sim.BodyScale()} {sim.ReachHeight()} {Vec(cap.foot)} {Vec(cap.head)} {cap.radius}, Godot {line}");
                    break;
                }
                case "SHAPE":
                    Check(MathF.Abs(cap.radius - F(x[1])) <= TOL && MathF.Abs(KaijuHide.Height(cap) - F(x[2])) <= TOL
                        && Near(KaijuHide.Centre(cap), V(x, 3)),
                        $"collision capsule: port {cap.radius} {KaijuHide.Height(cap)} {Vec(KaijuHide.Centre(cap))}, Godot {line}");
                    break;
                case "OUT":
                {
                    outs++;
                    N.Vector3 port = KaijuHide.Outside(V(x, 1), cap, margin);
                    if (Near(port, V(x, 4))) outsOk++;
                    else Console.WriteLine($"  keep-out: port {Vec(port)}, Godot {line}");
                    break;
                }
                case "SHATTER":
                    Settle();
                    shatters++;
                    name = x[1];
                    rng = new S.RandomNumberGenerator { seed = long.Parse(x[2]) };
                    onKaiju = x[3] == "kaiju";
                    break;
                case "XF":
                    xf = new PieceXf { x = V(x, 1), y = V(x, 4), z = V(x, 7), origin = V(x, 10) };
                    break;
                case "PIVOT":
                    pivot = V(x, 1);
                    break;
                case "PARTS":
                    parts.Clear();
                    partsDue = int.Parse(x[1]);
                    break;
                case "PART":
                    parts.Add(new BurstPart { pos = V(x, 1), color = C(x, 4) });
                    if (parts.Count == partsDue)
                        shatter = KaijuHide.Shatter(parts, xf, pivot, onKaiju,
                            new N.Vector2((float)sim.kaijuPos.x, (float)sim.kaijuPos.y), cap, margin, rng);
                    break;
                case "FRAG":
                {
                    frags++;
                    bool ok = shatter != null && next < shatter.fragments.Count && SameFrag(shatter.fragments[next], x);
                    if (ok) fragsOk++;
                    else if (fragsOk + 3 > frags)
                        Console.WriteLine($"  {name} fragment {next}: port {(shatter != null && next < shatter.fragments.Count ? Frag(shatter.fragments[next]) : "none")}, Godot {line}");
                    if (shatter != null && next == 0)
                        Check(shatter.hasDust && Near(shatter.dust, V(x, 1)), $"{name}: the dust goes where the first fragment flies");
                    next++;
                    break;
                }
            }
        }
        Settle();
        Check(poses == 9 && posesOk == poses, $"capsule: {posesOk}/{poses} poses as Godot's");
        Check(outs > 0 && outsOk == outs, $"keep-out: {outsOk}/{outs} points moved as Godot's");
        Check(shatters == 4, $"four break-ups in the golden ({shatters})");
        Check(frags > 0 && fragsOk == frags, $"break-up: {fragsOk}/{frags} fragments as Godot threw them");

        // No hide (none yet): the fragments start where the part is.
        var one = new List<BurstPart> { new BurstPart { pos = new N.Vector3(1f, 2f, 3f), color = N.Vector4.One } };
        var still = new PieceXf { x = N.Vector3.UnitX, y = N.Vector3.UnitY, z = N.Vector3.UnitZ };
        HideShatter bare = KaijuHide.Shatter(one, still, N.Vector3.Zero, true, new N.Vector2(1f, 3f), null, margin,
            new S.RandomNumberGenerator { seed = 1 });
        Check(bare.fragments.Count == 1 && bare.fragments[0].pos == new N.Vector3(1f, 2f, 3f)
            && bare.fragments[0].away == new N.Vector3(1f, 0.3f, 0f),
            $"a part right over his axis goes off along +x, from where it is ({Vec(bare.fragments[0].away)})");
        // A part with no samples throws nothing and raises no dust.
        HideShatter none = KaijuHide.Shatter(new List<BurstPart>(), still, N.Vector3.Zero, true, N.Vector2.Zero, cap,
            margin, new S.RandomNumberGenerator { seed = 1 });
        Check(none.fragments.Count == 0 && !none.hasDust, "an empty part throws nothing");

        Console.WriteLine($"kaiju hide: {poses} poses, {outs} points, {shatters} break-ups, {frags} fragments; {checks} checks, {failed} failed");
        return failed;
    }

    static bool SameFrag(BurstFragment f, string[] x) =>
        Near(f.pos, V(x, 1)) && Near(f.color, C(x, 4)) && Near(f.away, V(x, 8));

    static string Frag(BurstFragment f) => $"{Vec(f.pos)} {f.color} {Vec(f.away)}";

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL KaijuHideCheck: " + what);
    }

    static bool Near(N.Vector3 a, N.Vector3 b) => N.Vector3.Distance(a, b) <= TOL;
    static bool Near(N.Vector4 a, N.Vector4 b) => N.Vector4.Distance(a, b) <= TOL;
    static float F(string s) => float.Parse(s, CultureInfo.InvariantCulture);
    static double D(string s) => double.Parse(s, CultureInfo.InvariantCulture);
    static N.Vector3 V(string[] x, int i) => new N.Vector3(F(x[i]), F(x[i + 1]), F(x[i + 2]));
    static N.Vector4 C(string[] x, int i) => new N.Vector4(F(x[i]), F(x[i + 1]), F(x[i + 2]), F(x[i + 3]));
    static string Vec(N.Vector3 v) => string.Format(CultureInfo.InvariantCulture, "{0:F6} {1:F6} {2:F6}", v.X, v.Y, v.Z);
}
