extends SceneTree
## Captures the demo slice (D-050, D-145, D-156) through the real main scene by real input (mouse
## clicks pushed through the viewport, never a handler call): title -> New Kaiju -> Kaiju Creation
## (the croc genome only, D-207); then a save one level short of the whole tree: title ->
## Continue -> buy the last node -> the thanks screen, held while the adult roars -> Try Endless
## mode -> the endless city.
## Render a 4K still of the thanks screen locally (off-screen no_focus override.cfg):
##   godot --path . --resolution 3840x2160 --windowed --script tools/capture/capture_demo.gd \
##     -- --only=thanks --out=<dir>
## or on CI: tools/capture/ci_capture.sh --resolution=1920x1080 capture_demo.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE := 12
## Frames of autoplayed adult rampage before the clock is cut.
const AUTOPLAY_FRAMES := 300
## The totals the still shows (a stand-in for a ~2 h demo playthrough).
const TOTALS := {
	"biomass": 482310,
	"buildings": 1286,
	"eaten": 9740,
	"fled": 21365,
	"military": 413,
	"seconds": 7350
}
## Frames the end card is held for the clip (3 s at the movie's 30 fps; 6 s at 60).
const HOLD_FRAMES := 180
## The thanks still is taken this far in, mid-roar.
const ROAR_SHOT_FRAME := 50

var _out := "user://demo"
var _clip := false
var _only := ""
var _main: Node


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--clip":
			_clip = true
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Engine.max_physics_steps_per_frame = 1
	SaveFile.delete_save()
	if not _clip and _only == "":
		await _main_scene()
		_shot("01_title_new")
		await _click(_button(_screen(), "NEW KAIJU"))
		await _frames(SETTLE)
		_shot("02_kaiju_creation")
		_main.queue_free()
		await _frames(2)
	var defs: Array = Content.upgrades()
	var needed: Dictionary = {}
	for def: Dictionary in defs:
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			needed[req] = true
	var levels: Dictionary = {}
	var last := ""
	for def: Dictionary in defs:
		if def.has("species") and def["species"] != "reptilian":
			continue
		levels[str(def["id"])] = Num.i(def["max_level"])
		var effects: Dictionary = def.get("effects", {})
		if not needed.has(str(def["id"])) and not effects.has("size"):
			last = str(def["id"])
	levels[last] = Num.i(levels[last]) - 1
	var save := SaveFile.new_save("reptilian")
	save["demo"] = true
	save["runs"] = 3
	save["levels"] = levels
	save["rubble"] = UpgradeTree.new(defs, levels, "reptilian").cost(last) + 20
	save["totals"] = TOTALS
	SaveFile.save_game(save)
	await _main_scene()
	await _click(_button(_screen(), "CONTINUE"))
	await _frames(SETTLE)
	await _click((_screen() as UpgradeScreen).node_button(last))
	await _frames(SETTLE)
	print("demo: thanks screen is ", _screen_name())
	await _frames(ROAR_SHOT_FRAME)
	_shot("04_thanks")
	if _only == "thanks":
		SaveFile.delete_save()
		quit()
		return
	await _frames(HOLD_FRAMES - ROAR_SHOT_FRAME)
	await _click(_button(_screen(), "TRY ENDLESS MODE"))
	var endless := _screen() as Rampage
	await endless.wait_loaded()
	endless.set_autoplay(true)
	await _frames(AUTOPLAY_FRAMES)
	_shot("05_endless")
	SaveFile.delete_save()
	quit()


func _main_scene() -> void:
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(SETTLE)


func _screen() -> Node:
	return _main.call("screen")


func _screen_name() -> String:
	var script: Script = _screen().get_script()
	return script.get_global_name() if script != null else "?"


func _button(node: Node, prefix: String) -> Button:
	for found: Node in node.find_children("*", "Button", true, false):
		var b: Button = found
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	push_error("capture_demo: no button %s" % prefix)
	return null


## A left click at the control's centre, press then release, through the viewport.
func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path, " ", image.get_size())
