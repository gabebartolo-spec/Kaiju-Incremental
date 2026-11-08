// Generated from sim/hazard_cells.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class HazardCells : CellGrid
    {
        public static implicit operator HazardCells(Variant v) => (HazardCells)v.Obj;

        // A red-barrel site's fine destruction grid (D-094; director comments #19): HazardShape's cells
        // as material ids, on the grid BuildingCells uses, so the carved site is the model the view drew
        // (HazardVoxels). A top-floor chunk also owns what stands on the roof, and a boundary chunk what
        // stands proud of its face, as BuildingCells.clear_chunk has it. Pure sim.
        public RampageSim.Building b;

        public HazardCells(RampageSim.Building pBuilding)
        {
            _InitFields();
            b = pBuilding;
            res = CellRes();
            GDict ids = MaterialIds();
            GDict shape = HazardShape.Cells(b, res);
            var lo = Vector3i.ZERO;
            var hi = new Vector3i(b.w * res - 1, b.height * res - 1, b.d * res - 1);
            foreach (Vector3i c in shape)
            {
                lo = lo.Min(c);
                hi = hi.Max(c);
            }
            offset = lo;
            dims = hi - lo + Vector3i.ONE;
            cells = new PackedByteArray();
            cells.Resize(dims.x * dims.y * dims.z);
            foreach (Vector3i c in shape)
            {
                cells[Index(c - offset)] = Num.I(ids[shape[c]]);
            }
        }

        public override void ClearChunk(Vector3i chunk)
        {
            var lo = chunk * res - offset;
            var hi = lo + Vector3i.ONE * res;
            var last = new Vector3i(b.w, b.height, b.d) - Vector3i.ONE;
            foreach (long axis in Gd.Range(3))
            {
                if (chunk[axis] == 0)
                {
                    lo[axis] = 0;
                }
                if (chunk[axis] == last[axis])
                {
                    hi[axis] = dims[axis];
                }
            }
            foreach (long y in Gd.Range(Gd.Maxi(lo.y, 0), Gd.Mini(hi.y, dims.y)))
            {
                foreach (long z in Gd.Range(Gd.Maxi(lo.z, 0), Gd.Mini(hi.z, dims.z)))
                {
                    foreach (long x in Gd.Range(Gd.Maxi(lo.x, 0), Gd.Mini(hi.x, dims.x)))
                    {
                        cells[Index(new Vector3i(x, y, z))] = 0;
                    }
                }
            }
        }

        new void _InitFields()
        {
        }
    }
}
