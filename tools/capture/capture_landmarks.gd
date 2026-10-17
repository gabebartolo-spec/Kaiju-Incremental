extends SceneTree
## Stills of every landmark in the Behemoth's city (city.landmarks), from the rampage's own
## camera with the kaiju beside it: standing, then after the kaiju has knocked out the floors on
## its side (the sim breaks the chunks and settles what falls; the city view draws it as in a
## rampage). Needs a window: run it on CI (tools/capture/ci_capture.sh --resolution=1920x1080
## capture_landmarks.gd -- --out=<dir>), or off-screen with the no_focus override.
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_landmarks.gd -- --out=<dir> [--tier=2]

const SETTLE := 4
const SPECIES := "reptilian"
## Rampage.CAMERA_OFFSET: the in-game camera, before its zoom by body scale.
const GAME_CAMERA := Vector3(0, 27, 19)
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1}
## Sim time stepped after the break, so every falling part has landed.
const FALL_SECONDS := 4.0
const DT := 1.0 / 30.0
## Floors knocked out on the kaiju's side, and how deep into the footprint.
const BREAK_FLOORS := 2
const BREAK_DEPTH := 0.5
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
		_break(n)
		await _frames(SETTLE * 3)
		_shot("%s_broken" % b.landmark)
		print(
			(
				"%s: %d of %d chunks standing after the break"
				% [b.landmark, b.frame.alive_count, b.w * b.d * b.height]
			)
		)
	quit()


## Knocks out the bottom floors of the half of the footprint facing the kaiju, then steps the sim
## until what lost its support has fallen, drawing every event as a rampage does.
func _break(n: int) -> void:
	var b := _sim.buildings[n]
	var cells: Array[Vector3i] = []
	for y: int in BREAK_FLOORS:
		for z: int in range(floori(b.d * (1.0 - BREAK_DEPTH)), b.d):
			for x: int in b.w:
				if b.frame.alive(Vector3i(x, y, z)):
					cells.append(Vector3i(x, y, z))
	_sim.damage_chunks(n, cells, 1.0e9)
	_apply(_sim.events)
	var t := 0.0
	while t < FALL_SECONDS:
		_apply(_sim.step(DT, Vector2.ZERO, false))
		t += DT
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
