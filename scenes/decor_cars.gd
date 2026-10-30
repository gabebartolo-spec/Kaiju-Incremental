class_name DecorCars
extends RefCounted
## Parked cars on the city's kerbs (CityDecor).


## One kerb's (-1 or 1) parked and stopped cars along the street a..b. `street` is [width,
## playable, odds [parked, parked beyond, lane stop], parked gap].
static func park_kerb(d: CityDecor, kerb: float, a: Vector2, b: Vector2, street: Array) -> void:
	var width: float = street[0]
	var playable: bool = street[1]
	var odds: Array = street[2]
	var gap: Array = street[3]
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var length := a.distance_to(b)
	var along_x := absf(dir.x) > 0.5
	var t := CityDecor.CROSSING_CLEAR + d._rng.randf_range(0.0, 2.0)
	if not playable and t >= length - CityDecor.CROSSING_CLEAR:
		t = length * 0.5
	while t < length - CityDecor.CROSSING_CLEAR or is_equal_approx(t, length * 0.5):
		var lane := width * 0.5 - 0.6
		var stopped := d._rng.randf() < Num.f(odds[2])
		if stopped:
			lane = width * 0.25  # stopped in the traffic lane
		var p := a + dir * t + side * kerb * lane
		try_car(d, p, dir, street, stopped)
		t += d._rng.randf_range(Num.f(gap[0]), Num.f(gap[1]))


## A car at p in one of the paints, parked when the street's odds allow and it is off the
## playable diagonal, in view, off the buildings and clear of the street trees.
static func try_car(d: CityDecor, p: Vector2, dir: Vector2, street: Array, stopped: bool) -> void:
	var playable: bool = street[1]
	var odds: Array = street[2]
	var chance := Num.f(odds[0] if playable else odds[1])
	var along_x := absf(dir.x) > 0.5
	var color := "car%d" % d._rng.randi_range(0, d._paints - 1)
	var on_diagonal := (
		playable
		and (
			CityGen.diagonal_distance(d.plan, p)
			< CityGen.width_of(CityGen.DIAGONAL, d.sim.city) * 0.5 + 1.0
		)
	)
	var seen := d._inside(p, d._view - d._half) and not d._on_building(p)
	var half := (
		Vector2(CityDecor.CAR_HALF.y, CityDecor.CAR_HALF.x) if along_x else CityDecor.CAR_HALF
	)
	var body := Rect2(p - half, half * 2.0)
	if d._rng.randf() < chance and not on_diagonal and seen and d._clear_of_trees(body):
		if not d._street.vehicle(p, dir, stopped):
			d._props.add(
				Vector3(p.x, 0, p.y),
				func(v: VoxelBuilder) -> void: CityDecor.car(v, color, along_x)
			)
		d.cars.append(body)
