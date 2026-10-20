extends RefCounted
## Face-set helpers for tests/run_cell_mesh_tests.gd (CellMesher, D-094 WP4): carving a grid as
## KaijuCarve does, collecting a mesh's faces, counting a grid's solid-air boundaries.


## Empties every cell whose centre is in the sphere (KaijuCarve's rule); returns the box it
## touched as [lo, hi].
static func carve(
	cells: PackedByteArray, dims: Vector3i, centre: Vector3, radius: float
) -> Array[Vector3i]:
	var lo := Vector3i(
		floori(centre.x - radius), floori(centre.y - radius), floori(centre.z - radius)
	)
	var hi := Vector3i(ceili(centre.x + radius), ceili(centre.y + radius), ceili(centre.z + radius))
	lo = lo.max(Vector3i.ZERO)
	hi = hi.min(dims - Vector3i.ONE)
	for y: int in range(lo.y, hi.y + 1):
		for z: int in range(lo.z, hi.z + 1):
			for x: int in range(lo.x, hi.x + 1):
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5) - centre
				if p.length_squared() <= radius * radius:
					cells[x + z * dims.x + y * dims.x * dims.z] = 0
	return [lo, hi] as Array[Vector3i]


## Face key -> colour, for every quad of these arrays (key: first corner on a 1/64 grid, normal).
static func faces(arrays: Array, into: Dictionary) -> void:
	var verts: PackedVector3Array = arrays[0]
	var normals: PackedVector3Array = arrays[1]
	var colors: PackedColorArray = arrays[2]
	for q: int in range(0, verts.size(), 4):
		into[[Vector3i((verts[q] * 64.0).round()), Vector3i(normals[q])]] = colors[q]


static func colour(face_map: Dictionary, key: Array) -> Color:
	var c: Color = face_map[key]
	return c


## A baked mesh stores vertex colour in 8 bits a channel (truncated, clamped to 1): one step
## apart at most once clamped, as the GPU sees both.
static func same_colour(raw: Color, b: Color) -> bool:
	var a := raw.clamp()
	var e := 1.0 / 255.0
	return (
		absf(a.r - b.r) <= e
		and absf(a.g - b.g) <= e
		and absf(a.b - b.b) <= e
		and absf(a.a - b.a) <= e
	)


static func mesh_faces(mesh: ArrayMesh, into: Dictionary) -> void:
	if mesh != null and mesh.get_surface_count() > 0:
		var a := mesh.surface_get_arrays(0)
		faces(
			[a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_COLOR], a[Mesh.ARRAY_INDEX]],
			into
		)


static func cell_faces(m: CellMesher, cells: PackedByteArray) -> Dictionary:
	var out := {}
	for r: Vector3i in m.all_regions():
		faces(m.mesh_region(cells, r), out)
	return out


static func solid(cells: PackedByteArray) -> int:
	return cells.size() - cells.count(0)


## Solid-to-air boundaries of a grid (each must be exactly one drawn face).
static func boundaries(m: CellMesher, cells: PackedByteArray) -> int:
	var dims := m.dims
	var n := 0
	for i: int in cells.size():
		if cells[i] == 0:
			continue
		var c := Vector3i(i % dims.x, i / (dims.x * dims.z), (i / dims.x) % dims.z)
		for d: Vector3i in CellMesher.NEIGHBOURS:
			var o := c + d
			if o.y + m.offset.y < 0:
				continue
			if o.x < 0 or o.y < 0 or o.z < 0 or o.x >= dims.x or o.y >= dims.y or o.z >= dims.z:
				n += 1
			elif cells[o.x + o.z * dims.x + o.y * dims.x * dims.z] == 0:
				n += 1
	return n
