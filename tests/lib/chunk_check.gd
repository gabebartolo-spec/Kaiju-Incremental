extends RefCounted
## His death breaks into jagged stone chunks, never boxes (director 2026-10-27, D-323, on #240's
## clip: "the bllocks are stupid and look bad"; asked what should fly out: "Jagged stone chunks",
## irregular broken rock, many sizes). The cube test for one mesh (boxy), the planted boxes it must
## catch (planted), and the check of a death in flight (check_view): every piece is a mesh that
## passes the cube test, and the pieces' sizes spread at least SPREAD_MIN to 1.

## Triangles whose normals are within FACE_DEG of each other are one face of the mesh.
const FACE_DEG := 8.0
## A face within AXIS_DEG of a direction (either way) faces along it.
const AXIS_DEG := 10.0
## A chunk has at least FACES_MIN faces (a box has 6).
const FACES_MIN := 8
## At most this share of a chunk's area may face along its own axes (a box: all of it)...
const AXIS_SHARE_MAX := 0.5
## ...or along any three square directions (a box at any turn).
const BOX_SHARE_MAX := 0.75
## The biggest piece of one death is at least this many times the smallest (longest sides).
const SPREAD_MIN := 4.0


## Why `mesh` is box-like, or "" for a jagged chunk.
static func boxy(mesh: Mesh) -> String:
	if mesh == null:
		return "no mesh"
	var faces := _faces(mesh)
	if faces.size() < FACES_MIN:
		return "%d faces (a chunk has %d or more)" % [faces.size(), FACES_MIN]
	var own: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var square := _share(faces, own)
	if square >= AXIS_SHARE_MAX:
		return "%.0f%% of its area faces along its own axes" % (square * 100.0)
	var turned := _share(faces, _box_axes(faces))
	if turned >= BOX_SHARE_MAX:
		return "%.0f%% of its area faces along three square directions" % (turned * 100.0)
	return ""


## Boxes the test must catch, by what catches each: a plain cube (6 faces), a cube with two
## slivers knocked off a corner (8 faces, square to its axes) and that one turned (a turned box).
static func planted() -> Dictionary:
	var tris := PackedVector3Array()
	var box := BoxMesh.new()
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in arrays[Mesh.ARRAY_INDEX]:
		tris.append(verts[i])
	var c := Vector3(0.5, 0.5, 0.5)
	var sliver := PackedVector3Array([c, c + Vector3(-0.05, 0, 0.02), c + Vector3(0, -0.05, 0.03)])
	tris.append_array(sliver)
	sliver = PackedVector3Array([c, c + Vector3(0.02, -0.05, 0), c + Vector3(0, 0.03, -0.05)])
	tris.append_array(sliver)
	var turn := Basis(Vector3(1, 2, 3).normalized(), 0.7)
	var turned := PackedVector3Array()
	for v: Vector3 in tris:
		turned.append(turn * v)
	return {"faces": box, "own axes": _mesh(tris), "three square directions": _mesh(turned)}


## His death in flight (DeathView, at the burst): every piece a jagged chunk, sizes spread. The
## sizes are the pieces' own (DeathChunks.size, the longest side each is drawn at: its mesh's
## longest side is 1), not read back from the MultiMesh: headless, the renderer keeps no transforms.
static func check_view(view: Node, check_fn: Callable) -> void:
	var bad: Array[String] = []
	var lo := INF
	var hi := 0.0
	var count := 0
	for node: MultiMeshInstance3D in _multis(view):
		var mesh := node.multimesh.mesh
		var why := "a BoxMesh" if mesh is BoxMesh else boxy(mesh)
		var side := mesh.get_aabb().get_longest_axis_size() if mesh != null else 0.0
		if why == "" and absf(side - 1.0) > 0.02:
			why = "longest side %.3f, not 1 (its size would be wrong)" % side
		if why != "":
			bad.append("%s: %s" % [node.get_path(), why])
	for group: Node in view.get_children():
		if group is DeathChunks:
			for s: float in (group as DeathChunks).size:
				lo = minf(lo, s)
				hi = maxf(hi, s)
				count += 1
	var meshes := _multis(view).size()
	print("his death's chunks: %d pieces of %d meshes, sizes %.3f..%.3f" % [count, meshes, lo, hi])
	check_fn.call(bad.is_empty(), "every piece of his death is a jagged chunk: %s" % [bad])
	check_fn.call(
		count > 0 and hi >= lo * SPREAD_MIN,
		(
			"his chunks' sizes spread at least %.0f to 1: %.3f..%.3f (%.1f to 1) over %d"
			% [SPREAD_MIN, lo, hi, hi / maxf(lo, 0.0001), count]
		)
	)


## The mesh's faces: [normal, area] per group of triangles facing within FACE_DEG of each other.
static func _faces(mesh: Mesh) -> Array[Array]:
	var out: Array[Array] = []
	var same := cos(deg_to_rad(FACE_DEG))
	for s: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index := PackedInt32Array(range(verts.size()))  # no index: the triangles in order
		if arrays[Mesh.ARRAY_INDEX] != null:
			index = arrays[Mesh.ARRAY_INDEX]
		for t: int in range(0, index.size() - 2, 3):
			var a := verts[index[t]]
			var cross := (verts[index[t + 1]] - a).cross(verts[index[t + 2]] - a)
			var area := cross.length() * 0.5
			if area > 0.0:
				_add_face(out, cross.normalized(), area, same)
	return out


static func _add_face(faces: Array[Array], n: Vector3, area: float, same: float) -> void:
	for f: Array in faces:
		var at: Vector3 = f[0]
		if at.normalized().dot(n) >= same:
			f[0] = at + n * area
			f[1] = Num.f(f[1]) + area
			return
	faces.append([n * area, area])


## The share of the area whose faces face along one of `axes` (either way).
static func _share(faces: Array[Array], axes: Array[Vector3]) -> float:
	var along := cos(deg_to_rad(AXIS_DEG))
	var total := 0.0
	var hit := 0.0
	for f: Array in faces:
		var n: Vector3 = f[0]
		var area := Num.f(f[1])
		total += area
		for axis: Vector3 in axes:
			if absf(n.normalized().dot(axis)) >= along:
				hit += area
				break
	return hit / total if total > 0.0 else 0.0


## The three square directions a turned box would face along: its biggest face, the biggest face
## square to that, and the one square to both.
static func _box_axes(faces: Array[Array]) -> Array[Vector3]:
	var ranked := faces.duplicate()
	ranked.sort_custom(func(x: Array, y: Array) -> bool: return Num.f(x[1]) > Num.f(y[1]))
	var first: Vector3 = ranked[0][0]
	var a := first.normalized()
	var square := sin(deg_to_rad(AXIS_DEG))
	for f: Array in ranked:
		var n: Vector3 = f[0]
		if absf(n.normalized().dot(a)) <= square:
			var b := (n.normalized() - a * a.dot(n.normalized())).normalized()
			return [a, b, a.cross(b)]
	return [a]


static func _mesh(tris: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = tris
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _multis(root: Node) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for child: Node in root.get_children():
		if child is MultiMeshInstance3D:
			out.append(child as MultiMeshInstance3D)
		out.append_array(_multis(child))
	return out
