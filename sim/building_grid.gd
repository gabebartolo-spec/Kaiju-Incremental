class_name BuildingGrid
extends RefCounted
## A ground grid over the rampage's buildings, so a question about one spot (what the body
## touches, whether a street is blocked, the column under the kaiju) looks at the few buildings
## near it instead of the whole city (D-254: the 1.5x city has twice the buildings, and these
## run every step). Buildings never move, so it is filled once. Answers list building indices in
## ascending order, the order a pass over sim.buildings meets them, so every caller decides
## exactly as before. Pure sim.

## Side of a grid cell (m): about a block, so a body's reach spans a few cells.
const CELL := 16.0

var _cells := {}  # Vector2i -> PackedInt32Array of building indices, ascending
## The largest half-diagonal of any footprint (m): a building whose centre lies within r of a spot
## is always among around(spot, r + pad).
var pad := 0.0


func _init(buildings: Array) -> void:
	for i: int in buildings.size():
		var b: RampageSim.Building = buildings[i]
		pad = maxf(pad, Vector2(b.w, b.d).length() * 0.5)
		var lo := _cell(Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5))
		var hi := _cell(Vector2(b.x + b.w * 0.5, b.z + b.d * 0.5))
		for cx: int in range(lo.x, hi.x + 1):
			for cz: int in range(lo.y, hi.y + 1):
				var key := Vector2i(cx, cz)
				if not _cells.has(key):
					_cells[key] = PackedInt32Array()
				var list: PackedInt32Array = _cells[key]
				list.append(i)
				_cells[key] = list


## Every building whose footprint may reach the rect lo..hi (ground x, z), ascending, once each.
func in_rect(lo: Vector2, hi: Vector2) -> PackedInt32Array:
	var a := _cell(lo)
	var b := _cell(hi)
	if a == b:
		return _cells.get(a, PackedInt32Array())
	var seen := {}
	for cx: int in range(a.x, b.x + 1):
		for cz: int in range(a.y, b.y + 1):
			for i: int in _cells.get(Vector2i(cx, cz), PackedInt32Array()):
				seen[i] = true
	var out := PackedInt32Array(seen.keys())
	out.sort()
	return out


## Every building whose footprint may reach within `radius` of p.
func around(p: Vector2, radius: float) -> PackedInt32Array:
	return in_rect(p - Vector2.ONE * radius, p + Vector2.ONE * radius)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))
