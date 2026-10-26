class_name BuildingCells
extends CellGrid
## One building's fine destruction grid (D-094), made in the sim from its footprint, floors,
## tier and style: RES cells per sim unit (data/tuning.json "destruction"), one byte per cell
## (0 empty, else a data/materials.json id), x fastest, then z, then y. The layout is
## BuildingLayout's, the same one BuildingVoxels draws, so the sim and the view build the same
## grid. A window's lit or unlit look is the view's (Look), not a material: both are "window"
## here ("shop" on the ground floor, "glass" on a curtain wall).

const OFFICE := BuildingLayout.OFFICE
const BRICK := BuildingLayout.BRICK
const GLASS := BuildingLayout.GLASS
const STONE := BuildingLayout.STONE
const NEON_COUNT := BuildingLayout.NEON_COUNT
const SIGN_CHANCE := BuildingLayout.SIGN_CHANCE
## Sides, as the outward step in cells: -x, +x, -z, +z.
const SIDES := BuildingLayout.SIDES

var b: RampageSim.Building


## party: side (SIDES) -> floors of that side a touching neighbour covers (no sign hangs
## off that side), as PartyWalls.of() gives the sim and the view.
func _init(p_building: RampageSim.Building, party: Dictionary = {}) -> void:
	b = p_building
	res = cell_res()
	var ids := material_ids()
	if b.is_rail():  # a railway piece: the viaduct's own layout (RailLayout), the same grid rules
		var laid: Dictionary = RailLayout.laid(b, Content.section("rail"), res)[0]
		_pack(laid, ids)
		return
	if BuildingCellsNative.fill(self, ids, party):
		return
	_pack(BuildingLayout.new(b, res, party).cells, ids)


func archetype() -> int:
	return b.style % 4


## Empties every cell of a structural chunk (one sim unit, one floor) that is gone. The chunks
## are the view's (BuildingMesher.chunk_index): a boundary chunk also owns what stands proud of
## its face (sills, awnings, signs) and a top-floor chunk the roof gear above it, so their
## range runs on to the grid's edge.
func clear_chunk(chunk: Vector3i) -> void:
	var lo := chunk * res - offset
	var hi := lo + Vector3i.ONE * res
	var last := Vector3i(b.w, b.height, b.d) - Vector3i.ONE
	for axis: int in 3:
		if chunk[axis] == 0:
			lo[axis] = 0
		if chunk[axis] == last[axis]:
			hi[axis] = dims[axis]
	for y: int in range(maxi(lo.y, 0), mini(hi.y, dims.y)):
		for z: int in range(maxi(lo.z, 0), mini(hi.z, dims.z)):
			for x: int in range(maxi(lo.x, 0), mini(hi.x, dims.x)):
				cells[index(Vector3i(x, y, z))] = 0


## The laid cells (cell -> material key) into the packed grid, its box grown to hold every one.
func _pack(laid: Dictionary, ids: Dictionary) -> void:
	var lo := Vector3i.ZERO
	var hi := Vector3i(b.w * res - 1, b.height * res - 1, b.d * res - 1)
	for c: Vector3i in laid:
		lo = lo.min(c)
		hi = hi.max(c)
	offset = lo
	dims = hi - lo + Vector3i.ONE
	cells = PackedByteArray()
	cells.resize(dims.x * dims.y * dims.z)
	for c: Vector3i in laid:
		cells[index(c - offset)] = ids[laid[c]]
