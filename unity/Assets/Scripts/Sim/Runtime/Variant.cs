// GDScript's Variant: any value, with the type it was assigned. Numbers and small vectors sit inline
// so reading tuning does not allocate.
using System;
using System.Runtime.CompilerServices;

namespace Kaiju.Sim
{
    public class RefCounted
    {
        static long nextId;
        long id;
        public long GetInstanceId() => id != 0 ? id : (id = System.Threading.Interlocked.Increment(ref nextId));
        public virtual bool HasMethod(string name) => false;
        // Only the native classes (Native.cs) answer this.
        public virtual Variant Call(string name, params Variant[] args) => throw new InvalidOperationException(name);
    }

    public interface IGArray
    {
        long Size();
        Variant GetVariant(long i);
        object DuplicateAny(bool deep);
        void AppendVariant(Variant v);
    }

    public struct Variant : IEquatable<Variant>
    {
        readonly byte _t;
        readonly long _a, _b;
        readonly object _o;

        Variant(long t, long a, long b, object o) { _t = (byte)t; _a = a; _b = b; _o = o; }

        public long Type => _t;
        public bool IsNil => _t == Gd.TYPE_NIL;
        public object Obj => _o;

        static long Bits(double d) => BitConverter.DoubleToInt64Bits(d);
        static long Pack(float x, float y) =>
            (long)(uint)BitConverter.SingleToInt32Bits(x) | ((long)BitConverter.SingleToInt32Bits(y) << 32);
        static long Pack(int x, int y) => (long)(uint)x | ((long)y << 32);
        static float Lo32(long v) => BitConverter.Int32BitsToSingle((int)v);
        static float Hi32(long v) => BitConverter.Int32BitsToSingle((int)(v >> 32));

        public static implicit operator Variant(bool v) => new Variant(Gd.TYPE_BOOL, v ? 1 : 0, 0, null);
        public static implicit operator Variant(long v) => new Variant(Gd.TYPE_INT, v, 0, null);
        public static implicit operator Variant(double v) => new Variant(Gd.TYPE_FLOAT, Bits(v), 0, null);
        public static implicit operator Variant(string v) => new Variant(Gd.TYPE_STRING, 0, 0, v);
        public static implicit operator Variant(Vector2 v) => new Variant(Gd.TYPE_VECTOR2, Pack(v.X, v.Y), 0, null);
        public static implicit operator Variant(Vector2i v) => new Variant(Gd.TYPE_VECTOR2I, Pack(v.X, v.Y), 0, null);
        public static implicit operator Variant(Vector3 v) => new Variant(Gd.TYPE_VECTOR3, Pack(v.X, v.Y), BitConverter.SingleToInt32Bits(v.Z), null);
        public static implicit operator Variant(Vector3i v) => new Variant(Gd.TYPE_VECTOR3I, Pack(v.X, v.Y), v.Z, null);
        public static implicit operator Variant(Rect2 v) => new Variant(Gd.TYPE_RECT2, Pack(v.position.X, v.position.Y), Pack(v.size.X, v.size.Y), null);
        public static implicit operator Variant(Rect2i v) => new Variant(Gd.TYPE_RECT2I, Pack(v.position.X, v.position.Y), Pack(v.size.X, v.size.Y), null);
        public static implicit operator Variant(Vector4i v) => new Variant(Gd.TYPE_VECTOR4I, 0, 0, v);
        public static implicit operator Variant(Vector4 v) => new Variant(Gd.TYPE_VECTOR4, 0, 0, v);
        public static implicit operator Variant(Color v) => new Variant(Gd.TYPE_COLOR, 0, 0, v);
        public static implicit operator Variant(AABB v) => new Variant(Gd.TYPE_AABB, 0, 0, v);
        public static implicit operator Variant(Basis v) => new Variant(Gd.TYPE_BASIS, 0, 0, v);
        public static implicit operator Variant(Transform3D v) => new Variant(Gd.TYPE_TRANSFORM3D, 0, 0, v);
        public static implicit operator Variant(GDict v) => v == null ? default : new Variant(Gd.TYPE_DICTIONARY, 0, 0, v);
        public static implicit operator Variant(Callable v) => v == null ? default : new Variant(Gd.TYPE_CALLABLE, 0, 0, v);
        public static implicit operator Variant(RefCounted v) => v == null ? default : new Variant(Gd.TYPE_OBJECT, 0, 0, v);

        internal static Variant OfArray(object array, long type) => array == null ? default : new Variant(type, 0, 0, array);

        public static implicit operator bool(Variant v) => Gd.Truthy(v);
        public static implicit operator long(Variant v) =>
            v._t == Gd.TYPE_FLOAT ? (long)BitConverter.Int64BitsToDouble(v._a) : v._a;
        public static implicit operator double(Variant v) =>
            v._t == Gd.TYPE_FLOAT ? BitConverter.Int64BitsToDouble(v._a) : v._a;
        public static implicit operator string(Variant v) => v._t == Gd.TYPE_NIL ? "" : v._o as string ?? Gd.Str(v);
        public static implicit operator Vector2(Variant v) =>
            v._t == Gd.TYPE_VECTOR2I ? new Vector2((int)v._a, (int)(v._a >> 32)) : new Vector2(Lo32(v._a), Hi32(v._a));
        public static implicit operator Vector2i(Variant v) => new Vector2i((int)v._a, (int)(v._a >> 32));
        public static implicit operator Vector3(Variant v) =>
            new Vector3(Lo32(v._a), Hi32(v._a), BitConverter.Int32BitsToSingle((int)v._b));
        public static implicit operator Vector3i(Variant v) => new Vector3i((int)v._a, (int)(v._a >> 32), v._b);
        public static implicit operator Rect2(Variant v) =>
            new Rect2(new Vector2(Lo32(v._a), Hi32(v._a)), new Vector2(Lo32(v._b), Hi32(v._b)));
        public static implicit operator Rect2i(Variant v) => new Rect2i(
            new Vector2i((int)v._a, (int)(v._a >> 32)), new Vector2i((int)v._b, (int)(v._b >> 32)));
        public static implicit operator Vector4i(Variant v) => (Vector4i)v._o;
        public static implicit operator Vector4(Variant v) => (Vector4)v._o;
        public static implicit operator Color(Variant v) => (Color)v._o;
        public static implicit operator AABB(Variant v) => (AABB)v._o;
        public static implicit operator Basis(Variant v) => (Basis)v._o;
        public static implicit operator Transform3D(Variant v) => (Transform3D)v._o;
        public static implicit operator GDict(Variant v) => (GDict)v._o;
        public static implicit operator Callable(Variant v) => (Callable)v._o;
        public static implicit operator RefCounted(Variant v) => (RefCounted)v._o;

        // Indexing a value whose type only shows at run time, as GDScript does.
        public Variant this[Variant key]
        {
            get
            {
                if (_o is GDict d) return d[key];
                if (_o is IGArray a) return a.GetVariant(key);
                if (_o is string s) return s[(int)(long)key].ToString();
                if (_t == Gd.TYPE_VECTOR2) { Vector2 v = this; return (long)key == 0 ? v.x : v.y; }
                if (_t == Gd.TYPE_VECTOR2I) { Vector2i v = this; return (long)key == 0 ? v.x : v.y; }
                throw new InvalidOperationException($"cannot index type {_t}");
            }
            set
            {
                if (_o is GDict d) { d[key] = value; return; }
                if (_o is GArray<Variant> a) { a[key] = value; return; }
                throw new InvalidOperationException($"cannot write into type {_t}");
            }
        }

        public Variant Get(Variant key, Variant fallback = default) =>
            ((GDict)_o).Get(key, fallback);
        public bool Has(Variant key) => Gd.In(key, this);
        public long Size() => _o is GDict d ? d.Size() : _o is IGArray a ? a.Size() : ((string)_o).Length;
        public bool IsEmpty() => Size() == 0;

        public bool IsNumber => _t == Gd.TYPE_INT || _t == Gd.TYPE_FLOAT;
        double Num => _t == Gd.TYPE_FLOAT ? BitConverter.Int64BitsToDouble(_a) : _a;

        public bool Equals(Variant o)
        {
            if (_t == o._t)
            {
                if (_t == Gd.TYPE_FLOAT) return Num == o.Num;
                if (_o == null && o._o == null) return _a == o._a && _b == o._b;
                if (_o is string s) return string.Equals(s, o._o as string, StringComparison.Ordinal);
                if (_o is GDict d) return d.DeepEquals((GDict)o._o);
                if (_o is IGArray x) return Gd.ArraysEqual(x, (IGArray)o._o);
                return Equals(_o, o._o);
            }
            return IsNumber && o.IsNumber && Num == o.Num;
        }

        public override bool Equals(object o) => o is Variant v && Equals(v);

        public override int GetHashCode()
        {
            if (_o is string s) return s.GetHashCode();
            if (_o is GDict d) return d.DeepHash();
            if (_o is IGArray a) return Gd.ArrayHash(a);
            if (_o is RefCounted) return RuntimeHelpers.GetHashCode(_o);
            if (_o != null) return _o.GetHashCode();
            return (_a.GetHashCode() * 397 ^ _b.GetHashCode()) * 31 + _t;
        }

        public override string ToString() => Gd.Str(this);

        public static bool operator ==(Variant a, Variant b) => a.Equals(b);
        public static bool operator !=(Variant a, Variant b) => !a.Equals(b);
        public static bool operator ==(Variant a, string b) => a.Equals((Variant)b);
        public static bool operator !=(Variant a, string b) => !a.Equals((Variant)b);
        public static bool operator ==(string a, Variant b) => b.Equals((Variant)a);
        public static bool operator !=(string a, Variant b) => !b.Equals((Variant)a);
        public static bool operator ==(Variant a, long b) => a.Equals((Variant)b);
        public static bool operator !=(Variant a, long b) => !a.Equals((Variant)b);
        public static bool operator ==(long a, Variant b) => b.Equals((Variant)a);
        public static bool operator !=(long a, Variant b) => !b.Equals((Variant)a);
        public static bool operator ==(Variant a, double b) => a.Equals((Variant)b);
        public static bool operator !=(Variant a, double b) => !a.Equals((Variant)b);
        public static bool operator ==(double a, Variant b) => b.Equals((Variant)a);
        public static bool operator !=(double a, Variant b) => !b.Equals((Variant)a);
        public static bool operator ==(Variant a, bool b) => a.Equals((Variant)b);
        public static bool operator !=(Variant a, bool b) => !a.Equals((Variant)b);
        public static bool operator ==(Variant a, Vector2i b) => a.Equals((Variant)b);
        public static bool operator !=(Variant a, Vector2i b) => !a.Equals((Variant)b);
        public static bool operator ==(Vector2i a, Variant b) => b.Equals((Variant)a);
        public static bool operator !=(Vector2i a, Variant b) => !b.Equals((Variant)a);
        public static bool operator ==(Variant a, Vector3i b) => a.Equals((Variant)b);
        public static bool operator !=(Variant a, Vector3i b) => !a.Equals((Variant)b);
        public static bool operator ==(Variant a, RefCounted b) => a.Equals((Variant)b);
        public static bool operator !=(Variant a, RefCounted b) => !a.Equals((Variant)b);

        static bool BothInt(Variant a, Variant b) => a._t == Gd.TYPE_INT && b._t == Gd.TYPE_INT;
        public static Variant operator +(Variant a, Variant b)
        {
            if (a._o is string s) return s + (string)b;
            if (BothInt(a, b)) return a._a + b._a;
            if (a._t == Gd.TYPE_VECTOR2) return (Vector2)a + (Vector2)b;
            if (a._t == Gd.TYPE_VECTOR2I) return (Vector2i)a + (Vector2i)b;
            return a.Num + b.Num;
        }
        public static Variant operator -(Variant a, Variant b)
        {
            if (BothInt(a, b)) return a._a - b._a;
            if (a._t == Gd.TYPE_VECTOR2) return (Vector2)a - (Vector2)b;
            if (a._t == Gd.TYPE_VECTOR2I) return (Vector2i)a - (Vector2i)b;
            return a.Num - b.Num;
        }
        public static Variant operator *(Variant a, Variant b)
        {
            if (BothInt(a, b)) return a._a * b._a;
            if (a._t == Gd.TYPE_VECTOR2) return (Vector2)a * b.Num;
            return a.Num * b.Num;
        }
        public static Variant operator /(Variant a, Variant b)
        {
            if (BothInt(a, b)) return a._a / b._a;
            return a.Num / b.Num;
        }
        public static Variant operator -(Variant a)
        {
            if (a._t == Gd.TYPE_INT) return -a._a;
            return -a.Num;
        }
        public static Variant operator +(Variant a, long b) => a + (Variant)b;
        public static Variant operator +(long a, Variant b) => (Variant)a + b;
        public static Variant operator +(Variant a, double b) => a + (Variant)b;
        public static Variant operator +(double a, Variant b) => (Variant)a + b;
        public static Variant operator +(Variant a, string b) => a + (Variant)b;
        public static Variant operator +(string a, Variant b) => (Variant)a + b;
        public static Variant operator -(Variant a, long b) => a - (Variant)b;
        public static Variant operator -(long a, Variant b) => (Variant)a - b;
        public static Variant operator -(Variant a, double b) => a - (Variant)b;
        public static Variant operator -(double a, Variant b) => (Variant)a - b;
        public static Variant operator *(Variant a, long b) => a * (Variant)b;
        public static Variant operator *(long a, Variant b) => (Variant)a * b;
        public static Variant operator *(Variant a, double b) => a * (Variant)b;
        public static Variant operator *(double a, Variant b) => (Variant)a * b;
        public static Variant operator /(Variant a, long b) => a / (Variant)b;
        public static Variant operator /(long a, Variant b) => (Variant)a / b;
        public static Variant operator /(Variant a, double b) => a / (Variant)b;
        public static Variant operator /(double a, Variant b) => (Variant)a / b;
        public static bool operator <(Variant a, Variant b) => a.Num < b.Num;
        public static bool operator >(Variant a, Variant b) => a.Num > b.Num;
        public static bool operator <=(Variant a, Variant b) => a.Num <= b.Num;
        public static bool operator >=(Variant a, Variant b) => a.Num >= b.Num;
        public static bool operator <(Variant a, long b) => a.Num < b;
        public static bool operator >(Variant a, long b) => a.Num > b;
        public static bool operator <=(Variant a, long b) => a.Num <= b;
        public static bool operator >=(Variant a, long b) => a.Num >= b;
        public static bool operator <(long a, Variant b) => a < b.Num;
        public static bool operator >(long a, Variant b) => a > b.Num;
        public static bool operator <=(long a, Variant b) => a <= b.Num;
        public static bool operator >=(long a, Variant b) => a >= b.Num;
        public static bool operator <(Variant a, double b) => a.Num < b;
        public static bool operator >(Variant a, double b) => a.Num > b;
        public static bool operator <=(Variant a, double b) => a.Num <= b;
        public static bool operator >=(Variant a, double b) => a.Num >= b;
        public static bool operator <(double a, Variant b) => a < b.Num;
        public static bool operator >(double a, Variant b) => a > b.Num;
        public static bool operator <=(double a, Variant b) => a <= b.Num;
        public static bool operator >=(double a, Variant b) => a >= b.Num;
    }

    public class Callable
    {
        readonly Func<Variant[], Variant> _f;
        public Callable() { }
        public Callable(Func<Variant[], Variant> f) { _f = f; }
        public bool IsValid() => _f != null;
        public Variant Call(params Variant[] args) => _f(args);
    }
}
