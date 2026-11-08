// Godot's Rect2, Rect2i, AABB, Basis, Quaternion, Transform3D and Geometry2D, copied from core/math
// (Godot Engine, MIT, see docs/LICENSING_REGISTER.md). Only what sim/ calls.
using System;

namespace Kaiju.Sim
{
    public struct Rect2 : IEquatable<Rect2>
    {
        public Vector2 position, size;
        public Rect2(Vector2 position, Vector2 size) { this.position = position; this.size = size; }
        public Rect2(double x, double y, double w, double h) { position = new Vector2(x, y); size = new Vector2(w, h); }
        public Rect2(Rect2 r) { position = r.position; size = r.size; }
        public Rect2(Rect2i r) { position = new Vector2(r.position); size = new Vector2(r.size); }
        public Vector2 end { get => position + size; set => size = value - position; }

        public static bool operator ==(Rect2 a, Rect2 b) => a.position == b.position && a.size == b.size;
        public static bool operator !=(Rect2 a, Rect2 b) => !(a == b);
        public bool Equals(Rect2 o) => this == o;
        public override bool Equals(object o) => o is Rect2 r && this == r;
        public override int GetHashCode() => position.GetHashCode() * 397 ^ size.GetHashCode();
        public override string ToString() => $"[P: {position}, S: {size}]";

        public double GetArea() => size.X * size.Y;
        public Vector2 GetCenter() => position + size * 0.5f;
        public bool HasArea() => size.X > 0f && size.Y > 0f;
        public bool Intersects(Rect2 r, bool includeBorders = false)
        {
            if (includeBorders)
            {
                if (position.X > r.position.X + r.size.X) return false;
                if (position.X + size.X < r.position.X) return false;
                if (position.Y > r.position.Y + r.size.Y) return false;
                if (position.Y + size.Y < r.position.Y) return false;
                return true;
            }
            if (position.X >= r.position.X + r.size.X) return false;
            if (position.X + size.X <= r.position.X) return false;
            if (position.Y >= r.position.Y + r.size.Y) return false;
            if (position.Y + size.Y <= r.position.Y) return false;
            return true;
        }
        public Rect2 Intersection(Rect2 r)
        {
            if (!Intersects(r)) return new Rect2();
            Vector2 at = r.position.Max(position);
            return new Rect2(at, (r.position + r.size).Min(position + size) - at);
        }
        public Rect2 Merge(Rect2 r)
        {
            Vector2 at = r.position.Min(position);
            return new Rect2(at, (r.position + r.size).Max(position + size) - at);
        }
        public bool HasPoint(Vector2 p)
        {
            if (p.X < position.X || p.Y < position.Y) return false;
            if (p.X >= (float)(position.X + size.X) || p.Y >= (float)(position.Y + size.Y)) return false;
            return true;
        }
        public Rect2 Grow(double amount)
        {
            float a = (float)amount;
            return new Rect2(new Vector2(position.X - a, position.Y - a),
                new Vector2(size.X + (float)(a * 2f), size.Y + (float)(a * 2f)));
        }
        public Rect2 GrowIndividual(double left, double top, double right, double bottom)
        {
            float l = (float)left, t = (float)top, r = (float)right, b = (float)bottom;
            return new Rect2(new Vector2(position.X - l, position.Y - t),
                new Vector2(size.X + (float)(l + r), size.Y + (float)(t + b)));
        }
        public Rect2 Expand(Vector2 v)
        {
            float bx = position.X, by = position.Y;
            Vector2 e = position + size;
            float ex = e.X, ey = e.Y;
            if (v.X < bx) bx = v.X;
            if (v.Y < by) by = v.Y;
            if (v.X > ex) ex = v.X;
            if (v.Y > ey) ey = v.Y;
            Vector2 begin = new Vector2(bx, by);
            return new Rect2(begin, new Vector2(ex, ey) - begin);
        }
    }

    public struct Rect2i : IEquatable<Rect2i>
    {
        public Vector2i position, size;
        public Rect2i(Vector2i position, Vector2i size) { this.position = position; this.size = size; }
        public Rect2i(long x, long y, long w, long h) { position = new Vector2i(x, y); size = new Vector2i(w, h); }
        public Rect2i(Rect2i r) { position = r.position; size = r.size; }
        public Rect2i(Rect2 r) { position = new Vector2i(r.position); size = new Vector2i(r.size); }
        public Vector2i end { get => position + size; set => size = value - position; }

        public static bool operator ==(Rect2i a, Rect2i b) => a.position == b.position && a.size == b.size;
        public static bool operator !=(Rect2i a, Rect2i b) => !(a == b);
        public bool Equals(Rect2i o) => this == o;
        public override bool Equals(object o) => o is Rect2i r && this == r;
        public override int GetHashCode() => position.GetHashCode() * 397 ^ size.GetHashCode();
        public override string ToString() => $"[P: {position}, S: {size}]";

        public long GetArea() => (long)(size.X * size.Y);
        public Vector2i GetCenter() => position + size / 2;
        public bool HasArea() => size.X > 0 && size.Y > 0;
        public bool Intersects(Rect2i r)
        {
            if (position.X >= r.position.X + r.size.X) return false;
            if (position.X + size.X <= r.position.X) return false;
            if (position.Y >= r.position.Y + r.size.Y) return false;
            if (position.Y + size.Y <= r.position.Y) return false;
            return true;
        }
        public Rect2i Intersection(Rect2i r)
        {
            if (!Intersects(r)) return new Rect2i();
            Vector2i at = r.position.Max(position);
            return new Rect2i(at, (r.position + r.size).Min(position + size) - at);
        }
        public Rect2i Merge(Rect2i r)
        {
            Vector2i at = r.position.Min(position);
            return new Rect2i(at, (r.position + r.size).Max(position + size) - at);
        }
        public bool HasPoint(Vector2i p)
        {
            if (p.X < position.X || p.Y < position.Y) return false;
            if (p.X >= position.X + size.X || p.Y >= position.Y + size.Y) return false;
            return true;
        }
        public Rect2i Grow(long amount)
        {
            int a = (int)amount;
            return new Rect2i(new Vector2i(position.X - a, position.Y - a),
                new Vector2i(size.X + a * 2, size.Y + a * 2));
        }
    }

    public struct AABB
    {
        public Vector3 position, size;
        public AABB(Vector3 position, Vector3 size) { this.position = position; this.size = size; }
        public Vector3 end { get => position + size; set => size = value - position; }

        public bool HasPoint(Vector3 p)
        {
            if (p.X < position.X || p.Y < position.Y || p.Z < position.Z) return false;
            if (p.X > (float)(position.X + size.X) || p.Y > (float)(position.Y + size.Y) || p.Z > (float)(position.Z + size.Z)) return false;
            return true;
        }
        public AABB Merge(AABB o)
        {
            Vector3 b1 = position, b2 = o.position, e1 = size + b1, e2 = o.size + b2;
            Vector3 min = new Vector3(b1.X < b2.X ? b1.X : b2.X, b1.Y < b2.Y ? b1.Y : b2.Y, b1.Z < b2.Z ? b1.Z : b2.Z);
            Vector3 max = new Vector3(e1.X > e2.X ? e1.X : e2.X, e1.Y > e2.Y ? e1.Y : e2.Y, e1.Z > e2.Z ? e1.Z : e2.Z);
            return new AABB(min, max - min);
        }
        public AABB Grow(double by)
        {
            float a = (float)by;
            return new AABB(new Vector3(position.X - a, position.Y - a, position.Z - a),
                new Vector3(size.X + (float)(2f * a), size.Y + (float)(2f * a), size.Z + (float)(2f * a)));
        }
    }

    public struct Quaternion
    {
        internal float X, Y, Z, W;
        internal Quaternion(float x, float y, float z, float w) { X = x; Y = y; Z = z; W = w; }
        // Shortest arc from v0 to v1.
        public Quaternion(Vector3 v0, Vector3 v1)
        {
            X = 0f; Y = 0f; Z = 0f; W = 1f;
            Vector3 n0 = v0.Normalized(), n1 = v1.Normalized();
            float d = (float)n0.Dot(n1);
            if (MathF.Abs(d) > 0.99999975f)
            {
                if (d >= 0f) return;
                Vector3 axis = n0.AnyPerpendicular();
                X = axis.X; Y = axis.Y; Z = axis.Z; W = 0f;
            }
            else
            {
                Vector3 c = n0.Cross(n1);
                float s = MathF.Sqrt((float)((float)(1f + d) * 2f)), rs = 1f / s;
                X = c.X * rs; Y = c.Y * rs; Z = c.Z * rs; W = s * 0.5f;
            }
            float l = MathF.Sqrt((float)((float)((float)((float)(X * X) + (float)(Y * Y)) + (float)(Z * Z)) + (float)(W * W)));
            X /= l; Y /= l; Z /= l; W /= l;
        }
    }

    public struct Basis
    {
        // rows[i][j], as in Godot.
        internal Vector3 R0, R1, R2;
        public static readonly Basis IDENTITY = new Basis(new Vector3(1f, 0f, 0f), new Vector3(0f, 1f, 0f), new Vector3(0f, 0f, 1f));

        internal Basis(Vector3 r0, Vector3 r1, Vector3 r2) { R0 = r0; R1 = r1; R2 = r2; }

        // GDScript's Basis() is the identity; C#'s default(Basis) is not, so sim code must use this.
        public static Basis Make() => IDENTITY;

        public Basis(Vector3 axis, double angle)
        {
            float a = (float)angle;
            float sx = axis.X * axis.X, sy = axis.Y * axis.Y, sz = axis.Z * axis.Z;
            float cosine = Gd.Cos32(a);
            float m00 = sx + (float)(cosine * (float)(1f - sx)), m11 = sy + (float)(cosine * (float)(1f - sy)), m22 = sz + (float)(cosine * (float)(1f - sz));
            float sine = Gd.Sin32(a), t = 1f - cosine;
            float xyzt = (float)(axis.X * axis.Y) * t, zyxs = axis.Z * sine;
            float m01 = xyzt - zyxs, m10 = xyzt + zyxs;
            xyzt = (float)(axis.X * axis.Z) * t; zyxs = axis.Y * sine;
            float m02 = xyzt + zyxs, m20 = xyzt - zyxs;
            xyzt = (float)(axis.Y * axis.Z) * t; zyxs = axis.X * sine;
            float m12 = xyzt - zyxs, m21 = xyzt + zyxs;
            R0 = new Vector3(m00, m01, m02); R1 = new Vector3(m10, m11, m12); R2 = new Vector3(m20, m21, m22);
        }

        public Basis(Quaternion q)
        {
            float d = (float)((float)((float)((float)(q.X * q.X) + (float)(q.Y * q.Y)) + (float)(q.Z * q.Z)) + (float)(q.W * q.W)), s = 2f / d;
            float xs = q.X * s, ys = q.Y * s, zs = q.Z * s;
            float wx = q.W * xs, wy = q.W * ys, wz = q.W * zs;
            float xx = q.X * xs, xy = q.X * ys, xz = q.X * zs;
            float yy = q.Y * ys, yz = q.Y * zs, zz = q.Z * zs;
            R0 = new Vector3(1f - (float)(yy + zz), xy - wz, xz + wy);
            R1 = new Vector3(xy + wz, 1f - (float)(xx + zz), yz - wx);
            R2 = new Vector3(xz - wy, yz + wx, 1f - (float)(xx + yy));
        }

        Vector3 Col(int i) => new Vector3(R0.At(i), R1.At(i), R2.At(i));
        float TDot(Vector3 v, int i) => (float)((float)((float)(R0.At(i) * v.X) + (float)(R1.At(i) * v.Y)) + (float)(R2.At(i) * v.Z));

        public static Basis operator *(Basis a, Basis b) => new Basis(
            new Vector3(b.TDot(a.R0, 0), b.TDot(a.R0, 1), b.TDot(a.R0, 2)),
            new Vector3(b.TDot(a.R1, 0), b.TDot(a.R1, 1), b.TDot(a.R1, 2)),
            new Vector3(b.TDot(a.R2, 0), b.TDot(a.R2, 1), b.TDot(a.R2, 2)));
        public static Vector3 operator *(Basis a, Vector3 v) =>
            new Vector3((float)a.R0.Dot(v), (float)a.R1.Dot(v), (float)a.R2.Dot(v));

        public Basis Orthonormalized()
        {
            Vector3 x = Col(0).Normalized(), y = Col(1), z = Col(2);
            y = (y - x * x.Dot(y)).Normalized();
            z = (z - x * x.Dot(z) - y * y.Dot(z)).Normalized();
            return new Basis(new Vector3(x.X, y.X, z.X), new Vector3(x.Y, y.Y, z.Y), new Vector3(x.Z, y.Z, z.Z));
        }
    }

    public struct Transform3D
    {
        public Basis basis;
        public Vector3 origin;
        public Transform3D(Basis basis, Vector3 origin) { this.basis = basis; this.origin = origin; }

        public static Vector3 operator *(Transform3D t, Vector3 v) => new Vector3(
            (float)t.basis.R0.Dot(v) + t.origin.X,
            (float)t.basis.R1.Dot(v) + t.origin.Y,
            (float)t.basis.R2.Dot(v) + t.origin.Z);

        public static AABB operator *(Transform3D t, AABB box)
        {
            Vector3 min = box.position, max = box.position + box.size;
            Span<float> lo = stackalloc float[3], hi = stackalloc float[3];
            for (int i = 0; i < 3; i++)
            {
                Vector3 row = i == 0 ? t.basis.R0 : i == 1 ? t.basis.R1 : t.basis.R2;
                lo[i] = hi[i] = t.origin.At(i);
                for (int j = 0; j < 3; j++)
                {
                    float e = row.At(j) * min.At(j), f = row.At(j) * max.At(j);
                    if (e < f) { lo[i] += e; hi[i] += f; }
                    else { lo[i] += f; hi[i] += e; }
                }
            }
            Vector3 at = new Vector3(lo[0], lo[1], lo[2]);
            return new AABB(at, new Vector3(hi[0], hi[1], hi[2]) - at);
        }
    }

    public struct Color
    {
        float _r, _g, _b, _a;
        public double r { get => _r; set => _r = (float)value; }
        public double g { get => _g; set => _g = (float)value; }
        public double b { get => _b; set => _b = (float)value; }
        public double a { get => _a; set => _a = (float)value; }
        public Color(double r, double g, double b, double a = 1.0) { _r = (float)r; _g = (float)g; _b = (float)b; _a = (float)a; }

        // Only "#rrggbb" and "#rrggbbaa", which is what data holds.
        public Color(string text)
        {
            string h = text.StartsWith("#", StringComparison.Ordinal) ? text.Substring(1) : text;
            _r = Hex(h, 0) / 255f; _g = Hex(h, 2) / 255f; _b = Hex(h, 4) / 255f;
            _a = h.Length >= 8 ? Hex(h, 6) / 255f : 1f;
        }
        static int Hex(string s, int at) => Convert.ToInt32(s.Substring(at, 2), 16);
    }

    public static class Geometry2D
    {
        public static Vector2 GetClosestPointToSegment(Vector2 p, Vector2 a, Vector2 b)
        {
            Vector2 at = p - a, n = b - a;
            float l2 = (float)((float)(n.X * n.X) + (float)(n.Y * n.Y));
            if (l2 < 1e-20f) return a;
            float d = (float)((float)(n.X * at.X) + (float)(n.Y * at.Y)) / l2;
            if (d <= 0f) return a;
            if (d >= 1f) return b;
            return a + n * d;
        }

        static bool Crosses(Vector2 fromA, Vector2 toA, Vector2 fromB, Vector2 toB, out Vector2 result)
        {
            result = default;
            Vector2 B = toA - fromA, C = fromB - fromA, D = toB - fromA;
            float abLen = (float)((float)(B.X * B.X) + (float)(B.Y * B.Y));
            if (abLen <= 0f) return false;
            float nx = B.X / abLen, ny = B.Y / abLen;
            float cx = (float)((float)(C.X * nx) + (float)(C.Y * ny)), cy = (float)((float)(C.Y * nx) - (float)(C.X * ny));
            float dx = (float)((float)(D.X * nx) + (float)(D.Y * ny)), dy = (float)((float)(D.Y * nx) - (float)(D.X * ny));
            float eps = (float)Gd.CMP_EPSILON;
            if ((cy < -eps && dy < -eps) || (cy > eps && dy > eps)) return false;
            if (Gd.IsEqual32(cy, dy)) return false;
            float pos = dx + (float)((float)((float)(cx - dx) * dy) / (float)(dy - cy));
            if (pos < 0f || pos > 1f) return false;
            result = fromA + B * pos;
            return true;
        }

        // null when they miss, the crossing point when they meet.
        public static Variant SegmentIntersectsSegment(Vector2 fromA, Vector2 toA, Vector2 fromB, Vector2 toB) =>
            Crosses(fromA, toA, fromB, toB, out Vector2 at) ? at : default(Variant);

        public static bool IsPointInPolygon(Vector2 p, PackedVector2Array polygon)
        {
            int c = (int)polygon.Size();
            if (c < 3) return false;
            Vector2 far = new Vector2(-1e20, -1e20), opposite = new Vector2(1e20, 1e20);
            for (int i = 0; i < c; i++)
            {
                far = far.Max(polygon[i]);
                opposite = opposite.Min(polygon[i]);
            }
            far += (far - opposite) * new Vector2(1.221313, 1.512312);
            int hits = 0;
            for (int i = 0; i < c; i++)
            {
                if (Crosses(polygon[i], polygon[(i + 1) % c], p, far, out Vector2 res))
                {
                    hits++;
                    if (res.IsEqualApprox(p)) return true;
                }
            }
            return (hits & 1) != 0;
        }
    }
}
