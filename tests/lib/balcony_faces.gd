extends RefCounted
## Face helpers for tests/run_cell_mesh_tests.gd: the faces of a standing building's shell that look
## at a floor slab outside the hollow (a brick balcony, which the baked view never draws, D-289),
## and which of a shell's faces nothing drawn covers. Faces are keyed by their centre on a
## 1/1024 m grid.


## A face's centre: the cell's centre, half a voxel out along `d`.
static func key(voxels: BuildingVoxels, cell: Vector3i, d: Vector3i) -> Vector3i:
	var half := BuildingVoxels.VOXEL * 0.5
	var at := voxels.origin() + Vector3(0, half, 0) + Vector3(cell) * BuildingVoxels.VOXEL
	return Vector3i(((at + Vector3(d) * half) * 1024.0).round())


## The centres of a baked mesh's voxel faces (a merged quad split back into its voxels).
static func quad_keys(mesh: ArrayMesh) -> Dictionary:
	var out := {}
	if mesh.get_surface_count() == 0:
		return out
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var size := BuildingVoxels.VOXEL
	for q: int in range(0, verts.size(), 4):
		var u := verts[q + 1] - verts[q]
		var v := verts[q + 3] - verts[q]
		var nu := roundi(u.length() / size)
		var nv := roundi(v.length() / size)
		for i: int in nu:
			for j: int in nv:
				var centre := verts[q] + u * ((i + 0.5) / nu) + v * ((j + 0.5) / nv)
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
			var covered: bool = o.y < 0 or baked._inside(o) or (cells.has(o) and cells[o] != "slab")
			if not covered:
				n += 1
	return n
