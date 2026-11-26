// The title's smoke noise (Sim/GodotNoise.cs; scenes/title_sky_smoke.gd noise_texture): FastNoiseLite simplex
// smooth, frequency 0.012, 4 octaves, seed 7, through get_seamless_image(256, 256). The expected values come
// from Godot's own C++ (thirdparty/misc/FastNoiseLite.h and modules/noise/noise.h, built with g++ on
// 2026-11-26): raw noise at two points, the image's sum and ten pixels.
using System;
using Kaiju.Sim;

static class NoiseCheck
{
    const int SIDE = 256, SEED = 7, OCTAVES = 4, SUM = 8129152, SUM_SLACK = 64, PIXEL_SLACK = 1;
    const float FREQ = 0.012f, LACUNARITY = 2f, GAIN = 0.5f, SKIRT = 0.1f, RAW_SLACK = 1e-5f;
    static readonly (int x, int y, int v)[] PIXELS =
    {
        (0, 0, 172), (255, 255, 175), (128, 128, 96), (140, 135, 170), (130, 10, 80),
        (10, 140, 151), (64, 200, 146), (200, 64, 169), (255, 0, 179), (77, 151, 78),
    };
    static int failed, checks;

    public static int Run()
    {
        failed = 0;
        checks = 0;
        Check(Math.Abs(Raw(100, 37) - -0.484187484f) < RAW_SLACK, $"noise at (100, 37): {Raw(100, 37)}");
        Check(Math.Abs(Raw(0, 0)) < RAW_SLACK, $"noise at the origin is 0: {Raw(0, 0)}");
        byte[] img = GodotNoise.SeamlessImage(SIDE, SIDE, SEED, FREQ, OCTAVES, LACUNARITY, GAIN, SKIRT);
        long sum = 0;
        foreach (byte b in img) sum += b;
        Check(Math.Abs(sum - SUM) <= SUM_SLACK, $"seamless image sum {sum} (Godot {SUM})");
        foreach ((int x, int y, int v) in PIXELS)
            Check(Math.Abs(img[y * SIDE + x] - v) <= PIXEL_SLACK, $"pixel ({x}, {y}) = {img[y * SIDE + x]} (Godot {v})");
        Check(Seam(img) < Middle(img), $"the tile's edges meet: seam step {Seam(img)} under the middle's {Middle(img)}");
        Console.WriteLine(failed == 0 ? $"noise: ok ({checks} checks)" : $"noise: {failed} of {checks} failed");
        return failed;
    }

    static float Raw(int x, int y) => GodotNoise.SimplexSmooth(x, y, SEED, FREQ, OCTAVES, LACUNARITY, GAIN);

    // Mean step across the wrap (last column to first, last row to first) against the mean step between the
    // two middle rows and columns' neighbours: a tile that wraps cleanly steps no more at its edge.
    static double Seam(byte[] img) => Step(img, SIDE - 1, 0);

    static double Middle(byte[] img) => Step(img, SIDE / 2 - 1, SIDE / 2) + PIXEL_SLACK;

    static double Step(byte[] img, int a, int b)
    {
        double total = 0;
        for (int k = 0; k < SIDE; k++)
            total += Math.Abs(img[k * SIDE + a] - img[k * SIDE + b]) + Math.Abs(img[a * SIDE + k] - img[b * SIDE + k]);
        return total / (2 * SIDE);
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL noise: " + what);
    }
}
