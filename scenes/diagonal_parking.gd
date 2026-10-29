class_name DiagonalParking
extends RefCounted
## Cars parked along both kerbs of the diagonal avenue, turned to it, as far as grid parking
## reaches (the arena and what the camera shows past its edge, city.view_beyond: a sliver there
## is bare without them, map_seed 98765 stage 2)
## (D-062: no empty ground; a sliver of block wholly inside the diagonal carries no pavement and
## no walkers, so its parked row is what there is to smash). They are Traffic's cars, drawn
## turned to the avenue and parked for good, flattened by a stomp or a tank like any other.
## city.diagonal_parked_lane from the centre line keeps them off the traffic lanes and a metre
## clear of the kerb trees; city.parked_chance and city.parked_gap as on the grid. Never in a
## grid street, by a crossing, in the river or within city.street_tree_car_clear of a CityDecor
## prop (tree, bush, lamp, car). Own seed stream; presentation only. (Its fill rule, a car in
## any ground cell left bare, retired with the bigger blocks, D-265: no plan leaves such a cell.)

const CROSSING_CLEAR := 3.0  # no parking this close to a crossing (as CityDecor)


## Parks the row into `traffic` (after its moving cars spawned), drawn along each kerb.
static func park(traffic: Traffic, sim: RampageSim) -> void:
	var rng := Seeds.make("diagonal_parking", 0)
	var cfg := sim.city
	var plan := CityGen.map(cfg)
	var water := CityRiver.channels(plan, cfg)
	var reach_to := sim.arena_half + Num.f(cfg["view_beyond"])  # as CityDecor's parked cars
	var props := _props_near(traffic)
	var reach := Num.f(cfg["street_tree_car_clear"])
	var fits := func(p: Vector2, dir: Vector2) -> bool:
		return (
			maxf(absf(p.x), absf(p.y)) <= reach_to
			and _clear(plan, p, water)
			and _off_props(props, p, dir, reach)
		)
	var chance := Num.f(cfg["parked_chance"])
	var gap: Array = cfg["parked_gap"]
	for kerb: Array in _kerbs(plan, cfg):
		var facing: Vector2 = kerb[3]
		var t := CROSSING_CLEAR + rng.randf_range(0.0, 2.0)
		while t < Num.f(kerb[2]) - CROSSING_CLEAR:
			var p := _spot(kerb, t)
			if rng.randf() < chance and fits.call(p, kerb[1]):
				_add(traffic, rng, p, facing)
			t += rng.randf_range(Num.f(gap[0]), Num.f(gap[1]))


## Each kerb of each diagonal block: [start (its crossing, out at the parking lane), along,
## length, facing (its lane's way)].
static func _kerbs(plan: Dictionary, cfg: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	var nodes: Array[Vector2] = plan["nodes"]
	var lane := Num.f(cfg["diagonal_parked_lane"])
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) != CityGen.DIAGONAL:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var dir := (b - a).normalized()
		for side: float in [-1.0, 1.0]:
			out.append([a + dir.orthogonal() * side * lane, dir, a.distance_to(b), -dir * side])
	return out


static func _spot(kerb: Array, t: float) -> Vector2:
	var start: Vector2 = kerb[0]
	var along: Vector2 = kerb[1]
	return start + along * t


## Whether a car at p stands clear of the water and of every grid street (its carriageway and
## half a car more).
static func _clear(plan: Dictionary, p: Vector2, water: Array[Rect2]) -> bool:
	for channel: Rect2 in water:
		if channel.grow(CityDecor.CAR_HALF.y + 0.5).has_point(p):
			return false
	var nodes: Array[Vector2] = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) == CityGen.DIAGONAL:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var reach := Num.f(street["width"]) * 0.5 + CityDecor.CAR_HALF.y
		if q.distance_to(p) < reach:
			return false
	return true


## Where the props of the CityDecor beside this traffic stand (none without one: stills, tests).
static func _props_near(traffic: Traffic) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var up := traffic.get_parent()
	while up != null:
		for n: Node in up.get_children():
			if n is CityDecor:
				for group: Dictionary in (n as CityDecor)._props._groups:
					var at: Vector3 = group["at"]
					out.append(Vector2(at.x, at.z))
				return out
		up = up.get_parent()
	return out


## Whether a car at p along dir keeps `reach` between its body and every prop base.
static func _off_props(props: Array[Vector2], p: Vector2, dir: Vector2, reach: float) -> bool:
	for at: Vector2 in props:
		var d := at - p
		var gap := Vector2(
			maxf(0.0, absf(d.dot(dir)) - CityDecor.CAR_HALF.y),
			maxf(0.0, absf(d.cross(dir)) - CityDecor.CAR_HALF.x)
		)
		if gap.length() < reach:
			return false
	return true


static func _add(traffic: Traffic, rng: RandomNumberGenerator, p: Vector2, facing: Vector2) -> void:
	var car := traffic._make(traffic._meshes[rng.randi_range(0, traffic._meshes.size() - 1)], false)
	car.pos = p
	car.dir = facing
	car.arrive_facing = facing
	car.parked = true
	traffic._place(car, 1.0)
