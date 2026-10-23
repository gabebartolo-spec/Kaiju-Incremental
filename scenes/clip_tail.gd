class_name ClipTail
extends RefCounted
## The tail's mass on turns the clips don't carry (curves while walking, idle heading drift), for
## ClipGait: a damped spring driven by the body's turning acceleration (natural frequency rad/s and
## damping ratio as the turn clips' whip, motion_test TAIL_SPRING) plus a drag that trails the tail
## behind a body that is turning (a curve, not a rigid pole). The swing reaches each bone a moment
## after the one before, with a per-bone gain base -> tip (a mild one: a steep gain hooks the tip).
## A weight class (tuning "body_class" tail) sets its own numbers and may drive it in every clip.

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
var _spring := SPRING
var _gain := GAIN
var _max := MAX
var _drag := DRAG
var _drag_max := DRAG_MAX
var _drag_smooth := DRAG_SMOOTH
var _delay := DELAY
var _always := false


## tune: a weight class's tail (tuning "body_class"), or {} for the constants above.
func _init(bones: int, tune: Dictionary = {}) -> void:
	_at.resize(bones)
	_at.fill(0.0)
	if tune.is_empty():
		return
	var gain: Array = tune["gain"]
	_spring = Vector2(Num.f(tune["spring_hz"]), Num.f(tune["spring_zeta"]))
	_gain = Vector2(Num.f(gain[0]), Num.f(gain[1]))
	_max = Num.f(tune["max"])
	_drag = Num.f(tune["drag"])
	_drag_max = Num.f(tune["drag_max"])
	_drag_smooth = Num.f(tune["drag_smooth"])
	_delay = Num.f(tune["delay"])
	_always = tune["always"] == true


## One frame: the body's yaw now; `walking` (a standing turn's clip carries its own whip, unless
## the class drives the tail always).
func step(body_yaw: float, walking: bool, dt: float) -> void:
	walking = walking or _always
	if not _primed:  # the first frame: no turning yet
		_primed = true
		_last_yaw = body_yaw
	var rate := wrapf(body_yaw - _last_yaw, -PI, PI) / dt
	var accel := (rate - _last_rate) / dt if walking else 0.0
	_last_yaw = body_yaw
	_last_rate = rate
	_drag_rate = lerpf(_drag_rate, rate if walking else 0.0, minf(1.0, dt / _drag_smooth))
	_v += (-_spring.x * _spring.x * swing - 2.0 * _spring.y * _spring.x * _v - accel) * dt
	swing += _v * dt
	shown = _max * tanh(swing / _max)
	var reach := 1.0 - exp(-dt / _delay)
	var ahead := shown + clampf(-_drag_rate * _drag, -_drag_max, _drag_max)
	for i: int in _at.size():
		_at[i] += (ahead - _at[i]) * reach
		ahead = _at[i]


## The bend (rad about the world's up) bone `i` takes on top of the clip's pose.
func bend(i: int) -> float:
	var k := float(i) / maxf(1.0, _at.size() - 1.0)
	return _at[i] * (_gain.x + _gain.y * k)
