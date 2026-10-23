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

var _args := (
	Kit
	. args(
		{
			"seconds": 9.4,
			"still": -1.0,
			"label": "",
			"out": "user://serpent_still.png",
			"girth_scale": -1.0,
			"head_scale": -1.0,
			"run_hood": -1.0,
			"cam_zoom": 1.0,
			"cam_pitch": 0.0,
			"shadow_bias": -1.0,
			"normal_bias": -1.0,
			"sun_blur": -1.0,
		}
	)
)
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
	_look_options(cfg)
	var steps := int(PREROLL_S / DT)
	var start := START - Vector2(1, 0) * _preroll_distance(cfg, steps)
	_proto = SerpentProto.new()
	_proto.clear_along = _route(cfg, start, steps)
	_proto.preroll(start, Vector2(1, 0), steps)
	_proto.scripted = stick_at
	_swath_line = _swing(START.y)  # the S as the pre-roll laid it
	root.add_child(_proto)
	_sun_trial()
	var frames := 0
	while frames < int(Num.f(_args["seconds"]) / DT):
		await physics_frame
		frames += 1
		_watch()
		_eyes.append(_proto.camera.global_position)
		_track(frames * DT)
		if Num.f(_args["still"]) >= 0.0 and frames == int(Num.f(_args["still"]) / DT):
			await _still()
			return
	print("serpent capture: renderer %s" % RenderingServer.get_video_adapter_name())
	var sun := _proto.sun_shadow()
	print(
		"serpent capture: sun shadow blur %.2f, bias %.2f, normal bias %.2f" % [sun.x, sun.y, sun.z]
	)
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


## The size options for a labelled still (the director's call, D-188 round 5): girth and head
## scale, the hood spread while it runs, the camera brought closer (cam_zoom of its distance) or
## pitched cam_pitch deg lower. Applied to the shared "serpent" table before anything reads it.
func _look_options(cfg: Dictionary) -> void:
	for key: String in ["girth_scale", "head_scale", "run_hood"]:
		if Num.f(_args[key]) >= 0.0:
			cfg[key] = Num.f(_args[key])
	if Num.f(_args["sun_blur"]) >= 0.0:
		cfg["sun_shadow_blur"] = Num.f(_args["sun_blur"])
	var height := Num.f(cfg["camera_height"]) * Num.f(_args["cam_zoom"])
	var back := Num.f(cfg["camera_back"]) * Num.f(_args["cam_zoom"])
	var reach := Vector2(back, height).length()
	var pitch := atan2(height, back) - deg_to_rad(Num.f(_args["cam_pitch"]))
	cfg["camera_height"] = reach * sin(pitch)
	cfg["camera_back"] = reach * cos(pitch)


## Shadow trials for the lead (round 6): --shadow_bias and --normal_bias set on the scene's shadowed
## sun (--sun_blur sets the scene's own sun_shadow_blur), to compare what clears the speckle.
func _sun_trial() -> void:
	for node: Node in _proto.find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		if sun.shadow_enabled and Num.f(_args["shadow_bias"]) >= 0.0:
			sun.shadow_bias = Num.f(_args["shadow_bias"])
		if sun.shadow_enabled and Num.f(_args["normal_bias"]) >= 0.0:
			sun.shadow_normal_bias = Num.f(_args["normal_bias"])


## The labelled still: the label large at the top left, then the frame saved to --out.
func _still() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = str(_args["label"])
	label.position = Vector2(40, 30)
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 14)
	layer.add_child(label)
	root.add_child(layer)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(str(_args["out"]))
	print(
		(
			"serpent capture: still %s at %.1f s to %s (sun blur, bias, normal %s)"
			% [label.text, Num.f(_args["still"]), _args["out"], _proto.sun_shadow()]
		)
	)
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


## The clip's stick at `seconds` (shared with tools/capture/serpent_probe.gd).
static func stick_at(seconds: float) -> Vector2:
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
		body.step(DT, stick_at(i * DT))
		if i % 6 == 0:
			out.append(body.pos)
	for p: Vector2 in out.duplicate():
		for toward: float in CAMERA_SIDE:
			out.append(p + Vector2(0.0, toward))
	return out
