// The pause menu's bug / feedback report (scenes/feedback_report.gd, D-145): what to write and where. A report is a
// folder <user dir>/<folder>/<timestamp>/ (tuning "feedback") holding report.txt (the game version, what the player
// typed and the facts a bug needs) and screenshot.png (the rampage as it stood). It is a file on the player's disk and
// nothing else: no network call of any kind. Plain C#: the view (Game/Screens/FeedbackPanel.cs) grabs the picture and
// the machine's facts and hands them here as plain values.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // What Write did: the folder's absolute path when it saved, else the error.
    public sealed class FeedbackResult
    {
        public bool ok;
        public string path = "", error = "";
    }

    public static class FeedbackReport
    {
        public const string TEXT_FILE = "report.txt";
        public const string SHOT_FILE = "screenshot.png";
        // Godot's version lives in project.godot ([application] config/version); the build copies the file beside the
        // data (res root). Without it the version reads as Godot's own fallback.
        public const string PROJECT_FILE = "res://project.godot";
        const string VERSION_SECTION = "application";
        const string VERSION_KEY = "config/version";
        const string NO_VERSION = "unversioned";
        // A headless run has no picture: a black placeholder this size (feedback_report.gd SHOT_PLACEHOLDER).
        public const int PLACEHOLDER_W = 64, PLACEHOLDER_H = 36;
        public const string PLACEHOLDER_NOTE_KEY = "Screenshot note";
        public const string PLACEHOLDER_NOTE = "no renderer, so screenshot.png is a black placeholder";
        public const string WRITTEN_HEAD = "--- What the player wrote ---";
        public const string NOTHING_TYPED = "(nothing)";
        // The labels report.txt carries, in order (tests/lib/ui_feedback.gd FACTS).
        public static readonly string[] FACT_LABELS =
            { "Species", "City", "Growth step", "Run time", "OS", "GPU", "Graphics preset", "Resolution" };
        public static readonly byte[] PNG_SIGNATURE = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

        // tuning "feedback": the folder, the game's name and the panel's words and sizes.
        public static S.GDict Cfg() => S.Content.Section("feedback");

        // The game's version line: "Kaiju Evolution 0.1-demo".
        public static string Version()
        {
            string text = S.FileAccess.FileExists(PROJECT_FILE) ? S.FileAccess.GetFileAsString(PROJECT_FILE) : "";
            return S.Gd.Str(Cfg()["game"]) + " " + ProjectVersion(text);
        }

        // config/version under [application] in a project.godot's text; "unversioned" when it has none.
        public static string ProjectVersion(string projectText)
        {
            string section = "";
            foreach (string raw in (projectText ?? "").Split('\n'))
            {
                string line = raw.Trim();
                if (line.StartsWith("[", StringComparison.Ordinal) && line.EndsWith("]", StringComparison.Ordinal))
                {
                    section = line.Substring(1, line.Length - 2);
                    continue;
                }
                if (section != VERSION_SECTION || !line.StartsWith(VERSION_KEY + "=", StringComparison.Ordinal)) continue;
                string value = line.Substring(VERSION_KEY.Length + 1).Trim();
                if (value.Length >= 2 && value[0] == '"' && value[value.Length - 1] == '"') value = value.Substring(1, value.Length - 2);
                return value;
            }
            return NO_VERSION;
        }

        // The facts report.txt carries, in order, as label -> value (feedback_report.gd facts). The machine's facts
        // (os, gpu, window and canvas size) come from the view; the graphics level and its render scale from the
        // player's settings.
        public static List<KeyValuePair<string, string>> Facts(S.RampageSim sim, string speciesId, string os, string gpu,
            int windowW, int windowH, int canvasW, int canvasH)
        {
            long tier = sim.SizeTier();
            string level = PlayerSettings.GraphicsLevel();
            double renderScale = S.Num.F(PlayerSettings.GraphicsRow()["scale"]);
            return FactsOf(speciesId, tier, S.Num.I(sim.city["map_seed"]), sim.Stat("run_seconds"), sim.timeLeft, os, gpu,
                level, renderScale, windowW, windowH, canvasW, canvasH);
        }

        // The same from plain values, Godot's formatting.
        public static List<KeyValuePair<string, string>> FactsOf(string speciesId, long tier, long mapSeed, double runSeconds,
            double timeLeft, string os, string gpu, string level, double renderScale, int windowW, int windowH, int canvasW, int canvasH)
        {
            var out_ = new List<KeyValuePair<string, string>>();
            void Add(string k, string v) => out_.Add(new KeyValuePair<string, string>(k, v));
            Add("Species", speciesId);
            Add("City", $"stage {tier}, map seed {mapSeed}");
            Add("Growth step", $"{TreeText.StageFor(tier)} (size tier {tier})");
            Add("Run time", RunTime(runSeconds, timeLeft));
            Add("OS", os);
            Add("GPU", gpu);
            Add("Graphics preset", $"{level} (render scale {S.Gd.Str(renderScale)})");
            Add("Resolution", $"window {windowW}x{windowH}, canvas {canvasW}x{canvasH}");
            return out_;
        }

        // "1:05 (85 s left)": the time played so far and the clock left (feedback_report.gd _run_time).
        public static string RunTime(double runSeconds, double timeLeft)
        {
            double seconds = Math.Max(0.0, runSeconds - timeLeft);
            long whole = (long)seconds;
            return string.Format(CultureInfo.InvariantCulture, "{0}:{1:00} ({2} s left)", whole / 60, whole % 60, (long)timeLeft);
        }

        // report.txt: the version first, then the stamp, the facts, the picture's name and what the player typed.
        public static string Compose(string typed, IList<KeyValuePair<string, string>> details, string stamp)
        {
            var lines = new List<string> { "Version: " + Version(), "Reported: " + stamp };
            foreach (KeyValuePair<string, string> kv in details) lines.Add(kv.Key + ": " + kv.Value);
            lines.Add("Screenshot: " + SHOT_FILE);
            lines.Add("");
            lines.Add(WRITTEN_HEAD);
            string said = (typed ?? "").Trim();
            lines.Add(said.Length > 0 ? said : NOTHING_TYPED);
            return string.Join("\n", lines) + "\n";
        }

        // Writes the report folder under UserDir. `png` null or empty (no picture) saves a small black placeholder and
        // says so in the text. Two reports in one second get two folders (name, name_2, name_3 ...).
        public static FeedbackResult Write(string typed, IList<KeyValuePair<string, string>> details, byte[] png, string stamp)
        {
            var result = new FeedbackResult();
            try
            {
                string root = UserDir.Path(S.Gd.Str(Cfg()["folder"]));
                string folder = FreeFolder(root, FolderName(stamp));
                Directory.CreateDirectory(folder);
                var note = new List<KeyValuePair<string, string>>(details);
                if (png == null || png.Length == 0)
                {
                    png = BlackPng(PLACEHOLDER_W, PLACEHOLDER_H);
                    note.Add(new KeyValuePair<string, string>(PLACEHOLDER_NOTE_KEY, PLACEHOLDER_NOTE));
                }
                File.WriteAllBytes(Path.Combine(folder, SHOT_FILE), png);
                File.WriteAllText(Path.Combine(folder, TEXT_FILE), Compose(typed, note, stamp), new UTF8Encoding(false));
                result.ok = true;
                result.path = Path.GetFullPath(folder);
            }
            catch (Exception e) when (e is IOException || e is UnauthorizedAccessException || e is ArgumentException || e is NotSupportedException)
            {
                result.ok = false;
                result.error = e.Message;
            }
            return result;
        }

        // A stamp's folder name: 2026-10-23T14:05:33 -> 2026-10-23_14-05-33.
        public static string FolderName(string stamp) => stamp.Replace(":", "-").Replace("T", "_");

        // The local date and time as 2026-10-23T14:05:33 (Time.get_datetime_string_from_system).
        public static string Stamp(DateTime at) => at.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture);

        public static string StampNow() => Stamp(DateTime.Now);

        static string FreeFolder(string root, string name)
        {
            string folder = Path.Combine(root, name);
            int n = 2;
            while (Directory.Exists(folder))
            {
                folder = Path.Combine(root, name + "_" + n.ToString(CultureInfo.InvariantCulture));
                n++;
            }
            return folder;
        }

        // A black RGB picture as PNG bytes: one stored (uncompressed) deflate block, so no image library is needed.
        public static byte[] BlackPng(int w, int h)
        {
            int row = 1 + w * 3;  // filter byte + RGB
            byte[] raw = new byte[row * h];  // all zero: filter none, black
            var zlib = new MemoryStream();
            zlib.WriteByte(0x78);
            zlib.WriteByte(0x01);
            int at = 0;
            do
            {
                int len = Math.Min(65535, raw.Length - at);
                bool last = at + len >= raw.Length;
                zlib.WriteByte((byte)(last ? 1 : 0));
                zlib.WriteByte((byte)(len & 0xff));
                zlib.WriteByte((byte)(len >> 8));
                zlib.WriteByte((byte)(~len & 0xff));
                zlib.WriteByte((byte)((~len >> 8) & 0xff));
                zlib.Write(raw, at, len);
                at += len;
            } while (at < raw.Length);
            WriteBE(zlib, Adler32(raw));
            var png = new MemoryStream();
            png.Write(PNG_SIGNATURE, 0, PNG_SIGNATURE.Length);
            var ihdr = new MemoryStream();
            WriteBE(ihdr, (uint)w);
            WriteBE(ihdr, (uint)h);
            ihdr.WriteByte(8);  // bit depth
            ihdr.WriteByte(2);  // colour type: RGB
            ihdr.WriteByte(0);  // compression
            ihdr.WriteByte(0);  // filter
            ihdr.WriteByte(0);  // interlace
            Chunk(png, "IHDR", ihdr.ToArray());
            Chunk(png, "IDAT", zlib.ToArray());
            Chunk(png, "IEND", new byte[0]);
            return png.ToArray();
        }

        // True when `bytes` start with the PNG signature.
        public static bool IsPng(byte[] bytes)
        {
            if (bytes == null || bytes.Length < PNG_SIGNATURE.Length) return false;
            for (int i = 0; i < PNG_SIGNATURE.Length; i++) if (bytes[i] != PNG_SIGNATURE[i]) return false;
            return true;
        }

        static void Chunk(Stream s, string type, byte[] data)
        {
            WriteBE(s, (uint)data.Length);
            byte[] t = Encoding.ASCII.GetBytes(type);
            s.Write(t, 0, t.Length);
            s.Write(data, 0, data.Length);
            uint crc = Crc32(t, 0xffffffffu);
            crc = Crc32(data, crc);
            WriteBE(s, crc ^ 0xffffffffu);
        }

        static void WriteBE(Stream s, uint v)
        {
            s.WriteByte((byte)(v >> 24));
            s.WriteByte((byte)(v >> 16));
            s.WriteByte((byte)(v >> 8));
            s.WriteByte((byte)v);
        }

        static uint Crc32(byte[] data, uint crc)
        {
            foreach (byte b in data)
            {
                crc ^= b;
                for (int k = 0; k < 8; k++) crc = (crc & 1) != 0 ? 0xEDB88320u ^ (crc >> 1) : crc >> 1;
            }
            return crc;
        }

        static uint Adler32(byte[] data)
        {
            const uint MOD = 65521;
            uint a = 1, b = 0;
            foreach (byte x in data)
            {
                a = (a + x) % MOD;
                b = (b + a) % MOD;
            }
            return (b << 16) | a;
        }

        // What is wrong with the report folder `folder`, empty when it is a good report of a player who typed `typed`
        // (tests/lib/ui_feedback.gd problems: the one reader of a report folder).
        public static List<string> Problems(string folder, string typed)
        {
            var out_ = new List<string>();
            string textPath = Path.Combine(folder, TEXT_FILE);
            if (!File.Exists(textPath))
            {
                out_.Add("report.txt is missing");
            }
            else
            {
                string text = File.ReadAllText(textPath);
                string first = text.Split('\n')[0];
                string version = ProjectVersion(S.FileAccess.FileExists(PROJECT_FILE) ? S.FileAccess.GetFileAsString(PROJECT_FILE) : "");
                if (!first.StartsWith("Version: ", StringComparison.Ordinal) || version == NO_VERSION || !first.EndsWith(version, StringComparison.Ordinal))
                    out_.Add($"the first line is not the Version line ({first})");
                if (!string.IsNullOrEmpty(typed) && !text.Contains(typed)) out_.Add("the typed text is not in report.txt");
                foreach (string label in FACT_LABELS)
                    if (!("\n" + text).Contains("\n" + label + ":")) out_.Add($"no {label}: line");
            }
            string shotPath = Path.Combine(folder, SHOT_FILE);
            if (!File.Exists(shotPath)) out_.Add("screenshot.png is missing");
            else if (!IsPng(File.ReadAllBytes(shotPath))) out_.Add("screenshot.png is not a picture");
            return out_;
        }
    }
}
