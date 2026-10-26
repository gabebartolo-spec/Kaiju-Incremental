class_name StandingChunks
extends RefCounted
## Split from RampageSim (its 400-line cap): where the standing city is nearest.


## Nearest standing ground-floor chunk in the arena to `from` (an attacker's goal), or INF.
static func nearest(sim: RampageSim, from: Vector2) -> Vector2:
	var best := Vector2(INF, INF)
	var best_d := INF
	for b: RampageSim.Building in sim.buildings:
		if b.frame.alive_count == 0 or not b.in_arena:
			continue
		for x: int in b.w:
			for z: int in b.d:
				if b.frame.alive(Vector3i(x, 0, z)):
					var p := b.chunk_world(Vector3i(x, 0, z))
					var d := from.distance_squared_to(Vector2(p.x, p.z))
					if d < best_d:
						best_d = d
						best = Vector2(p.x, p.z)
	return best
