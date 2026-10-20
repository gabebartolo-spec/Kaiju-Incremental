extends RefCounted
## The stadium is a reward for growing, not free biomass at the start (build 2 note 21: "the
## stadium is free biomass, it needs to be placed as far away from our spawn spot as possible";
## director 2026-10-20 picked "past the edge"): in the stage-1 city it stands wholly outside
## the baby's play area (real, in the band past the edge, out of its walk) and at least
## FAR m from the river rise; the first growth's play area takes it in.

const FAR := 100.0


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	if tier != 1:
		return
	var plan := CityGen.map(sim.city)
	var spawn: Vector2 = plan.get("river_spawn", Vector2.ZERO)
	var site := {}
	for s: Dictionary in plan.get("sites", []):
		if str(s["id"]) == "stadium":
			site = s
	if site.is_empty():
		check_fn.call(false, "stage 1, map_seed %d: the stadium has a site" % map_seed)
		return
	var rect: Rect2 = site["rect"]
	var here := sim.arena_half
	var grown: Dictionary = CityGrowth.tuning_for(_with_seed(map_seed), 2)["city"]
	var next := CityGen.half_extent(grown) + Num.f(grown["arena_margin"])
	var far := spawn.distance_to(rect.get_center())
	var outside := CityBand.near_edge(rect) > here
	var later := (
		maxf(
			maxf(absf(rect.position.x), absf(rect.end.x)),
			maxf(absf(rect.position.y), absf(rect.end.y))
		)
		<= next
	)
	check_fn.call(
		outside and later and far >= FAR,
		(
			(
				"stage 1, map_seed %d: the stadium stands %.0f m from the rise (>= %.0f), past the"
				% [map_seed, far, FAR]
			)
			+ (
				" baby's play area (%s, edge %.1f) and inside the next stage's (%s, edge %.1f)"
				% [outside, here, later, next]
			)
		)
	)


static func _with_seed(map_seed: int) -> Dictionary:
	var t: Dictionary = Content.tuning().duplicate(true)
	t["city"]["map_seed"] = map_seed
	return t
