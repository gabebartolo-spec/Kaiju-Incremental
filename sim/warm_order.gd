class_name WarmOrder
extends RefCounted
## Which building Carving.warm() makes ready next (b2-3), split out to keep carving.gd small.


## The unpromoted carvable building nearest the kaiju whose nearest edge is within its strike
## reach plus `margin` (-1: none). Nearest first, ties by building index: the same order for the
## same run.
static func next_cold(
	carving: Carving, buildings: Array[RampageSim.Building], margin: float
) -> int:
	var sim := carving.sim
	var reach := maxf(2.0 * sim.stomp_radius(), sim.ability_reach()) + margin
	var best := -1
	var best_d := INF
	for n: int in buildings.size():
		if carving.promoted(n) or not carving.takes(n):
			continue
		var b := buildings[n]
		var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if d - Vector2(b.w, b.d).length() * 0.5 > reach or d >= best_d:
			continue
		best = n
		best_d = d
	return best
