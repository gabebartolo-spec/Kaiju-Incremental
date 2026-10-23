class_name TailSim
extends RefCounted
## A heavy body's tail as the sim's own (D-208, "any contact a kaiju has with a building will
## damage it"): its swing, drag and sway worked out here, deterministically, from the body's yaw
## (BodyContact.body_dir) and time, bone by bone, so the body volume's tail (HeavyPose.bend_tail)
## rides the tail the player sees (the presentation reads `bends` and adds no swing of its own).
## The tail's mass on turns: a damped spring driven by the body's turning acceleration, a drag
## that trails it behind a turning body, and a sway that never stops, each reaching every bone a
## moment after the one before (ClipTail's model, moved into the sim).
## Numbers: tuning "body_class" <class> "tail". Pure, no randomness.

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
var _at: Array[float] = []  # the swing as it has reached each bone
var _swing := 0.0
var _v := 0.0
var _time := 0.0
var _last_yaw := 0.0
var _last_rate := 0.0
var _drag_rate := 0.0
var _primed := false


## tune: the class's tail numbers; bones: the drawn tail's bones.
func _init(tune: Dictionary, bones: int) -> void:
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
	_at.resize(bones)
	_at.fill(0.0)
	bends.resize(bones)
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
