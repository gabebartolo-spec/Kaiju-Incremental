extends RefCounted
## The play area's edge is marked (director 2026-10-20: "the edge of the play area needs to be
## indicated somehow (not too loud) so players dont continuously try to destroy indestructible
## buildings"): ArenaEdge stands bollards on the pavement just past the arena's edge. Every
## bollard is on that line, none over water, on a street or in a street tree's trunk; every
## side but the river's carries at least 35% of the bollards its length allows (counted per
## side, corners apart, so two corner posts cannot pass for a side: critic on #114).


static func check(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check_fn: Callable
) -> void:
	var cfg: Dictionary = Content.tuning()["arena_edge"]
	var half := sim.arena_half + Num.f(cfg["out"])
	var clear := Num.f(cfg["tree_clear"])
	var trees := ArenaEdge.trees_of(decor)
	var posts := ArenaEdge.spots(sim, trees)
	var plan := CityGen.map(sim.city)
	var water := CityRiver.channels(plan, sim.city)
	var roads := ArenaEdge._roads(plan, sim.city, half)
	var per_side := {"n": 0, "s": 0, "e": 0, "w": 0}
	var bad := {"off": 0, "wet": 0, "road": 0, "tree": 0}
	for d: Vector3 in posts:
		var ground := Vector2(d.x, d.z)
		var on_x := is_equal_approx(absf(d.x), half)
		var on_z := is_equal_approx(absf(d.z), half)
		if not on_x and not on_z:
			bad["off"] += 1
		elif on_z and not on_x:
			per_side["s" if d.z > 0.0 else "n"] += 1
		elif on_x and not on_z:
			per_side["e" if d.x > 0.0 else "w"] += 1
		if water.any(func(r: Rect2) -> bool: return r.has_point(ground)):
			bad["wet"] += 1
		if ArenaEdge.on_road(ground, roads):
			bad["road"] += 1
		if trees.any(func(t: Vector2) -> bool: return t.distance_to(ground) < clear):
			bad["tree"] += 1
	var want := int(half * 2.0 / Num.f(cfg["spacing"]) * 0.35)  # streets crossing leave gaps
	var river_side := "s" if plan.has("river") else ""
	var thin := []
	for side: String in per_side:
		if side != river_side and Num.i(per_side[side]) < want:
			thin.append(side)
	var clean: bool = bad.values().all(func(v: int) -> bool: return v == 0)
	check_fn.call(
		clean and thin.is_empty() and not trees.is_empty(),
		(
			(
				"stage %d, map_seed %d: the edge is marked on every side but the river (%s, want"
				% [tier, map_seed, per_side]
			)
			+ " >= %d each; thin %s; bad %s; %d street trees)" % [want, thin, bad, trees.size()]
		)
	)
