class_name ClipIdle
extends RefCounted
## What a croc titan does standing (D-165, the living predator), for ClipAlive: a slow breath that
## gets slower and heavier with size, weight moving foot to foot, the head drifting and glancing
## away, now and then a deeper sigh, a small crack of the jaw, a blink. Presentation only; every
## number is "croc_idle" tuning; every random choice is a hash of (run, stage, event number), never
## the sim's RNG or a clock, so the same run stands the same way. Output: bone turns that go on top
## of the clip's pose (turn), a pelvis slide, the breath and the blink for the skin shader, all
## scaled by `weight`, which is 0 (and every output zero) unless the kaiju has stood still a while
## and fades out again at once on a walk, a turn, a roar or the beam.

enum Kind { SHIFT, GLANCE, SIGH, JAW, BLINK }

## How much of the life layer shows, 0..1.
var weight := 0.0
## The breath now, 0 (breathed out) to this breath's depth, at most 1 (not scaled by weight).
var breath := 0.0
## The eyes' lids, 0 open .. 1 shut (zero unless standing).
var blink := 0.0
## Pelvis slide, in hip heights, along the body's right.
var pelvis_x := 0.0
## The run's number and the stage (0 young croc, 1 Behemoth, 2 Colossus): the hash's inputs.
var seed := 0
var stage := 0
## Debug and tests: only the breath, none of the shifts, glances, cracks or blinks.
var breath_only := false

var _cfg := Content.section("croc_idle")
var _tail_bones := 9
var _q: Dictionary = {}  # bone name -> Quaternion on top of the clip
var _t := 0.0  # seconds of this stand
var _last_phase := 0.0
var _cycle_s := 3.0
var _depth := 1.0
var _cycles := 0
var _sigh_due := false
var _next: Array[float] = [INF, INF, INF, INF, INF]
var _count: Array[int] = [0, 0, 0, 0, 0]
var _shift := 0.0
var _shift_from := 0.0
var _shift_to := 0.0
var _shift_t := 0.0
var _glance_at := -INF
var _glance := Vector2.ZERO  # yaw, pitch (rad)
var _glance_hold := 0.0
var _jaw_at := -INF
var _blink_at := -INF
var _blink_again := false


func _init(p_tail_bones := 9) -> void:
	_tail_bones = p_tail_bones


## A new stand: the clock and the schedule start over (the baked idle starts at its frame 0).
func begin() -> void:
	_t = 0.0
	_last_phase = 0.0
	_cycles = 0
	_sigh_due = false
	for kind: int in _next.size():
		_next[kind] = _every(kind)
	_new_cycle()


## The speed to play the baked idle at (clip_seconds is its one breath): its breath is this one's.
func rate(clip_seconds: float) -> float:
	return clip_seconds / _cycle_s


## One frame. standing: still on the spot in the idle clip with the beam shut; phase: the idle
## clip's place in its loop, 0..1 (one breath).
func step(dt: float, standing: bool, phase: float) -> void:
	if standing:
		_t += dt
		var up := Num.f(_cfg["still_s"]) <= _t
		var rise := dt / Num.f(_cfg["fade_in_s"])
		weight = minf(1.0, weight + rise) if up else weight
		_advance(dt, phase)
	else:
		weight = maxf(0.0, weight - dt / Num.f(_cfg["fade_out_s"]))
	_pose()


func is_active() -> bool:
	return weight > 0.0


## The bone's turn from the life layer (identity: none).
func turn(bone_name: String) -> Quaternion:
	var q: Quaternion = _q.get(bone_name, Quaternion.IDENTITY)
	return q


## The skin shader's push at the stage's size (share of the body height), weight and depth in.
func skin_push() -> float:
	return _per_stage("skin_amp") * trade("push_gain") * weight * breath


## The biggest push this breath makes, as skin_push() but with the curve left to the shader.
func skin_peak() -> float:
	return _per_stage("skin_amp") * trade("push_gain") * weight * _depth


## The breath's depth and the weight of the layer: what the swell and the plate lift scale by.
func depth_weight() -> float:
	return weight * _depth


## An option of the director's breath trade (all off in the tuning).
func trade(key: String) -> float:
	var options: Dictionary = _cfg["trade"]
	var value: Variant = options[key]
	if value is Array:
		var by_stage: Array = value
		return Num.f(by_stage[stage])
	return Num.f(value)


## The breath's place in its cycle, 0..1.
func phase_now() -> float:
	return _last_phase


## The share of a breath the push reaches the hips after the neck (cycles).
func lag() -> float:
	return Num.f(_cfg["skin_lag"])


func _advance(dt: float, phase: float) -> void:
	if phase < _last_phase - 0.5:  # the breath came round: the next one is its own
		_cycles += 1
		_new_cycle()
	_last_phase = phase
	breath = _depth * curve(phase)
	for kind: int in _next.size():
		if breath_only:
			break
		if _t >= _next[kind]:
			_fire(kind)
			_next[kind] = _t + _every(kind)
	_shift_t += dt
	var k := smoothstep(0.0, 1.0, _shift_t / Num.f(_cfg["shift_s"]))
	_shift = lerpf(_shift_from, _shift_to, k)


## The next breath's length and depth: a little different each time; a sigh is deeper and slower.
func _new_cycle() -> void:
	_cycle_s = (
		_per_stage("breath_s") * (1.0 + Num.f(_cfg["breath_vary"]) * _signed(Kind.SIGH, _cycles, 1))
	)
	_depth = Num.f(_cfg["depth"]) + Num.f(_cfg["depth_vary"]) * _signed(Kind.SIGH, _cycles, 2)
	if _sigh_due:
		_sigh_due = false
		_depth = Num.f(_cfg["sigh_gain"])
		_cycle_s *= Num.f(_cfg["sigh_slow"])


## One breath, phase 0..1 from the bottom: in over the inhale share (a smooth rise to 1), out over
## the rest less the short pause at the bottom (a smooth fall to 0), then still. 0..1.
func curve(phase: float) -> float:
	var p := fposmod(phase, 1.0)
	var inhale: float = Num.f(_cfg["inhale"])
	var out_end := 1.0 - Num.f(_cfg["pause"])
	if p < inhale:
		return 0.5 - 0.5 * cos(PI * p / inhale)
	if p < out_end:
		return 0.5 + 0.5 * cos(PI * (p - inhale) / (out_end - inhale))
	return 0.0


func _fire(kind: int) -> void:
	var n := _count[kind]
	_count[kind] += 1
	match kind:
		Kind.SHIFT:
			_shift_from = _shift
			var to := -signf(_shift_to) if _shift_to != 0.0 else signf(_signed(kind, n, 0))
			_shift_to = to
			_shift_t = 0.0
		Kind.GLANCE:
			_glance_at = _t
			var side := signf(_signed(kind, n, 0))
			var yaw := _between("glance_yaw_deg", _unit(kind, n, 1))
			_glance = Vector2(side * deg_to_rad(yaw), _signed(kind, n, 2))
			_glance.y *= deg_to_rad(Num.f(_cfg["glance_pitch_deg"]))
			_glance_hold = _between("glance_hold_s", _unit(kind, n, 3))
		Kind.SIGH:
			_sigh_due = true
		Kind.JAW:
			_jaw_at = _t
		Kind.BLINK:
			_blink_at = _t
			_blink_again = _unit(kind, n, 1) < Num.f(_cfg["double_blink"])


## Builds this frame's bone turns and the blink from the state, weight and all.
func _pose() -> void:
	_q.clear()
	pelvis_x = _shift * Num.f(_cfg["shift_hip"]) * weight
	blink = _lids() if weight > 0.5 else 0.0
	if weight <= 0.0:
		return
	var roll := deg_to_rad(Num.f(_cfg["shift_roll_deg"])) * _shift * weight
	_add("spine0", Vector3.BACK, -roll)
	_add("spine2", Vector3.BACK, roll * 0.8)
	_add("head0", Vector3.BACK, roll * 0.2)
	var chest := deg_to_rad(Num.f(_cfg["chest_deg"]) * trade("chest_gain")) * breath * weight
	_add("spine1", Vector3.RIGHT, chest)
	_add("spine2", Vector3.RIGHT, chest * 0.6)
	_head(chest)
	_add("jaw", Vector3.RIGHT, -deg_to_rad(Num.f(_cfg["jaw_deg"])) * _jaw() * weight)
	_tail()


## The neck and skull: drift, glance (the skull leads, the neck follows a beat late) and the breath.
func _head(chest: float) -> void:
	var drift := Vector2(
		sin(TAU * _hz(0) * _t + _phase(0)) * Num.f(_cfg["drift_yaw_deg"]),
		sin(TAU * _hz(1) * _t + _phase(1)) * Num.f(_cfg["drift_pitch_deg"])
	)
	drift = Vector2(deg_to_rad(drift.x), deg_to_rad(drift.y)) * (0.0 if breath_only else 1.0)
	var skull := _glance * _envelope(_t - _glance_at) + drift
	var neck := _glance * _envelope(_t - _glance_at - Num.f(_cfg["neck_lag_s"])) + drift
	_add("head1", Vector3.UP, skull.x * 0.55 * weight)
	_add("head0", Vector3.UP, neck.x * 0.45 * weight)
	_add("head1", Vector3.RIGHT, skull.y * 0.55 * weight)
	# the head rises with the breath
	var settle := deg_to_rad(_per_stage("head_deg") * trade("head_gain")) * breath * weight
	_add("head0", Vector3.RIGHT, neck.y * 0.45 * weight - chest * 0.5 + settle)


## The tail rides the breath, each joint a little behind the last and a little less.
func _tail() -> void:
	var amp := deg_to_rad(Num.f(_cfg["tail_deg"])) * weight
	var lag: float = Num.f(_cfg["tail_lag"])
	for i: int in _tail_bones:
		var wave := _depth * curve(_last_phase - lag * float(i))
		_add("tail%d" % i, Vector3.RIGHT, amp * wave * pow(0.88, float(i)))


## A glance's shape over time since it began: in, held, out.
func _envelope(x: float) -> float:
	var rise: float = Num.f(_cfg["glance_in_s"])
	var fall: float = Num.f(_cfg["glance_out_s"])
	return (
		smoothstep(0.0, rise, x)
		* (1.0 - smoothstep(rise + _glance_hold, rise + _glance_hold + fall, x))
	)


## The jaw crack's opening, 0..1: opens, hangs, closes.
func _jaw() -> float:
	var x := _t - _jaw_at
	var up: float = Num.f(_cfg["jaw_open_s"])
	var hold: float = Num.f(_cfg["jaw_hold_s"])
	return (
		smoothstep(0.0, up, x)
		* (1.0 - smoothstep(up + hold, up + hold + Num.f(_cfg["jaw_close_s"]), x))
	)


## Lids: one blink shuts fast and opens a little slower; a double blink follows its first.
func _lids() -> float:
	var span: float = Num.f(_cfg["blink_s"])
	var one := _lid(_t - _blink_at, span)
	return maxf(one, _lid(_t - _blink_at - span * 1.6, span) if _blink_again else 0.0)


func _lid(x: float, span: float) -> float:
	if x < 0.0 or x > span:
		return 0.0
	var shut := span * Num.f(_cfg["blink_close"])
	return smoothstep(0.0, shut, x) if x < shut else 1.0 - smoothstep(shut, span, x)


func _add(bone_name: String, axis: Vector3, angle: float) -> void:
	var q: Quaternion = _q.get(bone_name, Quaternion.IDENTITY)
	_q[bone_name] = Quaternion(axis, angle) * q


func _hz(i: int) -> float:
	var range_hz: Array = _cfg["drift_hz"]
	return lerpf(Num.f(range_hz[0]), Num.f(range_hz[1]), _unit(Kind.GLANCE, 99, i))


func _phase(i: int) -> float:
	return TAU * _unit(Kind.GLANCE, 98, i)


## Seconds to the next event of this kind from now (a range in "<kind>_every_s", by the hash).
func _every(kind: int) -> float:
	var n := _count[kind]
	match kind:
		Kind.SHIFT:
			return _between("shift_every_s", _unit(kind, n, 9))
		Kind.GLANCE:
			return _between("glance_every_s", _unit(kind, n, 9))
		Kind.SIGH:
			return _between("sigh_every_s", _unit(kind, n, 9))
		Kind.JAW:
			return _between("jaw_every_s", _unit(kind, n, 9))
	return _between("blink_every_s", _unit(kind, n, 9))


## The [young croc, Behemoth, Colossus] list's number for this stage.
func _per_stage(key: String) -> float:
	var list: Array = _cfg[key]
	return Num.f(list[stage])


func _between(key: String, u: float) -> float:
	var pair: Array = _cfg[key]
	return lerpf(Num.f(pair[0]), Num.f(pair[1]), u)


## A repeatable number in 0..1 from (run, stage, kind, event number, salt).
func _unit(kind: int, n: int, salt: int) -> float:
	var key := seed * 1000003 + stage * 7919 + kind * 104729 + n * 15485863 + salt * 32452843
	return float(absi(hash(key)) % 10007) / 10006.0


func _signed(kind: int, n: int, salt: int) -> float:
	return _unit(kind, n, salt) * 2.0 - 1.0
