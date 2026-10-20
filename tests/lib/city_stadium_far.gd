extends RefCounted
## The stadium is a reward for growing, not free biomass at the start (build 2 note 21: "the
## stadium is free biomass, it needs to be placed as far away from our spawn spot as possible";
## director 2026-10-20 picked "past the edge"): in the stage-1 city it stands wholly outside
## the baby's walk (real, in the band past the edge: the baby at the edge can still bite into
## it, as with every band block) and at least FAR m from the river rise; in the stage-2 city it
## is real and inside the play area. The wheel, moved with it, also stands past the baby's edge
## and never overlaps the stadium; no block's lot overlaps a landmark's plaza.

const FAR := 100.0


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	var plan := CityGen.map(sim.city)
	var here := sim.arena_half
	var stadium := _site(plan, "stadium", tier, map_seed, check_fn)
	var wheel := _site(plan, "wheel", tier, map_seed, check_fn)
	if stadium.is_empty() or wheel.is_empty():
		return
	var rect: Rect2 = stadium["rect"]
	var wheel_rect: Rect2 = wheel["rect"]
	_check_lots(plan, [rect, wheel_rect], tier, map_seed, check_fn)
	if tier >= 2:
		var inside := _reach(rect) <= here and CityBand.real(rect, sim.city)
		check_fn.call(
			inside,
			(
				"stage %d, map_seed %d: the stadium is real and inside the play area (reach %.1f, edge %.1f)"
				% [tier, map_seed, _reach(rect), here]
			)
		)
		return
	var spawn: Vector2 = plan.get("river_spawn", Vector2.ZERO)
	var far := spawn.distance_to(rect.get_center())
	check_fn.call(
		CityBand.near_edge(rect) > here and far >= FAR,
		(
			"stage 1, map_seed %d: the stadium stands %.0f m from the rise (>= %.0f), its near side %.1f m past the baby's edge %.1f"
			% [map_seed, far, FAR, CityBand.near_edge(rect) - here, here]
		)
	)
	check_fn.call(
		CityBand.near_edge(wheel_rect) > here and not wheel_rect.intersects(rect),
		(
			"stage 1, map_seed %d: the wheel stands past the baby's edge (near side %.1f, edge %.1f) clear of the stadium"
			% [map_seed, CityBand.near_edge(wheel_rect), here]
		)
	)


## The one site with this id (a missing or doubled site fails by name).
static func _site(
	plan: Dictionary, id: String, tier: int, map_seed: int, check_fn: Callable
) -> Dictionary:
	var found: Array[Dictionary] = []
	for s: Dictionary in plan.get("sites", []):
		if str(s["id"]) == id:
			found.append(s)
	check_fn.call(
		found.size() == 1,
		"stage %d, map_seed %d: exactly one %s site (%d)" % [tier, map_seed, id, found.size()]
	)
	return found[0] if found.size() == 1 else {}


## No ordinary block's lot reaches into a landmark plaza (the plaza now runs to the kerb).
static func _check_lots(
	plan: Dictionary, plazas: Array, tier: int, map_seed: int, check_fn: Callable
) -> void:
	var hits := 0
	for block: Dictionary in plan["blocks"]:
		if block.has("site"):
			continue
		var lot: Rect2 = block["rect"]
		if lot.size.x <= 0.0 or lot.size.y <= 0.0:
			continue  # a zero-width sliver between two close street lines holds no lot
		for plaza: Rect2 in plazas:
			if lot.grow(-0.01).intersects(plaza):
				hits += 1
	check_fn.call(
		hits == 0,
		"stage %d, map_seed %d: no block lot overlaps a landmark plaza (%d)" % [tier, map_seed, hits]
	)


## How far a rect reaches from the centre, measured square.
static func _reach(rect: Rect2) -> float:
	return maxf(
		maxf(absf(rect.position.x), absf(rect.end.x)), maxf(absf(rect.position.y), absf(rect.end.y))
	)
