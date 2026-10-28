extends RefCounted
## Fixture helpers for tests/run_cell_mesh_tests.gd (split out of it to keep files small): a
## fixture's building, and the blocks a cell view shows stale.


## The building of fixture `f` ([name, x, z, w, d, floors, tier, style, party]).
static func building(f: Array) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = f[1]
	b.z = f[2]
	b.w = f[3]
	b.d = f[4]
	b.height = f[5]
	b.tier = f[6]
	b.style = f[7]
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	return b


## Blocks whose shown mesh is not a fresh mesh of `cells`.
static func stale_blocks(m: CellMesher, view: CellView, cells: PackedByteArray) -> int:
	var off := 0
	var drawn := m.drawn(cells)  # what a CellView draws of the grid (no proud balcony slab)
	for r: Vector3i in m.all_regions():
		var fresh := m.mesh_region(drawn, r)
		var shown: Array = view.arrays.get(r, [])
		if shown.is_empty() or CellMesher.digest(shown) != CellMesher.digest(fresh):
			off += 1
		var fresh_verts: PackedVector3Array = fresh[0]
		if view.parts.has(r) != (fresh_verts.size() > 0):
			off += 1
	return off
