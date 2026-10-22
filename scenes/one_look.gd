class_name OneLook
extends RefCounted
## Look-boards mock (capture-only branch, not for merge): a prop built at the city's block size.
## refine() takes a VoxelBuilder filled at the old prop grain and returns it rebuilt at twice the
## cells per axis (the same footprint and height, so the world size never changes), then rounds
## the convex corners of any part at least three cells thick. Presentation only.

const AXES: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.UP, Vector3i.BACK]


static func refine(src: VoxelBuilder) -> VoxelBuilder:
	var up := VoxelBuilder.new()
	up.salt = src.salt
	for cell: Vector3i in src.cells:
		var key := src.key_at(cell)
		var base := cell * 2
		for dx: int in 2:
			for dy: int in 2:
				for dz: int in 2:
					up.put(base + Vector3i(dx, dy, dz), key)
	_round(up)
	return up


## Removes every cell that is a convex corner (one side open on each axis) of a part three or
## more cells thick on all three axes: boxes get chamfered edges, crowns go round.
static func _round(v: VoxelBuilder) -> void:
	var drop: Array[Vector3i] = []
	for cell: Vector3i in v.cells:
		if _corner(v, cell):
			drop.append(cell)
	for cell: Vector3i in drop:
		v.cells.erase(cell)


static func _corner(v: VoxelBuilder, cell: Vector3i) -> bool:
	for axis: Vector3i in AXES:
		var minus := v.has(cell - axis)
		var plus := v.has(cell + axis)
		if minus == plus:
			return false
		var inward := axis if plus else -axis  # the side that is filled: it must be thick
		if not v.has(cell + inward * 2):
			return false
	return true
