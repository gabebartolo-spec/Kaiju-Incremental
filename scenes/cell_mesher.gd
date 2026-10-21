class_name CellMesher
extends RefCounted
## Meshes a building from its fine destruction grid (BuildingCells, D-094 WP4) one REGION^3
## block of cells at a time, so a carve rebuilds only the blocks it touched. A face is drawn
## wherever a cell meets air (an empty cell or the grid's edge; never the ground under y = 0),
## so the inside of a carved hole is real, outward-lit surface: the walls' inner faces and the
## floor slabs are drawn as solid, not as the dark backs of the shell (BuildingMesher's
## standing-building trick). Colours are today's look: BuildingVoxels' palette, its lit-window
## roll (the cells it drew "lit" or "shop_lit") and Look.jitter per cell, so an uncarved
## building looks as its baked BuildingView does. Two paths give the same bytes: the native
## KaijuMesher (native/, WP2's extension) when it is loaded, and the GDScript below, the oracle
## the native suite holds it to. Pure data: safe on a worker thread once set up.

const REGION := 16
## Look ids past the materials table (bytes in `looks`): the windows the view draws lit.
const LIT := 254
const SHOP_LIT := 255
const NEIGHBOURS: Array[Vector3i] = BuildingMesher.NEIGHBOURS

var dims: Vector3i
## Building-local cell (BuildingVoxels' coordinates) of grid cell (0, 0, 0).
var offset: Vector3i
## World position of grid cell (0, 0, 0)'s centre.
var origin: Vector3
var voxel: float
var salt: int
var noise: float
## Per cell, the palette index it draws with: its material id, or LIT/SHOP_LIT.
var looks: PackedByteArray
## Look id -> colour (sRGB; alpha 0 = glows), 256 entries.
var palette: PackedColorArray
## The native mesher when the extension is loaded (null: the GDScript path).
var native: Object = null
## Face corners per NEIGHBOURS direction, from a cell's centre (as BuildingMesher builds them).
var _corners: Array[PackedVector3Array] = []


## voxels: the building's view voxels (its palette and lit roll); cells: its grid. use_native:
## false forces the GDScript path (the oracle).
func _init(voxels: BuildingVoxels, cells: BuildingCells, use_native: bool = true) -> void:
	dims = cells.dims
	offset = cells.offset
	voxel = BuildingVoxels.VOXEL
	salt = voxels.b.style
	noise = Look.value("color_noise")
	origin = voxels.origin() + Vector3(0, voxel * 0.5, 0) + Vector3(offset) * voxel
	palette = PackedColorArray()
	palette.resize(256)
	palette.fill(Color.MAGENTA)
	for m: Dictionary in Content.materials():
		palette[Num.i(m["id"])] = voxels.palette.get(str(m["name"]), Color.MAGENTA)
	palette[LIT] = voxels.palette["lit"]
	palette[SHOP_LIT] = voxels.palette["shop_lit"]
	looks = cells.cells.duplicate()
	for i: int in looks.size():
		if looks[i] == 0:
			continue
		var key := voxels.vox.key_at(_local(i))
		if key == "lit":
			looks[i] = LIT
		elif key == "shop_lit":
			looks[i] = SHOP_LIT
	var half := voxel * 0.5
	for d: Vector3i in NEIGHBOURS:
		var nf := Vector3(d)
		var a := Vector3.UP if d.y == 0 else Vector3.RIGHT
		var u := a.cross(nf) * half
		var v := nf.cross(u.normalized()) * half
		var c := nf * half
		_corners.append(PackedVector3Array([c - u - v, c + u - v, c + u + v, c - u + v]))
	if use_native and ClassDB.class_exists("KaijuMesher"):
		native = ClassDB.instantiate("KaijuMesher")
		native.call("setup", dims, offset, origin, voxel, salt, noise, looks, palette)


## Regions along each axis.
func regions() -> Vector3i:
	return Vector3i(
		ceili(float(dims.x) / REGION), ceili(float(dims.y) / REGION), ceili(float(dims.z) / REGION)
	)


## Every region index in order (x fastest, then z, then y).
func all_regions() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var n := regions()
	for y: int in n.y:
		for z: int in n.z:
			for x: int in n.x:
				out.append(Vector3i(x, y, z))
	return out


## The regions whose meshes can change when the cells in [lo, hi] (grid cells, inclusive)
## change: a removed cell opens a face on each neighbour, so the box grows by one cell.
func regions_touching(lo: Vector3i, hi: Vector3i) -> Array[Vector3i]:
	var n := regions()
	var a := ((lo - Vector3i.ONE).max(Vector3i.ZERO)) / REGION
	var b := ((hi + Vector3i.ONE).min(dims - Vector3i.ONE)) / REGION
	a = a.min(n - Vector3i.ONE)
	b = b.min(n - Vector3i.ONE)
	var out: Array[Vector3i] = []
	for y: int in range(a.y, b.y + 1):
		for z: int in range(a.z, b.z + 1):
			for x: int in range(a.x, b.x + 1):
				out.append(Vector3i(x, y, z))
	return out


## Region r of grid `cells` as [vertices, normals, colours, indices] (empty arrays when it has
## no visible face). Native when loaded, else the oracle.
func mesh_region(cells: PackedByteArray, r: Vector3i) -> Array:
	if native != null:
		return native.call("mesh_region", cells, r)
	return mesh_region_gd(cells, r)


## The GDScript oracle of mesh_region.
func mesh_region_gd(cells: PackedByteArray, r: Vector3i) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	var lo := r * REGION
	var hi := (lo + Vector3i.ONE * REGION).min(dims)
	var plan := dims.x * dims.z
	for y: int in range(lo.y, hi.y):
		for z: int in range(lo.z, hi.z):
			for x: int in range(lo.x, hi.x):
				var i := x + z * dims.x + y * plan
				if cells[i] == 0:
					continue
				var c := Vector3i(x, y, z)
				var centre := origin + Vector3(c) * voxel
				var color := Color.BLACK
				var coloured := false
				for k: int in NEIGHBOURS.size():
					if not _open(cells, c + NEIGHBOURS[k]):
						continue
					if not coloured:
						color = Look.jitter(palette[looks[i]], c + offset, salt)
						coloured = true
					var at := verts.size()
					var corners := _corners[k]
					var nf := Vector3(NEIGHBOURS[k])
					for q: int in 4:
						verts.append(centre + corners[q])
						normals.append(nf)
						colors.append(color)
					index.append_array([at, at + 2, at + 1, at, at + 3, at + 2])
	return [verts, normals, colors, index]


## Whether a face towards grid cell n is drawn: it is air (empty or off the grid), not ground.
func _open(cells: PackedByteArray, n: Vector3i) -> bool:
	if n.y + offset.y < 0:
		return false
	if n.x < 0 or n.y < 0 or n.z < 0 or n.x >= dims.x or n.y >= dims.y or n.z >= dims.z:
		return true
	return cells[n.x + n.z * dims.x + n.y * dims.x * dims.z] == 0


func _local(i: int) -> Vector3i:
	var plan := dims.x * dims.z
	return Vector3i(i % dims.x, i / plan, (i / dims.x) % dims.z) + offset


## A region's arrays as a mesh (null when it has no face).
static func to_mesh(arrays: Array) -> ArrayMesh:
	var verts: PackedVector3Array = arrays[0]
	if verts.is_empty():
		return null
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = verts
	surface[Mesh.ARRAY_NORMAL] = arrays[1]
	surface[Mesh.ARRAY_COLOR] = arrays[2]
	surface[Mesh.ARRAY_INDEX] = arrays[3]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh


## SHA-256 of a region's arrays, byte for byte (native == oracle checks).
static func digest(arrays: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var verts: PackedVector3Array = arrays[0]
	var normals: PackedVector3Array = arrays[1]
	var colors: PackedColorArray = arrays[2]
	var index: PackedInt32Array = arrays[3]
	ctx.update(var_to_bytes([verts.size(), index.size()]))
	if not verts.is_empty():
		ctx.update(verts.to_byte_array())
		ctx.update(normals.to_byte_array())
		ctx.update(colors.to_byte_array())
		ctx.update(index.to_byte_array())
	return ctx.finish().hex_encode()
