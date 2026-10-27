extends RefCounted
## Helpers for tests/run_facade_tests.gd: the faces of a BuildingView the player can see from
## outside the building, as building_baked.gdshader draws them (the view's visible meshes, minus
## what the `alive` texture switches off).


## The air cells reachable from beyond the building's box through cells that hold nothing
## (voxel cells of BuildingVoxels, building-local). A face looks "outside" when its neighbour
## is one.
static func outside_air(all: Dictionary) -> Dictionary:
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := Vector3i(-(1 << 20), -(1 << 20), -(1 << 20))
	for c: Vector3i in all:
		lo = lo.min(c)
		hi = hi.max(c)
	lo -= Vector3i.ONE
	hi += Vector3i.ONE
	var seen := {lo: true}
	var stack: Array[Vector3i] = [lo]
	while not stack.is_empty():
		var c: Vector3i = stack.pop_back()
		for d: Vector3i in BuildingMesher.NEIGHBOURS:
			var n := c + d
			if n.x < lo.x or n.y < lo.y or n.z < lo.z or n.x > hi.x or n.y > hi.y or n.z > hi.z:
				continue
			if seen.has(n) or all.has(n):
				continue
			seen[n] = true
			stack.append(n)
	return seen


## Every face of the view's mesh `node` that is shown and that the shader draws, as
## {"key": [first corner on a 1/64 grid, normal], "cell": the solid cell, "normal": Vector3i,
## "floor": its chunk row}. The shader's rule is replayed on the CPU: a face is gone when its
## chunk's alive share (the image the node's material reads) is below 0.02 or under its
## voxel's hash.
static func drawn(view: BuildingView, node: MeshInstance3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not node.visible or node.mesh == null or node.mesh.get_surface_count() == 0:
		return out
	var alive := _alive_of(view, node)
	var half := BuildingVoxels.VOXEL * 0.5
	var origin := view.voxels.origin() + Vector3(0, half, 0)
	var per_floor := view.b.w * view.b.d
	var arrays := node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for q: int in range(0, verts.size(), 4):
		var chunk := int(uv2[q].x + 0.5)
		var state := alive.get_pixel(chunk, 0).r
		if state < 0.02 or uv2[q].y < 1.0 - state:
			continue
		var nf := normals[q]
		var centre := (verts[q] + verts[q + 1] + verts[q + 2] + verts[q + 3]) * 0.25
		out.append(
			{
				"key": [Vector3i((verts[q] * 64.0).round()), Vector3i(nf)],
				"cell": Vector3i(((centre - nf * half - origin) / BuildingVoxels.VOXEL).round()),
				"normal": Vector3i(nf.round()),
				"floor": floori(float(chunk) / per_floor)
			}
		)
	return out


## The alive image the node's material reads: the floors have their own once the building is hit.
static func _alive_of(view: BuildingView, node: MeshInstance3D) -> Image:
	var floors: Variant = view.get("_slab_alive")  # none before the first blow
	if node == view._slabs and floors is Image:
		return floors
	return view._alive


## Face key -> the floor (chunk row) of every face the view draws that looks at outside air.
static func seen_from_outside(view: BuildingView) -> Dictionary:
	var out := {}
	var outside := outside_air(view.voxels.vox.cells)
	for node: MeshInstance3D in [view._shell, view._slabs]:
		for face: Dictionary in drawn(view, node):
			var cell: Vector3i = face["cell"]
			var normal: Vector3i = face["normal"]
			if outside.has(cell + normal):
				out[face["key"]] = face["floor"]
	return out


## How many faces of the hidden floors the view draws on floor `from` or higher.
static func floors_drawn_from(view: BuildingView, from: int) -> int:
	var n := 0
	for face: Dictionary in drawn(view, view._slabs):
		if Num.i(face["floor"]) >= from:
			n += 1
	return n


## How many faces are in exactly one of the two sets and sit on floor `from` or higher.
static func changed_from_floor(before: Dictionary, after: Dictionary, from: int) -> int:
	var n := 0
	for key: Array in before:
		if Num.i(before[key]) >= from and not after.has(key):
			n += 1
	for key: Array in after:
		if Num.i(after[key]) >= from and not before.has(key):
			n += 1
	return n
