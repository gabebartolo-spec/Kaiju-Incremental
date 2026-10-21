class_name DiagonalParking
extends RefCounted
## Cars parked along both kerbs of the diagonal avenue inside the playable city, turned to it
## (D-062: no empty ground; a sliver of block wholly inside the diagonal carries no pavement and
## no walkers, so its parked row is what there is to smash). They are Traffic's cars, drawn
## turned to the avenue and parked for good, flattened by a stomp or a tank like any other.
## city.diagonal_parked_lane from the centre line keeps them off the traffic lanes and a metre
## clear of the kerb trees; city.parked_chance and city.parked_gap as on the grid. Never in a
## grid street, by a crossing, in the river or within city.street_tree_car_clear of a CityDecor
## prop (tree, bush, lamp, car). Fill rule, not chance, where it matters: a ground cell
## (city.coverage_cell, the no-empty-ground grid) that a parked spot fits in but that holds no
## building, prop or parked car after the draws always gets one, at its first spot. Own seed
## stream; presentation only.

const CROSSING_CLEAR := 3.0  # no parking this close to a crossing (as CityDecor)

const FILL_STEP := 0.25  # the fill looks for a free spot this often along each kerb
## Off only to show the fill rule's need (tests/lib/city_diag_fill.gd). A cell that is all
## junction (no spot clear of the grid streets) gets nothing.
static var fill := true


## Parks the row into `traffic` (after its moving cars spawned): the seeded draws first, then
## the fill (a car at the first spot that fits in each cell left with nothing to smash).
static func park(traffic: Traffic, sim: RampageSim) -> void:
	var rng := Seeds.make("diagonal_parking", 0)
	var cfg := sim.city
	var plan := CityGen.map(cfg)
	var water := CityRiver.channels(plan, cfg)
	var half := CityGen.half_extent(cfg)
	var props := _props_near(traffic)
	var reach := Num.f(cfg["street_tree_car_clear"])
	var fits := func(p: Vector2, dir: Vector2) -> bool:
		return (
			maxf(absf(p.x), absf(p.y)) <= half
			and _clear(plan, p, water)
			and _off_props(props, p, dir, reach)
		)
	var full := {}  # ground cell -> true: something to smash stands in it
	for at: Vector2 in props:
		full[cell_of(sim, at)] = true
	var chance := Num.f(cfg["parked_chance"])
	var gap: Array = cfg["parked_gap"]
	for kerb: Array in _kerbs(plan, cfg):
		var facing: Vector2 = kerb[3]
		var t := CROSSING_CLEAR + rng.randf_range(0.0, 2.0)
		while t < Num.f(kerb[2]) - CROSSING_CLEAR:
			var p := _spot(kerb, t)
			if rng.randf() < chance and fits.call(p, kerb[1]):
				_add(traffic, rng, p, facing)
				full[cell_of(sim, p)] = true
			t += rng.randf_range(Num.f(gap[0]), Num.f(gap[1]))
	if not fill:
		return
	for kerb: Array in _kerbs(plan, cfg):
		var facing: Vector2 = kerb[3]
		var t := CROSSING_CLEAR
		while t < Num.f(kerb[2]) - CROSSING_CLEAR:
			var p := _spot(kerb, t)
			var cell := cell_of(sim, p)
			if not full.has(cell) and not _built(sim, cell) and fits.call(p, kerb[1]):
				_add(traffic, rng, p, facing)
				full[cell] = true
			t += FILL_STEP


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


## The no-empty-ground cell (city.coverage_cell, laid over the arena and the band past it the
## camera shows, as tests/lib/city_coverage.gd measures) that holds p.
static func cell_of(sim: RampageSim, p: Vector2) -> Vector2i:
	var size := Num.f(sim.city["coverage_cell"])
	var n := ceili((sim.arena_half + Num.f(sim.city["view_beyond"])) * 2.0 / size)
	var origin := -n * size * 0.5
	return Vector2i(floori((p.x - origin) / size), floori((p.y - origin) / size))


## Whether a building stands in the cell.
static func _built(sim: RampageSim, cell: Vector2i) -> bool:
	var size := Num.f(sim.city["coverage_cell"])
	var n := ceili((sim.arena_half + Num.f(sim.city["view_beyond"])) * 2.0 / size)
	var box := Rect2(Vector2(cell) * size - Vector2.ONE * n * size * 0.5, Vector2.ONE * size)
	for b: RampageSim.Building in sim.buildings:
		if box.intersects(Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)):
			return true
	return false


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
