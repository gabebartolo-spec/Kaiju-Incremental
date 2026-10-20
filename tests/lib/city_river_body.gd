extends RefCounted
## The kaiju rises out of the water, not the street (director 2026-10-20: "make sure the river
## entrance shows our kaiju actually emerging from the water, not from the asphalt"): when a
## run starts, every disc of the reptilian's body (BodyContact, sized to the drawn model) lies
## inside the river's open water, not over the quay or the road past it.


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	var plan := CityGen.map(sim.city)
	if not plan.has("river"):
		return
	if not sim.body.active():
		sim.body.use_species("reptilian")
	var water := CityRiver.channels(plan, sim.city)
	sim.emerge.start(sim)
	var bs := sim.body_scale()
	var out := 0.0  # how far the worst disc pokes out of the water
	for d: Array in sim.body.discs():
		var at := sim.kaiju_pos + sim.body.heading * Num.f(d[0]) * bs
		var r := Num.f(d[1]) * bs
		var w := water[0]
		var past := maxf(
			maxf(w.position.x - (at.x - r), (at.x + r) - w.end.x),
			maxf(w.position.y - (at.y - r), (at.y + r) - w.end.y)
		)
		out = maxf(out, past)
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
