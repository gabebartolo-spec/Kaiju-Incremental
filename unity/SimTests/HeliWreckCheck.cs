// A downed helicopter's numbers (GameLogic/HeliWreck.cs; scenes/heli_wreck.gd _fall, _break_up, _jump, _canopy,
// _process and scenes/heli_debris.gd shards, throw, _step, _land). Against Godot's own output
// (golden/heli_wreck.txt, tools/unity/dump_heli_wreck_golden.gd): the port writes the same lines from the same
// starts and every number must agree. A fall's pose at each sampled step; every part and chunk a burst or a crash
// throws (in the heli_wreck stream's order: push, tumble, lie, fire seed, size, colour); each piece's arc, bounce,
// landing, rest, fire going out and fade, step by step; each crew member's drift and swing until they land; the
// canopy's cubes and shroud lines (present only when the golden was written with a window).
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using N = System.Numerics;
using S = Kaiju.Sim;

static class HeliWreckCheck
{
    // Godot writes 7 decimals: a draw (where a piece starts, how it is thrown) agrees to that; a pose many steps on
    // carries the float rounding of every step before it and of reading the rotation back from the basis.
    const double DRAW_TOL = 2e-5, POSE_TOL = 2e-4;
    // dump_heli_wreck_golden.gd EVERY: a pose is written every this many steps.
    const int EVERY = 6;
    const int SHOWN = 15;

    public static int Run(string repoRoot)
    {
        string[] golden = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "heli_wreck.txt"));
        S.FileAccess.Root = repoRoot;
        S.GDict cfg = S.Content.Section("heli_wreck");
        HeliTuning tuning = HeliTuning.Of(cfg);
        var rng = S.Seeds.Make("heli_wreck");
        var port = new List<string>();
        double dt = 0;
        bool canopy = false;
        for (int i = 0; i < golden.Length; i++)
        {
            string[] w = golden[i].Split(' ');
            switch (w[0])
            {
                case "RATE":
                    dt = 1.0 / int.Parse(w[1]);
                    port.Add(golden[i]);
                    break;
                case "FALL":
                    Fall(port, V(w, 1), V(w, 4), D(w[7]), dt, tuning);
                    break;
                case "BURST":
                case "CRASH":
                    bool burst = w[0] == "BURST";
                    N.Vector3 at = V(w, 1);
                    port.Add($"{w[0]} {Vs(at)} {w[4]} {w[5]}");
                    var pieces = new List<HeliPiece>();
                    HeliWreck.BreakUp(rng, tuning, burst ? 1.0 : CRASH_REACH, burst, pieces);
                    if (burst)
                        HeliWreck.Shards(rng, tuning, at, (int)S.Num.I(cfg["burst_shards"]), (int)S.Num.I(cfg["burst_burning"]), 1.0, pieces);
                    else
                        HeliWreck.Shards(rng, tuning, at + new N.Vector3(0f, CRASH_LIFT, 0f), (int)S.Num.I(cfg["crash_shards"]), CRASH_BURNING,
                            CRASH_SHARD_REACH, pieces);
                    Pieces(port, golden, i + 1, pieces, new[] { w[4], HeliWreck.CHARCOAL_RGB.ToString("x6"),
                        HeliWreck.SCORCH_RGB.ToString("x6"), w[5] }, dt, tuning);
                    break;
                case "CREW":
                    port.Add(golden[i]);
                    for (int n = 0; n < 2; n++) Chute(port, HeliWreck.Chute(n, V(w, 1), V(w, 4), tuning), dt);
                    break;
                case "CANOPY":
                    canopy = true;
                    Canopy(port, tuning);
                    break;
            }
        }
        int failed = 0, checks = 0;
        var worst = new Dictionary<string, double>();
        void Fail(string what)
        {
            if (++failed <= SHOWN) Console.WriteLine("  FAIL heli wreck: " + what);
        }
        if (port.Count != golden.Length) Fail($"the port wrote {port.Count} lines, Godot {golden.Length}");
        for (int i = 0; i < Math.Min(port.Count, golden.Length); i++)
        {
            checks++;
            string[] want = golden[i].Split(' '), got = port[i].Split(' ');
            if (want.Length != got.Length || want[0] != got[0])
            {
                Fail($"line {i + 1}: port '{port[i]}', Godot '{golden[i]}'");
                continue;
            }
            double tol = want[0] == "PIECE" || want[0] == "CHUTE" ? DRAW_TOL : POSE_TOL;
            for (int k = 1; k < want.Length; k++)
            {
                bool number = want[k].Contains('.') && got[k].Contains('.');
                if (!number)
                {
                    if (want[k] != got[k]) Fail($"line {i + 1} word {k}: port '{port[i]}', Godot '{golden[i]}'");
                    continue;
                }
                double off = Math.Abs(D(want[k]) - D(got[k]));
                worst[want[0]] = Math.Max(worst.TryGetValue(want[0], out double was) ? was : 0, off);
                if (off > tol) Fail($"line {i + 1} word {k} off by {off:G3}: port '{port[i]}', Godot '{golden[i]}'");
            }
        }
        var most = new List<string>();
        foreach (var kv in worst) most.Add($"{kv.Key} {kv.Value:G2}");
        string note = canopy ? "" : "; canopy not in the golden (written headless)";
        Console.WriteLine(failed == 0
            ? $"heli wreck: ok ({checks} lines; worst {string.Join(", ", most)}{note})"
            : $"heli wreck: {failed} differences in {checks} lines{note}");
        return failed == 0 ? 0 : 1;
    }

    // heli_wreck.gd crashed: the parts fly at 0.6 of a burst's reach and the chunks at 0.7, starting 0.8 m up, two
    // burning.
    const double CRASH_REACH = 0.6, CRASH_SHARD_REACH = 0.7;
    const float CRASH_LIFT = 0.8f;
    const int CRASH_BURNING = 2;

    static void Fall(List<string> port, N.Vector3 from, N.Vector3 drift, double seconds, double dt, in HeliTuning tuning)
    {
        port.Add($"FALL {Vs(from)} {Vs(drift)} {F(seconds)}");
        var fall = new HeliFall(from, drift, seconds);
        int steps = (int)Math.Ceiling(seconds / dt);
        for (int s = 0; s < steps; s++)
        {
            fall.Step(dt, tuning);
            if (s % EVERY == 0 || s == steps - 1)
                port.Add($"FPOSE {F(fall.t)} {Vs(fall.position)} {Vs(fall.basisX)} {Vs(fall.basisY)} {Vs(fall.basisZ)}");
        }
    }

    // The pieces' PIECE lines, then their flight until each has faded. A model part starts where Godot's model put
    // it (its PIECE line's position, rotation and scale); everything else is the port's.
    static void Pieces(List<string> port, string[] golden, int first, List<HeliPiece> pieces, string[] colours, double dt,
        in HeliTuning tuning)
    {
        var starts = new string[pieces.Count];
        for (int n = 0; n < pieces.Count; n++)
        {
            HeliPiece p = pieces[n];
            bool part = n < HeliWreck.PARTS;
            if (part && first + n < golden.Length)
            {
                string[] w = golden[first + n].Split(' ');
                if (w[0] == "PIECE" && w[^1] != "-")
                {
                    float[] start = Bits(w[^1]);
                    p.position = new N.Vector3(start[0], start[1], start[2]);
                    p.rotation = new N.Vector3(start[3], start[4], start[5]);
                    p.scale = p.size = new N.Vector3(start[6], start[7], start[8]);
                    starts[n] = w[^1];
                }
            }
            string seed = p.fire > 0f ? F(p.fireSeed) : "-1";
            string colour = p.colour < 0 ? "-" : colours[p.colour];
            port.Add($"PIECE {(part ? n : -1)} {Vs(p.position)} {Vs(p.rotation)} {Vs(p.scale)} {Vs(p.velocity)} {Vs(p.spin)} " +
                $"{F(p.half)} {F(p.lie)} {(p.flat ? 1 : 0)} {seed} {colour} {starts[n] ?? "-"}");
        }
        var live = new bool[pieces.Count];
        Array.Fill(live, true);
        for (int s = 0; s < STEPS; s++)
            for (int n = 0; n < pieces.Count; n++)
            {
                if (!live[n]) continue;
                HeliPiece p = pieces[n];
                if (!HeliWreck.Step(p, dt, tuning))
                {
                    live[n] = false;
                    port.Add($"GONE {n} {s}");
                    continue;
                }
                if (s % EVERY != 0) continue;
                GodotEuler.Columns(p.rotation, p.scale, out N.Vector3 bx, out N.Vector3 by, out N.Vector3 bz);
                port.Add($"STEP {n} {s} {Vs(p.position)} {Vs(bx)} {Vs(by)} {Vs(bz)} {(p.burning ? 1 : 0)}");
            }
    }

    // dump_heli_wreck_golden.gd STEPS: how long the pieces are followed.
    const int STEPS = 360;

    static void Chute(List<string> port, HeliChute chute, double dt)
    {
        port.Add($"CHUTE {Vs(chute.from)} {Vs(chute.to)} {F(chute.seconds)}");
        double t = 0;
        for (int s = 0; ; s++)
        {
            t += dt;
            if (!chute.Pose(t, out N.Vector3 at, out float swing))
            {
                port.Add($"LANDED {s}");
                return;
            }
            if (s % EVERY == 0) port.Add($"CPOSE {F(t)} {Vs(at)} {F(swing)}");
        }
    }

    static void Canopy(List<string> port, in HeliTuning tuning)
    {
        var cells = new List<CanopyCell>();
        HeliWreck.Canopy(tuning, cells);
        port.Add($"CANOPY {cells.Count} {Vs(new N.Vector3(0f, tuning.canopyHang, 0f))}");
        foreach (CanopyCell c in cells) port.Add($"CELL {c.x} {c.y} {c.z} {(c.dark ? 1 : 0)}");
        for (int k = 0; k < 4; k++)
        {
            HeliWreck.Line(k, tuning, out N.Vector3 from, out N.Vector3 to);
            port.Add($"LINE {Vs((from + to) * 0.5f)} {F(N.Vector3.Distance(from, to))}");
        }
    }

    static N.Vector3 V(string[] w, int at) => new N.Vector3((float)D(w[at]), (float)D(w[at + 1]), (float)D(w[at + 2]));

    // dump_heli_wreck_golden.gd _bits: little-endian floats as hex.
    static float[] Bits(string hex)
    {
        byte[] bytes = Convert.FromHexString(hex);
        var out_ = new float[bytes.Length / 4];
        for (int i = 0; i < out_.Length; i++) out_[i] = BitConverter.ToSingle(bytes, i * 4);
        return out_;
    }

    static double D(string s) => double.Parse(s, CultureInfo.InvariantCulture);

    static string F(double x) => x.ToString("F7", CultureInfo.InvariantCulture);

    static string Vs(N.Vector3 v) => $"{F(v.X)} {F(v.Y)} {F(v.Z)}";
}
