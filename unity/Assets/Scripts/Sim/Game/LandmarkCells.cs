// Generated from sim/landmark_cells.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class LandmarkCells : CellGrid
    {
        public static implicit operator LandmarkCells(Variant v) => (LandmarkCells)v.Obj;

        // A landmark's fine destruction grid (D-094 WP6): the baked model (data/landmarks.json "kvox",
        // tools/landmarks/bake.py) read as cells, on the same grid BuildingCells uses (RES cells per sim
        // unit, cells local to the footprint), so LandmarkVoxels' voxels and this grid are the same cells.
        // A cell's material is its colour's class: the shape's "ground" colours are landmark_pitch, greys
        // landmark_wall, reds landmark_seat, the rest landmark_other (the same tests LandmarkVoxels runs).
        // A ring landmark's arcs (Arcs, the stadium) carry over to cells: its sections are the same plan
        // columns, and an arc that has lost "arc_shed_cells" cells since it last shed (data/tuning.json
        // "destruction") brings down every cell of it above the stub as one toppling section, like
        // Structure.settle() does with chunks. shed() reports the section, the caller clears it with
        // clear_cell(). Pure sim: no clock, no RNG, no scene.
        public const double GREY = 0.12;
        public const double RED = 0.3;
        // How near (per channel, 0-255) a voxel's colour must be to a ground colour.
        public const long GROUND_MATCH = 24;
        public const string MAGIC = "KVOX";
        // A parsed model per landmark id: {"cells": PackedInt32Array x, y, z triples, "mats": names}.
        public static GDict _cache = new GDict();
        public static Mutex _lock = new Mutex();
        public RampageSim.Building b;
        // The chunk shape's arcs, or null for a landmark without them.
        public Arcs arcs;
        public PackedInt32Array _live = new PackedInt32Array();
        public PackedInt32Array _whole = new PackedInt32Array();
        public GArray<PackedInt32Array> _members = new GArray<PackedInt32Array>();
        public long _shedAt = 0;

        public LandmarkCells(RampageSim.Building pBuilding)
        {
            _InitFields();
            b = pBuilding;
            arcs = (b.frame != null ? b.frame.arcs : null);
            res = CellRes();
            _shedAt = Num.I(Content.Section("destruction").Get("arc_shed_cells", 1));
            GDict model = (b.model == "" ? _Model(b.landmark) : ModelOf(b));
            PackedInt32Array xyz = model["xyz"];
            PackedByteArray mats = model["mats"];
            GArray<Variant> box = _Bounds(model);
            Vector3i boxLo = box[0];
            Vector3i boxHi = box[1];
            var lo = boxLo.Min(Vector3i.ZERO);
            var hi = boxHi.Max(new Vector3i(b.w * res - 1, b.height * res - 1, b.d * res - 1));
            offset = lo;
            dims = hi - lo + Vector3i.ONE;
            cells = new PackedByteArray();
            cells.Resize(dims.x * dims.y * dims.z);
            long arcN = (arcs != null ? arcs.ArcCount() : 0);
            _live.Resize(arcN);
            _members.Resize(arcN);
            // no arcs to count: fill on the flat index (the wheel has 61k cells)
            if (arcs == null)
            {
                long plane = dims.x * dims.z;
                long @base = -lo.x - lo.z * dims.x - lo.y * plane;
                foreach (long i in Gd.Range(mats.Size()))
                {
                    cells[@base + xyz[i * 3] + xyz[i * 3 + 2] * dims.x + xyz[i * 3 + 1] * plane] = mats[i];
                }
            }
            foreach (long i in Gd.Range((arcs != null ? mats.Size() : 0)))
            {
                var c = new Vector3i(xyz[i * 3], xyz[i * 3 + 1], xyz[i * 3 + 2]);
                cells[Index(c - offset)] = mats[i];
                long g = ArcOf(c);
                if (g < 0)
                {
                    continue;
                }
                _live[g] += 1;
                if (c.y >= arcs.stub * res)
                {
                    _members[g].Append(Index(c - offset));
                }
            }
            _whole = _live.Duplicate();
        }
        // The arc a building-local cell belongs to (Arcs.arc_at on its plan column), or -1.

        public long ArcOf(Vector3i local)
        {
            if ((arcs == null || local.x < 0 || local.z < 0))
            {
                return -1;
            }
            long x = local.x / res;
            long z = local.z / res;
            if ((x >= b.w || z >= b.d))
            {
                return -1;
            }
            return arcs.ArcAt(x, z);
        }
        // Empties a cell; an arc's standing count follows.

        public override void ClearCell(Vector3i local)
        {
            if (At(local) == 0)
            {
                return;
            }
            base.ClearCell(local);
            long g = ArcOf(local);
            if (g >= 0)
            {
                _live[g] -= 1;
            }
        }
        // Empties a chunk; its arc's standing count follows (a chunk is one plan column, so one arc).

        public override void ClearChunk(Vector3i chunk)
        {
            long lost = _ClearRows(chunk);
            long g = ArcOf(chunk * res);
            if (g >= 0)
            {
                _live[g] -= lost;
            }
        }
        // Takes the standing arcs as the baseline: what the chunk Structure already shed (and
        // CellPromoter has emptied) is not a new loss.

        public void Rebase()
        {
            _whole = _live.Duplicate();
        }
        // The sections to bring down now: for each arc that lost arc_shed_cells cells since it last shed,
        // every cell of it still standing above the stub, as {"cells": Array[Vector3i] (building-local),
        // "kind": "topple", "pivot": Vector3 (in cells), "dir": Vector2i}. The caller clears them.

        public GArray<GDict> Shed()
        {
            GArray<GDict> @out = new GArray<GDict>();
            if (arcs == null)
            {
                return @out;
            }
            long plan = dims.x * dims.z;
            foreach (long g in Gd.Range(_live.Size()))
            {
                if (_whole[g] - _live[g] < _shedAt)
                {
                    continue;
                }
                GArray<Vector3i> section = new GArray<Vector3i>();
                foreach (long i in _members[g])
                {
                    if (cells[i] != 0)
                    {
                        section.Append(new Vector3i(i % dims.x, i / plan, (i / dims.x) % dims.z) + offset);
                    }
                }
                _whole[g] = _live[g] - section.Size();
                if (!section.IsEmpty())
                {
                    var dir = arcs.DirOf(g);
                    @out.Append(new GDict { { "cells", section }, { "kind", "topple" }, { "pivot", _Pivot(section, dir) }, { "dir", dir } });
                }
            }
            return @out;
        }
        // The edge it tips over: the section's far side toward `dir`, at the top of the stub.

        public Vector3 _Pivot(GArray<Vector3i> section, Vector2i dir)
        {
            var lo = new Vector2(Gd.INF, Gd.INF);
            var hi = new Vector2(-Gd.INF, -Gd.INF);
            var sum = Vector2.ZERO;
            foreach (Vector3i c in section)
            {
                lo = new Vector2(Gd.Minf(lo.x, c.x), Gd.Minf(lo.y, c.z));
                hi = new Vector2(Gd.Maxf(hi.x, c.x + 1), Gd.Maxf(hi.y, c.z + 1));
                sum += new Vector2(c.x + 0.5, c.z + 0.5);
            }
            var mid = sum / section.Size();
            double px = (dir.x > 0 ? hi.x : ((dir.x < 0 ? lo.x : mid.x)));
            double pz = (dir.y > 0 ? hi.y : ((dir.y < 0 ? lo.y : mid.y)));
            return new Vector3(px, arcs.stub * res, pz);
        }
        // The material of a baked colour, as the id of its landmark_ class.

        public static string MaterialOf(Color c, GArray<Variant> ground)
        {
            foreach (Variant key in ground)
            {
                var g = new Color(Gd.Str(key));
                var off = new Vector3(Gd.Absf(c.r - g.r), Gd.Absf(c.g - g.g), Gd.Absf(c.b - g.b)) * 255.0;
                if (Gd.Maxf(off.x, Gd.Maxf(off.y, off.z)) <= GROUND_MATCH)
                {
                    return "landmark_pitch";
                }
            }
            if (Gd.Maxf(c.r, Gd.Maxf(c.g, c.b)) - Gd.Minf(c.r, Gd.Minf(c.g, c.b)) < GREY)
            {
                return "landmark_wall";
            }
            if (c.r > c.g + RED && c.r > c.b + RED)
            {
                return "landmark_seat";
            }
            return "landmark_other";
        }
        // A pool building's model (data/city_buildings.json) as cells, turned, mirrored and stretched as
        // the building was placed (ModelVariant); the base read is kept once, the variant made per call
        // (only a building the rampage reaches is promoted).

        public static GDict ModelOf(RampageSim.Building building)
        {
            GDict v = (!building.variant.IsEmpty() ? building.variant : ModelVariant.Of(new GDict()));
            GDict row = ModelVariant.RowOf(building.model);
            GDict @out = new GDict { { "xyz", new PackedInt32Array() }, { "mats", new PackedByteArray() } };
            var path = Gd.Str(row.Get("kvox", ""));
            if (path != "" && FileAccess.FileExists(path))
            {
                _lock.Lock();
                GDict @base = _cache.Get(path, new GDict());
                _lock.Unlock();
                if (@base.IsEmpty())
                {
                    @base = _Read(path, Gd.Arr());
                    _lock.Lock();
                    _cache[path] = @base;
                    _lock.Unlock();
                }
                PackedInt32Array baseXyz = @base["xyz"];
                GDict turned = ModelVariant.Cells(baseXyz, row, v, CellRes());
                PackedInt32Array src = turned["src"];
                PackedByteArray mats = @base["mats"];
                var picked = new PackedByteArray();
                picked.Resize(src.Size());
                foreach (long i in Gd.Range(src.Size()))
                {
                    picked[i] = mats[src[i]];
                }
                @out = new GDict { { "xyz", turned["xyz"] }, { "mats", picked } };
            }
            return @out;
        }
        // The model's [lowest, highest] cell, kept in the model (a landmark's is read once).

        public static GArray<Variant> _Bounds(GDict model)
        {
            if (model.Has("box"))
            {
                return model["box"];
            }
            PackedInt32Array xyz = model["xyz"];
            var lo = Vector3i.ZERO;
            var hi = Vector3i.ZERO;
            foreach (long i in Gd.Range(xyz.Size() / 3))
            {
                var c = new Vector3i(xyz[i * 3], xyz[i * 3 + 1], xyz[i * 3 + 2]);
                lo = (i == 0 ? c : lo.Min(c));
                hi = (i == 0 ? c : hi.Max(c));
            }
            model["box"] = Gd.Arr(lo, hi);
            return model["box"];
        }
        // Reads every landmark's model now (at city load), so no first hit pays for the file.

        public static void PreloadModels(bool carving)
        {
            if (!carving)
            {
                return;
            }
            foreach (string id in Content.Landmarks())
            {
                _Bounds(_Model(id));
            }
        }
        // The landmark's model as cells, read once: {"xyz": x, y, z per voxel, "mats": material ids}.
        // Empty if the shape or file is missing.

        public static GDict _Model(string id)
        {
            if (_cache.Has(id))
            {
                return _cache[id];
            }
            GDict shape = Content.Landmarks().Get(id, new GDict());
            GDict @out = new GDict { { "xyz", new PackedInt32Array() }, { "mats", new PackedByteArray() } };
            var path = Gd.Str(shape.Get("kvox", ""));
            if (path != "" && FileAccess.FileExists(path))
            {
                GArray<Variant> ground = shape.Get("ground", Gd.Arr());
                @out = _Read(path, ground);
            }
            _cache[id] = @out;
            return @out;
        }
        // The first pose of a .kvox (Kvox.read's format): version 1 holds one pose, version 2 a count.

        public static GDict _Read(string path, GArray<Variant> ground)
        {
            var xyz = new PackedInt32Array();
            var mats = new PackedByteArray();
            var f = FileAccess.Open(path, FileAccess.READ);
            if ((Gd.IsNull(f) || f.GetBuffer(4).GetStringFromAscii() != MAGIC))
            {
                return new GDict { { "xyz", xyz }, { "mats", mats } };
            }
            GDict ids = MaterialIds();
            long version = f.Get32();
            long first = 0;
            if (version == 1)
            {
                first = f.Get32();
            }
            else
            {
                f.Get32();
            }
            // model height
            f.Get16();
            long voxels = (version == 1 ? first : f.Get32());
            GDict byClass = new GDict();
            // per voxel: x, y, z int16, r, g, b, face flags
            var buf = f.GetBuffer(voxels * 10);
            voxels = buf.Size() / 10;
            xyz.Resize(voxels * 3);
            mats.Resize(voxels);
            foreach (long v in Gd.Range(voxels))
            {
                long o = v * 10;
                xyz[v * 3] = buf.DecodeS16(o);
                xyz[v * 3 + 1] = buf.DecodeS16(o + 2);
                xyz[v * 3 + 2] = buf.DecodeS16(o + 4);
                var key = (((buf[o + 6] << (int)(16))) | ((buf[o + 7] << (int)(8))) | buf[o + 8]);
                if (!byClass.Has(key))
                {
                    var color = Gd.Color8(buf[o + 6], buf[o + 7], buf[o + 8]);
                    byClass[key] = Num.I(ids[MaterialOf(color, ground)]);
                }
                mats[v] = byClass[key];
            }
            return new GDict { { "xyz", xyz }, { "mats", mats } };
        }

        new void _InitFields()
        {
        }
    }
}
