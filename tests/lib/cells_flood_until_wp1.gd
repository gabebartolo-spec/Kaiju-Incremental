extends RefCounted
## TEMPORARY, delete when WP1's fixture rule lands: a test-side copy of the ground flood the
## carving sim will use (sim/voxel_support.gd on claude/carve-wp1), with the fixture rule added
## (D-094 WP3 review FIX). Once VoxelSupport has the rule, the cells suite floods with
## VoxelFrame.adopt(...).settle() instead and this file goes.

## The 6 face steps.
const FACES: Array[Vector3i] = [
	Vector3i(-1, 0, 0),
	Vector3i(1, 0, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, 0, -1),
	Vector3i(0, 0, 1),
]

## The 20 edge and corner steps (the 6 face steps are handled on their own).
const DIAGONAL: Array[Vector3i] = [
	Vector3i(-1, -1, -1),
	Vector3i(0, -1, -1),
	Vector3i(1, -1, -1),
	Vector3i(-1, 0, -1),
	Vector3i(1, 0, -1),
	Vector3i(-1, 1, -1),
	Vector3i(0, 1, -1),
	Vector3i(1, 1, -1),
	Vector3i(-1, -1, 0),
	Vector3i(1, -1, 0),
	Vector3i(-1, 1, 0),
	Vector3i(1, 1, 0),
	Vector3i(-1, -1, 1),
	Vector3i(0, -1, 1),
	Vector3i(1, -1, 1),
	Vector3i(-1, 0, 1),
	Vector3i(1, 0, 1),
	Vector3i(-1, 1, 1),
	Vector3i(0, 1, 1),
	Vector3i(1, 1, 1),
]


## Fixture lookup by material id (256 bytes, 1 = fixture), from data/materials.json.
static func fixture_ids() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	for m: Dictionary in Content.materials():
		if m.get("fixture", false) == true:
			out[Num.i(m["id"])] = 1
	return out


## Indices of every cell of `cells` (dims, x fastest, then z, then y) not joined to the ground,
## by WP1's rule exactly (sim/voxel_support.gd): structural cells ground by a 6-face flood over
## structural cells only, from the structural cells of grid layer 0; a fixture is grounded when
## it is on layer 0 or touches (26 neighbours) a grounded cell or grounded fixture, and it never
## passes grounding on to a structural cell.
static func ungrounded(
	dims: Vector3i, cells: PackedByteArray, fixture: PackedByteArray
) -> PackedInt32Array:
	var grounded := PackedByteArray()
	grounded.resize(cells.size())
	var stack := PackedInt32Array()
	for i: int in dims.x * dims.z:
		if cells[i] != 0 and fixture[cells[i]] == 0:
			grounded[i] = 1
			stack.append(i)
	_face_flood(dims, cells, fixture, grounded, stack)
	# Fixtures: layer 0 rests on the street; the rest take a grounded neighbour's footing.
	var front := PackedInt32Array()
	for i: int in cells.size():
		if cells[i] != 0 and fixture[cells[i]] == 1:
			if i < dims.x * dims.z or _touches_grounded(dims, grounded, i):
				grounded[i] = 1
				front.append(i)
	while not front.is_empty():
		var i := front[front.size() - 1]
		front.resize(front.size() - 1)
		for n: int in _around(dims, i):
			if grounded[n] == 0 and cells[n] != 0 and fixture[cells[n]] == 1:
				grounded[n] = 1
				front.append(n)
	var out := PackedInt32Array()
	for i: int in cells.size():
		if cells[i] != 0 and grounded[i] == 0:
			out.append(i)
	return out


## The 26 neighbours of cell i inside the grid.
static func _around(dims: Vector3i, i: int) -> PackedInt32Array:
	var plan := dims.x * dims.z
	var c := Vector3i(i % dims.x, i / plan, (i / dims.x) % dims.z)
	var out := PackedInt32Array()
	for step: Vector3i in DIAGONAL + FACES:
		var n := c + step
		if n.x >= 0 and n.y >= 0 and n.z >= 0 and n.x < dims.x and n.y < dims.y and n.z < dims.z:
			out.append(n.x + n.z * dims.x + n.y * plan)
	return out


static func _face_flood(
	dims: Vector3i,
	cells: PackedByteArray,
	fixture: PackedByteArray,
	grounded: PackedByteArray,
	stack: PackedInt32Array
) -> void:
	var plan := dims.x * dims.z
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % dims.x
		var z := (i / dims.x) % dims.z
		var y := i / plan
		for n: int in [
			i - 1 if x > 0 else -1,
			i + 1 if x < dims.x - 1 else -1,
			i - dims.x if z > 0 else -1,
			i + dims.x if z < dims.z - 1 else -1,
			i - plan if y > 0 else -1,
			i + plan if y < dims.y - 1 else -1,
		]:
			if n >= 0 and grounded[n] == 0 and cells[n] != 0 and fixture[cells[n]] == 0:
				grounded[n] = 1
				stack.append(n)


static func _touches_grounded(
	dims: Vector3i, grounded: PackedByteArray, i: int
) -> bool:
	for n: int in _around(dims, i):
		if grounded[n] == 1:
			return true
	return false
