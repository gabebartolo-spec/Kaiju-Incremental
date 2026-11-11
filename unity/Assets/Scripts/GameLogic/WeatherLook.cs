// The numbers of the run's weather look (scenes/weather_view.gd), as plain C#: the weather's layer from
// data/looks.json "weather" "layers" ('like' resolved), the sky dulling, the streak colour and the rain's three
// depth layers and splashes from data/tuning.json "rain", counts x the graphics preset's particles ratio.
// The Unity WeatherView draws these; unity/SimTests WeatherCheck holds them to tests/run_weather_tests.gd and
// run_rain_look_tests.gd. Presentation only: nothing here touches the sim.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    // One depth layer of streaks (weather_view.gd _build_layer), Godot axes.
    public sealed class RainLayer
    {
        public string name;
        public int count;
        // The volume that follows the camera: x and z across, y its height (the emitter sits at y, the fall ends
        // at the ground); ahead: metres in front of the camera its centre sits.
        public double volX, volY, volZ, ahead;
        // The fall: velocity (m/s, Godot axes), its jitter share, and how long every streak lives.
        public double velX, velY, velZ, speed, jitter, lifetime;
        // rain.gdshader uniforms.
        public double len, width, alpha, fadeIn, fadeOut, farBegin, farEnd, nearClear, nearFull;
    }

    // The ground splashes (weather_view.gd _build_splashes).
    public sealed class RainSplashes
    {
        public int count;
        public double areaX, areaZ, y, ahead, seconds, lifetimeSpread, size, alpha;
        // weather_view.gd SPLASH_SIZE_SPREAD.
        public double scaleMin, scaleMax;
        // rain_splash.gdshader uniforms (splash_clear).
        public double nearClear, nearFull, centreKeep, centreRadius, focusClear, focusFull;
    }

    public static class WeatherLook
    {
        // weather_view.gd SPLASH_SIZE_SPREAD: the splash quad's scale range.
        public const double SPLASH_SCALE_MIN = 0.45, SPLASH_SCALE_MAX = 1.3;
        // weather_view.gd _build_layer: every streak lives long enough to reach the ground (x 1.05).
        public const double LIFE_MARGIN = 1.05;

        // The layer of weather `id` (weather_view.gd layer_of): 'like' resolved; empty when it has none (clear).
        public static GDict LayerOf(string id)
        {
            GDict table = Content.WeatherTable().Get("layers", new GDict());
            Variant found = table.Get(id, new Variant());
            if (found.Type != Gd.TYPE_DICTIONARY) return new GDict();
            GDict src = found;
            GDict @out = src.Duplicate();
            if (@out.Has("like"))
            {
                GDict b = LayerOf(Gd.Str(@out["like"]));
                b.Merge(@out, true);
                b.Erase("like");
                return b;
            }
            return @out;
        }

        // A number of the layer, or its fallback (layer.get(key, fallback)).
        public static double Value(GDict layer, string key, double fallback) => layer.Has(key) ? Num.F(layer[key]) : fallback;

        // Whether the layer lets rain fall (layer.get("rain", false) == true).
        public static bool Rains(GDict layer) => layer.Has("rain") && layer["rain"].Type == Gd.TYPE_BOOL && (bool)layer["rain"];

        // weather_view.gd _dulled: `c` (r, g, b, Godot colour values) pulled `grey` of the way to its own luminance,
        // then dimmed. Godot's Color.get_luminance weights.
        public static double[] Dulled(double r, double g, double b, double grey, double dim)
        {
            double l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            return new[] { (r + (l - r) * grey) * dim, (g + (l - g) * grey) * dim, (b + (l - b) * grey) * dim };
        }

        // A hex colour as Godot's Color(str) reads it: "rrggbb" or "rrggbbaa", with or without '#'; r, g, b 0..1.
        public static double[] Hex(string hex)
        {
            string h = hex.StartsWith("#") ? hex.Substring(1) : hex;
            if (h.Length < 6) return new[] { 1.0, 0.0, 1.0 };
            return new[]
            {
                Convert.ToInt32(h.Substring(0, 2), 16) / 255.0,
                Convert.ToInt32(h.Substring(2, 2), 16) / 255.0,
                Convert.ToInt32(h.Substring(4, 2), 16) / 255.0,
            };
        }

        // weather_view.gd streak_color: the fog grey (the look's fog_color) lifted toward white, held under
        // max_channel so rain never blooms.
        public static double[] StreakColor(double[] fog, GDict cfg)
        {
            double w = Num.F(cfg["tint_white"]);
            double r = fog[0] + (1.0 - fog[0]) * w, g = fog[1] + (1.0 - fog[1]) * w, b = fog[2] + (1.0 - fog[2]) * w;
            double top = Math.Max(r, Math.Max(g, b));
            double cap = Num.F(cfg["max_channel"]);
            if (top > cap) return new[] { r * cap / top, g * cap / top, b * cap / top };
            return new[] { r, g, b };
        }

        // The streak colour of the look in use (Look.color("fog_color"), Godot's magenta when it is missing).
        public static double[] StreakColor() => StreakColor(Hex(Gd.Str(Content.Look().Get("fog_color", "ff00ff"))), Content.Section("rain"));

        // maxi(1, roundi(n * ratio)): Godot rounds halves away from zero.
        public static int Count(double n, double ratio) => Math.Max(1, (int)Math.Round(n * ratio, MidpointRounding.AwayFromZero));

        // The graphics preset's particles ratio (GraphicsPresets.cap("particles")).
        public static double ParticlesRatio() => GraphicsPreset.Cap("particles");

        // The three depth layers of data/tuning.json rain.layers, near first; wind is Fire.WIND (Godot axes, x and z).
        public static List<RainLayer> Layers(GDict cfg, double ratio, double windX, double windZ)
        {
            var @out = new List<RainLayer>();
            double gain = Num.F(cfg["wind_gain"]);
            double jitter = Num.F(cfg["speed_jitter"]);
            GArray<Variant> rows = cfg["layers"];
            foreach (Variant rowAny in rows)
            {
                GDict row = rowAny;
                GArray<Variant> vol = row["volume"];
                double speed = Num.F(cfg["fall_speed"]) * Num.F(row["speed_mul"]);
                double vx = windX * gain, vy = -speed, vz = windZ * gain;
                @out.Add(new RainLayer
                {
                    name = Gd.Str(row["name"]),
                    count = Count(Num.F(row["streaks"]), ratio),
                    volX = Num.F(vol[0]), volY = Num.F(vol[1]), volZ = Num.F(vol[2]),
                    ahead = Num.F(row["ahead"]),
                    velX = vx, velY = vy, velZ = vz,
                    speed = Math.Sqrt(vx * vx + vy * vy + vz * vz),
                    jitter = jitter,
                    lifetime = Num.F(vol[1]) / speed * (1.0 + jitter) * LIFE_MARGIN,
                    len = Num.F(row["len"]), width = Num.F(row["width"]), alpha = Num.F(row["alpha"]),
                    fadeIn = Num.F(cfg["fade_in"]), fadeOut = Num.F(cfg["fade_out"]),
                    farBegin = Num.F(row["far_begin"]), farEnd = Num.F(row["far_end"]),
                    nearClear = Num.F(row["near_clear"]), nearFull = Num.F(row["near_full"]),
                });
            }
            return @out;
        }

        // The splashes of data/tuning.json rain.
        public static RainSplashes Splashes(GDict cfg, double ratio)
        {
            GArray<Variant> area = cfg["splash_volume"];
            GDict clear = cfg["splash_clear"];
            return new RainSplashes
            {
                count = Count(Num.F(cfg["splashes"]), ratio),
                areaX = Num.F(area[0]), areaZ = Num.F(area[1]),
                y = Num.F(cfg["splash_y"]), ahead = Num.F(cfg["ahead"]),
                seconds = Num.F(cfg["splash_seconds"]),
                lifetimeSpread = Num.F(cfg["splash_lifetime_spread"]),
                size = Num.F(cfg["splash_size"]), alpha = Num.F(cfg["splash_alpha"]),
                scaleMin = SPLASH_SCALE_MIN, scaleMax = SPLASH_SCALE_MAX,
                nearClear = Num.F(clear["near_clear"]), nearFull = Num.F(clear["near_full"]),
                centreKeep = Num.F(clear["centre_keep"]), centreRadius = Num.F(clear["centre_radius"]),
                focusClear = Num.F(clear["focus_clear"]), focusFull = Num.F(clear["focus_full"]),
            };
        }

        // The streaks' clearing table (rain.clear): centre_keep, centre_radius, focus_clear, focus_full.
        public static double[] StreakClear(GDict cfg)
        {
            GDict c = cfg["clear"];
            return new[] { Num.F(c["centre_keep"]), Num.F(c["centre_radius"]), Num.F(c["focus_clear"]), Num.F(c["focus_full"]) };
        }
    }
}
