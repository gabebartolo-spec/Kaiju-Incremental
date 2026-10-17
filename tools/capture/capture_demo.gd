extends SceneTree
## Captures the demo slice (D-050) through the real main scene by real input (mouse clicks pushed
## through the viewport, never a handler call): title -> New Kaiju -> species select (the demo's
## species only); then a played save one evolution away: title -> Continue -> click Behemoth ->
## the reveal plays out -> the demo end card, held while the adult roars. Render it on CI:
##   tools/capture/ci_capture.sh --resolution=1920x1080 capture_demo.gd
##   tools/capture/ci_capture.sh --movie --fps=30 --resolution=1920x1080 capture_demo.gd -- --clip

const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE := 12
## Frames the end card is held for the clip (3 s at the movie's 30 fps; 6 s at 60).
const HOLD_FRAMES := 180
## The end-card still is taken this far in, mid-roar.
const ROAR_SHOT_FRAME := 50

var _out := "user://demo"
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
	Engine.max_physics_steps_per_frame = 1
	SaveFile.delete_save()
	if not _clip:
		await _main_scene()
		_shot("01_title_new")
		await _click(_button(_screen(), "NEW KAIJU"))
		await _frames(SETTLE)
		_shot("02_species_select")
		_main.queue_free()
		await _frames(2)
	var save := SaveFile.new_save("reptilian")
	save["runs"] = 3
	save["rubble"] = UpgradeTree.new(Content.upgrades(), {}, "reptilian").cost("evolve1") + 20
	save["levels"] = {"claws": 2, "hide": 1, "rage": 1}
	SaveFile.save_game(save)
	await _main_scene()
	await _click(_button(_screen(), "CONTINUE"))
	await _frames(SETTLE)
	var tree := _screen() as UpgradeScreen
	await _click(tree.node_button("evolve1"))
	await _frames(EvolutionReveal.SWAP_FRAME + EvolutionReveal.GROW_FRAMES + 10)
	_shot("03_reveal")
	while _screen() == tree:
		await process_frame
	print("demo: end card is ", _screen_name())
	await _frames(ROAR_SHOT_FRAME)
	_shot("04_demo_end")
	await _frames(HOLD_FRAMES - ROAR_SHOT_FRAME)
	await _click(_button(_screen(), "TITLE"))
	await _frames(SETTLE)
	_shot("05_title_after")
	await _click(_button(_screen(), "CONTINUE"))
	await _frames(SETTLE)
	print("demo: Continue lands on ", _screen_name())
	_shot("06_continue_again")
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
