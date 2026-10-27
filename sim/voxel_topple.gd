class_name VoxelTopple
extends RefCounted
## The topple rule behind VoxelSupport.topple() and VoxelSupport.landing() (split out of
## VoxelSupport to keep files small): per grounded part and level, the load at or above it, and
## the tip test that says whether a centre of mass hanging past a box topples over its edge.
## Static and pure: centres of mass are compared in integers (sums of 2x + 1), so the outcome is
## exact. The native pass (KaijuSettle "floors") gives what floors() gives; this stays the
## reference.


## Per grounded part and level: the load at or above it (mass, sums of 2x + 1 and 2z + 1, at
## k * (h + 1) + y) and the box [x0, z0, x1, z1) of its cells standing on a cell below (at
## (k * h + y) * 4; x1 < 0 when there are none). `labels` is VoxelSupport.labels over `cells` (a
## grid of `dims`), `fix` the fixture table, `count` the number of grounded parts.
static func floors(
	cells: PackedByteArray,
	fix: PackedByteArray,
	labels: PackedInt32Array,
	dims: Vector3i,
	count: int
) -> Dictionary:
	var w := dims.x
	var d := dims.z
	var h := dims.y
	var plan := w * d
	var mass := PackedInt64Array()
	mass.resize(count * (h + 1))
	var sx := mass.duplicate()
	var sz := mass.duplicate()
	var box := PackedInt32Array()
	box.resize(count * h * 4)
	box.fill(-1)
	for i: int in cells.size():
		var k := labels[i] - 1
		if k < 0 or cells[i] == VoxelFrame.EMPTY:
			continue
		var x := i % w
		var z := (i / w) % d
		var y := i / plan
		var at := k * (h + 1) + y
		mass[at] += 1
		sx[at] += 2 * x + 1
		sz[at] += 2 * z + 1
		var below := cells[i - plan] if y > 0 else VoxelFrame.EMPTY
		if below != VoxelFrame.EMPTY and fix[below] == 0 and fix[cells[i]] == 0:
			_widen(box, (k * h + y) * 4, x, z)
	_stack_up(mass, sx, sz, count, h)
	return {"mass": mass, "sx": sx, "sz": sz, "box": box}


## Grows the box record at `b` of `box` to take in the cell column (x, z).
static func _widen(box: PackedInt32Array, b: int, x: int, z: int) -> void:
	var fresh := box[b + 2] < 0
	box[b] = x if fresh else mini(box[b], x)
	box[b + 1] = z if fresh else mini(box[b + 1], z)
	box[b + 2] = x + 1 if fresh else maxi(box[b + 2], x + 1)
	box[b + 3] = z + 1 if fresh else maxi(box[b + 3], z + 1)


## Turns each part's per-level loads into loads at or above each level (top level down).
static func _stack_up(
	mass: PackedInt64Array, sx: PackedInt64Array, sz: PackedInt64Array, count: int, h: int
) -> void:
	for k: int in count:
		for y: int in range(h - 1, -1, -1):
			var at := k * (h + 1) + y
			mass[at] += mass[at + 1]
			sx[at] += sx[at + 1]
			sz[at] += sz[at + 1]


## The topple rule over per-part, per-level loads (the layout floors documents), for `parts`
## grounded parts in a grid `h` cells tall whose cell 0 is building-local `offset` at `res`
## cells a unit.
static func scan_levels(
	mass: PackedInt64Array,
	sx: PackedInt64Array,
	sz: PackedInt64Array,
	box: PackedInt32Array,
	parts: int,
	h: int,
	offset: Vector3i,
	res: int
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: int in parts:
		for level: int in range(1, h):
			var at := k * (h + 1) + level
			if mass[at] == 0:
				break
			var b := (k * h + level) * 4
			if box[b + 2] < 0:
				continue  # nothing stands on a cell below at this level
			var rect := Rect2i(box[b], box[b + 1], box[b + 2] - box[b], box[b + 3] - box[b + 1])
			var tip := tip_of(
				PackedInt64Array([sx[at], sz[at], mass[at]]), rect, level, offset, res
			)
			if not tip.is_empty():
				tip["label"] = k + 1
				tip["level"] = level
				out.append(tip)
				break
	return out


## Structure's tip test: a load (sums [2x + 1, 2z + 1, mass]) whose centre lies outside `box`
## (cells) tips over the box edge it passes furthest, at height `y` (cells). {} if inside.
static func tip_of(
	sums: PackedInt64Array, box: Rect2i, y: int, offset: Vector3i, res: int
) -> Dictionary:
	var over_x := _over(sums[0], sums[2], box.position.x, box.end.x)
	var over_z := _over(sums[1], sums[2], box.position.y, box.end.y)
	if over_x == 0 and over_z == 0:
		return {}
	var dir := Vector2i(signi(over_x), 0)
	if absi(over_z) > absi(over_x):
		dir = Vector2i(0, signi(over_z))
	var com := Vector2(sums[0], sums[1]) / (2.0 * sums[2])
	var px := com.x
	if dir.x != 0:
		px = box.end.x if dir.x > 0 else box.position.x
	var pz := com.y
	if dir.y != 0:
		pz = box.end.y if dir.y > 0 else box.position.y
	var pivot := (Vector3(px, y, pz) + Vector3(offset)) / res
	return {"kind": "topple", "pivot": pivot, "dir": dir}


## How far (in 1 / (2 mass) cells) a centre with sum `s` lies past [lo, hi); 0 if inside.
static func _over(s: int, mass: int, lo: int, hi: int) -> int:
	if s > 2 * hi * mass:
		return s - 2 * hi * mass
	if s < 2 * lo * mass:
		return s - 2 * lo * mass
	return 0
