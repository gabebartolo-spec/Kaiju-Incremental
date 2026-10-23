class_name TailSim
extends RefCounted
## A heavy body's tail as the sim's own (D-208, "any contact a kaiju has with a building will
## damage it"): its swing, drag and sway worked out here, deterministically, from the body's yaw
## (BodyContact.body_dir) and time, and its chain of bones laid over the ground on them, so the
## body volume's tail discs ride the tail the player sees (the presentation reads `bends` and adds
## no swing of its own). The tail's mass on turns: a damped spring driven by the body's turning
## acceleration, a drag that trails it behind a turning body, and a sway that never stops, each
## reaching every bone a moment after the one before (ClipTail's model, moved into the sim).
## Numbers: tuning "body_class" <class> "tail"; its "chain" is fitted to the drawn tail
## (tools/capture/fit_tail_chain.gd). Pure, no randomness.

## Each tail bone's bend (rad about the world's up, on top of its parent's; + turns it left as the
## presentation's yaw does), base to tip.
var bends: Array[float] = []
var _spring := Vector2.ZERO
var _gain := Vector2.ZERO
var _max := 0.0
var _drag := 0.0
var _drag_max := 0.0
var _drag_smooth := 1.0
var _delay := 1.0
var _sway := 0.0
var _sway_period := 1.0
var _sway_lag := 0.0
## The chain at body scale 1: where the tail's root stands ahead of the body's middle, and per bone
## [length over the ground, half-width, lowest, highest].
var _root := 0.0
var _chain: Array = []
var _at: Array[float] = []  # the swing as it has reached each bone
var _swing := 0.0
var _v := 0.0
var _time := 0.0
var _last_yaw := 0.0
var _last_rate := 0.0
var _drag_rate := 0.0
var _primed := false


func _init(tune: Dictionary) -> void:
	var gain: Array = tune["gain"]
	_spring = Vector2(Num.f(tune["spring_hz"]), Num.f(tune["spring_zeta"]))
	_gain = Vector2(Num.f(gain[0]), Num.f(gain[1]))
	_max = Num.f(tune["max"])
	_drag = Num.f(tune["drag"])
	_drag_max = Num.f(tune["drag_max"])
	_drag_smooth = Num.f(tune["drag_smooth"])
	_delay = Num.f(tune["delay"])
	_sway = deg_to_rad(Num.f(tune["sway_deg"]))
	_sway_period = Num.f(tune["sway_period_s"])
	_sway_lag = Num.f(tune["sway_lag"])
	_root = Num.f(tune["root"])
	_chain = tune["chain"]
	_at.resize(_chain.size())
	_at.fill(0.0)
	bends.resize(_chain.size())
	bends.fill(0.0)


## The body's yaw (rad, 0 facing -Z as the presentation counts it) after dt.
func step(yaw: float, dt: float) -> void:
	_time += dt
	if not _primed:  # the first step: no turning yet
		_primed = true
		_last_yaw = yaw
	var rate := wrapf(yaw - _last_yaw, -PI, PI) / dt
	var accel := (rate - _last_rate) / dt
	_last_yaw = yaw
	_last_rate = rate
	_drag_rate = lerpf(_drag_rate, rate, minf(1.0, dt / _drag_smooth))
	_v += (-_spring.x * _spring.x * _swing - 2.0 * _spring.y * _spring.x * _v - accel) * dt
	_swing += _v * dt
	var shown := _max * tanh(_swing / _max)
	var reach := 1.0 - exp(-dt / _delay)
	var ahead := shown + clampf(-_drag_rate * _drag, -_drag_max, _drag_max)
	for i: int in _at.size():
		_at[i] += (ahead - _at[i]) * reach
		ahead = _at[i]
		var k := float(i) / maxf(1.0, _at.size() - 1.0)
		var sway := _sway * sin(TAU * _time / _sway_period - _sway_lag * i)
		bends[i] = _at[i] * (_gain.x + _gain.y * k) + sway


## The tail's discs at a pose (body middle `centre`, facing `dir`, body scale `s`), as
## [centre (Vector2), radius, lowest, highest] at body scale 1 (the heights; the centre is world):
## along each bone, spaced no further apart than its half-width.
func discs(centre: Vector2, dir: Vector2, s: float) -> Array:
	var out: Array = []
	var at := centre + dir * _root * s
	var back := -dir
	for i: int in _chain.size():
		var bone: Array = _chain[i]
		back = back.rotated(-bends[i])  # the presentation's + yaw turns left: -angle in the sim's plane
		var length := Num.f(bone[0]) * s
		var half := Num.f(bone[1])
		var steps := maxi(1, ceili(Num.f(bone[0]) / maxf(half, 0.05)))
		for n: int in range(0 if i == 0 else 1, steps + 1):
			out.append([at + back * length * float(n) / steps, half, Num.f(bone[2]), Num.f(bone[3])])
		at += back * length
	return out


## How far the tail reaches from the body's middle (body scale 1).
func reach() -> float:
	var total := absf(_root)
	for bone: Array in _chain:
		total += Num.f(bone[0]) + Num.f(bone[1])
	return total
