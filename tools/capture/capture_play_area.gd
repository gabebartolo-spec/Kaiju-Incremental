extends SceneTree
## A clip of growth stage N's city at the game camera (D-254, the 1.5x play area): the real
## rampage (stage N's city and body, capture_kit STAGE_LEVELS), autoplayed from the rise, the
## controls card dismissed as a player's first key would. Record with --write-movie; the run
## quits after --seconds. Needs a window (the off-screen no_focus override.cfg).
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 --write-movie <out.avi> \
##     --script tools/capture/capture_play_area.gd -- --stage=3 --seconds=6

const Kit := preload("res://tools/capture/capture_kit.gd")

var _stage := 1
var _frames := 0
var _rampage: Rampage
var _hud: RampageHud


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"stage": 1, "seconds": 6.0})
	_stage = Num.i(a["stage"])
	_frames = roundi(Num.f(a["seconds"]) * Engine.get_physics_ticks_per_second())
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	var levels: Dictionary = Kit.STAGE_LEVELS[_stage - 1]
	var layout := CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0))
	var stats := Kit.stats("reptilian", levels, "reptilian")
	_rampage = Kit.autoplay(self, "reptilian", stats, 2, layout)
	for n: int in _frames:
		await process_frame
		if _hud == null:
			_hud = _find_hud(_rampage)
		if _hud != null and _hud.controls_card != null:
			_hud.dismiss_controls()
	print("play area clip: stage %d, %d frames" % [_stage, _frames])
	quit()


## The rampage's HUD: its first-run controls card goes as soon as it shows (as a first key).
func _find_hud(node: Node) -> RampageHud:
	for child: Node in node.get_children():
		if child is RampageHud:
			return child
		var found := _find_hud(child)
		if found != null:
			return found
	return null
