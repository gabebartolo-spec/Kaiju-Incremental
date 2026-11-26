// What creation_set.gd does to a lab prop's colours before it is built: read's despeckle (lone off-colour
// blocks take their neighbours' average) and the monitors' screen_color (the glass inside the data's
// rectangles turns dark green with rows of lit readout bars). Works on a copy: ModelColors' cache is shared.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

public static class CreationPaint
{
    // Godot's Color.get_luminance weights (sRGB channels as stored).
    const float LUMA_R = 0.2126f, LUMA_G = 0.7152f, LUMA_B = 0.0722f, BYTE = 255f;
    // A colour packed as 0xRRGGBB (ModelColors' rgb), and a hex string's base.
    const int MASK = 255, RED = 16, GREEN = 8, HEX = 16, HEX_DIGITS = 6;
    // despeckle: a speck has at least this many neighbours.
    const int CROWD = 4;
    // screen_color: a readout row every BAR_ROW rows, in runs of BAR_RUN cells, one run in BAR_GAP left dark.
    const int BAR_ROW = 4, BAR_GAP = 3;
    const double BAR_RUN = 6.0;

    static readonly Vector3Int[] NEIGHBOURS =
        { Vector3Int.left, Vector3Int.right, Vector3Int.up, Vector3Int.down, new Vector3Int(0, 0, -1), new Vector3Int(0, 0, 1) };

    public static ModelColors.Model Copy(ModelColors.Model m) => new ModelColors.Model { xyz = m.xyz, rgb = (int[])m.rgb.Clone() };

    static Vector3Int Cell(int[] raw, int i) => new Vector3Int(raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]);

    public static int R(int c) => (c >> RED) & MASK;
    public static int G(int c) => (c >> GREEN) & MASK;
    public static int B(int c) => c & MASK;
    public static int Pack(int r, int g, int b) => r << RED | g << GREEN | b;
    public static int Hex(string s) => Convert.ToInt32(s.Substring(0, HEX_DIGITS), HEX);
    public static Color Rgb(int c) => new Color(R(c) / BYTE, G(c) / BYTE, B(c) / BYTE, 1f);

    static float Luma(int c) => (LUMA_R * R(c) + LUMA_G * G(c) + LUMA_B * B(c)) / BYTE;

    // creation_set.gd despeckle, in place.
    public static void Despeckle(ModelColors.Model m)
    {
        float step = (float)S.Num.F(CreationLab.Cfg()["despeckle"]);
        int[] raw = m.xyz.Raw;
        var at = new Dictionary<Vector3Int, int>();
        for (int i = 0; i < m.rgb.Length; i++) at[Cell(raw, i)] = i;
        var fixes = new List<(int index, int rgb)>();
        for (int i = 0; i < m.rgb.Length; i++)
        {
            Vector3Int cell = Cell(raw, i);
            float own = Luma(m.rgb[i]);
            int n = 0, r = 0, g = 0, b = 0;
            bool alike = false;
            foreach (Vector3Int d in NEIGHBOURS)
            {
                if (!at.TryGetValue(cell + d, out int j)) continue;
                int o = m.rgb[j];
                r += R(o);
                g += G(o);
                b += B(o);
                n++;
                alike |= Math.Abs(Luma(o) - own) <= step;
            }
            if (n >= CROWD && !alike) fixes.Add((i, Pack(Avg(r, n), Avg(g, n), Avg(b, n))));
        }
        foreach ((int index, int rgb) in fixes) m.rgb[index] = rgb;
    }

    static int Avg(int sum, int n) => Mathf.RoundToInt(sum / (float)n);

    // creation_set.gd paint(monitors, screen_color), in place; returns which cells glow.
    public static bool[] Screens(ModelColors.Model m, int screen, int glass)
    {
        S.GDict s = CreationLab.Cfg()["screens"];
        int front = (int)S.Num.I(s["front_z"]);
        int[] raw = m.xyz.Raw;
        var glow = new bool[m.rgb.Length];
        for (int i = 0; i < m.rgb.Length; i++)
        {
            Vector3Int c = Cell(raw, i);
            if (c.z > front || !Within(c.x, s["x"]) || !Within(c.y, s["y"])) continue;
            bool bar = S.GodotHash.Vector2i(c.y, (int)Math.Floor(c.x / BAR_RUN)) % BAR_GAP != 0;
            glow[i] = c.y % BAR_ROW == 0 && bar;
            m.rgb[i] = glow[i] ? screen : glass;
        }
        return glow;
    }

    static bool Within(int v, S.Variant raw)
    {
        foreach (S.Variant r in (S.GArray<S.Variant>)raw)
        {
            S.GArray<S.Variant> pair = r;
            if (v >= S.Num.I(pair[0]) && v <= S.Num.I(pair[1])) return true;
        }
        return false;
    }
}
