using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// One column of a rubble shape on the debris grid: where it stands (Godot axes, a cell's centre), how many
// grains high, and the colour block it belongs to.
public struct RubbleColumn
{
    public double x, z;
    public int grains, bx, bz;
}

// The numbers a rubble shape is built from: lengths in sim units, as RubbleView reads them from the tuning.
public sealed class RubbleCfg
{
    public double cell, grain, share, res;
    public double peakBase, peakPerTier, spillCells, wobble, wobbleSwing, wobbleJitter, fallPower, heightJitter;
    public double stripHeight, lump, blockX, blockY, blockZ;
    public double pileBack, pileReach, pileReachMax, pilePeak;
}

// Rubble shapes as plain maths, no engine: scenes/ruin.gd heap and strip_plan and scenes/landmark_rubble.gd
// pile, laid on the debris heightfield's grid instead of as voxels (D-474). Columns stand on cell centres;
// the grid's lines are multiples of cfg.cell. Seeded and cosmetic; Godot's hash() is not reproduced, so the
// block pattern differs from Godot's.
public static class RubbleShape
{
    // scenes/ruin.gd heap: one colour key per 3x2x3 voxel block, the outline's three lobes.
    public const int HEAP_BLOCK = 3, HEAP_BLOCK_Y = 2;
    const double HEAP_LOBES = 3.0;
    // scenes/ruin.gd strip_plan: vox.salt.
    const int STRIP_SALT = 57;
    // scenes/landmark_rubble.gd pile: its rise, taper, outline and lump literals.
    const double PILE_RISE = 0.6, PILE_TAPER = 1.5, PILE_WOBBLE = 0.75, PILE_WOBBLE_SWING = 0.35, PILE_WOBBLE_STEP = 5.0;
    const double PILE_SHIFT = 0.8, PILE_SHIFT_STEP = 7.0, PILE_NARROW = 0.45, PILE_SPAN = 1.2;
    const int PILE_LUMPS = 5, PILE_BLOCK = 3;

    public static uint Hash(int a, int b, int c)
    {
        unchecked
        {
            uint h = (uint)a * 0x9E3779B1u ^ (uint)b * 0x85EBCA6Bu ^ (uint)c * 0xC2B2AE35u;
            h ^= h >> 15;
            h *= 0x2C1B3C6Du;
            h ^= h >> 12;
            h *= 0x297A2D39u;
            h ^= h >> 15;
            return h;
        }
    }

    static int Round(double v) => (int)Math.Round(v, MidpointRounding.AwayFromZero);

    static int FloorDiv(int a, double b) => (int)Math.Floor(a / b);

    static int Grains(RubbleCfg c, double high) => Math.Max(1, Round(high * c.share / c.grain));

    // Which of `keys` colours grain `layer` of a column takes: one per block, never per grain.
    public static int Key(RubbleCfg c, RubbleColumn col, int layer, double blockY, int salt, int keys)
    {
        int y = (int)Math.Floor(layer * c.grain * c.res / Math.Max(1.0, blockY));
        return (int)(Hash(col.bx + salt, y, col.bz) % (uint)keys);
    }

    // The low heap a gone building leaves, spilling past its footprint (Ruin.heap). The rng draws in
    // Godot's order: the outline's jitter for every cell, the height's for every cell inside it.
    public static void Heap(RubbleCfg c, double x, double z, long w, long d, long tier, S.RandomNumberGenerator rng, List<RubbleColumn> into)
    {
        double spill = (c.res + c.spillCells) / c.res;
        double halfW = w * 0.5 + spill, halfD = d * 0.5 + spill;
        double peak = c.peakBase + tier * c.peakPerTier;
        int x0 = (int)Math.Floor((x - halfW) / c.cell), x1 = (int)Math.Ceiling((x + halfW) / c.cell);
        int z0 = (int)Math.Floor((z - halfD) / c.cell), z1 = (int)Math.Ceiling((z + halfD) / c.cell);
        for (int ix = x0; ix < x1; ix++)
        {
            for (int iz = z0; iz < z1; iz++)
            {
                double px = (ix + 0.5) * c.cell, pz = (iz + 0.5) * c.cell;
                double cx = (px - x) / halfW, cz = (pz - z) / halfD;
                double wobble = c.wobble + c.wobbleSwing * Math.Sin(Math.Atan2(cz, cx) * HEAP_LOBES + x) + rng.RandfRange(-c.wobbleJitter, c.wobbleJitter);
                double fall = 1.0 - Math.Sqrt(cx * cx + cz * cz) / wobble;
                if (fall <= 0.0) continue;
                double high = peak * Math.Pow(fall, c.fallPower) + rng.RandfRange(-c.heightJitter, c.heightJitter) / c.res;
                int vx = (int)Math.Floor((px - x) * c.res), vz = (int)Math.Floor((pz - z) * c.res);
                into.Add(new RubbleColumn { x = px, z = pz, grains = Grains(c, Math.Max(high, 1.0 / c.res)), bx = FloorDiv(vx, HEAP_BLOCK), bz = FloorDiv(vz, HEAP_BLOCK) });
            }
        }
    }

    // The pile a toppled tower leaves along the street, highest along its middle (Ruin.strip_plan): big
    // blocks rise or sink together by cfg.lump.
    public static void Strip(RubbleCfg c, double fromX, double fromZ, double toX, double toZ, double width, List<RubbleColumn> into)
    {
        double ax = toX - fromX, az = toZ - fromZ;
        double length = Math.Sqrt(ax * ax + az * az);
        double dx = ax / Math.Max(0.001, length), dz = az / Math.Max(0.001, length);
        double sx = -dz, sz = dx;
        double half = width * 0.5 + 1.0 / c.res;
        Bounds(c, fromX, fromZ, dx, dz, 0.0, length, half, out int x0, out int x1, out int z0, out int z1);
        for (int ix = x0; ix <= x1; ix++)
        {
            for (int iz = z0; iz <= z1; iz++)
            {
                double px = (ix + 0.5) * c.cell, pz = (iz + 0.5) * c.cell;
                double t = (px - fromX) * dx + (pz - fromZ) * dz, s = (px - fromX) * sx + (pz - fromZ) * sz;
                if (t < 0.0 || t >= length || Math.Abs(s) > half) continue;
                double across = Math.Abs(s) / half;
                int tv = (int)Math.Floor(t * c.res), sv = Round(s * c.res);
                int slabX = FloorDiv(tv, c.blockX), slabZ = FloorDiv(sv, c.blockZ);
                double step = ((double)(Hash(slabX, slabZ, STRIP_SALT) % 3u) - 1.0) * c.lump;
                double high = c.stripHeight * (1.0 - across * across) + step + (Hash(tv, sv, STRIP_SALT + 1) % 2u) / c.res;
                into.Add(new RubbleColumn { x = px, z = pz, grains = Grains(c, Math.Max(high, 1.0 / c.res)), bx = slabX, bz = slabZ });
            }
        }
    }

    // The ragged heap a model building's toppled section leaves against its stub (LandmarkRubble.pile):
    // highest at the tipping edge `from`, thinning to nothing a short reach towards `to`.
    public static void Pile(RubbleCfg c, double fromX, double fromZ, double toX, double toZ, double width, List<RubbleColumn> into)
    {
        double ax = toX - fromX, az = toZ - fromZ;
        double length = Math.Sqrt(ax * ax + az * az);
        double dx = ax / Math.Max(0.001, length), dz = az / Math.Max(0.001, length);
        double sx = -dz, sz = dx;
        double reach = Math.Min(length * c.pileReach, c.pileReachMax);
        int seed = (int)(Hash(Round(fromX * 4.0), Round(fromZ * 4.0), 0) & 0x7FFFFFFFu);
        int t0 = -Round(c.pileBack * c.res), t1 = Round(reach * c.res);
        double half = width * 0.5 * c.res;
        Bounds(c, fromX, fromZ, dx, dz, -c.pileBack, reach, width * 0.5 * PILE_SPAN, out int x0, out int x1, out int z0, out int z1);
        for (int ix = x0; ix <= x1; ix++)
        {
            for (int iz = z0; iz <= z1; iz++)
            {
                double px = (ix + 0.5) * c.cell, pz = (iz + 0.5) * c.cell;
                int tv = Round(((px - fromX) * dx + (pz - fromZ) * dz) * c.res), sv = Round(((px - fromX) * sx + (pz - fromZ) * sz) * c.res);
                if (tv < t0 || tv > t1) continue;
                double u = Math.Min(1.0, Math.Max(0.0, tv / (double)Math.Max(1, t1)));
                double rise = Math.Min(1.0, Math.Max(0.0, (tv - t0) / (c.res * PILE_RISE)));
                double top = c.res * c.pilePeak * Math.Pow(1.0 - u, PILE_TAPER) * rise;
                double wobble = PILE_WOBBLE + PILE_WOBBLE_SWING * Noise(seed, tv / PILE_WOBBLE_STEP);
                double shift = (Noise(seed + 7, tv / PILE_SHIFT_STEP) - 0.5) * c.res * PILE_SHIFT;
                double across = Math.Abs(sv - shift) / Math.Max(1.0, half * wobble * (1.0 - PILE_NARROW * u));
                if (across > 1.0) continue;
                double lump = (double)(Hash(tv >> 1, sv >> 1, seed) % (uint)PILE_LUMPS) - (PILE_LUMPS - 1) / 2;
                int high = Round(top * (1.0 - across * across) + lump);
                if (high <= 0) continue;
                into.Add(new RubbleColumn { x = px, z = pz, grains = Grains(c, high / c.res), bx = FloorDiv(tv, PILE_BLOCK), bz = FloorDiv(sv, PILE_BLOCK) });
            }
        }
    }

    // The grid cells a strip from t0 to t1 along (dx, dz), `half` to each side, can touch.
    static void Bounds(RubbleCfg c, double fromX, double fromZ, double dx, double dz, double t0, double t1, double half, out int x0, out int x1, out int z0, out int z1)
    {
        double minX = double.MaxValue, maxX = double.MinValue, minZ = double.MaxValue, maxZ = double.MinValue;
        for (int k = 0; k < 4; k++)
        {
            double t = k < 2 ? t0 : t1, s = k % 2 == 0 ? -half : half;
            double px = fromX + dx * t - dz * s, pz = fromZ + dz * t + dx * s;
            minX = Math.Min(minX, px);
            maxX = Math.Max(maxX, px);
            minZ = Math.Min(minZ, pz);
            maxZ = Math.Max(maxZ, pz);
        }
        x0 = (int)Math.Floor(minX / c.cell) - 1;
        x1 = (int)Math.Floor(maxX / c.cell) + 1;
        z0 = (int)Math.Floor(minZ / c.cell) - 1;
        z1 = (int)Math.Floor(maxZ / c.cell) + 1;
    }

    // Smooth 1D value noise in [0, 1] (scenes/landmark_rubble.gd _noise).
    static double Noise(int seed, double x)
    {
        int k = (int)Math.Floor(x);
        double f = x - k;
        double a = (Hash(seed, k, 0) % 1000u) / 1000.0, b = (Hash(seed, k + 1, 0) % 1000u) / 1000.0;
        return a + (b - a) * (f * f * (3.0 - 2.0 * f));
    }

    // A foot's press on one column (scenes/ruin_yard.gd press, D-245): inside the radius it keeps the share
    // `keep` of its height, for good. Debris.compute's PressHeight kernel is this, on the height grid.
    public static long Pressed(long grains, double dx, double dz, double radius, double keep) =>
        dx * dx + dz * dz <= radius * radius ? (long)Math.Floor(grains * keep) : grains;
}
