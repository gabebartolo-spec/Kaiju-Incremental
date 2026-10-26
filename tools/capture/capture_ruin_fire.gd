extends SceneTree
## A still of a real autoplayed rampage (the flow test's city and seed) at a fixed tick, and the
## count of fires burning in the city then: the before/after for "rubble never burns" (#111,
## R 26.1). Needs a window and --fixed-fps 60 so the same tick is the same frame.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_ruin_fire.gd -- --species=reptilian --seconds=30 --out=dir

const Kit := preload("res://tools/capture/capture_kit.gd")

var _species := "reptilian"
var _seconds := 30.0
var _out := "user://ruin_fire"


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"species": _species, "seconds": _seconds, "out": _out})
	_species = str(a["species"])
	_seconds = Num.f(a["seconds"])
	_out = str(a["out"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rampage := Kit.autoplay(self, _species, Kit.stats(_species), 0)
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
	var path := Kit.still(self, _out, "ruin_fire_%s_t%d" % [_species, frames])
	print("RUIN_FIRE frames=%d burning=%d ruined=%d still=%s" % [frames, burning, ruined, path])
	quit()
