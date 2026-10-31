class_name BuildingMesher
extends RefCounted
## Bakes a building's voxels (BuildingVoxels) into meshes of only the faces that can be seen.
## The building's hollow inside counts as solid while it stands, so the inner faces of its
## walls are never drawn; the floor slabs bake into a second mesh that is shown only once the
## building is broken open; a slab proud of the walls (a balcony floor) is in neither mesh, so a
## first blow changes only what it breaks (D-289). Every vertex carries its structural chunk (UV2.x)
## for building_baked.gdshader, its corner AO and material finish (UV, VoxelAO) and its voxel's
## palette colour; faces of one chunk, colour and finish whose four AO corners are all one level
## merge into one quad (greedy, per plane), and the shader rebuilds each voxel's colour jitter and
## bite hash from the fragment's cell (voxel_merged), so the look stays per voxel. A few voxels
## per chunk are kept as samples for the debris a broken chunk throws.
## The bake is pure data, safe on a worker thread; the meshes are made on the main thread (shell,
## slabs).

const NEIGHBOURS: Array[Vector3i] = [
	Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK
]
const SAMPLES_PER_CHUNK := 12

## The shell (walls, windows, roof, gear) and the hidden floor slabs, made from the baked arrays
## the first time the main thread asks (a worker only bakes the arrays: ThreadCheck).
var shell: ArrayMesh:
	get:
		if _shell == null:
			_shell = mesh_of(_shell_arrays)
			_shell_arrays = []
		return _shell
var slabs: ArrayMesh:
	get:
		if _slabs == null:
			_slabs = mesh_of(_slab_arrays)
			_slab_arrays = []
		return _slabs
## Chunk index -> [PackedVector3Array positions, PackedColorArray colours] (debris sources;
## parts_of).
var samples: Dictionary = {}

var _shell: ArrayMesh
var _slabs: ArrayMesh
var _shell_arrays: Array = []
var _slab_arrays: Array = []
var _v: BuildingVoxels  # only while baking: a kept mesher must not hold the voxels
var _b: RampageSim.Building
var _res: int
var _w: int
var _d: int
var _h: int
# Only while baking (cleared after: the mesher is kept): the cells that hide a face (_bake's
# `all`), each palette key's
# finish (VoxelAO), per NEIGHBOURS direction the face's corner vectors and AO ring, the cell
# being meshed (colour, UV2 tag, finish) and the mesh's arrays.
var _all: Dictionary = {}
var _finish: Dictionary = {}
var _face_u: Array[Vector3] = []
var _face_v: Array[Vector3] = []
var _rings: Array = []
var _color: Color
var _base: Color
var _tag: Vector2
# Only while baking: per (direction, depth) plane, Vector2i(v, u) -> merge id; per merge id its
# [chunk, colour, finish, AO table entry]; per direction the axes of its normal, u and v.
var _planes: Dictionary = {}
var _merge_ids: Dictionary = {}
var _merge_info: Array = []
var _axes: Array[Vector3i] = []
var _finish_class := 0
var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _index := PackedInt32Array()


func _init(voxels: BuildingVoxels) -> void:
	_v = voxels
	_b = voxels.b
	_res = BuildingVoxels.RES
	_w = _v.b.w * _res
	_d = _v.b.d * _res
	_h = _v.b.height * _res
	var shell_cells: Array[Vector3i] = []
	var slab_cells: Array[Vector3i] = []
	var outside: Array[Vector3i] = []  # slabs outside the hollow (a brick building's balconies)
	for cell: Vector3i in _v.vox.cells:
		if _v.vox.key_at(cell) == "slab":
			if not _inside(cell):
				outside.append(cell)
			# A slab proud of the walls (a balcony floor) is never drawn: it would pop in building-wide
			# with the hidden floors at the first blow (director 2026-10-27, D-289). The wall behind it
			# draws its own face while the building stands (`outside`, below).
			if _in_footprint(cell):
				slab_cells.append(cell)
		else:
			shell_cells.append(cell)
	_begin()
	_shell_arrays = _bake(shell_cells, true, _standing_solid(outside))
	_slab_arrays = _bake(slab_cells, false, _v.vox.cells)
	_end()
	_v = null  # the voxels are the bulk of a building's memory: BuildingView rebuilds them on demand


## Index of the structural chunk a cell belongs to (cells outside the footprint clamp in).
func chunk_index(cell: Vector3i) -> int:
	var b := _b
	var cx := clampi(floori(float(cell.x) / _res), 0, b.w - 1)
	var cy := clampi(floori(float(cell.y) / _res), 0, b.height - 1)
	var cz := clampi(floori(float(cell.z) / _res), 0, b.d - 1)
	return cx + cz * b.w + cy * b.w * b.d


## Within the footprint (the walls and what they enclose), not proud of it.
func _in_footprint(c: Vector3i) -> bool:
	return c.x >= 0 and c.x < _w and c.z >= 0 and c.z < _d


## Inside the standing building: the hollow behind its walls, under its roof deck.
func _inside(c: Vector3i) -> bool:
	return c.x >= 1 and c.x <= _w - 2 and c.z >= 1 and c.z <= _d - 2 and c.y >= 0 and c.y < _h - 1


func _begin() -> void:
	_finish = VoxelAO.finish_table()
	var half := BuildingVoxels.VOXEL * 0.5
	for d: Vector3i in NEIGHBOURS:
		var nf := Vector3(d)
		var a := Vector3.UP if d.y == 0 else Vector3.RIGHT
		var u := a.cross(nf) * half
		_face_u.append(u)
		_face_v.append(nf.cross(u.normalized()) * half)
		_rings.append(VoxelAO.ring_of(d))
		_axes.append(Vector3i(_axis(nf), _axis(u), _axis(_face_v[-1])))


static func _axis(v: Vector3) -> int:
	return 0 if v.x != 0.0 else (1 if v.y != 0.0 else 2)


func _end() -> void:
	_all = {}
	_finish = {}
	_face_u.clear()
	_face_v.clear()
	_rings.clear()
	_axes.clear()


## The cells that hide a shell face while the building stands: all of them but the floor slabs
## `outside` the hollow (a brick balcony, proud of the wall). That slab is in the hidden mesh, so it
## hides nothing, and the wall behind it must draw its own outward face, or a see-through strip
## crosses the facade at every balcony (the dark flickering bars across the windows).
func _standing_solid(outside: Array[Vector3i]) -> Dictionary:
	var solid: Dictionary = _v.vox.cells
	if outside.is_empty():
		return solid
	solid = solid.duplicate()
	for cell: Vector3i in outside:
		solid.erase(cell)
	return solid


## The surface arrays of these cells' visible faces ([] when none shows); hollow_is_solid: the
## shell (its hollow hides the walls' inner faces and shades their AO); `all`: the cells whose
## faces hide the ones they touch and shade their AO.
func _bake(cells: Array[Vector3i], hollow_is_solid: bool, all: Dictionary) -> Array:
	_all = all
	var voxel := BuildingVoxels.VOXEL
	var origin := _v.origin() + Vector3(0, voxel * 0.5, 0)
	for cell: Vector3i in cells:
		var mask := _v.face_mask(cell)
		var hollow := hollow_is_solid and mask < 0  # a masked cell's faces meet real air
		if mask < 0:
			mask = _open_faces(cell, hollow)
		if mask == 0:
			continue
		var centre := origin + Vector3(cell) * voxel
		_start_cell(cell)
		for k: int in NEIGHBOURS.size():
			if mask & (1 << k) != 0:
				var ao := VoxelAO.table(_ring_bits(cell + NEIGHBOURS[k], k, hollow))
				if _flat(ao):
					_queue(cell, k, ao)
				else:
					_quad(centre, k, ao, Vector3.ONE)
		if hollow_is_solid:
			_sample(chunk_index(cell), centre, _color)
	_merge(origin)
	return _arrays()


## Whether a face's four AO corners are one level (it can merge with its like).
static func _flat(ao: int) -> bool:
	return (ao & 255) == (ao & 3) * 0x55


## Holds a flat face for _merge, keyed by what must match for two faces to merge.
func _queue(cell: Vector3i, k: int, ao: int) -> void:
	var key := [_tag.x, _base, _finish_class, ao]
	var id: int = _merge_ids.get(key, -1)
	if id < 0:
		id = _merge_info.size()
		_merge_ids[key] = id
		_merge_info.append(key)
	var ax := _axes[k]
	var plane := Vector2i(k, cell[ax.x])
	if not _planes.has(plane):
		_planes[plane] = {}
	var faces: Dictionary = _planes[plane]
	faces[Vector2i(cell[ax.z], cell[ax.y])] = id


## Greedy merge of the queued faces, plane by plane: a face grows along u while the next face
## matches, then along v while the whole row does; each rectangle is one quad.
func _merge(origin: Vector3) -> void:
	for plane: Vector2i in _planes:
		var k := plane.x
		var ax := _axes[k]
		var faces: Dictionary = _planes[plane]
		var order: Array = faces.keys()
		order.sort()
		for p: Vector2i in order:
			if not faces.has(p):
				continue
			var id: int = faces[p]
			var nu := 1
			while faces.get(Vector2i(p.x, p.y + nu), -1) == id:
				nu += 1
			var nv := 1
			while _row_matches(faces, Vector2i(p.x + nv, p.y), nu, id):
				nv += 1
			for j: int in nv:
				for i: int in nu:
					faces.erase(Vector2i(p.x + j, p.y + i))
			var mid := Vector3.ZERO
			mid[ax.x] = plane.y
			mid[ax.y] = p.y + (nu - 1) * 0.5
			mid[ax.z] = p.x + (nv - 1) * 0.5
			var span := Vector3.ONE
			span[ax.y] = nu
			span[ax.z] = nv
			var info: Array = _merge_info[id]
			var chunk: int = info[0]
			_tag = Vector2(chunk, 0.0)
			_base = info[1]
			_finish_class = info[2]
			var face_ao: int = info[3]
			_quad(origin + mid * BuildingVoxels.VOXEL, k, face_ao, span)
	_planes = {}
	_merge_ids = {}
	_merge_info = []


func _row_matches(faces: Dictionary, start: Vector2i, n: int, id: int) -> bool:
	for i: int in n:
		if faces.get(Vector2i(start.x, start.y + i), -1) != id:
			return false
	return true


## Whether a face towards n is hidden: a voxel, the ground, or (hollow) the building's inside.
func _solid(n: Vector3i, hollow: bool) -> bool:
	return _all.has(n) or (hollow and _inside(n)) or n.y < 0


## The faces (one bit per NEIGHBOURS entry) of a cell that meet air.
func _open_faces(cell: Vector3i, hollow: bool) -> int:
	var mask := 0
	for k: int in NEIGHBOURS.size():
		if not _solid(cell + NEIGHBOURS[k], hollow):
			mask |= 1 << k
	return mask


## The cell's colour (palette and jitter), UV2 tag (chunk, bite hash) and finish.
func _start_cell(cell: Vector3i) -> void:
	var key: String = _all[cell]
	var base: Color = _v.palette.get(key, Color.MAGENTA)
	if key == VoxelBuilder.DIRECT:
		base = _v.vox.colors[cell]
	# The mesh keeps the palette colour: building_baked.gdshader jitters it per voxel and bites in
	# clumps of 2x2x2 voxels (voxel_merged). The jittered colour is the debris sample's.
	_base = base
	_color = Look.jitter(base, cell, _v.b.style)
	_tag = Vector2(chunk_index(cell), 0.0)
	_finish_class = Num.i(_finish.get(key, 0))


## Which of the 8 cells round a face's air cell are solid (VoxelAO.ring_of's bits).
func _ring_bits(air: Vector3i, k: int, hollow: bool) -> int:
	var steps: Array[Vector3i] = _rings[k]
	var bits := 0
	for i: int in 8:
		if _solid(air + steps[i], hollow):
			bits |= 1 << i
	return bits


## One face centred on `centre` (a cell's centre, or a merged run's middle); ao: its
## VoxelAO.table entry; span: how many voxels it covers along each axis.
func _quad(centre: Vector3, k: int, ao: int, span: Vector3) -> void:
	var at := _verts.size()
	var nf := Vector3(NEIGHBOURS[k])
	var u := _face_u[k] * span
	var v := _face_v[k] * span
	var c := centre + nf * (BuildingVoxels.VOXEL * 0.5)
	_verts.append_array([c - u - v, c + u - v, c + u + v, c - u + v])
	for q: int in 4:
		_normals.append(nf)
		_colors.append(_base)
		_uv.append(VoxelAO.uv(ao, q, _finish_class))
		_uv2.append(_tag)
	var split := VoxelAO.SPLIT_13 if (ao & VoxelAO.FLIP) != 0 else VoxelAO.SPLIT_02
	for i: int in split:
		_index.append(at + i)


## The baked arrays ([] when none shows); the arrays start over for the next bake.
func _arrays() -> Array:
	var arrays := []
	if not _verts.is_empty():
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_TEX_UV] = _uv
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2
		arrays[Mesh.ARRAY_INDEX] = _index
	_verts = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	_uv = PackedVector2Array()
	_uv2 = PackedVector2Array()
	_index = PackedInt32Array()
	return arrays


## The mesh of _bake() arrays (no surface when empty). Main thread only.
static func mesh_of(arrays: Array) -> ArrayMesh:
	ThreadCheck.main_only("BuildingMesher.mesh_of")
	var mesh := ArrayMesh.new()
	if not arrays.is_empty():
		# Packed: 24 bytes a vertex, not 40 (positions within 0.85 mm, director yes 10-31).
		mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		)
	return mesh


func _sample(chunk: int, pos: Vector3, color: Color) -> void:
	if not samples.has(chunk):
		samples[chunk] = [PackedVector3Array(), PackedColorArray()]
	var list: Array = samples[chunk]
	var at: PackedVector3Array = list[0]
	var tint: PackedColorArray = list[1]
	if at.size() < SAMPLES_PER_CHUNK:
		at.append(pos)
		tint.append(color)
	elif absi(hash(pos)) % 7 == 0:  # spread the samples over the chunk, not just its corner
		var k := absi(hash(pos * 3.0)) % SAMPLES_PER_CHUNK
		at[k] = pos
		tint[k] = color
	list[0] = at
	list[1] = tint


## Chunk `chunk`'s debris sources as {"pos", "color"} (kept as two packed arrays: a dictionary
## per sample cost ~1.4 KB, more than the rest of a small building).
func parts_of(chunk: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if samples.has(chunk):
		var list: Array = samples[chunk]
		var at: PackedVector3Array = list[0]
		var tint: PackedColorArray = list[1]
		for k: int in at.size():
			out.append({"pos": at[k], "color": tint[k]})
	return out
