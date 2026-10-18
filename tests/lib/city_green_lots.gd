extends RefCounted
## D-075 (director 2026-10-18: green lots at 8% of the city, answering D-065(b)): the city
## suite's green-lot checks, called from its D-062 loop for each stage and map_seed.
##   1. Share and spread: parks, plazas and green lots cover at least city.green_lot_share of
##      the playable city's block area (less SHARE_SLACK, a small city's blocks come in big
##      steps) and at most SHARE_CAP, and no building stands more than SPREAD_BLOCKS of the
##      city's longest blocks (city.block_long) from one.
##   2. A green lot holds no building, and it is the same block at stage 1 and the Behemoth,
##      so an evolution never turns a park back into buildings.

const Green := preload("res://tests/lib/city_green.gd")
const SHARE_SLACK := 0.015
const SHARE_CAP := 0.12
const SPREAD_BLOCKS := 2.0


static func check(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check_fn: Callable
) -> void:
	var got: Dictionary = Green.measure(sim, decor)
	var share := Num.f(sim.city.get("green_lot_share", 0.0))
	var pct := Num.f(got["green_pct"]) / 100.0
	var long: Array = sim.city["block_long"]
	var reach := SPREAD_BLOCKS * Num.f(long[1])
	var furthest := Num.f(got["furthest_from_park_m"])
	check_fn.call(
		pct >= share - SHARE_SLACK and pct <= SHARE_CAP and share > 0.0 and furthest <= reach,
		(
			(
				"stage %d, map_seed %d: green lots (%.1f%% of the blocks green, want %.1f-%.0f%%;"
				+ " furthest building %.0f m from a park, want <= %.0f m)"
			)
			% [
				tier,
				map_seed,
				pct * 100.0,
				(share - SHARE_SLACK) * 100.0,
				SHARE_CAP * 100.0,
				furthest,
				reach
			]
		)
	)
	var lots := _green_lots(sim.city)
	var inside := 0
	for b: RampageSim.Building in sim.buildings:
		for rect: Rect2 in lots:
			if rect.has_point(Vector2(b.x, b.z)):
				inside += 1
	var stage_one: Dictionary = CityGrowth.tuning_for(_with_seed(map_seed), 1)["city"]
	var first := _green_lots(stage_one)
	check_fn.call(
		not lots.is_empty() and inside == 0 and lots == first,
		(
			"stage %d, map_seed %d: %d green lots hold %d buildings, the same blocks as stage 1: %s"
			% [tier, map_seed, lots.size(), inside, lots == first]
		)
	)


## The green lots' rects, in plan order.
static func _green_lots(cfg: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for block: Dictionary in CityGen.map(cfg)["blocks"]:
		if block.has("green"):
			var rect: Rect2 = block["rect"]
			out.append(rect)
	return out


static func _with_seed(map_seed: int) -> Dictionary:
	var base: Dictionary = Content.tuning().duplicate(true)
	var city: Dictionary = base["city"]
	city["map_seed"] = map_seed
	return base
