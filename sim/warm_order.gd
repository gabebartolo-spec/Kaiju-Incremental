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
	for n: int in sim.grid.around(sim.kaiju_pos, reach + 2.0 * sim.grid.pad):
		if carving.promoted(n) or not carving.takes(n):
			continue
		var b := buildings[n]
		var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if d - Vector2(b.w, b.d).length() * 0.5 > reach or d >= best_d:
			continue
		best = n
		best_d = d
	return best


## Up to `count` unpromoted carvable buildings within the same reach as next_cold, nearest first
## (ties by building index).
static func cold(
	carving: Carving, buildings: Array[RampageSim.Building], margin: float, count: int
) -> Array[int]:
	var sim := carving.sim
	var reach := maxf(2.0 * sim.stomp_radius(), sim.ability_reach()) + margin
	var found: Array[Vector2] = []  # (distance, index)
	for n: int in sim.grid.around(sim.kaiju_pos, reach + 2.0 * sim.grid.pad):
		if carving.promoted(n) or not carving.takes(n):
			continue
		var b := buildings[n]
		var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if d - Vector2(b.w, b.d).length() * 0.5 <= reach:
			found.append(Vector2(d, n))
	found.sort()
	var out: Array[int] = []
	for k: int in mini(count, found.size()):
		out.append(int(found[k].y))
	return out
