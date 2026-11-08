// Generated from sim/cell_grid.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CellGrid : RefCounted
    {
        public static implicit operator CellGrid(Variant v) => (CellGrid)v.Obj;

        // The fine destruction grid of one building or landmark (D-094): RES cells per sim unit
        // (data/tuning.json "destruction"), one byte per cell (0 empty, else a data/materials.json id),
        // x fastest, then z, then y. BuildingCells makes one from a generated facade, LandmarkCells from a
        // baked landmark model; both are read the same way. Pure sim.
        // Cells per sim unit.
        public long res;
        // Grid size in cells.
        public Vector3i dims;
        // The building-local cell (BuildingVoxels' coordinates) of grid cell (0, 0, 0): the grid also
        // holds what stands proud of the footprint (sills, awnings, signs) and the roof gear.
        public Vector3i offset;
        // One byte per cell, index x + z * dims.x + y * dims.x * dims.z.
        public PackedByteArray cells = new PackedByteArray();
        // Cells per sim unit, from data/tuning.json.

        public static long CellRes()
        {
            return Num.I(Content.Section("destruction").Get("res", 0));
        }
        // Material name -> id (data/materials.json).

        public static GDict MaterialIds()
        {
            GDict @out = new GDict();
            foreach (GDict m in Content.Materials())
            {
                @out[Gd.Str(m["name"])] = Num.I(m["id"]);
            }
            return @out;
        }

        public long Index(Vector3i c)
        {
            return c.x + c.z * dims.x + c.y * dims.x * dims.z;
        }
        // The material at a building-local cell (BuildingVoxels' coordinates); 0 outside the grid.

        public long At(Vector3i local)
        {
            var c = local - offset;
            if ((c.x < 0 || c.y < 0 || c.z < 0 || c.x >= dims.x || c.y >= dims.y || c.z >= dims.z))
            {
                return 0;
            }
            return cells[Index(c)];
        }
        // Cells that are not empty.

        public long Count()
        {
            return cells.Size() - cells.Count(0);
        }
        // Empties every cell of a structural chunk (one sim unit, one floor) that is gone.

        public virtual void ClearChunk(Vector3i chunk)
        {
            _ClearRows(chunk);
        }
        // Empties a chunk's cells and returns how many were standing. Row by row on the flat index: a
        // landmark's promote clears thousands of chunks in one step (the wheel took 1.75 s through
        // clear_cell, docs/research/2026-10-31-cpu-profile.md).

        public long _ClearRows(Vector3i chunk)
        {
            long lost = 0;
            var lo = chunk * res - offset;
            long x0 = Gd.Maxi(lo.x, 0);
            long x1 = Gd.Mini(lo.x + res, dims.x);
            foreach (long y in Gd.Range(Gd.Maxi(lo.y, 0), Gd.Mini(lo.y + res, dims.y)))
            {
                foreach (long z in Gd.Range(Gd.Maxi(lo.z, 0), Gd.Mini(lo.z + res, dims.z)))
                {
                    long row = z * dims.x + y * dims.x * dims.z;
                    foreach (long x in Gd.Range(x0, x1))
                    {
                        if (cells[row + x] != 0)
                        {
                            cells[row + x] = 0;
                            lost += 1;
                        }
                    }
                }
            }
            return lost;
        }
        // Empties one building-local cell (a no-op outside the grid or on an empty cell).

        public virtual void ClearCell(Vector3i local)
        {
            var c = local - offset;
            if ((c.x < 0 || c.y < 0 || c.z < 0 || c.x >= dims.x || c.y >= dims.y || c.z >= dims.z))
            {
                return;
            }
            cells[Index(c)] = 0;
        }

        void _InitFields()
        {
        }
        public CellGrid() { _InitFields(); }
    }
}
