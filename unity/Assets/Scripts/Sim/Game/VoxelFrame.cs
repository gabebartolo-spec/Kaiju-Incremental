// Generated from sim/voxel_frame.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class VoxelFrame : RefCounted
    {
        public static implicit operator VoxelFrame(Variant v) => (VoxelFrame)v.Obj;

        // A building as a fine voxel grid that a monster carves (D-094, option A: Teardown's carving plus
        // Red Faction: Guerrilla's support rule). RES cells per sim unit (data/tuning.json
        // "destruction"), one byte per cell: 0 empty, else a material id from the caller's material
        // list (data/materials.json's shape: {id, name, strength}). Cells run x fastest, then z, then y,
        // as in Structure. A material marked "fixture" (a window pane, a sign) hangs on its neighbours:
        // it is attached when it touches an attached cell by a face, an edge or a corner, and it holds
        // no structural cell up (lead rule on #97). Positions passed in are building-local sim units:
        // local cell (x, y, z) fills [x, x + 1] / RES on each axis; grid cell 0 is local cell `offset`.
        //
        // A blow carves a sphere (stomp) or a capsule (swipe); settle() then finds what lost support,
        // with Structure.settle()'s event shape ({cells, kind "drop"|"topple", pivot, dir}) so Collapse
        // can consume it unchanged (cells are fine-grid cells; pivot is in sim units):
        // - islands: parts no longer joined to the ground floor; each drops, or topples off the edge of
        // the cells it lands on when its centre of mass hangs past them;
        // - the grounded remainder: Structure's topple rule per connected grounded part, so a tower
        // is not "held up by a chimney".
        // Pure and deterministic: integer grid and decisions, fixed scan order, no RNG, no clock.
        // The GDScript reference (the oracle); WP2's native port must match its digests.
        public const long EMPTY = 0;
        public long res;
        // Grid size in cells.
        public long w;
        public long d;
        public long h;
        public long aliveCount = 0;
        // The building-local cell of grid cell (0, 0, 0) (WP3's BuildingCells.offset: the grid also
        // holds what stands proud of the footprint). Every Vector3i, position and event is
        // building-local; only "index" is a grid index.
        public Vector3i offset = Vector3i.ZERO;
        public PackedByteArray cells = new PackedByteArray();
        // By material id: 1 when the material is a fixture (data/materials.json "fixture", default
        // false), else 0. VoxelSupport reads it.
        public PackedByteArray fixtures = new PackedByteArray();
        // True when any material in the list is a fixture (the flood skips the fixture pass if not).
        public bool hasFixtures = false;
        // True once a settle has run (Carving.warm's first-settle stage looks).
        public bool settledOnce = false;
        // By material id: the blow needed to break a cell of it.
        public PackedFloat64Array _strength = new PackedFloat64Array();
        public GDict _ids = new GDict();

        public VoxelFrame(Vector3i units, long pRes, GArray<GDict> materials)
        {
            _InitFields();
            res = pRes;
            w = units.x * res;
            d = units.z * res;
            h = units.y * res;
            cells.Resize(w * d * h);
            _strength.Resize(256);
            fixtures.Resize(256);
            foreach (GDict m in materials)
            {
                long id = Num.I(m["id"]);
                if (id > EMPTY && id < 256)
                {
                    _strength[id] = Num.F(m.Get("strength", 1.0));
                    _ids[Gd.Str(m["name"])] = id;
                    if (m.Get("fixture", false) == true)
                    {
                        fixtures[id] = 1;
                        hasFixtures = true;
                    }
                }
            }
        }
        // Takes a generated grid (WP3's BuildingCells: dims, offset, cells), a copy of its bytes.
        // The ground is grid layer 0, so offset.y must be 0; dims must match the bytes. A grid that
        // breaks either is refused (an error, false) and the frame is left as it was.

        public bool Adopt(Vector3i dims, Vector3i pOffset, PackedByteArray pCells)
        {
            long size = dims.x * dims.y * dims.z;
            if ((pOffset.y != 0 || Gd.Mini(Gd.Mini(dims.x, dims.y), dims.z) < 1 || size != pCells.Size()))
            {
                Gd.PushError((Gd.Format("VoxelFrame.adopt refused: dims %s, offset %s, %d bytes", Gd.Arr(dims, pOffset, pCells.Size()))));
                return false;
            }
            w = dims.x;
            d = dims.z;
            h = dims.y;
            offset = pOffset;
            cells = pCells.Duplicate();
            aliveCount = cells.Size() - cells.Count(EMPTY);
            return true;
        }
        // The id of a material by name, or EMPTY when the list has no such material.

        public long MaterialId(string material)
        {
            long id = _ids.Get(material, EMPTY);
            return id;
        }
        // The grid index of a building-local cell.

        public long Index(Vector3i c)
        {
            var g = c - offset;
            return g.x + g.z * w + g.y * w * d;
        }

        public bool Inside(Vector3i c)
        {
            var g = c - offset;
            return g.x >= 0 && g.y >= 0 && g.z >= 0 && g.x < w && g.y < h && g.z < d;
        }

        public bool Alive(Vector3i c)
        {
            return Inside(c) && cells[Index(c)] != EMPTY;
        }
        // Sets one cell's material (EMPTY clears it); outside the grid is ignored.

        public void SetCell(Vector3i c, long material)
        {
            if (!Inside(c))
            {
                return;
            }
            long i = Index(c);
            aliveCount += Gd.Int(material != EMPTY) - Gd.Int(cells[i] != EMPTY);
            cells[i] = material;
        }
        // Sets every cell in [lo, hi) (clipped to the grid).

        public void Fill(Vector3i lo, Vector3i hi, long material)
        {
            var top = offset + new Vector3i(w, h, d);
            foreach (long y in Gd.Range(Gd.Maxi(offset.y, lo.y), Gd.Mini(top.y, hi.y)))
            {
                foreach (long z in Gd.Range(Gd.Maxi(offset.z, lo.z), Gd.Mini(top.z, hi.z)))
                {
                    foreach (long x in Gd.Range(Gd.Maxi(offset.x, lo.x), Gd.Mini(top.x, hi.x)))
                    {
                        SetCell(new Vector3i(x, y, z), material);
                    }
                }
            }
        }
        // A blow of `amount` on one cell: it breaks when the blow reaches its material's strength.
        // One byte per cell holds no wear, so a weaker blow leaves it whole. True if it broke now.

        public bool Damage(Vector3i c, double amount)
        {
            if (!Alive(c))
            {
                return false;
            }
            long i = Index(c);
            if (amount < _strength[cells[i]])
            {
                return false;
            }
            cells[i] = EMPTY;
            aliveCount -= 1;
            return true;
        }
        // Empties grid cell `i` (a grid index, not a cell); returns the material it held.

        public long ClearIndex(long i)
        {
            long m = cells[i];
            if (m != EMPTY)
            {
                cells[i] = EMPTY;
                aliveCount -= 1;
            }
            return m;
        }

        public void Remove(Vector3i c)
        {
            if (Alive(c))
            {
                cells[Index(c)] = EMPTY;
                aliveCount -= 1;
            }
        }
        // Highest standing cell in column (x, z) below `below_y`, or -1 (building-local).

        public long TopBelow(long x, long z, long belowY)
        {
            long y = ColumnTop(x - offset.x, z - offset.z, belowY - offset.y);
            return (y >= 0 ? y + offset.y : -1);
        }
        // As top_below in grid coordinates (VoxelSupport's landing).

        public long ColumnTop(long gx, long gz, long belowGy)
        {
            if ((gx < 0 || gz < 0 || gx >= w || gz >= d))
            {
                return -1;
            }
            long plan = w * d;
            foreach (long y in Gd.Range(Gd.Mini(belowGy, h) - 1, -1, -1))
            {
                if (cells[gx + gz * w + y * plan] != EMPTY)
                {
                    return y;
                }
            }
            return -1;
        }
        // Removes every cell whose centre is inside the sphere and whose strength is at most `force`.
        // Returns the removed cell indices in scan order. Does not settle.

        public PackedInt32Array CarveSphere(Vector3 centre, double radius, double force)
        {
            var removed = new PackedInt32Array();
            var shift = new Vector3(offset);
            var lo = ((centre - Vector3.ONE * radius) * res - shift).Floor();
            var hi = ((centre + Vector3.ONE * radius) * res - shift).Ceil();
            double r2 = radius * radius * res * res;
            var c = centre * res - shift;
            long plan = w * d;
            foreach (long y in Gd.Range(Gd.Maxi(0, Gd.Int(lo.y)), Gd.Mini(h, Gd.Int(hi.y) + 1)))
            {
                foreach (long z in Gd.Range(Gd.Maxi(0, Gd.Int(lo.z)), Gd.Mini(d, Gd.Int(hi.z) + 1)))
                {
                    foreach (long x in Gd.Range(Gd.Maxi(0, Gd.Int(lo.x)), Gd.Mini(w, Gd.Int(hi.x) + 1)))
                    {
                        long i = x + z * w + y * plan;
                        long m = cells[i];
                        if ((m == EMPTY || _strength[m] > force))
                        {
                            continue;
                        }
                        if (new Vector3(x + 0.5, y + 0.5, z + 0.5).DistanceSquaredTo(c) <= r2)
                        {
                            cells[i] = EMPTY;
                            removed.Append(i);
                        }
                    }
                }
            }
            aliveCount -= removed.Size();
            return removed;
        }
        public PackedInt32Array CarveSphere(Vector3 centre, double radius) => CarveSphere(centre, radius, Gd.INF);
        // As carve_sphere, along the segment a-b (a swipe sweeps a sphere from a to b).

        public PackedInt32Array CarveCapsule(Vector3 a, Vector3 b, double radius, double force)
        {
            var shift = new Vector3(offset);
            var ca = a * res - shift;
            var ab = (b - a) * res;
            double len2 = ab.LengthSquared();
            if (len2 == 0.0)
            {
                return CarveSphere(a, radius, force);
            }
            var removed = new PackedInt32Array();
            var lo = ((a.Min(b) - Vector3.ONE * radius) * res - shift).Floor();
            var hi = ((a.Max(b) + Vector3.ONE * radius) * res - shift).Ceil();
            double r2 = radius * radius * res * res;
            long plan = w * d;
            foreach (long y in Gd.Range(Gd.Maxi(0, Gd.Int(lo.y)), Gd.Mini(h, Gd.Int(hi.y) + 1)))
            {
                foreach (long z in Gd.Range(Gd.Maxi(0, Gd.Int(lo.z)), Gd.Mini(d, Gd.Int(hi.z) + 1)))
                {
                    foreach (long x in Gd.Range(Gd.Maxi(0, Gd.Int(lo.x)), Gd.Mini(w, Gd.Int(hi.x) + 1)))
                    {
                        long i = x + z * w + y * plan;
                        long m = cells[i];
                        if ((m == EMPTY || _strength[m] > force))
                        {
                            continue;
                        }
                        var p = new Vector3(x + 0.5, y + 0.5, z + 0.5);
                        double t = Gd.Clampf((p - ca).Dot(ab) / len2, 0.0, 1.0);
                        if (p.DistanceSquaredTo(ca + ab * t) <= r2)
                        {
                            cells[i] = EMPTY;
                            removed.Append(i);
                        }
                    }
                }
            }
            aliveCount -= removed.Size();
            return removed;
        }
        public PackedInt32Array CarveCapsule(Vector3 a, Vector3 b, double radius) => CarveCapsule(a, b, radius, Gd.INF);
        // Teardown's split alone (the spike's rule, no support rule): removes and returns every part
        // no longer joined to the ground floor, in scan order of its first cell, each a "drop".

        public GArray<GDict> Detach()
        {
            var support = new VoxelSupport(this);
            return _TakeAll(support.Islands());
        }
        // Removes and returns every part that lost support, as Structure.settle() does:
        // {"cells": Array[Vector3i], "kind": "drop"|"topple", "pivot": Vector3 (local sim units),
        // "dir": Vector2i, "mats": PackedByteArray (each cell's material), "index": PackedInt32Array}.
        // Islands first (scan order), then at most one topple per grounded part (lowest level), then
        // what hung from a toppled load below its level: a fresh flood, its islands land as the first
        // ones do (review FIX on #97: nothing is left floating). The native flood and cell loops
        // (KaijuSettle) run it where the extension is loaded; with VoxelSupport.use_native off this is
        // the GDScript reference they are held to (tests/lib/settle_replay.gd). `topples` off: islands
        // only (a ring landmark comes down by its arcs, never whole: its weight hangs over the pitch).

        public GArray<GDict> Settle(bool topples = true)
        {
            settledOnce = true;
            var support = new VoxelSupport(this);
            GArray<GDict> @out = new GArray<GDict>();
            _DropIslands(support, @out);
            long first = @out.Size();
            long plan = w * d;
            var tips = (topples ? support.Topple() : (((GArray<GDict>)Gd.Arr())));
            foreach (GDict tip in tips)
            {
                long label = tip["label"];
                long level = tip["level"];
                var part = new PackedInt32Array();
                var nat = VoxelSupport.Native();
                if (nat != null)
                {
                    part = nat.Call("gather", support.labels, cells, level * plan, label);
                }
                else
                {
                    foreach (long i in Gd.Range(level * plan, cells.Size()))
                    {
                        if (support.labels[i] == label && cells[i] != EMPTY)
                        {
                            part.Append(i);
                        }
                    }
                }
                GDict @event = _TakeAll(new GArray<PackedInt32Array> { part })[0];
                @event["kind"] = "topple";
                @event["pivot"] = tip["pivot"];
                @event["dir"] = tip["dir"];
                @out.Append(@event);
            }
            if (@out.Size() > first)
            {
                _DropIslands(new VoxelSupport(this), @out);
            }
            return @out;
        }
        // Takes every island `support` finds and appends it to `out`, each with where it lands.

        public void _DropIslands(VoxelSupport support, GArray<GDict> @out)
        {
            long start = @out.Size();
            var isl = support.Islands();
            @out.AppendArray(_TakeAll(isl));
            foreach (long k in Gd.Range(start, @out.Size()))
            {
                PackedInt32Array index = @out[k]["index"];
                @out[k].Merge(support.Landing(index), true);
            }
        }
        // A digest of the grid, for replay checks.

        public long Digest()
        {
            return Gd.Hash(cells);
        }
        // Removes the cells of `part` (grid indices, all standing) and returns them as a "drop" event, as
        // settle() does (Carving brings a ring landmark's arc down with it).

        public GDict Take(PackedInt32Array part)
        {
            return _TakeAll(new GArray<PackedInt32Array> { part })[0];
        }
        // Removes the cells of each part and returns them as "drop" events (natively where loaded).

        public GArray<GDict> _TakeAll(GArray<PackedInt32Array> parts)
        {
            GArray<GDict> @out = new GArray<GDict>();
            var nat = VoxelSupport.Native();
            if (nat == null)
            {
                foreach (PackedInt32Array part in parts)
                {
                    @out.Append(_Take(part));
                }
                return @out;
            }
            GArray<Variant> got = nat.Call("take", cells, parts, new Vector3i(w, h, d), offset);
            cells = got[0];
            foreach (long k in Gd.Range(parts.Size()))
            {
                GArray<Vector3i> list = new GArray<Vector3i>();
                GArray<Variant> raw = got[2][k];
                list.Assign(raw);
                aliveCount -= parts[k].Size();
                PackedByteArray mats = got[1][k];
                @out.Append(_DropEvent(list, mats, parts[k]));
            }
            return @out;
        }
        // Removes the cells of `part` and returns them as a "drop" event.

        public GDict _Take(PackedInt32Array part)
        {
            var mats = new PackedByteArray();
            mats.Resize(part.Size());
            GArray<Vector3i> list = new GArray<Vector3i>();
            long plan = w * d;
            foreach (long k in Gd.Range(part.Size()))
            {
                long i = part[k];
                mats[k] = cells[i];
                cells[i] = EMPTY;
                list.Append(new Vector3i(i % w, i / plan, (i / w) % d) + offset);
            }
            aliveCount -= part.Size();
            return _DropEvent(list, mats, part);
        }

        public static GDict _DropEvent(GArray<Vector3i> list, PackedByteArray mats, PackedInt32Array part)
        {
            return new GDict { { "cells", list }, { "kind", "drop" }, { "pivot", Vector3.ZERO }, { "dir", Vector2i.ZERO }, { "mats", mats }, { "index", part } };
        }

        void _InitFields()
        {
        }
    }
}
