extends RefCounted
## The building stream follows the camera's view (BuildingStream): through the fastest camera
## swing the game allows (the breath's side orbit, BreathCamera) no stand-in box shows inside the
## full-detail depth DEPTH_M. For stages 2 and 3 a real stream (the stage's city, the real chunk
## budget, its workers meshing) runs under the real camera path (CameraFollow,
## BreathCamera, 60 frames a second) with the kaiju at three spots. Every frame, each building left
## as a box whose bounding box meets the camera's frustum gives a distance from the camera; the
## smallest over a phase is the depth with full buildings ("depth"; "ahead" is the same within 10
## degrees of the view axis). The rest and the swing at every spot must keep DEPTH_M. A dash
## (a body length or more in 0.4 s) is run and reported only: the camera reaches
## ground the budget cannot have meshed ahead of it.
##
## Landmarks (the stadium and wheel at these stages) unload like ordinary buildings when the
## camera cannot see them (director 2026-10-22: "Yes, if no pop-in"), so every frame also counts
## the landmarks standing as a box whose bounding box meets the camera's frustum, at any
## distance: none may show through rest, swing, a walk from the junction each way with the swing
## running, or a dash. Presentation only. Not exercised: camera shake, a GPU frame, a slower PC.

const Kit := preload("res://tools/capture/capture_kit.gd")
const StreamFrustum := preload("res://tests/lib/stream_frustum.gd")

## The full-detail depth every phase must keep (metres from the camera).
const DEPTH_M := 48.0
const DT := 1.0 / 60.0
## The body the camera follows eases toward the sim's kaiju at this rate (Rampage._update_kaiju).
const BODY_FOLLOW := 12.0
const LOOK_M := StreamFrustum.LOOK_M
## Real time to wait for the stream to settle.
const SETTLE_MS := 240000
const STAGES: Array[int] = [2, 3]
## Walks out from the junction (name, heading, metres) and back, the breath's swing running at
## the start and half way: the landmarks leave the view and return to it. The north-east walk
## ends in the arena corner, 250 m and more from them with the camera turned away.
const WALKS: Array[Array] = [
	["walk east", Vector2(1, 0), 150.0], ["walk north-east", Vector2(0.7071, -0.7071), 290.0]
]
## Where the kaiju stands (the first also dashes): the central junction and two spots among blocks.
const SPOTS: Array[Vector2] = [Vector2(0, 0), Vector2(26, -14), Vector2(-30, 18)]

## The camera's fastest turn seen (degrees a second) and the widest it swung from rest (degrees).
var yaw_rate := 0.0
var yaw_reach := 0.0
var worst_step := 0

var _check: Callable
var _marks: Array[int] = []
var _view: StreamFrustum
var _host: Node
var _sim: RampageSim
var _stream: BuildingStream
var _camera: Camera3D
var _follow: CameraFollow
var _breath := BreathCamera.new()
var _body := Vector3.ZERO
var _zoom := 1.0
var _step_us := 0  # the slowest stream frame of the phase (microseconds)
var _last_yaw := 0.0
var _rest_yaw := 0.0


func _init(p_check: Callable, p_host: Node) -> void:
	_check = p_check
	_host = p_host


func run() -> void:
	for stage: int in STAGES:
		await _stage(stage)


func _stage(stage: int) -> void:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), Kit.STAGE_LEVELS[stage - 1], "reptilian")
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
	_marks.clear()
	for n: int in _sim.buildings.size():
		if _sim.buildings[n].landmark != "":
			_marks.append(n)
	_snap()
	_stream = BuildingStream.new(_sim, colors)
	_host.add_child(_stream)
	_stream.set_process(false)  # this test owns the stream's clock: see _advance
	_view = StreamFrustum.new(_sim, _stream, _camera, _marks)
	var steps: Array[float] = []
	worst_step = 0
	var results := {}
	var fx: Dictionary = Content.section("fx")
	var swing := (
		Num.f(fx["orbit_in_seconds"]) + Num.f(fx["beam_seconds"]) + Num.f(fx["orbit_out_seconds"])
	)
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
		for way: Array in WALKS:
			var heading: Vector2 = way[1]
			var metres: float = way[2]
			results[way[0]] = await _walk(heading, metres)
			results[way[0] + " and back"] = await _walk(-heading, metres)
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
	var line := (
		(
			"VIEWDEPTH stage %d (%d buildings; camera turns up to %.0f deg/s, swings %.1f deg;"
			+ " worst step %.0f ms, mean replan %.1f ms):"
		)
		% [
			stage,
			_sim.buildings.size(),
			yaw_rate,
			yaw_reach,
			worst_step / 1000.0,
			plan_usec / 1000.0 / maxi(1, plans)
		]
	)
	line += (
		"\n  landmarks %d, %d chunks (stream budget %d), resident at the end %d"
		% [
			_marks.size(),
			_view.landmark_chunks(),
			Num.i(_sim.city["stream_chunks"]),
			_stream.resident_chunks()
		]
	)
	for phase: String in results:
		var r: Dictionary = results[phase]
		line += (
			(
				"\n  %-14s depth %3.0f m, ahead %3.0f m, %3d frames with a box inside %.0f m,"
				+ " %3d frames with a landmark box in view, %3d frames with a landmark unloaded"
			)
			% [phase, r["depth"], r["ahead"], r["short"], DEPTH_M, r["pop"], r["out"]]
		)
	print(line)
	for phase: String in results:
		if not (phase.begins_with("dash") or phase.begins_with("walk")):  # reported, not held
			var depth: float = results[phase]["depth"]
			_check.call(
				depth >= DEPTH_M,
				(
					(
						"stage %d, %s: no stand-in box inside the camera's frustum within %.0f m"
						% [stage, phase, DEPTH_M]
					)
					+ (
						" on any frame (nearest %.0f m, %d frames short)"
						% [depth, results[phase]["short"]]
					)
				)
			)
		var pops: int = results[phase]["pop"]
		_check.call(
			pops == 0,
			(
				"stage %d, %s: no landmark is a stand-in box in the camera's view (%d frames)"
				% [stage, phase, pops]
			)
		)
	var unloaded := 0
	for phase: String in results:
		unloaded += Num.i(results[phase]["out"])
	if stage == STAGES[-1]:  # the walks reach 200 m from the landmarks only in the big arena (stage 3)
		_check.call(
			unloaded > 0,
			(
				"stage %d: a landmark is unloaded out of view (%d frames): the pop check is live"
				% [stage, unloaded]
			)
		)
	for phase: String in results:
		steps.append(results[phase]["step"])
	steps.sort()
	(
		_check
		. call(
			steps[steps.size() / 2] <= 50.0,
			(
				"stage %d: the stream's worst step stays under 50 ms (median phase %.0f ms, worst %.0f ms)"
				% [stage, steps[steps.size() / 2], steps[-1]]
			)
		)
	)
	var shake := Num.f(Content.section("camera_shake")["max_deg"])
	var margin := (
		Num.f(_sim.city["stream_view"]["margin_deg"]) if _sim.city.has("stream_view") else 0.0
	)
	(
		_check
		. call(
			margin >= yaw_reach + shake,
			(
				(
					"stage %d: the margin band (%.1f deg) is wider than the widest camera swing (%.1f deg)"
					+ " plus its shake (%.1f deg)"
				)
				% [stage, margin, yaw_reach, shake]
			)
		)
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


## One frame: the sim's kaiju to the body, the camera after it, then the stream's frame.
func _frame(swinging: bool) -> void:
	_body = _body.lerp(
		Vector3(_sim.kaiju_pos.x, _sim.stand_y, _sim.kaiju_pos.y), minf(1.0, DT * BODY_FOLLOW)
	)
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
	_advance()
	await _host.get_tree().process_frame


## The stream's frame of DT seconds, then its workers run to the end of what they were given: the
## test judges what the plan has meshed in camera time, never how fast this machine's workers are.
func _advance() -> void:
	var t0 := Time.get_ticks_usec()
	_stream.step(DT)
	_step_us = maxi(_step_us, Time.get_ticks_usec() - t0)
	var deadline := Time.get_ticks_msec() + SETTLE_MS
	while not _stream.complete() and Time.get_ticks_msec() < deadline:
		OS.delay_usec(200)
		_stream.step(0.0)


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
	_step_us = 0
	var depth := LOOK_M
	var aheadmin := LOOK_M
	var short := 0
	var pop := 0
	var out := 0
	var t := 0.0
	while t < seconds:
		step.call(t)
		await _frame(swinging)
		var d := _view.nearest_box()
		depth = minf(depth, d)
		aheadmin = minf(aheadmin, _view.ahead)
		short += 1 if d < DEPTH_M else 0
		pop += 1 if _view.landmark_pops() > 0 else 0
		out += 1 if _view.unbuilt > 0 else 0
		t += DT
	worst_step = maxi(worst_step, _step_us)
	return {
		"depth": depth,
		"short": short,
		"ahead": aheadmin,
		"pop": pop,
		"out": out,
		"step": _step_us / 1000.0
	}


## A walk of `metres` from where the kaiju stands in `dir` at its walking speed, the breath's
## swing running at its start and half way (the camera turning while the kaiju moves).
func _walk(dir: Vector2, metres: float) -> Dictionary:
	var speed := _sim.stat("speed")
	var seconds := metres / speed
	var started := [false, false]
	var run := func(t: float) -> void:
		_sim.kaiju_pos = _sim.clamp_to_arena(_sim.kaiju_pos + dir * speed * DT)
		for k: int in 2:
			if not started[k] and t >= seconds * 0.5 * k:
				started[k] = true
				_breath.start(1.0)
	return await _phase(seconds, run, true)
