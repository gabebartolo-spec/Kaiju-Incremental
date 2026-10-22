class_name BuildingCellsNative
extends RefCounted
## BuildingCells' grid from native/src/kaiju_cells.cpp (KaijuSettle.cells, b2-3 part 4), which is
## BuildingLayout's GDScript (sim/building_layout.gd) cell for cell at a fraction of the cost; the
## GDScript stays the reference (tests/lib/cells_native.gd builds both, VoxelSupport.use_native
## off for the GDScript).

## The material keys the native generator marks, in its order; neon0.. follow.
const KEYS: Array[String] = [
	"wall",
	"pillar",
	"trim",
	"band",
	"awning",
	"shop",
	"mullion",
	"window",
	"spandrel",
	"frame",
	"glass",
	"rail",
	"sill",
	"slab",
	"roof",
	"vent",
	"gear",
	"pipe",
	"tank",
	"beacon",
	"sign_frame",
]


## Fills g's offset, dims and cells natively; false (g untouched) when the extension is not loaded
## or switched off. ids: material name -> id; party: as BuildingCells'.
static func fill(g: BuildingCells, ids: Dictionary, party: Dictionary) -> bool:
	var nat := VoxelSupport.native()
	if nat == null or not nat.has_method("cells"):
		return false
	var b := g.b
	var sides := 0
	for i: int in BuildingCells.SIDES.size():
		sides |= (1 << i) if party.has(BuildingCells.SIDES[i]) else 0
	var bay := Num.i(Content.section("destruction").get("column_bay", 0))
	var ints := PackedInt32Array(
		[b.w, b.d, b.height, g.res, b.style, b.tier, bay, sides, BuildingCells.NEON_COUNT]
	)
	var key_ids := PackedInt32Array()
	for key: String in KEYS:
		key_ids.append(Num.i(ids.get(key, 0)))
	for i: int in BuildingCells.NEON_COUNT:
		key_ids.append(Num.i(ids.get("neon%d" % i, 0)))
	var nums := PackedFloat64Array([b.x, b.z, BuildingCells.SIGN_CHANCE])
	var got: Array = nat.call("cells", ints, nums, key_ids)
	if got.is_empty():
		return false
	g.offset = got[0]
	g.dims = got[1]
	g.cells = got[2]
	return true
