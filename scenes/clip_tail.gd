class_name ClipTail
extends RefCounted
## The tail's mass on turns the clips don't carry (curves while walking, idle heading drift), for
## ClipGait: a damped spring driven by the body's turning acceleration (natural frequency rad/s and
## damping ratio as the turn clips' whip, motion_test TAIL_SPRING) plus a drag that trails the tail
## behind a body that is turning (a curve, not a rigid pole). The swing reaches each bone a moment
## after the one before, with a per-bone gain base -> tip (a mild one: a steep gain hooks the tip).

const SPRING := Vector2(14.0, 0.7)
const GAIN := Vector2(7.8, 4.0)
## How long the swing takes to reach each next bone (s).
const DELAY := 0.021
## The swing the spring eases towards and never passes (rad; the sim turns faster than the clips,
## so a sharp turn would curl the tail too far).
const MAX := 0.008
## The drag: swing per rad/s of the body's turn (smoothed over DRAG_SMOOTH seconds, so a stepped
## turn's slices do not whip it), and the most it swings (rad).
const DRAG := 0.004
const DRAG_SMOOTH := 0.3
const DRAG_MAX := 0.006

## The spring's swing from the body's turning (rad; not counting the clips' own tail motion), and
## the same eased to MAX: what the tail shows.
var swing := 0.0
var shown := 0.0
var _v := 0.0
var _at: Array[float] = []  # the swing as it reaches each bone
var _last_yaw := 0.0
var _last_rate := 0.0
var _drag_rate := 0.0
var _primed := false


func _init(bones: int) -> void:
	_at.resize(bones)
	_at.fill(0.0)


## One frame: the body's yaw now; `walking` (a standing turn's clip carries its own whip).
func step(body_yaw: float, walking: bool, dt: float) -> void:
	if not _primed:  # the first frame: no turning yet
		_primed = true
		_last_yaw = body_yaw
	var rate := wrapf(body_yaw - _last_yaw, -PI, PI) / dt
	var accel := (rate - _last_rate) / dt if walking else 0.0
	_last_yaw = body_yaw
	_last_rate = rate
	_drag_rate = lerpf(_drag_rate, rate if walking else 0.0, minf(1.0, dt / DRAG_SMOOTH))
	_v += (-SPRING.x * SPRING.x * swing - 2.0 * SPRING.y * SPRING.x * _v - accel) * dt
	swing += _v * dt
	shown = MAX * tanh(swing / MAX)
	var reach := 1.0 - exp(-dt / DELAY)
	var ahead := shown + clampf(-_drag_rate * DRAG, -DRAG_MAX, DRAG_MAX)
	for i: int in _at.size():
		_at[i] += (ahead - _at[i]) * reach
		ahead = _at[i]


## The bend (rad about the world's up) bone `i` takes on top of the clip's pose.
func bend(i: int) -> float:
	var k := float(i) / maxf(1.0, _at.size() - 1.0)
	return _at[i] * (GAIN.x + GAIN.y * k)
