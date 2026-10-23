extends SceneTree
## Records a real autoplayed rampage (the flow test's city and seed) for one species, so its
## locomotion is seen among buildings: the cephalopod gripping building edges, every species
## stomping and turning at the gameplay camera. Needs a window and --write-movie.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_rampage_kaiju.gd -- --species=cephalopod --seconds=12
## --stage=N (0 baby, 1 adolescent, 2 adult; default -1: no upgrades) gives the kaiju that growth
## stage's body (Kit.STAGE_LEVELS).

const Kit := preload("res://tools/capture/capture_kit.gd")

var _species := "cephalopod"
var _seconds := 12.0
var _stage := -1


func _initialize() -> void:
	var a := Kit.args({"species": _species, "seconds": _seconds, "stage": _stage})
	_species = str(a["species"])
	_seconds = Num.f(a["seconds"])
	_stage = Num.i(a["stage"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[_stage] if _stage >= 0 else {}
	var rampage := Kit.autoplay(self, _species, Kit.stats(_species, levels), 0)
	var frames := 0
	while frames < int(_seconds * 60.0) and not rampage.sim.over:
		await physics_frame
		frames += 1
	quit()
