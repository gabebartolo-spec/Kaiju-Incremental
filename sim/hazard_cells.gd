class_name HazardCells
extends CellGrid
## A red-barrel site's fine destruction grid (D-094; director comments #19): HazardShape's cells
## as material ids, on the grid BuildingCells uses, so the carved site is the model the view drew
## (HazardVoxels). A top-floor chunk also owns what stands on the roof, and a boundary chunk what
## stands proud of its face, as BuildingCells.clear_chunk has it. Pure sim.

var b: RampageSim.Building


func _init(p_building: RampageSim.Building) -> void:
	b = p_building
	res = cell_res()
	var ids := material_ids()
	var shape := HazardShape.cells(b, res)
	var lo := Vector3i.ZERO
	var hi := Vector3i(b.w * res - 1, b.height * res - 1, b.d * res - 1)
	for c: Vector3i in shape:
		lo = lo.min(c)
		hi = hi.max(c)
	offset = lo
	dims = hi - lo + Vector3i.ONE
	cells = PackedByteArray()
	cells.resize(dims.x * dims.y * dims.z)
	for c: Vector3i in shape:
		cells[index(c - offset)] = Num.i(ids[shape[c]])


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
