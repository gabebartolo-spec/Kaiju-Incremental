// The dish in Kaiju Creation's cradle (scenes/creation_dish.gd, D-207), in the cradle's cells: the agar as one
// clean surface in its tones (lighter in the middle, a dark ring against the glass), the model's beige inner
// wall turned steel, and the glass petri dish ring with its bright rim and the key lamp's glint. The agar stays
// in the cradle's model here (Godot draws it on its own so the takeover can burn it; that is not drawn yet).
// Sizes and colours: tuning "creation" "lab" "dish" and "colors".
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

public static class CreationDish
{
    // _steel_band: the beige the model paints its inner wall (hue range, the most saturation).
    const float BEIGE_HUE_LO = 0.04f, BEIGE_HUE_HI = 0.22f, BEIGE_SAT = 0.45f;
    // _agar_tone: the rim and middle steps (shares of the glass's inner radius) and the ring's width (cells).
    const float AGAR_RIM = 0.72f, AGAR_MID = 0.4f, AGAR_RING = 1f;
    const double FULL_TURN = 360.0;

    static S.GDict Dish() => CreationLab.Cfg()["dish"];

    static S.GDict Glass() => Dish()["glass"];

    static int Colour(string key) => CreationPaint.Hex(S.Gd.Str(((S.GDict)CreationLab.Cfg()["colors"])[key]));

    static int I(S.Variant v) => (int)S.Num.I(v);

    // clean_dish and agar_node's tones, on the cradle's cells.
    public static void Clean(Dictionary<Vector3Int, int> cradle)
    {
        S.GDict dish = Dish();
        int top = I(dish["surface_y"]) - 1, flat = I(dish["flat"]), r = I(dish["radius"]);
        int agar = Colour("agar");
        foreach (Vector3Int cell in new List<Vector3Int>(cradle.Keys))
        {
            int r2 = cell.x * cell.x + cell.z * cell.z;
            if (r2 <= flat * flat && cell.y > top) cradle.Remove(cell);
            else if (r2 <= r * r && cell.y == top) cradle[cell] = agar;
        }
        for (int x = -r; x <= r; x++)
            for (int z = -r; z <= r; z++)
            {
                var cell = new Vector3Int(x, top, z);
                if (x * x + z * z <= r * r && !cradle.ContainsKey(cell)) cradle[cell] = agar;
            }
        SteelBand(cradle, top);
        GlassRing(cradle, top + 1);
        Tones(cradle, top);
    }

    // _steel_band: pale, unsaturated warm blocks within `band` of the dish turn steel at the same brightness.
    static void SteelBand(Dictionary<Vector3Int, int> cradle, int top)
    {
        S.GDict dish = Dish();
        int reach = I(dish["radius"]) + I(dish["band"]);
        CreationPaint.Hsv(Colour("steel"), out float sh, out float ss, out _);
        foreach (Vector3Int cell in new List<Vector3Int>(cradle.Keys))
        {
            if (cell.x * cell.x + cell.z * cell.z > reach * reach || cell.y < top) continue;
            CreationPaint.Hsv(cradle[cell], out float h, out float s, out float v);
            if (h <= BEIGE_HUE_LO || h >= BEIGE_HUE_HI || s >= BEIGE_SAT) continue;
            Color steel = Color.HSVToRGB(sh, ss, v);
            cradle[cell] = CreationPaint.Pack(Byte(steel.r), Byte(steel.g), Byte(steel.b));
        }
    }

    static int Byte(float c) => Mathf.RoundToInt(Mathf.Clamp01(c) * byte.MaxValue);

    // _glass_ring: a low ring of pale glass inner..outer from the axis, its top row the rim (white in the glint arc).
    static void GlassRing(Dictionary<Vector3Int, int> cradle, int floorY)
    {
        S.GDict g = Glass();
        float r0 = (float)S.Num.F(g["inner"]), r1 = (float)S.Num.F(g["outer"]);
        int h = I(g["height"]), n = Mathf.CeilToInt(r1);
        for (int x = -n; x <= n; x++)
            for (int z = -n; z <= n; z++)
            {
                float r = new Vector2(x, z).magnitude;
                if (r < r0 || r > r1) continue;
                for (int dy = 0; dy < h; dy++)
                {
                    int col = dy < h - 1 ? Colour("glass") : InArc(x, z, g["glint"]) ? Colour("glint") : Colour("glass_rim");
                    cradle[new Vector3Int(x, floorY + dy, z)] = col;
                }
            }
    }

    static bool InArc(int x, int z, S.Variant raw)
    {
        S.GArray<S.Variant> arc = raw;
        double a = Math.Atan2(z, x) * FULL_TURN / (2.0 * Math.PI);
        a = ((a % FULL_TURN) + FULL_TURN) % FULL_TURN;
        return a >= S.Num.F(arc[0]) && a <= S.Num.F(arc[1]);
    }

    // agar_node / _agar_tone: the agar's top cells in three steps from the middle out, a dark ring at the glass.
    static void Tones(Dictionary<Vector3Int, int> cradle, int top)
    {
        float r = (float)S.Num.F(Dish()["radius"]), inner = (float)S.Num.F(Glass()["inner"]);
        foreach (Vector3Int cell in new List<Vector3Int>(cradle.Keys))
        {
            float d = new Vector2(cell.x, cell.z).magnitude;
            if (cell.y != top || d > r) continue;
            cradle[cell] = d >= inner - AGAR_RING ? Colour("agar_ring")
                : d > inner * AGAR_RIM ? Colour("agar_rim")
                : d > inner * AGAR_MID ? Colour("agar_mid") : Colour("agar");
        }
    }
}
