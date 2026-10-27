class_name CameraYaw
extends RefCounted
## Where the game camera stands round the kaiju (D-330, director: "the game camera stays at his back
## and turns slowly with him, as heavy as his turn"). `turn` is how far the camera has swung from
## its rest side (data/tuning.json camera.offset: due +z of him) round to his back: it follows the
## way he faces, at camera.yaw_share of his own heavy turn rate (BodyContact, for his size),
## gathering that speed over camera.yaw_ease_s and slowing before it lands, never overshooting
## (the law of BodyContact.steer). Pure sim state, so a replay and the helicopters (AirFlight,
## which keep off the camera's side) see the same camera; the scenes only draw it.

## The camera's swing from its rest side, radians (counter-clockwise on the ground plane, x to z).
var turn := 0.0
var _rest: float  # the rest offset's bearing from him (radians)
var _spin := 0.0  # how fast it swings now (rad/s, signed as turn)
var _share: float
var _ease: float


## `cfg`: tuning "camera". `facing`: the way he faces now; the camera starts behind him.
func _init(cfg: Dictionary, facing: Vector2) -> void:
	var o: Array = cfg["offset"]
	_rest = atan2(Num.f(o[2]), Num.f(o[0]))
	_share = Num.f(cfg["yaw_share"])
	_ease = Num.f(cfg["yaw_ease_s"])
	snap(facing)


## The camera at his back at once (the run's rise, where the intro's shot ends on it).
func snap(facing: Vector2) -> void:
	turn = _behind(facing)
	_spin = 0.0


## The bearing from him to the camera (radians).
func bearing() -> float:
	return _rest + turn


## One step: swing toward his back at no more than `share` x `rate` (his turn rate, rad/s).
func step(facing: Vector2, rate: float, dt: float) -> void:
	var top := rate * _share
	var accel := top / maxf(_ease, 0.001)
	var left := wrapf(_behind(facing) - turn, -PI, PI)
	# Braking is judged from where this step's move leaves it, so it slows into his back
	# (a stop from a whole frame's lag would land at a sixth of its top speed).
	var rest := maxf(0.0, absf(left) - absf(_spin) * dt)
	var aim := signf(left) * minf(top, sqrt(2.0 * accel * rest))
	_spin = move_toward(_spin, aim, accel * dt)
	var by := _spin * dt
	if signf(by) == signf(left) and absf(by) >= absf(left):
		by = left  # lands on his back exactly
		_spin = 0.0
	turn = wrapf(turn + by, -PI, PI)


## The turn that puts the camera straight behind `facing`.
func _behind(facing: Vector2) -> float:
	return wrapf(facing.angle() + PI - _rest, -PI, PI)
