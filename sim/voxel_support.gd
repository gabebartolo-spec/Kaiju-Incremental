class_name VoxelSupport
extends RefCounted
## The ground flood and the support rule behind VoxelFrame.settle() (split out to keep files
## small). Made fresh for each settle: it labels every 6-connected part joined to the ground
## floor (1, 2, ... in scan order of its first ground cell; 0 not grounded), then answers:
##  - islands(): the ungrounded parts, scan order (Teardown's split);
##  - landing(part): an island lands on the columns with the smallest gap below it; hung past
##    them it topples over their edge, else it drops;
##  - topple(): Structure._topple_check per grounded part: the lowest level whose load (the
##    part's cells at or above it) has its centre of mass outside the box of the cells there
##    standing on a cell below.
## Centres of mass are compared in integers (sums of 2x + 1), so the outcome is exact.

## Per cell: the grounded part's label (> 0), 0 for not grounded, -1 once taken by an island.
var labels := PackedInt32Array()
var count := 0
var _f: VoxelFrame
var _cells: PackedByteArray
var _plan: int


func _init(frame: VoxelFrame) -> void:
	_f = frame
	_cells = frame.cells
	_plan = frame.w * frame.d
	labels.resize(_cells.size())
	var stack := PackedInt32Array()
	stack.resize(_cells.size())
	for start: int in _plan:
		if _cells[start] != VoxelFrame.EMPTY and labels[start] == 0:
			count += 1
			labels[start] = count
			stack[0] = start
			_flood(stack, count)


## Floods `label` over every alive unlabelled cell joined to stack[0] (iterative, packed stack;
## the six neighbours written out: an array per cell costs the flood about a third more).
func _flood(stack: PackedInt32Array, label: int) -> void:
	var w := _f.w
	var d := _f.d
	var h := _f.h
	var plan := _plan
	var top := 1
	while top > 0:
		top -= 1
		var i := stack[top]
		var x := i % w
		var z := (i / w) % d
		var y := i / plan
		if x > 0 and labels[i - 1] == 0 and _cells[i - 1] != 0:
			labels[i - 1] = label
			stack[top] = i - 1
			top += 1
		if x < w - 1 and labels[i + 1] == 0 and _cells[i + 1] != 0:
			labels[i + 1] = label
			stack[top] = i + 1
			top += 1
		if z > 0 and labels[i - w] == 0 and _cells[i - w] != 0:
			labels[i - w] = label
			stack[top] = i - w
			top += 1
		if z < d - 1 and labels[i + w] == 0 and _cells[i + w] != 0:
			labels[i + w] = label
			stack[top] = i + w
			top += 1
		if y > 0 and labels[i - plan] == 0 and _cells[i - plan] != 0:
			labels[i - plan] = label
			stack[top] = i - plan
			top += 1
		if y < h - 1 and labels[i + plan] == 0 and _cells[i + plan] != 0:
			labels[i + plan] = label
			stack[top] = i + plan
			top += 1


## Every alive, ungrounded cell, split into 6-connected islands (scan order of first cell,
## cells in flood order); marks them -1. The caller removes them.
func islands() -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var w := _f.w
	var d := _f.d
	var h := _f.h
	for start: int in _cells.size():
		if _cells[start] == VoxelFrame.EMPTY or labels[start] != 0:
			continue
		var part := PackedInt32Array([start])
		labels[start] = -1
		var k := 0
		while k < part.size():
			var i := part[k]
			k += 1
			var x := i % w
			var z := (i / w) % d
			var y := i / _plan
			for n: int in [
				i - 1 if x > 0 else -1,
				i + 1 if x < w - 1 else -1,
				i - w if z > 0 else -1,
				i + w if z < d - 1 else -1,
				i - _plan if y > 0 else -1,
				i + _plan if y < h - 1 else -1,
			]:
				if n >= 0 and labels[n] == 0 and _cells[n] != VoxelFrame.EMPTY:
					labels[n] = -1
					part.append(n)
		out.append(part)
	return out


## Where an island (already removed from the grid) lands: {kind, pivot, dir}.
func landing(part: PackedInt32Array) -> Dictionary:
	var low: Dictionary = {}
	var sums := PackedInt64Array([0, 0, part.size()])
	for i: int in part:
		var col := i % _plan
		var y := i / _plan
		var was: int = low.get(col, y)
		low[col] = mini(was, y)
		sums[0] += 2 * (col % _f.w) + 1
		sums[1] += 2 * (col / _f.w) + 1
	var gaps: Dictionary = {}
	var least := _f.h
	for col: int in low:
		var bottom: int = low[col]
		var gap := bottom - _f.column_top(col % _f.w, col / _f.w, bottom) - 1
		gaps[col] = gap
		least = mini(least, gap)
	var box := Rect2i()
	var lands := _f.h
	for col: int in gaps:
		var gap: int = gaps[col]
		if gap == least:
			var bottom: int = low[col]
			var at := Rect2i(col % _f.w, col / _f.w, 1, 1)
			box = at if box.size == Vector2i.ZERO else box.merge(at)
			lands = mini(lands, bottom - least)
	var tip := _tip(sums, box, lands)
	if tip.is_empty():
		return {"kind": "drop", "pivot": Vector3.ZERO, "dir": Vector2i.ZERO}
	return tip


## The lowest toppling level of each grounded part, as {kind, pivot, dir, label, level}.
func topple() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if count == 0:
		return out
	var floors := _floors()
	var mass: PackedInt64Array = floors["mass"]
	var sx: PackedInt64Array = floors["sx"]
	var sz: PackedInt64Array = floors["sz"]
	var box: PackedInt32Array = floors["box"]
	var h := _f.h
	for k: int in count:
		for level: int in range(1, h):
			var at := k * (h + 1) + level
			if mass[at] == 0:
				break
			var b := (k * h + level) * 4
			if box[b + 2] < 0:
				continue  # nothing stands on a cell below at this level
			var rect := Rect2i(box[b], box[b + 1], box[b + 2] - box[b], box[b + 3] - box[b + 1])
			var tip := _tip(PackedInt64Array([sx[at], sz[at], mass[at]]), rect, level)
			if not tip.is_empty():
				tip["label"] = k + 1
				tip["level"] = level
				out.append(tip)
				break
	return out


## Per grounded part and level: the load at or above it (mass, sums of 2x + 1 and 2z + 1, at
## k * (h + 1) + y) and the box [x0, z0, x1, z1) of its cells standing on a cell below (at
## (k * h + y) * 4; x1 < 0 when there are none).
func _floors() -> Dictionary:
	var w := _f.w
	var d := _f.d
	var h := _f.h
	var mass := PackedInt64Array()
	mass.resize(count * (h + 1))
	var sx := mass.duplicate()
	var sz := mass.duplicate()
	var box := PackedInt32Array()
	box.resize(count * h * 4)
	box.fill(-1)
	for i: int in _cells.size():
		var k := labels[i] - 1
		if k < 0 or _cells[i] == VoxelFrame.EMPTY:
			continue
		var x := i % w
		var z := (i / w) % d
		var y := i / _plan
		var at := k * (h + 1) + y
		mass[at] += 1
		sx[at] += 2 * x + 1
		sz[at] += 2 * z + 1
		if y > 0 and _cells[i - _plan] != VoxelFrame.EMPTY:
			var b := (k * h + y) * 4
			var fresh := box[b + 2] < 0
			box[b] = x if fresh else mini(box[b], x)
			box[b + 1] = z if fresh else mini(box[b + 1], z)
			box[b + 2] = x + 1 if fresh else maxi(box[b + 2], x + 1)
			box[b + 3] = z + 1 if fresh else maxi(box[b + 3], z + 1)
	for k: int in count:
		for y: int in range(h - 1, -1, -1):
			var at := k * (h + 1) + y
			mass[at] += mass[at + 1]
			sx[at] += sx[at + 1]
			sz[at] += sz[at + 1]
	return {"mass": mass, "sx": sx, "sz": sz, "box": box}


## Structure's tip test: a load (sums [2x + 1, 2z + 1, mass]) whose centre lies outside `box`
## (cells) tips over the box edge it passes furthest, at height `y` (cells). {} if inside.
func _tip(sums: PackedInt64Array, box: Rect2i, y: int) -> Dictionary:
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
	var pivot := (Vector3(px, y, pz) + Vector3(_f.offset)) / _f.res
	return {"kind": "topple", "pivot": pivot, "dir": dir}


## How far (in 1 / (2 mass) cells) a centre with sum `s` lies past [lo, hi); 0 if inside.
static func _over(s: int, mass: int, lo: int, hi: int) -> int:
	if s > 2 * hi * mass:
		return s - 2 * hi * mass
	if s < 2 * lo * mass:
		return s - 2 * lo * mass
	return 0
