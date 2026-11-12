using System;
using S = Kaiju.Sim;

// scenes/look.gd jitter_by: each cell of a voxel model is a touch lighter or darker than its paint, by Godot's own
// hash of the cell and the model's salt, so the same cell gets the same shade in both engines.
// No UnityEngine here: unity/SimTests compiles this file (LightPoolCheck).
public static class VoxelJitter
{
    // look.gd jitter_by: the hash's last three digits, as -1..1.
    const int STEPS = 1000;
    const int CHANNEL = 255;
    // 0xRRGGBB: where red and green sit.
    const int RED = 16, GREEN = 8;

    // rgb is 0xRRGGBB; the cell in Godot's axes; amount is the look's color_noise.
    public static int Shade(int rgb, int x, int y, int z, int salt, double amount)
    {
        if (amount <= 0.0) return rgb;
        uint h = S.GodotHash.Vector4i(x, y, z, salt);
        double t = (h % STEPS) / (double)STEPS * 2.0 - 1.0;
        double by = 1.0 + t * amount;
        return Channel(rgb >> RED, by) << RED | Channel(rgb >> GREEN, by) << GREEN | Channel(rgb, by);
    }

    static int Channel(int value, double by) =>
        (int)Math.Min(CHANNEL, Math.Max(0.0, Math.Round((value & CHANNEL) * by)));
}
