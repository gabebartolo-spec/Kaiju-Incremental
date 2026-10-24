extends RefCounted
## Every building in the play area can be destroyed (director, build 2 note 6: "ALL buildings in
## the play area must be destroyable"). Past the arena's edge, as far as the game camera shows
## (city.view_beyond), every block holds real buildings (CityBand); the skyline's
## painted stand-ins only start past that, and every real building falls when its chunks break.


## How far past the arena's edge a rect starts (negative: it overlaps the arena).
static func past_edge(rect: Rect2, arena_half: float) -> float:
	return CityBand.near_edge(rect) - arena_half


## No outer (stand-in) block of the street plan starts inside the band the camera shows past
## the arena's edge, at every size tier, for each street plan in map_seeds.
static func check_plan(map_seeds: Array[int], check: Callable) -> void:
	for tier: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
		for map_seed: int in map_seeds:
			var city: Dictionary = CityGrowth.tuning_for(Content.tuning(), tier)["city"]
			city["map_seed"] = map_seed
			var arena := CityGen.half_extent(city) + Num.f(city["arena_margin"])
			var view := Num.f(city["view_beyond"])
			var nearest := INF
			for block: Dictionary in CityGen.map(city)["blocks"]:
				var rect: Rect2 = block["rect"]
				if str(block["use"]) == "outer":
					nearest = minf(nearest, past_edge(rect, arena))
			check.call(
				nearest >= view,
				(
					(
						"stage %d, map_seed %d: every block on screen past the edge (%.0f) is real"
						+ " buildings; the nearest stand-in block starts %.1f past it"
					)
					% [tier, map_seed, view, nearest]
				)
			)


## In a built city: every skyline stand-in stands past the band the camera shows, and every
## real building can be destroyed (each chunk broken, nothing is left standing).
static func check_city(
	tier: int, map_seed: int, sim: RampageSim, skyline: CitySkyline, check: Callable
) -> void:
	var view := Num.f(sim.city["view_beyond"])
	var nearest := INF
	for box: Dictionary in skyline.stand_ins():
		var size: Vector3 = box["size"]
		var at: Vector3 = box["at"]
		var rect := Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z)
		nearest = minf(nearest, past_edge(rect, sim.arena_half))
	var whole := 0
	for b: RampageSim.Building in sim.buildings:
		for y: int in b.frame.h:
			for z: int in b.frame.d:
				for x: int in b.frame.w:
					b.frame.damage(Vector3i(x, y, z), INF)
		whole += 1 if b.frame.alive_count == 0 else 0
	(
		check
		. call(
			nearest >= view and whole == sim.buildings.size() and whole > 0,
			(
				(
					"stage %d, map_seed %d: the nearest stand-in is %.1f past the edge (camera band %.0f),"
					+ " and %d of %d buildings break down to nothing"
				)
				% [tier, map_seed, nearest, view, whole, sim.buildings.size()]
			)
		)
	)
