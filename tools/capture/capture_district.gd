extends SceneTree
## Captures a real district (D-029) for review: the gameplay camera at the start and mid-rampage
## (autoplayed, real sim), then from high above (straight down over the playable rect, to lay
## beside an OpenStreetMap render) and an aerial three-quarter view. Needs a window; run with an
## untracked override.cfg that sets no_focus and an off-screen position.
##
##   APPDATA=<scratch> godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_district.gd -- --out=<dir> --district=melbourne_cbd

const SETTLE := 30

var _out := "user://district"
var _district := "melbourne_cbd"
var _mid_seconds := 6


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--district="):
			_district = arg.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Content.set_district(_district)
	var species := Content.species_def("reptilian")
	var levels := {"claws": 2, "hide": 2}
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var city := Content.section("city")
	var rampage := Rampage.new()
	rampage.setup(species, stats, CitySource.buildings(Seeds.make("city", 0), city), 1)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	await _frames(SETTLE)
	var play := CitySource.play(city)
	var game_camera := root.get_viewport().get_camera_3d()
	# Overview shots look through hundreds of units of air: no fog, so the map reads.
	var env: Environment = null
	for node: Node in root.find_children("*", "WorldEnvironment", true, false):
		env = (node as WorldEnvironment).environment
	var fog := env.fog_enabled
	env.fog_enabled = false
	var top := Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = play.size.x * 1.04
	top.keep_aspect = Camera3D.KEEP_WIDTH
	top.far = 600.0
	rampage.add_child(top)
	top.position = Vector3(play.get_center().x, 300.0, play.get_center().y)
	top.rotation_degrees = Vector3(-90, 0, 0)
	top.current = true
	await _frames(4)
	_shot("1_top_down")
	var aerial := Camera3D.new()
	aerial.fov = 50.0
	aerial.far = 1200.0
	rampage.add_child(aerial)
	aerial.position = Vector3(play.position.x - 20.0, 110.0, play.end.y + 90.0)
	aerial.look_at(Vector3(play.get_center().x, 0.0, play.get_center().y))
	aerial.current = true
	await _frames(4)
	_shot("2_aerial")
	env.fog_enabled = fog
	game_camera.current = true
	await _frames(4)
	_shot("3_gameplay_start")
	await _frames(60 * _mid_seconds)
	_shot("4_gameplay_mid")
	quit()


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := _out.path_join("%s_%s.png" % [_district, shot_name])
	image.save_png(path)
	print("saved ", path)
