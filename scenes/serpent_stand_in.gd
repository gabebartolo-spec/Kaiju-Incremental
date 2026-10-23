class_name SerpentStandIn
extends Node3D
## The serpent prototype's stand-in body (D-198, "a stand-in segmented body"; round 4: it must
## read as a snake): one smooth tapered tube (SerpentTube) with a cobra-ish head and a thin tail,
## laid each frame along the drawn S (SerpentWeave) over the sim's trail (SerpentBody). The head
## and neck bend into a turn ahead of the path and the head lifts, sprung (data/tuning.json
## "serpent" head_lead*, neck_bend, head_lift); before a turn it cocks away from it and rears
## (windup_*), then lunges into it; the thin tail swings a little wider than the rest of the S
## (tail_whip); a stop settles (SerpentSettle). Plain colour, no voxels yet. Presentation only: it
## reads the body and never moves it. World space (x, z).

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
var tongue := 0.0
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
	_settled = _settle.apply(laid, moving, delta, body.heading)
	_spring_lead(body, delta)
	look = _settle.tracking()
	jab = _settle.jab()
	tongue = _settle.tongue()
	joints = _bend_neck(_settled, lead + look, jab)
	lifts = _lifts(seg)
	_tube.build(joints, lifts, _settle.swell(), tongue)


## How wide the body is drawn `d` m behind the snout (m).
func width_at(d: float) -> float:
	return _tube.width_at(d, 1.0)


## How tall the body is drawn `d` m behind the snout (m).
func height_at(d: float) -> float:
	return _tube.height_at(d, 1.0)


## Each joint's height (m): the coil's stack, and the head raised by the turn it leads or winds up.
func _lifts(seg: float) -> PackedFloat32Array:
	var out := _settle.heights.duplicate()
	var reach := Num.f(_cfg["head_len"]) * 1.5
	for j: int in out.size():
		out[j] += raised * (1.0 - smoothstep(0.0, reach, j * seg))
	return out


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
