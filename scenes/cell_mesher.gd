class_name CellMesher
extends RefCounted
## Meshes a building from its fine destruction grid (BuildingCells, D-094 WP4) one REGION^3
## block of cells at a time, so a carve rebuilds only the blocks it touched. A face is drawn
## wherever a cell meets air (an empty cell or the grid's edge; never the ground under y = 0),
## so the inside of a carved hole is real, outward-lit surface: the walls' inner faces and the
## floor slabs are drawn as solid, not as the dark backs of the shell (BuildingMesher's
## standing-building trick). Colours are today's look: BuildingVoxels' palette, its lit-window
## roll (the cells it drew "lit" or "shop_lit") and Look.jitter per cell, so an uncarved
## building looks as its baked BuildingView does. Every corner carries its AO and the cell's
## material finish in UV (VoxelAO; a solid neighbour or the ground shades it, off-grid is air).
## Two paths give the same bytes: the native KaijuMesher (native/, WP2's extension) when it is
## loaded, and the GDScript below, the oracle the native suite holds it to. Pure data: safe on a
## worker thread once set up.

const REGION := 16
## Look ids past the materials table (bytes in `looks`): the windows the view draws lit.
const LIT := 254
const SHOP_LIT := 255
## Look ids for a model's own colours (a landmark's or a pool building's DIRECT voxels): its
## material ids (landmark_wall...) have no palette colour, so each colour, quantised, gets a slot.
const FIRST_COLOR := 64
## Colour quantisation steps per channel for those slots.
const COLOR_STEPS := 16.0
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
## Grid indices of the cells the view never draws (drawn()): a balcony floor proud of the walls.
var hidden := PackedInt32Array()
## Look id -> colour (sRGB; alpha 0 = glows), 256 entries.
var palette: PackedColorArray
## The native mesher when the extension is loaded (null: the GDScript path).
var native: Object = null
## Look id -> finish class (VoxelAO), 256 entries: a lit window's cells are glass, mullions
## included, as the baked BuildingMesher draws them.
var finish: PackedByteArray
## Face corners per NEIGHBOURS direction, from a cell's centre (as BuildingMesher builds them).
var _corners: Array[PackedVector3Array] = []
## Per NEIGHBOURS direction, the 8 cells round a face's air cell (VoxelAO.ring_of).
var _rings: Array = []
## Colour slot (FIRST_COLOR..) -> the material id its first cell had (for its finish).
var _slot_material: Dictionary = {}
## Quantised colour -> its slot.
var _slot_of: Dictionary = {}


## One region's arrays while the oracle meshes it (a holder: packed arrays copy on write).
class _Out:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	var uv := PackedVector2Array()


## voxels: the building's view voxels (its palette and lit roll); cells: its grid. use_native:
## false forces the GDScript path (the oracle).
func _init(voxels: BuildingVoxels, cells: CellGrid, use_native: bool = true) -> void:
	dims = cells.dims
	offset = cells.offset
	voxel = BuildingVoxels.VOXEL
	salt = voxels.b.style
	noise = Look.value("color_noise")
	origin = voxels.origin() + Vector3(0, voxel * 0.5, 0) + Vector3(offset) * voxel
	_fill_palette(voxels)
	_read_looks(voxels, cells)
	var half := voxel * 0.5
	for d: Vector3i in NEIGHBOURS:
		var nf := Vector3(d)
		var a := Vector3.UP if d.y == 0 else Vector3.RIGHT
		var u := a.cross(nf) * half
		var v := nf.cross(u.normalized()) * half
		var c := nf * half
		_corners.append(PackedVector3Array([c - u - v, c + u - v, c + u + v, c - u + v]))
		_rings.append(VoxelAO.ring_of(d))
	finish = VoxelAO.finish_by_look(LIT, SHOP_LIT)
	for slot: int in _slot_material:
		finish[slot] = finish[_slot_material[slot]]
	if use_native and ClassDB.class_exists("KaijuMesher"):
		_start_native()


## Look id -> colour: each material's from the building's palette, and the two lit looks.
func _fill_palette(voxels: BuildingVoxels) -> void:
	palette = PackedColorArray()
	palette.resize(256)
	palette.fill(Color.MAGENTA)
	for m: Dictionary in Content.materials():
		palette[Num.i(m["id"])] = voxels.palette.get(str(m["name"]), Color.MAGENTA)
	palette[LIT] = voxels.palette["lit"]
	palette[SHOP_LIT] = voxels.palette["shop_lit"]


## Each cell's look (its material, or a lit window's), and the balcony floors proud of the walls
## the view never draws (hidden).
func _read_looks(voxels: BuildingVoxels, cells: CellGrid) -> void:
	looks = cells.cells.duplicate()
	var foot := Rect2i(Vector2i.ZERO, Vector2i(voxels.b.w, voxels.b.d) * BuildingVoxels.RES)
	for i: int in looks.size():
		if looks[i] == 0:
			continue
		var local := _local(i)
		var key := voxels.vox.key_at(local)
		if key == "lit":
			looks[i] = LIT
		elif key == "shop_lit":
			looks[i] = SHOP_LIT
		elif key == "slab" and not foot.has_point(Vector2i(local.x, local.z)):
			hidden.append(i)
		elif key == VoxelBuilder.DIRECT:
			looks[i] = _color_slot(voxels.vox.colors[local], looks[i])


## The look id drawing colour `c` (a model's own voxel colour): a new slot per quantised colour,
## the nearest one once the slots run out. material: the cell's material id (its finish).
func _color_slot(c: Color, material: int) -> int:
	var q := Color(
		roundf(c.r * COLOR_STEPS) / COLOR_STEPS,
		roundf(c.g * COLOR_STEPS) / COLOR_STEPS,
		roundf(c.b * COLOR_STEPS) / COLOR_STEPS,
		c.a
	)
	if _slot_of.has(q):
		return _slot_of[q]
	var next := FIRST_COLOR + _slot_material.size()
	if next < LIT:
		palette[next] = q
		_slot_material[next] = material
		_slot_of[q] = next
		return next
	var best := FIRST_COLOR
	var best_d := INF
	for slot: int in _slot_material:
		var p := palette[slot]
		var d := Vector4(p.r - q.r, p.g - q.g, p.b - q.b, p.a - q.a).length_squared()
		if d < best_d:
			best = slot
			best_d = d
	_slot_of[q] = best
	return best


## The native mesher, set up as this one; a library older than item 12 has no AO, so the oracle
## draws instead (native stays null).
func _start_native() -> void:
	native = ClassDB.instantiate("KaijuMesher")
	native.call("setup", dims, offset, origin, voxel, salt, noise, looks, palette)
	if not native.has_method("set_finish") or not native.call("set_finish", finish):
		native = null


## The grid as the view draws it: `cells` with the hidden cells as air. A slab proud of the walls
## (a balcony floor) is in neither of the baked view's meshes (D-289), so promotion must not pop
## it in; the sim still holds it, and the wall behind it draws its own face, as the baked shell's
## does.
func drawn(cells: PackedByteArray) -> PackedByteArray:
	if hidden.is_empty():
		return cells
	var out := cells.duplicate()
	for i: int in hidden:
		out[i] = 0
	return out


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


## Region r of grid `cells` as [vertices, normals, colours, indices, UVs (AO, finish)] (empty
## arrays when it has no visible face). Native when loaded, else the oracle.
func mesh_region(cells: PackedByteArray, r: Vector3i) -> Array:
	if native != null:
		return native.call("mesh_region", cells, r)
	return mesh_region_gd(cells, r)


## The GDScript oracle of mesh_region.
func mesh_region_gd(cells: PackedByteArray, r: Vector3i) -> Array:
	var out := _Out.new()
	var lo := r * REGION
	var hi := (lo + Vector3i.ONE * REGION).min(dims)
	var plan := dims.x * dims.z
	for y: int in range(lo.y, hi.y):
		for z: int in range(lo.z, hi.z):
			for x: int in range(lo.x, hi.x):
				var i := x + z * dims.x + y * plan
				if cells[i] != 0:
					_cell_faces(cells, Vector3i(x, y, z), i, out)
	return [out.verts, out.normals, out.colors, out.index, out.uv]


## The faces of solid grid cell c (index i) that meet air, into `out`.
func _cell_faces(cells: PackedByteArray, c: Vector3i, i: int, out: _Out) -> void:
	var centre := origin + Vector3(c) * voxel
	var color := Color.BLACK
	var coloured := false
	var fin := finish[looks[i]]
	for k: int in NEIGHBOURS.size():
		var air := c + NEIGHBOURS[k]
		if not _open(cells, air):
			continue
		if not coloured:
			color = Look.jitter(palette[looks[i]], c + offset, salt)
			coloured = true
		var ao := VoxelAO.table(_ring_bits(cells, air, k))
		var at := out.verts.size()
		var corners := _corners[k]
		var nf := Vector3(NEIGHBOURS[k])
		for q: int in 4:
			out.verts.append(centre + corners[q])
			out.normals.append(nf)
			out.colors.append(color)
			out.uv.append(VoxelAO.uv(ao, q, fin))
		var split := VoxelAO.SPLIT_13 if (ao & VoxelAO.FLIP) != 0 else VoxelAO.SPLIT_02
		for s: int in split:
			out.index.append(at + s)


## Which of the 8 cells round a face's air cell are solid or ground (VoxelAO.ring_of's bits).
func _ring_bits(cells: PackedByteArray, air: Vector3i, k: int) -> int:
	var steps: Array[Vector3i] = _rings[k]
	var bits := 0
	for s: int in 8:
		if not _open(cells, air + steps[s]):
			bits |= 1 << s
	return bits


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
	surface[Mesh.ARRAY_TEX_UV] = arrays[4]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh


## Render plan item 9c: whether this mesher packs a finished surface itself (the native mesher
## with KaijuMesher.pack_surface; the GDScript path and an older extension do not).
func can_pack() -> bool:
	return native != null and native.has_method("pack_surface")


## A region's arrays as a mesh from the native packed surface (null when it has no face): the
## bytes to_mesh's add_surface_from_arrays packs, handed to ArrayMesh._set_surfaces, which makes
## the mesh with RenderingServer.mesh_create_from_surfaces. Under a real renderer that runs on the
## calling thread, upload included, so a worker can call this (CellView); the dummy renderer
## queues it with an allocator that is not thread-safe, so headless calls it on the main thread
## only (tests). Needs can_pack().
func packed_mesh(arrays: Array) -> ArrayMesh:
	var surface: Dictionary = native.call("pack_surface", arrays)
	if surface.is_empty():
		return null
	# An ArrayMesh with no RID yet: _set_surfaces makes it with mesh_create_from_surfaces, which a
	# RenderingDevice renderer builds on the calling thread by design (async resource creation); no
	# material. CellView's worker_mesh gate (not headless, a RenderingDevice) keeps others on main.
	var mesh := ArrayMesh.new()  # thread-ok: RenderingDevice only, gated in CellView (above)
	mesh.call("_set_surfaces", [surface])
	return mesh


## SHA-256 of a region's arrays, byte for byte (native == oracle checks).
static func digest(arrays: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var verts: PackedVector3Array = arrays[0]
	var normals: PackedVector3Array = arrays[1]
	var colors: PackedColorArray = arrays[2]
	var index: PackedInt32Array = arrays[3]
	var uv: PackedVector2Array = arrays[4]
	ctx.update(var_to_bytes([verts.size(), index.size(), uv.size()]))
	if not verts.is_empty():
		ctx.update(verts.to_byte_array())
		ctx.update(normals.to_byte_array())
		ctx.update(colors.to_byte_array())
		ctx.update(index.to_byte_array())
		ctx.update(uv.to_byte_array())
	return ctx.finish().hex_encode()
