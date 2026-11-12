// GDScript's Array, Dictionary and Packed*Array. Sort is Godot's own unstable introsort
// (core/templates/sort_array.h, Godot Engine, MIT): equal keys must land where Godot leaves them.
using System;
using System.Collections.Generic;
using System.Text;

namespace Kaiju.Sim
{
    public static class GodotSort
    {
        const long Threshold = 16;

        public static void Sort<T>(T[] a, long n, Func<T, T, bool> less)
        {
            if (n == 0) return;
            Introsort(a, 0, n, Bitlog(n) * 2, less);
            FinalInsertion(a, 0, n, less);
        }

        static long Bitlog(long n) { long k = 0; for (; n != 1; n >>= 1) k++; return k; }

        static long MedianOf3<T>(T[] p, long ai, long bi, long ci, Func<T, T, bool> c)
        {
            T a = p[ai], b = p[bi], d = p[ci];
            if (c(a, b))
            {
                if (c(b, d)) return bi;
                return c(a, d) ? ci : ai;
            }
            if (c(a, d)) return ai;
            return c(b, d) ? ci : bi;
        }

        static void PushHeap<T>(T[] p, long first, long hole, long top, T value, Func<T, T, bool> c)
        {
            long parent = (hole - 1) / 2;
            while (hole > top && c(p[first + parent], value))
            {
                p[first + hole] = p[first + parent];
                hole = parent;
                parent = (hole - 1) / 2;
            }
            p[first + hole] = value;
        }

        static void AdjustHeap<T>(T[] p, long first, long hole, long len, T value, Func<T, T, bool> c)
        {
            long top = hole, second = 2 * hole + 2;
            while (second < len)
            {
                if (c(p[first + second], p[first + (second - 1)])) second--;
                p[first + hole] = p[first + second];
                hole = second;
                second = 2 * (second + 1);
            }
            if (second == len)
            {
                p[first + hole] = p[first + (second - 1)];
                hole = second - 1;
            }
            PushHeap(p, first, hole, top, value, c);
        }

        static void PartialSort<T>(T[] p, long first, long last, Func<T, T, bool> c)
        {
            long len = last - first;
            if (len >= 2)
            {
                long parent = (len - 2) / 2;
                while (true)
                {
                    AdjustHeap(p, first, parent, len, p[first + parent], c);
                    if (parent == 0) break;
                    parent--;
                }
            }
            while (last - first > 1)
            {
                long end = last - 1;
                T value = p[end];
                p[end] = p[first];
                AdjustHeap(p, first, 0, end - first, value, c);
                last--;
            }
        }

        static long Partition<T>(T[] p, long first, long last, long pivot, Func<T, T, bool> c)
        {
            long at = pivot;
            while (true)
            {
                while (first != pivot && c(p[first], p[at])) first++;
                last--;
                while (last != pivot && c(p[at], p[last])) last--;
                if (first >= last) return first;
                if (at == first) at = last;
                else if (at == last) at = first;
                T t = p[first]; p[first] = p[last]; p[last] = t;
                first++;
            }
        }

        static void Introsort<T>(T[] p, long first, long last, long depth, Func<T, T, bool> c)
        {
            while (last - first > Threshold)
            {
                if (depth == 0) { PartialSort(p, first, last, c); return; }
                depth--;
                long cut = Partition(p, first, last, MedianOf3(p, first, first + (last - first) / 2, last - 1, c), c);
                Introsort(p, cut, last, depth, c);
                last = cut;
            }
        }

        static void UnguardedInsert<T>(T[] p, long last, T value, Func<T, T, bool> c)
        {
            long next = last - 1;
            while (c(value, p[next]))
            {
                p[last] = p[next];
                last = next;
                next--;
            }
            p[last] = value;
        }

        static void Insertion<T>(T[] p, long first, long last, Func<T, T, bool> c)
        {
            if (first == last) return;
            for (long i = first + 1; i != last; i++)
            {
                T val = p[i];
                if (c(val, p[first]))
                {
                    for (long k = i; k > first; k--) p[k] = p[k - 1];
                    p[first] = val;
                }
                else
                {
                    UnguardedInsert(p, i, val, c);
                }
            }
        }

        static void FinalInsertion<T>(T[] p, long first, long last, Func<T, T, bool> c)
        {
            if (last - first > Threshold)
            {
                Insertion(p, first, first + Threshold, c);
                for (long i = first + Threshold; i != last; i++) UnguardedInsert(p, i, p[i], c);
            }
            else
            {
                Insertion(p, first, last, c);
            }
        }
    }

    public class GArray<T> : IGArray, System.Collections.IEnumerable
    {
        T[] _p;
        int _n;

        public GArray() { _p = new T[4]; }
        public GArray(long capacity, bool reserve) { _p = new T[Math.Max(4, (int)capacity)]; }
        // Every array converts to Variant, so this one copying constructor takes them all.
        public GArray(Variant from)
        {
            IGArray a = (IGArray)from.Obj;
            _p = new T[Math.Max(4, (int)a.Size())];
            for (long i = 0; i < a.Size(); i++) Add(Gd.Cast<T>(a.GetVariant(i)));
        }

        System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator()
        {
            for (int i = 0; i < _n; i++) yield return _p[i];
        }

        public static GArray<T> operator +(GArray<T> a, GArray<T> b)
        {
            GArray<T> c = a.Duplicate();
            c.AppendArray(b);
            return c;
        }

        public static implicit operator Variant(GArray<T> a) => Variant.OfArray(a, Gd.TYPE_ARRAY);
        public static implicit operator GArray<T>(Variant v) =>
            v.Obj == null ? null : v.Obj as GArray<T> ?? new GArray<T>(v);
        public static implicit operator GArray<T>(GArray<Variant> a) =>
            a == null ? null : a as GArray<T> ?? new GArray<T>(Variant.OfArray(a, Gd.TYPE_ARRAY));
        public static implicit operator GArray<Variant>(GArray<T> a) =>
            a == null ? null : a as GArray<Variant> ?? new GArray<Variant>(Variant.OfArray(a, Gd.TYPE_ARRAY));

        public void Add(T v)
        {
            if (_n == _p.Length) Array.Resize(ref _p, _n * 2);
            _p[_n++] = v;
        }

        long Wrap(long i)
        {
            if (i < 0) i += _n;
            if (i < 0 || i >= _n) throw new IndexOutOfRangeException($"index {i} of {_n}");
            return i;
        }

        public T this[long i]
        {
            get => _p[Wrap(i)];
            set => _p[Wrap(i)] = value;
        }

        public Enumerator GetEnumerator() => new Enumerator(this);
        public struct Enumerator
        {
            readonly GArray<T> _a;
            int _i;
            public Enumerator(GArray<T> a) { _a = a; _i = -1; }
            public bool MoveNext() => ++_i < _a._n;
            public T Current => _a._p[_i];
        }

        public long Size() => _n;
        public bool IsEmpty() => _n == 0;
        public Variant GetVariant(long i) => Gd.Box(_p[Wrap(i)]);
        public void AppendVariant(Variant v) => Add(Gd.Cast<T>(v));
        public object DuplicateAny(bool deep) => Duplicate(deep);
        public void Append(T v) => Add(v);
        public void PushBack(T v) => Add(v);
        public void PushFront(T v) => Insert(0, v);
        public void Clear() { Array.Clear(_p, 0, _n); _n = 0; }
        public T Back() => _p[_n - 1];
        public T Front() => _p[0];
        public T PopBack()
        {
            if (_n == 0) return default;
            T v = _p[--_n];
            _p[_n] = default;
            return v;
        }
        public T PopFront()
        {
            if (_n == 0) return default;
            T v = _p[0];
            RemoveAt(0);
            return v;
        }
        public void Insert(long at, T v)
        {
            if (at < 0) at += _n;
            Add(v);
            Array.Copy(_p, at, _p, at + 1, _n - 1 - at);
            _p[at] = v;
        }
        public void RemoveAt(long at)
        {
            at = Wrap(at);
            Array.Copy(_p, at + 1, _p, at, _n - 1 - at);
            _p[--_n] = default;
        }
        public long Find(T v, long from = 0)
        {
            EqualityComparer<T> eq = EqualityComparer<T>.Default;
            for (long i = from; i < _n; i++) if (eq.Equals(_p[i], v)) return i;
            return -1;
        }
        public bool Has(T v) => Find(v) >= 0;
        public void Erase(T v)
        {
            long at = Find(v);
            if (at >= 0) RemoveAt(at);
        }
        public void Resize(long size)
        {
            int s = (int)size;
            if (s > _p.Length) Array.Resize(ref _p, Math.Max(s, _p.Length * 2));
            if (s < _n) Array.Clear(_p, s, _n - s);
            else for (int i = _n; i < s; i++) _p[i] = Gd.DefaultOf<T>();
            _n = s;
        }
        public void Fill(T v) { for (int i = 0; i < _n; i++) _p[i] = v; }
        public void AppendArray(GArray<T> o)
        {
            int count = o._n;
            for (int i = 0; i < count; i++) Add(o._p[i]);
        }
        public long Count(T v)
        {
            long c = 0;
            EqualityComparer<T> eq = EqualityComparer<T>.Default;
            for (int i = 0; i < _n; i++) if (eq.Equals(_p[i], v)) c++;
            return c;
        }
        public void Assign(Variant from)
        {
            if (ReferenceEquals(from.Obj, this)) return;
            IGArray o = (IGArray)from.Obj;
            Clear();
            for (long i = 0; i < o.Size(); i++) Add(Gd.Cast<T>(o.GetVariant(i)));
        }
        public GArray<T> Duplicate(bool deep = false)
        {
            GArray<T> c = new GArray<T>(_n, true);
            for (int i = 0; i < _n; i++) c.Add(deep ? Gd.DeepCopy(_p[i]) : _p[i]);
            return c;
        }
        public GArray<T> Slice(long begin, long end = int.MaxValue)
        {
            if (begin < 0) begin = Math.Max(0, begin + _n);
            if (end < 0) end += _n;
            end = Math.Min(end, _n);
            GArray<T> c = new GArray<T>(Math.Max(0, end - begin), true);
            for (long i = begin; i < end; i++) c.Add(_p[i]);
            return c;
        }
        public GArray<T> Filter(Callable f)
        {
            GArray<T> c = new GArray<T>();
            for (int i = 0; i < _n; i++) if (Gd.Truthy(f.Call(Gd.Box(_p[i])))) c.Add(_p[i]);
            return c;
        }
        public GArray<Variant> Map(Callable f)
        {
            GArray<Variant> c = new GArray<Variant>(_n, true);
            for (int i = 0; i < _n; i++) c.Add(f.Call(Gd.Box(_p[i])));
            return c;
        }
        public bool Any(Callable f)
        {
            for (int i = 0; i < _n; i++) if (Gd.Truthy(f.Call(Gd.Box(_p[i])))) return true;
            return false;
        }
        public bool All(Callable f)
        {
            for (int i = 0; i < _n; i++) if (!Gd.Truthy(f.Call(Gd.Box(_p[i])))) return false;
            return true;
        }
        public void Reverse() => Array.Reverse(_p, 0, _n);
        public void Sort() => GodotSort.Sort(_p, _n, Gd.LessOf<T>());
        public void SortCustom(Callable f) =>
            GodotSort.Sort(_p, _n, (a, b) => Gd.Truthy(f.Call(Gd.Box(a), Gd.Box(b))));
        public T Max()
        {
            if (_n == 0) return default;
            Func<T, T, bool> less = Gd.LessOf<T>();
            T best = _p[0];
            for (int i = 1; i < _n; i++) if (less(best, _p[i])) best = _p[i];
            return best;
        }
        public T Min()
        {
            if (_n == 0) return default;
            Func<T, T, bool> less = Gd.LessOf<T>();
            T best = _p[0];
            for (int i = 1; i < _n; i++) if (less(_p[i], best)) best = _p[i];
            return best;
        }
    }

    public interface IConv<S, V>
    {
        S In(V v);
        V Out(S s);
    }

    public struct ByteConv : IConv<byte, long> { public byte In(long v) => (byte)v; public long Out(byte s) => s; }
    public struct Int32Conv : IConv<int, long> { public int In(long v) => (int)v; public long Out(int s) => s; }
    public struct Int64Conv : IConv<long, long> { public long In(long v) => v; public long Out(long s) => s; }
    public struct Float32Conv : IConv<float, double> { public float In(double v) => (float)v; public double Out(float s) => s; }
    public struct Float64Conv : IConv<double, double> { public double In(double v) => v; public double Out(double s) => s; }
    public struct SameConv<V> : IConv<V, V> { public V In(V v) => v; public V Out(V s) => s; }

    public abstract class Packed<S, V, C, Self> : IGArray where C : struct, IConv<S, V> where Self : Packed<S, V, C, Self>, new()
    {
        protected S[] _p = new S[4];
        protected int _n;
        static C Conv => default;

        protected void Fill(IGArray from)
        {
            for (long i = 0; i < from.Size(); i++) Append(Gd.Cast<V>(from.GetVariant(i)));
        }

        public static implicit operator Variant(Packed<S, V, C, Self> a) => Variant.OfArray(a, Gd.TYPE_ARRAY);
        public static implicit operator Packed<S, V, C, Self>(Variant v) => (Self)v.Obj;

        long Wrap(long i)
        {
            if (i < 0) i += _n;
            if (i < 0 || i >= _n) throw new IndexOutOfRangeException($"index {i} of {_n}");
            return i;
        }

        public V this[long i]
        {
            get => Conv.Out(_p[Wrap(i)]);
            set => _p[Wrap(i)] = Conv.In(value);
        }

        public Enumerator GetEnumerator() => new Enumerator(this);
        public struct Enumerator
        {
            readonly Packed<S, V, C, Self> _a;
            int _i;
            public Enumerator(Packed<S, V, C, Self> a) { _a = a; _i = -1; }
            public bool MoveNext() => ++_i < _a._n;
            public V Current => Conv.Out(_a._p[_i]);
        }

        public long Size() => _n;
        public bool IsEmpty() => _n == 0;
        public Variant GetVariant(long i) => Gd.Box(this[i]);
        public void AppendVariant(Variant v) => Append(Gd.Cast<V>(v));
        public object DuplicateAny(bool deep) => Duplicate();
        public void Append(V v)
        {
            if (_n == _p.Length) Array.Resize(ref _p, _n * 2);
            _p[_n++] = Conv.In(v);
        }
        public void PushBack(V v) => Append(v);
        public void Clear() { _n = 0; }
        public void Resize(long size)
        {
            int s = (int)size;
            if (s > _p.Length) Array.Resize(ref _p, Math.Max(s, _p.Length * 2));
            // Godot leaves new packed elements as they come from a fresh allocation: sim code fills
            // what it reads, and zeros are what a fresh allocation gives here.
            if (s > _n) Array.Clear(_p, _n, s - _n);
            _n = s;
        }
        public void Fill(V v) { S s = Conv.In(v); for (int i = 0; i < _n; i++) _p[i] = s; }
        public void AppendArray(Self o)
        {
            int count = o._n;
            for (int i = 0; i < count; i++) Append(Conv.Out(o._p[i]));
        }
        public void AppendArray(IGArray o)
        {
            long count = o.Size();
            for (long i = 0; i < count; i++) Append(Gd.Cast<V>(o.GetVariant(i)));
        }
        public static Self operator +(Packed<S, V, C, Self> a, Packed<S, V, C, Self> b)
        {
            Self c = a.Duplicate();
            c.AppendArray((Self)b);
            return c;
        }
        public void Insert(long at, V v)
        {
            Append(v);
            Array.Copy(_p, at, _p, at + 1, _n - 1 - at);
            _p[at] = Conv.In(v);
        }
        public void RemoveAt(long at)
        {
            at = Wrap(at);
            Array.Copy(_p, at + 1, _p, at, _n - 1 - at);
            _n--;
        }
        public long Find(V v, long from = 0)
        {
            S want = Conv.In(v);
            EqualityComparer<S> eq = EqualityComparer<S>.Default;
            for (long i = from; i < _n; i++) if (eq.Equals(_p[i], want)) return i;
            return -1;
        }
        public bool Has(V v) => Find(v) >= 0;
        public long Count(V v)
        {
            S want = Conv.In(v);
            long c = 0;
            EqualityComparer<S> eq = EqualityComparer<S>.Default;
            for (int i = 0; i < _n; i++) if (eq.Equals(_p[i], want)) c++;
            return c;
        }
        public Self Duplicate()
        {
            Self c = new Self();
            c._p = new S[Math.Max(4, _n)];
            Array.Copy(_p, c._p, _n);
            c._n = _n;
            return c;
        }
        public Self Slice(long begin, long end = int.MaxValue)
        {
            if (begin < 0) begin = Math.Max(0, begin + _n);
            if (end < 0) end += _n;
            end = Math.Min(end, _n);
            Self c = new Self();
            for (long i = begin; i < end; i++) c.Append(Conv.Out(_p[i]));
            return c;
        }
        public void Reverse() => Array.Reverse(_p, 0, _n);
        public void Sort()
        {
            Func<V, V, bool> less = Gd.LessOf<V>();
            C conv = default;
            GodotSort.Sort(_p, _n, (a, b) => less(conv.Out(a), conv.Out(b)));
        }
        public S[] Raw => _p;
    }

    public sealed class PackedByteArray : Packed<byte, long, ByteConv, PackedByteArray>
    {
        public PackedByteArray() { }
        public PackedByteArray(Variant from) { Fill((IGArray)from.Obj); }
        public static implicit operator PackedByteArray(Variant v) => (PackedByteArray)v.Obj;
        public long DecodeS16(long at) => (short)(_p[at] | (_p[at + 1] << 8));
        public string GetStringFromAscii()
        {
            StringBuilder s = new StringBuilder(_n);
            for (int i = 0; i < _n && _p[i] != 0; i++) s.Append((char)_p[i]);
            return s.ToString();
        }
    }

    public sealed class PackedInt32Array : Packed<int, long, Int32Conv, PackedInt32Array>
    {
        public PackedInt32Array() { }
        public PackedInt32Array(Variant from) { Fill((IGArray)from.Obj); }
        public static implicit operator PackedInt32Array(Variant v) => (PackedInt32Array)v.Obj;
    }

    public sealed class PackedInt64Array : Packed<long, long, Int64Conv, PackedInt64Array>
    {
        public PackedInt64Array() { }
        public PackedInt64Array(Variant from) { Fill((IGArray)from.Obj); }
        public static implicit operator PackedInt64Array(Variant v) => (PackedInt64Array)v.Obj;
    }

    public sealed class PackedFloat32Array : Packed<float, double, Float32Conv, PackedFloat32Array>
    {
        public PackedFloat32Array() { }
        public PackedFloat32Array(Variant from) { Fill((IGArray)from.Obj); }
        public static implicit operator PackedFloat32Array(Variant v) => (PackedFloat32Array)v.Obj;
    }

    public sealed class PackedFloat64Array : Packed<double, double, Float64Conv, PackedFloat64Array>
    {
        public PackedFloat64Array() { }
        public PackedFloat64Array(Variant from) { Fill((IGArray)from.Obj); }
        public static implicit operator PackedFloat64Array(Variant v) => (PackedFloat64Array)v.Obj;
    }

    public sealed class PackedStringArray : Packed<string, string, SameConv<string>, PackedStringArray>
    {
        public PackedStringArray() { }
        public PackedStringArray(Variant from) { Fill((IGArray)from.Obj); }
        public static implicit operator PackedStringArray(Variant v) => (PackedStringArray)v.Obj;
    }

    public sealed class PackedVector2Array : Packed<Vector2, Vector2, SameConv<Vector2>, PackedVector2Array>
    {
        public PackedVector2Array() { }
        public PackedVector2Array(Variant from) { Fill((IGArray)from.Obj); }
        public static implicit operator PackedVector2Array(Variant v) => (PackedVector2Array)v.Obj;
    }

    public sealed class PackedVector3Array : Packed<Vector3, Vector3, SameConv<Vector3>, PackedVector3Array>
    {
        public PackedVector3Array() { }
        public PackedVector3Array(Variant from) { Fill((IGArray)from.Obj); }
        public static implicit operator PackedVector3Array(Variant v) => (PackedVector3Array)v.Obj;
    }

    // Insertion order, like Godot's: iterating a Dictionary must visit keys in the same order.
    public sealed class GDict : System.Collections.IEnumerable
    {
        struct Slot { public Variant Key, Value; public bool Live; }
        Slot[] _s = new Slot[4];
        int _used, _live;
        readonly Dictionary<Variant, int> _at = new Dictionary<Variant, int>();

        System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator()
        {
            for (int i = 0; i < _used; i++) if (_s[i].Live) yield return _s[i].Key;
        }

        public void Add(Variant k, Variant v) => this[k] = v;

        public Variant this[Variant k]
        {
            get => TryFind(k, out int at) ? _s[at].Value : default;
            set
            {
                if (TryFind(k, out int at))
                {
                    _s[at].Value = value;
                    return;
                }
                if (_used == _s.Length) Array.Resize(ref _s, _used * 2);
                _s[_used] = new Slot { Key = k, Value = value, Live = true };
                _at[Typed(k)] = _used;
                _used++;
                _live++;
            }
        }

        // Variant equality says 1 == 1.0; a key keeps them apart by carrying its type in the string.
        static Variant Typed(Variant k) => k.Type == Gd.TYPE_FLOAT ? (Variant)("\u0001f" + BitConverter.DoubleToInt64Bits(k)) : k;

        bool TryFind(Variant k, out int at) => _at.TryGetValue(Typed(k), out at);

        public long Size() => _live;
        public bool IsEmpty() => _live == 0;
        public bool Has(Variant k) => TryFind(k, out _);
        public Variant Get(Variant k, Variant fallback = default) => TryFind(k, out int at) ? _s[at].Value : fallback;
        public bool Erase(Variant k)
        {
            if (!TryFind(k, out int at)) return false;
            _at.Remove(Typed(k));
            _s[at] = default;
            _live--;
            if (at == _used - 1)
            {
                while (_used > 0 && !_s[_used - 1].Live) _used--;
            }
            return true;
        }
        public void Clear()
        {
            Array.Clear(_s, 0, _used);
            _used = 0;
            _live = 0;
            _at.Clear();
        }
        public GArray<Variant> Keys()
        {
            GArray<Variant> c = new GArray<Variant>(_live, true);
            for (int i = 0; i < _used; i++) if (_s[i].Live) c.Add(_s[i].Key);
            return c;
        }
        public GArray<Variant> Values()
        {
            GArray<Variant> c = new GArray<Variant>(_live, true);
            for (int i = 0; i < _used; i++) if (_s[i].Live) c.Add(_s[i].Value);
            return c;
        }
        public void Merge(GDict o, bool overwrite = false)
        {
            for (int i = 0; i < o._used; i++)
            {
                if (!o._s[i].Live) continue;
                if (overwrite || !Has(o._s[i].Key)) this[o._s[i].Key] = o._s[i].Value;
            }
        }
        public GDict Merged(GDict o, bool overwrite = false)
        {
            GDict c = Duplicate();
            c.Merge(o, overwrite);
            return c;
        }
        public GDict Duplicate(bool deep = false)
        {
            GDict c = new GDict();
            for (int i = 0; i < _used; i++)
            {
                if (_s[i].Live) c[_s[i].Key] = deep ? Gd.DeepCopy(_s[i].Value) : _s[i].Value;
            }
            return c;
        }
        public Enumerator GetEnumerator() => new Enumerator(this);
        public struct Enumerator
        {
            readonly GDict _d;
            int _i;
            public Enumerator(GDict d) { _d = d; _i = -1; }
            public bool MoveNext()
            {
                while (++_i < _d._used) if (_d._s[_i].Live) return true;
                return false;
            }
            public Variant Current => _d._s[_i].Key;
        }
        internal bool DeepEquals(GDict o)
        {
            if (ReferenceEquals(this, o)) return true;
            if (_live != o._live) return false;
            for (int i = 0; i < _used; i++)
            {
                if (!_s[i].Live) continue;
                if (!o.TryFind(_s[i].Key, out int at) || !_s[i].Value.Equals(o._s[at].Value)) return false;
            }
            return true;
        }
        internal int DeepHash()
        {
            int h = _live;
            for (int i = 0; i < _used; i++) if (_s[i].Live) h += _s[i].Key.GetHashCode() ^ _s[i].Value.GetHashCode();
            return h;
        }
    }
}
