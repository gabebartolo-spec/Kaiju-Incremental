// The leader's paint rule (scenes/helicopter_model.gd _paint), kept free of UnityEngine so
// unity/SimTests/VipCheck.cs holds it to the rule. Colours are 0xRRGGBB as ModelColors reads them.
public static class VipPaint
{
    // Godot's Color.get_luminance weights.
    const float LUM_R = 0.2126f, LUM_G = 0.7152f, LUM_B = 0.0722f;
    // scenes/helicopter_model.gd _paint: a painted voxel keeps this much of its own light and shade.
    const float SHADE_MIN = 0.8f, SHADE_MAX = 1.15f, SHADE_FLOOR = 0.01f;

    public static float Luminance(int rgb) => (((rgb >> 16) & 255) * LUM_R + ((rgb >> 8) & 255) * LUM_G + (rgb & 255) * LUM_B) / 255f;

    // Repaints `rgb` in place (one colour per voxel of `xyz`, three ints a voxel): every voxel takes `paint`
    // scaled by its own shade against the part's mean, the band at bandFrom..bandTo of the part's height takes
    // `band`, and voxels darker than `dark` (glass, skids) are left alone. Returns which voxels glow: the painted ones.
    public static bool[] Paint(int[] xyz, int[] rgb, int paint, int band, float dark, float bandFrom, float bandTo)
    {
        int count = rgb.Length;
        var glow = new bool[count];
        if (count == 0) return glow;
        int low = int.MaxValue, high = int.MinValue;
        float shade = 0f;
        for (int i = 0; i < count; i++)
        {
            int y = xyz[i * 3 + 1];
            if (y < low) low = y;
            if (y > high) high = y;
            shade += Luminance(rgb[i]) / count;
        }
        float from = low + (high - low) * bandFrom, to = low + (high - low) * bandTo;
        for (int i = 0; i < count; i++)
        {
            float lum = Luminance(rgb[i]);
            if (lum < dark) continue;
            int y = xyz[i * 3 + 1];
            int c = y >= from && y <= to ? band : paint;
            float lit = lum / (shade > SHADE_FLOOR ? shade : SHADE_FLOOR);
            lit = lit < SHADE_MIN ? SHADE_MIN : lit > SHADE_MAX ? SHADE_MAX : lit;
            rgb[i] = Channel((c >> 16) & 255, lit) << 16 | Channel((c >> 8) & 255, lit) << 8 | Channel(c & 255, lit);
            glow[i] = true;
        }
        return glow;
    }

    static int Channel(int value, float lit)
    {
        int v = (int)(value * lit + 0.5f);
        return v > 255 ? 255 : v;
    }
}
