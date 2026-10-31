class_name CoatWear
extends RefCounted
## The coatings (beam fire, ink) eat what they cover each step, and wear off when their time
## runs out or the chunk is gone. Part of SpeciesPowers; split out to keep files small. Pure.
## Coats are kept in packed arrays in the order they were first laid (a refresh keeps its
## place): a beam lays a thousand at once, and a Dictionary per coat cost ~4 us each a step.

## Key of a coated chunk: building * KEY_SPAN + chunk index.
const KEY_SPAN := 1048576

## Coat slot of each coated chunk, by key.
var _slot: Dictionary = {}
var _key := PackedInt64Array()
var _b := PackedInt32Array()
var _c: Array[Vector3i] = []
var _t := PackedFloat64Array()  # seconds left
var _dps := PackedFloat64Array()


func size() -> int:
	return _key.size()


func has(key: int) -> bool:
	return _slot.has(key)


## Coats chunk `c` under `key` (or refreshes its coat in place) for `seconds` at `dps`.
func put(key: int, c: Vector3i, seconds: float, dps: float) -> void:
	var i: int = _slot.get(key, -1)
	if i < 0:
		_slot[key] = _key.size()
		_key.append(key)
		_b.append(key / KEY_SPAN)
		_c.append(c)
		_t.append(seconds)
		_dps.append(dps)
		return
	_t[i] = seconds
	_dps[i] = dps


## One step of every coat over `dt` seconds: each building's coated chunks take dps * dt in one
## blow (buildings in the order their first coat was laid), spent coats drop out.
func step(sim: RampageSim, dt: float) -> void:
	if _key.is_empty():
		return
	var groups: Dictionary = {}  # building -> index into cells/amounts
	var order := PackedInt32Array()
	var cells: Array[Array] = []
	var amounts: Array[PackedFloat32Array] = []
	var last_b := -1
	var g := -1
	var frame: Structure = null
	var keep := 0
	for i: int in _key.size():
		var b := _b[i]
		if b != last_b:
			last_b = b
			frame = sim.buildings[b].frame
			g = groups.get(b, -1)
		var c := _c[i]
		_t[i] -= dt
		if _t[i] <= 0.0 or not frame.alive(c):
			_slot.erase(_key[i])
			continue
		if g < 0:
			g = cells.size()
			groups[b] = g
			order.append(b)
			cells.append([] as Array[Vector3i])
			amounts.append(PackedFloat32Array())
		cells[g].append(c)
		amounts[g].append(_dps[i] * dt)
		if keep != i:
			_move(i, keep)
		keep += 1
	_shrink(keep)
	for n: int in order.size():
		var hit: Array[Vector3i] = []
		hit.assign(cells[n])
		sim.damage_cells(order[n], hit, amounts[n])


## Moves the coat in slot `from` down to slot `to` (compaction keeps first-laid order).
func _move(from: int, to: int) -> void:
	_key[to] = _key[from]
	_b[to] = _b[from]
	_c[to] = _c[from]
	_t[to] = _t[from]
	_dps[to] = _dps[from]
	_slot[_key[to]] = to


func _shrink(n: int) -> void:
	_key.resize(n)
	_b.resize(n)
	_c.resize(n)
	_t.resize(n)
	_dps.resize(n)
