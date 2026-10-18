class_name CarveGrid
extends RefCounted
@warning_ignore_start("unsafe_method_access", "unsafe_property_access", "unsafe_call_argument", "unsafe_cast", "untyped_declaration", "integer_division", "narrowing_conversion")
## SPIKE (throwaway). Option A's sim side: one building as a fine voxel grid (RES cells per sim
## unit), carved by spheres. After every carve, cells no longer joined to the ground floor are
## split into islands and removed; each island is an event the view turns into a falling body.
## Pure and deterministic: integers only, fixed scan order, no RNG, no Node.

const EMPTY := 0
const WALL := 1
const SLAB := 2
const GLASS := 3
const COLUMN := 4

var res: int
var w: int  # cells
var d: int
var h: int
var origin: Vector3  # world position of cell (0,0,0)'s corner
var cells: PackedByteArray
var alive_count := 0
## Timings of the last carve (usec): carve, flood, islands.
var last_us := Vector3i.ZERO
## Each island's materials, parallel to the islands of the last carve (cells are EMPTY by then).
var island_mats: Array[PackedByteArray] = []


## A hollow office block: shell walls with window bands, a slab per floor, interior columns.
func _init(p_res: int, units: Vector3i, p_origin: Vector3) -> void:
	res = p_res
	w = units.x * res
	d = units.z * res
	h = units.y * res
	origin = p_origin
	cells.resize(w * d * h)
	for y: int in h:
		for z: int in d:
			for x: int in w:
				var edge := x == 0 or z == 0 or x == w - 1 or z == d - 1
				var m := EMPTY
				if y % res == 0:
					m = SLAB
				elif edge:
					var bay := (x + z) % res
					m = GLASS if (y % res >= 2 and bay != 0 and y >= res) else WALL
				elif x % (2 * res) == res and z % (2 * res) == res:
					m = COLUMN
				if m != EMPTY:
					cells[x + z * w + y * w * d] = m
					alive_count += 1


func index(x: int, y: int, z: int) -> int:
	return x + z * w + y * w * d


## World centre of a cell index.
func world(i: int) -> Vector3:
	var plan := w * d
	var c := Vector3(i % w, i / plan, (i / w) % d)
	return origin + (c + Vector3.ONE * 0.5) / res


## Removes every cell inside the sphere. Returns removed cell indices (scan order), then
## detaches islands into `islands` (each a PackedInt32Array of cell indices, scan order).
func carve(centre: Vector3, radius: float, islands: Array[PackedInt32Array]) -> PackedInt32Array:
	var t0 := Time.get_ticks_usec()
	var removed := PackedInt32Array()
	var lo := ((centre - Vector3.ONE * radius - origin) * res).floor()
	var hi := ((centre + Vector3.ONE * radius - origin) * res).ceil()
	var r2 := radius * radius * res * res
	var c := (centre - origin) * res
	for y: int in range(maxi(0, int(lo.y)), mini(h, int(hi.y) + 1)):
		for z: int in range(maxi(0, int(lo.z)), mini(d, int(hi.z) + 1)):
			for x: int in range(maxi(0, int(lo.x)), mini(w, int(hi.x) + 1)):
				var i := x + z * w + y * w * d
				if cells[i] == EMPTY:
					continue
				if Vector3(x + 0.5, y + 0.5, z + 0.5).distance_squared_to(c) <= r2:
					cells[i] = EMPTY
					removed.append(i)
	alive_count -= removed.size()
	var t1 := Time.get_ticks_usec()
	var grounded := PackedByteArray()
	if not removed.is_empty():
		grounded = _grounded()
	var t2 := Time.get_ticks_usec()
	if not removed.is_empty():
		_islands(grounded, islands)
	last_us = Vector3i(t1 - t0, t2 - t1, Time.get_ticks_usec() - t2)
	return removed


## Cells joined to the ground floor (1 each), flooded over the 6 neighbours.
func _grounded() -> PackedByteArray:
	var plan := w * d
	var seen := PackedByteArray()
	seen.resize(plan * h)
	var frontier := PackedInt32Array()
	for i: int in plan:
		if cells[i] != EMPTY:
			seen[i] = 1
			frontier.append(i)
	var top := frontier.size()
	frontier.resize(cells.size())
	while top > 0:
		top -= 1
		var i := frontier[top]
		var x := i % w
		var z := (i / w) % d
		var y := i / plan
		if x > 0 and seen[i - 1] == 0 and cells[i - 1] != EMPTY:
			seen[i - 1] = 1
			frontier[top] = i - 1
			top += 1
		if x < w - 1 and seen[i + 1] == 0 and cells[i + 1] != EMPTY:
			seen[i + 1] = 1
			frontier[top] = i + 1
			top += 1
		if z > 0 and seen[i - w] == 0 and cells[i - w] != EMPTY:
			seen[i - w] = 1
			frontier[top] = i - w
			top += 1
		if z < d - 1 and seen[i + w] == 0 and cells[i + w] != EMPTY:
			seen[i + w] = 1
			frontier[top] = i + w
			top += 1
		if y > 0 and seen[i - plan] == 0 and cells[i - plan] != EMPTY:
			seen[i - plan] = 1
			frontier[top] = i - plan
			top += 1
		if y < h - 1 and seen[i + plan] == 0 and cells[i + plan] != EMPTY:
			seen[i + plan] = 1
			frontier[top] = i + plan
			top += 1
	return seen


## Every alive, ungrounded cell, split into 6-connected islands and removed from the grid.
func _islands(grounded: PackedByteArray, out: Array[PackedInt32Array]) -> void:
	var plan := w * d
	for start: int in cells.size():
		if cells[start] == EMPTY or grounded[start] != 0:
			continue
		var part := PackedInt32Array([start])
		grounded[start] = 1
		var k := 0
		while k < part.size():
			var i := part[k]
			k += 1
			var x := i % w
			var z := (i / w) % d
			var y := i / plan
			for n: int in [
				i - 1 if x > 0 else -1,
				i + 1 if x < w - 1 else -1,
				i - w if z > 0 else -1,
				i + w if z < d - 1 else -1,
				i - plan if y > 0 else -1,
				i + plan if y < h - 1 else -1
			]:
				if n >= 0 and grounded[n] == 0 and cells[n] != EMPTY:
					grounded[n] = 1
					part.append(n)
		out.append(part)
	island_mats.clear()
	for part: PackedInt32Array in out:
		var mats := PackedByteArray()
		mats.resize(part.size())
		for k: int in part.size():
			mats[k] = cells[part[k]]
			cells[part[k]] = EMPTY
		island_mats.append(mats)
		alive_count -= part.size()


## A digest of the grid, for the replay check.
func digest() -> int:
	return hash(cells)
