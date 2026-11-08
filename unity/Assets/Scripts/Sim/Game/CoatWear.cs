// Generated from sim/coat_wear.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CoatWear : RefCounted
    {
        public static implicit operator CoatWear(Variant v) => (CoatWear)v.Obj;

        // The coatings (beam fire) eat what they cover each step, and wear off when their time
        // runs out or the chunk is gone. Part of SpeciesPowers; split out to keep files small. Pure.
        // Coats are kept in packed arrays in the order they were first laid (a refresh keeps its
        // place): a beam lays a thousand at once, and a Dictionary per coat cost ~4 us each a step.
        // Key of a coated chunk: building * KEY_SPAN + chunk index.
        public const long KEY_SPAN = 1048576;
        // Coat slot of each coated chunk, by key.
        public GDict _slot = new GDict();
        public PackedInt64Array _key = new PackedInt64Array();
        public PackedInt32Array _b = new PackedInt32Array();
        public GArray<Vector3i> _c = new GArray<Vector3i>();
        // seconds left
        public PackedFloat64Array _t = new PackedFloat64Array();
        public PackedFloat64Array _dps = new PackedFloat64Array();

        public long Size()
        {
            return _key.Size();
        }

        public bool Has(long key)
        {
            return _slot.Has(key);
        }
        // Coats chunk `c` under `key` (or refreshes its coat in place) for `seconds` at `dps`.

        public void Put(long key, Vector3i c, double seconds, double dps)
        {
            long i = _slot.Get(key, -1);
            if (i < 0)
            {
                _slot[key] = _key.Size();
                _key.Append(key);
                _b.Append(key / KEY_SPAN);
                _c.Append(c);
                _t.Append(seconds);
                _dps.Append(dps);
                return;
            }
            _t[i] = seconds;
            _dps[i] = dps;
        }
        // One step of every coat over `dt` seconds: each building's coated chunks take dps * dt in one
        // blow (buildings in the order their first coat was laid), spent coats drop out.

        public void Step(RampageSim sim, double dt)
        {
            if (_key.IsEmpty())
            {
                return;
            }
            // building -> index into cells/amounts
            GDict groups = new GDict();
            var order = new PackedInt32Array();
            GArray<GArray<Variant>> cells = new GArray<GArray<Variant>>();
            GArray<PackedFloat32Array> amounts = new GArray<PackedFloat32Array>();
            long lastB = -1;
            long g = -1;
            Structure frame = null;
            long keep = 0;
            foreach (long i in Gd.Range(_key.Size()))
            {
                long b = _b[i];
                if (b != lastB)
                {
                    lastB = b;
                    frame = sim.buildings[b].frame;
                    g = groups.Get(b, -1);
                }
                var c = _c[i];
                _t[i] -= dt;
                if ((_t[i] <= 0.0 || !frame.Alive(c)))
                {
                    _slot.Erase(_key[i]);
                    continue;
                }
                if (g < 0)
                {
                    g = cells.Size();
                    groups[b] = g;
                    order.Append(b);
                    cells.Append(((GArray<Vector3i>)Gd.Arr()));
                    amounts.Append(new PackedFloat32Array());
                }
                cells[g].Append(c);
                amounts[g].Append(_dps[i] * dt);
                if (keep != i)
                {
                    _Move(i, keep);
                }
                keep += 1;
            }
            _Shrink(keep);
            foreach (long n in Gd.Range(order.Size()))
            {
                GArray<Vector3i> hit = new GArray<Vector3i>();
                hit.Assign(cells[n]);
                sim.DamageCells(order[n], hit, amounts[n]);
            }
        }
        // Moves the coat in slot `from` down to slot `to` (compaction keeps first-laid order).

        public void _Move(long from, long to)
        {
            _key[to] = _key[from];
            _b[to] = _b[from];
            _c[to] = _c[from];
            _t[to] = _t[from];
            _dps[to] = _dps[from];
            _slot[_key[to]] = to;
        }

        public void _Shrink(long n)
        {
            _key.Resize(n);
            _b.Resize(n);
            _c.Resize(n);
            _t.Resize(n);
            _dps.Resize(n);
        }

        void _InitFields()
        {
        }
        public CoatWear() { _InitFields(); }
    }
}
