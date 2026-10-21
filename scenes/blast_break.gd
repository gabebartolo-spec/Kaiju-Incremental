class_name BlastBreak
extends Node
## A building a red-barrel blast reaches blows apart rather than blinking out (motion critic
## 2026-10-21: "debris thrown outward and upward before the walls drop, walls breaking into
## voxels over 3-4 frames"). CityView hands it the chunks the sim broke while a blast is fresh
## (blew() opens a short window); instead of hiding them at once, it breaks them top floor
## first in break.slices steps, one a frame, each throwing the city's own debris out from the
## blast and up. The sim's chunks are already gone: this is only when and how the view lets go
## of them. Looks: data/tuning.json "blast_fx" break.

var _cfg: Dictionary
var _city: CityView
var _rng: RandomNumberGenerator
## Fresh blasts: [origin (Vector3, ground), reach, frames left].
var _blasts: Array[Array] = []
## Breaks still running: [view, slices left (Array of Array[Vector3i]), origin, building].
var _queue: Array[Array] = []


func _init(city: CityView, rng: RandomNumberGenerator, cfg: Dictionary) -> void:
	_city = city
	_rng = rng
	_cfg = cfg


## A blast went off at `origin`: chunks broken within `reach` for the next few frames blow apart.
func blew(origin: Vector3, reach: float) -> void:
	_blasts.append([origin, reach, Num.i(_cfg["window_frames"])])


## True when these broken chunks belong to a fresh blast (they are then this node's to break).
func takes(index: int, cells: Array[Vector3i], view: BuildingView) -> bool:
	var b := _city.sim.buildings[index]
	for blast: Array in _blasts:
		var origin: Vector3 = blast[0]
		if Vector2(b.x - origin.x, b.z - origin.z).length() > Num.f(blast[1]):
			continue
		var slices := _slices(cells)
		var first: Array[Vector3i] = slices.pop_front()
		_break(view, first, origin, b)
		if not slices.is_empty():
			_queue.append([view, slices, origin, b])
		return true
	return false


func _process(_delta: float) -> void:
	for blast: Array in _blasts:
		blast[2] = Num.i(blast[2]) - 1
	_blasts = _blasts.filter(func(blast: Array) -> bool: return Num.i(blast[2]) > 0)
	for item: Array in _queue:
		var slices: Array = item[1]
		var view: BuildingView = item[0]
		var next: Array[Vector3i] = slices.pop_front()
		var origin: Vector3 = item[2]
		var b: RampageSim.Building = item[3]
		_break(view, next, origin, b)
	_queue = _queue.filter(
		func(item: Array) -> bool:
			var left: Array = item[1]
			return not left.is_empty()
	)


## The broken chunks, top floor first, in break.slices groups (fewer when there are fewer).
func _slices(cells: Array[Vector3i]) -> Array:
	var sorted := cells.duplicate()
	sorted.sort_custom(func(a: Vector3i, c: Vector3i) -> bool: return a.y > c.y)
	var n := clampi(Num.i(_cfg["slices"]), 1, maxi(1, sorted.size()))
	var out: Array = []
	for k: int in n:
		var lo := floori(sorted.size() * float(k) / n)
		var hi := floori(sorted.size() * float(k + 1) / n)
		var part: Array[Vector3i] = []
		part.assign(sorted.slice(lo, hi))
		if not part.is_empty():
			out.append(part)
	return out


## One step: these chunks go, their voxels thrown out from the blast and up.
func _break(
	view: BuildingView, cells: Array[Vector3i], origin: Vector3, b: RampageSim.Building
) -> void:
	if not is_instance_valid(view):
		return
	var parts := view.hide_chunks(cells)
	parts.append_array(view.chip(cells, _rng))
	if parts.is_empty():
		return
	var push := Num.f(_cfg["push"])
	var up := Num.f(_cfg["up"])
	for _n: int in mini(parts.size(), cells.size() * Num.i(_cfg["per_chunk"])):
		var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
		var pos: Vector3 = part["pos"]
		var out := Vector3(pos.x - origin.x, 0.0, pos.z - origin.z).normalized()
		var away := (
			out * push * _rng.randf_range(0.6, 1.2) + Vector3.UP * up * _rng.randf_range(0.5, 1.2)
		)
		var colour: Color = part["color"]
		_city.debris(pos, colour, away)
	_city.fx.dust(b.chunk_world(cells[0]), 0.5 + cells.size() * 0.05)
