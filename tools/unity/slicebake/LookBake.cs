// The view-side helpers the slice export reads (scenes/look.gd, scenes/window_palette.gd,
// scenes/voxel_ao.gd, Godot's Color), with Godot's 32-bit colour arithmetic.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using Kaiju.Sim;

// Godot's Color: 32-bit channels, its operations in 32-bit floats (core/math/color.h).
struct GColor
{
    public float r, g, b, a;
    public GColor(float r, float g, float b, float a) { this.r = r; this.g = g; this.b = b; this.a = a; }

    public static readonly GColor Magenta = new GColor(1f, 0f, 1f, 1f);

    // Color("rrggbb") / Color("rrggbbaa"), each channel n / 255.
    public static GColor Hex(string text)
    {
        string h = text.StartsWith("#", StringComparison.Ordinal) ? text.Substring(1) : text;
        float P(int at) => Convert.ToInt32(h.Substring(at, 2), 16) / 255f;
        return new GColor(P(0), P(2), P(4), h.Length >= 8 ? P(6) : 1f);
    }

    public GColor Lightened(double amount)
    {
        float t = (float)amount;
        return new GColor(r + (1f - r) * t, g + (1f - g) * t, b + (1f - b) * t, a);
    }

    public GColor Darkened(double amount)
    {
        float t = (float)amount;
        return new GColor(r * (1f - t), g * (1f - t), b * (1f - t), a);
    }

    public GColor Lerp(GColor to, double weight)
    {
        float w = (float)weight;
        return new GColor(r + w * (to.r - r), g + w * (to.g - g), b + w * (to.b - b), a + w * (to.a - a));
    }

    // color.h: (c + 0.055) and its scale are double literals, so that part runs in doubles.
    static float Linear(float c) =>
        c < 0.04045f ? c * (1f / 12.92f) : MathF.Pow((float)((c + 0.055) * (1.0 / (1.0 + 0.055))), 2.4f);

    public GColor SrgbToLinear() => new GColor(Linear(r), Linear(g), Linear(b), a);

    static byte Eight(float c) => (byte)Math.Clamp(MathF.Round(c * 255f, MidpointRounding.AwayFromZero), 0f, 255f);
    public byte R8 => Eight(r);
    public byte G8 => Eight(g);
    public byte B8 => Eight(b);
    public byte A8 => Eight(a);
}

// scenes/look.gd
static class Look
{
    public static double Value(string key) => Num.F(Content.Look().Get(key, 0.0));
    public static GColor Color(string key) => GColor.Hex(Gd.Str(Content.Look().Get(key, "ff00ff")));

    public static List<GColor> Styles()
    {
        var o = new List<GColor>();
        GArray<Variant> raw = Content.Look().Get("styles", new GArray<Variant>());
        foreach (Variant hex in raw) o.Add(GColor.Hex(Gd.Str(hex)));
        return o;
    }
}

// scenes/window_palette.gd: what the slice needs of it.
static class WindowPalette
{
    // Colours the shader holds (window_palette.gdshaderinc WINDOW_PALETTE_MAX).
    const int MAX = 8;
    // A lit window's colour alpha: the glow flag plus a tag the shader tells from neon (alpha 0).
    public const double TAG = 1.0 / 255.0;

    public static bool On() => Look.Value("window_palette_on") > 0.5;

    static List<Variant> Entries()
    {
        GArray<Variant> raw = Content.Look().Get("window_lit_palette", new GArray<Variant>());
        var o = new List<Variant>();
        for (long i = 0; i < Math.Min(raw.Size(), MAX); i++) o.Add(raw[i]);
        return o;
    }

    // The palette as linear colours (Vector3, 32-bit parts).
    public static List<float[]> Colours()
    {
        var o = new List<float[]>();
        foreach (Variant entry in Entries())
        {
            GColor c = GColor.Hex(Gd.Str(entry[0L])).SrgbToLinear();
            o.Add(new[] { c.r, c.g, c.b });
        }
        return o;
    }

    // Each entry's cumulative share (a PackedFloat32Array of a double running total).
    public static List<float> WeightEnds()
    {
        var o = new List<float>();
        double total = 0.0;
        foreach (Variant entry in Entries())
        {
            total += Num.F(entry[1L]);
            o.Add((float)total);
        }
        return o;
    }

    public static float[] Gain()
    {
        GArray<Variant> raw = Content.Look().Get("window_lit_gain", Gd.Arr(1.0, 1.0));
        return new[] { (float)Num.F(raw[0]), (float)Num.F(raw[1]) };
    }

    // (bays, floors) one lit window spans above the ground floor (BuildingLayout's lit rolls).
    public static float[] UnitOf(RampageSim.Building b)
    {
        bool plain = b.landmark == "" && b.hazard == "" && !b.IsSpan();
        if (plain && b.style % 4 == BuildingLayout.GLASS) return new[] { 2f, 0.5f };
        return new[] { 1f, 1f };
    }

    // Where the city's lit-window grid starts for this building.
    public static float[] AlignOf(RampageSim.Building b, float[] unit) => new[]
    {
        (float)Fposmod(b.x - b.w * 0.5, unit[0]),
        (float)Fposmod(b.z - b.d * 0.5, unit[0]),
    };

    // Godot's fposmod ends with `value += 0.0`, which turns -0.0 into 0.0; the sim runtime's
    // Gd.Fposmod leaves -0.0, and the stored float's sign bit then differs.
    static double Fposmod(double x, double y) => Gd.Fposmod(x, y) + 0.0;
}

// scenes/voxel_ao.gd: the finish tables.
static class VoxelAO
{
    static readonly string[] FINISHES = { "rough", "glass", "metal" };
    static readonly (string, string)[] DRAWN_AS = { ("lit", "window"), ("shop_lit", "shop") };

    static long FinishOf(GDict m) => Math.Max(0, Array.IndexOf(FINISHES, Gd.Str(m.Get("finish", "rough"))));

    public static Dictionary<string, long> FinishTable()
    {
        var o = new Dictionary<string, long>();
        foreach (GDict m in Content.Materials()) o[Gd.Str(m["name"])] = FinishOf(m);
        foreach ((string key, string drawn) in DRAWN_AS) o[key] = o.TryGetValue(drawn, out long f) ? f : 0;
        return o;
    }

    public static byte[] FinishByLook(int lit, int shopLit)
    {
        var o = new byte[256];
        foreach (GDict m in Content.Materials()) o[Num.I(m["id"])] = (byte)FinishOf(m);
        Dictionary<string, long> drawn = FinishTable();
        o[lit] = (byte)drawn["lit"];
        o[shopLit] = (byte)drawn["shop_lit"];
        return o;
    }
}

// Constants the export reads from scenes/ GDScript (the scripts are the source; never copied here).
static class GdConst
{
    public static double ModelHeight() => Read("scenes/kaiju_model.gd", "MODEL_HEIGHT");

    static double Read(string script, string name)
    {
        string text = File.ReadAllText(Path.Combine(Kaiju.Sim.FileAccess.Root, script));
        Match m = Regex.Match(text, @"^const\s+" + name + @"\s*:?=\s*([-0-9.eE+]+)\s*$", RegexOptions.Multiline);
        if (!m.Success) throw new InvalidOperationException($"slicebake: no const {name} in {script}");
        return Strtod.Parse(m.Groups[1].Value);
    }
}
