// Compares the C# sim with values Godot itself produced (tools/unity/dump_sim_golden.gd).
//   dotnet run --project unity/SimTests
using System;
using System.Globalization;
using System.IO;
using System.Text.Json;
using Kaiju.Sim;

static class Program
{
    static int failures;
    static int checks;

    static int Main()
    {
        // SIM_NATIVE: off replays on the C# passes alone; on fails without the DLL, which CI needs,
        // since a replay that quietly fell back would pass without testing the DLL at all.
        string mode = Environment.GetEnvironmentVariable("SIM_NATIVE");
        ClassDB.UseNative = mode != "off";
        bool native = ClassDB.ClassExists("KaijuSettle");
        Console.WriteLine("native DLL: " + (native ? "on" : "off"));
        if (mode == "on" && !native) return 1;
        if (native) failures += BeamCheck.Run();
        if (native) failures += WaterCheck.Run();
        failures += RubbleCheck.Run();
        failures += PostFxCheck.Run(RepoRoot());
        failures += StreetCheck.Run(RepoRoot());
        // The game logic outside the sim (GameLogic/): saves, settings and what a rampage takes from the save.
        failures += SaveCheck.Run(RepoRoot());
        failures += SettingsCheck.Run(RepoRoot());
        failures += MotionCheck.Run(RepoRoot());
        failures += RunStartCheck.Run(RepoRoot());
        // The screens' plain logic (GameLogic/): what each screen shows and decides, against the Godot game's data.
        failures += TitleCheck.Run(RepoRoot());
        failures += OptionsRowsCheck.Run(RepoRoot());
        failures += CreationCheck.Run(RepoRoot());
        failures += GlobeCheck.Run(RepoRoot());
        failures += ResultsCheck.Run(RepoRoot());
        failures += DemoCardCheck.Run(RepoRoot());
        failures += TreeCheck.Run(RepoRoot());
        failures += HudCheck.Run(RepoRoot());
        failures += AudioCheck.Run(RepoRoot());
        failures += LoadingCheck.Run(RepoRoot());
        failures += FeedbackCheck.Run(RepoRoot());
        failures += PhotoCheck.Run(RepoRoot());
        failures += WeatherCheck.Run(RepoRoot());
        string path = Path.Combine(AppContext.BaseDirectory, "golden", "rng.json");
        using JsonDocument doc = JsonDocument.Parse(File.ReadAllText(path));
        JsonElement root = doc.RootElement;
        foreach (JsonElement stream in root.GetProperty("streams").EnumerateArray())
            CheckStream(stream);
        foreach (JsonElement row in root.GetProperty("strings").EnumerateArray())
            Same("hash string", row.GetProperty("hash").GetUInt32(), GodotHash.String(row.GetProperty("text").GetString()));
        foreach (JsonElement row in root.GetProperty("vectors").EnumerateArray())
        {
            JsonElement v = row.GetProperty("v");
            uint got = GodotHash.Vector4i(v[0].GetInt32(), v[1].GetInt32(), v[2].GetInt32(), v[3].GetInt32());
            Same("hash Vector4i", row.GetProperty("hash").GetUInt32(), got);
        }
        foreach (JsonElement row in root.GetProperty("arrays").EnumerateArray())
        {
            uint got = GodotHash.Array(
                GodotHash.Int(row.GetProperty("i").GetInt64()),
                GodotHash.Double(Dbl(row.GetProperty("a").GetString())),
                GodotHash.Double(Dbl(row.GetProperty("b").GetString())));
            Same("hash array", row.GetProperty("hash").GetUInt32(), got);
        }
        foreach (JsonElement row in root.GetProperty("seeds").EnumerateArray())
        {
            RandomNumberGenerator made = Seeds.Make(row.GetProperty("stream").GetString(), row.GetProperty("index").GetInt32());
            Same("Seeds.Make", row.GetProperty("seed").GetUInt64(), unchecked((ulong)made.seed));
            Same("Seeds.Derive", row.GetProperty("derived").GetUInt64(), unchecked((ulong)Seeds.Derive(made, row.GetProperty("salt").GetInt64()).seed));
        }
        Console.WriteLine($"{checks} checks, {failures} failed");
        string log = Path.Combine(AppContext.BaseDirectory, "golden", "log.json");
        string text = Environment.GetEnvironmentVariable("SIM_LOG_TEXT");
        int differ = SimLog.Check(log, RepoRoot(), Console.WriteLine, text);
        Console.WriteLine($"{differ} ticks differ from Godot");
        // After the replay, so its sims cannot disturb it.
        failures += AirstrikeCheck.Run(RepoRoot());
        failures += VipCheck.Run(RepoRoot());
        failures += RailCheck.Run();
        failures += RooftopCheck.Run();
        failures += LeapCheck.Run(RepoRoot());
        return failures == 0 && differ == 0 ? 0 : 1;
    }

    static string RepoRoot()
    {
        string at = AppContext.BaseDirectory;
        while (!File.Exists(Path.Combine(at, "data", "tuning.json"))) at = Path.GetDirectoryName(at);
        return at;
    }

    static void CheckStream(JsonElement stream)
    {
        Rng rng = new Rng(stream.GetProperty("seed").GetUInt64());
        foreach (JsonElement step in stream.GetProperty("steps").EnumerateArray())
        {
            string op = step[0].GetString();
            string want = step[step.GetArrayLength() - 1].GetString();
            string got;
            switch (op)
            {
                case "randi":
                    got = rng.Randi().ToString(CultureInfo.InvariantCulture);
                    break;
                case "randf":
                    got = Hex(rng.Randf());
                    break;
                case "randf_range":
                    got = Hex(rng.RandfRange((float)step[1].GetDouble(), (float)step[2].GetDouble()));
                    break;
                case "randi_range":
                    got = rng.RandiRange(step[1].GetInt32(), step[2].GetInt32()).ToString(CultureInfo.InvariantCulture);
                    break;
                default:
                    throw new InvalidDataException(op);
            }
            Same(op, want, got);
        }
        // GDScript's int is signed, so a large state prints negative.
        Same("state", stream.GetProperty("state").GetString(), unchecked((long)rng.State).ToString(CultureInfo.InvariantCulture));
    }

    static string Hex(float value) => BitConverter.SingleToInt32Bits(value).ToString("x8", CultureInfo.InvariantCulture);

    static double Dbl(string hex) => BitConverter.Int64BitsToDouble(long.Parse(hex, NumberStyles.HexNumber, CultureInfo.InvariantCulture));

    static void Same<T>(string what, T want, T got)
    {
        checks++;
        if (Equals(want, got))
            return;
        failures++;
        if (failures <= 20)
            Console.WriteLine($"FAIL {what}: Godot {want}, C# {got}");
    }
}
