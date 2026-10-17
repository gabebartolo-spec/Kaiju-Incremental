extends SceneTree
## Records a real autoplayed rampage (the flow test's city and seed) for one species, so its
## locomotion is seen among buildings: the cephalopod gripping building edges, every species
## stomping and turning at the gameplay camera. Needs a window and --write-movie.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_rampage_kaiju.gd -- --species=cephalopod --seconds=12

var _species := "cephalopod"
var _seconds := 12.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rampage := Rampage.new()
	var species := Content.species_def(_species)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	var frames := 0
	while frames < int(_seconds * 60.0) and not rampage.sim.over:
		await physics_frame
		frames += 1
	quit()
