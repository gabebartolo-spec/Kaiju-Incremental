extends SceneTree
## Captures the title's save slots as the player finds them: real saves written to slots 1 and 3
## (slot 2 empty), the game's own Main opened, CONTINUE clicked, the burning city given time to
## stand, then the still. With --delete, DELETE on slot 1 is clicked too (the "are you sure?").
## Local GPU, off-screen no_focus override.cfg, its own APPDATA:
##   godot --path . --windowed --resolution 3840x2160 --script tools/capture/capture_slots.gd -- \
##     --out=<dir> [--size=3840x2160] [--delete]

const CaptureKit := preload("res://tools/capture/capture_kit.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const MAX_WAIT_MS := 60000
const AFTER_SHOWN := 1.5
const OFF_SCREEN_X := -12000

var _out := "user://slots"
var _size := Vector2i.ZERO
var _delete := false


func _initialize() -> void:
	DisplayServer.window_set_position(Vector2i(OFF_SCREEN_X, 0))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--size="):
			var wh := arg.substr(7)
			_size = Vector2i(int(wh.get_slice("x", 0)), int(wh.get_slice("x", 1)))
		elif arg == "--delete":
			_delete = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	if not CaptureKit.window_ok():
		quit(1)
		return
	if _size != Vector2i.ZERO:
		await _tick()
		root.size = _size
		await _tick()
	SaveFile.wipe()
	var played := SaveFile.new_save("reptilian")
	played["runs"] = 7
	played["rubble"] = 1240
	played["specimen"] = 3
	played["demo"] = Demo.enabled()
	SaveFile.save_game(played, 1)
	var fresh := SaveFile.new_save("reptilian")
	fresh["runs"] = 1
	fresh["rubble"] = 85
	fresh["demo"] = Demo.enabled()
	SaveFile.save_game(fresh, 3)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	await _tick()
	await _tick()
	var shown: Node = main.call("screen")
	var title := shown as TitleScreen
	var backdrops := title.find_children("*", "TitleBackdrop", true, false)
	var t0 := Time.get_ticks_msec()
	while (
		not backdrops.is_empty()
		and not (backdrops[0] as TitleBackdrop).is_loaded
		and Time.get_ticks_msec() - t0 < MAX_WAIT_MS
	):
		await _tick()
	_press(title, "CONTINUE")
	await _tick()
	if _delete:
		(title.slot_list().find_child("Delete1", true, false) as Button).pressed.emit()
	var until := Time.get_ticks_msec() + int(AFTER_SHOWN * 1000.0)
	while Time.get_ticks_msec() < until:
		await _tick()
	var file := "slots_delete.png" if _delete else "slots.png"
	root.get_texture().get_image().save_png(_out.path_join(file))
	print("saved ", file, " at ", root.size)
	SaveFile.wipe()
	quit()


func _press(node: Node, prefix: String) -> void:
	for found: Node in node.find_children("*", "Button", true, false):
		var b: Button = found
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			b.pressed.emit()
			return
	push_error("capture_slots: no button %s" % prefix)


func _tick() -> void:
	await process_frame
