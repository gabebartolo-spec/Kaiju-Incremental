extends RefCounted
## The building stream follows the camera's view (BuildingStream): through the fastest camera
## swing the game allows (the breath's side orbit, BreathCamera) no stand-in box shows inside the
## full-detail depth DEPTH_M. For stages 2 and 4 a real stream (the stage's city, the real chunk
## budget, workers meshing in real time) runs under the real camera path (CameraFollow,
## BreathCamera, 60 frames a second) with the kaiju at three spots. Every frame, each building left
## as a box whose bounding box meets the camera's frustum gives a distance from the camera; the
## smallest over a phase is the depth with full buildings ("depth"; "ahead" is the same within 10
## degrees of the view axis). The rest and the swing at every spot must keep DEPTH_M. A dash
## (36 m at stage 2, 113 m at stage 4, in 0.4 s) is run and reported only: the camera reaches
## ground the budget cannot have meshed ahead of it. Presentation only: the sim is never stepped,
## only its kaiju moved. Not exercised: camera shake, a real GPU frame, a slower machine.

const Growth := preload("res://tools/capture/capture_growth.gd")

## The full-detail depth every phase must keep (metres from the camera).
const DEPTH_M := 48.0
const DT := 1.0 / 60.0
const FRAME_USEC := 16667
## The body the camera follows eases toward the sim's kaiju at this rate (Rampage._update_kaiju).
const BODY_FOLLOW := 12.0
## Boxes farther than this never count (and are not tested).
const LOOK_M := 260.0
## Real time to wait for the stream to settle.
const SETTLE_MS := 240000
const STAGES: Array[int] = [2, 4]
## Where the kaiju stands (the first also dashes): the central junction and two spots among blocks.
const SPOTS: Array[Vector2] = [Vector2(0, 0), Vector2(26, -14), Vector2(-30, 18)]

var _check: Callable
var _host: Node
var _sim: RampageSim
var _stream: BuildingStream
var _camera: Camera3D
var _follow: CameraFollow
var _breath := BreathCamera.new()
var _body := Vector3.ZERO
var _zoom := 1.0
var _inward := 0.0  # 1 when the frustum's planes face outward, -1 inward (found on first use)
var _clock := 0
## The camera's fastest turn seen (degrees a second) and the widest it swung from rest (degrees).
var yaw_rate := 0.0
var yaw_reach := 0.0
var _last_yaw := 0.0
var _rest_yaw := 0.0
var report: Array[String] = []
var worst_step := 0
var ahead := 0.0


func _init(p_check: Callable, p_host: Node) -> void:
	_check = p_check
	_host = p_host


func run() -> void:
	for stage: int in STAGES:
		await _stage(stage)


func _stage(stage: int) -> void:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), Growth.LEVELS[stage - 1], "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var tier := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	_sim = RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	_sim.body.use_species("reptilian")
	_sim.kaiju_pos = Vector2.ZERO
	var colors: Array[Color] = []
	for b: RampageSim.Building in _sim.buildings:
		colors.append(Color.GRAY)
	_camera = Camera3D.new()
	_camera.fov = CameraTuning.fov()
	_host.add_child(_camera)
	_camera.current = true
	_zoom = CameraTuning.zoom(_sim.body_scale())
	_snap()
	_stream = BuildingStream.new(_sim, colors)
	_host.add_child(_stream)
	var steps: Array[float] = []
	worst_step = 0
	var results := {}
	var fx: Dictionary = Content.section("fx")
	var swing := Num.f(fx["orbit_in_seconds"]) + Num.f(fx["beam_seconds"]) + Num.f(fx["orbit_out_seconds"])
	var long := _sim.body.length()
	var dash: Dictionary = _sim.body.dash.cfg
	var seconds := Num.f(dash["seconds"])
	var speed := Num.f(dash["lengths"]) * long / seconds
	for at: int in SPOTS.size():
		_sim.kaiju_pos = SPOTS[at]
		_body = Vector3(_sim.kaiju_pos.x, _sim.stand_y, _sim.kaiju_pos.y)
		_follow.focus = _body
		await _settle()
		var tag := "" if at == 0 else " at %d" % at
		results["rest" + tag] = await _phase(1.0, func(_t: float) -> void: pass)
		_breath.start(1.0)
		_rest_yaw = _yaw()
		_last_yaw = _rest_yaw
		results["swing" + tag] = await _phase(swing + 0.3, func(_t: float) -> void: pass, true)
		if at > 0:
			continue
		await _settle()
		for way: Array in [["dash ahead", Vector2(0, -1)], ["dash sideways", Vector2(1, 0)]]:
			var dir: Vector2 = way[1]
			var from := _sim.kaiju_pos
			var run := func(t: float) -> void:
				if t < seconds:
					_sim.kaiju_pos = _sim.clamp_to_arena(_sim.kaiju_pos + dir * speed * DT)
			results[way[0]] = await _phase(seconds + 1.5, run)
			_sim.kaiju_pos = from
			await _settle()
	var plans: int = Num.i(_stream.get("plans") if "plans" in _stream else 0)
	var plan_usec: int = Num.i(_stream.get("plan_usec") if "plan_usec" in _stream else 0)
	var line := "VIEWDEPTH stage %d (%d buildings; camera turns up to %.0f deg/s, swings %.1f deg; worst step %.0f ms, mean replan %.1f ms):" % [
		stage, _sim.buildings.size(), yaw_rate, yaw_reach, worst_step / 1000.0, plan_usec / 1000.0 / maxi(1, plans)]
	for phase: String in results:
		var r: Dictionary = results[phase]
		line += "
  %-14s depth %3.0f m, ahead %3.0f m, %3d frames with a box inside %.0f m" % [phase, r["depth"], r["ahead"], r["short"], DEPTH_M]
	print(line)
	for phase: String in results:
		if phase.begins_with("dash"):
			continue  # a dash crosses 36-113 m in 0.4 s: reported, not held (see the suite's note)
		_check.call(
			results[phase]["depth"] >= DEPTH_M,
			(
				"stage %d, %s: no stand-in box inside the camera's frustum within %.0f m on any frame"
				+ " (nearest %.0f m, %d frames short)"
			)
			% [stage, phase, DEPTH_M, results[phase]["depth"], results[phase]["short"]]
		)
	for phase: String in results:
		steps.append(results[phase]["step"])
	steps.sort()
	_check.call(
		steps[steps.size() / 2] <= 50.0,
		"stage %d: the stream's worst step stays under 50 ms (median phase %.0f ms, worst %.0f ms)" % [stage, steps[steps.size() / 2], steps[-1]]
	)
	var shake := Num.f(Content.section("camera_shake")["max_deg"])
	var margin := Num.f(_sim.city["stream_view"]["margin_deg"]) if _sim.city.has("stream_view") else 0.0
	_check.call(
		margin >= yaw_reach + shake,
		"stage %d: the margin band (%.1f deg) is wider than the widest camera swing (%.1f deg) plus its shake (%.1f deg)" % [stage, margin, yaw_reach, shake]
	)
	_host.remove_child(_stream)
	_stream.free()
	_camera.free()
	await _host.get_tree().process_frame


## The camera at rest on the kaiju (the first placement of Rampage).
func _snap() -> void:
	_body = Vector3(_sim.kaiju_pos.x, _sim.stand_y, _sim.kaiju_pos.y)
	_follow = CameraFollow.new(_body, CameraTuning.offset())
	_follow.step(_body, CameraTuning.offset() * _zoom, 1.0)
	_place()


func _place() -> void:
	_camera.position = _follow.eye()
	_camera.look_at(_follow.look_at(_sim.body_scale()))


func _yaw() -> float:
	var f := -_camera.global_transform.basis.z
	return rad_to_deg(atan2(f.x, -f.z))


## One frame: the sim's kaiju to the body, the camera after it, real time paced at 60 a second.
func _frame(swinging: bool) -> void:
	_body = _body.lerp(Vector3(_sim.kaiju_pos.x, _sim.stand_y, _sim.kaiju_pos.y), minf(1.0, DT * BODY_FOLLOW))
	var rest := CameraTuning.offset()
	if swinging:
		rest = _breath.offset(rest, DT)
	_follow.step(_body, rest * _zoom, DT)
	_place()
	if swinging:
		var yaw := _yaw()
		var turn := absf(angle_difference(deg_to_rad(_last_yaw), deg_to_rad(yaw)))
		yaw_rate = maxf(yaw_rate, rad_to_deg(turn) / DT)
		yaw_reach = maxf(yaw_reach, absf(yaw - _rest_yaw))
		_last_yaw = yaw
	var tree := _host.get_tree()
	var wait := _clock + FRAME_USEC - Time.get_ticks_usec()
	if wait > 0:
		OS.delay_usec(wait)
	_clock = Time.get_ticks_usec()
	await tree.process_frame


## Waits until the stream has nothing left to mesh or free (the camera holds still).
func _settle() -> void:
	var deadline := Time.get_ticks_msec() + SETTLE_MS
	for i: int in 45:  # the stream replans a quarter second after the camera moves
		await _frame(false)
	while not _stream.complete() and Time.get_ticks_msec() < deadline:
		await _frame(false)
	for i: int in 30:
		await _frame(false)


## Runs `seconds` of frames; `step` moves the kaiju (given the seconds so far). Returns the
## depth with full buildings (smallest box distance seen, LOOK_M when none) and the frames on
## which a box stood inside DEPTH_M.
func _phase(seconds: float, step: Callable, swinging: bool = false) -> Dictionary:
	_stream.worst_usec = 0
	var depth := LOOK_M
	var aheadmin := LOOK_M
	var short := 0
	var t := 0.0
	while t < seconds:
		step.call(t)
		await _frame(swinging)
		var d := _nearest_box()
		depth = minf(depth, d)
		aheadmin = minf(aheadmin, ahead)
		short += 1 if d < DEPTH_M else 0
		t += DT
	worst_step = maxi(worst_step, _stream.worst_usec)
	return {"depth": depth, "short": short, "ahead": aheadmin, "step": _stream.worst_usec / 1000.0}


## The distance from the camera to the nearest building still standing as a box whose
## bounding box meets the camera's frustum (LOOK_M when none within reach).
func _nearest_box() -> float:
	var planes := _camera.get_frustum()
	var eye := _camera.global_position
	if _inward == 0.0:  # which way the planes face: a point ahead of the camera is inside
		var ahead := eye - _camera.global_transform.basis.z * 10.0
		_inward = 1.0 if (planes[2] as Plane).distance_to(ahead) < 0.0 else -1.0
	var best := LOOK_M
	var fwd := Vector2(-_camera.global_transform.basis.z.x, -_camera.global_transform.basis.z.z).normalized()
	ahead = LOOK_M
	for n: int in _sim.buildings.size():
		if _stream.built(n) != null:
			continue
		var b := _sim.buildings[n]
		var box := AABB(
			Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, b.height, b.d)
		)
		var near := Vector3(clampf(eye.x, box.position.x, box.end.x), clampf(eye.y, 0.0, b.height), clampf(eye.z, box.position.z, box.end.z))
		var d := eye.distance_to(near)
		if d >= ahead and d >= best:
			continue
		if not _in_frustum(planes, box):
			continue
		var rel := Vector2(b.x - eye.x, b.z - eye.z)
		if absf(rel.angle_to(fwd)) < deg_to_rad(10.0):
			ahead = minf(ahead, d)
		if d < best:
			best = d
	return best


## Whether the box is not wholly outside one of the frustum's planes.
func _in_frustum(planes: Array[Plane], box: AABB) -> bool:
	for plane: Plane in planes:
		var out := true
		for i: int in 8:
			if plane.distance_to(box.get_endpoint(i)) * _inward <= 0.0:
				out = false
				break
		if out:
			return false
	return true
