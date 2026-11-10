// scenes/rooftop_aim.gd and the stance half of scenes/rooftop_view.gd: where a rooftop soldier stands, where
// the rifle's muzzle is and which part of the kaiju a round strikes. Sim types only (no UnityEngine), Godot
// axes, so unity/SimTests compiles it too. Presentation only: it reads the sim and decides no outcome.
using System;
using Kaiju.Sim;

public static class RooftopAim
{
    // scenes/rooftop_aim.gd
    public static readonly string[] TARGETS =
    {
        "spine0", "spine1", "spine2", "head0", "head1", "leg_l0", "leg_l1", "leg_r0", "leg_r1",
        "tail0", "tail1", "tail2", "tail3",
    };
    public const int NEAREST = 5, TRIES = 24;
    public const double FACING = 0.2, BODY_MIDDLE = 3.0;
    // scenes/rooftop_view.gd
    public const double FIGURE_SCALE = 1.5, MUZZLE_HEIGHT = 8.5, MUZZLE_AHEAD = 7.5, SPACING = 0.55, FLASH_AHEAD = 0.45;
    public const double TRACER_SPEED = 60.0, STAGGER = 0.1;
    public const int STONE_STEP = 2, PARAPET_IN = 2, RAGGED_FRAMES = 14, RAGGED_FROM = 2, TICKS_PER_SECOND = 60;
    // scenes/building_voxels.gd VOXEL
    public const double VOXEL = 1.0 / 8.0;

    // The flat roof around a squad's cell, in world x/z (rooftop_view.gd _roof): as far each way as the
    // columns stay at the squad's own height.
    public static Rect2 Roof(RampageSim.Building b, Vector3i c)
    {
        long loX = c.x, hiX = c.x, loZ = c.z, hiZ = c.z;
        while (loX > 0 && b.frame.TopBelow(loX - 1, c.z, b.height) == c.y) loX--;
        while (hiX < b.w - 1 && b.frame.TopBelow(hiX + 1, c.z, b.height) == c.y) hiX++;
        while (loZ > 0 && b.frame.TopBelow(c.x, loZ - 1, b.height) == c.y) loZ--;
        while (hiZ < b.d - 1 && b.frame.TopBelow(c.x, hiZ + 1, b.height) == c.y) hiZ++;
        Vector3 corner = b.LocalToWorld(new Vector3(loX, 0, loZ));
        return new Rect2(corner.x, corner.z, hiX - loX + 1, hiZ - loZ + 1);
    }

    // Where a squad's feet are (rooftop_view.gd stance): the roof's top, on the cornice step of a stone tower.
    public static double Feet(RampageSim.Building b, Vector3i c)
    {
        double feet = c.y + 1.0;
        if (b.style % 4 == BuildingLayout.STONE) feet += STONE_STEP * VOXEL;
        return feet;
    }

    // Soldier k of n: in a line across the kaiju's bearing, inside the parapet, facing the kaiju. The basis is
    // the unscaled turn; Point applies FIGURE_SCALE.
    public static Transform3D Stance(Vector2 squad, Vector2 kaiju, Rect2 roof, double feet, int k, int n)
    {
        Vector2 to = (kaiju - squad).Normalized();
        if (to == Vector2.ZERO) to = new Vector2(0, -1);
        Vector2 across = new Vector2(-to.y, to.x);
        Vector2 at = squad + across * ((k - (n - 1) * 0.5) * SPACING) + to * (STAGGER * (k % 2));
        Rect2 inner = roof.Grow(-PARAPET_IN * VOXEL);
        at = at.Clamp(inner.position, inner.end);
        Basis turn = new Basis(Vector3.UP, Gd.Atan2(-to.x, -to.y));
        return new Transform3D(turn, new Vector3(at.x, feet, at.y));
    }

    // A point of the figure, given in its own voxels.
    public static Vector3 Point(Transform3D t, Vector3 cells, double voxel) => t.origin + t.basis * (cells * (voxel * FIGURE_SCALE));

    public static Vector3 Muzzle(Transform3D t, double voxel) => Point(t, new Vector3(0, MUZZLE_HEIGHT, -MUZZLE_AHEAD), voxel);

    public static Vector3 Top(Transform3D t, double voxel) => Point(t, new Vector3(0, MUZZLE_HEIGHT, 0), voxel);

    public static Vector3 Forward(Transform3D t) => (t.basis * new Vector3(0, 0, -1)).Normalized();

    public static Vector3 FlashAt(Transform3D t, double voxel) => Muzzle(t, voxel) + Forward(t) * FLASH_AHEAD;

    // The frames a rifle waits after the squad's first: a ragged volley. Rifle 0 draws nothing.
    public static int Wait(int k, RandomNumberGenerator rng) => k == 0 ? 0 : (int)rng.RandiRange(RAGGED_FROM, RAGGED_FRAMES);

    public static double Flight(Vector3 muzzle, Vector3 to) => muzzle.DistanceTo(to) / TRACER_SPEED;

    public static int Frames(double flight) => (int)Gd.Roundi(flight * TICKS_PER_SECOND);

    // One of the NEAREST few of `count` distances, at random: the index into distSq, or -1 when there is none.
    public static int Pick(double[] distSq, int count, RandomNumberGenerator rng)
    {
        if (count <= 0) return -1;
        int rank = (int)rng.RandiRange(0, Math.Min(NEAREST, count) - 1);
        int pick = -1;
        double last = double.NegativeInfinity;
        int lastAt = -1;
        // The rank-th smallest, ties in index order, without sorting: count is 13 at most.
        for (int r = 0; r <= rank; r++)
        {
            pick = -1;
            for (int i = 0; i < count; i++)
            {
                bool after = distSq[i] > last || (distSq[i] == last && i > lastAt);
                if (!after) continue;
                if (pick < 0 || distSq[i] < distSq[pick]) pick = i;
            }
            if (pick < 0) return lastAt;
            last = distSq[pick];
            lastAt = pick;
        }
        return pick;
    }

    // Which of a bone's `cells` voxels a round strikes: up to TRIES drawn at random, the first on the side facing
    // the muzzle (flat), else the one of them that faces it most. -1 when the bone carries none.
    public static int Facing(int cells, Func<int, Vector3> world, Vector3 axis, Vector3 muzzle, RandomNumberGenerator rng)
    {
        Vector2 toward = new Vector2(muzzle.x - axis.x, muzzle.z - axis.z).Normalized();
        int best = -1;
        double bestDot = double.NegativeInfinity;
        for (int i = 0; i < Math.Min(TRIES, cells); i++)
        {
            int cell = (int)rng.RandiRange(0, cells - 1);
            Vector3 at = world(cell);
            double dot = new Vector2(at.x - axis.x, at.z - axis.z).Normalized().Dot(toward);
            if (dot >= FACING) return cell;
            if (dot > bestDot)
            {
                bestDot = dot;
                best = cell;
            }
        }
        return best;
    }
}
