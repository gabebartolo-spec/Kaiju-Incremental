// Replays the rampages tools/unity/dump_sim_log.gd played in Godot and holds the C# sim to the same
// log on every tick (D-470 U2). Compiled twice, to prove both runtimes: unity/SimTests under dotnet,
// and this Editor-only assembly under Unity's own. Pass textDir to write each run's full text there,
// to diff against Godot's (SIM_LOG_TEXT on the Godot side).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace Kaiju.Sim
{
    public static class SimLog
    {
        const int StateEvery = 30;

        // Returns how many ticks differ, across the runs; `report` gets one line per run.
        public static int Check(
            string goldenPath,
            string repoRoot,
            Action<string> report,
            string textDir = null,
            int runs = int.MaxValue)
        {
            FileAccess.Root = repoRoot;
            GDict doc = JSON.ParseString(File.ReadAllText(goldenPath));
            double dt = Dbl(doc["dt"]);
            IGArray all = (IGArray)doc["runs"].Obj;
            int failed = 0;
            for (long i = 0; i < all.Size() && i < runs; i++)
                failed += Run(all.GetVariant(i), dt, report, textDir);
            return failed;
        }

        static int Run(GDict run, double dt, Action<string> report, string textDir)
        {
            long tier = (long)(double)run["tier"];
            long seed = (long)(double)run["seed"];
            string ability = run["ability"];
            RampageSim sim = Start(run, tier, seed, ability);
            IGArray script = (IGArray)run["script"].Obj;
            IGArray digests = (IGArray)run["digests"].Obj;
            List<string> text = new List<string>();
            Stopwatch clock = Stopwatch.StartNew();
            long ticks = digests.Size();
            long count = script.Size();
            int bad = 0, at = 0;
            long first = -1;
            using (MD5 md5 = MD5.Create())
            {
                for (long tick = 0; tick < ticks; tick++)
                {
                    while (at + 1 < count && From(script.GetVariant(at + 1)) <= tick) at++;
                    IGArray seg = (IGArray)script.GetVariant(at).Obj;
                    Vector2 move = new Vector2(Flt(seg.GetVariant(1)), Flt(seg.GetVariant(2)));
                    bool pressed = tick == From(script.GetVariant(at)) && seg.GetVariant(3);
                    long buttons = (long)(double)seg.GetVariant(4);
                    string line = Line(sim, sim.Step(dt, move, pressed, buttons), tick);
                    if (textDir != null) text.Add(line);
                    string want = digests.GetVariant(tick);
                    if (Md5(md5, line) != want)
                    {
                        bad++;
                        if (first < 0) first = tick;
                    }
                }
            }
            if (textDir != null)
                File.WriteAllText(Path.Combine(textDir, $"cs_{tier}_{seed}.txt"), string.Join("\n", text));
            report(
                $"run tier={tier} seed={seed} {ability}: {ticks - bad}/{ticks} ticks match, "
                + $"first difference {first}, chunks {sim.chunksDestroyed}, {clock.ElapsedMilliseconds} ms");
            return bad;
        }

        static RampageSim Start(GDict run, long tier, long seed, string ability)
        {
            GDict stats = UpgradeTree.RunStats(
                Content.Section("kaiju"),
                Content.SpeciesDef(run["species"]),
                new UpgradeTree(Content.Upgrades()));
            stats["hp"] = (double)stats["hp"] * Dbl(run["toughness"]);
            GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), tier, Seeds.Make("city", seed));
            RampageSim sim = new RampageSim(
                stats, CityGrowth.TuningFor(Content.Tuning(), tier), layout, Seeds.Make("army", seed));
            sim.abilityType = ability;
            sim.emerge.Start(sim);
            return sim;
        }

        static long From(Variant segment) => (long)(double)((IGArray)segment.Obj).GetVariant(0);

        static string Line(RampageSim sim, GArray<GDict> events, long tick)
        {
            List<string> parts = new List<string>
            {
                Canon(events),
                Canon(sim.kaijuPos),
                Canon(sim.facing),
                Canon(sim.standY),
                Canon(sim.hp),
                Canon(sim.timeLeft),
                Canon(sim.chunksDestroyed),
                sim._rng.state.ToString(CultureInfo.InvariantCulture),
            };
            if (tick % StateEvery == 0)
            {
                PackedInt64Array alive = new PackedInt64Array();
                foreach (RampageSim.Building b in sim.buildings)
                    alive.Append(b.frame != null ? b.frame.aliveCount : -1);
                parts.Add(Canon(alive));
                parts.Add(Canon(sim.Result()));
            }
            return string.Join(" ", parts);
        }

        // The same text form as _canon in tools/unity/dump_sim_log.gd.
        static string Canon(Variant v)
        {
            switch (v.Type)
            {
                case Gd.TYPE_NIL: return "n";
                case Gd.TYPE_BOOL: return (long)v != 0 ? "b1" : "b0";
                case Gd.TYPE_INT: return "i" + ((long)v).ToString(CultureInfo.InvariantCulture);
                case Gd.TYPE_FLOAT: return "f" + Hex((double)v);
                case Gd.TYPE_STRING: return "s" + Quote((string)v.Obj);
                case Gd.TYPE_VECTOR2: { Vector2 p = v; return $"V({Hex(p.x)},{Hex(p.y)})"; }
                case Gd.TYPE_VECTOR2I: { Vector2i p = v; return $"I({p.x},{p.y})"; }
                case Gd.TYPE_VECTOR3: { Vector3 p = v; return $"V({Hex(p.x)},{Hex(p.y)},{Hex(p.z)})"; }
                case Gd.TYPE_VECTOR3I: { Vector3i p = v; return $"I({p.x},{p.y},{p.z})"; }
                case Gd.TYPE_RECT2: { Rect2 r = v; return $"R({Canon(r.position)},{Canon(r.size)})"; }
                case Gd.TYPE_RECT2I: { Rect2i r = v; return $"R({Canon(r.position)},{Canon(r.size)})"; }
                case Gd.TYPE_AABB: { AABB r = v; return $"A({Canon(r.position)},{Canon(r.size)})"; }
                case Gd.TYPE_COLOR: { Color c = v; return $"C({Hex(c.r)},{Hex(c.g)},{Hex(c.b)},{Hex(c.a)})"; }
                case Gd.TYPE_OBJECT: return "o";
                case Gd.TYPE_DICTIONARY:
                {
                    GDict d = v;
                    List<string> items = new List<string>();
                    foreach (Variant key in d) items.Add(Canon(key) + ":" + Canon(d[key]));
                    return "{" + string.Join(",", items) + "}";
                }
            }
            if (v.Obj is IGArray a)
            {
                List<string> items = new List<string>();
                for (long i = 0; i < a.Size(); i++) items.Add(Canon(a.GetVariant(i)));
                return "[" + string.Join(",", items) + "]";
            }
            throw new InvalidOperationException($"sim log: no text form for type {v.Type}");
        }

        // JSON.stringify's escapes: only quote, backslash and control characters.
        static string Quote(string s)
        {
            StringBuilder b = new StringBuilder("\"");
            foreach (char c in s)
            {
                switch (c)
                {
                    case '"': b.Append("\\\""); break;
                    case '\\': b.Append("\\\\"); break;
                    case '\n': b.Append("\\n"); break;
                    case '\t': b.Append("\\t"); break;
                    case '\r': b.Append("\\r"); break;
                    default: b.Append(c); break;
                }
            }
            return b.Append('"').ToString();
        }

        static string Md5(MD5 md5, string line) => Lower(md5.ComputeHash(Encoding.UTF8.GetBytes(line)));
        static string Hex(double v) => Lower(BitConverter.GetBytes(v));
        static double Dbl(string hex) => BitConverter.ToDouble(Bytes(hex), 0);
        static float Flt(string hex) => BitConverter.ToSingle(Bytes(hex), 0);
        static string Lower(byte[] bytes) => BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();

        static byte[] Bytes(string hex)
        {
            byte[] bytes = new byte[hex.Length / 2];
            for (int i = 0; i < bytes.Length; i++)
                bytes[i] = byte.Parse(hex.Substring(i * 2, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
            return bytes;
        }
    }
}
