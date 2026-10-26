extends SceneTree
## A clip of a real autoplayed rampage (the game's own Rampage: its camera, lead, head frame,
## shake and dip) walking into the towers: the ones between the camera and the kaiju are cut away
## by the camera bubble, and far buildings stream in. --stage=0 is the hatchling a new save
## plays (no upgrades, the flow test's city); 1-3 are the growth stages. --time picks the time of
## day ("" keeps the game's default). Prints the camera's numbers (distance, pitch, FOV) at
## --frame so a still can be checked against the player's run. Record it with --write-movie
## (local only off-screen with the no_focus override).
##   godot --path . --resolution 3840x2160 --windowed --write-movie out.avi --fixed-fps 30 \
##     --script tools/capture/capture_occlusion.gd -- [--stage=0] [--seconds=6] [--time=night]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
const FPS := 30.0

var _stage := 0
var _seconds := 6.0
var _time := "night"
var _frame := 60


func _initialize() -> void:
	var a := Kit.args({"stage": _stage, "seconds": _seconds, "time": _time, "frame": _frame})
	_stage = Num.i(a["stage"])
	_seconds = Num.f(a["seconds"])
	_time = str(a["time"])
	_frame = Num.i(a["frame"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _time != "":
		Content.set_time(_time)
	var rampage: Rampage
	if _stage == 0:
		rampage = Kit.autoplay(self, SPECIES, Kit.stats(SPECIES), 0)
	else:
		var stats := Kit.stats(SPECIES, Kit.STAGE_LEVELS[_stage - 1], SPECIES)
		var layout := CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0))
		rampage = Kit.autoplay(self, SPECIES, stats, 0, layout)
	await rampage.wait_loaded()
	var cam := Kit.game_camera(self)
	for f: int in roundi(_seconds * FPS):
		await process_frame
		if rampage.sim.over:
			break
		if f == _frame:
			var focus := Vector3(rampage.sim.kaiju_pos.x, 0.0, rampage.sim.kaiju_pos.y)
			var to := focus - cam.global_position
			print(
				(
					"CAMERA frame %d: dist %.1f pitch %.1f fov %.1f body %.2f"
					% [
						f,
						to.length(),
						rad_to_deg(atan2(-to.y, Vector2(to.x, to.z).length())),
						cam.fov,
						rampage.sim.body_scale()
					]
				)
			)
	quit()
