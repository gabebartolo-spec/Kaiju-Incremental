class_name CarveMesh
extends RefCounted
## Meshes a set of grid cells as voxel cubes: only the faces that border a cell outside `solid`
## are drawn, each wound clockwise from outside with its outward normal (the destruction spike's
## first clip had inverted normals: faces vanished from outside). Colours by material, with a
## faint per-cell shade so a flat wall reads as voxels. Shared by island bodies and captures.

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
const SHADE_MIN := 0.9  # the darkest a cell is shaded, of its material colour

static var _material: StandardMaterial3D


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
	var solid: PackedByteArray = src[1]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var s := 1.0 / site.res
	var base := site.origin - offset
	for k: int in cells.size():
		var c := site.cell(cells[k])
		var col := site.color(mats[k])
		var shade := SHADE_MIN + (1.0 - SHADE_MIN) * posmod(c.x * 7 + c.y * 13 + c.z * 3, 5) / 4.0
		col = Color(col.r * shade, col.g * shade, col.b * shade)
		var p := base + Vector3(c) * s
		for f: int in 6:
			var q := c + STEPS[f]
			if site.inside(q) and solid[site.index(q)] != 0:
				continue
			var n := Vector3(STEPS[f])
			for v: int in ORDER:
				verts.append(p + CORNERS[f * 4 + v] * s)
				normals.append(n)
				colors.append(col)
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
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
