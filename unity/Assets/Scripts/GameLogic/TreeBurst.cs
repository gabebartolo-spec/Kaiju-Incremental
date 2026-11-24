// A crushed tree (scenes/prop_field.gd _burst, _crown; scenes/debris_field.gd _spawn_now): its lowest STUMP cells
// stand, the top one of them showing cut wood; every cell above is gone, and every bark cell and every LEAF_EVERY-th
// leaf cell is thrown as a piece: bark scattered round the trunk and flung toward the game camera, leaves from
// anywhere in the crown, out from the blow. Each piece then takes its size, push, spin and life from its debris
// field's own stream as DebrisField does. Godot axes. Plain C# (System.Numerics) so SimTests/PropCrushCheck.cs walks
// it against Godot's own output. Presentation only: the sim never knows trees exist.
using System;
using System.Collections.Generic;
using N = System.Numerics;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // One drawn (not buried) cell of a tree, in the order Godot indexed it.
    public struct BurstCell
    {
        public N.Vector3 origin;
        public int height;
        public bool bark;
    }

    // One piece thrown: where it starts and its push (DebrisField.spawn's pos and away).
    public struct BurstPiece
    {
        public N.Vector3 from, away;
        public bool bark;
    }

    // PropField.configure's crushed-tree tuning (tree_debris_speed, tree_leaf_speed, tree_leaf_spread).
    public struct BurstTuning
    {
        public float throwSpeed, leafSpeed, leafSpread;
    }

    // DebrisField._spawn_now's draws for one piece: its cube size, starting velocity and spin, and how long it lives
    // before it shrinks away.
    public struct DebrisPiece
    {
        public float size;
        public N.Vector3 velocity, angular;
        public float life;
    }

    public static class TreeBurst
    {
        // prop_field.gd STUMP, LEAF_EVERY, BARK_EVERY.
        public const int STUMP = 2;
        public const int LEAF_EVERY = 4;
        public const int BARK_EVERY = 1;
        // _burst: the golden angle that spreads the bark round the trunk, how many voxels out, and how far toward the
        // camera (+z) and up the bark is flung.
        const double GOLDEN = 2.39996;
        const float BARK_RING = 3f;
        const float BARK_BACK = 1.5f;
        // _burst: a leaf's lean turns this far past its aim, and rises or dips up to LEAN_RISE.
        const double LEAN_TURN = 1.0;
        const float LEAN_RISE = 0.5f;
        const double TAU = 2 * Math.PI;

        // A cell below the stump height stays standing.
        public static bool Stands(int height) => height < STUMP;

        // The stump's top row shows the cut wood (stump_color).
        public static bool CutTop(int height) => height == STUMP - 1;

        // _burst: the pieces a tree at `treeBase` throws when crushed from `at`, appended in Godot's order. `rng` is the
        // field's tree_burst stream, drawn only for leaves.
        public static void Burst(IReadOnlyList<BurstCell> cells, N.Vector3 treeBase, N.Vector3 at, float voxel,
            BurstTuning tuning, S.RandomNumberGenerator rng, List<BurstPiece> pieces)
        {
            N.Vector3 outward = Flat(treeBase - at);
            Crown(cells, out N.Vector3 mid, out float reach);
            N.Vector3 flung = (outward + N.Vector3.UnitZ * BARK_BACK + N.Vector3.UnitY) * tuning.throwSpeed;
            for (int k = 0; k < cells.Count; k++)
            {
                BurstCell cell = cells[k];
                if (Stands(cell.height) || k % (cell.bark ? BARK_EVERY : LEAF_EVERY) != 0) continue;
                if (cell.bark)
                {
                    double turn = k * GOLDEN;
                    N.Vector3 from = cell.origin + new N.Vector3((float)Math.Cos(turn), 0f, (float)Math.Sin(turn)) * voxel * BARK_RING;
                    pieces.Add(new BurstPiece { from = from, away = flung, bark = true });
                    continue;
                }
                double aim = rng.Randf() * TAU;
                N.Vector3 side = new N.Vector3((float)Math.Cos(aim), 0f, (float)Math.Sin(aim));
                N.Vector3 lean = new N.Vector3((float)Math.Cos(aim + LEAN_TURN), (float)rng.RandfRange(-LEAN_RISE, LEAN_RISE),
                    (float)Math.Sin(aim + LEAN_TURN));
                N.Vector3 start = mid + lean * (float)rng.Randf() * reach;
                N.Vector3 away = (outward + N.Vector3.UnitY + side * (float)rng.Randf() * tuning.leafSpread) * tuning.leafSpeed;
                pieces.Add(new BurstPiece { from = start, away = away, bark = false });
            }
        }

        // _crown: the middle of the leaf cells and how far the farthest lies from it.
        static void Crown(IReadOnlyList<BurstCell> cells, out N.Vector3 mid, out float reach)
        {
            N.Vector3 sum = N.Vector3.Zero;
            int count = 0;
            foreach (BurstCell c in cells)
                if (!c.bark)
                {
                    sum += c.origin;
                    count++;
                }
            mid = sum / Math.Max(count, 1);
            reach = 0f;
            foreach (BurstCell c in cells)
                if (!c.bark) reach = Math.Max(reach, N.Vector3.Distance(mid, c.origin));
        }

        // Vector3(x, 0, z).normalized(): zero stays zero.
        static N.Vector3 Flat(N.Vector3 v)
        {
            v.Y = 0f;
            return v.LengthSquared() > 0f ? N.Vector3.Normalize(v) : N.Vector3.Zero;
        }
    }

    public static class DebrisSpawn
    {
        // BuildingVoxels.VOXEL: a debris cube's base size.
        public const float VOXEL = 0.125f;
        // _spawn_now: most pieces (SMALL_SHARE) are a smaller share of the voxel, the rest a whole one.
        const float SMALL_SHARE = 0.8f;
        const float SMALL_MIN = 0.35f;
        const float SMALL_MAX = 0.8f;
        // The impulse is (away + spread) * PUSH times the mass, so it starts at that velocity.
        public const float PUSH = 2.5f;
        const float SPREAD_UP_MIN = 0.1f;
        const float SPREAD_UP_MAX = 0.7f;
        const float SPIN = 6f;
        const float LIFE_MIN = 5f;
        const float LIFE_MAX = 8f;

        // One piece's draws from its field's stream, in _spawn_now's order.
        public static DebrisPiece Draw(S.RandomNumberGenerator rng, float sizeScale, N.Vector3 away)
        {
            float size = VOXEL * (rng.Randf() < SMALL_SHARE ? (float)rng.RandfRange(SMALL_MIN, SMALL_MAX) : 1f);
            size *= sizeScale;
            N.Vector3 spread = new N.Vector3((float)rng.RandfRange(-1, 1), (float)rng.RandfRange(SPREAD_UP_MIN, SPREAD_UP_MAX),
                (float)rng.RandfRange(-1, 1));
            N.Vector3 angular = new N.Vector3((float)rng.RandfRange(-SPIN, SPIN), (float)rng.RandfRange(-SPIN, SPIN),
                (float)rng.RandfRange(-SPIN, SPIN));
            float life = (float)rng.RandfRange(LIFE_MIN, LIFE_MAX);
            return new DebrisPiece { size = size, velocity = away * PUSH + spread * PUSH, angular = angular, life = life };
        }
    }
}
