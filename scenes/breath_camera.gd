class_name BreathCamera
extends RefCounted
## The camera move while Atomic Breath fires (lead-approved): the offset swings to the side and
## lifts so the beam crosses the screen instead of running straight away from the camera, holds
## while the beam fires, then eases back. The kaiju stays framed. Presentation only.

var _t := -1.0
var _side := 1.0


## Starts the move; side 1 swings one way, -1 the other (pick it from the kaiju's facing).
func start(side: float) -> void:
	_t = 0.0
	_side = side


## The camera offset this frame: `rest` when no breath is firing.
func offset(rest: Vector3, delta: float) -> Vector3:
	if _t < 0.0:
		return rest
	_t += delta
	var fx: Dictionary = Content.section("fx")
	var ease_in := Num.f(fx["orbit_in_seconds"])
	var hold := ease_in + Num.f(fx["beam_seconds"])
	var ease_out := Num.f(fx["orbit_out_seconds"])
	var w := smoothstep(0.0, ease_in, _t)
	if _t > hold:
		w = 1.0 - smoothstep(hold, hold + ease_out, _t)
	if _t > hold + ease_out:
		_t = -1.0
	var turn := deg_to_rad(Num.f(fx["orbit_degrees"])) * w * _side
	return rest.rotated(Vector3.UP, turn) + Vector3(0, Num.f(fx["orbit_rise"]) * w, 0)
