class_name BuildingMesher
extends RefCounted
## Bakes a building's voxels (BuildingVoxels) into meshes of only the faces that can be seen.
## The building's hollow inside counts as solid while it stands, so the inner faces of its
## walls are never drawn; the floor slabs bake into a second mesh that is shown only once the
## building is broken open. Every vertex carries its structural chunk and a per-voxel hash
## (UV2) for building_baked.gdshader and its corner AO and material finish (UV, VoxelAO), and a
## few voxels per chunk are kept as samples for the debris a broken chunk throws. Pure data:
## safe to run on a worker thread.

const NEIGHBOURS: Array[Vector3i] = [
	Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK
]
const SAMPLES_PER_CHUNK := 12

## The shell (walls, windows, roof, gear) and the hidden floor slabs.
var shell: ArrayMesh
var slabs: ArrayMesh
## Chunk index -> [PackedVector3Array positions, PackedColorArray colours] (debris sources;
## parts_of).
var samples: Dictionary = {}

var _v: BuildingVoxels  # only while baking: a kept mesher must not hold the voxels
var _b: RampageSim.Building
var _res: int
var _w: int
var _d: int
var _h: int
# Only while baking (cleared after: the mesher is kept): the voxels' cells, each palette key's
# finish (VoxelAO), per NEIGHBOURS direction the face's corner vectors and AO ring, the cell
# being meshed (colour, UV2 tag, finish) and the mesh's arrays.
var _all: Dictionary = {}
var _finish: Dictionary = {}
var _face_u: Array[Vector3] = []
var _face_v: Array[Vector3] = []
var _rings: Array = []
var _color: Color
var _tag: Vector2
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
	for cell: Vector3i in _v.vox.cells:
		if _v.vox.key_at(cell) == "slab":
			slab_cells.append(cell)
		else:
			shell_cells.append(cell)
	_begin()
	shell = _bake(shell_cells, true)
	slabs = _bake(slab_cells, false)
	_end()
	_v = null  # the voxels are the bulk of a building's memory: BuildingView rebuilds them on demand


## Index of the structural chunk a cell belongs to (cells outside the footprint clamp in).
func chunk_index(cell: Vector3i) -> int:
	var b := _b
	var cx := clampi(floori(float(cell.x) / _res), 0, b.w - 1)
	var cy := clampi(floori(float(cell.y) / _res), 0, b.height - 1)
	var cz := clampi(floori(float(cell.z) / _res), 0, b.d - 1)
	return cx + cz * b.w + cy * b.w * b.d


## Inside the standing building: the hollow behind its walls, under its roof deck.
func _inside(c: Vector3i) -> bool:
	return c.x >= 1 and c.x <= _w - 2 and c.z >= 1 and c.z <= _d - 2 and c.y >= 0 and c.y < _h - 1


func _begin() -> void:
	_all = _v.vox.cells
	_finish = VoxelAO.finish_table()
	var half := BuildingVoxels.VOXEL * 0.5
	for d: Vector3i in NEIGHBOURS:
		var nf := Vector3(d)
		var a := Vector3.UP if d.y == 0 else Vector3.RIGHT
		var u := a.cross(nf) * half
		_face_u.append(u)
		_face_v.append(nf.cross(u.normalized()) * half)
		_rings.append(VoxelAO.ring_of(d))


func _end() -> void:
	_all = {}
	_finish = {}
	_face_u.clear()
	_face_v.clear()
	_rings.clear()


## A mesh of these cells' visible faces; hollow_is_solid: the shell (its hollow hides the walls'
## inner faces and shades their AO).
func _bake(cells: Array[Vector3i], hollow_is_solid: bool) -> ArrayMesh:
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
				_quad(centre, k, VoxelAO.table(_ring_bits(cell + NEIGHBOURS[k], k, hollow)))
		if hollow_is_solid:
			_sample(chunk_index(cell), centre, _color)
	return _mesh()


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
	var salt := _v.b.style
	_color = Look.jitter(base, cell, salt)
	# Bites come out in clumps of 2x2x2 voxels, not single-voxel confetti.
	var clump := Vector3i(cell.x >> 1, cell.y >> 1, cell.z >> 1)
	var h := float(absi(hash(clump * 7 + Vector3i(salt, 3, 11))) % 997) / 997.0
	_tag = Vector2(chunk_index(cell), h)
	_finish_class = int(_finish.get(key, 0))


## Which of the 8 cells round a face's air cell are solid (VoxelAO.ring_of's bits).
func _ring_bits(air: Vector3i, k: int, hollow: bool) -> int:
	var steps: Array[Vector3i] = _rings[k]
	var bits := 0
	for i: int in 8:
		if _solid(air + steps[i], hollow):
			bits |= 1 << i
	return bits


## One face of the cell centred at `centre`; ao: its VoxelAO.table entry.
func _quad(centre: Vector3, k: int, ao: int) -> void:
	var at := _verts.size()
	var nf := Vector3(NEIGHBOURS[k])
	var u := _face_u[k]
	var v := _face_v[k]
	var c := centre + nf * (BuildingVoxels.VOXEL * 0.5)
	_verts.append_array([c - u - v, c + u - v, c + u + v, c - u + v])
	for q: int in 4:
		_normals.append(nf)
		_colors.append(_color)
		_uv.append(VoxelAO.uv(ao, q, _finish_class))
		_uv2.append(_tag)
	var split := VoxelAO.SPLIT_13 if (ao & VoxelAO.FLIP) != 0 else VoxelAO.SPLIT_02
	for i: int in split:
		_index.append(at + i)


## The baked arrays as a mesh; the arrays start over for the next bake.
func _mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not _verts.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_TEX_UV] = _uv
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2
		arrays[Mesh.ARRAY_INDEX] = _index
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_verts = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	_uv = PackedVector2Array()
	_uv2 = PackedVector2Array()
	_index = PackedInt32Array()
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
