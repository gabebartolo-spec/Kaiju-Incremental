// Generated from sim/voxel_support.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class VoxelSupport : RefCounted
    {
        public static implicit operator VoxelSupport(Variant v) => (VoxelSupport)v.Obj;

        // The ground flood and the support rule behind VoxelFrame.settle() (split out to keep files
        // small). Made fresh for each settle: it labels every 6-connected structural part joined to the
        // ground floor, grid layer 0 (1, 2, ... in scan order of its first ground cell; 0 not
        // grounded). Fixtures (VoxelFrame.fixtures: panes, signs) then join a part when they touch it,
        // or a fixture already joined, by a face, an edge or a corner (26 neighbours), or stand on
        // layer 0; they never carry a structural cell (lead rule on #97). It then answers:
        // - islands(): the ungrounded parts, scan order (Teardown's split); two cells are in one
        // part when they share a face, or touch at all and one of them is a fixture;
        // - landing(part): an island lands on the columns with the smallest gap below it; hung past
        // them it topples over their edge, else it drops;
        // - topple(): Structure._topple_check per grounded part: the lowest level whose load (the
        // part's cells at or above it) has its centre of mass outside the box of the structural
        // cells there standing on a structural cell below (fixtures weigh but hold nothing).
        // Centres of mass are compared in integers (sums of 2x + 1), so the outcome is exact (the rule
        // itself is VoxelTopple's).
        // The native flood (native/src/kaiju_settle.cpp, KaijuSettle) does the whole-grid passes of this
        // class when the extension is loaded, and gives what the GDScript below gives, which stays the
        // reference: the "native port must match its digests" rule, held by tests/lib/settle_replay.gd,
        // which switches this off to settle the same carves both ways.
        public static bool useNative = true;
        public static RefCounted _native = null;
        // Per cell: the grounded part's label (> 0), 0 for not grounded, -1 once taken by an island.
        public PackedInt32Array labels = new PackedInt32Array();
        public long count = 0;
        public VoxelFrame _f;
        public PackedByteArray _cells = new PackedByteArray();
        public PackedByteArray _fix = new PackedByteArray();
        // per material id: 1 when structural (not empty, not a fixture)
        public PackedByteArray _solid = new PackedByteArray();
        public long _plan;

        public VoxelSupport(VoxelFrame frame)
        {
            _InitFields();
            _f = frame;
            _cells = frame.cells;
            _fix = frame.fixtures;
            _plan = frame.w * frame.d;
            var nat = VoxelSupport.Native();
            if (nat != null)
            {
                GArray<Variant> got = nat.Call("label", _cells, _fix, _Dims(), frame.hasFixtures);
                labels = got[0];
                count = got[1];
                return;
            }
            labels.Resize(_cells.Size());
            _solid.Resize(256);
            foreach (long m in Gd.Range(1, 256))
            {
                _solid[m] = (_fix[m] == 0 ? 1 : 0);
            }
            var stack = new PackedInt32Array();
            stack.Resize(_cells.Size());
            foreach (long start in Gd.Range(_plan))
            {
                long m = _cells[start];
                if (m != VoxelFrame.EMPTY && _fix[m] == 0 && labels[start] == 0)
                {
                    count += 1;
                    labels[start] = count;
                    stack[0] = start;
                    _Flood(stack, count);
                }
            }
            if (frame.hasFixtures)
            {
                _AttachFixtures(stack);
            }
        }
        // The native flood, or null (switched off, or the extension is not loaded).

        public static RefCounted Native()
        {
            if (!useNative)
            {
                return null;
            }
            if (_native == null && ClassDB.ClassExists("KaijuSettle"))
            {
                _native = ClassDB.Instantiate("KaijuSettle");
            }
            return _native;
        }

        public Vector3i _Dims()
        {
            return new Vector3i(_f.w, _f.h, _f.d);
        }
        // Floods `label` over every structural unlabelled cell joined to stack[0] (iterative, packed stack;
        // the neighbours written out: an array per cell costs the flood about a third more).

        public void _Flood(PackedInt32Array stack, long label)
        {
            long top = 1;
            while (top > 0)
            {
                top -= 1;
                long i = stack[top];
                top = _SpreadX(stack, top, i, label);
                top = _SpreadZ(stack, top, i, label);
                top = _SpreadY(stack, top, i, label);
            }
        }
        // Labels and pushes the structural unlabelled neighbours of cell `i` along x (x - 1, x + 1);
        // returns the new top of the stack.

        public long _SpreadX(PackedInt32Array stack, long top, long i, long label)
        {
            long x = i % _f.w;
            if (x > 0 && labels[i - 1] == 0 && _solid[_cells[i - 1]] != 0)
            {
                labels[i - 1] = label;
                stack[top] = i - 1;
                top += 1;
            }
            if (x < _f.w - 1 && labels[i + 1] == 0 && _solid[_cells[i + 1]] != 0)
            {
                labels[i + 1] = label;
                stack[top] = i + 1;
                top += 1;
            }
            return top;
        }
        // As _spread_x, along z (z - 1, z + 1).

        public long _SpreadZ(PackedInt32Array stack, long top, long i, long label)
        {
            long w = _f.w;
            long z = (i / w) % _f.d;
            if (z > 0 && labels[i - w] == 0 && _solid[_cells[i - w]] != 0)
            {
                labels[i - w] = label;
                stack[top] = i - w;
                top += 1;
            }
            if (z < _f.d - 1 && labels[i + w] == 0 && _solid[_cells[i + w]] != 0)
            {
                labels[i + w] = label;
                stack[top] = i + w;
                top += 1;
            }
            return top;
        }
        // As _spread_x, along y (y - 1, y + 1).

        public long _SpreadY(PackedInt32Array stack, long top, long i, long label)
        {
            long y = i / _plan;
            if (y > 0 && labels[i - _plan] == 0 && _solid[_cells[i - _plan]] != 0)
            {
                labels[i - _plan] = label;
                stack[top] = i - _plan;
                top += 1;
            }
            if (y < _f.h - 1 && labels[i + _plan] == 0 && _solid[_cells[i + _plan]] != 0)
            {
                labels[i + _plan] = label;
                stack[top] = i + _plan;
                top += 1;
            }
            return top;
        }
        // Joins each fixture to a grounded part: scan order, a fixture touching a labelled cell takes
        // its label (one on layer 0 touching none starts a new part), then floods it over the fixtures
        // it touches (26 neighbours). Fixtures never pass a label on to a structural cell.

        public void _AttachFixtures(PackedInt32Array stack)
        {
            foreach (long start in Gd.Range(_cells.Size()))
            {
                long m = _cells[start];
                if ((m == VoxelFrame.EMPTY || _fix[m] == 0 || labels[start] != 0))
                {
                    continue;
                }
                long label = _FixtureLabel(start);
                if (label == 0)
                {
                    // Lead rule (#97): a fixture on grid layer 0 is grounded though it touches nothing else
                    // (a ground-floor shopfront rests on the street).
                    if (start >= _plan)
                    {
                        continue;
                    }
                    count += 1;
                    label = count;
                }
                labels[start] = label;
                _FloodFixtures(stack, start, label);
            }
        }
        // The label of the first labelled cell round fixture `start` (ring order), or 0 when none.

        public long _FixtureLabel(long start)
        {
            var ring = _Ring(start);
            foreach (long r in Gd.Range(0, ring.Size(), 2))
            {
                if (labels[ring[r]] > 0)
                {
                    return labels[ring[r]];
                }
            }
            return 0;
        }
        // Floods `label` from fixture `start` over the unlabelled fixtures it touches (26 neighbours).

        public void _FloodFixtures(PackedInt32Array stack, long start, long label)
        {
            stack[0] = start;
            long top = 1;
            while (top > 0)
            {
                top -= 1;
                var around = _Ring(stack[top]);
                foreach (long r in Gd.Range(0, around.Size(), 2))
                {
                    long n = around[r];
                    if (labels[n] == 0 && _cells[n] != VoxelFrame.EMPTY && _fix[_cells[n]] != 0)
                    {
                        labels[n] = label;
                        stack[top] = n;
                        top += 1;
                    }
                }
            }
        }
        // The 26 neighbours of cell `i` inside the grid, as pairs [index, 1 if it shares a face].

        public PackedInt32Array _Ring(long i)
        {
            long w = _f.w;
            long d = _f.d;
            long x = i % w;
            long z = (i / w) % d;
            long y = i / _plan;
            var @out = new PackedInt32Array();
            foreach (long dy in Gd.Range(Gd.Maxi(-y, -1), Gd.Mini(_f.h - y, 2)))
            {
                foreach (long dz in Gd.Range(Gd.Maxi(-z, -1), Gd.Mini(d - z, 2)))
                {
                    foreach (long dx in Gd.Range(Gd.Maxi(-x, -1), Gd.Mini(w - x, 2)))
                    {
                        long step = Gd.Absi(dx) + Gd.Absi(dy) + Gd.Absi(dz);
                        if (step > 0)
                        {
                            @out.Append(i + dx + dz * w + dy * _plan);
                            @out.Append(Gd.Int(step == 1));
                        }
                    }
                }
            }
            return @out;
        }
        // Every alive, ungrounded cell, split into islands (scan order of first cell,
        // cells in flood order; joined as the header says); marks them -1. The caller removes them.

        public GArray<PackedInt32Array> Islands()
        {
            GArray<PackedInt32Array> @out = new GArray<PackedInt32Array>();
            var nat = VoxelSupport.Native();
            // the labels stay as they were: the caller takes these cells out of the grid
            if (nat != null)
            {
                GArray<Variant> got = nat.Call("islands", labels, _cells, _fix, _Dims(), _f.hasFixtures);
                @out.Assign(got);
                return @out;
            }
            foreach (long start in Gd.Range(_cells.Size()))
            {
                if (_cells[start] != VoxelFrame.EMPTY && labels[start] == 0)
                {
                    @out.Append(_Grow(start));
                }
            }
            return @out;
        }
        // The island holding cell `start`, its cells in flood order, marked -1.

        public PackedInt32Array _Grow(long start)
        {
            var part = new PackedInt32Array(Gd.Arr(start));
            labels[start] = -1;
            long k = 0;
            while (k < part.Size())
            {
                long i = part[k];
                k += 1;
                if (_f.hasFixtures)
                {
                    _Join(i, part);
                }
                else
                {
                    _JoinFaces(i, part);
                }
            }
            return part;
        }
        // Adds to `part` the unclaimed cells sharing a face with `i` (a grid with no fixtures).

        public void _JoinFaces(long i, PackedInt32Array part)
        {
            long w = _f.w;
            long x = i % w;
            long z = (i / w) % _f.d;
            long y = i / _plan;
            foreach (long n in Gd.Arr((x > 0 ? i - 1 : -1), (x < w - 1 ? i + 1 : -1), (z > 0 ? i - w : -1), (z < _f.d - 1 ? i + w : -1), (y > 0 ? i - _plan : -1), (y < _f.h - 1 ? i + _plan : -1)))
            {
                if (n >= 0 && labels[n] == 0 && _cells[n] != VoxelFrame.EMPTY)
                {
                    labels[n] = -1;
                    part.Append(n);
                }
            }
        }
        // Adds to `part` the unclaimed neighbours of `i` it is joined to: a face, or any touch when
        // either cell is a fixture.

        public void _Join(long i, PackedInt32Array part)
        {
            var loose = _fix[_cells[i]] != 0;
            var ring = _Ring(i);
            foreach (long r in Gd.Range(0, ring.Size(), 2))
            {
                long n = ring[r];
                if ((labels[n] != 0 || _cells[n] == VoxelFrame.EMPTY))
                {
                    continue;
                }
                if ((loose || ring[r + 1] == 1 || _fix[_cells[n]] != 0))
                {
                    labels[n] = -1;
                    part.Append(n);
                }
            }
        }
        // Where an island (already removed from the grid) lands: {kind, pivot, dir}.

        public GDict Landing(PackedInt32Array part)
        {
            var nat = VoxelSupport.Native();
            if (nat != null)
            {
                return _LandNative(nat, part);
            }
            GDict low = new GDict();
            var sums = new PackedInt64Array(Gd.Arr(0, 0, part.Size()));
            foreach (long i in part)
            {
                long col = i % _plan;
                long y = i / _plan;
                long was = low.Get(col, y);
                low[col] = Gd.Mini(was, y);
                sums[0] += 2 * (col % _f.w) + 1;
                sums[1] += 2 * (col / _f.w) + 1;
            }
            GDict gaps = new GDict();
            long least = _f.h;
            foreach (long col in low)
            {
                long bottom = low[col];
                long gap = bottom - _f.ColumnTop(col % _f.w, col / _f.w, bottom) - 1;
                gaps[col] = gap;
                least = Gd.Mini(least, gap);
            }
            var box = new Rect2i();
            long lands = _f.h;
            foreach (long col in gaps)
            {
                long gap = gaps[col];
                if (gap == least)
                {
                    long bottom = low[col];
                    var at = new Rect2i(col % _f.w, col / _f.w, 1, 1);
                    box = (box.size == Vector2i.ZERO ? at : box.Merge(at));
                    lands = Gd.Mini(lands, bottom - least);
                }
            }
            GDict tip = _Tip(sums, box, lands);
            return (!tip.IsEmpty() ? tip : _PlainDrop());
        }
        // KaijuSettle's landing of `part` (its lowest cells per column), read as landing() reads its own.

        public GDict _LandNative(RefCounted nat, PackedInt32Array part)
        {
            PackedInt64Array r = nat.Call("land", part, _f.cells, _Dims());
            GDict at = _Tip(new PackedInt64Array(Gd.Arr(r[0], r[1], r[2])), new Rect2i(r[3], r[4], r[5] - r[3], r[6] - r[4]), r[7]);
            return (!at.IsEmpty() ? at : _PlainDrop());
        }

        public static GDict _PlainDrop()
        {
            return new GDict { { "kind", "drop" }, { "pivot", Vector3.ZERO }, { "dir", Vector2i.ZERO } };
        }
        // The lowest toppling level of each grounded part, as {kind, pivot, dir, label, level}.

        public GArray<GDict> Topple()
        {
            GArray<GDict> @out = new GArray<GDict>();
            if (count == 0)
            {
                return @out;
            }
            GDict floors = _Floors();
            PackedInt64Array mass = floors["mass"];
            PackedInt64Array sx = floors["sx"];
            PackedInt64Array sz = floors["sz"];
            PackedInt32Array box = floors["box"];
            return VoxelTopple.ScanLevels(mass, sx, sz, box, count, _f.h, _f.offset, _f.res);
        }
        // Per grounded part and level, the loads and support boxes (VoxelTopple.floors documents the
        // layout): from the native pass, or the GDScript reference.

        public GDict _Floors()
        {
            var nat = VoxelSupport.Native();
            if (nat != null)
            {
                return nat.Call("floors", labels, _cells, _fix, _Dims(), count);
            }
            return VoxelTopple.Floors(_cells, _fix, labels, _Dims(), count);
        }
        // Structure's tip test (VoxelTopple.tip_of) for a load over `box` (cells) at height `y` (cells).

        public GDict _Tip(PackedInt64Array sums, Rect2i box, long y)
        {
            return VoxelTopple.TipOf(sums, box, y, _f.offset, _f.res);
        }

        void _InitFields()
        {
        }
    }
}
