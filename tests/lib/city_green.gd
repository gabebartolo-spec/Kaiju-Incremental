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
	var roomy := 0  # parks with room for a playground beside the path (CityGreenery)
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
			if (
				str(block["use"]) == "park"
				and CityGreenery.playground_pad(rect, sim.city).has_area()
			):
				roomy += 1
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
		"roomy_parks": roomy,
		"bushes": Num.i(green.get("bushes", 0)),
		"flower_beds": Num.i(green.get("flower_beds", 0)),
		"yards": Num.i(green.get("yards", 0)),
		"hedges": Num.i(green.get("hedges", 0)),
		"green_pct": 100.0 * green_area / maxf(1.0, city_area),
		"furthest_from_park_m": furthest,
	}


## A believable amount of green (D-065, director 2026-10-18: "make sure there are a believable
## amount of trees, bushes, floral areas, parks, gardens, playgrounds throughout the city"):
## street trees down every street at a real downtown spacing (both kerbs, one every
## city.street_tree_gap metres, fewer at crossings and lamps), a garden in every park and a
## playground in every park with room for one beside its path (a pocket park has none), and a
## hedge in the front yards. Everything is a crushable decor prop.
static func check_city(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check: Callable
) -> void:
	var got: Dictionary = measure(sim, decor)
	var gap := Num.f(sim.city["street_tree_gap"])
	var per_km := Num.f(got["trees_per_km"])
	# Both kerbs, every slot, less the crossings (street_tree_clear each side of a node) on the
	# city's shortest blocks; lamps and the diagonal take a few more.
	var short: Array = sim.city["block_short"]
	var shortest := Num.f(short[0])
	var clear := Num.f(sim.city["street_tree_clear"])
	var low := 2000.0 / gap * (1.0 - 2.0 * clear / shortest)
	var high := 2000.0 / gap  # both kerbs, every slot
	var parks := Num.i(got["parks"])
	check.call(
		(
			per_km >= low
			and per_km <= high
			and Num.i(got["playgrounds"]) == Num.i(got["roomy_parks"])
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
	# A steady row down each kerb: neighbours one street_tree_gap apart, or two where a lamp
	# took the slot between them, every trunk on the city-wide spacing (lead review round 4:
	# pairs 6 m apart beside 20 m gaps).
	var pairs := 0
	var uneven := 0
	var odd := 0.0
	for row: Array in green_of(decor).get("rows", []):
		for i: int in range(1, row.size()):
			var here: Vector2 = row[i]
			var before: Vector2 = row[i - 1]
			var d := here.distance_to(before)
			# ...and on one city-wide spacing, so the line carries on across the crossings.
			var off := fposmod(here.dot((here - before).normalized()) + gap * 0.5, gap) - gap * 0.5
			pairs += 1
			if (absf(d - gap) > 0.05 and absf(d - gap * 2.0) > 0.05) or absf(off) > 0.05:
				uneven += 1
				odd = d
	check.call(
		uneven == 0 and pairs > 0,
		(
			(
				"stage %d, map_seed %d: street trees stand a steady %.0f m apart down each kerb"
				% [tier, map_seed, gap]
			)
			+ " (%d of %d neighbours are not, e.g. %.1f m)" % [uneven, pairs, odd]
		)
	)
	# Trees and parking share the kerb: no car body within city.street_tree_car_clear of a trunk.
	var reach := Num.f(sim.city["street_tree_car_clear"])
	var trunks: Array = green_of(decor).get("trunks", [])
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


## decor.green, or {} for a CityDecor from before D-065.
static func green_of(decor: CityDecor) -> Dictionary:
	var got: Variant = decor.get("green")
	return got if got is Dictionary else {}
