class_name ClipProbe
extends RefCounted
## Numbers for the croc titan's clip moves (D-047), from the in-game rig at 60 Hz, headless: the
## tail tip's side-to-side period and sweep on the walk, how long the tail takes to settle after a
## standing turn, the roar's timeline (tip above the hip, slam contact, back to standing) and the
## slam's feedback. capture_clips.gd --probe feeds it every frame of its schedule and prints the
## report; a motion change is gated on these before anything is captured.
##   godot --headless --path . --script tools/capture/capture_clips.gd -- --probe

## Walk window (s): steady walking, past the start-up.
const WALK := Vector2(2.0, 6.5)
## Standing idle window before the turn (s): the tail's rest angle.
const REST := Vector2(7.6, 8.4)
## Within this much of rest (deg) the tail has settled; below this share of its peak rate the body
## has stopped turning.
const SETTLE_DEG := 2.0
const STOP_RATE := 0.02

var _t: Array[float] = []
var _lateral: Array[float] = []
var _angle: Array[float] = []
var _yaw: Array[float] = []
var _tip_y: Array[float] = []
var _hip_y: Array[float] = []
var _cycles: Array[float] = []
var _states: Array[String] = []
var _slams: Array[String] = []
var _m_per_unit := 1.0


## The slam as the scene draws it: strength, and what the scene spawned (dust, ring, dip px).
func slam(t: float, strength: float, fx: Vector3) -> void:
	var row := [t, strength, fx.x, fx.y, fx.z]
	_slams.append("t %.2f s, strength %.2f, dust %.2f, ring %.2f units, dip %.1f px at 1080p" % row)


func sample(t: float, kaiju: KaijuModel, gait: ClipGait, tip_bone: String) -> void:
	var rig := gait.rig
	var body := rig.global_transform
	var tip := rig.tail_world(tip_bone)
	var local := body.affine_inverse() * tip
	_m_per_unit = 50.0 / maxf(0.001, kaiju.hip_height())  # the Blender hip is 50 m
	_t.append(t)
	_lateral.append(local.x)
	_angle.append(rad_to_deg(atan2(local.x, local.z)))
	_yaw.append(rig.global_rotation.y)
	_tip_y.append(tip.y - kaiju.global_position.y)
	_hip_y.append(kaiju.hip_height())
	_cycles.append(gait.walk_cycles)
	_states.append(gait.state)


func report(turn_at: float, roar_at: float) -> void:
	print("PROBE walk: %s" % _walk())
	print("PROBE turn: %s" % _turn(turn_at, roar_at))
	print("PROBE roar: %s" % _roar(roar_at))
	for s: String in _slams:
		print("PROBE slam: " + s)
	if _slams.is_empty():
		print("PROBE slam: none")


func _walk() -> String:
	var xs: Array[float] = []
	var ts: Array[float] = []
	for i: int in _t.size():
		if _t[i] >= WALK.x and _t[i] <= WALK.y:
			xs.append(_lateral[i])
			ts.append(_t[i])
	if xs.size() < 10:
		return "no walk"
	var mean := 0.0
	for x: float in xs:
		mean += x / xs.size()
	var period := _dominant_period(xs, ts, mean)
	var hi: float = xs.max()
	var lo: float = xs.min()
	var sweep := (hi - lo) * 0.5
	var i0 := _t.find(ts[0])
	var i1 := _t.find(ts[-1])
	var stride := (ts[-1] - ts[0]) / maxf(0.001, _cycles[i1] - _cycles[i0])
	return (
		"tail period %.2f s, sweep %.2f units (%.1f m), stride cycle %.2f s"
		% [period, sweep, sweep * _m_per_unit, stride]
	)


## The period (s) with the most power in the series, 0.5-3 s in 0.01 s steps (a stride-rate
## wobble on top of a slower wave doesn't fool it the way zero crossings would).
func _dominant_period(xs: Array[float], ts: Array[float], mean: float) -> float:
	var best := 0.0
	var best_power := -1.0
	for step: int in range(50, 301):
		var w := TAU / (step * 0.01)
		var c := 0.0
		var s := 0.0
		for i: int in xs.size():
			c += (xs[i] - mean) * cos(w * ts[i])
			s += (xs[i] - mean) * sin(w * ts[i])
		if c * c + s * s > best_power:
			best_power = c * c + s * s
			best = step * 0.01
	return best


func _turn(turn_at: float, roar_at: float) -> String:
	var rest := 0.0
	var n := 0
	var peak := 0.0
	for i: int in range(1, _t.size()):
		if _t[i] >= REST.x and _t[i] <= REST.y:
			rest += _angle[i]
			n += 1
		if _t[i] > turn_at and _t[i] < roar_at:
			peak = maxf(peak, absf(_rate(i)))
	rest /= maxi(1, n)
	var stop := -1.0
	var settled := -1.0
	var over := 0.0
	for i: int in range(1, _t.size()):
		if _t[i] <= turn_at or _t[i] >= roar_at:
			continue
		if stop < 0.0 and absf(_rate(i)) < STOP_RATE * peak and _t[i] > turn_at + 0.5:
			stop = _t[i]
		if stop >= 0.0:
			over = maxf(over, -(_angle[i] - rest) * signf(_angle[_t.find(stop)] - rest))
			if absf(_angle[i] - rest) > SETTLE_DEG:
				settled = _t[i]
	var settle := maxf(0.0, settled - stop) if stop >= 0.0 else -1.0
	var trace := PackedStringArray()
	for i: int in _t.size():
		if _t[i] >= turn_at and _t[i] < roar_at and i % 6 == 0:
			trace.append("%.1f:%+.1f" % [_t[i], _angle[i] - rest])
	print("PROBE turn trace (s:deg off rest): " + " ".join(trace))
	return (
		"body stops %.2f s, tail settles within %.1f deg of rest %.2f s later, overshoot %.1f deg"
		% [stop, SETTLE_DEG, settle, over]
	)


func _roar(roar_at: float) -> String:
	var above := Vector2(-1, -1)
	var exit := -1.0
	for i: int in _t.size():
		if _t[i] < roar_at:
			continue
		if _tip_y[i] > _hip_y[i]:
			above = Vector2(_t[i] if above.x < 0.0 else above.x, _t[i])
		if exit < 0.0 and i > 0 and _states[i - 1] == "roar" and _states[i] != "roar":
			exit = _t[i]
	return (
		"tip above the hip %.2f-%.2f s (%.2f s), back to standing (roar ends) %.2f s"
		% [above.x, above.y, maxf(0.0, above.y - above.x), exit]
	)


func _rate(i: int) -> float:
	return wrapf(_yaw[i] - _yaw[i - 1], -PI, PI) / maxf(0.0001, _t[i] - _t[i - 1])
