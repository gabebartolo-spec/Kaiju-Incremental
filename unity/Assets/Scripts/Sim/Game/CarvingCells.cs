// Generated from sim/carving_cells.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CarvingCells : RefCounted
    {
        public static implicit operator CarvingCells(Variant v) => (CarvingCells)v.Obj;

        // Carving's per-cell loops (b2-3 part 3), split out to keep carving.gd small: a blow's wear, a
        // new grid's chunk counts, a fallen part's bookkeeping and its drop. Each runs natively
        // (KaijuSettle, native/src/kaiju_settle_parts.cpp) where the extension is loaded; the GDScript
        // here stays the reference it is held to (run_carving_tests _check_replay, use_native).
        // A blow's wear on grid g: per chunk in `spans` [x0, x1, z0, z1, floor] (grid columns), each
        // column worn (Carving.wear_column) by damage x at[col] x mult where at[col] > 0 or, when `at`
        // is empty, by amounts[chunk] x mult; what breaks goes into g.removed and g.mats.

        public static void Wear(Carving carving, Carving.Grid g, PackedInt32Array spans, PackedFloat32Array at, PackedFloat32Array amounts, double damage, double mult)
        {
            var f = g.frame;
            var nat = VoxelSupport.Native();
            var even = at.IsEmpty();
            if (nat == null)
            {
                foreach (long s in Gd.Range(0, spans.Size(), 5))
                {
                    foreach (long gz in Gd.Range(spans[s + 2], spans[s + 3]))
                    {
                        foreach (long gx in Gd.Range(spans[s], spans[s + 1]))
                        {
                            long col = gx + gz * f.w;
                            if (even)
                            {
                                carving.WearColumn(g, col, spans[s + 4], amounts[s / 5] * mult);
                            }
                            else if (at[col] > 0.0)
                            {
                                carving.WearColumn(g, col, spans[s + 4], damage * at[col] * mult);
                            }
                        }
                    }
                }
                return;
            }
            GArray<Variant> got = nat.Call("wear", f.cells, g.wear, at, amounts, spans, carving.Strengths(), new PackedFloat64Array(Gd.Arr(damage, mult, g.hp, carving.Weakest())), new PackedInt32Array(Gd.Arr(f.w, f.d, f.h, g.bw, g.bd, g.floors, f.offset.y, f.res)), g.cx, g.cz, g.fy, g.live);
            f.cells = got[0];
            g.wear = got[1];
            g.live = got[2];
            PackedInt32Array removed = got[3];
            PackedByteArray mats = got[4];
            f.aliveCount -= removed.Size();
            g.removed.AppendArray(removed);
            g.mats.AppendArray(mats);
        }
        // A beam's force at each grid column the spans cover (1 or 0, -1 elsewhere), sampled natively
        // as Carving.hit's Callable loop would; empty when there is no beam or no native core.

        public static PackedFloat32Array BeamAt(RampageSim.Beam beam, RampageSim.Building b, VoxelFrame f, PackedInt32Array spans)
        {
            var nat = VoxelSupport.Native();
            if ((beam == null || nat == null))
            {
                return new PackedFloat32Array();
            }
            return nat.Call("beam_at", spans, new PackedInt32Array(Gd.Arr(f.w, f.d, f.offset.x, f.offset.z, f.res)), new PackedFloat64Array(Gd.Arr(b.x - b.w * 0.5, b.z - b.d * 0.5, beam.origin.x, beam.origin.y, beam.dir.x, beam.dir.y, beam.length, beam.half)));
        }
        // Per chunk (Structure.index), the cells of g's grid in it.

        public static PackedInt32Array Counts(Carving.Grid g, long chunks)
        {
            var f = g.frame;
            var nat = VoxelSupport.Native();
            if (nat != null)
            {
                return nat.Call("chunk_counts", f.cells, g.cx, g.cz, g.fy, _Geo(g), chunks);
            }
            var full = new PackedInt32Array();
            full.Resize(chunks);
            var bytes = f.cells;
            foreach (long i in Gd.Range(bytes.Size()))
            {
                if (bytes[i] != VoxelFrame.EMPTY)
                {
                    full[g.Chunk(i)] += 1;
                }
            }
            return full;
        }
        // A part that fell out of g's grid: one cell less in each chunk it held (g.live), and
        // [lo, hi (grid cells, Vector3i), base (Rect2i, the footprint of its lowest layer), under (true
        // when a cell stands below that layer)].

        public static GArray<Variant> Fallen(Carving.Grid g, PackedInt32Array index)
        {
            var f = g.frame;
            var nat = VoxelSupport.Native();
            if (nat != null)
            {
                GArray<Variant> got = nat.Call("part_info", index, f.cells, g.cx, g.cz, g.fy, _Geo(g), g.live);
                g.live = got[0];
                PackedInt32Array r = got[1];
                return Gd.Arr(new Vector3i(r[0], r[1], r[2]), new Vector3i(r[3], r[4], r[5]), new Rect2i(r[6], r[7], r[8] - r[6], r[9] - r[7]), r[10] == 1);
            }
            long plan = f.w * f.d;
            var lo = new Vector3i(f.w, f.h, f.d);
            var hi = -Vector3i.ONE;
            foreach (long i in index)
            {
                g.live[g.Chunk(i)] -= 1;
                var c = new Vector3i(i % f.w, i / plan, (i / f.w) % f.d);
                lo = lo.Min(c);
                hi = hi.Max(c);
            }
            var @base = new Rect2i(-1, -1, 0, 0);
            var under = false;
            foreach (long i in index)
            {
                if (i / plan == lo.y)
                {
                    long x = i % f.w;
                    long z = (i / f.w) % f.d;
                    var cell = new Rect2i(x, z, 1, 1);
                    @base = (@base.position.x < 0 ? cell : @base.Merge(cell));
                    under = (under || f.ColumnTop(x, z, lo.y) >= 0);
                }
            }
            return Gd.Arr(lo, hi, @base, under);
        }
        // How far an island (already out of the grid) drops before it meets what stands below it,
        // in sim units.

        public static double Drop(VoxelFrame f, PackedInt32Array index)
        {
            var nat = VoxelSupport.Native();
            if (nat != null)
            {
                PackedInt64Array r = nat.Call("land", index, f.cells, new Vector3i(f.w, f.h, f.d));
                return Gd.Maxf(0.5, Gd.Float(r[8]) / f.res);
            }
            long plan = f.w * f.d;
            GDict low = new GDict();
            foreach (long i in index)
            {
                long col = i % plan;
                long y = i / plan;
                if ((!low.Has(col) || y < Num.I(low[col])))
                {
                    low[col] = y;
                }
            }
            long gap = f.h;
            foreach (long col in low)
            {
                long y = low[col];
                gap = Gd.Mini(gap, y - f.ColumnTop(col % f.w, col / f.w, y) - 1);
            }
            return Gd.Maxf(0.5, Gd.Float(gap) / f.res);
        }

        public static PackedInt32Array _Geo(Carving.Grid g)
        {
            return new PackedInt32Array(Gd.Arr(g.frame.w, g.frame.d, g.frame.h, g.bw, g.bd));
        }
        // One settled part in Collapse's part shape (Carving.settle): `info` is fallen()'s answer for it
        // and `deaths` the chunks it took with it.

        public static GDict PartEvent(VoxelFrame f, GDict part, GArray<Variant> info, GArray<Vector3i> deaths)
        {
            PackedInt32Array index = part["index"];
            Vector3i lo = info[0];
            Vector3i hi = info[1];
            Rect2i @base = info[2];
            bool under = info[3];
            Vector2i dir = part["dir"];
            var span = hi - lo + Vector3i.ONE;
            GDict @event = new GDict { { "cells", deaths }, { "kind", part["kind"] }, { "pivot", part["pivot"] }, { "dir", dir }, { "index", index }, { "mats", part["mats"] }, { "low", Gd.Float(lo.y) / f.res }, { "height", Gd.Ceilf(Gd.Float(span.y) / f.res) }, { "width", Gd.Float((dir.x != 0 ? span.z : span.x)) / f.res } };
            @event["base"] = new Rect2(new Vector2(@base.position + new Vector2i(f.offset.x, f.offset.z)) / f.res, new Vector2(@base.size) / f.res);
            @event["gutted"] = !under && span.y > Gd.Mini(@base.size.x, @base.size.y);
            @event["under"] = under;
            // the cell it stands on, for the readers that check what held it
            if (under)
            {
                @event["support"] = Support(f, index, lo.y);
            }
            // a gutted topple falls the gap too
            if ((Gd.Str(part["kind"]) != "topple" || !under))
            {
                @event["drop"] = Drop(f, index);
            }
            return @event;
        }
        // The grid index of the cell that holds up an island whose lowest layer is `low`: the top cell
        // under the first of its lowest cells that has one (VoxelFrame.column_top), or -1.

        public static long Support(VoxelFrame f, PackedInt32Array index, long low)
        {
            long plan = f.w * f.d;
            foreach (long i in index)
            {
                if (i / plan != low)
                {
                    continue;
                }
                long x = i % f.w;
                long z = (i / f.w) % f.d;
                long y = f.ColumnTop(x, z, low);
                if (y >= 0)
                {
                    return x + z * f.w + y * plan;
                }
            }
            return -1;
        }
        // Whether chunk ci of g is gone: worn to at most `share` of its cells, or, for a chunk that never
        // held a cell (the inside of a landmark's shell, under the stadium's stands and pitch), once
        // the chunk above it is gone (until then it holds up what stands on it), or at once on the top
        // floor (a tower's setback: nothing stands on it).

        public static bool Gone(Carving.Grid g, long ci, double share)
        {
            if (g.full[ci] > 0)
            {
                return g.live[ci] <= Gd.Floori(g.full[ci] * share);
            }
            long above = ci + g.bw * g.bd;
            return (above >= g.dead.Size() || g.dead[above] == 1);
        }

        void _InitFields()
        {
        }
        public CarvingCells() { _InitFields(); }
    }
}
