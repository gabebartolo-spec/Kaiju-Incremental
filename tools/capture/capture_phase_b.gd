extends SceneTree
## Phase B decision boards (b2-19 voxel count, b2-20 abandon voxels): the same seeded rampage
## (city seed 0, the reptilian, the shipped look and camera) as stills, or as a clip when Godot is
## run with --write-movie. Waits for every building mesh (BuildingStream.complete) before the sim
## is allowed to move, so no box stand-ins are in the shot. Stills are seconds after the kaiju has
## risen from the river. Not for merge: a capture tool for a decision.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_phase_b.gd -- --stills=1,8,14 --out=<dir> --label=today \
##     --route=record|replay --route-file=<json>
##   (a clip: add --write-movie <dir>/clip.avi, --seconds=8 and --skip=<s>; the whole run is
##    recorded, trim with ffmpeg from the "risen at drawn frame" line plus skip)

var _out := "user://phase_b"
var _stills: Array[float] = [1.0, 8.0, 14.0]
var _seconds := 0.0
var _skip := 0.0
var _label := ""
## The kaiju's route, so every voxel density gets the same shot: "record" logs what autoplay's
## nearest-standing-building rule picks (every 15 steps) to --route-file; "replay" walks that log.
var _route_mode := ""
var _route_file := ""
var _route: Array = []
var _target := Vector2(INF, INF)
var _steps := 0
var _cam := Vector3.INF  ## a closer camera rest offset (the game's is in data/tuning.json "camera")


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
		elif arg.begins_with("--cam="):
			var p := arg.substr(6).split(",")
			_cam = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif arg.begins_with("--label="):
			_label = arg.substr(8)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	var rampage := Rampage.new()
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	if _cam != Vector3.INF:
		rampage.camera_rest = _cam
	# The sim stays still while the buildings mesh (a bigger voxel count takes longer), so every
	# option reaches the same sim tick at the same frame.
	root.add_child(rampage)
	rampage.set_physics_process(false)  # after _ready, which switches it on
	var city: CityView = rampage.get("_city")
	var stream: BuildingStream = city.get("_stream")
	while not stream.complete():
		await process_frame
	for _i: int in 10:
		await process_frame
	print("PHASEB stream complete, buildings=%d" % rampage.sim.buildings.size())
	rampage.set_physics_process(true)
	if _route_mode == "replay":
		_route = JSON.parse_string(FileAccess.get_file_as_string(_route_file))
	if _route_mode != "":
		rampage.scripted = _scripted
	else:
		rampage.set_autoplay(true)
	while rampage.sim.emerge.active:
		await physics_frame
	print("PHASEB risen at drawn frame %d" % Engine.get_frames_drawn())
	var frames := 0
	if _seconds > 0.0:
		var total := int((_skip + _seconds) * 60.0)
		while frames < total and not rampage.sim.over:
			await physics_frame
			frames += 1
		_finish()
		return
	for at: float in _stills:
		while frames < int(at * 60.0) and not rampage.sim.over:
			await physics_frame
			frames += 1
		for _i: int in 3:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s/%s_t%02d.png" % [_out, _label, int(at)])
		print("PHASEB shot t=%d" % int(at))
	_finish()


## Autoplay's own rules (Rampage._autoplay_move), but the target of each 15 steps comes from the
## recorded route in "replay", so a different voxel density cannot send the kaiju elsewhere.
func _scripted(sim: RampageSim) -> Dictionary:
	if sim.emerge.active or _route_mode == "idle":
		return {}  # idle: the kaiju stands where it rose and nothing is broken
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
