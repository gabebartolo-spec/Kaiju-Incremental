extends SceneTree
## A clip of the Apex Titan walking north from the city's south edge into the towers, seen
## from the rampage's own camera (Rampage.CAMERA_OFFSET, zoomed by body scale): towers between
## the camera and the kaiju fade to a screen door (BuildingFade, D-025), and far buildings
## stream in (BuildingStream). Record it with --write-movie (CI: ci_capture.sh --movie; local
## only off-screen with the no_focus override). --stage=N picks another stage.
##   godot --path . --resolution 1280x720 --windowed --write-movie out.avi --fixed-fps 30 \
##     --script tools/capture/capture_occlusion.gd -- [--stage=4] [--seconds=20]

const SPECIES := "reptilian"
const GAME_CAMERA := Vector3(0, 27, 19)  # Rampage.CAMERA_OFFSET
const FPS := 30.0
const WALK_SPEED := 9.0  # sim units a second: a steady stride up the street
const STREET_X := 5.0  # a north-south street line of the plan (CityGen.map xs)
## The upgrades a kaiju of each stage owns (as capture_growth.gd).
const LEVELS: Array[Dictionary] = [
	{"claws": 2, "hide": 2},
	{"claws": 5, "hide": 5, "rage": 3, "evolve1": 1},
	{"claws": 5, "hide": 5, "rage": 5, "evolve1": 1, "tail": 3, "sig_power": 3, "evolve2": 1},
	{
		"claws": 5,
		"hide": 5,
		"rage": 5,
		"evolve1": 1,
		"tail": 5,
		"sig_power": 5,
		"evolve2": 1,
		"apex_claws": 3,
		"sig_reach": 2,
		"evolve3": 1
	},
]

var _stage := 4
var _seconds := 20.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = arg.substr(8).to_int()
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def(SPECIES)
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS[_stage - 1], SPECIES)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	var stage := Node3D.new()
	var started := Time.get_ticks_msec()
	stage.add_child(CityView.new(sim, Seeds.make("fx", 0)))
	var colors: Dictionary = species["colors"]
	var kaiju := KaijuModel.new(SPECIES, colors, KaijuModel.stage_for(sim.size_tier()))
	var scale := sim.body_scale()
	kaiju.scale = Vector3.ONE * scale
	stage.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = 55.0
	stage.add_child(cam)
	root.add_child(stage)
	cam.current = true
	print("stage %d loaded in %d ms" % [_stage, Time.get_ticks_msec() - started])
	sim.kaiju_pos.x = STREET_X  # walk up a street, not through the blocks
	var zoom := 0.75 + 0.4 * scale
	var frames := roundi(_seconds * FPS)
	for f: int in frames:
		var dt := 1.0 / FPS
		sim.kaiju_pos += Vector2(0, -WALK_SPEED * dt)
		var at := Vector3(sim.kaiju_pos.x, 0, sim.kaiju_pos.y)
		kaiju.position = at
		kaiju.animate(dt, 1.0)
		cam.position = at + GAME_CAMERA * zoom
		cam.look_at(at + Vector3(0, 3.5 * scale, 0))
		await process_frame
	quit()
