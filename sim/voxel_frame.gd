class_name VoxelFrame
extends RefCounted
## A building as a fine voxel grid that a monster carves (D-094, option A: Teardown's carving plus
## Red Faction: Guerrilla's support rule). RES cells per sim unit (data/tuning.json
## "destruction"), one byte per cell: 0 empty, else a material id from the caller's material
## list (data/materials.json's shape: {id, name, strength}). Cells run x fastest, then z, then y,
## as in Structure. A material marked "fixture" (a window pane, a sign) hangs on its neighbours:
## it is attached when it touches an attached cell by a face, an edge or a corner, and it holds
## no structural cell up (lead rule on #97). Positions passed in are building-local sim units:
## local cell (x, y, z) fills [x, x + 1] / RES on each axis; grid cell 0 is local cell `offset`.
##
## A blow carves a sphere (stomp) or a capsule (swipe); settle() then finds what lost support,
## with Structure.settle()'s event shape ({cells, kind "drop"|"topple", pivot, dir}) so Collapse
## can consume it unchanged (cells are fine-grid cells; pivot is in sim units):
##  - islands: parts no longer joined to the ground floor; each drops, or topples off the edge of
##    the cells it lands on when its centre of mass hangs past them;
##  - the grounded remainder: Structure's topple rule per connected grounded part, so a tower
##    is not "held up by a chimney".
## Pure and deterministic: integer grid and decisions, fixed scan order, no RNG, no clock.
## The GDScript reference (the oracle); WP2's native port must match its digests.

const EMPTY := 0

var res: int
## Grid size in cells.
var w: int
var d: int
var h: int
var alive_count := 0
## The building-local cell of grid cell (0, 0, 0) (WP3's BuildingCells.offset: the grid also
## holds what stands proud of the footprint). Every Vector3i, position and event is
## building-local; only "index" is a grid index.
var offset := Vector3i.ZERO
var cells := PackedByteArray()
## By material id: 1 when the material is a fixture (data/materials.json "fixture", default
## false), else 0. VoxelSupport reads it.
var fixtures := PackedByteArray()
## True when any material in the list is a fixture (the flood skips the fixture pass if not).
var has_fixtures := false
## True once a settle has run (Carving.warm's first-settle stage looks).
var settled_once := false
## By material id: the blow needed to break a cell of it.
var _strength := PackedFloat64Array()
var _ids: Dictionary = {}


func _init(units: Vector3i, p_res: int, materials: Array[Dictionary]) -> void:
	res = p_res
	w = units.x * res
	d = units.z * res
	h = units.y * res
	cells.resize(w * d * h)
	_strength.resize(256)
	fixtures.resize(256)
	for m: Dictionary in materials:
		var id := Num.i(m["id"])
		if id > EMPTY and id < 256:
			_strength[id] = Num.f(m.get("strength", 1.0))
			_ids[str(m["name"])] = id
			if m.get("fixture", false) == true:
				fixtures[id] = 1
				has_fixtures = true


## Takes a generated grid (WP3's BuildingCells: dims, offset, cells), a copy of its bytes.
## The ground is grid layer 0, so offset.y must be 0; dims must match the bytes. A grid that
## breaks either is refused (an error, false) and the frame is left as it was.
func adopt(dims: Vector3i, p_offset: Vector3i, p_cells: PackedByteArray) -> bool:
	var size := dims.x * dims.y * dims.z
	if p_offset.y != 0 or mini(mini(dims.x, dims.y), dims.z) < 1 or size != p_cells.size():
		push_error(
			(
				"VoxelFrame.adopt refused: dims %s, offset %s, %d bytes"
				% [dims, p_offset, p_cells.size()]
			)
		)
		return false
	w = dims.x
	d = dims.z
	h = dims.y
	offset = p_offset
	cells = p_cells.duplicate()
	alive_count = cells.size() - cells.count(EMPTY)
	return true


## The id of a material by name, or EMPTY when the list has no such material.
func material_id(material: String) -> int:
	var id: int = _ids.get(material, EMPTY)
	return id


## The grid index of a building-local cell.
func index(c: Vector3i) -> int:
	var g := c - offset
	return g.x + g.z * w + g.y * w * d


func inside(c: Vector3i) -> bool:
	var g := c - offset
	return g.x >= 0 and g.y >= 0 and g.z >= 0 and g.x < w and g.y < h and g.z < d


func alive(c: Vector3i) -> bool:
	return inside(c) and cells[index(c)] != EMPTY


## Sets one cell's material (EMPTY clears it); outside the grid is ignored.
func set_cell(c: Vector3i, material: int) -> void:
	if not inside(c):
		return
	var i := index(c)
	alive_count += int(material != EMPTY) - int(cells[i] != EMPTY)
	cells[i] = material


## Sets every cell in [lo, hi) (clipped to the grid).
func fill(lo: Vector3i, hi: Vector3i, material: int) -> void:
	var top := offset + Vector3i(w, h, d)
	for y: int in range(maxi(offset.y, lo.y), mini(top.y, hi.y)):
		for z: int in range(maxi(offset.z, lo.z), mini(top.z, hi.z)):
			for x: int in range(maxi(offset.x, lo.x), mini(top.x, hi.x)):
				set_cell(Vector3i(x, y, z), material)


## A blow of `amount` on one cell: it breaks when the blow reaches its material's strength.
## One byte per cell holds no wear, so a weaker blow leaves it whole. True if it broke now.
func damage(c: Vector3i, amount: float) -> bool:
	if not alive(c):
		return false
	var i := index(c)
	if amount < _strength[cells[i]]:
		return false
	cells[i] = EMPTY
	alive_count -= 1
	return true


## Empties grid cell `i` (a grid index, not a cell); returns the material it held.
func clear_index(i: int) -> int:
	var m := cells[i]
	if m != EMPTY:
		cells[i] = EMPTY
		alive_count -= 1
	return m


func remove(c: Vector3i) -> void:
	if alive(c):
		cells[index(c)] = EMPTY
		alive_count -= 1


## Highest standing cell in column (x, z) below `below_y`, or -1 (building-local).
func top_below(x: int, z: int, below_y: int) -> int:
	var y := column_top(x - offset.x, z - offset.z, below_y - offset.y)
	return y + offset.y if y >= 0 else -1


## As top_below in grid coordinates (VoxelSupport's landing).
func column_top(gx: int, gz: int, below_gy: int) -> int:
	if gx < 0 or gz < 0 or gx >= w or gz >= d:
		return -1
	var plan := w * d
	for y: int in range(mini(below_gy, h) - 1, -1, -1):
		if cells[gx + gz * w + y * plan] != EMPTY:
			return y
	return -1


## Removes every cell whose centre is inside the sphere and whose strength is at most `force`.
## Returns the removed cell indices in scan order. Does not settle.
func carve_sphere(centre: Vector3, radius: float, force: float = INF) -> PackedInt32Array:
	var removed := PackedInt32Array()
	var shift := Vector3(offset)
	var lo := ((centre - Vector3.ONE * radius) * res - shift).floor()
	var hi := ((centre + Vector3.ONE * radius) * res - shift).ceil()
	var r2 := radius * radius * res * res
	var c := centre * res - shift
	var plan := w * d
	for y: int in range(maxi(0, int(lo.y)), mini(h, int(hi.y) + 1)):
		for z: int in range(maxi(0, int(lo.z)), mini(d, int(hi.z) + 1)):
			for x: int in range(maxi(0, int(lo.x)), mini(w, int(hi.x) + 1)):
				var i := x + z * w + y * plan
				var m := cells[i]
				if m == EMPTY or _strength[m] > force:
					continue
				if Vector3(x + 0.5, y + 0.5, z + 0.5).distance_squared_to(c) <= r2:
					cells[i] = EMPTY
					removed.append(i)
	alive_count -= removed.size()
	return removed


## As carve_sphere, along the segment a-b (a swipe sweeps a sphere from a to b).
func carve_capsule(a: Vector3, b: Vector3, radius: float, force: float = INF) -> PackedInt32Array:
	var shift := Vector3(offset)
	var ca := a * res - shift
	var ab := (b - a) * res
	var len2 := ab.length_squared()
	if len2 == 0.0:
		return carve_sphere(a, radius, force)
	var removed := PackedInt32Array()
	var lo := ((a.min(b) - Vector3.ONE * radius) * res - shift).floor()
	var hi := ((a.max(b) + Vector3.ONE * radius) * res - shift).ceil()
	var r2 := radius * radius * res * res
	var plan := w * d
	for y: int in range(maxi(0, int(lo.y)), mini(h, int(hi.y) + 1)):
		for z: int in range(maxi(0, int(lo.z)), mini(d, int(hi.z) + 1)):
			for x: int in range(maxi(0, int(lo.x)), mini(w, int(hi.x) + 1)):
				var i := x + z * w + y * plan
				var m := cells[i]
				if m == EMPTY or _strength[m] > force:
					continue
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var t := clampf((p - ca).dot(ab) / len2, 0.0, 1.0)
				if p.distance_squared_to(ca + ab * t) <= r2:
					cells[i] = EMPTY
					removed.append(i)
	alive_count -= removed.size()
	return removed


## Teardown's split alone (the spike's rule, no support rule): removes and returns every part
## no longer joined to the ground floor, in scan order of its first cell, each a "drop".
func detach() -> Array[Dictionary]:
	var support := VoxelSupport.new(self)
	return _take_all(support.islands())


## Removes and returns every part that lost support, as Structure.settle() does:
## {"cells": Array[Vector3i], "kind": "drop"|"topple", "pivot": Vector3 (local sim units),
## "dir": Vector2i, "mats": PackedByteArray (each cell's material), "index": PackedInt32Array}.
## Islands first (scan order), then at most one topple per grounded part (lowest level), then
## what hung from a toppled load below its level: a fresh flood, its islands land as the first
## ones do (review FIX on #97: nothing is left floating). The native flood and cell loops
## (KaijuSettle) run it where the extension is loaded; with VoxelSupport.use_native off this is
## the GDScript reference they are held to (tests/lib/settle_replay.gd).
func settle() -> Array[Dictionary]:
	settled_once = true
	var support := VoxelSupport.new(self)
	var out: Array[Dictionary] = []
	_drop_islands(support, out)
	var first := out.size()
	var plan := w * d
	var tips := support.topple()
	for tip: Dictionary in tips:
		var label: int = tip["label"]
		var level: int = tip["level"]
		var part := PackedInt32Array()
		var nat := VoxelSupport.native()
		if nat != null:
			part = nat.call("gather", support.labels, cells, level * plan, label)
		else:
			for i: int in range(level * plan, cells.size()):
				if support.labels[i] == label and cells[i] != EMPTY:
					part.append(i)
		var event := _take_all([part])[0]
		event["kind"] = "topple"
		event["pivot"] = tip["pivot"]
		event["dir"] = tip["dir"]
		out.append(event)
	if out.size() > first:
		_drop_islands(VoxelSupport.new(self), out)
	return out


## Takes every island `support` finds and appends it to `out`, each with where it lands.
func _drop_islands(support: VoxelSupport, out: Array[Dictionary]) -> void:
	var start := out.size()
	var isl := support.islands()
	out.append_array(_take_all(isl))
	for k: int in range(start, out.size()):
		var index: PackedInt32Array = out[k]["index"]
		out[k].merge(support.landing(index), true)


## A digest of the grid, for replay checks.
func digest() -> int:
	return hash(cells)


## Removes the cells of `part` (grid indices, all standing) and returns them as a "drop" event, as
## settle() does (Carving brings a ring landmark's arc down with it).
func take(part: PackedInt32Array) -> Dictionary:
	return _take_all([part])[0]


## Removes the cells of each part and returns them as "drop" events (natively where loaded).
func _take_all(parts: Array[PackedInt32Array]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var nat := VoxelSupport.native()
	if nat == null:
		for part: PackedInt32Array in parts:
			out.append(_take(part))
		return out
	var got: Array = nat.call("take", cells, parts, Vector3i(w, h, d), offset)
	cells = got[0]
	for k: int in parts.size():
		var list: Array[Vector3i] = []
		var raw: Array = got[2][k]
		list.assign(raw)
		alive_count -= parts[k].size()
		var mats: PackedByteArray = got[1][k]
		out.append(_drop_event(list, mats, parts[k]))
	return out


## Removes the cells of `part` and returns them as a "drop" event.
func _take(part: PackedInt32Array) -> Dictionary:
	var mats := PackedByteArray()
	mats.resize(part.size())
	var list: Array[Vector3i] = []
	var plan := w * d
	for k: int in part.size():
		var i := part[k]
		mats[k] = cells[i]
		cells[i] = EMPTY
		list.append(Vector3i(i % w, i / plan, (i / w) % d) + offset)
	alive_count -= part.size()
	return _drop_event(list, mats, part)


static func _drop_event(
	list: Array[Vector3i], mats: PackedByteArray, part: PackedInt32Array
) -> Dictionary:
	return {
		"cells": list,
		"kind": "drop",
		"pivot": Vector3.ZERO,
		"dir": Vector2i.ZERO,
		"mats": mats,
		"index": part,
	}
