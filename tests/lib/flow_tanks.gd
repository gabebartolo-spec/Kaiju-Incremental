extends RefCounted
## Flow-test helper: the army holds its standoff, and a rampage that clears the city fast may never
## pass in reach of a tank, so a powers check walks the kaiju to one when none has fired.


## Puts the kaiju a stomp's reach from the nearest tank, on the side it came from, so the army
## fires at it (the armour cues are what the powers check hears).
static func walk_to_nearest(sim: RampageSim) -> void:
	var best: RampageSim.Tank = null
	for tank: RampageSim.Tank in sim.tanks:
		if (
			best == null
			or tank.pos.distance_to(sim.kaiju_pos) < best.pos.distance_to(sim.kaiju_pos)
		):
			best = tank
	if best != null:
		var away := (sim.kaiju_pos - best.pos).normalized()
		sim.kaiju_pos = sim.clamp_to_arena(best.pos + away * Num.f(sim.army["range"]) * 0.5)
