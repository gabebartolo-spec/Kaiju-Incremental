class_name VoxelSupport
extends RefCounted
## The ground flood and the support rule behind VoxelFrame.settle() (split out to keep files
## small). Made fresh for each settle: it labels every 6-connected structural part joined to the
## ground floor, grid layer 0 (1, 2, ... in scan order of its first ground cell; 0 not
## grounded). Fixtures (VoxelFrame.fixtures: panes, signs) then join a part when they touch it,
## or a fixture already joined, by a face, an edge or a corner (26 neighbours), or stand on
## layer 0; they never carry a structural cell (lead rule on #97). It then answers:
##  - islands(): the ungrounded parts, scan order (Teardown's split); two cells are in one
##    part when they share a face, or touch at all and one of them is a fixture;
##  - landing(part): an island lands on the columns with the smallest gap below it; hung past
##    them it topples over their edge, else it drops;
##  - topple(): Structure._topple_check per grounded part: the lowest level whose load (the
##    part's cells at or above it) has its centre of mass outside the box of the structural
##    cells there standing on a structural cell below (fixtures weigh but hold nothing).
## Centres of mass are compared in integers (sums of 2x + 1), so the outcome is exact (the rule
## itself is VoxelTopple's).

## The native flood (native/src/kaiju_settle.cpp, KaijuSettle) does the whole-grid passes of this
## class when the extension is loaded, and gives what the GDScript below gives, which stays the
## reference: the "native port must match its digests" rule, held by tests/lib/settle_replay.gd,
## which switches this off to settle the same carves both ways.
static var use_native := true
static var _native: Object = null

## Per cell: the grounded part's label (> 0), 0 for not grounded, -1 once taken by an island.
var labels := PackedInt32Array()
var count := 0
var _f: VoxelFrame
var _cells: PackedByteArray
var _fix: PackedByteArray
var _solid := PackedByteArray()  # per material id: 1 when structural (not empty, not a fixture)
var _plan: int


func _init(frame: VoxelFrame) -> void:
	_f = frame
	_cells = frame.cells
	_fix = frame.fixtures
	_plan = frame.w * frame.d
	var nat := VoxelSupport.native()
	if nat != null:
		var got: Array = nat.call("label", _cells, _fix, _dims(), frame.has_fixtures)
		labels = got[0]
		count = got[1]
		return
	labels.resize(_cells.size())
	_solid.resize(256)
	for m: int in range(1, 256):
		_solid[m] = 1 if _fix[m] == 0 else 0
	var stack := PackedInt32Array()
	stack.resize(_cells.size())
	for start: int in _plan:
		var m := _cells[start]
		if m != VoxelFrame.EMPTY and _fix[m] == 0 and labels[start] == 0:
			count += 1
			labels[start] = count
			stack[0] = start
			_flood(stack, count)
	if frame.has_fixtures:
		_attach_fixtures(stack)


## The native flood, or null (switched off, or the extension is not loaded).
static func native() -> Object:
	if not use_native:
		return null
	if _native == null and ClassDB.class_exists("KaijuSettle"):
		_native = ClassDB.instantiate("KaijuSettle")
	return _native


func _dims() -> Vector3i:
	return Vector3i(_f.w, _f.h, _f.d)


## Floods `label` over every structural unlabelled cell joined to stack[0] (iterative, packed stack;
## the neighbours written out: an array per cell costs the flood about a third more).
func _flood(stack: PackedInt32Array, label: int) -> void:
	var top := 1
	while top > 0:
		top -= 1
		var i := stack[top]
		top = _spread_x(stack, top, i, label)
		top = _spread_z(stack, top, i, label)
		top = _spread_y(stack, top, i, label)


## Labels and pushes the structural unlabelled neighbours of cell `i` along x (x - 1, x + 1);
## returns the new top of the stack.
func _spread_x(stack: PackedInt32Array, top: int, i: int, label: int) -> int:
	var x := i % _f.w
	if x > 0 and labels[i - 1] == 0 and _solid[_cells[i - 1]] != 0:
		labels[i - 1] = label
		stack[top] = i - 1
		top += 1
	if x < _f.w - 1 and labels[i + 1] == 0 and _solid[_cells[i + 1]] != 0:
		labels[i + 1] = label
		stack[top] = i + 1
		top += 1
	return top


## As _spread_x, along z (z - 1, z + 1).
func _spread_z(stack: PackedInt32Array, top: int, i: int, label: int) -> int:
	var w := _f.w
	var z := (i / w) % _f.d
	if z > 0 and labels[i - w] == 0 and _solid[_cells[i - w]] != 0:
		labels[i - w] = label
		stack[top] = i - w
		top += 1
	if z < _f.d - 1 and labels[i + w] == 0 and _solid[_cells[i + w]] != 0:
		labels[i + w] = label
		stack[top] = i + w
		top += 1
	return top


## As _spread_x, along y (y - 1, y + 1).
func _spread_y(stack: PackedInt32Array, top: int, i: int, label: int) -> int:
	var y := i / _plan
	if y > 0 and labels[i - _plan] == 0 and _solid[_cells[i - _plan]] != 0:
		labels[i - _plan] = label
		stack[top] = i - _plan
		top += 1
	if y < _f.h - 1 and labels[i + _plan] == 0 and _solid[_cells[i + _plan]] != 0:
		labels[i + _plan] = label
		stack[top] = i + _plan
		top += 1
	return top


## Joins each fixture to a grounded part: scan order, a fixture touching a labelled cell takes
## its label (one on layer 0 touching none starts a new part), then floods it over the fixtures
## it touches (26 neighbours). Fixtures never pass a label on to a structural cell.
func _attach_fixtures(stack: PackedInt32Array) -> void:
	for start: int in _cells.size():
		var m := _cells[start]
		if m == VoxelFrame.EMPTY or _fix[m] == 0 or labels[start] != 0:
			continue
		var label := _fixture_label(start)
		if label == 0:
			# Lead rule (#97): a fixture on grid layer 0 is grounded though it touches nothing else
			# (a ground-floor shopfront rests on the street).
			if start >= _plan:
				continue
			count += 1
			label = count
		labels[start] = label
		_flood_fixtures(stack, start, label)


## The label of the first labelled cell round fixture `start` (ring order), or 0 when none.
func _fixture_label(start: int) -> int:
	var ring := _ring(start)
	for r: int in range(0, ring.size(), 2):
		if labels[ring[r]] > 0:
			return labels[ring[r]]
	return 0


## Floods `label` from fixture `start` over the unlabelled fixtures it touches (26 neighbours).
func _flood_fixtures(stack: PackedInt32Array, start: int, label: int) -> void:
	stack[0] = start
	var top := 1
	while top > 0:
		top -= 1
		var around := _ring(stack[top])
		for r: int in range(0, around.size(), 2):
			var n := around[r]
			if labels[n] == 0 and _cells[n] != VoxelFrame.EMPTY and _fix[_cells[n]] != 0:
				labels[n] = label
				stack[top] = n
				top += 1


## The 26 neighbours of cell `i` inside the grid, as pairs [index, 1 if it shares a face].
func _ring(i: int) -> PackedInt32Array:
	var w := _f.w
	var d := _f.d
	var x := i % w
	var z := (i / w) % d
	var y := i / _plan
	var out := PackedInt32Array()
	for dy: int in range(maxi(-y, -1), mini(_f.h - y, 2)):
		for dz: int in range(maxi(-z, -1), mini(d - z, 2)):
			for dx: int in range(maxi(-x, -1), mini(w - x, 2)):
				var step := absi(dx) + absi(dy) + absi(dz)
				if step > 0:
					out.append(i + dx + dz * w + dy * _plan)
					out.append(int(step == 1))
	return out


## Every alive, ungrounded cell, split into islands (scan order of first cell,
## cells in flood order; joined as the header says); marks them -1. The caller removes them.
func islands() -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var nat := VoxelSupport.native()
	if nat != null:  # the labels stay as they were: the caller takes these cells out of the grid
		var got: Array = nat.call("islands", labels, _cells, _fix, _dims(), _f.has_fixtures)
		out.assign(got)
		return out
	for start: int in _cells.size():
		if _cells[start] != VoxelFrame.EMPTY and labels[start] == 0:
			out.append(_grow(start))
	return out


## The island holding cell `start`, its cells in flood order, marked -1.
func _grow(start: int) -> PackedInt32Array:
	var part := PackedInt32Array([start])
	labels[start] = -1
	var k := 0
	while k < part.size():
		var i := part[k]
		k += 1
		if _f.has_fixtures:
			_join(i, part)
		else:
			_join_faces(i, part)
	return part


## Adds to `part` the unclaimed cells sharing a face with `i` (a grid with no fixtures).
func _join_faces(i: int, part: PackedInt32Array) -> void:
	var w := _f.w
	var x := i % w
	var z := (i / w) % _f.d
	var y := i / _plan
	for n: int in [
		i - 1 if x > 0 else -1,
		i + 1 if x < w - 1 else -1,
		i - w if z > 0 else -1,
		i + w if z < _f.d - 1 else -1,
		i - _plan if y > 0 else -1,
		i + _plan if y < _f.h - 1 else -1,
	]:
		if n >= 0 and labels[n] == 0 and _cells[n] != VoxelFrame.EMPTY:
			labels[n] = -1
			part.append(n)


## Adds to `part` the unclaimed neighbours of `i` it is joined to: a face, or any touch when
## either cell is a fixture.
func _join(i: int, part: PackedInt32Array) -> void:
	var loose := _fix[_cells[i]] != 0
	var ring := _ring(i)
	for r: int in range(0, ring.size(), 2):
		var n := ring[r]
		if labels[n] != 0 or _cells[n] == VoxelFrame.EMPTY:
			continue
		if loose or ring[r + 1] == 1 or _fix[_cells[n]] != 0:
			labels[n] = -1
			part.append(n)


## Where an island (already removed from the grid) lands: {kind, pivot, dir}.
func landing(part: PackedInt32Array) -> Dictionary:
	var nat := VoxelSupport.native()
	if nat != null:
		return _land_native(nat, part)
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
	return tip if not tip.is_empty() else _plain_drop()


## KaijuSettle's landing of `part` (its lowest cells per column), read as landing() reads its own.
func _land_native(nat: Object, part: PackedInt32Array) -> Dictionary:
	var r: PackedInt64Array = nat.call("land", part, _f.cells, _dims())
	var at := _tip(
		PackedInt64Array([r[0], r[1], r[2]]), Rect2i(r[3], r[4], r[5] - r[3], r[6] - r[4]), r[7]
	)
	return at if not at.is_empty() else _plain_drop()


static func _plain_drop() -> Dictionary:
	return {"kind": "drop", "pivot": Vector3.ZERO, "dir": Vector2i.ZERO}


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
	return VoxelTopple.scan_levels(mass, sx, sz, box, count, _f.h, _f.offset, _f.res)


## Per grounded part and level, the loads and support boxes (VoxelTopple.floors documents the
## layout): from the native pass, or the GDScript reference.
func _floors() -> Dictionary:
	var nat := VoxelSupport.native()
	if nat != null:
		return nat.call("floors", labels, _cells, _fix, _dims(), count)
	return VoxelTopple.floors(_cells, _fix, labels, _dims(), count)


## Structure's tip test (VoxelTopple.tip_of) for a load over `box` (cells) at height `y` (cells).
func _tip(sums: PackedInt64Array, box: Rect2i, y: int) -> Dictionary:
	return VoxelTopple.tip_of(sums, box, y, _f.offset, _f.res)
