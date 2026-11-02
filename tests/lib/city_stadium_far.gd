extends RefCounted
## The stadium is a reward for growing, not free biomass at the start (build 2 note 21: "the
## stadium is free biomass, it needs to be placed as far away from our spawn spot as possible"):
## at every stage it stands at least FAR m from the rise. Every landmark spot stands from stage 1
## in the one adult city (D-436), so the old "past the baby's edge" bar (2026-10-20) is gone.
## The wheel, moved with it, never overlaps the stadium; no block's lot overlaps a landmark's
## plaza.

const FAR := 100.0


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	var plan := CityGen.map(sim.city)
	var stadium := _site(plan, "stadium", tier, map_seed, check_fn)
	var wheel := _site(plan, "wheel", tier, map_seed, check_fn)
	if stadium.is_empty() or wheel.is_empty():
		return
	var rect: Rect2 = stadium["rect"]
	var wheel_rect: Rect2 = wheel["rect"]
	_check_lots(plan, [rect, wheel_rect], tier, map_seed, check_fn)
	var spawn: Vector2 = plan.get("rise_spawn", Vector2.ZERO)
	var far := spawn.distance_to(rect.get_center())
	check_fn.call(
		far >= FAR,
		(
			"stage %d, map_seed %d: the stadium stands %.0f m from the rise (>= %.0f)"
			% [tier, map_seed, far, FAR]
		)
	)
	check_fn.call(
		not wheel_rect.intersects(rect),
		"stage %d, map_seed %d: the wheel stands clear of the stadium" % [tier, map_seed]
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
		(
			"stage %d, map_seed %d: no block lot overlaps a landmark plaza (%d)"
			% [tier, map_seed, hits]
		)
	)
