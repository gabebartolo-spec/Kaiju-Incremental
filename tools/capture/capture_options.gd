extends SceneTree
## Captures the options pages (D-259) through the real main scene and real input: the title gear
## opens Settings (shot), CONTROLS (shot), a click on the signature attack's key waits (shot),
## R binds it (shot), Esc back, ACCESSIBILITY (shot), each button clicked once (shot). Bindings
## and settings go back to the defaults at the end. Render it at 3840x2160 off screen (the
## no_focus override.cfg plus window/size/borderless=true), never in a window that takes focus.
##
##   godot --path . --script tools/capture/capture_options.gd -- --out=<dir>

const GuiInput := preload("res://tests/lib/gui_input.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE := 12
const SHOT_SIZE := Vector2i(3840, 2160)

var _out := "user://options"
var _main: Node


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.size = SHOT_SIZE
	await _frames(2)
	KeyBinds.reset()
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(SETTLE)
	var title: Node = _main.call("screen")
	await GuiInput.click(self, title.find_child("Gear", true, false) as Button)
	await _frames(SETTLE)
	_shot("options_settings")
	var menu := GuiInput.find_script(title, SettingsMenu) as SettingsMenu
	await GuiInput.click(self, GuiInput.button(menu, "CONTROLS"))
	await _frames(SETTLE)
	_shot("options_controls")
	var page := menu.page as ControlsMenu
	var sig: Button = page.binds["signature"][KeyBinds.KEYS]
	await GuiInput.click(self, sig)
	await _frames(SETTLE)
	_shot("options_controls_waiting")
	await GuiInput.key(self, KEY_R)
	await _frames(SETTLE)
	_shot("options_controls_rebound")
	await GuiInput.key(self, KEY_ESCAPE)
	await _frames(4)
	await GuiInput.click(self, GuiInput.button(menu, "ACCESSIBILITY"))
	await _frames(SETTLE)
	_shot("options_accessibility")
	var access := menu.page as AccessMenu
	for b: Button in [access.held, access.flashing, access.rumble, access.gore]:
		await GuiInput.click(self, b)
	await _frames(SETTLE)
	_shot("options_accessibility_changed")
	for b: Button in [access.held, access.flashing, access.rumble, access.gore]:
		await GuiInput.click(self, b)
	KeyBinds.reset()
	quit()


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path, " ", image.get_size())
	if image.get_size() != SHOT_SIZE:
		push_error("shot is %s, not %s" % [image.get_size(), SHOT_SIZE])
