extends SceneTree
## Camera framing options (build2-7, "the camera doesnt let us see much of the city"): the same
## seeded, autoplayed rampage (city seed 0, the reptilian) with the gameplay camera's rest offset
## and FOV overridden, saving stills once the kaiju has risen from the river. Add --write-movie
## for a clip of the same run.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_framing.gd -- --offset=0,27,19 --fov=55 --out=<dir>

var _offset := Vector3.INF
var _fov := 0.0
var _seconds := 20.0
var _out := "user://framing"
var _stills: Array[float] = [4.0, 9.0, 14.0, 19.0]


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--offset="):
			var p := arg.substr(9).split(",")
			_offset = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif arg.begins_with("--fov="):
			_fov = float(arg.substr(6))
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
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
	if _offset != Vector3.INF:
		rampage.camera_rest = _offset
	if _fov > 0.0:
		rampage.camera_fov = _fov
	rampage.set_autoplay(true)
	root.add_child(rampage)
	while rampage.sim.emerge.active:
		await physics_frame
	var frames := 0
	var next := 0
	while frames < int(_seconds * 60.0) and not rampage.sim.over:
		await physics_frame
		frames += 1
		if next < _stills.size() and frames >= int(_stills[next] * 60.0):
			await process_frame
			var image := root.get_viewport().get_texture().get_image()
			image.save_png("%s/t%02d.png" % [_out, int(_stills[next])])
			next += 1
	quit()
