// The globe's maths on the Tellus Nova mask (scenes/globe_view.gd uv_of, point_of, id_at_uv and
// scenes/globe_anchors.gd): one byte per texel, 0 sea, 1..7 the continents in data order, row 0 at the top.
// Plain C#: the Unity side decodes the PNG and hands the bytes over.
using System;

namespace Kaiju.Game
{
    public static class GlobeMath
    {
        // globe_anchors.gd ANCHOR_STEP: the mask is sampled every this many texels.
        public const int ANCHOR_STEP = 4;

        const double TAU = Math.PI * 2.0;

        // globe_view.gd uv_of: a point on the unit sphere (globe space) to the mask's uv.
        public static void UvOf(double x, double y, double z, out double u, out double v)
        {
            double len = Math.Sqrt(x * x + y * y + z * z);
            if (len > 0.0) { x /= len; y /= len; z /= len; }
            double turn = Math.Atan2(x, z) / TAU;
            u = turn - Math.Floor(turn);  // fposmod(turn, 1)
            v = Math.Acos(Math.Max(-1.0, Math.Min(1.0, y))) / Math.PI;
        }

        // globe_view.gd point_of: the mask's uv to the point on the unit sphere.
        public static void PointOf(double u, double v, out double x, out double y, out double z)
        {
            double lon = u * TAU, colat = v * Math.PI;
            x = Math.Sin(colat) * Math.Sin(lon);
            y = Math.Cos(colat);
            z = Math.Sin(colat) * Math.Cos(lon);
        }

        // globe_view.gd id_at_uv: the mask value under a uv, clamped to the image.
        public static int IdAtUv(byte[] mask, int width, int height, double u, double v)
        {
            if (mask == null || width <= 0 || height <= 0) return 0;
            int x = Math.Max(0, Math.Min(width - 1, (int)(u * width)));
            int y = Math.Max(0, Math.Min(height - 1, (int)(v * height)));
            return mask[y * width + x];
        }

        // globe_anchors.gd anchors: per mask value 1..count, the inland sample (all 8 neighbours a step away
        // are the same continent) nearest the continent's mean direction, as a uv on the mask. Entry 0 and a
        // continent with no inland sample are null.
        public static double[][] AnchorUvs(byte[] mask, int width, int height, int count)
        {
            double[][] outUv = new double[count + 1][];
            if (mask == null || width <= 0 || height <= 0) return outUv;
            int s = ANCHOR_STEP;
            double[,] means = new double[count + 1, 3];
            // Pass 1: each continent's mean direction over every sample.
            for (int y = s; y < height - s; y += s)
            {
                for (int x = 0; x < width; x += s)
                {
                    int v = mask[y * width + x];
                    if (v == 0 || v > count) continue;
                    PointOf((x + 0.5) / width, (y + 0.5) / height, out double px, out double py, out double pz);
                    means[v, 0] += px; means[v, 1] += py; means[v, 2] += pz;
                }
            }
            for (int v = 1; v <= count; v++)
            {
                double len = Math.Sqrt(means[v, 0] * means[v, 0] + means[v, 1] * means[v, 1] + means[v, 2] * means[v, 2]);
                if (len > 0.0) { means[v, 0] /= len; means[v, 1] /= len; means[v, 2] /= len; }
            }
            // Pass 2: the inland sample facing that mean most (best_dot starts at -2 in Godot).
            double[] best = new double[count + 1];
            for (int v = 0; v <= count; v++) best[v] = -2.0;
            for (int y = s; y < height - s; y += s)
            {
                for (int x = 0; x < width; x += s)
                {
                    int v = mask[y * width + x];
                    if (v == 0 || v > count || !Inland(mask, width, height, x, y, v, s)) continue;
                    double u = (x + 0.5) / width, w = (y + 0.5) / height;
                    PointOf(u, w, out double px, out double py, out double pz);
                    double dot = px * means[v, 0] + py * means[v, 1] + pz * means[v, 2];
                    if (dot > best[v])
                    {
                        best[v] = dot;
                        outUv[v] = new[] { u, w };
                    }
                }
            }
            return outUv;
        }

        // All 8 neighbours `s` texels away hold `v`; x wraps round the globe, y must stay on the image.
        static bool Inland(byte[] mask, int width, int height, int x, int y, int v, int s)
        {
            for (int dy = -s; dy <= s; dy += s)
            {
                for (int dx = -s; dx <= s; dx += s)
                {
                    if (dx == 0 && dy == 0) continue;
                    int ny = y + dy;
                    if (ny < 0 || ny >= height) return false;
                    int nx = ((x + dx) % width + width) % width;
                    if (mask[ny * width + nx] != v) return false;
                }
            }
            return true;
        }

        // globe_land.gdshader `edge`: a texel is coastline when a neighbour `texels` away differs (x wraps as
        // the texture repeats; y is held on the image).
        public static bool Coast(byte[] mask, int width, int height, int x, int y, int texels)
        {
            int id = mask[y * width + x];
            int l = ((x - texels) % width + width) % width, r = (x + texels) % width;
            int up = Math.Max(0, y - texels), down = Math.Min(height - 1, y + texels);
            return mask[y * width + l] != id || mask[y * width + r] != id || mask[up * width + x] != id || mask[down * width + x] != id;
        }
    }
}
