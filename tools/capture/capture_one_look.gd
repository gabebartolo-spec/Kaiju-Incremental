extends SceneTree
## One look, phase 1 proof (D-163): the same seeded rampage (city seed 0, the reptilian, the
## Behemoth body and its city, Medium preset, HUD on) with the phase-1 look or today's, as stills
## or a clip (--write-movie). Same seed, route and tick in both, so pairs differ only by the look.
##   --today  zero the phase-1 keys (far blur, block ground): the picture before D-163
##   --time=dusk|night|morning|noon   --stage=2 (STAGE_LEVELS index + 1)   --out=<dir>
##   --label=<name>   --stills=4,12 (seconds after the rise)   --seconds=6 --skip=9 (a clip:
##   the whole run is recorded; trim from the "risen at drawn frame" line + skip*60)
##   --route=idle|record|replay  --route-file=<json>  --face=x,z,steps  --cam=x,y,z
##   --fire=x,z,at,size  (a ground fire the capture lights, the same in both)
##   --set=key=value,...  (look; true/false ok)   --tune=section.key=value  (a tuning.json number)
##   --graphics=potato|low|medium|high|max   --frames=N  (print the mean frame time after N frames)

const Kit := preload("res://tools/capture/capture_kit.gd")
## What --today zeroes: every number phase 1 added to the look (the keys that make a pair differ).
const PHASE_ONE_KEYS: Array[String] = [
	"far_blur_amount",
	"ground_block_noise",
	"ground_patch_noise",
	"ground_speck_chance",
	"ground_seam",
]

var _out := "user://one_look"
var _stills: Array[float] = [4.0]
var _seconds := 0.0
var _skip := 0.0
var _label := "p1"
var _time := "dusk"
var _stage := 2
var _today := false
var _graphics := "medium"
var _bench := 0
var _sets: Dictionary = {}
var _route_mode := "idle"
var _route_file := ""
var _route: Array = []
var _target := Vector2(INF, INF)
var _steps := 0
var _cam := Vector3.INF
var _face := Vector2.ZERO
var _face_steps := 0
var _fire := Vector4.ZERO
var _fire_done := true


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--stills="):
			_stills = []
			for s: String in arg.substr(9).split(","):
				_stills.append(float(s))
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--skip="):
			_skip = float(arg.substr(7))
		elif arg.begins_with("--route="):
			_route_mode = arg.substr(8)
		elif arg.begins_with("--route-file="):
			_route_file = arg.substr(13)
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
		elif arg.begins_with("--stage="):
			_stage = int(arg.substr(8))
		elif arg.begins_with("--graphics="):
			_graphics = arg.substr(11)
		elif arg.begins_with("--frames="):
			_bench = int(arg.substr(9))
		elif arg.begins_with("--set="):
			for pair: String in arg.substr(6).split(","):
				var kv := pair.split("=")
				if kv[1] in ["true", "false"]:  # a look switch such as deband
					_sets[kv[0]] = kv[1] == "true"
				else:
					_sets[kv[0]] = float(kv[1]) if kv[1].is_valid_float() else kv[1]
		elif arg.begins_with("--tune="):  # --tune=camera.fade_opacity=1 (a tuning.json number)
			var tv := arg.substr(7).split("=")
			var path := tv[0].split(".")  # any depth: display.graphics.medium.fsr_sharpness=0.1
			var table: Dictionary = Content.section(path[0])
			for i: int in range(1, path.size() - 1):
				table = table[path[i]]
			table[path[path.size() - 1]] = float(tv[1])
		elif arg == "--today":
			_today = true
		elif arg == "--calm":
			PlayerSettings.camera_motion = 0.0  # no shake or dip, so a pair frames the same way
		elif arg.begins_with("--cam="):
			var p := arg.substr(6).split(",")
			_cam = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif arg.begins_with("--face="):
			var f := arg.substr(7).split(",")
			_face = Vector2(float(f[0]), float(f[1])).normalized()
			_face_steps = int(f[2])
		elif arg.begins_with("--fire="):
			var q := arg.substr(7).split(",")
			_fire = Vector4(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
			_fire_done = false
		elif arg.begins_with("--label="):
			_label = arg.substr(8)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	PlayerSettings.graphics = _graphics  # the 4K default preset (D-109), whatever the screen is
	var species := Content.species_def("reptilian")
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[_stage - 1], "reptilian")
	var tier := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	Content.set_time(_time)
	var look := Content.look()
	if _today:
		for key: String in PHASE_ONE_KEYS:
			look[key] = 0.0
	for key: String in _sets:
		look[key] = _sets[key]
	if _cam != Vector3.INF:
		rampage.camera_rest = _cam
	root.add_child(rampage)
	rampage.set_physics_process(false)  # after _ready, which switches it on
	var city: CityView = rampage.get("_city")
	var stream: BuildingStream = city.get("_stream")
	while not stream.complete():
		await process_frame
	for _i: int in 10:
		await process_frame
	print(
		(
			"ONEL stream complete, buildings=%d, time=%s, today=%s"
			% [rampage.sim.buildings.size(), _time, _today]
		)
	)
	rampage.set_physics_process(true)
	# The breath-aim wedge is a play aid, not part of the look: hide it in every capture.
	for child: Node in rampage.get_children():
		if child is BreathAim:
			child.set_physics_process(false)
			child.set_process(false)
			(child as BreathAim).visible = false
	if _route_mode == "replay":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_route_file))
		if not parsed is Array:
			push_error("ONEL no route at %s" % _route_file)
			quit(1)
			return
		_route = parsed
	rampage.scripted = _scripted
	while rampage.sim.emerge.active:
		await physics_frame
	print("ONEL risen at drawn frame %d" % Engine.get_frames_drawn())
	var frames := 0
	if _bench > 0:
		await _bench_frames(rampage, city)
		quit()
		return
	if _seconds > 0.0:
		var total := int((_skip + _seconds) * 60.0)
		while frames < total and not rampage.sim.over:
			await physics_frame
			frames += 1
			_maybe_fire(city, frames)
		print("ONEL clip end frame %d" % Engine.get_frames_drawn())
		_finish()
		return
	for at: float in _stills:
		while frames < int(at * 60.0) and not rampage.sim.over:
			await physics_frame
			frames += 1
			_maybe_fire(city, frames)
		for _i: int in 4:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		if image == null:
			print("ONEL no image (headless) t=%d" % int(at))
			continue
		image.save_png("%s/%s_t%02d.png" % [_out, _label, int(at)])
		_print_fires(city, image.get_size())
		print("ONEL kaiju at %s" % rampage.sim.kaiju_pos)
		print(
			(
				"ONEL shot t=%d size=%s fires=%d"
				% [int(at), image.get_size(), _fire_nodes(city).size()]
			)
		)
	_finish()


## Mean and worst frame time over --frames frames of the walk (the adult city).
## Mean and worst frame time over --frames frames of the walk (the adult city).
func _bench_frames(rampage: Rampage, city: CityView) -> void:
	var frames := 0
	while frames < 120 and not rampage.sim.over:  # settle
		await process_frame
		frames += 1
	var times: Array[float] = []
	var gpu: Array[float] = []
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var last := Time.get_ticks_usec()
	for i: int in _bench:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		last = now
		_maybe_fire(city, 99999)
	times.sort()
	var sum := 0.0
	for t: float in times:
		sum += t
	print(
		(
			"ONEL frame ms mean %.2f median %.2f p95 %.2f max %.2f (n=%d, today=%s, %s)"
			% [
				sum / times.size(),
				times[times.size() / 2],
				times[int(times.size() * 0.95)],
				times[times.size() - 1],
				times.size(),
				_today,
				_graphics
			]
		)
	)
	gpu.sort()
	var gsum := 0.0
	for g: float in gpu:
		gsum += g
	print(
		(
			"ONEL gpu ms mean %.3f median %.3f p95 %.3f max %.3f (n=%d)"
			% [
				gsum / gpu.size(),
				gpu[gpu.size() / 2],
				gpu[int(gpu.size() * 0.95)],
				gpu[gpu.size() - 1],
				gpu.size()
			]
		)
	)


## Autoplay's own rules (Rampage._autoplay_move); "record" logs the pick every 15 steps, "replay"
## walks that log, "idle" stands where it rose (after --face turns it).
func _scripted(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {}
	if _route_mode == "idle":
		_steps += 1
		return {"move": _face} if _steps <= _face_steps else {}
	var input := {}
	if _route_mode == "replay":
		var at: Array = _route[mini(_steps, _route.size() - 1)]
		input = {
			"move": Vector2(Num.f(at[0]), Num.f(at[1])),
			"signature": Num.f(at[2]) > 0.5,
			"held": Num.f(at[3]) > 0.5,
			"ultimate": Num.f(at[4]) > 0.5,
		}
	else:
		if _steps % 15 == 0 or _target.x == INF:
			_target = sim.nearest_standing(sim.kaiju_pos)
		var to := _target - sim.kaiju_pos
		var move := Vector2.ZERO
		if _target.x != INF and to.length() >= sim.stomp_radius() * 0.5:
			move = to.normalized()
		var sig := sim.ability_ready_in <= 0.0
		var held := _steps % Rampage.AUTOPLAY_GLIDE_CYCLE < Rampage.AUTOPLAY_GLIDE_HELD
		input = {"move": move, "signature": sig, "held": held, "ultimate": true}
		_route.append([move.x, move.y, 1.0 if sig else 0.0, 1.0 if held else 0.0, 1.0])
	_steps += 1
	return input


func _finish() -> void:
	if _route_mode == "record":
		var f := FileAccess.open(_route_file, FileAccess.WRITE)
		f.store_string(JSON.stringify(_route))
		f.close()
	quit()


func _fire_nodes(city: CityView) -> Array:
	var fires: Array = city.get("_fires")
	return fires


## Where each burning fire is on the saved image (for the 2x crops): "ONEL fire x y".
func _print_fires(city: CityView, size: Vector2i) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var fires := _fire_nodes(city)
	for f: Variant in fires:
		var node: Node3D = f
		var p := cam.unproject_position(node.global_position + Vector3(0, 2, 0))
		var scaled := p * Vector2(size) / root.get_visible_rect().size
		print("ONEL fire world %s image %s" % [node.global_position, scaled.round()])


func _maybe_fire(city: CityView, frames: int) -> void:
	if _fire_done or float(frames) < _fire.z * 60.0:
		return
	_fire_done = true
	var at := Vector3(_fire.x, 0.0, _fire.y)
	city.fire(at, _fire.w)
	print("ONEL fire placed at %s size %.2f" % [at, _fire.w])
