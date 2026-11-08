// Generated from sim/model_variant.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class ModelVariant : RefCounted
    {
        public static implicit operator ModelVariant(Variant v) => (ModelVariant)v.Obj;

        // A placed copy of a pool building (data/city_buildings.json, D-256): its baked model turned by
        // `facing` quarter turns, mirrored across x when `mirror`, and `stretch` floors taller (the row's
        // stretch_floor repeated). Cells are building-local (RES cells per sim unit, as the bake wrote
        // them); the same mapping serves the sim's grid (LandmarkCells) and the view (LandmarkVoxels), so
        // the two never drift apart. Pure: no scene, no RNG.
        // A face's bit (bake.py STEPS: -x, +x, +y, -y, -z, +z) after a mirror across x, and after one
        // quarter turn (x, z) -> (d - 1 - z, x): -x faces -z, +x faces +z, -z faces +x, +z faces -x.
        public static readonly GArray<long> MIRROR_BIT = new GArray<long> { 1, 0, 2, 3, 4, 5 };
        public static readonly GArray<long> TURN_BIT = new GArray<long> { 4, 5, 2, 3, 1, 0 };
        // The pool row of model `id` (data/city_buildings.json), or {}.

        public static GDict RowOf(string id)
        {
            GDict pool = Content.CityBuildings().Get("pool", new GDict());
            GDict row = pool.Get(id, new GDict());
            return row;
        }
        // The variant of a layout entry: {"facing", "mirror", "stretch"} (defaults for a bare model).

        public static GDict Of(GDict entry)
        {
            return new GDict { { "facing", Gd.Posmod(Num.I(entry.Get("facing", 0)), 4) }, { "mirror", entry.Get("mirror", false) == true }, { "stretch", Gd.Maxi(0, Num.I(entry.Get("stretch", 0))) } };
        }
        // Footprint and floors of the placed copy: Vector3i(w, h, d) in sim units.

        public static Vector3i Size(GDict row, GDict v)
        {
            long w = Num.I(row["w"]);
            long d = Num.I(row["d"]);
            long h = Num.I(row["h"]) + StretchOf(row, v);
            return (Num.I(v["facing"]) % 2 == 1 ? new Vector3i(d, h, w) : new Vector3i(w, h, d));
        }
        // The floors the copy really adds: none when the model has no floor that repeats.

        public static long StretchOf(GDict row, GDict v)
        {
            return (Num.I(row.Get("stretch_floor", -1)) >= 0 ? Num.I(v["stretch"]) : 0);
        }
        // Maps baked cells (x, y, z triples) to the copy's: {"xyz": PackedInt32Array, "src": the baked
        // cell index each output cell came from (a stretched floor's cells appear once per copy)}.

        public static GDict Cells(PackedInt32Array xyz, GDict row, GDict v, long res)
        {
            long w = Num.I(row["w"]) * res;
            long d = Num.I(row["d"]) * res;
            long extra = StretchOf(row, v);
            long bandLo = (extra > 0 ? Num.I(row.Get("stretch_floor", -1)) * res : (1L << (int)(30)));
            long bandHi = bandLo + res;
            long n = xyz.Size() / 3;
            long total = n;
            foreach (long i in Gd.Range(n))
            {
                long y = xyz[i * 3 + 1];
                total += (y >= bandLo && y < bandHi ? extra : 0);
            }
            // the turn and mirror are affine in (x, z): p = p0 + x * px + z * pz
            var p0 = Place(Vector3i.ZERO, w, d, v);
            var px = Place(new Vector3i(1, 0, 0), w, d, v) - p0;
            var pz = Place(new Vector3i(0, 0, 1), w, d, v) - p0;
            var @out = new PackedInt32Array();
            @out.Resize(total * 3);
            var src = new PackedInt32Array();
            src.Resize(total);
            long k = 0;
            foreach (long i in Gd.Range(n))
            {
                long x = xyz[i * 3];
                long y = xyz[i * 3 + 1];
                long z = xyz[i * 3 + 2];
                long copies = 1;
                if (y >= bandHi)
                {
                    y += extra * res;
                }
                else if (y >= bandLo)
                {
                    copies += extra;
                }
                long ox = p0.x + x * px.x + z * pz.x;
                long oz = p0.z + x * px.z + z * pz.z;
                foreach (long c in Gd.Range(copies))
                {
                    @out[k * 3] = ox;
                    @out[k * 3 + 1] = y + c * res;
                    @out[k * 3 + 2] = oz;
                    src[k] = i;
                    k += 1;
                }
            }
            return new GDict { { "xyz", @out }, { "src", src } };
        }
        // Every open-face bit set (0..63) through the variant's mirror and turns: index by a cell's
        // baked flags (flags(m, v) for all m at once).

        public static PackedInt32Array FlagTable(GDict v)
        {
            var @out = new PackedInt32Array();
            @out.Resize(64);
            foreach (long m in Gd.Range(64))
            {
                @out[m] = Flags(m, v);
            }
            return @out;
        }
        // One cell (already stretched) through the mirror and the quarter turns; w, d in cells.

        public static Vector3i Place(Vector3i c, long w, long d, GDict v)
        {
            var p = c;
            if (v["mirror"] == true)
            {
                p.x = w - 1 - p.x;
            }
            long cw = w;
            long cd = d;
            foreach (long _t in Gd.Range(Num.I(v["facing"])))
            {
                p = new Vector3i(cd - 1 - p.z, p.y, p.x);
                long keep = cw;
                cw = cd;
                cd = keep;
            }
            return p;
        }
        // A cell's open-face bits through the same mirror and turns.

        public static long Flags(long m, GDict v)
        {
            long @out = m;
            if (v["mirror"] == true)
            {
                @out = _Remap(@out, MIRROR_BIT);
            }
            foreach (long _t in Gd.Range(Num.I(v["facing"])))
            {
                @out = _Remap(@out, TURN_BIT);
            }
            return @out;
        }
        // The copy's structural chunks, one string per floor (x fastest, then z), as the bake writes them.

        public static GArray<Variant> Chunks(GDict row, GDict v)
        {
            long w = Num.I(row["w"]);
            long d = Num.I(row["d"]);
            GArray<Variant> layers = row["chunks"];
            long extra = StretchOf(row, v);
            long band = Num.I(row.Get("stretch_floor", -1));
            GArray<string> floors = new GArray<string>();
            foreach (long y in Gd.Range(layers.Size()))
            {
                floors.Append(Gd.Str(layers[y]));
                if (y == band)
                {
                    foreach (long _k in Gd.Range(extra))
                    {
                        floors.Append(Gd.Str(layers[y]));
                    }
                }
            }
            var dims = Size(row, v);
            // each source column's index in the placed layer
            var to = new PackedInt32Array();
            to.Resize(w * d);
            foreach (long z in Gd.Range(d))
            {
                foreach (long x in Gd.Range(w))
                {
                    var p = Place(new Vector3i(x, 0, z), w, d, v);
                    to[z * w + x] = p.z * dims.x + p.x;
                }
            }
            GArray<Variant> @out = Gd.Arr();
            foreach (string layer in floors)
            {
                var src = layer.ToAsciiBuffer();
                var cellsOut = new PackedByteArray();
                cellsOut.Resize(dims.x * dims.z);
                foreach (long n in Gd.Range(to.Size()))
                {
                    cellsOut[to[n]] = src[n];
                }
                @out.Append(cellsOut.GetStringFromAscii());
            }
            return @out;
        }

        public static long _Remap(long m, GArray<long> to)
        {
            long @out = 0;
            foreach (long k in Gd.Range(6))
            {
                if (Gd.Truthy((m & ((1L << (int)(k))))))
                {
                    @out |= (1L << (int)(to[k]));
                }
            }
            return @out;
        }

        void _InitFields()
        {
        }
        public ModelVariant() { _InitFields(); }
    }
}
