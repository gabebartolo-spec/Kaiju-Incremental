using System;

// Godot's Vector3, Basis and Transform3D for the far beast's rig and gait (FarBeastRig, HexapodGait), in doubles and
// Godot axes (y up, a body faces -z): the sim runtime's maths keeps its matrices internal to the sim. Only what
// kaiju_rig.gd, kaiju_gait.gd, gait_hexapod.gd and hexapod_upper.gd use. Pure maths: no UnityEngine.
public struct BV
{
    public double x, y, z;
    public BV(double x, double y, double z) { this.x = x; this.y = y; this.z = z; }

    public static readonly BV ZERO = new BV(0, 0, 0);
    public static readonly BV UP = new BV(0, 1, 0);
    public static readonly BV DOWN = new BV(0, -1, 0);
    public static readonly BV RIGHT = new BV(1, 0, 0);
    public static readonly BV BACK = new BV(0, 0, 1);
    public static readonly BV FORWARD = new BV(0, 0, -1);
    const double TINY = 1e-12;

    public static BV operator +(BV a, BV b) => new BV(a.x + b.x, a.y + b.y, a.z + b.z);
    public static BV operator -(BV a, BV b) => new BV(a.x - b.x, a.y - b.y, a.z - b.z);
    public static BV operator -(BV a) => new BV(-a.x, -a.y, -a.z);
    public static BV operator *(BV a, double s) => new BV(a.x * s, a.y * s, a.z * s);
    public static BV operator *(double s, BV a) => a * s;
    public static BV operator /(BV a, double s) => new BV(a.x / s, a.y / s, a.z / s);
    public static bool operator ==(BV a, BV b) => a.x == b.x && a.y == b.y && a.z == b.z;
    public static bool operator !=(BV a, BV b) => !(a == b);
    public override bool Equals(object o) => o is BV v && v == this;
    public override int GetHashCode() => x.GetHashCode() ^ y.GetHashCode() << 2 ^ z.GetHashCode() >> 2;

    public double Dot(BV o) => x * o.x + y * o.y + z * o.z;
    public BV Cross(BV o) => new BV(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
    public double Length() => Math.Sqrt(Dot(this));
    public BV Normalized() { double l = Length(); return l < TINY ? ZERO : this / l; }
    public BV Lerp(BV to, double w) => this + (to - this) * w;

    public BV MoveToward(BV to, double delta)
    {
        BV d = to - this;
        double l = d.Length();
        return l <= delta || l < TINY ? to : this + d / l * delta;
    }

    // Vector3::get_any_perpendicular.
    public BV AnyPerpendicular()
    {
        double ax = Math.Abs(x), ay = Math.Abs(y), az = Math.Abs(z);
        BV other = ax <= ay && ax <= az ? RIGHT : ay <= az ? UP : BACK;
        return Cross(other).Normalized();
    }
}

// A 3x3 basis as Godot keeps it: rows; its columns are the axes (x, y, z).
public struct BB
{
    public BV r0, r1, r2;
    public BB(BV r0, BV r1, BV r2) { this.r0 = r0; this.r1 = r1; this.r2 = r2; }

    public static readonly BB IDENTITY = new BB(BV.RIGHT, BV.UP, BV.BACK);

    public BV X => new BV(r0.x, r1.x, r2.x);
    public BV Y => new BV(r0.y, r1.y, r2.y);
    public BV Z => new BV(r0.z, r1.z, r2.z);

    public static BB FromColumns(BV x, BV y, BV z) => new BB(new BV(x.x, y.x, z.x), new BV(x.y, y.y, z.y), new BV(x.z, y.z, z.z));

    // Basis(axis, angle).
    public static BB Axis(BV axis, double angle)
    {
        double c = Math.Cos(angle), s = Math.Sin(angle), t = 1.0 - c;
        double x = axis.x, y = axis.y, z = axis.z;
        return new BB(
            new BV(x * x + c * (1.0 - x * x), x * y * t - z * s, x * z * t + y * s),
            new BV(x * y * t + z * s, y * y + c * (1.0 - y * y), y * z * t - x * s),
            new BV(x * z * t - y * s, y * z * t + x * s, z * z + c * (1.0 - z * z)));
    }

    // Basis.from_euler (Godot's default order YXZ: yaw, then pitch, then roll).
    public static BB Euler(BV e) => Axis(BV.UP, e.y) * Axis(BV.RIGHT, e.x) * Axis(BV.BACK, e.z);

    // Basis(Quaternion(from, to)): the shortest turn taking one direction to the other.
    public static BB Arc(BV from, BV to)
    {
        const double PARALLEL = 0.999999;
        BV a = from.Normalized(), b = to.Normalized();
        double d = a.Dot(b);
        if (d > PARALLEL) return IDENTITY;
        if (d < -PARALLEL) return Axis(a.AnyPerpendicular(), Math.PI);
        BV axis = a.Cross(b).Normalized();
        return Axis(axis, Math.Acos(Math.Max(-1.0, Math.Min(1.0, d))));
    }

    // Basis.looking_at(target): -z towards the target, y as near up as it can be.
    public static BB LookingAt(BV target)
    {
        BV z = (-target).Normalized();
        BV x = BV.UP.Cross(z).Normalized();
        return FromColumns(x, z.Cross(x), z);
    }

    public static BB Scale(BV s) => new BB(new BV(s.x, 0, 0), new BV(0, s.y, 0), new BV(0, 0, s.z));

    public static BB operator *(BB a, BB b)
    {
        BV c0 = b.X, c1 = b.Y, c2 = b.Z;
        return new BB(new BV(a.r0.Dot(c0), a.r0.Dot(c1), a.r0.Dot(c2)),
            new BV(a.r1.Dot(c0), a.r1.Dot(c1), a.r1.Dot(c2)),
            new BV(a.r2.Dot(c0), a.r2.Dot(c1), a.r2.Dot(c2)));
    }

    public static BV operator *(BB a, BV v) => new BV(a.r0.Dot(v), a.r1.Dot(v), a.r2.Dot(v));

    public BB Inverse()
    {
        BV c0 = r1.Cross(r2), c1 = r2.Cross(r0), c2 = r0.Cross(r1);
        double det = r0.Dot(c0);
        return FromColumns(c0 / det, c1 / det, c2 / det);
    }

    public BB Orthonormalized()
    {
        BV x = X.Normalized(), y = Y, z = Z;
        y = (y - x * x.Dot(y)).Normalized();
        z = (z - x * x.Dot(z) - y * y.Dot(z)).Normalized();
        return FromColumns(x, y, z);
    }
}

// A Transform3D: basis then origin.
public struct BT
{
    public BB basis;
    public BV origin;
    public BT(BB basis, BV origin) { this.basis = basis; this.origin = origin; }

    public static readonly BT IDENTITY = new BT(BB.IDENTITY, BV.ZERO);

    const int ROW_LAST = 11;

    // A rig.json row's 12 numbers (export_slice.gd _xf): the basis columns x, y, z, then the origin.
    public static BT FromRow(double[] f) =>
        new BT(BB.FromColumns(new BV(f[0], f[1], f[2]), new BV(f[3], f[4], f[5]), new BV(f[6], f[7], f[8])), new BV(f[9], f[10], f[ROW_LAST]));

    public static BT operator *(BT a, BT b) => new BT(a.basis * b.basis, a * b.origin);
    public static BV operator *(BT a, BV v) => a.basis * v + a.origin;

    public BT AffineInverse()
    {
        BB inv = basis.Inverse();
        return new BT(inv, inv * -origin);
    }
}

// The GDScript maths the gait calls by name.
public static class BMath
{
    public static double Clamp(double v, double lo, double hi) => v < lo ? lo : v > hi ? hi : v;

    public static double Wrap(double v, double lo, double hi)
    {
        double range = hi - lo;
        return range == 0 ? lo : lo + ((v - lo) % range + range) % range;
    }

    // rotate_toward(from, to, delta): from turned at most delta towards to, the short way round.
    public static double RotateToward(double from, double to, double delta)
    {
        double diff = Wrap(to - from, -Math.PI, Math.PI);
        double abs = Math.Abs(diff);
        return from + Clamp(delta, abs - Math.PI, abs) * (diff >= 0 ? 1.0 : -1.0);
    }
}
