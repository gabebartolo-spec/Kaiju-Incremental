class_name AutoWalk
extends RefCounted
## Rampage's autoplay steering (tests and captures): walk toward the nearest standing ground-floor
## chunk, re-aimed every 15 physics steps (paced on the step count, never the clock).

var _target := Vector2(INF, INF)


func move(sim: RampageSim, steps: int) -> Vector2:
	if steps % 15 == 0 or _target.x == INF:
		_target = sim.nearest_standing(sim.kaiju_pos)
	var to := _target - sim.kaiju_pos
	if _target.x == INF or sim.stomp_reaches(_target):
		return Vector2.ZERO
	return to.normalized()
