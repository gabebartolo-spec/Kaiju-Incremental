extends RefCounted
## Helpers for tests/run_voxel_ao_tests.gd (render plan item 12): the 3x3x3 inside-corner
## fixture, a face's corner levels, how its quad is split, and faces keyed for comparison.

## Expected corner levels, keyed by the corner's sign on the face's two in-plane axes (x, y, z
## order, the normal's axis left out). The back wall's +z face at the inside corner: all four.
const XY_LADDER := {Vector2i(-1, -1): 0, Vector2i(1, -1): 1, Vector2i(-1, 1): 2, Vector2i(1, 1): 3}
## The floor's top at (1, 0, 1): closed back-left, half closed beside the walls, open front-right.
const XZ_FLOOR := {Vector2i(-1, -1): 0, Vector2i(1, -1): 1, Vector2i(-1, 1): 1, Vector2i(1, 1): 3}
## The side wall's -x face at (0, 0, 1): the ground shades its foot, its top is open.
const YZ_GROUND := {Vector2i(-1, -1): 1, Vector2i(-1, 1): 1, Vector2i(1, -1): 3, Vector2i(1, 1): 3}


## A mesher reset to a 3x3x3 grid at the ground (offset 0), every cell drawn as wall (id 1).
static func fixture_mesher(m: CellMesher) -> CellMesher:
	m.dims = Vector3i(3, 3, 3)
	m.offset = Vector3i.ZERO
	var looks := PackedByteArray()
	looks.resize(27)
	looks.fill(1)
	m.looks = looks
	return m


## The fixture: a full floor (y 0); at y 1 a back wall (z 0) and a side wall (x 0).
static func inside_corner() -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(27)
	for i: int in 9:
		cells[i] = 1
	for x: int in 3:
		cells[x + 9] = 1
	for z: int in [1, 2]:
		cells[z * 3 + 9] = 1
	return cells


## The levels (0..3) of the corners of `cell`'s face towards `normal`, keyed as XY_LADDER.
static func corner_levels(
	m: CellMesher, arrays: Array, cell: Vector3i, normal: Vector3i
) -> Dictionary:
	var verts: PackedVector3Array = arrays[0]
	var uv: PackedVector2Array = arrays[4]
	var centre := m.origin + Vector3(cell) * m.voxel + Vector3(normal) * m.voxel * 0.5
	var axes: Array[int] = []
	for a: int in 3:
		if normal[a] == 0:
			axes.append(a)
	var out := {}
	for at: int in range(0, verts.size(), 4):
		var mid := (verts[at] + verts[at + 1] + verts[at + 2] + verts[at + 3]) * 0.25
		if not mid.is_equal_approx(centre):
			continue
		for q: int in 4:
			var o := verts[at + q] - centre
			out[Vector2i(signi(roundi(o[axes[0]] * 1000)), signi(roundi(o[axes[1]] * 1000)))] = (roundi(
				uv[at + q].x * 3.0
			))
	return out


## How the quads are split: [faces split along their darker diagonal, along 0-2, along 1-3].
static func splits(uv: PackedVector2Array, index: PackedInt32Array) -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	for f: int in uv.size() / 4:
		var lv: Array[int] = []
		for q: int in 4:
			lv.append(roundi(uv[f * 4 + q].x * 3.0))
		var first := [index[f * 6], index[f * 6 + 1], index[f * 6 + 2]]
		var shared_02 := first.has(f * 4) and first.has(f * 4 + 2)
		shared_02 = shared_02 and index.slice(f * 6 + 3, f * 6 + 6).has(f * 4)
		if shared_02:
			out[1] += 1
			out[0] += int(lv[0] + lv[2] < lv[1] + lv[3])
		else:
			out[2] += 1
			out[0] += int(lv[1] + lv[3] < lv[0] + lv[2])
	return out


## Face key (first corner on a 1/64 grid, normal) -> its four UVs, over every region.
static func cell_uvs(m: CellMesher, cells: PackedByteArray) -> Dictionary:
	var out := {}
	for r: Vector3i in m.all_regions():
		var arrays := m.mesh_region(cells, r)
		if arrays.size() > 4:
			_uvs(arrays[0], arrays[1], arrays[4], out)
	return out


## The same for a baked mesh (empty when it has no UV).
static func mesh_uvs(mesh: ArrayMesh) -> Dictionary:
	var out := {}
	if mesh == null or mesh.get_surface_count() == 0:
		return out
	var a := mesh.surface_get_arrays(0)
	if a[Mesh.ARRAY_TEX_UV] == null:
		return out
	_uvs(a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_TEX_UV], out)
	return out


static func _uvs(
	verts: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array, into: Dictionary
) -> void:
	for q: int in range(0, verts.size(), 4):
		into[[Vector3i((verts[q] * 64.0).round()), Vector3i(normals[q])]] = uv.slice(q, q + 4)


## Baked faces against the cell mesh's: [shared, finish differs, AO off] where AO off is unequal
## (equal) or lighter than the cell mesh's (not equal: the shell, whose hollow is solid).
static func compare(baked: Dictionary, cells: Dictionary, equal: bool) -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	for key: Array in baked:
		if not cells.has(key):
			continue
		out[0] += 1
		var b: PackedVector2Array = baked[key]
		var c: PackedVector2Array = cells[key]
		var finish_off := false
		var ao_off := false
		for q: int in 4:
			finish_off = finish_off or roundi(b[q].y) != roundi(c[q].y)
			var d := b[q].x - c[q].x
			ao_off = ao_off or (absf(d) > 1e-6 if equal else d > 1e-6)
		out[1] += int(finish_off)
		out[2] += int(ao_off)
	return out


## [ao_strength, ao_light_affect, finish_on] of a building view's shell material (-1 / false
## when a uniform was never set).
static func uniforms(view: BuildingView) -> Array:
	var mat: ShaderMaterial = null
	for child: Node in view.get_children():
		if child is MeshInstance3D:
			mat = (child as MeshInstance3D).material_override as ShaderMaterial
			break
	var out := []
	for name: String in ["ao_strength", "ao_light_affect"]:
		var v: Variant = mat.get_shader_parameter(name) if mat != null else null
		out.append(float(v) if v != null else -1.0)
	var on: Variant = mat.get_shader_parameter("finish_on") if mat != null else null
	out.append(on == true)
	return out
