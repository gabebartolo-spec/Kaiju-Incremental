class_name VoxelSettleCache
extends RefCounted
## VoxelFrame.settle() without the full flood (b2-3: the ground flood and floor loads were 60-90 %
## of the worst sim steps). After a full settle that left nothing to fall, the grid is one
## grounded part with no island, and this keeps what the next settle needs: the part's loads per
## level and the box of its supported cells per level. The cells a carve removes since then
## (VoxelFrame records them) are taken out, and two searches stand in for the flood:
##  - structure: every surviving structural cell that touched a removed one must still be joined
##    to the others (and, if a layer-0 cell went, to a layer-0 cell) through structural cells by
##    faces. A cell that lost no path joins the same part as before, so none is cut off the ground
##    and the part is not split;
##  - fixtures: every surviving fixture that touched a removed cell must still reach a structural
##    cell through fixtures (any touch).
## The loads are then updated and the topple rule runs over them (VoxelSupport.scan_levels, the
## code the full settle runs). A search that fails or runs past SEARCH_LIMIT, a topple, a grid
## changed behind its back (a hash of the cells is checked) or more than one part: false, and the
## caller does the full settle, which also rebuilds this. The result is always what the full
## settle gives; tests/lib/settle_replay.gd replays seeded carves against it. Pure and
## deterministic: integers and fixed scan order.

## Cells a search visits at most before it gives up (a limit on time, never on the result).
const SEARCH_LIMIT := 40000
## Fixtures visited at most per surviving fixture that must still reach the structure.
const PANE_LIMIT := 600

## False once anything the next settle needs is out of step; the caller then settles in full.
var valid := false
## Settles by the cache, full settles that built it, of those that found nothing to fall, and why
## the fast path gave up, by reason (tests and benchmarks).
var fast := 0
var full := 0
var quiet := 0
var why: Dictionary = {}
var removed := 0  # cells taken out by fast settles

var _hash := 0
var _built := false
# The frame being settled (set by try_fast): its cells while they are edited here, the fixture
# flags and the grid's size.
var _cells := PackedByteArray()
var _fix := PackedByteArray()
var _w := 0
var _d := 0
var _h := 0
var _plan := 0
# Per cell: the stamp of the search that last visited it and of the one that wants it reached.
# Shared by every cache (one search runs at a time), so each grid does not keep its own.
static var _seen := PackedInt32Array()
static var _goal := PackedInt32Array()
static var _stamp := 0
var _mass := PackedInt64Array()  # per level: cells, sums of 2x + 1 and 2z + 1 (not cumulative)
var _sx := PackedInt64Array()
var _sz := PackedInt64Array()
var _count_x := PackedInt32Array()  # per level and column: supported structural cells
var _count_z := PackedInt32Array()
var _box := PackedInt32Array()  # per level: x0, z0, x1, z1 of the supported cells (x1 < 0: none)
var _dirty := PackedByteArray()  # per level: box out of date


## The frame was just settled in full with `events` falls: if the grid is `parts` part(s) joined
## to the ground, later settles can be fast (a load still tipping is found by the same scan the
## full settle runs). `cells` is the grid as it now stands.
func adopt(cells: PackedByteArray, parts: int, events: int) -> void:
	quiet += 1 if events == 0 else 0
	valid = parts == 1
	_hash = hash(cells)
	_built = false
	full += 1


## The settle of `f` with the cells it has lost since the cache was made, or false if the full
## settle must run (f.cells is then left as it should be: those cells empty).
func try_fast(f: VoxelFrame) -> bool:
	if not valid:
		return _fail("invalid")
	_take(f)
	var gone := f.gone
	var n := gone.size()
	for k: int in n:
		_cells[gone[k]] = f.gone_mats[k]
	if hash(_cells) != _hash:
		return _stop(f, 0, "hash")
	for k: int in n:
		var i := gone[k]
		if _built:  # the loads lose it (else they are built below, from the grid without it)
			_take_out(i, Vector3i(i % _w, i / _plan, (i / _w) % _d), _fix[_cells[i]] != 0)
		_cells[i] = 0
	if not _structure_holds(gone, f.gone_mats):
		return _stop(f, n, "cut")
	if not _panes_hold(gone):
		return _stop(f, n, "pane")
	if not _built:
		_build()
	_refresh_boxes()
	var mass := PackedInt64Array()
	var sx := PackedInt64Array()
	var sz := PackedInt64Array()
	mass.resize(_h + 1)
	sx.resize(_h + 1)
	sz.resize(_h + 1)
	for y: int in range(_h - 1, -1, -1):
		mass[y] = mass[y + 1] + _mass[y]
		sx[y] = sx[y + 1] + _sx[y]
		sz[y] = sz[y + 1] + _sz[y]
	if not VoxelSupport.scan_levels(mass, sx, sz, _box, 1, _h, f.offset, f.res).is_empty():
		return _stop(f, n, "topple")
	f.cells = _cells
	_cells = PackedByteArray()
	_hash = hash(f.cells)
	removed += n
	fast += 1
	return true


## Builds the loads of `f` (settled, nothing lost since) now, so its next settle need not.
func prime(f: VoxelFrame) -> void:
	if valid and not _built and hash(f.cells) == _hash:
		_take(f)
		_build()
		_cells = PackedByteArray()


func _take(f: VoxelFrame) -> void:
	_cells = f.cells
	_fix = f.fixtures
	_w = f.w
	_d = f.d
	_h = f.h
	_plan = _w * _d
	if _seen.size() < _cells.size():
		_seen.resize(_cells.size())
		_goal.resize(_cells.size())


func _fail(reason: String) -> bool:
	why[reason] = Num.i(why.get(reason, 0)) + 1
	return false


## Gives up: the cells the fast path had not yet taken out are emptied again, and the frame keeps
## the grid it should have.
func _stop(f: VoxelFrame, from: int, reason: String) -> bool:
	for k: int in range(from, f.gone.size()):
		_cells[f.gone[k]] = 0
	f.cells = _cells
	_cells = PackedByteArray()
	valid = false
	return _fail(reason)


## The loads of the whole grid (it is one grounded part with no island).
func _build() -> void:
	_mass.resize(_h)
	_sx.resize(_h)
	_sz.resize(_h)
	_mass.fill(0)
	_sx.fill(0)
	_sz.fill(0)
	_count_x.resize(_h * _w)
	_count_z.resize(_h * _d)
	_count_x.fill(0)
	_count_z.fill(0)
	_box.resize(_h * 4)
	_dirty.resize(_h)
	var i := 0
	for y: int in _h:
		var count := 0
		var sum_x := 0
		var sum_z := 0
		for z: int in _d:
			for x: int in _w:
				var m := _cells[i]
				if m != 0:
					count += 1
					sum_x += 2 * x + 1
					sum_z += 2 * z + 1
					if y > 0 and _fix[m] == 0:
						var below := _cells[i - _plan]
						if below != 0 and _fix[below] == 0:
							_count_x[y * _w + x] += 1
							_count_z[y * _d + z] += 1
				i += 1
		_mass[y] = count
		_sx[y] = sum_x
		_sz[y] = sum_z
		_dirty[y] = 1
	_refresh_boxes()
	_built = true


## Level `y`'s box from its column counts, for the levels that changed.
func _refresh_boxes() -> void:
	for y: int in _h:
		if _dirty[y] == 0:
			continue
		_dirty[y] = 0
		var x0 := -1
		var x1 := -1
		for x: int in _w:
			if _count_x[y * _w + x] > 0:
				if x0 < 0:
					x0 = x
				x1 = x + 1
		var z0 := -1
		var z1 := -1
		for z: int in _d:
			if _count_z[y * _d + z] > 0:
				if z0 < 0:
					z0 = z
				z1 = z + 1
		var b := y * 4
		_box[b] = x0
		_box[b + 1] = z0
		_box[b + 2] = x1
		_box[b + 3] = z1


## Cell `i` (at `at`) leaves the loads; it is still in the cells, so its neighbours read as they
## stood.
func _take_out(i: int, at: Vector3i, fixture: bool) -> void:
	_mass[at.y] -= 1
	_sx[at.y] -= 2 * at.x + 1
	_sz[at.y] -= 2 * at.z + 1
	if fixture:
		return
	if at.y > 0:
		var below := _cells[i - _plan]
		if below != 0 and _fix[below] == 0:  # it was in its level's box
			_count_x[at.y * _w + at.x] -= 1
			_count_z[at.y * _d + at.z] -= 1
			_dirty[at.y] = 1
	if at.y < _h - 1:
		var above := _cells[i + _plan]
		if above != 0 and _fix[above] == 0:  # it stood on this cell
			_count_x[(at.y + 1) * _w + at.x] -= 1
			_count_z[(at.y + 1) * _d + at.z] -= 1
			_dirty[at.y + 1] = 1


## The face neighbours of cell `j` inside the grid.
func _faces(j: int) -> Array[int]:
	var out: Array[int] = []
	var x := j % _w
	var z := (j / _w) % _d
	var y := j / _plan
	if x > 0:
		out.append(j - 1)
	if x < _w - 1:
		out.append(j + 1)
	if z > 0:
		out.append(j - _w)
	if z < _d - 1:
		out.append(j + _w)
	if y > 0:
		out.append(j - _plan)
	if y < _h - 1:
		out.append(j + _plan)
	return out


## True when the structural cells left touching the ones removed are still all one piece (and,
## if a cell of layer 0 went, joined to the layer). `mats` are what the removed cells held.
func _structure_holds(gone: PackedInt32Array, mats: PackedByteArray) -> bool:
	_stamp += 1
	var wanted := 0
	var start := -1
	var on_ground := false
	for k: int in gone.size():
		if _fix[mats[k]] != 0:
			continue
		on_ground = on_ground or gone[k] < _plan
		for j: int in _faces(gone[k]):
			var m := _cells[j]
			if m != 0 and _fix[m] == 0 and _goal[j] != _stamp:
				_goal[j] = _stamp
				wanted += 1
				start = j if start < 0 else start
	if wanted == 0:
		return true
	var grounded := not on_ground
	var stack := PackedInt32Array([start])
	_seen[start] = _stamp
	var visited := 0
	while not stack.is_empty():
		var j: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		visited += 1
		if visited > SEARCH_LIMIT:
			return false
		if _goal[j] == _stamp:
			_goal[j] = 0
			wanted -= 1
		grounded = grounded or j < _plan
		if wanted == 0 and grounded:
			return true
		for k: int in _faces(j):
			var m := _cells[k]
			if m != 0 and _fix[m] == 0 and _seen[k] != _stamp:
				_seen[k] = _stamp
				stack.append(k)
	return false


## True when every fixture left touching a removed cell still reaches a structural cell through
## fixtures (any touch: a face, an edge or a corner).
func _panes_hold(gone: PackedInt32Array) -> bool:
	var checked := {}  # fixtures known to be attached
	for r: int in gone:
		for j: int in _touching(r):
			var m := _cells[j]
			if m != 0 and _fix[m] != 0 and not checked.has(j) and not _attached(j, checked):
				return false
	return true


## The cells (up to 26) around cell `i` inside the grid.
func _touching(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % _w
	var z := (i / _w) % _d
	var y := i / _plan
	for dy: int in range(maxi(-y, -1), mini(_h - y, 2)):
		for dz: int in range(maxi(-z, -1), mini(_d - z, 2)):
			for dx: int in range(maxi(-x, -1), mini(_w - x, 2)):
				if dx != 0 or dy != 0 or dz != 0:
					out.append(i + dx + dz * _w + dy * _plan)
	return out


## Fixture `start` reaches a structural cell through fixtures; every fixture on the way is
## then known to (recorded in `checked`).
func _attached(start: int, checked: Dictionary) -> bool:
	var seen := {start: true}
	var stack: Array[int] = [start]
	while not stack.is_empty() and seen.size() <= PANE_LIMIT:
		var j: int = stack.pop_back()
		for k: int in _touching(j):
			var m := _cells[k]
			if m == 0 or seen.has(k):
				continue
			if _fix[m] == 0 or checked.has(k):
				for done: Variant in seen:
					checked[done] = true
				return true
			seen[k] = true
			stack.append(k)
	return false
