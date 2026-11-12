// GDScript's global functions, copied from core/math/math_funcs.h and variant_utility.cpp
// (Godot Engine, MIT, see docs/LICENSING_REGISTER.md).
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Kaiju.Sim
{
    public static class Gd
    {
        public const double PI = 3.1415926535897932384626433833;
        public const double TAU = 6.2831853071795864769252867666;
        public const double INF = double.PositiveInfinity;
        public const double NAN = double.NaN;
        internal const double CMP_EPSILON = 0.00001;

        public const long TYPE_NIL = 0, TYPE_BOOL = 1, TYPE_INT = 2, TYPE_FLOAT = 3, TYPE_STRING = 4,
            TYPE_VECTOR2 = 5, TYPE_VECTOR2I = 6, TYPE_RECT2 = 7, TYPE_RECT2I = 8, TYPE_VECTOR3 = 9,
            TYPE_VECTOR3I = 10, TYPE_VECTOR4 = 12, TYPE_VECTOR4I = 13, TYPE_AABB = 16, TYPE_BASIS = 17,
            TYPE_TRANSFORM3D = 18, TYPE_COLOR = 20, TYPE_OBJECT = 24, TYPE_CALLABLE = 25,
            TYPE_DICTIONARY = 27, TYPE_ARRAY = 28;

        // ---------- 32-bit helpers the vectors use ----------
        internal static float Min32(float a, float b) => a < b ? a : b;
        internal static float Max32(float a, float b) => a > b ? a : b;
        internal static float Clamp32(float v, float lo, float hi) => v < lo ? lo : (v > hi ? hi : v);
        internal static bool IsZero32(float v) => MathF.Abs(v) < (float)CMP_EPSILON;
        internal static bool IsEqual32(float a, float b)
        {
            if (a == b) return true;
            float tolerance = (float)CMP_EPSILON * MathF.Abs(a);
            if (tolerance < (float)CMP_EPSILON) tolerance = (float)CMP_EPSILON;
            return MathF.Abs(a - b) < tolerance;
        }

        // ---------- maths ----------
        public static double Absf(double v) => Math.Abs(v);
        public static long Absi(long v) => v < 0 ? -v : v;
        public static double Abs(double v) => Math.Abs(v);
        public static double Acos(double x) => x < -1 ? PI : (x > 1 ? 0 : Math.Acos(x));
        public static double Atan2(double y, double x) => Math.Atan2(y, x);
        public static double Ceilf(double v) => Math.Ceiling(v);
        public static long Ceili(double v) => (long)Math.Ceiling(v);
        public static double Clampf(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
        public static long Clampi(long v, long lo, long hi) => v < lo ? lo : (v > hi ? hi : v);
        public static double Cos(double v) => Math.Cos(v);
        // Godot's 32-bit sin, cos and atan2 equal the 64-bit result narrowed (200,000 inputs, 0 differ);
        // MathF's come from each platform's C library and differ between runtimes and machines.
        public static float Sin32(float v) => (float)Math.Sin((double)v);
        public static float Cos32(float v) => (float)Math.Cos((double)v);
        public static float Atan232(float y, float x) => (float)Math.Atan2((double)y, (double)x);
        public static double DegToRad(double y) => y * (PI / 180.0);
        public static double Exp(double v) => Math.Exp(v);
        public static double Floor(double v) => Math.Floor(v);
        public static double Floorf(double v) => Math.Floor(v);
        public static long Floori(double v) => (long)Math.Floor(v);
        public static double Fposmod(double x, double y)
        {
            double value = CFmod(x, y);
            if ((value < 0 && y > 0) || (value > 0 && y < 0)) value += y;
            return value + 0.0;  // Godot's fposmod: -0.0 becomes 0.0
        }
        static double CFmod(double x, double y) => x % y;
        public static long Posmod(long x, long y)
        {
            long value = x % y;
            if ((value < 0 && y > 0) || (value > 0 && y < 0)) value += y;
            return value;
        }
        public static double AngleDifference(double from, double to)
        {
            double d = CFmod(to - from, TAU);
            return CFmod(2.0 * d, TAU) - d;
        }
        public static bool IsEqualApprox(double a, double b)
        {
            if (a == b) return true;
            double tolerance = CMP_EPSILON * Math.Abs(a);
            if (tolerance < CMP_EPSILON) tolerance = CMP_EPSILON;
            return Math.Abs(a - b) < tolerance;
        }
        public static bool IsZeroApprox(double v) => Math.Abs(v) < CMP_EPSILON;
        public static double Lerpf(double from, double to, double w) => from + (to - from) * w;
        public static double Maxf(double a, double b) => a > b ? a : b;
        public static long Maxi(long a, long b) => a > b ? a : b;
        public static double Minf(double a, double b) => a < b ? a : b;
        public static long Mini(long a, long b) => a < b ? a : b;
        public static double MoveToward(double from, double to, double delta) =>
            Math.Abs(to - from) <= delta ? to : from + Signf(to - from) * delta;
        public static double Pow(double x, double y) => Math.Pow(x, y);
        public static double Roundf(double v) => Math.Round(v, MidpointRounding.AwayFromZero);
        public static long Roundi(double v) => (long)Math.Round(v, MidpointRounding.AwayFromZero);
        public static double Signf(double v) => v > 0 ? 1.0 : (v < 0 ? -1.0 : 0.0);
        public static long Signi(long v) => v > 0 ? 1 : (v < 0 ? -1 : 0);
        public static double Sin(double v) => Math.Sin(v);
        public static double Sinh(double v) => Math.Sinh(v);
        public static double Smoothstep(double from, double to, double s)
        {
            if (IsEqualApprox(from, to))
            {
                if (from <= to) return s <= from ? 0.0 : 1.0;
                return s <= to ? 1.0 : 0.0;
            }
            double t = Clampf((s - from) / (to - from), 0.0, 1.0);
            return t * t * (3.0 - 2.0 * t);
        }
        public static double Snappedf(double v, double step) => step != 0 ? Math.Floor(v / step + 0.5) * step : v;
        public static double Sqrt(double v) => Math.Sqrt(v);
        public static double Tan(double v) => Math.Tan(v);
        public static double Wrapf(double v, double lo, double hi)
        {
            double range = hi - lo;
            if (IsZeroApprox(range)) return lo;
            double result = v - (range * Math.Floor((v - lo) / range));
            return IsEqualApprox(result, hi) ? lo : result;
        }

        // ---------- conversions ----------
        public static long Int(Variant v) => v.Obj is string s ? (long)Strtod.Parse(s) : (long)v;
        public static long Int(double v) => (long)v;
        public static long Int(long v) => v;
        public static long Int(bool v) => v ? 1 : 0;
        public static double Float(Variant v) => v.Obj is string s ? Strtod.Parse(s) : (double)v;
        public static double Float(double v) => v;
        public static double Float(long v) => v;
        public static long Typeof(Variant v) => v.Type;
        public static bool IsNull(Variant v) => v.IsNil;
        public static bool IsNull(object v) => v == null;
        public static bool IsSame(Variant a, Variant b) => ReferenceEquals(a.Obj, b.Obj) && (a.Obj != null || a.Equals(b));
        public static Color Color8(long r, long g, long b, long a = 255) => new Color(r / 255f, g / 255f, b / 255f, a / 255f);

        public static void PushError(params Variant[] parts)
        {
            StringBuilder s = new StringBuilder();
            foreach (Variant p in parts) s.Append(Str(p));
            Console.Error.WriteLine(s.ToString());
        }

        public static bool Truthy(bool v) => v;
        public static bool Truthy(long v) => v != 0;
        public static bool Truthy(double v) => v != 0.0;
        public static bool Truthy(string v) => !string.IsNullOrEmpty(v);
        public static bool Truthy(Vector2 v) => v != Vector2.ZERO;
        public static bool Truthy(Vector2i v) => v != Vector2i.ZERO;
        public static bool Truthy(Vector3 v) => v != Vector3.ZERO;
        public static bool Truthy(Vector3i v) => v != Vector3i.ZERO;
        public static bool Truthy(Rect2 v) => v != default;
        public static bool Truthy(Rect2i v) => v != default;
        public static bool Truthy(GDict v) => v != null && !v.IsEmpty();
        public static bool Truthy(IGArray v) => v != null && v.Size() != 0;
        public static bool Truthy(RefCounted v) => v != null;
        public static bool Truthy(Callable v) => v != null && v.IsValid();
        public static bool Truthy(Variant v)
        {
            switch (v.Type)
            {
                case TYPE_NIL: return false;
                case TYPE_BOOL: case TYPE_INT: return (long)v != 0;
                case TYPE_FLOAT: return (double)v != 0.0;
                case TYPE_STRING: return ((string)v.Obj).Length != 0;
                case TYPE_VECTOR2: return (Vector2)v != Vector2.ZERO;
                case TYPE_VECTOR2I: return (Vector2i)v != Vector2i.ZERO;
                case TYPE_VECTOR3: return (Vector3)v != Vector3.ZERO;
                case TYPE_VECTOR3I: return (Vector3i)v != Vector3i.ZERO;
                case TYPE_DICTIONARY: return !((GDict)v.Obj).IsEmpty();
                case TYPE_ARRAY: return ((IGArray)v.Obj).Size() != 0;
                case TYPE_CALLABLE: return ((Callable)v.Obj).IsValid();
                default: return v.Obj != null;
            }
        }

        // GDScript's "is": a Variant's type at run time, and any array passes "is Array".
        public static bool Is<T>(Variant v)
        {
            if (typeof(T) == typeof(Variant)) return true;
            if (typeof(T) == typeof(long)) return v.Type == TYPE_INT;
            if (typeof(T) == typeof(double)) return v.Type == TYPE_FLOAT;
            if (typeof(T) == typeof(bool)) return v.Type == TYPE_BOOL;
            if (typeof(T) == typeof(string)) return v.Type == TYPE_STRING;
            if (typeof(T) == typeof(Vector2)) return v.Type == TYPE_VECTOR2;
            if (typeof(T) == typeof(Vector2i)) return v.Type == TYPE_VECTOR2I;
            if (typeof(T) == typeof(Vector3)) return v.Type == TYPE_VECTOR3;
            if (typeof(T) == typeof(Vector3i)) return v.Type == TYPE_VECTOR3I;
            if (typeof(T) == typeof(GArray<Variant>)) return v.Obj is IGArray && v.Obj.GetType().Name.StartsWith("GArray", StringComparison.Ordinal);
            return v.Obj is T;
        }

        public static bool In(Variant item, Variant holder)
        {
            if (holder.Obj is GDict d) return d.Has(item);
            if (holder.Obj is string s) return s.Contains((string)item.Obj);
            if (holder.Obj is IGArray a)
            {
                for (long i = 0; i < a.Size(); i++) if (a.GetVariant(i).Equals(item)) return true;
                return false;
            }
            throw new InvalidOperationException("'in' on a value that holds nothing");
        }

        // ---------- generic helpers for the containers ----------
        internal static Variant Box<T>(T v)
        {
            switch (v)
            {
                case Variant x: return x;
                case long x: return x;
                case double x: return x;
                case bool x: return x;
                case string x: return x;
                case Vector2 x: return x;
                case Vector2i x: return x;
                case Vector3 x: return x;
                case Vector3i x: return x;
                case Rect2 x: return x;
                case Rect2i x: return x;
                case GDict x: return x;
                case RefCounted x: return x;
                case Callable x: return x;
                case IGArray x: return Variant.OfArray(x, TYPE_ARRAY);
                case null: return default;
                default: throw new InvalidCastException(typeof(T).Name);
            }
        }

        internal static T Cast<T>(Variant v)
        {
            if (typeof(T) == typeof(Variant)) return (T)(object)v;
            if (typeof(T) == typeof(long)) return (T)(object)(long)v;
            if (typeof(T) == typeof(double)) return (T)(object)(double)v;
            if (typeof(T) == typeof(bool)) return (T)(object)Truthy(v);
            if (typeof(T) == typeof(string)) return (T)(object)(string)v;
            if (typeof(T) == typeof(Vector2)) return (T)(object)(Vector2)v;
            if (typeof(T) == typeof(Vector2i)) return (T)(object)(Vector2i)v;
            if (typeof(T) == typeof(Vector3)) return (T)(object)(Vector3)v;
            if (typeof(T) == typeof(Vector3i)) return (T)(object)(Vector3i)v;
            if (typeof(T) == typeof(Rect2)) return (T)(object)(Rect2)v;
            if (typeof(T) == typeof(Rect2i)) return (T)(object)(Rect2i)v;
            return (T)v.Obj;
        }

        internal static T DefaultOf<T>()
        {
            if (typeof(T) == typeof(string)) return (T)(object)"";
            if (typeof(T) == typeof(GDict)) return (T)(object)new GDict();
            // A typed array of arrays resizes to empty arrays, never nulls (LandmarkCells._members).
            if (typeof(IGArray).IsAssignableFrom(typeof(T))) return System.Activator.CreateInstance<T>();
            return default;
        }

        internal static T DeepCopy<T>(T v)
        {
            if (v is GDict d) return (T)(object)d.Duplicate(true);
            if (v is IGArray a) return (T)a.DuplicateAny(true);
            if (v is Variant x)
            {
                if (x.Obj is GDict vd) return (T)(object)(Variant)vd.Duplicate(true);
                if (x.Obj is IGArray va) return (T)(object)Variant.OfArray(va.DuplicateAny(true), TYPE_ARRAY);
            }
            return v;
        }

        internal static Func<T, T, bool> LessOf<T>()
        {
            if (typeof(T) == typeof(long)) return (Func<T, T, bool>)(object)(Func<long, long, bool>)((a, b) => a < b);
            if (typeof(T) == typeof(double)) return (Func<T, T, bool>)(object)(Func<double, double, bool>)((a, b) => a < b);
            if (typeof(T) == typeof(string)) return (Func<T, T, bool>)(object)(Func<string, string, bool>)((a, b) => Less(a, b));
            if (typeof(T) == typeof(Vector2)) return (Func<T, T, bool>)(object)(Func<Vector2, Vector2, bool>)((a, b) => a < b);
            if (typeof(T) == typeof(Vector2i)) return (Func<T, T, bool>)(object)(Func<Vector2i, Vector2i, bool>)((a, b) => a < b);
            return (a, b) => LessVariant(Box(a), Box(b));
        }

        static bool Less(string a, string b) => string.CompareOrdinal(a, b) < 0;

        static bool LessVariant(Variant a, Variant b)
        {
            if (a.Obj is string s && b.Obj is string t) return Less(s, t);
            if (a.Type == TYPE_VECTOR2) return (Vector2)a < (Vector2)b;
            if (a.Type == TYPE_VECTOR2I) return (Vector2i)a < (Vector2i)b;
            return a < b;
        }

        internal static bool ArraysEqual(IGArray a, IGArray b)
        {
            if (ReferenceEquals(a, b)) return true;
            if (a.Size() != b.Size()) return false;
            for (long i = 0; i < a.Size(); i++) if (!a.GetVariant(i).Equals(b.GetVariant(i))) return false;
            return true;
        }

        internal static int ArrayHash(IGArray a)
        {
            int h = 17;
            for (long i = 0; i < a.Size(); i++) h = h * 31 + a.GetVariant(i).GetHashCode();
            return h;
        }

        public static GArray<Variant> Arr(params Variant[] items)
        {
            GArray<Variant> a = new GArray<Variant>(items.Length, true);
            foreach (Variant v in items) a.Add(v);
            return a;
        }

        public static Range Range(long end) => new Range(0, end, 1);
        public static Range Range(long begin, long end) => new Range(begin, end, 1);
        public static Range Range(long begin, long end, long step) => new Range(begin, end, step);

        public static IEnumerable<Variant> Iter(Variant v)
        {
            if (v.Obj is GDict d)
            {
                foreach (Variant k in d) yield return k;
            }
            else if (v.Obj is IGArray a)
            {
                for (long i = 0; i < a.Size(); i++) yield return a.GetVariant(i);
            }
            else
            {
                for (long i = 0; i < (long)v; i++) yield return i;
            }
        }

        // ---------- hash ----------
        public static long Hash(string s) => GodotHash.String(s);
        public static long Hash(Vector4i v) => v.Hash();
        public static long Hash(IGArray a)
        {
            uint[] parts = new uint[a.Size()];
            for (long i = 0; i < a.Size(); i++) parts[i] = HashOne(a.GetVariant(i));
            return GodotHash.Array(parts);
        }
        static uint HashOne(Variant v)
        {
            if (v.Type == TYPE_INT) return GodotHash.Int(v);
            if (v.Type == TYPE_FLOAT) return GodotHash.Double(v);
            if (v.Obj is string s) return GodotHash.String(s);
            throw new InvalidOperationException($"hash of type {v.Type} is not used by the sim");
        }

        // ---------- strings ----------
        public static string Str(Variant v)
        {
            switch (v.Type)
            {
                case TYPE_NIL: return "<null>";
                case TYPE_BOOL: return (long)v != 0 ? "true" : "false";
                case TYPE_INT: return ((long)v).ToString(CultureInfo.InvariantCulture);
                case TYPE_FLOAT: return Str((double)v);
                case TYPE_STRING: return (string)v.Obj;
                case TYPE_VECTOR2: return ((Vector2)v).ToString();
                case TYPE_VECTOR2I: return ((Vector2i)v).ToString();
                case TYPE_VECTOR3: return ((Vector3)v).ToString();
                case TYPE_VECTOR3I: return ((Vector3i)v).ToString();
                case TYPE_RECT2: return ((Rect2)v).ToString();
                case TYPE_RECT2I: return ((Rect2i)v).ToString();
                default: return v.Obj?.ToString() ?? "";
            }
        }
        public static string Str(string v) => v;
        public static string Str(long v) => v.ToString(CultureInfo.InvariantCulture);
        public static string Str(bool v) => v ? "true" : "false";

        // String::num_real(double, true).
        public static string Str(double v)
        {
            if (double.IsNaN(v)) return "nan";
            if (double.IsInfinity(v)) return v > 0 ? "inf" : "-inf";
            if (v == (double)(long)v) return ((long)v).ToString(CultureInfo.InvariantCulture) + ".0";
            int decimals = 14;
            double abs = Math.Abs(v);
            if (abs > 10) decimals -= (int)Math.Floor(Math.Log10(abs));
            string text = v.ToString("F" + decimals, CultureInfo.InvariantCulture).TrimEnd('0');
            return text.EndsWith(".", StringComparison.Ordinal) ? text + "0" : text;
        }
        internal static string Str32(float v) => Str((double)v);

        // GDScript's "text % args": %s %d %f with width and zero padding, which is all sim/ writes.
        public static string Format(string f, Variant args)
        {
            StringBuilder s = new StringBuilder();
            int next = 0;
            IGArray list = args.Obj as IGArray;
            for (int i = 0; i < f.Length; i++)
            {
                if (f[i] != '%') { s.Append(f[i]); continue; }
                i++;
                if (f[i] == '%') { s.Append('%'); continue; }
                bool zero = false;
                int width = 0, precision = -1;
                if (f[i] == '0') { zero = true; i++; }
                while (char.IsDigit(f[i])) width = width * 10 + (f[i++] - '0');
                if (f[i] == '.')
                {
                    i++;
                    precision = 0;
                    while (char.IsDigit(f[i])) precision = precision * 10 + (f[i++] - '0');
                }
                Variant v = list != null ? list.GetVariant(next++) : args;
                string text;
                if (f[i] == 's') text = Str(v);
                else if (f[i] == 'd') text = ((long)v).ToString(CultureInfo.InvariantCulture);
                else if (f[i] == 'f') text = ((double)v).ToString("F" + (precision < 0 ? 6 : precision), CultureInfo.InvariantCulture);
                else throw new FormatException($"%{f[i]} in \"{f}\"");
                s.Append(zero ? text.PadLeft(width, '0') : text.PadLeft(width));
            }
            return s.ToString();
        }
    }

    public struct Range
    {
        readonly long _begin, _end, _step;
        public Range(long begin, long end, long step) { _begin = begin; _end = end; _step = step; }
        public Enumerator GetEnumerator() => new Enumerator(_begin, _end, _step);
        public static implicit operator Variant(Range r)
        {
            GArray<Variant> a = new GArray<Variant>();
            foreach (long i in r) a.Add(i);
            return a;
        }
        public struct Enumerator
        {
            long _at;
            readonly long _end, _step;
            public Enumerator(long begin, long end, long step) { _at = begin - step; _end = end; _step = step; }
            public bool MoveNext()
            {
                _at += _step;
                return _step > 0 ? _at < _end : _at > _end;
            }
            public long Current => _at;
        }
    }

    public static class GdString
    {
        public static string At(this string s, long i) => s[(int)(i < 0 ? i + s.Length : i)].ToString();
        public static bool BeginsWith(this string s, string with) => s.StartsWith(with, StringComparison.Ordinal);
        public static bool IsEmpty(this string s) => s.Length == 0;
        public static long Length(this string s) => s.Length;
        public static string Repeat(this string s, long n)
        {
            StringBuilder b = new StringBuilder();
            for (long i = 0; i < n; i++) b.Append(s);
            return b.ToString();
        }
        public static string Substr(this string s, long from, long len = -1)
        {
            int start = (int)from;
            if (start >= s.Length) return "";
            int count = len < 0 ? s.Length - start : (int)Math.Min(len, s.Length - start);
            return s.Substring(start, count);
        }
        public static double ToFloat(this string s) => Strtod.Parse(s);
        public static PackedByteArray ToAsciiBuffer(this string s)
        {
            PackedByteArray b = new PackedByteArray();
            foreach (char c in s) b.Append(c > 127 ? '?' : c);
            return b;
        }
    }

    // RandomNumberGenerator over the exact PCG in Rng.
    public sealed class RandomNumberGenerator : RefCounted
    {
        readonly Rng _r = new Rng();
        public long seed { get => unchecked((long)_r.Seed); set => _r.Seed = unchecked((ulong)value); }
        public long state { get => unchecked((long)_r.State); set => _r.State = unchecked((ulong)value); }
        public long Randi() => _r.Randi();
        public double Randf() => _r.Randf();
        public double RandfRange(double from, double to) => _r.RandfRange((float)from, (float)to);
        public long RandiRange(long from, long to) => _r.RandiRange((int)from, (int)to);
        public static implicit operator RandomNumberGenerator(Variant v) => (RandomNumberGenerator)v.Obj;
    }

    public sealed class Mutex
    {
        public void Lock() => Monitor.Enter(this);
        public void Unlock() => Monitor.Exit(this);
    }

    public static class WorkerThreadPool
    {
        static long next;
        static readonly Dictionary<long, Task> Open = new Dictionary<long, Task>();

        public static long AddTask(Callable job, bool highPriority = false)
        {
            lock (Open)
            {
                long id = ++next;
                Open[id] = Task.Run(() => job.Call());
                return id;
            }
        }
        public static void WaitForTaskCompletion(long id)
        {
            Task t;
            lock (Open)
            {
                t = Open[id];
                Open.Remove(id);
            }
            t.Wait();
        }
    }

    public static class ClassDB
    {
        // The DLL's classes (Native.cs). Without the DLL, or with UseNative off, the sim takes its
        // own C# passes, which give the same results.
        public static bool UseNative = true;
        public static bool ClassExists(string name) =>
            UseNative && (name == "KaijuSettle" || name == "KaijuWater") && KaijuNative.Available;
        public static RefCounted Instantiate(string name) =>
            !ClassExists(name) ? null : name == "KaijuSettle" ? (RefCounted)new KaijuSettle() : new KaijuWater();
    }

    public static class SimTeardown
    {
        public static void Note(RefCounted sim) { }
        public static void Cut(RefCounted sim) { }
    }

    // res:// resolves against Root, set once at start-up (the repository, or StreamingAssets).
    public sealed class FileAccess
    {
        public const long READ = 1;
        public static string Root = "";
        readonly BinaryReader _r;

        FileAccess(BinaryReader r) { _r = r; }

        static string Real(string path) =>
            path.StartsWith("res://", StringComparison.Ordinal) ? Path.Combine(Root, path.Substring(6)) : path;

        public static bool FileExists(string path) => File.Exists(Real(path));
        public static string GetFileAsString(string path) =>
            File.Exists(Real(path)) ? File.ReadAllText(Real(path)) : "";
        public static FileAccess Open(string path, long mode) =>
            File.Exists(Real(path)) ? new FileAccess(new BinaryReader(File.OpenRead(Real(path)))) : null;

        public PackedByteArray GetBuffer(long n)
        {
            PackedByteArray b = new PackedByteArray();
            byte[] raw = _r.ReadBytes((int)n);
            b.Resize(raw.Length);
            Array.Copy(raw, b.Raw, raw.Length);
            return b;
        }
        public long Get16() => _r.ReadUInt16();
        public long Get32() => _r.ReadUInt32();
    }

    public static class Strtod
    {
        static readonly double[] Powers = { 10.0, 100.0, 1.0e4, 1.0e8, 1.0e16, 1.0e32, 1.0e64, 1.0e128, 1.0e256 };

        // String::to_float and JSON numbers go through built_in_strtod, which is not correctly
        // rounded. Copied so that every number from data lands on Godot's bits.
        public static double Parse(string s)
        {
            int at = 0;
            return Parse(s, ref at);
        }

        public static double Parse(string s, ref int at)
        {
            int p = at;
            while (p < s.Length && (s[p] == ' ' || s[p] == '\t' || s[p] == '\n' || s[p] == '\r')) p++;
            bool negative = false;
            if (p < s.Length && s[p] == '-') { negative = true; p++; }
            else if (p < s.Length && s[p] == '+') { p++; }
            int decPt = -1, mantSize = 0, begin = p;
            for (; p < s.Length; p++, mantSize++)
            {
                char c = s[p];
                if (c < '0' || c > '9')
                {
                    if (c != '.' || decPt >= 0) break;
                    decPt = mantSize;
                }
            }
            int pExp = p;
            int digits = begin;
            int mantChars = pExp - begin;
            int size = decPt < 0 ? mantChars : mantChars - 1;
            if (decPt < 0) decPt = mantChars;
            if (size == 0)
            {
                at = begin;
                return 0.0;
            }
            int fracExp;
            int use = size;
            if (use > 18)
            {
                fracExp = decPt - 18;
                use = 18;
            }
            else
            {
                fracExp = decPt - use;
            }
            long frac1 = 0, frac2 = 0;
            int q = digits;
            for (int left = use; left > 9; left--)
            {
                char c = s[q++];
                if (c == '.') c = s[q++];
                frac1 = 10 * frac1 + (c - '0');
            }
            for (int left = Math.Min(use, 9); left > 0; left--)
            {
                char c = s[q++];
                if (c == '.') c = s[q++];
                frac2 = 10 * frac2 + (c - '0');
            }
            double fraction = 1.0e9 * frac1 + frac2;
            p = pExp;
            int exp = 0;
            bool expNegative = false;
            if (p < s.Length && (s[p] == 'e' || s[p] == 'E'))
            {
                int e = p + 1;
                if (e < s.Length && (s[e] == '-' || s[e] == '+')) { expNegative = s[e] == '-'; e++; }
                if (e < s.Length && s[e] >= '0' && s[e] <= '9')
                {
                    while (e < s.Length && s[e] >= '0' && s[e] <= '9') exp = exp * 10 + (s[e++] - '0');
                    p = e;
                }
            }
            exp = expNegative ? fracExp - exp : fracExp + exp;
            bool divide = exp < 0;
            if (divide) exp = -exp;
            if (exp > 511) exp = 511;
            double dblExp = 1.0;
            for (int d = 0; exp != 0; exp >>= 1, d++)
            {
                if ((exp & 1) != 0) dblExp *= Powers[d];
            }
            fraction = divide ? fraction / dblExp : fraction * dblExp;
            at = p;
            return negative ? -fraction : fraction;
        }
    }

    // Enough of JSON for data/: objects keep their order, numbers are all float, as in Godot.
    public static class JSON
    {
        public static Variant ParseString(string text)
        {
            int at = 0;
            Variant v = Value(text, ref at);
            Skip(text, ref at);
            if (at != text.Length) throw new FormatException($"JSON: stray text at {at}");
            return v;
        }

        static void Skip(string s, ref int at)
        {
            while (at < s.Length && (s[at] == ' ' || s[at] == '\n' || s[at] == '\r' || s[at] == '\t')) at++;
        }

        static Variant Value(string s, ref int at)
        {
            Skip(s, ref at);
            char c = s[at];
            if (c == '{')
            {
                GDict d = new GDict();
                at++;
                Skip(s, ref at);
                if (s[at] == '}') { at++; return d; }
                while (true)
                {
                    Skip(s, ref at);
                    string key = Text(s, ref at);
                    Skip(s, ref at);
                    at++; // :
                    d[key] = Value(s, ref at);
                    Skip(s, ref at);
                    if (s[at++] == '}') return d;
                }
            }
            if (c == '[')
            {
                GArray<Variant> a = new GArray<Variant>();
                at++;
                Skip(s, ref at);
                if (s[at] == ']') { at++; return a; }
                while (true)
                {
                    a.Add(Value(s, ref at));
                    Skip(s, ref at);
                    if (s[at++] == ']') return a;
                }
            }
            if (c == '"') return Text(s, ref at);
            if (string.CompareOrdinal(s, at, "true", 0, 4) == 0) { at += 4; return true; }
            if (string.CompareOrdinal(s, at, "false", 0, 5) == 0) { at += 5; return false; }
            if (string.CompareOrdinal(s, at, "null", 0, 4) == 0) { at += 4; return default(Variant); }
            return Strtod.Parse(s, ref at);
        }

        static string Text(string s, ref int at)
        {
            StringBuilder b = new StringBuilder();
            at++;
            while (s[at] != '"')
            {
                char c = s[at++];
                if (c != '\\') { b.Append(c); continue; }
                c = s[at++];
                switch (c)
                {
                    case 'n': b.Append('\n'); break;
                    case 't': b.Append('\t'); break;
                    case 'r': b.Append('\r'); break;
                    case 'b': b.Append('\b'); break;
                    case 'f': b.Append('\f'); break;
                    case 'u':
                        b.Append((char)Convert.ToInt32(s.Substring(at, 4), 16));
                        at += 4;
                        break;
                    default: b.Append(c); break;
                }
            }
            at++;
            return b.ToString();
        }
    }
}
