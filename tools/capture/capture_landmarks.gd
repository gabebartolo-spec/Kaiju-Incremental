extends SceneTree
## Stills of every landmark in the Behemoth's city (city.landmarks), from the rampage's own
## camera's angle with the kaiju beside it: standing, then after a short rampage into it (the
## sim breaks the chunks and settles what falls; the city view draws it as in a rampage). Needs
## a window: run it on CI (tools/capture/ci_capture.sh --resolution=1920x1080
## capture_landmarks.gd -- --out=<dir>), or off-screen with the no_focus override.
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_landmarks.gd -- --out=<dir> [--tier=2]

const SETTLE := 4
const SPECIES := "reptilian"
## Rampage.CAMERA_OFFSET: the in-game camera, before its zoom by body scale.
const GAME_CAMERA := Vector3(0, 27, 19)
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1}
## Sim time of the rampage into each landmark, and sim steps per drawn frame.
const RAMPAGE_SECONDS := 9.0
const STEPS_PER_FRAME := 3
const DT := 1.0 / 30.0
## Camera distance per unit of the landmark's largest size.
const FRAME := 1.7

var _out := "user://landmarks"
var _tier := 2
var _sim: RampageSim
var _city: CityView
var _kaiju_at := Vector3.ZERO


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--tier="):
			_tier = arg.substr(7).to_int()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def(SPECIES)
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS, SPECIES)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var tuning := CityGrowth.tuning_for(Content.tuning(), _tier)
	var layout := CityGrowth.layout(Content.tuning(), _tier, Seeds.make("city", 0))
	_sim = RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	_sim.time_left = 1.0e6
	var stage := Node3D.new()
	_city = CityView.new(_sim, Seeds.make("fx", 0))
	stage.add_child(_city)
	var colors: Dictionary = species["colors"]
	var kaiju := KaijuModel.new(SPECIES, colors, KaijuModel.stage_for(_sim.size_tier()))
	kaiju.scale = Vector3.ONE * _sim.body_scale()
	stage.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 4000.0
	stage.add_child(cam)
	root.add_child(stage)
	cam.current = true
	for n: int in _sim.buildings.size():
		var b := _sim.buildings[n]
		if b.landmark == "":
			continue
		# South of it, in the plaza by the kerb, facing it, as a player walking up would be.
		_kaiju_at = Vector3(b.x, 0, b.z + b.d * 0.5 + 2.0)
		_sim.kaiju_pos = Vector2(_kaiju_at.x, _kaiju_at.z)
		kaiju.position = _kaiju_at
		# The game camera's angle, centred on the landmark and backed off to frame all of it, so
		# the towers south of the plaza (faded in a rampage) do not hide it.
		var centre := Vector3(b.x, b.height * 0.3, b.z)
		var reach := maxf(maxf(b.w, b.d), b.height) * FRAME
		cam.position = centre + GAME_CAMERA.normalized() * reach
		cam.look_at(centre)
		await _frames(SETTLE)
		_shot("%s_standing" % b.landmark)
		await _break(n, kaiju)
		await _frames(SETTLE * 3)
		_shot("%s_broken" % b.landmark)
		print(
			(
				"%s: %d of %d chunks standing after the break"
				% [b.landmark, b.frame.alive_count, b.w * b.d * b.height]
			)
		)
	quit()


## A short rampage into it: the kaiju walks from the kerb toward the landmark's middle, stomping
## as it goes and using its signature whenever it is ready, the sim deciding what breaks and falls
## and the city view drawing every event as in a rampage. Several sim steps per drawn frame keep
## the software-rendered CI run short.
func _break(n: int, kaiju: Node3D) -> void:
	var b := _sim.buildings[n]
	var goal := Vector2(b.x, b.z)
	var t := 0.0
	while t < RAMPAGE_SECONDS:
		for _k: int in STEPS_PER_FRAME:
			var to := goal - _sim.kaiju_pos
			var move := to.normalized() if to.length() > 1.0 else Vector2.ZERO
			_apply(_sim.step(DT, move, _sim.ability_ready_in <= 0.0))
			t += DT
		_kaiju_at = Vector3(_sim.kaiju_pos.x, 0, _sim.kaiju_pos.y)
		kaiju.position = _kaiju_at
		await process_frame


func _apply(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		match str(event["type"]):
			"chunks_broken":
				var cells: Array[Vector3i] = event["cells"]
				_city.chunks_broken(Num.i(event["building"]), cells, _kaiju_at)
			"fall_start":
				_city.fall_start(event)
			"fall_land":
				_city.fall_land(event)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
