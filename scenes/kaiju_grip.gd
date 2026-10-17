class_name KaijuGrip
extends RefCounted
## Where a kaiju limb can take hold of the city (presentation only; the sim decides nothing from
## it). Rampage hands KaijuModel.set_grip_finder a finder built on this.


## A tentacle's hold: the nearest standing building edge to `at` within `radius` (presentation;
## the sim decides nothing from it): on the footprint's rim, at the roof or at most tentacle
## height up the wall. Vector3.INF when nothing is close.
static func point(sim: RampageSim, at: Vector3, radius: float) -> Vector3:
	var best := Vector3.INF
	var best_d := radius
	var reach_up := 4.0 * sim.body_scale()
	for b: RampageSim.Building in sim.buildings:
		if b.frame.alive_count <= 0:
			continue
		var lo := Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5)
		var hi := Vector2(b.x + b.w * 0.5, b.z + b.d * 0.5)
		var p := Vector2(at.x, at.z)
		var q := p.clamp(lo, hi)
		if q == p:  # inside the footprint: out to the nearest wall
			var gaps := [p.x - lo.x, hi.x - p.x, p.y - lo.y, hi.y - p.y]
			var side: int = gaps.find(gaps.min())
			q = [Vector2(lo.x, p.y), Vector2(hi.x, p.y), Vector2(p.x, lo.y), Vector2(p.x, hi.y)][side]
		var d := q.distance_to(p)
		if d >= best_d:
			continue
		var cx := clampi(floori(q.x - lo.x), 0, b.w - 1)
		var cz := clampi(floori(q.y - lo.y), 0, b.d - 1)
		var top := b.frame.top_below(cx, cz, b.height)
		if top < 0:
			continue
		best_d = d
		best = Vector3(q.x, minf(top + 1.0, reach_up), q.y)
	return best
