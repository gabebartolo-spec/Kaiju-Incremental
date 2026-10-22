class_name AutoWalk
extends RefCounted
## Rampage's autoplay steering (tests and captures): walk toward the nearest standing ground-floor
## chunk, re-aimed every 15 physics steps (paced on the step count, never the clock).

## Autoplay holds the signature for GLIDE_HELD of every GLIDE_CYCLE steps.
const GLIDE_CYCLE := 90
const GLIDE_HELD := 50

var _target := Vector2(INF, INF)


func move(sim: RampageSim, steps: int) -> Vector2:
	if steps % 15 == 0 or _target.x == INF:
		_target = sim.nearest_standing(sim.kaiju_pos)
	var to := _target - sim.kaiju_pos
	if _target.x == INF or to.length() < sim.stomp_radius() * 0.5:
		return Vector2.ZERO
	return to.normalized()


## The autoplay's presses, paced on the step count: the signature whenever it is ready, held for
## GLIDE_HELD of every GLIDE_CYCLE steps (the insectoid's glide), the ultimate whenever it can.
func presses(sim: RampageSim, steps: int, signature_on: bool) -> Dictionary:
	return {
		"move": move(sim, steps),
		"signature": signature_on and sim.ability_ready_in <= 0.0,
		"held": signature_on and steps % GLIDE_CYCLE < GLIDE_HELD,
		"ultimate": signature_on,
	}
