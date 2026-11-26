// What creation_set.gd does to a lab prop's colours before it is built: read's despeckle (lone off-colour
// blocks take their neighbours' average), the monitors' screen_color (the glass inside the data's rectangles
// turns dark green with rows of lit readout bars), the rack's vial_color (each titan's serum glowing in its
// genome's colour, a needle port over its vial) and the canister's Special K (glowing violet, a port in its lid).
// The serums and the Special K leave their props here, for CreationLiquid to drain. Works on a copy:
// ModelColors' cache is shared.
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

    // A model as cell -> colour (and back), for the paints that cut or add cells.
    public static Dictionary<Vector3Int, int> Cells(ModelColors.Model m)
    {
        var cells = new Dictionary<Vector3Int, int>();
        int[] raw = m.xyz.Raw;
        for (int i = 0; i < m.rgb.Length; i++) cells[Cell(raw, i)] = m.rgb[i];
        return cells;
    }

    public static ModelColors.Model Model(Dictionary<Vector3Int, int> cells, HashSet<Vector3Int> glowing, out bool[] glow)
    {
        var xyz = new S.PackedInt32Array();
        xyz.Resize(cells.Count * 3);
        int[] raw = xyz.Raw;
        var rgb = new int[cells.Count];
        glow = new bool[cells.Count];
        int i = 0;
        foreach (KeyValuePair<Vector3Int, int> cell in cells)
        {
            raw[i * 3] = cell.Key.x;
            raw[i * 3 + 1] = cell.Key.y;
            raw[i * 3 + 2] = cell.Key.z;
            glow[i] = glowing != null && glowing.Contains(cell.Key);
            rgb[i++] = cell.Value;
        }
        return new ModelColors.Model { xyz = xyz, rgb = rgb };
    }

    public static void Hsv(int c, out float h, out float s, out float v) => Color.RGBToHSV(Rgb(c), out h, out s, out v);

    static int Lab(string key) => Hex(S.Gd.Str(((S.GDict)CreationLab.Cfg()["colors"])[key]));

    static int I(S.Variant v) => (int)S.Num.I(v);

    static int I(S.GArray<S.Variant> a, int k) => (int)S.Num.I(a[k]);

    // creation_set.gd paint(rack, vial_color) and take_liquid: the port over each titan's vial, and its serum moved
    // out of the rack; returns each titan's serum, cell -> the dark glass it shows drained (CreationLiquid).
    public static Dictionary<int, Dictionary<Vector3Int, int>> Rack(Dictionary<Vector3Int, int> rack, IList<CreationTitan> titans)
    {
        S.GDict v = CreationLab.Cfg()["vials"];
        S.GArray<S.Variant> by = v["box_y"], slots = v["titan_slots"];
        var glowing = new HashSet<Vector3Int>();
        foreach (Vector3Int cell in new List<Vector3Int>(rack.Keys))
        {
            int col = rack[cell];
            Hsv(col, out _, out _, out float value);
            if (cell.y > I(by, 1) && value < S.Num.F(v["cap_dark"])) rack[cell] = Lab("rack_cap");
            else if (Liquid(col, v) || HelixPrint(cell, col, v))
            {
                int titan = TitanIn(Slot(cell, v), slots);
                bool shown = titan >= 0 && titan < titans.Count;
                rack[cell] = shown ? Hex(titans[titan].Genome) : Lab("locked");
                if (shown) glowing.Add(cell);
            }
        }
        var serums = new Dictionary<int, Dictionary<Vector3Int, int>>();
        for (int t = 0; t < titans.Count && t < slots.Size(); t++)
        {
            int vial = I(slots, t);
            S.GArray<S.Variant> xs = ((S.GArray<S.Variant>)v["columns_x"])[vial];
            S.GArray<S.Variant> zs = v["column_z"];
            var centre = new Vector2(I(xs, 0) + I(xs, 1), I(zs, 0) + I(zs, 1)) * 0.5f;
            Port(rack, glowing, centre, (float)S.Num.F(v["port_radius"]), I(v["port_from_y"]));
            serums[t] = Take(rack, glowing, cell => Slot(cell, v) == vial);
        }
        return serums;
    }

    // take_liquid's tail: the glowing cells `which` picks leave `cells`; returns them as cell -> the drained glass.
    static Dictionary<Vector3Int, int> Take(Dictionary<Vector3Int, int> cells, HashSet<Vector3Int> glowing, Func<Vector3Int, bool> which)
    {
        var empties = new Dictionary<Vector3Int, int>();
        int glass = Lab("locked");
        foreach (Vector3Int cell in new List<Vector3Int>(glowing))
        {
            if (!which(cell)) continue;
            empties[cell] = glass;
            cells.Remove(cell);
            glowing.Remove(cell);
        }
        return empties;
    }

    // take_liquid / take_canister_liquid: the cells within `radius` of the axis at `centre`, from `fromY` up, go.
    static void Port(Dictionary<Vector3Int, int> cells, HashSet<Vector3Int> glowing, Vector2 centre, float radius, int fromY)
    {
        foreach (Vector3Int cell in new List<Vector3Int>(cells.Keys))
        {
            if (cell.y < fromY || Vector2.Distance(new Vector2(cell.x, cell.z), centre) > radius) continue;
            cells.Remove(cell);
            glowing.Remove(cell);
        }
    }

    static bool Liquid(int col, S.GDict v)
    {
        Hsv(col, out float h, out float s, out float value);
        S.GArray<S.Variant> hues = v["hue_range"];
        return s > S.Num.F(v["min_saturation"]) && value > S.Num.F(v["min_value"]) && h > S.Num.F(hues[0]) && h < S.Num.F(hues[1]);
    }

    // _helix_print: the model's pale DNA print, inside the liquid columns only.
    static bool HelixPrint(Vector3Int cell, int col, S.GDict v)
    {
        S.GArray<S.Variant> by = v["box_y"], bz = v["column_z"];
        bool inside = cell.y >= I(by, 0) && cell.y <= I(by, 1) && Within(cell.x, v["columns_x"]) && cell.z >= I(bz, 0) && cell.z <= I(bz, 1);
        Hsv(col, out _, out float s, out float value);
        return inside && value > S.Num.F(v["print_value"]) && s < S.Num.F(v["min_saturation"]);
    }

    // slot: which of the rack's three vials a cell belongs to (0 = the left vial seen from the front).
    static int Slot(Vector3Int cell, S.GDict v) => cell.x > I(v["split_hi"]) ? 0 : cell.x >= I(v["split_lo"]) ? 1 : 2;

    static int TitanIn(int vial, S.GArray<S.Variant> slots)
    {
        for (int i = 0; i < slots.Size(); i++)
            if (I(slots, i) == vial) return i;
        return -1;
    }

    // take_canister_liquid: the lid's port cut, and the violet glass moved out of the canister; returns it as
    // cell -> the dark glass it shows once drawn (CreationLiquid fills it with Special K).
    public static Dictionary<Vector3Int, int> Canister(Dictionary<Vector3Int, int> can)
    {
        S.GDict c = CreationLab.Cfg()["canister"];
        S.GArray<S.Variant> hues = c["hue"];
        var glowing = new HashSet<Vector3Int>();
        foreach (Vector3Int cell in new List<Vector3Int>(can.Keys))
        {
            Hsv(can[cell], out float h, out float s, out _);
            if (h <= S.Num.F(hues[0]) || h >= S.Num.F(hues[1]) || s <= S.Num.F(c["min_saturation"])) continue;
            glowing.Add(cell);
        }
        Port(can, glowing, Vector2.zero, (float)S.Num.F(c["port_radius"]), I(c["port_from_y"]));
        return Take(can, glowing, _ => true);
    }

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
