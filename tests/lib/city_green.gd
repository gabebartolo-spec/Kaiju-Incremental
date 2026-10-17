extends RefCounted
## D-065 (director 2026-10-18: "make sure there are a believable amount of trees, bushes,
## floral areas, parks, gardens, playgrounds throughout the city"): measures a city's
## greenery the way a real downtown is judged. Street trees per km of avenue, the parks and
## what is in them, front yards and their hedges, the share of the playable city's blocks
## that are green, and the furthest any building stands from a park.


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
