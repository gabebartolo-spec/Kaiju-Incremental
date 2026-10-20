extends SceneTree
## Phase B decision boards (b2-19 voxel count, b2-20 abandon voxels): the same seeded, autoplayed
## rampage (city seed 0, the reptilian, the shipped look and camera) as stills, or as a clip when
## Godot is run with --write-movie. Waits for every building mesh (BuildingStream.complete) before
## the sim is allowed to move, so no box stand-ins are in the shot. Stills are seconds after the
## kaiju has risen from the river. Not for merge: a capture tool for a decision.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_phase_b.gd -- --stills=1,8,14 --out=<dir> [--seconds=8]
##   (a clip: add --write-movie <dir>/clip.avi and --seconds=8; the clip starts at --skip seconds)

var _out := "user://phase_b"
var _stills: Array[float] = [1.0, 8.0, 14.0]
var _seconds := 0.0
var _skip := 0.0
var _label := ""


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
	root.add_child(rampage)
	var city: CityView = rampage.get("_city")
	var stream: BuildingStream = city.get("_stream")
	while not stream.complete():
		await process_frame
	for _i: int in 10:
		await process_frame
	print("PHASEB stream complete, buildings=%d" % rampage.sim.buildings.size())
	rampage.set_autoplay(true)
	while rampage.sim.emerge.active:
		await physics_frame
	print("PHASEB risen at drawn frame %d" % Engine.get_frames_drawn())
	var frames := 0
	if _seconds > 0.0:
		# A clip: run to _skip, then the movie writer is already recording the whole run, so just
		# play out _skip + _seconds.
		var total := int((_skip + _seconds) * 60.0)
		while frames < total and not rampage.sim.over:
			await physics_frame
			frames += 1
		quit()
		return
	for at: float in _stills:
		while frames < int(at * 60.0) and not rampage.sim.over:
			await physics_frame
			frames += 1
		for _i: int in 3:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s/%s_t%02d.png" % [_out, _label, int(at)])
		print("PHASEB shot t=%d alive=%d" % [int(at), rampage.sim.buildings.size()])
	quit()
