class_name TreeSpots
extends RefCounted
## Where trees stand, filed by ground cell so "is anything within r of here" looks at nine cells
## and not the whole city (CityDecor and CityGreenery keep their trees clear of each other and of
## parked cars with it). Presentation only.

const CELL := 4.0  # spots are filed by ground cell of this size; reaches stay under it

var _cells := {}  # Vector2i cell -> the spots in it


func add(spot: Vector2) -> void:
	var cell := Vector2i((spot / CELL).floor())
	var in_cell: Array = _cells.get(cell, [])
	in_cell.append(spot)
	_cells[cell] = in_cell


## Every spot filed.
func all() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for in_cell: Array in _cells.values():
		for spot: Vector2 in in_cell:
			out.append(spot)
	return out


## Whether some spot lies closer to p than `apart` (at most CELL). Standing exactly `apart` away
## counts as clear.
func crowded(p: Vector2, apart: float) -> bool:
	var here := Vector2i((p / CELL).floor())
	for cx: int in range(here.x - 1, here.x + 2):
		for cy: int in range(here.y - 1, here.y + 2):
			for spot: Vector2 in _cells.get(Vector2i(cx, cy), []):
				if spot.distance_to(p) < apart - 0.01:
					return true
	return false


## Whether some spot lies within `reach` of the rectangle `body`.
func near_box(body: Rect2, reach: float) -> bool:
	var lo := Vector2i(((body.position - Vector2.ONE * reach) / CELL).floor())
	var hi := Vector2i(((body.end + Vector2.ONE * reach) / CELL).floor())
	for cx: int in range(lo.x, hi.x + 1):
		for cy: int in range(lo.y, hi.y + 1):
			for spot: Vector2 in _cells.get(Vector2i(cx, cy), []):
				if spot.clamp(body.position, body.end).distance_to(spot) < reach:
					return true
	return false


## The nearest spot to p along `dirs` (tried in order, step by step out to city.tree_slide_reach)
## that `ok` accepts, or an infinite vector when there is none. Deterministic.
static func nearest(p: Vector2, dirs: Array[Vector2], cfg: Dictionary, ok: Callable) -> Vector2:
	var reach := Num.f(cfg["tree_slide_reach"])
	var step := Num.f(cfg["tree_slide_step"])
	var r := step
	while r <= reach:
		for dir: Vector2 in dirs:
			var q := p + dir * r
			if ok.call(q):
				return q
		r += step
	return Vector2(INF, INF)
