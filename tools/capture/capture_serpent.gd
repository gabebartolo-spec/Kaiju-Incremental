extends SceneTree
## The serpent slither prototype's clip (D-198: "a stand-in segmented body slithering, turning and
## stopping", one short clip): already slithering east (pre-rolled, its S laid along all of it),
## then a 90 deg turn north, a full U-turn to the south, a stop, the settle and the idle, in the
## real city's streets with the buildings along the route left out (no crushing in this step).
## Prints the S's swing each side, the closest two strands come, the U-turn's reversal, the
## stop, the S depth per quarter and the tail's bend, the head's place in the frame, the opening
## second's speeds and the camera's jolt.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_serpent.gd -- --seconds=7

const Kit := preload("res://tools/capture/capture_kit.gd")
const DT := 1.0 / 60.0
const START := Vector2(-12.0, 16.0)
const PREROLL_S := 14.0
## Clip time (s) each stick change happens at: north (the 90 deg turn), south (the U-turn), let go.
const TURN_AT := 0.5
const U_TURN_AT := 2.2
const LET_GO_AT := 4.7
## Frames skipped before the camera's jolt is measured (the window's first frames).
const SETTLE_FRAMES := 6
## How far toward the camera (south, m) the cleared strip reaches from the route.
const CAMERA_SIDE: Array[float] = [8.0, 16.0, 24.0, 32.0]
## The U-turn's stick leans a little east for its first U_TURN_LEAN_S, so it turns right, through
## east, then points straight south.
const U_TURN_LEAN_S := 1.5
const U_TURN := Vector2(0.08, 1.0)

var _args := Kit.args({"seconds": 9.4})
var _proto: SerpentProto
var _closest := INF
var _swath_line := ""
var _stopped_at := -1.0
## The camera's positions, one a frame (for the hitch and the settled end).
var _eyes := PackedVector3Array()
var _jolt_at := 0.0
var _heading_at_u := Vector2.ZERO
## (lowest, highest) share down the frame the head rode on the north leg.
var _north_leg := Vector2(1.0, 0.0)
## The opening second: (slowest, fastest) drawn head and camera, m/s.
var _head_speeds := Vector2(INF, 0.0)
var _last_head := Vector2.INF
## The head tip's place on screen (px at 1080p) each frame of the idle, and the body's width there.
var _idle_px := PackedVector2Array()
var _width_px := 0.0


func _initialize() -> void:
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var cfg := Content.section("serpent")
	var steps := int(PREROLL_S / DT)
	var start := START - Vector2(1, 0) * _preroll_distance(cfg, steps)
	_proto = SerpentProto.new()
	_proto.clear_along = _route(cfg, start, steps)
	_proto.preroll(start, Vector2(1, 0), steps)
	_proto.scripted = _stick
	_swath_line = _swing(START.y)  # the S as the pre-roll laid it
	root.add_child(_proto)
	var frames := 0
	while frames < int(Num.f(_args["seconds"]) / DT):
		await physics_frame
		frames += 1
		_watch()
		_eyes.append(_proto.camera.global_position)
		_track(frames * DT)
	print("serpent capture: renderer %s" % RenderingServer.get_video_adapter_name())
	print("serpent capture: on the straight the S swings %s" % _swath_line)
	print("serpent capture: closest strands %.2f m apart (surface to surface)" % _closest)
	print("serpent capture: head stopped at %.2f s (let go at %.2f s)" % [_stopped_at, LET_GO_AT])
	print("serpent capture: S depth by quarter, head to tail: %s m" % _quarters())
	print("serpent capture: camera %s" % _camera_report())
	print("serpent capture: idle: %s" % _idle_report())
	print("serpent capture: camera still %s after the head stopped" % _camera_settle())
	var turned := rad_to_deg(absf(_heading_at_u.angle_to(_proto.body.heading)))
	print("serpent capture: the U-turn reversed the heading by %.0f deg" % turned)
	print("serpent capture: tail tip bends %.0f deg over its last 4 segments" % _tail_bend())
	var leg := "serpent capture: head %.0f-%.0f%% down the frame on the north leg"
	print(leg % [_north_leg.x * 100.0, _north_leg.y * 100.0])
	var opening := "serpent capture: opening second, drawn head %.2f-%.2f m/s, camera %s"
	print(opening % [_head_speeds.x, _head_speeds.y, _opening_camera()])
	quit()


## How deep the S bends in each quarter of the body (the most a joint stands off the quarter's
## chord): a straight rod reads near 0.
func _quarters() -> String:
	var joints := _proto.stand_in.joints
	var quarter := (joints.size() - 1) / 4
	var out: Array[String] = []
	for q: int in 4:
		var a := joints[q * quarter]
		var b := joints[(q + 1) * quarter]
		var most := 0.0
		for j: int in range(q * quarter, (q + 1) * quarter + 1):
			most = maxf(
				most,
				joints[j].distance_to(Geometry2D.get_closest_point_to_segment(joints[j], a, b))
			)
		out.append("%.1f" % most)
	return ", ".join(out)


## The camera's worst jolt (change of acceleration, m/s^3) and how fast it still moves at the end.
func _camera_report() -> String:
	var jolt := 0.0
	for i: int in range(SETTLE_FRAMES, _eyes.size()):  # the window opens a few frames in
		var a1 := _eyes[i] - 2.0 * _eyes[i - 1] + _eyes[i - 2]
		var a0 := _eyes[i - 1] - 2.0 * _eyes[i - 2] + _eyes[i - 3]
		var j := (a1 - a0).length() / (DT * DT * DT)
		if j > jolt:
			jolt = j
			_jolt_at = i * DT
	var n := _eyes.size()
	var end_speed := _eyes[n - 1].distance_to(_eyes[n - 2]) / DT
	var basis := _proto.camera.global_transform.basis
	var pitch := rad_to_deg(asin(basis.z.y))
	var line := "worst jolt %.1f m/s^3 at %.2f s, last-frame speed %.3f m/s, pitch %.0f deg down"
	return line % [jolt, _jolt_at, end_speed, pitch]


func _stick(seconds: float) -> Vector2:
	if seconds < TURN_AT:
		return Vector2(1, 0)
	if seconds < U_TURN_AT:
		return Vector2(0, -1)
	if seconds < U_TURN_AT + U_TURN_LEAN_S:
		return U_TURN.normalized()
	if seconds < LET_GO_AT:
		return Vector2(0, 1)  # straight south: the heading reverses fully
	return Vector2.ZERO


## Every frame: the closest two strands of the body, and when the head came to rest.
func _watch() -> void:
	var body := _proto.body
	var joints := _proto.stand_in.joints
	var cfg := body.cfg
	var count := joints.size() - 1
	for i: int in count:
		for j: int in range(i + 8, count):
			var w := _half_width(cfg, i, count) + _half_width(cfg, j, count)
			_closest = minf(_closest, joints[i].distance_to(joints[j]) - w)
	if _stopped_at < 0.0 and body.speed <= 0.0:
		_stopped_at = _proto.seconds


func _half_width(_cfg: Dictionary, i: int, count: int) -> float:
	return 0.5 * _proto.stand_in.width_at(i * _proto.body.length() / count)


## How far the S swings each side of the straight centreline (z = `line`) as pre-rolled.
func _swing(line: float) -> String:
	var lo := INF
	var hi := -INF
	for p: Vector2 in _proto.stand_in.joints:
		lo = minf(lo, p.y - line)
		hi = maxf(hi, p.y - line)
	return (
		"+%.1f / %.1f m each side (ruled ~6), %.1f m across with the girth"
		% [hi, lo, hi - lo + Num.f(_proto.body.cfg["girth"])]
	)


## Per frame: the heading as the U-turn starts, the head's place on the north leg, the opening
## second's drawn head speed.
func _track(t: float) -> void:
	var body := _proto.body
	if absf(t - U_TURN_AT) < DT * 0.5:
		_heading_at_u = body.heading
	if t > TURN_AT + 1.4 and t < U_TURN_AT:
		var head := Vector3(body.pos.x, 0.0, body.pos.y)
		var xform := _proto.camera.global_transform
		var down := SerpentCamera.screen_down(xform, _proto.camera.fov, head)
		_north_leg = Vector2(minf(_north_leg.x, down), maxf(_north_leg.y, down))
	_idle_view(t)
	var tip := _proto.stand_in.joints[0]
	if t > DT * 2.0 and t <= 1.0 and _last_head.x != INF:
		var speed := tip.distance_to(_last_head) / DT
		_head_speeds = Vector2(minf(_head_speeds.x, speed), maxf(_head_speeds.y, speed))
	_last_head = tip


## While the idle runs: where the head tip is on screen, and how wide the body is mid-way (px).
func _idle_view(t: float) -> void:
	var stand := _proto.stand_in
	if _stopped_at < 0.0 or t < _stopped_at + Num.f(_proto.body.cfg["coil_s"]) + 0.2:
		return
	var cam := _proto.camera
	var tip := stand.joints[0]
	var at := Vector3(tip.x, stand.lifts[0], tip.y)
	_idle_px.append(cam.unproject_position(at))
	var mid := stand.joints[stand.joints.size() / 2]
	var half := stand.width_at(stand.joints.size() * 0.5 * _proto.body.length() / 60.0) * 0.5
	var a := cam.unproject_position(Vector3(mid.x - half, 0.0, mid.y))
	var b := cam.unproject_position(Vector3(mid.x + half, 0.0, mid.y))
	_width_px = a.distance_to(b)


## How far the head tip wanders on screen during the idle (px from its mean), and the body width.
func _idle_report() -> String:
	if _idle_px.is_empty():
		return "no idle seen"
	var mean := Vector2.ZERO
	for p: Vector2 in _idle_px:
		mean += p / _idle_px.size()
	var most := 0.0
	for p: Vector2 in _idle_px:
		most = maxf(most, p.distance_to(mean))
	return (
		"head tip wanders up to %.0f px (body %.0f px wide at 1080p) over %.1f s"
		% [most, _width_px, _idle_px.size() * DT]
	)


## Seconds after the head stopped until the camera is still (under 0.15 m/s from then on).
func _camera_settle() -> String:
	if _stopped_at < 0.0:
		return "head never stopped"
	var last_fast := 0
	for i: int in range(1, _eyes.size()):
		if _eyes[i].distance_to(_eyes[i - 1]) / DT > 0.15:
			last_fast = i
	return "%.2f s" % maxf(last_fast * DT - _stopped_at, 0.0)


## The camera's slowest and fastest speed over the opening second.
func _opening_camera() -> String:
	var lo := INF
	var hi := 0.0
	for i: int in range(SETTLE_FRAMES, mini(_eyes.size(), int(1.0 / DT))):
		var speed := _eyes[i].distance_to(_eyes[i - 1]) / DT
		lo = minf(lo, speed)
		hi = maxf(hi, speed)
	return "%.2f-%.2f m/s" % [lo, hi]


## How far the last 4 segments turn, tip to tail joint, degrees.
func _tail_bend() -> float:
	var j := _proto.stand_in.joints
	var n := j.size() - 1
	var total := 0.0
	for i: int in range(n - 4, n):
		total += (j[i - 1] - j[i]).angle_to(j[i] - j[i + 1])
	return rad_to_deg(absf(total))


## How far a body set off from rest goes in `steps` (so the clip starts at START).
func _preroll_distance(cfg: Dictionary, steps: int) -> float:
	var body := SerpentBody.new(cfg, Vector2.ZERO, Vector2(1, 0))
	for _i: int in steps:
		body.step(DT, Vector2(1, 0))
	return body.pos.x


## The ground the whole run's body covers (pre-roll and clip), and the strip from it toward the
## camera (which looks north from the south), for the buildings to leave out.
func _route(cfg: Dictionary, start: Vector2, steps: int) -> PackedVector2Array:
	var body := SerpentBody.new(cfg, start, Vector2(1, 0))
	var out := PackedVector2Array()
	for i: int in steps:
		body.step(DT, Vector2(1, 0))
		if i % 6 == 0:
			out.append(body.pos)
	for i: int in int(Num.f(_args["seconds"]) / DT):
		body.step(DT, _stick(i * DT))
		if i % 6 == 0:
			out.append(body.pos)
	for p: Vector2 in out.duplicate():
		for toward: float in CAMERA_SIDE:
			out.append(p + Vector2(0.0, toward))
	return out
