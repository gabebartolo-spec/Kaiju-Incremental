extends SceneTree
## The audio exit smoke run (debt list row 2, D-295): a sound is playing when the script quits, the way the
## demo run's last button press leaves one, and QuitGame.settle_audio lets the engine release it first.
## tools/lint/log_smoke.sh starts this script several times (the `audio` runs) and fails on any ERROR /
## WARNING / leak line in any log: an exit with a live sound leaks its stream and playbacks on some runs
## and not others (CI run 40443431942), so one run proves nothing and a few runs are the check.
##
##   godot --headless --fixed-fps 60 --path . --script tools/lint/log_smoke_audio.gd -- [--settle=0]
## --settle=0 quits without settling: the known-bad input that shows the checker red.

const Kit := preload("res://tools/capture/capture_kit.gd")
## Frames the sounds play before the script quits.
const PLAY_FRAMES := 3

var _settle := 1


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_settle = Num.i(Kit.args({"settle": _settle})["settle"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Sfx.ui("ui_confirm")  # the menu player the screens share, under the root
	var scene_sound := AudioStreamPlayer.new()  # and one a scene owns
	scene_sound.stream = load("res://assets/sfx/ui_click.ogg")
	root.add_child(scene_sound)
	scene_sound.play()
	await Kit.frames(self, PLAY_FRAMES)
	if _settle != 0:
		await QuitGame.settle_audio(self)
	print("LOG_SMOKE audio done")
	quit()
