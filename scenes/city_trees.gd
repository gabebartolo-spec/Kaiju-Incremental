class_name CityTrees
extends RefCounted
## The trees CityDecor plants outside the kerb rows: the park's lawn trees, the ring round a
## plaza (or landmark) and the rows down the diagonal avenue. All keep city.tree_min_apart from
## every other tree: a tree that would stand too close slides along its own ring or row (or
## round its own lawn) to the nearest free spot, and drops only when there is none within
## city.tree_slide_reach. Seeded; presentation only.

const RING_STEPS := 5  # a plaza's ring trees per edge, corner to corner

var _sim: RampageSim
var _plan: Dictionary
var _props: PropField
var _rng: RandomNumberGenerator
var _on_building: Callable  # Callable(p: Vector2) -> bool
var _park_trees: Array[Vector2]
var _kerb: TreeSpots
var _others := TreeSpots.new()
var _half: float
var _view: float


## decor: the CityDecor whose PropField this plants into; its kerb spots are already filed.
func _init(decor: CityDecor, rng: RandomNumberGenerator) -> void:
	_sim = decor.sim
	_plan = decor.plan
	_props = decor._props
	_rng = rng
	_on_building = decor._on_building
	_park_trees = decor._park_trees
	_kerb = decor._kerb
	_half = CityGen.half_extent(_sim.city)
	_view = decor._view


## Lawn trees at random spots (about one per 9 m2), off the path and the playground.
func park(rect: Rect2) -> void:
	var inner := rect.grow(-1.6)
	var play := CityGreenery.playground_pad(rect, _sim.city).grow(0.5)
	var dirs: Array[Vector2] = []
	for k: int in 8:
		dirs.append(Vector2.from_angle(TAU * k / 8.0))
	var mid := rect.get_center().x  # a path runs down the middle
	var lawn := func(q: Vector2) -> bool:
		return absf(q.x - mid) > 1.2 and not play.has_point(q) and _lawn_round(q)
	for n: int in roundi(rect.get_area() / 9.0):
		var p := Vector2(
			_rng.randf_range(inner.position.x, inner.end.x),
			_rng.randf_range(inner.position.y, inner.end.y)
		)
		if lawn.call(p):
			var at := _place(
				p,
				dirs,
				func(q: Vector2) -> bool:
					return rect.grow(-0.6).has_point(q) and lawn.call(q) and _room(q)
			)
			if at.is_finite():
				_park_trees.append(at)


## Trees round a plaza, each edge corner to corner (a corner is met by two edges; the second
## would stand on the first, so it is skipped).
func ring(rect: Rect2) -> void:
	var inner := rect.grow(-1.2)
	for step: int in RING_STEPS + 1:
		for edge: int in 4:
			var p := _on_edge(inner, edge, float(step) / RING_STEPS)
			if _on_building.call(p) or _others.crowded(p, 0.02):
				continue
			var along := Vector2.RIGHT if edge < 2 else Vector2.DOWN
			var dirs: Array[Vector2] = [along, -along]
			_place(
				p,
				dirs,
				func(q: Vector2) -> bool:
					return inner.grow(0.01).has_point(q) and not _on_building.call(q) and _room(q)
			)


func _on_edge(r: Rect2, edge: int, t: float) -> Vector2:
	match edge:
		0:
			return Vector2(lerpf(r.position.x, r.end.x, t), r.position.y)
		1:
			return Vector2(lerpf(r.position.x, r.end.x, t), r.end.y)
		2:
			return Vector2(r.position.x, lerpf(r.position.y, r.end.y, t))
	return Vector2(r.end.x, lerpf(r.position.y, r.end.y, t))


## Street trees down both sides of the diagonal, and in the leftover corners it cuts out of
## the blocks (little plazas, the way Broadway leaves them). Past the playable edge the kerb row
## runs on as far as the camera sees (D-062), clear of the skyline's stand-ins.
func diagonal() -> void:
	var diag: Dictionary = _plan["diagonal"]
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	var side := Vector2(-dir.y, dir.x)
	var kerb := CityGen.width_of(CityGen.DIAGONAL, _sim.city) * 0.5 + 0.6
	var reach := maxf(_half * 1.6, _view / absf(dir.x))
	var dirs: Array[Vector2] = [dir, -dir]
	var t := -reach
	while t < reach:
		for s: float in [-1.0, 1.0]:
			for off: float in [kerb, kerb + 2.5, kerb + 5.0]:
				var p := at + dir * t + side * s * off
				if not _diag_fits(p, off == kerb):
					continue
				if off == kerb or _rng.randf() < 0.45:
					_place(
						p,
						dirs,
						func(q: Vector2) -> bool: return _diag_fits(q, off == kerb) and _room(q)
					)
		t += 4.0


## Whether a diagonal-avenue tree may stand at p (`on_kerb`: it is a kerb-row tree, not one of
## the two rows behind it).
func _diag_fits(p: Vector2, on_kerb: bool) -> bool:
	var city := maxf(absf(p.x), absf(p.y)) <= _half - 1.0
	if not city and (not on_kerb or maxf(absf(p.x), absf(p.y)) > _view):
		return false
	return not (_on_building.call(p) or (_near_street(p) if city else _on_road(p)))


## Plants a tree at p, or at the nearest `ok` spot along `dirs` when p is too close to another
## tree; returns where it stands (infinite when it was dropped).
func _place(p: Vector2, dirs: Array[Vector2], ok: Callable) -> Vector2:
	var at := p if _room(p) else TreeSpots.nearest(p, dirs, _sim.city, ok)
	if at.is_finite():
		_props.add(Vector3(at.x, 0, at.y), _tree, true)
		_others.add(at)
	return at


## Whether a tree at p keeps city.tree_min_apart from every tree planted so far.
func _room(p: Vector2) -> bool:
	var apart := Num.f(_sim.city["tree_min_apart"])
	return not _kerb.crowded(p, apart) and not _others.crowded(p, apart)


## Park trees keep city.park_tree_spacing apart (about a crown's width of lawn between them),
## so a park reads as a lawn with trees and not as a wood (critic on #55).
func _lawn_round(p: Vector2) -> bool:
	var spacing := Num.f(_sim.city["park_tree_spacing"])
	for tree: Vector2 in _park_trees:
		if tree.distance_to(p) < spacing:
			return false
	return true


## Whether p lies on a grid street's carriageway (past the edge, where stand-ins fill the blocks
## and a tree may stand on the pavement).
func _on_road(p: Vector2) -> bool:
	var nodes: Array[Vector2] = _plan["nodes"]
	for street: Dictionary in _plan["streets"]:
		if str(street["kind"]) == CityGen.DIAGONAL:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) < Num.f(street["width"]) * 0.5 + 0.3:
			return true
	return false


## Whether p lies on a grid street (not on a block).
func _near_street(p: Vector2) -> bool:
	for block: Dictionary in _plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if rect.has_point(p):
			return false
	return true


func _tree(v: VoxelBuilder) -> void:
	var tall := 4 + _rng.randi_range(0, 3)
	v.box(Vector3i(0, 0, 0), Vector3i(1, tall, 1), "bark")
	var r := _rng.randf_range(2.6, 3.6)
	v.blob(Vector3(0.5, tall + r * 0.8, 0.5), Vector3(r, r * 0.85, r), "leaf")
	v.blob(
		Vector3(0.5 + r * 0.5, tall + r * 0.5, 0.0), Vector3(r * 0.7, r * 0.6, r * 0.7), "leaf_dark"
	)
