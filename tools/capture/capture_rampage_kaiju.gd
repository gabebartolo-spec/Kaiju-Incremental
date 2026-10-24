extends SceneTree
## Records a real autoplayed rampage (the flow test's city and seed) for one species, so its
## locomotion is seen among buildings: the cephalopod gripping building edges, every species
## stomping and turning at the gameplay camera. Needs a window and --write-movie.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_rampage_kaiju.gd -- --species=cephalopod --seconds=12

const Kit := preload("res://tools/capture/capture_kit.gd")

var _species := "cephalopod"
var _seconds := 12.0


func _initialize() -> void:
	var a := Kit.args({"species": _species, "seconds": _seconds})
	_species = str(a["species"])
	_seconds = Num.f(a["seconds"])
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
	quit()
