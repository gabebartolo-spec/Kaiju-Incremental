class_name BuildingMesher
extends RefCounted
## Bakes a building's voxels (BuildingVoxels) into meshes of only the faces that can be seen.
## The building's hollow inside counts as solid while it stands, so the inner faces of its
## walls are never drawn; the floor slabs bake into a second mesh that is shown only once the
## building is broken open. Every vertex carries its structural chunk and a per-voxel hash
## (UV2) for building_baked.gdshader, and a few voxels per chunk are kept as samples for the
## debris a broken chunk throws. Pure data: safe to run on a worker thread.

const NEIGHBOURS: Array[Vector3i] = [
	Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK
]
const SAMPLES_PER_CHUNK := 12

## The shell (walls, windows, roof, gear) and the hidden floor slabs.
var shell: ArrayMesh
var slabs: ArrayMesh
## Chunk index -> Array of {"pos": world Vector3, "color": Color} (debris sources).
var samples: Dictionary = {}

var _v: BuildingVoxels
var _res: int
var _w: int
var _d: int
var _h: int


func _init(voxels: BuildingVoxels) -> void:
	_v = voxels
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
	shell = _bake(shell_cells, true)
	slabs = _bake(slab_cells, false)


## Index of the structural chunk a cell belongs to (cells outside the footprint clamp in).
func chunk_index(cell: Vector3i) -> int:
	var b := _v.b
	var cx := clampi(floori(float(cell.x) / _res), 0, b.w - 1)
	var cy := clampi(floori(float(cell.y) / _res), 0, b.height - 1)
	var cz := clampi(floori(float(cell.z) / _res), 0, b.d - 1)
	return cx + cz * b.w + cy * b.w * b.d


## Inside the standing building: the hollow behind its walls, under its roof deck.
func _inside(c: Vector3i) -> bool:
	return c.x >= 1 and c.x <= _w - 2 and c.z >= 1 and c.z <= _d - 2 and c.y >= 0 and c.y < _h - 1


func _bake(cells: Array[Vector3i], hollow_is_solid: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv2 := PackedVector2Array()
	var index := PackedInt32Array()
	var all: Dictionary = _v.vox.cells
	var voxel := BuildingVoxels.VOXEL
	var half := voxel * 0.5
	var origin := _v.origin() + Vector3(0, half, 0)
	var salt := _v.b.style
	for cell: Vector3i in cells:
		var key: String = all[cell]
		var base: Color = _v.palette.get(key, Color.MAGENTA)
		if key == VoxelBuilder.DIRECT:
			base = _v.vox.colors[cell]
		var mask := _v.face_mask(cell)
		var color := Look.jitter(base, cell, salt)
		var centre := origin + Vector3(cell) * voxel
		var chunk := chunk_index(cell)
		# Bites come out in clumps of 2x2x2 voxels, not single-voxel confetti.
		var clump := Vector3i(cell.x >> 1, cell.y >> 1, cell.z >> 1)
		var h := float(absi(hash(clump * 7 + Vector3i(salt, 3, 11))) % 997) / 997.0
		var faces := 0
		for k: int in NEIGHBOURS.size():
			var d := NEIGHBOURS[k]
			var n := cell + d
			if mask >= 0:
				if mask & (1 << k) == 0:
					continue
			elif all.has(n) or (hollow_is_solid and _inside(n)) or (n.y < 0):
				continue
			faces += 1
			var at := verts.size()
			var nf := Vector3(d)
			var a := Vector3.UP if d.y == 0 else Vector3.RIGHT
			var u := a.cross(nf) * half
			var v := nf.cross(u.normalized()) * half
			var c := centre + nf * half
			verts.append_array([c - u - v, c + u - v, c + u + v, c - u + v])
			for i: int in 4:
				normals.append(nf)
				colors.append(color)
				uv2.append(Vector2(chunk, h))
			index.append_array([at, at + 2, at + 1, at, at + 3, at + 2])
		if faces > 0 and hollow_is_solid:
			_sample(chunk, centre, color)
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = index
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _sample(chunk: int, pos: Vector3, color: Color) -> void:
	if not samples.has(chunk):
		samples[chunk] = []
	var list: Array = samples[chunk]
	if list.size() < SAMPLES_PER_CHUNK:
		list.append({"pos": pos, "color": color})
	elif absi(hash(pos)) % 7 == 0:  # spread the samples over the chunk, not just its corner
		list[absi(hash(pos * 3.0)) % SAMPLES_PER_CHUNK] = {"pos": pos, "color": color}
