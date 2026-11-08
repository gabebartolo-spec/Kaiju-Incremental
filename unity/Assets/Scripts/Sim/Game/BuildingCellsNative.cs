// Generated from sim/building_cells_native.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BuildingCellsNative : RefCounted
    {
        public static implicit operator BuildingCellsNative(Variant v) => (BuildingCellsNative)v.Obj;

        // BuildingCells' grid from native/src/kaiju_cells.cpp (KaijuSettle.cells, b2-3 part 4), which is
        // BuildingLayout's GDScript (sim/building_layout.gd) cell for cell at a fraction of the cost; the
        // GDScript stays the reference (tests/lib/cells_native.gd builds both, VoxelSupport.use_native
        // off for the GDScript).
        // The material keys the native generator marks, in its order; neon0.. follow.
        public static readonly GArray<string> KEYS = new GArray<string> { "wall", "pillar", "trim", "band", "awning", "shop", "mullion", "window", "spandrel", "frame", "glass", "rail", "sill", "slab", "roof", "vent", "gear", "pipe", "tank", "beacon", "sign_frame", "heater", "heater_hi", "solar" };
        // Fills g's offset, dims and cells natively; false (g untouched) when the extension is not loaded
        // or switched off. ids: material name -> id; party: as BuildingCells'.

        public static bool Fill(BuildingCells g, GDict ids, GDict party)
        {
            var nat = VoxelSupport.Native();
            if ((nat == null || !nat.HasMethod("cells")))
            {
                return false;
            }
            var b = g.b;
            long sides = 0;
            foreach (long i in Gd.Range(BuildingCells.SIDES.Size()))
            {
                sides |= (party.Has(BuildingCells.SIDES[i]) ? ((1L << (int)(i))) : 0);
            }
            long bay = Num.I(Content.Section("destruction").Get("column_bay", 0));
            var ints = new PackedInt32Array(Gd.Arr(b.w, b.d, b.height, g.res, b.style, b.tier, bay, sides, BuildingCells.NEON_COUNT));
            var keyIds = new PackedInt32Array();
            foreach (string key in KEYS)
            {
                keyIds.Append(Num.I(ids.Get(key, 0)));
            }
            foreach (long i in Gd.Range(BuildingCells.NEON_COUNT))
            {
                keyIds.Append(Num.I(ids.Get(Gd.Format("neon%d", i), 0)));
            }
            var nums = new PackedFloat64Array(Gd.Arr(b.x, b.z, BuildingCells.SIGN_CHANCE));
            GArray<Variant> got = nat.Call("cells", ints, nums, keyIds);
            if (got.IsEmpty())
            {
                return false;
            }
            g.offset = got[0];
            g.dims = got[1];
            g.cells = got[2];
            return true;
        }

        void _InitFields()
        {
        }
        public BuildingCellsNative() { _InitFields(); }
    }
}
