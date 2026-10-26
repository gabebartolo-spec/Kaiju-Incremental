extends SceneTree
## Captures Kaiju Creation (D-207) through the real main scene by real input (keys and the pad,
## pushed the way a player's arrive): title -> New Kaiju -> the rack -> the injector draws the
## croc genome and puts it in the dish -> the injection -> the takeover -> the black with the egg
## crack -> the run. Five stills (01_rack, 02_draw, 03_dish, 04_takeover, 05_black) and, with
## --write-movie, the whole sequence at game speed. Local GPU, off-screen no_focus override.cfg,
## fixed 60 fps:
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_creation.gd -- --out=<dir>
##   godot --path . --resolution 1920x1080 --windowed --write-movie <dir>/clip.avi \
##     --script tools/capture/capture_creation.gd -- --out=<dir> --clip
## --titan=<id> captures that genome's sequence instead of the croc's (the director 2026-10-25:
## "ensure the clip is functional for all 3"). A locked genome is unlocked for the capture only,
## and one with no kaiju to play yet plays the croc's (reptilian) run after the black.

const Kit := preload("res://tools/capture/capture_kit.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE := 20
## Frames the rack is held before the pick, and the dish before the injection (the clip's beats).
const RACK_HOLD := 30
const DISH_HOLD := 25
## The takeover still is taken this far through the takeover, the draw still this far through
## the injector's trip to the vial (the needle down in it).
const TAKEOVER_SHOT := 0.4
const DRAW_SHOT := 0.42
## Frames of the run shown after the lab: 3 s, so the clip shows the river rise opening the run.
const AFTER := 180
const CAP := 60 * 30

var _out := "user://creation"
var _clip := false
var _titan := "croc"
var _main: Node


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--clip":
			_clip = true
		elif arg.begins_with("--titan="):
			_titan = arg.substr(8)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not Kit.window_ok():
		quit(1)
		return
	SaveFile.delete_save()
	var down := _open_titan()
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
	for _i: int in down:
		await _key(KEY_DOWN)
	await Kit.frames(self, RACK_HOLD)
	_shot("01_rack")
	await _key(KEY_ENTER)
	await Kit.frames(self, _ticks("place_s", DRAW_SHOT))
	_shot("02_draw")
	await _until(func() -> bool: return lab.step == KaijuCreation.Step.DISH)
	await Kit.frames(self, DISH_HOLD)
	_shot("03_dish")
	await _pad(JOY_BUTTON_A)
	await Kit.frames(self, _ticks("inject_s", DRAW_SHOT))
	_shot("03b_canister")
	await _until(func() -> bool: return lab.step == KaijuCreation.Step.TAKEOVER)
	await Kit.frames(self, _ticks("takeover_s", TAKEOVER_SHOT))
	_shot("04_takeover")
	await _until(func() -> bool: return lab.step == KaijuCreation.Step.BLACK)
	await Kit.frames(self, 2)
	_shot("05_black")
	print("CUES %s" % [lab.cues])
	await _until(func() -> bool: return _main.call("screen") is Rampage)
	await Kit.frames(self, AFTER)
	print("CREATION_CAPTURE done -> %s" % _out)
	quit(0)


## Unlocks the captured genome in the loaded data (this process only) and gives one with no kaiju
## yet the croc's species; returns how many presses of Down move the rack's focus onto it.
func _open_titan() -> int:
	var rows: Array = Content.section("creation")["titans"]
	var down := 0
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		if str(row["id"]) != _titan:
			continue
		row["unlocked"] = true
		if str(row["species"]) == "":
			row["species"] = "reptilian"
		for j: int in i:
			var before: Dictionary = rows[j]
			if before["unlocked"] == true and str(before["species"]) != "":
				down += 1
	return down


## Frames to `share` of a timing step (tuning "creation" "timing" `key`).
func _ticks(key: String, share: float) -> int:
	return roundi(Num.f(Content.section("creation")["timing"][key]) * 60.0 * share)


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
