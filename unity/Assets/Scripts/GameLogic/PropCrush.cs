// How a crushed prop's cells lie (scenes/prop_field.gd _crush_group, _fallen, crush_box): a car, bush or lamp
// flattens where it stands; a beach umbrella's pole and canopy (its "folds" keys) close in on the pole and fall over
// away from the blow (director 10-30); a prop is under the walking kaiju when its base lies in the body's ground box
// (KaijuFootprint), turned and scaled with the body. Godot axes and Godot's Transform3D as a row-vector matrix
// (a point is Vector3.Transform(p, body)). Plain C# (System.Numerics) so SimTests/PropCrushCheck.cs walks it against
// Godot's own output. Presentation only: the sim never knows props exist.
using System;
using N = System.Numerics;

namespace Kaiju.Game
{
    // One crushed cell's transform: Basis.from_scale(scale) at origin (prop_field.gd sets no rotation).
    public struct CellPose
    {
        public N.Vector3 scale;
        public N.Vector3 origin;
    }

    public static class PropCrush
    {
        // prop_field.gd FOLD: a folded prop's cells close in on its pole to this share of their reach.
        public const float FOLD = 0.3f;
        // _crush_group: a flattened cell is this much wider and this much as tall...
        public const float FLAT_WIDE = 1.15f, FLAT_TALL = 0.25f;
        // ...and drawn at this share of its height, lifted this many voxels off the ground.
        public const double FLAT_HEIGHT = 0.2, FLAT_LIFT = 0.1;
        // _fallen: the fallen bundle's centre is half a voxel up, and its cells this much as tall.
        public const double FALLEN_LIFT = 0.5;
        public const float FALLEN_TALL = 0.8f;

        // _crush_group's `out`: from the blow to the prop's base on the ground plane; Vector3.BACK under the blow.
        public static N.Vector3 Out(N.Vector3 baseAt, N.Vector3 at)
        {
            var d = new N.Vector3(baseAt.X - at.X, 0f, baseAt.Z - at.Z);
            float sq = d.LengthSquared();
            return sq == 0f ? N.Vector3.UnitZ : d / MathF.Sqrt(sq);
        }

        // add_cells's offset (the prop's base rounded to whole voxels, on the ground) in world units: _crush_group's foot.
        public static N.Vector3 Foot(N.Vector3 baseAt, float voxel)
        {
            float R(float v) => MathF.Round(v / voxel, MidpointRounding.AwayFromZero);
            return new N.Vector3((int)R(baseAt.X), 0, (int)R(baseAt.Z)) * voxel;
        }

        // _crush_group for one cell drawn at `o`: folding keys fall (_fallen), every other cell flattens.
        public static CellPose Cell(N.Vector3 o, bool folds, N.Vector3 foot, N.Vector3 outward, float voxel)
        {
            if (folds)
            {
                CellPose fallen = Fallen(o - foot, outward, voxel);
                fallen.origin += foot;
                return fallen;
            }
            return new CellPose
            {
                scale = new N.Vector3(FLAT_WIDE, FLAT_TALL, FLAT_WIDE),
                origin = new N.Vector3(o.X, (float)(o.Y * FLAT_HEIGHT + voxel * FLAT_LIFT), o.Z),
            };
        }

        // _fallen: where a folding cell (`rel` from the prop's foot) lies once the prop has closed and fallen along
        // `outward`: it hangs as far below its height as it reached from the pole, its reach closes to FOLD, and the
        // bundle lies on the ground as thick as it is closed.
        public static CellPose Fallen(N.Vector3 rel, N.Vector3 outward, float voxel)
        {
            N.Vector3 round = new N.Vector3(rel.X, 0f, rel.Z) * FOLD;
            N.Vector3 lie = outward * (rel.Y - new N.Vector2(rel.X, rel.Z).Length()) + round;
            lie.Y = (float)(voxel * FALLEN_LIFT + round.Length());
            return new CellPose { scale = new N.Vector3(1f, FALLEN_TALL, 1f), origin = lie };
        }

        // crush_box's reach: how far from the body's origin the box can lie (its farther corner, by the body's x scale).
        public static float Reach(N.Matrix4x4 body, FootRect foot) =>
            MathF.Max(foot.position.Length(), foot.End.Length()) * ScaleX(body);

        // crush_box's test: the prop's base, carried at the body's height into the body's own frame, lies in `foot`.
        public static bool Under(N.Matrix4x4 body, FootRect foot, N.Vector3 baseAt)
        {
            N.Matrix4x4.Invert(body, out N.Matrix4x4 into);
            N.Vector3 local = N.Vector3.Transform(new N.Vector3(baseAt.X, body.M42, baseAt.Z), into);
            return foot.HasPoint(new N.Vector2(local.X, local.Z));
        }

        // Basis.get_scale().x: the x axis's length, signed by the basis's determinant.
        static float ScaleX(N.Matrix4x4 m)
        {
            float len = new N.Vector3(m.M11, m.M12, m.M13).Length();
            N.Matrix4x4 basis = m;
            basis.Translation = N.Vector3.Zero;
            return basis.GetDeterminant() < 0f ? -len : len;
        }
    }
}
