// Godot's vectors, copied from core/math (Godot Engine, MIT, see docs/LICENSING_REGISTER.md).
// Parts are 32-bit like real_t; reads widen to double, the same as a GDScript float.
using System;

namespace Kaiju.Sim
{
    public struct Vector2 : IEquatable<Vector2>
    {
        float _x, _y;
        public double x { get => _x; set => _x = (float)value; }
        public double y { get => _y; set => _y = (float)value; }
        internal float X => _x;
        internal float Y => _y;

        public Vector2(double x, double y) { _x = (float)x; _y = (float)y; }
        public Vector2(Vector2 v) { _x = v._x; _y = v._y; }
        public Vector2(Vector2i v) { _x = v.X; _y = v.Y; }
        internal Vector2(float x, float y) { _x = x; _y = y; }

        public static readonly Vector2 ZERO = new Vector2(0f, 0f);
        public static readonly Vector2 ONE = new Vector2(1f, 1f);
        public static readonly Vector2 RIGHT = new Vector2(1f, 0f);
        public static readonly Vector2 LEFT = new Vector2(-1f, 0f);
        public static readonly Vector2 UP = new Vector2(0f, -1f);
        public static readonly Vector2 DOWN = new Vector2(0f, 1f);
        public static readonly Vector2 INF = new Vector2(float.PositiveInfinity, float.PositiveInfinity);

        public static Vector2 FromAngle(double angle)
        {
            float a = (float)angle;
            return new Vector2(MathF.Cos(a), MathF.Sin(a));
        }

        public static Vector2 operator +(Vector2 a, Vector2 b) => new Vector2(a._x + b._x, a._y + b._y);
        public static Vector2 operator -(Vector2 a, Vector2 b) => new Vector2(a._x - b._x, a._y - b._y);
        public static Vector2 operator *(Vector2 a, Vector2 b) => new Vector2(a._x * b._x, a._y * b._y);
        public static Vector2 operator /(Vector2 a, Vector2 b) => new Vector2(a._x / b._x, a._y / b._y);
        public static Vector2 operator *(Vector2 a, double s) { float f = (float)s; return new Vector2(a._x * f, a._y * f); }
        public static Vector2 operator *(double s, Vector2 a) => a * s;
        public static Vector2 operator /(Vector2 a, double s) { float f = (float)s; return new Vector2(a._x / f, a._y / f); }
        public static Vector2 operator -(Vector2 a) => new Vector2(-a._x, -a._y);
        public static bool operator ==(Vector2 a, Vector2 b) => a._x == b._x && a._y == b._y;
        public static bool operator !=(Vector2 a, Vector2 b) => a._x != b._x || a._y != b._y;
        public static bool operator <(Vector2 a, Vector2 b) => a._x == b._x ? a._y < b._y : a._x < b._x;
        public static bool operator >(Vector2 a, Vector2 b) => a._x == b._x ? a._y > b._y : a._x > b._x;
        public static bool operator <=(Vector2 a, Vector2 b) => a._x == b._x ? a._y <= b._y : a._x < b._x;
        public static bool operator >=(Vector2 a, Vector2 b) => a._x == b._x ? a._y >= b._y : a._x > b._x;
        public bool Equals(Vector2 o) => this == o;
        public override bool Equals(object o) => o is Vector2 v && this == v;
        public override int GetHashCode() => _x.GetHashCode() * 397 ^ _y.GetHashCode();
        public override string ToString() => $"({Gd.Str32(_x)}, {Gd.Str32(_y)})";

        public double this[long i]
        {
            get => i == 0 ? _x : _y;
            set { if (i == 0) _x = (float)value; else _y = (float)value; }
        }
        public double Angle() => MathF.Atan2(_y, _x);
        public double Dot(Vector2 o) => _x * o._x + _y * o._y;
        public double Cross(Vector2 o) => _x * o._y - _y * o._x;
        public double Length() => MathF.Sqrt(_x * _x + _y * _y);
        public double LengthSquared() => _x * _x + _y * _y;
        public double DistanceTo(Vector2 o)
        {
            float dx = _x - o._x, dy = _y - o._y;
            return MathF.Sqrt(dx * dx + dy * dy);
        }
        public double DistanceSquaredTo(Vector2 o)
        {
            float dx = _x - o._x, dy = _y - o._y;
            return dx * dx + dy * dy;
        }
        public double AngleTo(Vector2 o) => MathF.Atan2((float)Cross(o), (float)Dot(o));
        public Vector2 Normalized()
        {
            if (!float.IsFinite(_x) || !float.IsFinite(_y)) return ZERO;
            float l = _x * _x + _y * _y;
            if (l == 0f) return ZERO;
            l = MathF.Sqrt(l);
            return new Vector2(_x / l, _y / l);
        }
        public Vector2 DirectionTo(Vector2 to) => (to - this).Normalized();
        public Vector2 Rotated(double by)
        {
            float a = (float)by, sine = MathF.Sin(a), cosi = MathF.Cos(a);
            return new Vector2(_x * cosi - _y * sine, _x * sine + _y * cosi);
        }
        public Vector2 Orthogonal() => new Vector2(_y, -_x);
        public Vector2 Abs() => new Vector2(MathF.Abs(_x), MathF.Abs(_y));
        public Vector2 Floor() => new Vector2(MathF.Floor(_x), MathF.Floor(_y));
        public Vector2 Ceil() => new Vector2(MathF.Ceiling(_x), MathF.Ceiling(_y));
        public Vector2 Min(Vector2 o) => new Vector2(Gd.Min32(_x, o._x), Gd.Min32(_y, o._y));
        public Vector2 Max(Vector2 o) => new Vector2(Gd.Max32(_x, o._x), Gd.Max32(_y, o._y));
        public Vector2 Clamp(Vector2 lo, Vector2 hi) =>
            new Vector2(Gd.Clamp32(_x, lo._x, hi._x), Gd.Clamp32(_y, lo._y, hi._y));
        public Vector2 LimitLength(double length = 1.0)
        {
            float len = (float)length, l = MathF.Sqrt(_x * _x + _y * _y);
            Vector2 v = this;
            if (l > 0f && len < l)
            {
                v = new Vector2(v._x / l, v._y / l);
                v = new Vector2(v._x * len, v._y * len);
            }
            return v;
        }
        public Vector2 MoveToward(Vector2 to, double delta)
        {
            float d = (float)delta;
            Vector2 vd = to - this;
            float len = MathF.Sqrt(vd._x * vd._x + vd._y * vd._y);
            if (len <= d || len < (float)Gd.CMP_EPSILON) return to;
            float tx = vd._x / len, ty = vd._y / len;
            return new Vector2(_x + tx * d, _y + ty * d);
        }
        public Vector2 Lerp(Vector2 to, double weight)
        {
            float w = (float)weight;
            return new Vector2(_x + (to._x - _x) * w, _y + (to._y - _y) * w);
        }
        public Vector2 Slerp(Vector2 to, double weight)
        {
            float w = (float)weight;
            float startSq = _x * _x + _y * _y, endSq = to._x * to._x + to._y * to._y;
            if (startSq == 0f || endSq == 0f) return Lerp(to, weight);
            float start = MathF.Sqrt(startSq), end = MathF.Sqrt(endSq);
            float result = start + (end - start) * w;
            float angle = (float)AngleTo(to);
            return Rotated(angle * w) * (result / start);
        }
        public bool IsZeroApprox() => Gd.IsZero32(_x) && Gd.IsZero32(_y);
        public bool IsEqualApprox(Vector2 o) => Gd.IsEqual32(_x, o._x) && Gd.IsEqual32(_y, o._y);
    }

    public struct Vector2i : IEquatable<Vector2i>
    {
        int _x, _y;
        public long x { get => _x; set => _x = (int)value; }
        public long y { get => _y; set => _y = (int)value; }
        internal int X => _x;
        internal int Y => _y;

        public Vector2i(long x, long y) { _x = (int)x; _y = (int)y; }
        public Vector2i(Vector2i v) { _x = v._x; _y = v._y; }
        public Vector2i(Vector2 v) { _x = (int)v.X; _y = (int)v.Y; }

        public static readonly Vector2i ZERO = new Vector2i(0, 0);
        public static readonly Vector2i ONE = new Vector2i(1, 1);

        public static Vector2i operator +(Vector2i a, Vector2i b) => new Vector2i(a._x + b._x, a._y + b._y);
        public static Vector2i operator -(Vector2i a, Vector2i b) => new Vector2i(a._x - b._x, a._y - b._y);
        public static Vector2i operator *(Vector2i a, Vector2i b) => new Vector2i(a._x * b._x, a._y * b._y);
        public static Vector2i operator /(Vector2i a, Vector2i b) => new Vector2i(a._x / b._x, a._y / b._y);
        public static Vector2i operator %(Vector2i a, Vector2i b) => new Vector2i(a._x % b._x, a._y % b._y);
        public static Vector2i operator *(Vector2i a, long s) => new Vector2i(a._x * (int)s, a._y * (int)s);
        public static Vector2i operator *(long s, Vector2i a) => a * s;
        public static Vector2i operator /(Vector2i a, long s) => new Vector2i(a._x / (int)s, a._y / (int)s);
        public static Vector2i operator %(Vector2i a, long s) => new Vector2i(a._x % (int)s, a._y % (int)s);
        public static Vector2 operator *(Vector2i a, double s) => new Vector2(a) * s;
        public static Vector2 operator *(double s, Vector2i a) => new Vector2(a) * s;
        public static Vector2 operator /(Vector2i a, double s) => new Vector2(a) / s;
        public static Vector2i operator -(Vector2i a) => new Vector2i(-a._x, -a._y);
        public static bool operator ==(Vector2i a, Vector2i b) => a._x == b._x && a._y == b._y;
        public static bool operator !=(Vector2i a, Vector2i b) => a._x != b._x || a._y != b._y;
        public static bool operator <(Vector2i a, Vector2i b) => a._x == b._x ? a._y < b._y : a._x < b._x;
        public static bool operator >(Vector2i a, Vector2i b) => a._x == b._x ? a._y > b._y : a._x > b._x;
        public bool Equals(Vector2i o) => this == o;
        public override bool Equals(object o) => o is Vector2i v && this == v;
        public override int GetHashCode() => _x * 397 ^ _y;
        public override string ToString() => $"({_x}, {_y})";

        public long this[long i]
        {
            get => i == 0 ? _x : _y;
            set { if (i == 0) _x = (int)value; else _y = (int)value; }
        }
        public Vector2i Abs() => new Vector2i(Math.Abs(_x), Math.Abs(_y));
        public Vector2i Min(Vector2i o) => new Vector2i(Math.Min(_x, o._x), Math.Min(_y, o._y));
        public Vector2i Max(Vector2i o) => new Vector2i(Math.Max(_x, o._x), Math.Max(_y, o._y));
        public Vector2i Clamp(Vector2i lo, Vector2i hi) =>
            new Vector2i(Gd.Clampi(_x, lo._x, hi._x), Gd.Clampi(_y, lo._y, hi._y));
    }

    public struct Vector3 : IEquatable<Vector3>
    {
        float _x, _y, _z;
        public double x { get => _x; set => _x = (float)value; }
        public double y { get => _y; set => _y = (float)value; }
        public double z { get => _z; set => _z = (float)value; }
        internal float X => _x;
        internal float Y => _y;
        internal float Z => _z;

        public Vector3(double x, double y, double z) { _x = (float)x; _y = (float)y; _z = (float)z; }
        public Vector3(Vector3 v) { _x = v._x; _y = v._y; _z = v._z; }
        public Vector3(Vector3i v) { _x = v.X; _y = v.Y; _z = v.Z; }
        internal Vector3(float x, float y, float z) { _x = x; _y = y; _z = z; }

        public static readonly Vector3 ZERO = new Vector3(0f, 0f, 0f);
        public static readonly Vector3 ONE = new Vector3(1f, 1f, 1f);
        public static readonly Vector3 RIGHT = new Vector3(1f, 0f, 0f);
        public static readonly Vector3 UP = new Vector3(0f, 1f, 0f);
        public static readonly Vector3 DOWN = new Vector3(0f, -1f, 0f);

        public static Vector3 operator +(Vector3 a, Vector3 b) => new Vector3(a._x + b._x, a._y + b._y, a._z + b._z);
        public static Vector3 operator -(Vector3 a, Vector3 b) => new Vector3(a._x - b._x, a._y - b._y, a._z - b._z);
        public static Vector3 operator *(Vector3 a, Vector3 b) => new Vector3(a._x * b._x, a._y * b._y, a._z * b._z);
        public static Vector3 operator /(Vector3 a, Vector3 b) => new Vector3(a._x / b._x, a._y / b._y, a._z / b._z);
        public static Vector3 operator *(Vector3 a, double s) { float f = (float)s; return new Vector3(a._x * f, a._y * f, a._z * f); }
        public static Vector3 operator *(double s, Vector3 a) => a * s;
        public static Vector3 operator /(Vector3 a, double s) { float f = (float)s; return new Vector3(a._x / f, a._y / f, a._z / f); }
        public static Vector3 operator -(Vector3 a) => new Vector3(-a._x, -a._y, -a._z);
        public static bool operator ==(Vector3 a, Vector3 b) => a._x == b._x && a._y == b._y && a._z == b._z;
        public static bool operator !=(Vector3 a, Vector3 b) => !(a == b);
        public bool Equals(Vector3 o) => this == o;
        public override bool Equals(object o) => o is Vector3 v && this == v;
        public override int GetHashCode() => (_x.GetHashCode() * 397 ^ _y.GetHashCode()) * 397 ^ _z.GetHashCode();
        public override string ToString() => $"({Gd.Str32(_x)}, {Gd.Str32(_y)}, {Gd.Str32(_z)})";

        public double Dot(Vector3 o) => _x * o._x + _y * o._y + _z * o._z;
        public Vector3 Cross(Vector3 o) =>
            new Vector3(_y * o._z - _z * o._y, _z * o._x - _x * o._z, _x * o._y - _y * o._x);
        public double LengthSquared() { float a = _x * _x, b = _y * _y, c = _z * _z; return a + b + c; }
        public double Length() { float a = _x * _x, b = _y * _y, c = _z * _z; return MathF.Sqrt(a + b + c); }
        public double DistanceTo(Vector3 o) => (o - this).Length();
        public double DistanceSquaredTo(Vector3 o) => (o - this).LengthSquared();
        public Vector3 Normalized()
        {
            if (!float.IsFinite(_x) || !float.IsFinite(_y) || !float.IsFinite(_z)) return ZERO;
            float a = _x * _x, b = _y * _y, c = _z * _z, l = a + b + c;
            if (l == 0f) return ZERO;
            l = MathF.Sqrt(l);
            return new Vector3(_x / l, _y / l, _z / l);
        }
        public Vector3 Abs() => new Vector3(MathF.Abs(_x), MathF.Abs(_y), MathF.Abs(_z));
        public Vector3 Floor() => new Vector3(MathF.Floor(_x), MathF.Floor(_y), MathF.Floor(_z));
        public Vector3 Ceil() => new Vector3(MathF.Ceiling(_x), MathF.Ceiling(_y), MathF.Ceiling(_z));
        public Vector3 Min(Vector3 o) => new Vector3(Gd.Min32(_x, o._x), Gd.Min32(_y, o._y), Gd.Min32(_z, o._z));
        public Vector3 Max(Vector3 o) => new Vector3(Gd.Max32(_x, o._x), Gd.Max32(_y, o._y), Gd.Max32(_z, o._z));
        public Vector3 Lerp(Vector3 to, double weight)
        {
            float w = (float)weight;
            return new Vector3(_x + (to._x - _x) * w, _y + (to._y - _y) * w, _z + (to._z - _z) * w);
        }
        public bool IsZeroApprox() => Gd.IsZero32(_x) && Gd.IsZero32(_y) && Gd.IsZero32(_z);
        internal Vector3 AnyPerpendicular() =>
            Cross(MathF.Abs(_x) <= MathF.Abs(_y) && MathF.Abs(_x) <= MathF.Abs(_z) ? RIGHT : UP).Normalized();
        internal float At(int i) => i == 0 ? _x : i == 1 ? _y : _z;
        public double this[long i]
        {
            get => At((int)i);
            set { if (i == 0) _x = (float)value; else if (i == 1) _y = (float)value; else _z = (float)value; }
        }
    }

    public struct Vector3i : IEquatable<Vector3i>
    {
        int _x, _y, _z;
        public long x { get => _x; set => _x = (int)value; }
        public long y { get => _y; set => _y = (int)value; }
        public long z { get => _z; set => _z = (int)value; }
        internal int X => _x;
        internal int Y => _y;
        internal int Z => _z;

        public Vector3i(long x, long y, long z) { _x = (int)x; _y = (int)y; _z = (int)z; }
        public Vector3i(Vector3i v) { _x = v._x; _y = v._y; _z = v._z; }
        public Vector3i(Vector3 v) { _x = (int)v.X; _y = (int)v.Y; _z = (int)v.Z; }

        public static readonly Vector3i ZERO = new Vector3i(0, 0, 0);
        public static readonly Vector3i ONE = new Vector3i(1, 1, 1);
        public static readonly Vector3i LEFT = new Vector3i(-1, 0, 0);
        public static readonly Vector3i RIGHT = new Vector3i(1, 0, 0);
        public static readonly Vector3i UP = new Vector3i(0, 1, 0);
        public static readonly Vector3i DOWN = new Vector3i(0, -1, 0);
        public static readonly Vector3i FORWARD = new Vector3i(0, 0, -1);
        public static readonly Vector3i BACK = new Vector3i(0, 0, 1);

        public static Vector3i operator +(Vector3i a, Vector3i b) => new Vector3i(a._x + b._x, a._y + b._y, a._z + b._z);
        public static Vector3i operator -(Vector3i a, Vector3i b) => new Vector3i(a._x - b._x, a._y - b._y, a._z - b._z);
        public static Vector3i operator *(Vector3i a, Vector3i b) => new Vector3i(a._x * b._x, a._y * b._y, a._z * b._z);
        public static Vector3i operator /(Vector3i a, Vector3i b) => new Vector3i(a._x / b._x, a._y / b._y, a._z / b._z);
        public static Vector3i operator *(Vector3i a, long s) => new Vector3i(a._x * (int)s, a._y * (int)s, a._z * (int)s);
        public static Vector3i operator *(long s, Vector3i a) => a * s;
        public static Vector3i operator /(Vector3i a, long s) => new Vector3i(a._x / (int)s, a._y / (int)s, a._z / (int)s);
        public static Vector3i operator %(Vector3i a, long s) => new Vector3i(a._x % (int)s, a._y % (int)s, a._z % (int)s);
        public static Vector3 operator *(Vector3i a, double s) => new Vector3(a) * s;
        public static Vector3 operator *(double s, Vector3i a) => new Vector3(a) * s;
        public static Vector3 operator /(Vector3i a, double s) => new Vector3(a) / s;
        public static Vector3i operator -(Vector3i a) => new Vector3i(-a._x, -a._y, -a._z);
        public static bool operator ==(Vector3i a, Vector3i b) => a._x == b._x && a._y == b._y && a._z == b._z;
        public static bool operator !=(Vector3i a, Vector3i b) => !(a == b);
        public static bool operator <(Vector3i a, Vector3i b) =>
            a._x == b._x ? (a._y == b._y ? a._z < b._z : a._y < b._y) : a._x < b._x;
        public static bool operator >(Vector3i a, Vector3i b) =>
            a._x == b._x ? (a._y == b._y ? a._z > b._z : a._y > b._y) : a._x > b._x;
        public bool Equals(Vector3i o) => this == o;
        public override bool Equals(object o) => o is Vector3i v && this == v;
        public override int GetHashCode() => (_x * 397 ^ _y) * 397 ^ _z;
        public override string ToString() => $"({_x}, {_y}, {_z})";

        public long this[long i]
        {
            get => i == 0 ? _x : i == 1 ? _y : _z;
            set { if (i == 0) _x = (int)value; else if (i == 1) _y = (int)value; else _z = (int)value; }
        }
        public Vector3i Abs() => new Vector3i(Math.Abs(_x), Math.Abs(_y), Math.Abs(_z));
        public Vector3i Min(Vector3i o) => new Vector3i(Math.Min(_x, o._x), Math.Min(_y, o._y), Math.Min(_z, o._z));
        public Vector3i Max(Vector3i o) => new Vector3i(Math.Max(_x, o._x), Math.Max(_y, o._y), Math.Max(_z, o._z));
    }

    public struct Vector4
    {
        float _x, _y, _z, _w;
        public double x { get => _x; set => _x = (float)value; }
        public double y { get => _y; set => _y = (float)value; }
        public double z { get => _z; set => _z = (float)value; }
        public double w { get => _w; set => _w = (float)value; }
        public Vector4(double x, double y, double z, double w) { _x = (float)x; _y = (float)y; _z = (float)z; _w = (float)w; }
    }

    public struct Vector4i
    {
        int _x, _y, _z, _w;
        public long x { get => _x; set => _x = (int)value; }
        public long y { get => _y; set => _y = (int)value; }
        public long z { get => _z; set => _z = (int)value; }
        public long w { get => _w; set => _w = (int)value; }
        public Vector4i(long x, long y, long z, long w) { _x = (int)x; _y = (int)y; _z = (int)z; _w = (int)w; }
        internal uint Hash() => GodotHash.Vector4i(_x, _y, _z, _w);
    }
}
