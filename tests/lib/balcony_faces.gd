extends RefCounted
## Face helpers for tests/run_cell_mesh_tests.gd: the faces of a standing building's shell that look
## at a floor slab outside the hollow (a brick balcony, which the baked view keeps in its hidden
## slab mesh), and which of a shell's faces nothing drawn covers. Faces are keyed by their
## centre on a 1/1024 m grid.


## A face's centre: the cell's centre, half a voxel out along `d`.
static func key(voxels: BuildingVoxels, cell: Vector3i, d: Vector3i) -> Vector3i:
	var half := BuildingVoxels.VOXEL * 0.5
	var at := voxels.origin() + Vector3(0, half, 0) + Vector3(cell) * BuildingVoxels.VOXEL
	return Vector3i(((at + Vector3(d) * half) * 1024.0).round())


## The centres of a baked mesh's quads.
static func quad_keys(mesh: ArrayMesh) -> Dictionary:
	var out := {}
	if mesh.get_surface_count() == 0:
		return out
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for q: int in range(0, verts.size(), 4):
		var centre := (verts[q] + verts[q + 1] + verts[q + 2] + verts[q + 3]) * 0.25
		out[Vector3i((centre * 1024.0).round())] = true
	return out


## Faces of the shell's cells that look at a floor slab outside the hollow.
static func behind(voxels: BuildingVoxels, baked: BuildingMesher) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cells: Dictionary = voxels.vox.cells
	for cell: Vector3i in cells:
		if cells[cell] == "slab":
			continue
		for d: Vector3i in BuildingMesher.NEIGHBOURS:
			var o := cell + d
			if cells.get(o, "") == "slab" and not baked._inside(o):
				out.append(key(voxels, cell, d))
	return out


## How many faces of the shell's cells are not drawn although only a floor slab outside the
## hollow (hidden while the building stands) covers them: a see-through strip.
static func hidden(voxels: BuildingVoxels, baked: BuildingMesher) -> int:
	var cells: Dictionary = voxels.vox.cells
	var drawn := quad_keys(baked.shell)
	var n := 0
	for cell: Vector3i in cells:
		if cells[cell] == "slab":
			continue
		for d: Vector3i in BuildingMesher.NEIGHBOURS:
			var o := cell + d
			if drawn.has(key(voxels, cell, d)):
				continue
			var covered := o.y < 0 or baked._inside(o) or (cells.has(o) and cells[o] != "slab")
			if not covered:
				n += 1
	return n
