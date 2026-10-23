class_name SerpentStandIn
extends Node3D
## The serpent prototype's stand-in body (D-198, "a stand-in segmented body"; round 4: it must
## read as a snake): one smooth tapered tube (SerpentTube) with a cobra-ish head and a thin tail,
## laid each frame along the drawn S (SerpentWeave) over the sim's trail (SerpentBody). The head
## and neck bend into a turn ahead of the path and the head lifts, sprung (data/tuning.json
## "serpent" head_lead*, neck_bend, head_lift); before a turn it cocks away from it and rears
## (windup_*), then lunges into it; the thin tail swings a little wider than the rest of the S
## (tail_whip); in the last stop_bunch_s before a stop the S bunches up, tail first and the head
## last (its sideways swing deepens by stop_bunch, the chain drawn up behind the head and the body
## shortened by stop_shorten, its bands closing up toward the head) as the hood flares stop_flare
## wide, the cue the high camera sees (round 5 critic: the rear-up alone is "invisible at 62 deg
## pitch"; round 6: "no visible bunch-up"); a stop then settles (SerpentSettle), the body
## lengthening again as the head leads it into the coil. Plain colour, no voxels yet. Presentation
## only: it reads the body and never moves it. World space (x, z).

## Joint points drawn this frame (ground plane, head first), for captures and tests.
var joints := PackedVector2Array()
## The head's look into the turn now (rad, signed as Vector2.angle_to).
var lead := 0.0
## How far the head is raised now (m).
var raised := 0.0
## Each joint's height above the ground (m), the coil's stack and the raised head.
var lifts := PackedFloat32Array()
## The idle's head look about (rad), jab forward (m) and tongue out (0..1) now.
var look := 0.0
var jab := 0.0
## How far the front end rears (m) and the head draws back (m) as it brakes to a stop.
var reared := 0.0
var recoil := 0.0
## How far the cobra's hood is spread now (0..1): with the rear and the coil (D-206).
var hood := 0.0
var tongue := 0.0
## How far the tongue is turned side to side now (rad).
var tongue_wag := 0.0
var _cfg: Dictionary
var _weave: SerpentWeave
var _settle: SerpentSettle
var _tube: SerpentTube
## The body's joints as settled, before the neck bends into the lead.
var _settled := PackedVector2Array()
var _lead_v := 0.0
## Seconds of wind-up left, and which way the turn it winds up for goes (+1 / -1).
var _wind := 0.0
var _wind_side := 0.0
## False after a wind-up until the turn has mostly been made, so one turn winds up once.
var _armed := true
var _brace_k := 0.0  # 0..1: how far into the brace before a stop
## Seconds into the bunch-up before a stop (below 0: none under way), and the hood's flare (0..1).
var _bunch_t := -1.0
var _flare := 0.0
## How much of its length the body is drawn at now (1: all; the bunch-up shortens it).
var _squash := 1.0


func _init(cfg: Dictionary) -> void:
	_cfg = cfg
	_settle = SerpentSettle.new(cfg)
	name = "SerpentStandIn"
	_tube = SerpentTube.new(cfg)
	add_child(_tube)


## Lays the body along the S as it is now; call once after every sim step (delta: that step).
func update(body: SerpentBody, delta: float) -> void:
	var count := Num.i(_cfg["segments"])
	var seg := body.length() / count
	if _weave == null:
		_weave = SerpentWeave.new(body)
	var moving := body.speed > 0.0
	if moving and _settle.still > 0.0:  # sets off from the shape it settled in
		_weave.settle_into(_settled, body)
	_weave.step(body, delta)
	var laid := SerpentWeave.joints(_weave.path(body.length() + seg), seg, count)
	if moving:
		laid = _whip(laid, body, seg)
	_bunch_up(body, moving, delta)
	if _bunch_t > 0.0:
		laid = _bunched(laid, body, seg)
	_settle.squash = _squash
	var line := PackedVector2Array()
	if not moving and _settle.still == 0.0:  # the stop: where the coil may go
		for k: int in ceili(body.length()) + 1:
			line.append(body.centre_at(k))
	_settle.stop_at(body.heading, line, lifts)
	_settled = _settle.apply(laid, moving, delta)
	_spring_lead(body, delta)
	_brace(body, moving, delta)
	look = _settle.tracking()
	jab = _settle.jab() - recoil
	tongue = _settle.tongue()
	joints = _bend_neck(_settled, lead + look, jab)
	lifts = _lifts(seg, moving)
	hood = maxf(_settle.hood(), _brace_k * Num.f(_cfg["stop_hood"]))
	hood = maxf(maxf(hood, _flare), Num.f(_cfg["run_hood"]))
	_tube.hood = hood
	tongue_wag = _settle.tongue_wag()
	_tube.tongue_wag = tongue_wag
	_tube.build(joints, lifts, _settle.swell(), tongue)


## How wide the body is drawn `d` m behind the snout (m).
func width_at(d: float) -> float:
	return _tube.width_at(d, 1.0)


## How tall the body is drawn `d` m behind the snout (m).
func height_at(d: float) -> float:
	return _tube.height_at(d, 1.0)


## Each joint's height (m): the coil's stack; while it moves, the head raised by the turn it leads
## or winds up and the front reared as it brakes (once it stops, the coil's path carries those).
func _lifts(seg: float, moving: bool) -> PackedFloat32Array:
	var out := _settle.heights.duplicate()
	if not moving:
		return out
	var reach := Num.f(_cfg["head_len"]) * 1.5
	var rear_reach := Num.f(_cfg["stop_rear_reach"])
	for j: int in out.size():
		out[j] += raised * (1.0 - smoothstep(0.0, reach, j * seg))
		out[j] += reared * (1.0 - smoothstep(0.0, rear_reach, j * seg))
	return out


## As it brakes to a stop (the stick let go), the front end rears up stop_rear m and the head
## draws back stop_recoil m, more the nearer it is to stopping: the anticipation of the coil.
func _brace(body: SerpentBody, moving: bool, delta: float) -> void:
	if not moving:  # the coil's path carries the rear; the hood folds while the body coils
		reared = 0.0
		recoil = 0.0
		_brace_k = move_toward(_brace_k, 0.0, Num.f(_cfg["stop_rear_rate"]) * delta)
		return
	var braking := body.turn_left == 0.0 and body.push < 0.0
	var near := 1.0 - body.speed / Num.f(_cfg["speed"])
	var want := smoothstep(0.0, 1.0, near) if braking else 0.0
	_brace_k = move_toward(_brace_k, want, Num.f(_cfg["stop_rear_rate"]) * delta)
	reared = Num.f(_cfg["stop_rear"]) * _brace_k
	recoil = Num.f(_cfg["stop_recoil"]) * _brace_k


## The bunch-up's clock: it starts as the braking body slows under stop_bunch_speed and runs
## stop_bunch_s (held once the head stops: the coil starts from the bunched shape); setting off
## again clears it.
func _bunch_up(body: SerpentBody, moving: bool, delta: float) -> void:
	var braking := body.turn_left == 0.0 and body.push < 0.0
	var span := Num.f(_cfg["stop_bunch_s"])
	if moving and not braking:
		_bunch_t = -1.0
	elif moving and _bunch_t < 0.0 and body.speed < Num.f(_cfg["stop_bunch_speed"]):
		_bunch_t = 0.0
	if _bunch_t >= 0.0 and (moving or _settle.still == 0.0):
		_bunch_t = minf(_bunch_t + delta, span)
	_bunch_cue(moving, delta)


## What the bunch-up shows now: the body shortened by stop_shorten and the hood flared stop_flare
## wide as it runs (the flare folding at stop_rear_rate once the body coils).
func _bunch_cue(moving: bool, delta: float) -> void:
	var span := Num.f(_cfg["stop_bunch_s"])
	var k := smoothstep(0.0, 1.0, _bunch_t / span) if _bunch_t >= 0.0 else 0.0
	_squash = 1.0 - Num.f(_cfg["stop_shorten"]) * k
	if _bunch_t >= 0.0 and moving:
		_flare = Num.f(_cfg["stop_flare"]) * k
	else:
		_flare = move_toward(_flare, 0.0, Num.f(_cfg["stop_rear_rate"]) * delta)


## The S bunched up: each joint's sideways swing about the sim's centreline deepened by up to
## stop_bunch, the tail's joints first and the head's last (each eases in over half of
## stop_bunch_s, the tail's starting at once, the head's half way), the chain then drawn up behind
## the head so every segment keeps its length; then the joints are laid closer along that shape
## (the body shortened to _squash of its length, the tail drawn up toward the head).
func _bunched(points: PackedVector2Array, body: SerpentBody, seg: float) -> PackedVector2Array:
	var span := Num.f(_cfg["stop_bunch_s"]) * 0.5
	var deepen := Num.f(_cfg["stop_bunch"])
	var centre := PackedVector2Array()
	for k: int in ceili(body.length() * 1.3 / seg) + 1:
		centre.append(body.centre_at(k * seg))
	var out := points.duplicate()
	var last := points.size() - 1
	for j: int in range(1, last + 1):
		var start := span * (1.0 - float(j) / last)
		var k := smoothstep(0.0, 1.0, (_bunch_t - start) / span)
		var near := _nearest(points[j], centre)
		out[j] = near + (points[j] - near) * (1.0 + deepen * k)
	out = SerpentSettle.keep_lengths(out, seg)
	if _squash >= 1.0:
		return out
	return SerpentWeave.joints(out, seg * _squash, last)


## The thin tail swung a little wider than the S about the sim's centreline, more toward its tip
## (tail_whip over the last of the body from tail_whip_from), as the speed allows.
func _whip(points: PackedVector2Array, body: SerpentBody, seg: float) -> PackedVector2Array:
	var amount := Num.f(_cfg["tail_whip"])
	var from := Num.f(_cfg["tail_whip_from"])
	var last := points.size() - 1
	var first := int(last * from)
	var centre := PackedVector2Array()
	for k: int in ceili(body.length() * 1.3 / seg) + 1:
		centre.append(body.centre_at(k * seg))
	var full := smoothstep(0.0, Num.f(_cfg["speed"]) * Num.f(_cfg["wave_full_at"]), body.speed)
	var out := points.duplicate()
	for j: int in range(first, last + 1):
		var near := _nearest(points[j], centre)
		var t := float(j - first) / maxf(1.0, last - first)
		out[j] = near + (points[j] - near) * (1.0 + amount * smoothstep(0.0, 1.0, t) * full)
	return SerpentSettle.keep_lengths(out, seg)


## The point of the polyline `line` nearest `p`.
static func _nearest(p: Vector2, line: PackedVector2Array) -> Vector2:
	var best := INF
	var at := line[0]
	for i: int in range(1, line.size()):
		var q := Geometry2D.get_closest_point_to_segment(p, line[i - 1], line[i])
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			at = q
	return at


## The front of the body bent by `angle` (the head's lead, look about): each front segment turned
## by its neck_bend share of it, rebuilt from the first unbent joint forward, so the head looks
## first; then `jab` m thrust forward along the head, the neck's share of it each.
func _bend_neck(points: PackedVector2Array, angle: float, jab: float) -> PackedVector2Array:
	var out := points.duplicate()
	var bends: Array = _cfg["neck_bend"]
	if angle == 0.0 and jab == 0.0:
		return out
	for i: int in range(mini(bends.size(), out.size() - 1) - 1, -1, -1):
		var along := (points[i] - points[i + 1]).rotated(angle * Num.f(bends[i]))
		out[i] = out[i + 1] + along
	if jab != 0.0:
		var aim := (out[0] - out[1]).normalized()
		for i: int in mini(bends.size(), out.size()):
			out[i] += aim * jab * Num.f(bends[i])
	return out


## The head leads a turn by a share of the turn still to make, on a critically damped spring;
## a turn just asked for first cocks it away from the turn and rears it (windup_s), then it lunges
## in. It settles exactly once there is nothing left to lead and the body is still.
func _spring_lead(body: SerpentBody, delta: float) -> void:
	var cap := Num.f(_cfg["head_lead_max"])
	var target := clampf(body.turn_left * Num.f(_cfg["head_lead"]), -cap, cap)
	_wind_up(body, delta)
	var rear := 0.0
	if _wind > 0.0:
		var done := 1.0 - _wind / Num.f(_cfg["windup_s"])
		target = -_wind_side * Num.f(_cfg["windup_lead"])
		rear = Num.f(_cfg["windup_lift"]) * sin(PI * done)
	var omega := TAU * Num.f(_cfg["head_lead_hz"])
	var sprung := KaijuGait.spring(lead, _lead_v, target, omega, 1.0, delta)
	lead = sprung.x
	_lead_v = sprung.y
	if target == 0.0 and absf(lead) < 0.002 and absf(_lead_v) < 0.01:
		lead = 0.0
		_lead_v = 0.0
	raised = Num.f(_cfg["head_lift"]) * absf(lead) + rear


## Starts a wind-up when a real turn is asked for from nearly straight on, while moving.
func _wind_up(body: SerpentBody, delta: float) -> void:
	var asked := absf(body.turn_left)
	_wind = maxf(0.0, _wind - delta)
	if asked < Num.f(_cfg["windup_turn"]) * 0.5:
		_armed = true
	if _armed and asked >= Num.f(_cfg["windup_turn"]) and body.speed > 1.0:
		_armed = false
		_wind = Num.f(_cfg["windup_s"])
		_wind_side = signf(body.turn_left)
