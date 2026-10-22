extends SceneTree
## Look boards (director 2026-10-23: is the voxel look worth abandoning?): the same seeded rampage
## (city seed 0, the reptilian, the Behemoth body and its city, Medium preset, HUD on) under one
## look option, as stills or as a clip with --write-movie. Capture-only branch, never merged.
##   --look=today|one|smooth  (today = the branch tip; one = the ONE LOOK mock, pass "--one-look"
##                             after the options too; smooth = the Tripo croc, "--smooth-croc")
##   --time=dusk|noon   --stage=2 (STAGE_LEVELS index + 1)   --out=<dir>   --label=<name>
##   --stills=4,12 (seconds after the rise)   --seconds=6 --skip=9 (a clip: the whole run is
##   recorded; trim from the "risen at drawn frame" line + skip*60)
##   --route=idle|record|replay  --route-file=<json>  --face=x,z,steps  --cam=x,y,z
## Flags read from the command line by the game classes: --one-look, --smooth-croc.

const Kit := preload("res://tools/capture/capture_kit.gd")

var _out := "user://look_boards"
var _stills: Array[float] = [4.0]
var _seconds := 0.0
var _skip := 0.0
var _label := "today"
var _time := "dusk"
var _stage := 2
var _route_mode := "idle"
var _route_file := ""
var _route: Array = []
var _target := Vector2(INF, INF)
var _steps := 0
var _cam := Vector3.INF
var _face := Vector2.ZERO
var _face_steps := 0
## "--fire=x,z,at,size": the capture lights one ground fire at world (x, z) `at` seconds after the rise, the same in every option (the natural ones are tiny
## and hide in dust), so the fire can be compared: "fire placed by the capture".
var _fire := Vector4.ZERO
var _fire_done := true


func _initialize() -> void:
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
	PlayerSettings.graphics = "medium"  # the 4K default preset (D-109), whatever the screen is
	var species := Content.species_def("reptilian")
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[_stage - 1], "reptilian")
	var tier := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	Content.set_time(_time)
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
	print("LOOKB stream complete, buildings=%d, time=%s, tier=%d" % [rampage.sim.buildings.size(), _time, tier])
	rampage.set_physics_process(true)
	if _route_mode == "replay":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_route_file))
		if not parsed is Array:
			push_error("LOOKB no route at %s" % _route_file)
			quit(1)
			return
		_route = parsed
	rampage.scripted = _scripted
	while rampage.sim.emerge.active:
		await physics_frame
	print("LOOKB risen at drawn frame %d" % Engine.get_frames_drawn())
	var frames := 0
	if _seconds > 0.0:
		var total := int((_skip + _seconds) * 60.0)
		while frames < total and not rampage.sim.over:
			await physics_frame
			frames += 1
			_maybe_fire(rampage, city, frames)
		print("LOOKB clip end frame %d" % Engine.get_frames_drawn())
		_finish()
		return
	for at: float in _stills:
		while frames < int(at * 60.0) and not rampage.sim.over:
			await physics_frame
			frames += 1
			_maybe_fire(rampage, city, frames)
		for _i: int in 4:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		if image == null:
			print("LOOKB no image (headless) t=%d" % int(at))
			continue
		image.save_png("%s/%s_t%02d.png" % [_out, _label, int(at)])
		_print_fires(city, image.get_size())
		print("LOOKB kaiju at %s" % rampage.sim.kaiju_pos)
		print(
			(
				"LOOKB shot t=%d size=%s biomass=%s fires=%d"
				% [
					int(at),
					image.get_size(),
					str(rampage.sim.rubble),
					_fire_count(city)
				]
			)
		)
	_finish()


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


func _fire_count(city: CityView) -> int:
	var fires: Array = city.get("_fires")
	return fires.size()


## Where each burning fire is on the saved image (for the 2x crops): "LOOKB fire x y".
func _print_fires(city: CityView, size: Vector2i) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var fires: Array = city.get("_fires")
	for f: Variant in fires:
		var node: Node3D = f
		var p := cam.unproject_position(node.global_position + Vector3(0, 2, 0))
		var scaled := p * Vector2(size) / root.get_visible_rect().size
		print("LOOKB fire world %s image %s" % [node.global_position, scaled.round()])


func _maybe_fire(rampage: Rampage, city: CityView, frames: int) -> void:
	if _fire_done or float(frames) < _fire.z * 60.0:
		return
	_fire_done = true
	var at := Vector3(_fire.x, 0.0, _fire.y)
	city.fire(at, _fire.w)
	print("LOOKB fire placed at %s size %.2f" % [at, _fire.w])
