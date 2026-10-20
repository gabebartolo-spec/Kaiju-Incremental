extends RefCounted
## The play area's edge is marked (director 2026-10-20: "the edge of the play area needs to be
## indicated somehow (not too loud) so players dont continuously try to destroy indestructible
## buildings"): ArenaEdge stands bollards on every side but the river, every one on the
## pavement just past the arena's edge, none over the river's water.


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	var edge := ArenaEdge.new(sim)
	var half := sim.arena_half + Num.f(Content.tuning()["arena_edge"]["out"])
	var water := CityRiver.channels(CityGen.map(sim.city), sim.city)
	var sides := {}
	var off := 0
	var wet := 0
	for d: Vector3 in edge.posts:
		var on_x := is_equal_approx(absf(d.x), half)
		var on_z := is_equal_approx(absf(d.z), half)
		if not on_x and not on_z:
			off += 1
		sides["x%d" % signi(int(d.x))] = sides.get("x%d" % signi(int(d.x)), false) or on_x
		sides["z%d" % signi(int(d.z))] = sides.get("z%d" % signi(int(d.z)), false) or on_z
		for r: Rect2 in water:
			wet += 1 if r.has_point(Vector2(d.x, d.z)) else 0
	var all_sides := sides.values().count(true) >= 3  # the river is the fourth, where it runs
	(
		check_fn
		. call(
			not edge.posts.is_empty() and off == 0 and wet == 0 and all_sides,
			(
				(
					"stage %d, map_seed %d: the edge is marked on every side but the river (%d bollards,"
					% [tier, map_seed, edge.posts.size()]
				)
				+ " %d off the edge, %d over water)" % [off, wet]
			)
		)
	)
	edge.free()
