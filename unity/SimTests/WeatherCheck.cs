// The weather look's numbers (Assets/Scripts/GameLogic/WeatherLook.cs) against scenes/weather_view.gd and the checks
// of tests/run_weather_tests.gd (rain view, preset scaling) and tests/run_rain_look_tests.gd that need no scene:
// which weathers build a view, the 'like' layer, the dulling, the streak colour under the bloom threshold, counts x
// the particles ratio, a fall that reaches the ground, and the rain staying heavy. No clock.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using Kaiju.Sim;

static class WeatherCheck
{
    static int checks, failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL weather: " + what);
    }

    static int Total(List<RainLayer> layers)
    {
        int n = 0;
        foreach (RainLayer l in layers) n += l.count;
        return n;
    }

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        FileAccess.Root = repoRoot;
        GDict cfg = Content.Section("rain");

        // Which weathers build a view (run_weather_tests.gd _check_rain_view): rain and the storm do, the rest not yet.
        foreach (Variant idAny in Content.Weathers())
        {
            string id = Gd.Str(idAny);
            GDict layer = WeatherLook.LayerOf(id);
            if (id == "rain" || id == "thunderstorm")
            {
                Check(WeatherLook.Rains(layer), id + " lets rain fall");
                Check(WeatherLook.Value(layer, "wet", 0.0) > 0.5, id + " wets the streets");
                Check(WeatherLook.Value(layer, "sun_mul", 1.0) < 1.0, id + " dulls the sun");
            }
            else Check(layer.IsEmpty(), id + " builds no weather view yet");
        }
        Check(WeatherLook.LayerOf("clear").IsEmpty(), "clear has no layer");
        Check(WeatherLook.LayerOf("no_such_weather").IsEmpty(), "an unknown weather has no layer");

        // 'like' copies the other layer whole and is not kept.
        GDict rain = WeatherLook.LayerOf("rain");
        GDict storm = WeatherLook.LayerOf("thunderstorm");
        Check(!storm.Has("like") && storm.Size() == rain.Size(), "the storm's layer is rain's, 'like' resolved");
        foreach (Variant key in rain.Keys())
            Check(storm.Has(key) && Gd.Str(storm[key]) == Gd.Str(rain[key]), "the storm copies rain's " + Gd.Str(key));

        // The dulling (weather_view.gd _dulled).
        double[] same = WeatherLook.Dulled(0.3, 0.5, 0.7, 0.0, 1.0);
        Check(Math.Abs(same[0] - 0.3) < 1e-9 && Math.Abs(same[1] - 0.5) < 1e-9 && Math.Abs(same[2] - 0.7) < 1e-9, "no grey and no dim leave a colour alone");
        double[] grey = WeatherLook.Dulled(0.3, 0.5, 0.7, 1.0, 0.5);
        double lum = 0.2126 * 0.3 + 0.7152 * 0.5 + 0.0722 * 0.7;
        Check(Math.Abs(grey[0] - lum * 0.5) < 1e-9 && Math.Abs(grey[1] - grey[0]) < 1e-9 && Math.Abs(grey[2] - grey[0]) < 1e-9,
            "full grey is the colour's own luminance, dimmed");

        // The streaks stay under the bloom threshold in every time of day (run_weather_tests.gd).
        string keptTime = Content._timeId;
        foreach (Variant timeAny in Content.Times())
        {
            Content.SetTime(Gd.Str(timeAny));
            double[] tint = WeatherLook.StreakColor();
            Check(Math.Max(tint[0], Math.Max(tint[1], tint[2])) < 0.9, $"{Gd.Str(timeAny)} streaks stay under the bloom threshold");
        }
        Content.SetTime(keptTime);
        double[] white = WeatherLook.StreakColor(new[] { 1.0, 1.0, 1.0 }, cfg);
        Check(Math.Abs(Math.Max(white[0], Math.Max(white[1], white[2])) - Num.F(cfg["max_channel"])) < 1e-9, "a white fog is held at max_channel");
        Check(WeatherLook.Hex("#7e8274")[0] == 0x7e / 255.0 && WeatherLook.Hex("7e8274")[2] == 0x74 / 255.0, "hex colours read as Godot's Color(str)");

        // Counts are x the particles ratio (_check_rain_scales_with_preset), Godot's maxi(1, roundi()).
        GDict table = Content.Section("display")["graphics"];
        double potato = Num.F(((GDict)table["potato"])["particles"]);
        double high = Num.F(((GDict)table["high"])["particles"]);
        List<RainLayer> few = WeatherLook.Layers(cfg, potato, 2.2, 0.9);
        List<RainLayer> many = WeatherLook.Layers(cfg, high, 2.2, 0.9);
        Check(Total(few) > 0 && Total(few) < Total(many), $"potato draws fewer rain streaks than high: {Total(few)} < {Total(many)}");
        Check(WeatherLook.Splashes(cfg, potato).count < WeatherLook.Splashes(cfg, high).count, "potato draws fewer splashes than high");
        Check(WeatherLook.Count(0.2, 1.0) == 1 && WeatherLook.Count(2.5, 1.0) == 3 && WeatherLook.Count(100, 0.35) == 35, "counts round as roundi, at least 1");

        // Every streak lives long enough to reach the ground, at its slowest (weather_view.gd _build_layer).
        foreach (RainLayer l in many)
        {
            double slowestFall = -l.velY * (1.0 - l.jitter);
            Check(l.lifetime * slowestFall >= l.volY, $"{l.name} streaks reach the ground ({l.lifetime * slowestFall:F1} m >= {l.volY:F1} m)");
            Check(l.velX != 0.0 && l.velY < 0.0, $"{l.name} streaks fall and lean with the wind");
        }

        // The rain stays heavy (run_rain_look_tests.gd _check_rain_is_heavy).
        GArray<Variant> rows = cfg["layers"];
        Check(rows.Size() == 3 && many.Count == 3, "rain has three depth layers");
        int streaks = 0;
        foreach (Variant rowAny in rows)
        {
            GDict row = rowAny;
            streaks += (int)Num.I(row["streaks"]);
            Check(Num.F(row["alpha"]) >= Num.F(cfg["min_streak_alpha"]), Gd.Str(row["name"]) + " streak alpha at least min_streak_alpha");
            Check(Num.F(row["width"]) >= 0.0005, Gd.Str(row["name"]) + " streaks at least 0.05% of the screen height thick");
        }
        RainLayer near = many[0], far = many[2];
        Check(near.len >= 0.02 && near.len <= 0.04, $"near streaks are 2-4% of the screen height ({near.len:F3})");
        Check(near.width > far.width && near.alpha > far.alpha && -near.velY > -far.velY, "near streaks are thicker, brighter and faster than far");
        Check(streaks >= 60000, $"at least 60000 streaks in all ({streaks})");
        Check(Num.I(cfg["splashes"]) >= 8000, "at least 8000 mist puffs");
        Check(Num.F(cfg["tint_white"]) >= 0.7, "streaks are lifted well toward white");
        Check(WeatherLook.Value(rain, "fog_mul", 0.0) >= 1.2 && WeatherLook.Value(rain, "wet", 0.0) >= 0.9, "rain adds fog and wets the streets");

        Console.WriteLine($"weather: {checks} checks, {failed} failed");
        return failed;
    }
}
