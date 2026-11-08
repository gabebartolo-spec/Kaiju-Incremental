// Generated from sim/building_cells.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BuildingCells : CellGrid
    {
        public static implicit operator BuildingCells(Variant v) => (BuildingCells)v.Obj;

        // One building's fine destruction grid (D-094), made in the sim from its footprint, floors,
        // tier and style: RES cells per sim unit (data/tuning.json "destruction"), one byte per cell
        // (0 empty, else a data/materials.json id), x fastest, then z, then y. The layout is
        // BuildingLayout's, the same one BuildingVoxels draws, so the sim and the view build the same
        // grid. A window's lit or unlit look is the view's (Look), not a material: both are "window"
        // here ("shop" on the ground floor, "glass" on a curtain wall).
        public const long OFFICE = BuildingLayout.OFFICE;
        public const long BRICK = BuildingLayout.BRICK;
        public const long GLASS = BuildingLayout.GLASS;
        public const long STONE = BuildingLayout.STONE;
        public const long NEON_COUNT = BuildingLayout.NEON_COUNT;
        public const double SIGN_CHANCE = BuildingLayout.SIGN_CHANCE;
        // Sides, as the outward step in cells: -x, +x, -z, +z.
        public static readonly GArray<Vector2i> SIDES = BuildingLayout.SIDES;
        public RampageSim.Building b;
        // party: side (SIDES) -> floors of that side a touching neighbour covers (no sign hangs
        // off that side), as PartyWalls.of() gives the sim and the view.

        public BuildingCells(RampageSim.Building pBuilding, GDict party)
        {
            _InitFields();
            b = pBuilding;
            res = CellRes();
            GDict ids = MaterialIds();
            // a railway piece: the viaduct's own layout (RailLayout), the same grid rules
            if (b.IsRail())
            {
                GDict laid = RailLayout.Laid(b, Content.Section("rail"), res)[0];
                _Pack(laid, ids);
                return;
            }
            // a river bridge's piece: BridgeLayout's deck, parapets and piers
            if (b.IsBridge())
            {
                GDict deck = BridgeLayout.Laid(b, Content.Section("bridge"), res)[0];
                _Pack(deck, ids);
                return;
            }
            if (BuildingCellsNative.Fill(this, ids, party))
            {
                return;
            }
            _Pack(new BuildingLayout(b, res, party).cells, ids);
        }
        public BuildingCells(RampageSim.Building pBuilding) : this(pBuilding, new GDict()) { }

        public long Archetype()
        {
            return b.style % 4;
        }
        // Empties every cell of a structural chunk (one sim unit, one floor) that is gone. The chunks
        // are the view's (BuildingMesher.chunk_index): a boundary chunk also owns what stands proud of
        // its face (sills, awnings, signs) and a top-floor chunk the roof gear above it, so their
        // range runs on to the grid's edge.

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
        // The laid cells (cell -> material key) into the packed grid, its box grown to hold every one.

        public void _Pack(GDict laid, GDict ids)
        {
            var lo = Vector3i.ZERO;
            var hi = new Vector3i(b.w * res - 1, b.height * res - 1, b.d * res - 1);
            foreach (Vector3i c in laid)
            {
                lo = lo.Min(c);
                hi = hi.Max(c);
            }
            offset = lo;
            dims = hi - lo + Vector3i.ONE;
            cells = new PackedByteArray();
            cells.Resize(dims.x * dims.y * dims.z);
            foreach (Vector3i c in laid)
            {
                cells[Index(c - offset)] = ids[laid[c]];
            }
        }

        new void _InitFields()
        {
        }
    }
}
