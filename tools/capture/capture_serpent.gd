extends SceneTree
## The serpent slither prototype's clip (D-198: "a stand-in segmented body slithering, turning and
## stopping at the game camera, one ~6 s clip"): already slithering east (pre-rolled, its S laid),
## then a 90 deg turn north, a U-turn to the south, and a stop, in the real city's streets with the
## buildings along the route left out (no crushing in this step). Prints the swath it sweeps, the
## closest two strands of the body come (a U-turn could fold it over itself) and the stop time.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_serpent.gd -- --seconds=7

const Kit := preload("res://tools/capture/capture_kit.gd")
const DT := 1.0 / 60.0
const START := Vector2(-12.0, 16.0)
const PREROLL_S := 8.0
## Clip time (s) each stick change happens at: north (the 90 deg turn), south (the U-turn), let go.
const TURN_AT := 0.8
const U_TURN_AT := 2.4
const LET_GO_AT := 4.6
## Frames skipped before the camera's jolt is measured (the window's first frames).
const SETTLE_FRAMES := 6
## How far toward the camera (south, m) the cleared strip reaches from the route.
const CAMERA_SIDE: Array[float] = [8.0, 16.0, 24.0, 32.0]
## The U-turn's stick leans a little east, so it turns right, through east.
const U_TURN := Vector2(0.08, 1.0)

var _args := Kit.args({"seconds": 7.0})
var _proto: SerpentProto
var _closest := INF
var _swath := 0.0
var _stopped_at := -1.0
## The camera's positions, one a frame (for the hitch and the settled end).
var _eyes := PackedVector3Array()
var _jolt_at := 0.0


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
	_swath = _width(_proto.body)  # the S as the pre-roll laid it
	root.add_child(_proto)
	var frames := 0
	while frames < int(Num.f(_args["seconds"]) / DT):
		await physics_frame
		frames += 1
		_watch()
		_eyes.append(_proto.camera.global_position)
	print("serpent capture: renderer %s" % RenderingServer.get_video_adapter_name())
	print("serpent capture: swath %.1f m across while slithering straight" % _swath)
	print("serpent capture: closest strands %.2f m apart (surface to surface)" % _closest)
	print("serpent capture: head stopped at %.2f s (let go at %.2f s)" % [_stopped_at, LET_GO_AT])
	print("serpent capture: S depth by quarter, head to tail: %s m" % _quarters())
	print("serpent capture: camera %s" % _camera_report())
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
	if seconds < LET_GO_AT:
		return U_TURN.normalized()
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


func _half_width(cfg: Dictionary, i: int, count: int) -> float:
	var t := float(i) / maxf(1.0, count - 1.0)
	return 0.5 * lerpf(Num.f(cfg["head_width"]), Num.f(cfg["tail_width"]), t)


## The ground the body sweeps across its way on a straight: its widest side-to-side reach.
func _width(body: SerpentBody) -> float:
	var joints := _proto.stand_in.joints
	var lo := INF
	var hi := -INF
	for p: Vector2 in joints:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	return hi - lo + Num.f(body.cfg["head_width"])


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
