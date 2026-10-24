extends RefCounted
## Every bridge meets land on both banks (director, build 4 comments 2026-10-21 #12: "bridge is
## not connected to land"): for every deck CityRiver.bridges lays, at stages 1-3 in three
## cities, the deck spans the whole open water (CityRiver.channels) from bank to bank, and the
## ground just past each deck end is land (out of the channel), so no water shows between a
## deck end and the road on its bank.
## Seeded by design: the street plan is fixed by city.map_seed.

const STAGES: Array[int] = [1, 2, 3]
const STEP := 0.25  # how far past a deck end the bank road is sampled (m)
const EPS := 0.01


static func check(seeds: Array[int], check_fn: Callable) -> void:
	for tier: int in STAGES:
		for map_seed: int in seeds:
			var base: Dictionary = Content.tuning().duplicate(true)
			var city_cfg: Dictionary = base["city"]
			city_cfg["map_seed"] = map_seed
			var cfg: Dictionary = CityGrowth.tuning_for(base, tier)["city"]
			_check_city(tier, map_seed, cfg, check_fn)


static func _check_city(tier: int, map_seed: int, cfg: Dictionary, check_fn: Callable) -> void:
	var plan := CityGen.map(cfg)
	if not plan.has("river"):
		return
	var water := CityRiver.channels(plan, cfg)
	var decks := CityRiver.bridges(plan, cfg)
	var bad := 0
	var worst := 0.0  # the widest strip of water between a deck end and its bank (m)
	var at := Vector2.ZERO
	for deck: Rect2 in decks:
		for w: Rect2 in water:
			if deck.position.x < w.position.x or deck.end.x > w.end.x:
				continue
			var gap := maxf(deck.position.y - w.position.y, w.end.y - deck.end.y)
			var mid := deck.get_center().x
			var ends: Array[Vector2] = [
				Vector2(mid, deck.position.y - STEP), Vector2(mid, deck.end.y + STEP)
			]
			var wet := false
			for p: Vector2 in ends:
				wet = wet or w.has_point(p)
			if gap > EPS or wet:
				bad += 1
				if gap > worst:
					worst = gap
					at = deck.get_center()
	check_fn.call(
		not decks.is_empty() and bad == 0,
		(
			(
				"stage %d, map_seed %d: every bridge meets land on both banks (%d decks, %d"
				% [tier, map_seed, decks.size(), bad]
			)
			+ " short of a bank, widest water gap %.2f m at %s)" % [worst, at]
		)
	)
