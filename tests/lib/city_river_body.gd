extends RefCounted
## The kaiju rises out of the water, not the street (director 2026-10-20: "make sure the river
## entrance shows our kaiju actually emerging from the water, not from the asphalt"): when a
## run starts, every disc of the reptilian's body (BodyContact, sized to the drawn model) lies
## inside the sea bay's open water (CityHarbour.holds; 2026-10-26 "Sea bay, real beach"), not
## over the quay, the beach or the road past it.


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	var plan := CityGen.map(sim.city)
	if not plan.has("harbour"):
		return
	if not sim.body.active():
		sim.body.use_species("reptilian")
	var water := CityHarbour.bands(plan, sim.city)
	var beach := Num.f(sim.city["harbour"]["beach"])  # the beach's slope is not open water
	sim.emerge.start(sim)
	var bs := sim.body_scale()
	var out := 0.0  # how far the worst disc pokes out of the water
	for d: Array in sim.body.discs():
		var at := sim.kaiju_pos + sim.body.heading * Num.f(d[0]) * bs
		var r := Num.f(d[1]) * bs
		for edge: Vector2 in [
			at + Vector2(r, 0), at - Vector2(r, 0), at + Vector2(0, r), at - Vector2(0, r)
		]:
			if not CityHarbour.holds(plan, edge):
				out = maxf(out, maxf(0.001, _outside(water, edge)))
			else:
				out = maxf(out, beach - CityHarbour.from_shore(plan, sim.city, edge))
	(
		check_fn
		. call(
			out <= 0.05,
			(
				(
					"stage %d, map_seed %d: the kaiju rises with its whole body in the water (worst disc"
					% [tier, map_seed]
				)
				+ " %.2f m past the open water's edge, facing %s)" % [out, sim.body.heading]
			)
		)
	)


## How far p lies outside every rect of `water` (0 inside one).
static func _outside(water: Array[Rect2], p: Vector2) -> float:
	var best := INF
	for w: Rect2 in water:
		best = minf(best, p.distance_to(p.clamp(w.position, w.end)))
	return best
