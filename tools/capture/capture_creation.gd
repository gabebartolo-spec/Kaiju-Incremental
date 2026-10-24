extends SceneTree
## Captures Kaiju Creation (D-207) through the real main scene by real input (keys and the pad,
## pushed the way a player's arrive): title -> New Kaiju -> the rack -> the croc genome poured
## into the dish -> the injection -> the takeover -> the black with the egg crack -> the run.
## Four stills (01_rack, 02_dish, 03_takeover, 04_black) and, with --write-movie, the whole
## sequence at game speed. Local GPU, off-screen no_focus override.cfg, fixed 60 fps:
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_creation.gd -- --out=<dir>
##   godot --path . --resolution 1920x1080 --windowed --write-movie <dir>/clip.avi \
##     --script tools/capture/capture_creation.gd -- --out=<dir> --clip

const Kit := preload("res://tools/capture/capture_kit.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE := 20
## Frames the rack is held before the pick, and the dish before the injection (the clip's beats).
const RACK_HOLD := 60
const DISH_HOLD := 40
## The takeover still is taken this far through the takeover.
const TAKEOVER_SHOT := 0.6
## Frames of the run shown after the lab (the clip ends on the loading screen's way in).
const AFTER := 20
const CAP := 60 * 30

var _out := "user://creation"
var _clip := false
var _main: Node


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--clip":
			_clip = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not Kit.window_ok():
		quit(1)
		return
	SaveFile.delete_save()
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await Kit.frames(self, SETTLE)
	await _key(KEY_ENTER)  # New Kaiju has the focus with no save
	await Kit.frames(self, SETTLE)
	var shown: Node = _main.call("screen")
	var lab := shown as KaijuCreation
	if lab == null:
		printerr("capture: New Kaiju did not open Kaiju Creation")
		quit(1)
		return
	await Kit.frames(self, RACK_HOLD)
	_shot("01_rack")
	await _key(KEY_ENTER)
	await _until(func() -> bool: return lab.step == KaijuCreation.Step.DISH)
	await Kit.frames(self, DISH_HOLD)
	_shot("02_dish")
	await _pad(JOY_BUTTON_A)
	await _until(func() -> bool: return lab.step == KaijuCreation.Step.TAKEOVER)
	var takeover := roundi(
		Num.f(Content.section("creation")["timing"]["takeover_s"]) * 60.0 * TAKEOVER_SHOT
	)
	await Kit.frames(self, takeover)
	_shot("03_takeover")
	await _until(func() -> bool: return lab.step == KaijuCreation.Step.BLACK)
	await Kit.frames(self, 2)
	_shot("04_black")
	print("CUES %s" % [lab.cues])
	await _until(func() -> bool: return _main.call("screen") is Rampage)
	await Kit.frames(self, AFTER)
	print("CREATION_CAPTURE done -> %s" % _out)
	quit(0)


func _shot(shot_name: String) -> void:
	if not _clip:
		print("still %s" % Kit.still(self, _out, shot_name))


func _until(done: Callable) -> void:
	for _i: int in CAP:
		if done.call() == true:
			return
		await process_frame


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
