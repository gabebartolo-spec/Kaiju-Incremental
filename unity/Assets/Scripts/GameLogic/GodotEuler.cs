// Godot's Node3D rotation in its default YXZ order, in Godot's own 32-bit floats (core/math/basis.cpp from_euler,
// set_euler_scale, orthonormalize, get_euler_normalized, get_euler; Node3D._update_rotation_and_scale): the basis a
// rotation and scale build, and the angles Godot reads back from that basis once the node has moved. Reading back
// folds the angles into Godot's own ranges (x within a quarter turn), so a tumble that keeps adding to the angles must
// add to what Godot reads, as HeliWreck.Step does. Near a quarter turn of pitch the reading is very sensitive, so it is
// done step for step as Godot does it, in floats. Plain C#.
using System;
using N = System.Numerics;

namespace Kaiju.Game
{
    public static class GodotEuler
    {
        // basis.cpp get_euler epsilon: how close to straight up or down the pitch is treated as exactly so (about
        // 0.04 degrees).
        const float GIMBAL_EPSILON = 0.00000025f;
        const float HALF_PI = (float)(Math.PI * 0.5);

        // from_euler (YXZ): ymat * xmat * zmat, as Godot's rows (row r, column c).
        public static float[,] Rows(N.Vector3 euler)
        {
            float c = Cos(euler.X), s = Sin(euler.X);
            var x = new float[,] { { 1, 0, 0 }, { 0, c, -s }, { 0, s, c } };
            c = Cos(euler.Y);
            s = Sin(euler.Y);
            var y = new float[,] { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } };
            c = Cos(euler.Z);
            s = Sin(euler.Z);
            var z = new float[,] { { c, -s, 0 }, { s, c, 0 }, { 0, 0, 1 } };
            return Mul(Mul(y, x), z);
        }

        // set_euler_scale: the rotation's rows with each column scaled.
        public static float[,] Basis(N.Vector3 euler, N.Vector3 scale)
        {
            float[,] m = Rows(euler);
            for (int r = 0; r < 3; r++)
            {
                m[r, 0] *= scale.X;
                m[r, 1] *= scale.Y;
                m[r, 2] *= scale.Z;
            }
            return m;
        }

        // The basis's columns (Godot's basis.x, .y, .z) for `euler` and `scale`.
        public static void Columns(N.Vector3 euler, N.Vector3 scale, out N.Vector3 bx, out N.Vector3 by, out N.Vector3 bz)
        {
            float[,] m = Basis(euler, scale);
            bx = Column(m, 0);
            by = Column(m, 1);
            bz = Column(m, 2);
        }

        // Node3D._update_rotation_and_scale: Godot's reading of a node's rotation and scale after it moved, from the
        // basis `euler` and `scale` build: scale = get_scale (column lengths, sign of the determinant), rotation =
        // get_euler_normalized (YXZ).
        public static N.Vector3 Read(N.Vector3 euler, ref N.Vector3 scale)
        {
            float[,] b = Basis(euler, scale);
            float sign = Math.Sign(Determinant(b));
            scale = new N.Vector3(Length(Column(b, 0)), Length(Column(b, 1)), Length(Column(b, 2))) * sign;
            return Angles(b);
        }

        // get_euler_normalized (YXZ) of the basis with columns `bx`, `by`, `bz`: the angles a node turned so reads
        // back (a model part's rotation when it is thrown).
        public static N.Vector3 Euler(N.Vector3 bx, N.Vector3 by, N.Vector3 bz) =>
            Angles(new float[,] { { bx.X, by.X, bz.X }, { bx.Y, by.Y, bz.Y }, { bx.Z, by.Z, bz.Z } });

        static N.Vector3 Angles(float[,] b)
        {
            // orthonormalize: Gram-Schmidt on the columns.
            N.Vector3 x = Normalize(Column(b, 0)), y = Column(b, 1), z = Column(b, 2);
            y = Normalize(y - x * Dot(x, y));
            z = Normalize(z - x * Dot(x, z) - y * Dot(y, z));
            var r = new float[,] { { x.X, y.X, z.X }, { x.Y, y.Y, z.Y }, { x.Z, y.Z, z.Z } };
            if (Determinant(r) < 0f)
                for (int i = 0; i < 3; i++)
                    for (int j = 0; j < 3; j++) r[i, j] = -r[i, j];
            float m12 = r[1, 2];
            if (m12 >= 1f - GIMBAL_EPSILON) return new N.Vector3(-HALF_PI, -Atan2(r[0, 1], r[0, 0]), 0f);
            if (m12 <= -(1f - GIMBAL_EPSILON)) return new N.Vector3(HALF_PI, Atan2(r[0, 1], r[0, 0]), 0f);
            if (r[1, 0] == 0f && r[0, 1] == 0f && r[0, 2] == 0f && r[2, 0] == 0f && r[0, 0] == 1f)
                return new N.Vector3(Atan2(-m12, r[1, 1]), 0f, 0f);
            return new N.Vector3(Asin(-m12), Atan2(r[0, 2], r[2, 2]), Atan2(r[1, 0], r[1, 1]));
        }

        // Godot's Windows build takes sinf, cosf, asinf and atan2f from MinGW, which works them out in more precision
        // and rounds once; .NET's MathF can land a last digit away, and near a quarter turn of pitch that digit grows.
        static float Sin(float a) => (float)Math.Sin(a);

        static float Cos(float a) => (float)Math.Cos(a);

        static float Atan2(float y, float x) => (float)Math.Atan2(y, x);

        // Math::asin: clamped outside -1..1.
        static float Asin(float v) => v < -1f ? -HALF_PI : v > 1f ? HALF_PI : (float)Math.Asin(v);

        static N.Vector3 Column(float[,] m, int c) => new N.Vector3(m[0, c], m[1, c], m[2, c]);

        // Vector3 dot and normalize, summed in Godot's order.
        static float Dot(N.Vector3 a, N.Vector3 b) => a.X * b.X + a.Y * b.Y + a.Z * b.Z;

        static float Length(N.Vector3 v) => MathF.Sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z);

        static N.Vector3 Normalize(N.Vector3 v)
        {
            float lengthSq = v.X * v.X + v.Y * v.Y + v.Z * v.Z;
            if (lengthSq == 0f) return N.Vector3.Zero;
            float length = MathF.Sqrt(lengthSq);
            return new N.Vector3(v.X / length, v.Y / length, v.Z / length);
        }

        static float Determinant(float[,] m) =>
            m[0, 0] * (m[1, 1] * m[2, 2] - m[2, 1] * m[1, 2]) - m[1, 0] * (m[0, 1] * m[2, 2] - m[2, 1] * m[0, 2])
            + m[2, 0] * (m[0, 1] * m[1, 2] - m[1, 1] * m[0, 2]);

        // Basis * Basis, each sum in Godot's order (tdotx).
        static float[,] Mul(float[,] a, float[,] b)
        {
            var m = new float[3, 3];
            for (int i = 0; i < 3; i++)
                for (int j = 0; j < 3; j++)
                    m[i, j] = a[i, 0] * b[0, j] + a[i, 1] * b[1, j] + a[i, 2] * b[2, j];
            return m;
        }
    }
}
