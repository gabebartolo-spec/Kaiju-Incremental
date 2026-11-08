// Generated from sim/voxel_topple.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class VoxelTopple : RefCounted
    {
        public static implicit operator VoxelTopple(Variant v) => (VoxelTopple)v.Obj;

        // The topple rule behind VoxelSupport.topple() and VoxelSupport.landing() (split out of
        // VoxelSupport to keep files small): per grounded part and level, the load at or above it, and
        // the tip test that says whether a centre of mass hanging past a box topples over its edge.
        // Static and pure: centres of mass are compared in integers (sums of 2x + 1), so the outcome is
        // exact. The native pass (KaijuSettle "floors") gives what floors() gives; this stays the
        // reference.
        // Per grounded part and level: the load at or above it (mass, sums of 2x + 1 and 2z + 1, at
        // k * (h + 1) + y) and the box [x0, z0, x1, z1) of its cells standing on a cell below (at
        // (k * h + y) * 4; x1 < 0 when there are none). `labels` is VoxelSupport.labels over `cells` (a
        // grid of `dims`), `fix` the fixture table, `count` the number of grounded parts.

        public static GDict Floors(PackedByteArray cells, PackedByteArray fix, PackedInt32Array labels, Vector3i dims, long count)
        {
            long w = dims.x;
            long d = dims.z;
            long h = dims.y;
            long plan = w * d;
            var mass = new PackedInt64Array();
            mass.Resize(count * (h + 1));
            var sx = mass.Duplicate();
            var sz = mass.Duplicate();
            var box = new PackedInt32Array();
            box.Resize(count * h * 4);
            box.Fill(-1);
            foreach (long i in Gd.Range(cells.Size()))
            {
                long k = labels[i] - 1;
                if ((k < 0 || cells[i] == VoxelFrame.EMPTY))
                {
                    continue;
                }
                long x = i % w;
                long z = (i / w) % d;
                long y = i / plan;
                long at = k * (h + 1) + y;
                mass[at] += 1;
                sx[at] += 2 * x + 1;
                sz[at] += 2 * z + 1;
                long below = (y > 0 ? cells[i - plan] : VoxelFrame.EMPTY);
                if (below != VoxelFrame.EMPTY && fix[below] == 0 && fix[cells[i]] == 0)
                {
                    _Widen(box, (k * h + y) * 4, x, z);
                }
            }
            _StackUp(mass, sx, sz, count, h);
            return new GDict { { "mass", mass }, { "sx", sx }, { "sz", sz }, { "box", box } };
        }
        // Grows the box record at `b` of `box` to take in the cell column (x, z).

        public static void _Widen(PackedInt32Array box, long b, long x, long z)
        {
            var fresh = box[b + 2] < 0;
            box[b] = (fresh ? x : Gd.Mini(box[b], x));
            box[b + 1] = (fresh ? z : Gd.Mini(box[b + 1], z));
            box[b + 2] = (fresh ? x + 1 : Gd.Maxi(box[b + 2], x + 1));
            box[b + 3] = (fresh ? z + 1 : Gd.Maxi(box[b + 3], z + 1));
        }
        // Turns each part's per-level loads into loads at or above each level (top level down).

        public static void _StackUp(PackedInt64Array mass, PackedInt64Array sx, PackedInt64Array sz, long count, long h)
        {
            foreach (long k in Gd.Range(count))
            {
                foreach (long y in Gd.Range(h - 1, -1, -1))
                {
                    long at = k * (h + 1) + y;
                    mass[at] += mass[at + 1];
                    sx[at] += sx[at + 1];
                    sz[at] += sz[at + 1];
                }
            }
        }
        // The topple rule over per-part, per-level loads (the layout floors documents), for `parts`
        // grounded parts in a grid `h` cells tall whose cell 0 is building-local `offset` at `res`
        // cells a unit.

        public static GArray<GDict> ScanLevels(PackedInt64Array mass, PackedInt64Array sx, PackedInt64Array sz, PackedInt32Array box, long parts, long h, Vector3i offset, long res)
        {
            GArray<GDict> @out = new GArray<GDict>();
            foreach (long k in Gd.Range(parts))
            {
                foreach (long level in Gd.Range(1, h))
                {
                    long at = k * (h + 1) + level;
                    if (mass[at] == 0)
                    {
                        break;
                    }
                    long b = (k * h + level) * 4;
                    if (box[b + 2] < 0)
                    {
                        // nothing stands on a cell below at this level
                        continue;
                    }
                    var rect = new Rect2i(box[b], box[b + 1], box[b + 2] - box[b], box[b + 3] - box[b + 1]);
                    GDict tip = TipOf(new PackedInt64Array(Gd.Arr(sx[at], sz[at], mass[at])), rect, level, offset, res);
                    if (!tip.IsEmpty())
                    {
                        tip["label"] = k + 1;
                        tip["level"] = level;
                        @out.Append(tip);
                        break;
                    }
                }
            }
            return @out;
        }
        // Structure's tip test: a load (sums [2x + 1, 2z + 1, mass]) whose centre lies outside `box`
        // (cells) tips over the box edge it passes furthest, at height `y` (cells). {} if inside.

        public static GDict TipOf(PackedInt64Array sums, Rect2i box, long y, Vector3i offset, long res)
        {
            long overX = _Over(sums[0], sums[2], box.position.x, box.end.x);
            long overZ = _Over(sums[1], sums[2], box.position.y, box.end.y);
            if (overX == 0 && overZ == 0)
            {
                return new GDict();
            }
            var dir = new Vector2i(Gd.Signi(overX), 0);
            if (Gd.Absi(overZ) > Gd.Absi(overX))
            {
                dir = new Vector2i(0, Gd.Signi(overZ));
            }
            var com = new Vector2(sums[0], sums[1]) / (2.0 * sums[2]);
            double px = com.x;
            if (dir.x != 0)
            {
                px = (dir.x > 0 ? box.end.x : box.position.x);
            }
            double pz = com.y;
            if (dir.y != 0)
            {
                pz = (dir.y > 0 ? box.end.y : box.position.y);
            }
            var pivot = (new Vector3(px, y, pz) + new Vector3(offset)) / res;
            return new GDict { { "kind", "topple" }, { "pivot", pivot }, { "dir", dir } };
        }
        // How far (in 1 / (2 mass) cells) a centre with sum `s` lies past [lo, hi); 0 if inside.

        public static long _Over(long s, long mass, long lo, long hi)
        {
            if (s > 2 * hi * mass)
            {
                return s - 2 * hi * mass;
            }
            if (s < 2 * lo * mass)
            {
                return s - 2 * lo * mass;
            }
            return 0;
        }

        void _InitFields()
        {
        }
        public VoxelTopple() { _InitFields(); }
    }
}
