// Godot's FastNoiseLite for what the game draws with it (D-470 U5): OpenSimplex2S ("simplex smooth") with FBm
// fractals, and Noise.get_seamless_image's quadrant swap and skirt blend, so the title's smoke and the
// colossus's smog read the same texture Godot makes. Sources: thirdparty/misc/FastNoiseLite.h (MIT License,
// Copyright (c) 2023 Jordan Peck, Copyright (c) 2023 Contributors) and modules/noise/noise.{h,cpp}
// (Godot Engine contributors; Juan Linietsky, Ariel Manzur; notice in Runtime/LICENSE_Godot.txt). Floats as
// Godot's single-precision build has them; checked against the C++ in SimTests/NoiseCheck.cs.
using System;

namespace Kaiju.Sim
{
    public static class GodotNoise
    {
        const int PrimeX = 501125321, PrimeY = 1136930381;
        const int HashMul = 0x27d4eb2d, HashShift = 15, GradMask = 127 << 1;
        const float Sqrt3 = 1.7320508075688772935274463415059f;
        const float F2 = 0.5f * (Sqrt3 - 1f), G2 = (3f - Sqrt3) / 6f;
        const float Reach = 2f / 3f, Scale = 18.24196194486065f;
        // Gradients2D: 24 directions 15 degrees apart from 7.5, five times over, then 8 from 22.5, 45 apart.
        const int Wheel = 24, Turns = 5, Diagonals = 8;
        const double WheelStart = 7.5, WheelStep = 15.0, DiagStart = 22.5, DiagStep = 45.0;
        // get_seamless_image: the skirt's blend ramp and 8-bit alpha.
        const float RampLo = 0.1f, RampHi = 0.9f, Byte = 255f;
        const int AlphaFull = 256;

        static readonly float[] Grad = Gradients();

        static float[] Gradients()
        {
            var g = new float[(Wheel * Turns + Diagonals) * 2];
            for (int k = 0; k < Wheel * Turns; k++) Dir(g, k, WheelStart + WheelStep * (k % Wheel));
            for (int k = 0; k < Diagonals; k++) Dir(g, Wheel * Turns + k, DiagStart + DiagStep * k);
            return g;
        }

        static void Dir(float[] g, int k, double degrees)
        {
            double a = degrees * Math.PI / 180.0;
            g[k * 2] = (float)Math.Sin(a);
            g[k * 2 + 1] = (float)Math.Cos(a);
        }

        static int FastFloor(float f) => f >= 0 ? (int)f : (int)f - 1;

        static float GradCoord(int seed, int xPrimed, int yPrimed, float xd, float yd)
        {
            int hash = unchecked((seed ^ xPrimed ^ yPrimed) * HashMul);
            hash ^= hash >> HashShift;
            hash &= GradMask;
            return xd * Grad[hash] + yd * Grad[hash | 1];
        }

        static float Corner(float x, float y, int seed, int i, int j)
        {
            float a = Reach - x * x - y * y;
            return a > 0 ? a * a * (a * a) * GradCoord(seed, i, j, x, y) : 0f;
        }

        // FastNoiseLite::SingleOpenSimplex2S, 2D, on skewed coordinates.
        static float OpenSimplex2S(int seed, float x, float y)
        {
            int i = FastFloor(x), j = FastFloor(y);
            float xi = x - i, yi = y - j;
            unchecked
            {
                i *= PrimeX;
                j *= PrimeY;
                int i1 = i + PrimeX, j1 = j + PrimeY;
                float t = (xi + yi) * G2;
                float x0 = xi - t, y0 = yi - t;
                float a0 = Reach - x0 * x0 - y0 * y0;
                float value = a0 * a0 * (a0 * a0) * GradCoord(seed, i, j, x0, y0);
                float a1 = 2f * (1f - 2f * G2) * (1f / G2 - 2f) * t + (-2f * (1f - 2f * G2) * (1f - 2f * G2) + a0);
                float x1 = x0 - (1f - 2f * G2), y1 = y0 - (1f - 2f * G2);
                value += a1 * a1 * (a1 * a1) * GradCoord(seed, i1, j1, x1, y1);
                float xmyi = xi - yi;
                if (t > G2)
                {
                    value += xi + xmyi > 1
                        ? Corner(x0 + (3f * G2 - 2f), y0 + (3f * G2 - 1f), seed, i + (PrimeX << 1), j + PrimeY)
                        : Corner(x0 + G2, y0 + (G2 - 1f), seed, i, j + PrimeY);
                    value += yi - xmyi > 1
                        ? Corner(x0 + (3f * G2 - 1f), y0 + (3f * G2 - 2f), seed, i + PrimeX, j + (PrimeY << 1))
                        : Corner(x0 + (G2 - 1f), y0 + G2, seed, i + PrimeX, j);
                }
                else
                {
                    value += xi + xmyi < 0
                        ? Corner(x0 + (1f - G2), y0 - G2, seed, i - PrimeX, j)
                        : Corner(x0 + (G2 - 1f), y0 + G2, seed, i + PrimeX, j);
                    value += yi < xmyi
                        ? Corner(x0 - G2, y0 - (G2 - 1f), seed, i, j - PrimeY)
                        : Corner(x0 + G2, y0 + (G2 - 1f), seed, i, j + PrimeY);
                }
                return value * Scale;
            }
        }

        /// FastNoiseLite.get_noise_2d with TYPE_SIMPLEX_SMOOTH, FRACTAL_FBM, no weighting, no domain warp.
        public static float SimplexSmooth(float x, float y, int seed, float frequency, int octaves, float lacunarity, float gain)
        {
            x *= frequency;
            y *= frequency;
            float s = (x + y) * F2;
            x += s;
            y += s;
            float g = Math.Abs(gain), amp = g, fractal = 1f;
            for (int k = 1; k < octaves; k++)
            {
                fractal += amp;
                amp *= g;
            }
            float sum = 0f;
            amp = 1f / fractal;
            for (int k = 0; k < octaves; k++)
            {
                sum += OpenSimplex2S(seed++, x, y) * amp;
                x *= lacunarity;
                y *= lacunarity;
                amp *= gain;
            }
            return sum;
        }

        /// Noise.get_seamless_image(width, height) with the defaults (no invert, 2D, skirt 0.1, normalised), for
        /// FastNoiseLite simplex smooth FBm: the L8 bytes, row by row.
        public static byte[] SeamlessImage(int width, int height, int seed, float frequency, int octaves, float lacunarity, float gain, float skirt)
        {
            var tile = new Tile(width, height, skirt);
            tile.src = Normalised(tile.srcW, tile.srcH, (x, y) => SimplexSmooth(x, y, seed, frequency, octaves, lacunarity, gain));
            tile.Swap();
            tile.Skirts();
            tile.Centre();
            return tile.dst;
        }

        // Noise::_generate_seamless_image<uint8_t>: the source has a skirt (a tenth more) past the right and
        // bottom edges; the quadrants swap so the edges meet, and the skirt is blended over the middle seams.
        sealed class Tile
        {
            public readonly int w, h, sw, sh, srcW, srcH, hw, hh, ex, ey;
            public byte[] src;
            public readonly byte[] dst;

            public Tile(int width, int height, float skirt)
            {
                w = width;
                h = height;
                sw = Math.Max(1, (int)(width * skirt));
                sh = Math.Max(1, (int)(height * skirt));
                srcW = w + sw;
                srcH = h + sh;
                hw = (int)(w * 0.5f);
                hh = (int)(h * 0.5f);
                ex = hw + sw;
                ey = hh + sh;
                dst = new byte[w * h];
            }

            // img_buff: a half offset; DEFAULT wraps by the source's size, ALT_X/ALT_Y/ALT_XY by the output's.
            byte Src(int x, int y, bool altX, bool altY) => src[(x + hw) % (altX ? w : srcW) + (y + hh) % (altY ? h : srcH) * srcW];

            public void Swap()
            {
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                        dst[y * w + x] = Src(x, y, true, true);
            }

            // The vertical skirt over the middle column seam, then the horizontal one, each skipping the centre.
            public void Skirts()
            {
                for (int x = hw; x < ex; x++)
                {
                    int a = Alpha(x - hw, sw);
                    for (int y = 0; y < h; y++)
                    {
                        if (y == hh) y = ey - 1;
                        else dst[y * w + x] = Blend(dst[y * w + x], Src(x, y, false, true), a);
                    }
                }
                for (int y = hh; y < ey; y++)
                {
                    int a = Alpha(y - hh, sh);
                    for (int x = 0; x < w; x++)
                    {
                        if (x == hw) x = ex - 1;
                        else dst[y * w + x] = Blend(dst[y * w + x], Src(x, y, true, false), a);
                    }
                }
            }

            public void Centre()
            {
                for (int y = hh; y < ey; y++)
                    for (int x = hw; x < ex; x++)
                    {
                        int xa = Alpha(x - hw, sw), ya = Alpha(y - hh, sh);
                        byte top = Blend(Src(x, y, true, false), Src(x, y, false, false), xa);
                        byte bottom = Blend(Src(x, y, true, true), Src(x, y, false, true), xa);
                        dst[y * w + x] = Blend(bottom, top, ya);
                    }
            }
        }

        // Noise::_get_image, normalised: min..max to 0..255, truncated.
        static byte[] Normalised(int w, int h, Func<float, float, float> noise)
        {
            var v = new float[w * h];
            float lo = float.MaxValue, hi = -float.MaxValue;
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    float n = noise(x, y);
                    v[y * w + x] = n;
                    lo = Math.Min(lo, n);
                    hi = Math.Max(hi, n);
                }
            var px = new byte[v.Length];
            if (hi == lo) return px;
            for (int i = 0; i < v.Length; i++) px[i] = (byte)Math.Clamp((v[i] - lo) / (hi - lo) * Byte, 0f, Byte);
            return px;
        }

        // 255 * (1 - smoothstep(0.1, 0.9, step / skirt)), truncated.
        static int Alpha(int step, int skirt)
        {
            float s = Math.Clamp(((float)step / skirt - RampLo) / (RampHi - RampLo), 0f, 1f);
            return (int)(Byte * (1f - s * s * (3f - 2f * s)));
        }

        // Noise::_alpha_blend<uint8_t>.
        static byte Blend(byte bg, byte fg, int alpha) => (byte)(((alpha + 1) * fg + (AlphaFull - alpha) * bg) >> 8);
    }
}
