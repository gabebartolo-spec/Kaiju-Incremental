extends RefCounted
## The kaiju rises out of the water, not the street (director 2026-10-20: "make sure the river
## entrance shows our kaiju actually emerging from the water, not from the asphalt"): when a
## run starts, every disc of the reptilian's body (BodyContact, sized to the drawn model) lies
## inside the river's open water (its channel or the bay it rises in, CityRiver.water), not over
## the quay, the shore or the road past it.


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	var plan := CityGen.map(sim.city)
	if not plan.has("river"):
		return
	if not sim.body.active():
		sim.body.use_species("reptilian")
	var water := CityRiver.water(plan, sim.city)
	var sand := CityRiver.shore(plan, sim.city)  # the shore is not open water
	sim.emerge.start(sim)
	var bs := sim.body_scale()
	var out := 0.0  # how far the worst disc pokes out of the water
	for d: Array in sim.body.discs():
		var at := sim.kaiju_pos + sim.body.heading * Num.f(d[0]) * bs
		var r := Num.f(d[1]) * bs
		for edge: Vector2 in [
			at + Vector2(r, 0), at - Vector2(r, 0), at + Vector2(0, r), at - Vector2(0, r)
		]:
			out = maxf(out, _outside(water, edge))
			if sand.has_point(edge):
				out = maxf(out, sand.end.y - edge.y)
	(
		check_fn
		. call(
			out <= 0.05,
			(
				(
					"stage %d, map_seed %d: the kaiju rises with its whole body in the water (worst disc"
					% [tier, map_seed]
				)
				+ " %.2f m past the channel's edge, facing %s)" % [out, sim.body.heading]
			)
		)
	)


## How far p lies outside every rect of `water` (0 inside one).
static func _outside(water: Array[Rect2], p: Vector2) -> float:
	var best := INF
	for w: Rect2 in water:
		best = minf(best, p.distance_to(p.clamp(w.position, w.end)))
	return best
