using System;
using System.Collections.Generic;
using Kaiju.Game;
using S = Kaiju.Sim;

// The wet streets of a rainy run (scenes/weather_view.gd _wet_the_ground, _place_smears, _place_lamps, _place_windows;
// D-155): how wet the ground is (the weather layer's "wet", data/looks.json weather.layers) and the glowing smears
// on the wet road, one under every lit streetlight in reach and one in front of each of the nearest lit buildings,
// placed from the camera's ground point. Godot axes throughout (the sim's); WeatherView turns them into Unity's.
// Presentation only: it reads the sim's buildings and never changes them. No UnityEngine here: unity/SimTests
// compiles this file (WetStreetsCheck).
public sealed class WetStreets
{
    // A streetlight's light (city_decor.gd _lamp's PooledLight): where it is, its colour (as Godot's Color holds it)
    // and the energy it wants. A trampled lamp leaves the list (city_decor.gd crush, _process).
    public struct Lamp
    {
        public double x, y, z, r, g, b, energy;
    }

    // One smear (weather_view.gd's MultiMesh instance): its foot on the ground, its colour and how much is on (the
    // instance colour), its width and length in metres (the instance custom data's x and y).
    public struct Smear
    {
        public double x, y, z, r, g, b, a, width, length;
    }

    public readonly double wet;
    public readonly bool smears;
    public readonly int max;
    readonly double y, reach, lampFull, lampWidth, lampPerHeight, windowReach, windowGain, windowPerHeight, windowMax;
    readonly int lampMax;
    readonly double[] warm;
    // weather_view.gd _place_windows' `near`: (distance, building index), float like Godot's Vector2.
    (float d, int i)[] near = new (float d, int i)[0];

    // weather_view.gd: a wet window shortest it may be (its clampf floor).
    const double WINDOW_LENGTH_MIN = 2.0;
    // weather_view.gd _place_windows: a window smear is this share of its building's width.
    const double WINDOW_WIDTH_SHARE = 0.8;
    // weather_view.gd _place_smears: the smears sit this far above the splashes' plane.
    const double ABOVE_SPLASHES = 0.02;
    // weather_view.gd _place_windows: a look this dark has no lit windows to mirror.
    const double LIT_MIN = 0.02;

    // `layer`: the run's weather layer (WeatherLook.LayerOf; empty for clear).
    public WetStreets(S.GDict layer)
    {
        wet = WetOf(layer);
        // weather_view.gd _build_rain: the smears come with the rain, and only on a wet ground.
        smears = wet > 0.0 && WeatherLook.Rains(layer);
        S.GDict cfg = S.Content.Section("rain");
        S.GDict smear = cfg["smear"];
        y = S.Num.F(cfg["splash_y"]) + ABOVE_SPLASHES;
        max = (int)S.Num.I(smear["max"]);
        lampMax = (int)S.Num.I(smear["lamp_max"]);
        reach = S.Num.F(smear["reach"]);
        lampFull = S.Num.F(smear["lamp_energy_full"]);
        lampWidth = S.Num.F(smear["width"]);
        lampPerHeight = S.Num.F(smear["length_per_height"]);
        windowReach = S.Num.F(smear["window_reach"]);
        windowGain = S.Num.F(smear["window_gain"]);
        windowPerHeight = S.Num.F(smear["window_length_per_height"]);
        windowMax = S.Num.F(smear["window_length_max"]);
        warm = WeatherLook.Hex(S.Gd.Str(smear["window_color"]));
    }

    // weather_view.gd _wet_the_ground: the layer's "wet" (0 when it has none: the streets stay dry).
    public static double WetOf(S.GDict layer) => layer.IsEmpty() ? 0.0 : WeatherLook.Value(layer, "wet", 0.0);

    // weather_view.gd _place_smears: every smear for a camera at (ox, oz), lamps first, then the lit buildings,
    // into `into` (cleared). `lit`: the look's window_lit share.
    public void Place(double ox, double oz, IReadOnlyList<Lamp> lamps, S.RampageSim sim, double lit, List<Smear> into)
    {
        into.Clear();
        PlaceLamps(ox, oz, lamps, into);
        PlaceWindows(ox, oz, sim, lit, into);
    }

    // weather_view.gd _place_lamps: one smear under every lit streetlight in reach, in the order the lamps were
    // made, the first lamp_max at most. Godot tells its lamps from fires and beacons by their fade distance; here
    // the list holds lamps only.
    void PlaceLamps(double ox, double oz, IReadOnlyList<Lamp> lamps, List<Smear> into)
    {
        foreach (Lamp lamp in lamps)
        {
            if (into.Count >= lampMax) break;
            if (lamp.energy <= 0.0) continue;
            if (Length(lamp.x - ox, lamp.z - oz) > reach) continue;
            into.Add(new Smear
            {
                x = lamp.x, y = y, z = lamp.z, r = lamp.r, g = lamp.g, b = lamp.b,
                a = Math.Clamp(lamp.energy / lampFull, 0.0, 1.0), width = lampWidth, length = lampPerHeight * lamp.y,
            });
        }
    }

    // weather_view.gd _place_windows: a long soft smear in front of each standing building in window_reach, nearest
    // first, until the smears run out. Godot sorts by distance alone with its own unstable introsort; GodotSort is
    // that sort, so buildings at the same distance come in Godot's order.
    void PlaceWindows(double ox, double oz, S.RampageSim sim, double lit, List<Smear> into)
    {
        if (lit <= LIT_MIN || sim == null) return;
        int n = 0;
        if (near.Length < sim.buildings.Size()) near = new (float d, int i)[sim.buildings.Size()];
        for (int i = 0; i < sim.buildings.Size(); i++)
        {
            S.RampageSim.Building b = sim.buildings[i];
            double d = Length(b.x - ox, b.z - oz);
            if (d <= windowReach && b.height > 0) near[n++] = ((float)d, i);
        }
        S.GodotSort.Sort(near, n, (p, q) => p.d < q.d);
        double a = Math.Clamp(lit * windowGain, 0.0, 1.0);
        for (int k = 0; k < n; k++)
        {
            if (into.Count >= max) break;
            S.RampageSim.Building b = sim.buildings[near[k].i];
            into.Add(new Smear
            {
                x = b.x, y = y, z = b.z + b.d * 0.5, r = warm[0], g = warm[1], b = warm[2], a = a,
                width = b.w * WINDOW_WIDTH_SHARE, length = Math.Clamp(b.height * windowPerHeight, WINDOW_LENGTH_MIN, windowMax),
            });
        }
    }

    // city_decor.gd crush: the lamps within `radius` of (x, z) go out for good (their smears with them).
    public static int Crush(List<Lamp> lamps, double x, double z, double radius)
    {
        return lamps.RemoveAll(l => Length(l.x - x, l.z - z) <= radius);
    }

    // Godot's Vector2.length(): float components.
    static double Length(double dx, double dz)
    {
        float fx = (float)dx, fz = (float)dz;
        return MathF.Sqrt(fx * fx + fz * fz);
    }
}
