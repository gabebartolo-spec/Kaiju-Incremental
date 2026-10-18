extends RefCounted
## D-065 (director 2026-10-18: "make sure there are a believable amount of trees, bushes,
## floral areas, parks, gardens, playgrounds throughout the city"): measures a city's
## greenery the way a real downtown is judged. Street trees per km of street, the parks and
## what is in them, front yards and their hedges, the share of the playable city's blocks
## that are green, and the furthest any building stands from a park. The city suite's green
## check lives here too (check_city), so run_city_tests.gd keeps room under its line cap.


## decor is a CityDecor that has run _ready; before D-065 it has no "green" counts, and every
## count reads 0.
static func measure(sim: RampageSim, decor: CityDecor) -> Dictionary:
	var green: Dictionary = {}
	var got: Variant = decor.get("green")
	if got is Dictionary:
		green = got
	var trees: Array = green.get("street_trees", [])
	var avenue_m := Num.f(green.get("avenue_m", 0.0))
	var half := CityGen.half_extent(sim.city)
	var plan := CityGen.map(sim.city)
	var parks: Array[Rect2] = []
	var green_area := 0.0
	var city_area := 0.0
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		var c := rect.get_center()
		if maxf(absf(c.x), absf(c.y)) > half or str(block["use"]) == "outer":
			continue
		city_area += rect.get_area()
		if str(block["use"]) in ["park", "plaza"]:
			green_area += rect.get_area()
			parks.append(rect)
	var furthest := 0.0
	for b: RampageSim.Building in sim.buildings:
		var p := Vector2(b.x, b.z)
		var nearest := INF
		for rect: Rect2 in parks:
			var q := p.clamp(rect.position, rect.end)
			nearest = minf(nearest, q.distance_to(p))
		furthest = maxf(furthest, nearest)
	return {
		"street_trees": trees.size(),
		"avenue_km": avenue_m / 1000.0,
		"trees_per_km": trees.size() / maxf(0.001, avenue_m / 1000.0),
		"parks": parks.size(),
		"playgrounds": Num.i(green.get("playgrounds", 0)),
		"bushes": Num.i(green.get("bushes", 0)),
		"flower_beds": Num.i(green.get("flower_beds", 0)),
		"yards": Num.i(green.get("yards", 0)),
		"hedges": Num.i(green.get("hedges", 0)),
		"green_pct": 100.0 * green_area / maxf(1.0, city_area),
		"furthest_from_park_m": furthest,
	}


## A believable amount of green (D-065, director 2026-10-18: "make sure there are a believable
## amount of trees, bushes, floral areas, parks, gardens, playgrounds throughout the city"):
## street trees down the avenues at a real downtown spacing (both pavements, one every
## city.street_tree_gap metres, fewer at crossings and lamps), a garden and a playground in
## every park, and a hedge in the front yards. Everything is a crushable decor prop.
static func check_city(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check: Callable
) -> void:
	var got: Dictionary = measure(sim, decor)
	var gap := Num.f(sim.city["street_tree_gap"])
	var per_km := Num.f(got["trees_per_km"])
	var low := 1000.0 / gap  # one kerb's worth: crossings, lamps and the diagonal take the rest
	var high := 2000.0 / gap  # both kerbs, every slot
	var parks := Num.i(got["parks"])
	check.call(
		(
			per_km >= low
			and per_km <= high
			and Num.i(got["playgrounds"]) == parks
			and Num.i(got["bushes"]) > 0
			and Num.i(got["flower_beds"]) > 0
			and (Num.i(got["yards"]) == 0 or Num.i(got["hedges"]) > 0)
		),
		(
			(
				"stage %d, map_seed %d: green city (%.0f street trees/km of street, want %.0f-%.0f;"
				+ " %d parks, %d playgrounds, %d bushes, %d flower beds, %d yards, %d hedges)"
			)
			% [
				tier,
				map_seed,
				per_km,
				low,
				high,
				parks,
				Num.i(got["playgrounds"]),
				Num.i(got["bushes"]),
				Num.i(got["flower_beds"]),
				Num.i(got["yards"]),
				Num.i(got["hedges"])
			]
		)
	)
	# Trees and parking share the kerb: no car body within city.street_tree_car_clear of a trunk.
	var reach := Num.f(sim.city["street_tree_car_clear"])
	var green: Dictionary = decor.get("green") if decor.get("green") is Dictionary else {}
	var trunks: Array = green.get("trunks", [])
	var cars: Array = decor.get("cars") if decor.get("cars") is Array else []
	var hits := 0
	var near := Vector2.INF
	for trunk: Vector2 in trunks:
		for car: Rect2 in cars:
			if trunk.clamp(car.position, car.end).distance_to(trunk) < reach:
				hits += 1
				near = trunk
				break
	check.call(
		hits == 0 and trunks.size() > 0,
		(
			(
				"stage %d, map_seed %d: no parked car within %.1f m of a street tree's trunk"
				% [tier, map_seed, reach]
			)
			+ " (%d of %d trunks have one, e.g. at %s)" % [hits, trunks.size(), near]
		)
	)
