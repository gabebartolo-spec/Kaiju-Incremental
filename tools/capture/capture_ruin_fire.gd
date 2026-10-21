extends SceneTree
## A still of a real autoplayed rampage (the flow test's city and seed) at a fixed tick, and the
## count of fires burning in the city then: the before/after for "rubble never burns" (#111,
## R 26.1). Needs a window and --fixed-fps 60 so the same tick is the same frame.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_ruin_fire.gd -- --species=reptilian --seconds=30 --out=dir

var _species := "reptilian"
var _seconds := 30.0
var _out := "user://ruin_fire"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
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
	await process_frame
	var burning := 0
	for node: Node in rampage.find_children("*", "Node3D", true, false):
		if node is Fire and not (node.has_method("is_out") and node.call("is_out")):
			burning += 1
	var ruined := 0
	for b: RampageSim.Building in rampage.sim.buildings:
		ruined += int(b.frame.alive_count == 0)
	DirAccess.make_dir_recursive_absolute(_out)
	var path := _out.path_join("ruin_fire_%s_t%d.png" % [_species, frames])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("RUIN_FIRE frames=%d burning=%d ruined=%d still=%s" % [frames, burning, ruined, path])
	quit()
