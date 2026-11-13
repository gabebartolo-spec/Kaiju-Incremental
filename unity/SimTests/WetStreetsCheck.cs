// The wet streets (Rampage/WetStreets.cs; scenes/weather_view.gd _wet_the_ground, _place_smears). Player-effect
// fixture "wet streets" (tests/run_weather_tests.gd _check_rain_view, _check_sheen_only_when_wet): in the rain (on)
// the ground is soaked and the streetlights and lit buildings round the camera lay their smears on it; in clear
// weather (off) the ground stays dry and nothing is laid. A lamp that is out lays none, a trampled lamp's smear goes
// with it, and with no lit windows only the lamps lay smears. On the young croc's first city with a fixed grid of
// lamps at night (dusk lights no lamps), the port lays Godot's smears, smear for smear, from four camera places (golden/wet_streets.txt,
// tools/unity/dump_wet_streets_golden.gd).
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using Kaiju.Sim;

static class WetStreetsCheck
{
    // tools/unity/dump_wet_streets_golden.gd: the lamp grid, the lamps that are out and the camera places.
    const int LAMPS_X = 15, LAMPS_Z = 12, LAMP_OUT_EVERY = 7, LAMP_OUT_AT = 3;
    const double STEP_X = 13.0, STEP_Z = 17.0, FROM_X = -90.0, FROM_Z = -80.0, LAMP_Y = 2.4, NEAR = 0.002;
    static readonly double[][] ORIGINS = { new[] { 3.7, 11.3 }, new[] { -41.2, 27.9 }, new[] { 66.4, -58.1 }, new[] { 400.3, 400.7 } };
    const string TIME = "night";
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        Content.Look();
        string was = Content._timeId;
        Content.SetTime(TIME);
        RainWetsClearDoesNot();
        LampsOutAndTrampled();
        Godot();
        Content.SetTime(was);
        Console.WriteLine(failed == 0 ? $"wet streets: ok ({checks} checks)" : $"wet streets: {failed} of {checks} failed");
        return failed;
    }

    static RampageSim City()
    {
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), new UpgradeTree(Content.Upgrades()));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), 1, Seeds.Make("city", 0));
        return new RampageSim(stats, CityGrowth.ForStats(stats), layout, Seeds.Make("army", 0));
    }

    static List<WetStreets.Lamp> Lamps()
    {
        double[] c = WeatherLook.Hex("ffd59a");
        double energy = Num.F(Content.Look()["lamp_energy"]);
        var lamps = new List<WetStreets.Lamp>();
        for (int i = 0; i < LAMPS_X * LAMPS_Z; i++)
        {
            lamps.Add(new WetStreets.Lamp
            {
                x = FROM_X + i % LAMPS_X * STEP_X, y = LAMP_Y, z = FROM_Z + i / LAMPS_X * STEP_Z,
                r = c[0], g = c[1], b = c[2], energy = i % LAMP_OUT_EVERY == LAMP_OUT_AT ? 0.0 : energy,
            });
        }
        return lamps;
    }

    static double Lit() => Num.F(Content.Look().Get("window_lit", 0.0));

    static void RainWetsClearDoesNot()
    {
        RampageSim sim = City();
        List<WetStreets.Lamp> lamps = Lamps();
        var laid = new List<WetStreets.Smear>();
        foreach (string id in new[] { "rain", "thunderstorm" })
        {
            var wet = new WetStreets(WeatherLook.LayerOf(id));
            Check(wet.wet > 0.5 && wet.smears, $"{id} wets the streets (wet {wet.wet:F2}) and lays smears");
            wet.Place(ORIGINS[0][0], ORIGINS[0][1], lamps, sim, Lit(), laid);
            int lampSmears = laid.FindAll(m => m.r == lamps[0].r && m.g == lamps[0].g && m.b == lamps[0].b).Count;
            Check(lampSmears > 0 && laid.Count > lampSmears, $"{id}: the lamps ({lampSmears}) and the lit buildings ({laid.Count - lampSmears}) lay smears");
        }
        var clear = new WetStreets(WeatherLook.LayerOf("clear"));
        Check(clear.wet == 0.0 && !clear.smears, $"clear leaves the streets dry (wet {clear.wet:F2}) and lays no smears");
        Check(WetStreets.WetOf(new GDict()) == 0.0, "no layer: dry");
    }

    static void LampsOutAndTrampled()
    {
        var wet = new WetStreets(WeatherLook.LayerOf("rain"));
        List<WetStreets.Lamp> lamps = Lamps();
        var laid = new List<WetStreets.Smear>();
        wet.Place(ORIGINS[0][0], ORIGINS[0][1], lamps, null, Lit(), laid);
        int all = laid.Count;
        bool noneOut = laid.TrueForAll(m => lamps.Exists(l => l.energy > 0.0 && l.x == m.x && l.z == m.z));
        Check(all > 0 && noneOut, $"only lit lamps lay smears ({all})");
        double fx = laid[0].x, fz = laid[0].z;
        int gone = WetStreets.Crush(lamps, fx, fz, 1.0);
        wet.Place(ORIGINS[0][0], ORIGINS[0][1], lamps, null, Lit(), laid);
        bool smearGone = !laid.Exists(m => m.x == fx && m.z == fz);
        Check(gone == 1 && smearGone, $"a trampled lamp's smear goes with it ({gone} lamp out, its smear {(smearGone ? "gone" : "still laid")})");
        int lampsOnly = laid.Count;
        wet.Place(ORIGINS[0][0], ORIGINS[0][1], lamps, City(), 0.0, laid);
        Check(laid.Count == lampsOnly, $"no lit windows: only the lamps lay smears ({laid.Count} of {lampsOnly})");
    }

    static void Godot()
    {
        string[] gold = File.ReadAllLines(Path.Combine(AppContext.BaseDirectory, "golden", "wet_streets.txt"));
        var wet = new WetStreets(WeatherLook.LayerOf("rain"));
        RampageSim sim = City();
        List<WetStreets.Lamp> lamps = Lamps();
        var ours = new List<string> { Inv($"W {wet.wet:F4} {Lit():F4}") };
        var laid = new List<WetStreets.Smear>();
        for (int k = 0; k < ORIGINS.Length; k++)
        {
            wet.Place(ORIGINS[k][0], ORIGINS[k][1], lamps, sim, Lit(), laid);
            ours.Add(Inv($"O {k} {ORIGINS[k][0]:F4} {ORIGINS[k][1]:F4} {laid.Count}"));
            for (int i = 0; i < laid.Count; i++)
            {
                WetStreets.Smear m = laid[i];
                ours.Add(Inv($"M {i} {m.x:F4} {m.y:F4} {m.z:F4} {m.r:F4} {m.g:F4} {m.b:F4} {m.a:F4} {m.width:F4} {m.length:F4}"));
            }
        }
        Check(ours.Count == gold.Length, $"as many lines as Godot's wet streets ({ours.Count} vs {gold.Length})");
        int same = 0;
        for (int i = 0; i < Math.Min(ours.Count, gold.Length); i++)
        {
            if (Match(ours[i], gold[i])) same++;
            else if (same + 3 > i) Console.WriteLine($"  wet streets: ours {ours[i]} | godot {gold[i]}");
        }
        Check(same == gold.Length, $"every smear laid as Godot's ({same} of {gold.Length} lines within {NEAR})");
    }

    static string Inv(FormattableString s) => s.ToString(CultureInfo.InvariantCulture);

    static bool Match(string a, string b)
    {
        string[] x = a.Split(' '), y = b.Split(' ');
        if (x.Length != y.Length) return false;
        for (int i = 0; i < x.Length; i++)
        {
            bool nx = double.TryParse(x[i], NumberStyles.Float, CultureInfo.InvariantCulture, out double vx);
            bool ny = double.TryParse(y[i], NumberStyles.Float, CultureInfo.InvariantCulture, out double vy);
            if (nx && ny ? Math.Abs(vx - vy) > NEAR : x[i] != y[i]) return false;
        }
        return true;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL wet streets: " + what);
    }
}
