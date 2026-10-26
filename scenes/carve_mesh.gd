class_name CarveMesh
extends RefCounted
## Meshes a set of grid cells as voxel cubes: only the faces that border a cell outside `solid`
## are drawn, each wound clockwise from outside with its outward normal (the destruction spike's
## first clip had inverted normals: faces vanished from outside). Colours by material, with a
## faint per-cell shade so a flat wall reads as voxels, darkened at each corner by the baked
## voxel AO (VoxelAO, the look's strength; a StandardMaterial3D cannot read it from UV). Shared
## by island bodies and captures.

## Face order: -x, +x, -y, +y, -z, +z.
const STEPS: Array[Vector3i] = [
	Vector3i(-1, 0, 0),
	Vector3i(1, 0, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, 0, -1),
	Vector3i(0, 0, 1),
]
## Each face's four corners in unit-cube space (face f at 4f..4f+3); (c1 - c0) x (c2 - c0)
## points out of the cube.
const CORNERS: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(0, 0, 1),
	Vector3(0, 1, 1),
	Vector3(0, 1, 0),
	Vector3(1, 0, 1),
	Vector3(1, 0, 0),
	Vector3(1, 1, 0),
	Vector3(1, 1, 1),
	Vector3(0, 0, 0),
	Vector3(1, 0, 0),
	Vector3(1, 0, 1),
	Vector3(0, 0, 1),
	Vector3(0, 1, 1),
	Vector3(1, 1, 1),
	Vector3(1, 1, 0),
	Vector3(0, 1, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, 0),
	Vector3(0, 1, 0),
	Vector3(1, 1, 0),
	Vector3(0, 0, 1),
	Vector3(1, 0, 1),
	Vector3(1, 1, 1),
	Vector3(0, 1, 1),
]
const ORDER: Array[int] = [0, 2, 1, 0, 3, 2]
## ORDER split along the other diagonal (corners 1-3), when that one is brighter (VoxelAO).
const ORDER_FLIPPED: Array[int] = [0, 3, 1, 1, 3, 2]
const SHADE_MIN := 0.9  # the darkest a cell is shaded, of its material colour

static var _material: StandardMaterial3D
## Per face, per corner: the steps from the face's air cell to the corner's two side cells and
## its corner cell (VoxelAO's rule, in this mesher's own corner order).
static var _ao_steps: Array = _make_ao_steps()


## The faces being built: the grid they test against and their arrays (a holder: packed arrays
## copy on write).
class _Faces:
	var site: CarveSite
	var solid: PackedByteArray
	var size: float
	var strength: float
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	func _init(p_site: CarveSite, p_solid: PackedByteArray) -> void:
		site = p_site
		solid = p_solid
		size = 1.0 / site.res
		strength = VoxelAO.strength()

	## Face f of cell c (corner at p), coloured col and shaded by its corners' AO.
	func add(c: Vector3i, f: int, p: Vector3, col: Color) -> void:
		var shade: Array[float] = [1.0, 1.0, 1.0, 1.0]
		var order := ORDER
		if strength > 0.0:
			var lv := _levels(c + STEPS[f], f)
			for q: int in 4:
				shade[q] = lerpf(1.0, VoxelAO.LEVEL_VALUE[lv[q]], strength)
			if lv[1] + lv[3] > lv[0] + lv[2]:
				order = ORDER_FLIPPED
		var n := Vector3(STEPS[f])
		for v: int in order:
			var k := shade[v]
			verts.append(p + CORNERS[f * 4 + v] * size)
			normals.append(n)
			colors.append(Color(col.r * k, col.g * k, col.b * k))

	func _levels(air: Vector3i, f: int) -> Array[int]:
		var out: Array[int] = []
		for q: int in 4:
			var steps: Array = CarveMesh._ao_steps[f][q]
			var s1: Vector3i = steps[0]
			var s2: Vector3i = steps[1]
			var c: Vector3i = steps[2]
			out.append(VoxelAO.level(blocks(air + s1), blocks(air + s2), blocks(air + c)))
		return out

	func blocks(q: Vector3i) -> bool:
		return site.inside(q) and solid[site.index(q)] != 0


## One shared vertex-coloured material for every carved mesh.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.9
		# A fill light: a face the sun and sky cannot reach (the inside of a gouge, a slab's
		# underside) keeps a floor of light, so it reads as concrete, not a black hole.
		var fill := Num.f(Content.section("carve_physics")["fill_light"])
		_material.emission_enabled = fill > 0.0
		_material.emission = Color(fill, fill, fill)
	return _material


## The mesh of `cells` (indices), coloured by `mats` (parallel), in world space. A face is
## drawn where the neighbour is outside the grid or `solid` is 0 there. Null when none shows.
static func build(
	site: CarveSite, cells: PackedInt32Array, mats: PackedByteArray, solid: PackedByteArray
) -> ArrayMesh:
	return build_at(site, cells, [mats, solid], Vector3.ZERO)


## build() relative to `offset` (world): vertices are placed at their world position minus it;
## `src` is [mats, solid].
static func build_at(
	site: CarveSite, cells: PackedInt32Array, src: Array, offset: Vector3
) -> ArrayMesh:
	var mats: PackedByteArray = src[0]
	var out := _Faces.new(site, src[1])
	var base := site.origin - offset
	for k: int in cells.size():
		var c := site.cell(cells[k])
		var col := site.color(mats[k])
		var shade := SHADE_MIN + (1.0 - SHADE_MIN) * posmod(c.x * 7 + c.y * 13 + c.z * 3, 5) / 4.0
		col = Color(col.r * shade, col.g * shade, col.b * shade)
		var p := base + Vector3(c) * out.size
		for f: int in 6:
			if not out.blocks(c + STEPS[f]):
				out.add(c, f, p, col)
	if out.verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out.verts
	arrays[Mesh.ARRAY_NORMAL] = out.normals
	arrays[Mesh.ARRAY_COLOR] = out.colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh


## Cells grouped by brick (res^3 cells, one sim unit): brick -> PackedInt32Array of positions
## in `cells` (not cell indices), so a caller can keep parallel arrays.
static func bricks(site: CarveSite, cells: PackedInt32Array) -> Dictionary:
	var out := {}
	for k: int in cells.size():
		var key := site.cell(cells[k]) / site.res
		if not out.has(key):
			out[key] = PackedInt32Array()
		var list: PackedInt32Array = out[key]
		list.append(k)
		out[key] = list
	return out


## The world box round the given positions of `cells`.
static func span(site: CarveSite, cells: PackedInt32Array, ks: PackedInt32Array) -> AABB:
	var lo := site.size
	var hi := -Vector3i.ONE
	for k: int in ks:
		var c := site.cell(cells[k])
		lo = lo.min(c)
		hi = hi.max(c)
	var s := 1.0 / site.res
	return AABB(site.origin + Vector3(lo) * s, Vector3(hi - lo + Vector3i.ONE) * s)


## _ao_steps: a corner's sides step along the face's two in-plane axes towards the corner.
static func _make_ao_steps() -> Array:
	var out := []
	for f: int in 6:
		var per := []
		for q: int in 4:
			var o := CORNERS[f * 4 + q] * 2.0 - Vector3.ONE  # -1 or +1 on every axis
			var side: Array[Vector3i] = []
			for axis: int in 3:
				if STEPS[f][axis] == 0:
					var step := Vector3i.ZERO
					step[axis] = int(o[axis])
					side.append(step)
			per.append([side[0], side[1], side[0] + side[1]])
		out.append(per)
	return out
