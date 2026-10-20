extends RefCounted
## The stadium stands as far from the kaiju's rise as it can (director, build 2 note 21: "the
## stadium is free biomass, it needs to be placed as far away from our spawn spot as possible
## to make it less farmable"): of every site the stadium fits in the first city (each pair of
## grid cells as its anchor, CitySites' own rules for what fits), none lies further from where
## the kaiju actually rises (the river spawn, CityRiver) than the one it gets.

## The rise point CitySites aims from is the river row's middle on the axis; the real spawn sits
## within a street's half width of it, so the stadium may come out this much short of the best.
const SLACK := 2.0


static func check(map_seeds: Array[int], check_fn: Callable) -> void:
	for map_seed: int in map_seeds:
		var cfg: Dictionary = Content.section("city").duplicate(true)
		cfg["map_seed"] = map_seed
		var plan := CityGen.map(cfg)
		var spawn: Vector2 = plan.get("river_spawn", Vector2(INF, INF))
		var got := -1.0
		for site: Dictionary in plan["sites"]:
			if str(site["id"]) == "stadium":
				var rect: Rect2 = site["rect"]
				got = rect.get_center().distance_to(spawn)
		var best := _best(plan, cfg, spawn)
		check_fn.call(
			spawn.x < INF and got > 0.0 and got >= best - SLACK,
			(
				(
					"map_seed %d: the stadium stands %.1f from the kaiju's rise at %s (the furthest"
					+ " site it fits: %.1f)"
				)
				% [map_seed, got, spawn, best]
			)
		)


## The furthest any stadium site in the first district lies from `spawn`.
static func _best(plan: Dictionary, cfg: Dictionary, spawn: Vector2) -> float:
	var spec: Dictionary = {}
	for s: Dictionary in cfg["landmarks"]:
		if str(s["id"]) == "stadium":
			spec = s
	var shape: Dictionary = cfg["landmark_shapes"]["stadium"]
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var rings := CityGen.districts(cfg)
	var avenues: Array = plan["avenues"]
	var axes := [
		{"lines": xs, "rings": rings, "avenues": avenues[0], "cfg": cfg},
		{"lines": zs, "rings": rings, "avenues": avenues[1], "cfg": cfg},
	]
	var best := 0.0
	for i: int in xs.size() - 1:
		for j: int in zs.size() - 1:
			var at := Vector2(xs[i] + xs[i + 1], zs[j] + zs[j + 1]) * 0.5
			if maxf(absf(at.x), absf(at.y)) >= rings[0]:
				continue
			var none: Array[Dictionary] = []
			var site := CitySites._site(plan, axes, at, spec, shape, none)
			if not site.is_empty():
				var rect: Rect2 = site["rect"]
				best = maxf(best, rect.get_center().distance_to(spawn))
	return best
