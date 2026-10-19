extends RefCounted
## TEMPORARY, delete when WP1's fixture rule lands: a test-side copy of the ground flood the
## carving sim will use (sim/voxel_support.gd on claude/carve-wp1), with the fixture rule added
## (D-094 WP3 review FIX). Once VoxelSupport has the rule, the cells suite floods with
## VoxelFrame.adopt(...).settle() instead and this file goes.
##
## The rule: grid y 0 is the ground. A structural cell is grounded when it shares a face with a
## grounded cell (6 neighbours). A fixture cell (data/materials.json "fixture": true: panes,
## mullions, signs; attached parts that hang off the wall) is grounded when it touches a
## grounded cell by a face, an edge or a corner (26 neighbours).

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


## Indices of every cell of `cells` (dims, x fastest, then z, then y) not joined to the ground.
## fixture: as fixture_ids(); all zeros floods 6-connected only, as VoxelSupport does today.
static func ungrounded(
	dims: Vector3i, cells: PackedByteArray, fixture: PackedByteArray
) -> PackedInt32Array:
	var grounded := PackedByteArray()
	grounded.resize(cells.size())
	var stack := PackedInt32Array()
	for i: int in dims.x * dims.z:
		if cells[i] != 0:
			grounded[i] = 1
			stack.append(i)
	_face_flood(dims, cells, grounded, stack)
	# Fixtures that touch a grounded cell only by an edge or a corner, until none is left.
	var waiting := PackedInt32Array()
	for i: int in cells.size():
		if cells[i] != 0 and grounded[i] == 0 and fixture[cells[i]] == 1:
			waiting.append(i)
	var changed := true
	while changed:
		changed = false
		var still := PackedInt32Array()
		for i: int in waiting:
			if grounded[i] == 1:
				continue
			if _touches_grounded(dims, grounded, i):
				grounded[i] = 1
				_face_flood(dims, cells, grounded, PackedInt32Array([i]))
				changed = true
			else:
				still.append(i)
		waiting = still
	var out := PackedInt32Array()
	for i: int in cells.size():
		if cells[i] != 0 and grounded[i] == 0:
			out.append(i)
	return out


static func _face_flood(
	dims: Vector3i, cells: PackedByteArray, grounded: PackedByteArray, stack: PackedInt32Array
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
			if n >= 0 and grounded[n] == 0 and cells[n] != 0:
				grounded[n] = 1
				stack.append(n)


static func _touches_grounded(dims: Vector3i, grounded: PackedByteArray, i: int) -> bool:
	var plan := dims.x * dims.z
	var c := Vector3i(i % dims.x, i / plan, (i / dims.x) % dims.z)
	for step: Vector3i in DIAGONAL:
		var n := c + step
		if n.x >= 0 and n.y >= 0 and n.z >= 0 and n.x < dims.x and n.y < dims.y and n.z < dims.z:
			if grounded[n.x + n.z * dims.x + n.y * plan] == 1:
				return true
	return false
