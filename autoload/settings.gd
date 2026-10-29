extends Node
## Input actions (keyboard and controller), the F11 toggle, and loading the player's settings
## at start (PlayerSettings, autoload/player_settings.gd, holds and saves them), and the frame cap
## each frame (PlayerSettings.frame_cap: lower in menus and pause).

const DEADZONE := 0.2
## Our faces draw Latin and Cyrillic; Chinese falls back to the Noto Sans SC subset (D-392,
## tools/fonts/subset_cjk.py). Loaded fonts are shared, so one fallback reaches every label.
const FONTS: Array[String] = [
	"res://assets/fonts/kaiju_block.ttf",
	"res://assets/fonts/kaiju_claw.ttf",
	"res://assets/fonts/kaiju_rubble.ttf",
	"res://assets/fonts/kaiju_fault.ttf",
]
const CJK_FONT := "res://assets/fonts/kaiju_cjk.ttf"

var _graphics := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_axis_action("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_axis_action("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_axis_action("move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_axis_action("move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_button_action("signature", [KEY_SPACE], JOY_BUTTON_A)
	_button_action("ultimate", [KEY_E], JOY_BUTTON_Y)
	_button_action("dash", [KEY_SHIFT], JOY_BUTTON_B)
	_button_action("pause", [KEY_ESCAPE, KEY_P], JOY_BUTTON_START)
	_button_action("toggle_fullscreen", [KEY_F11], JOY_BUTTON_INVALID)
	# Photo mode's own keys (PhotoMode, D-259): it moves on the move keys and turns on the mouse.
	_button_action("photo_rise", [KEY_E], JOY_BUTTON_RIGHT_SHOULDER)
	_button_action("photo_sink", [KEY_Q], JOY_BUTTON_LEFT_SHOULDER)
	_button_action("photo_hint", [KEY_H], JOY_BUTTON_X)
	_axis_action("photo_look_left", [], JOY_AXIS_RIGHT_X, -1.0)
	_axis_action("photo_look_right", [], JOY_AXIS_RIGHT_X, 1.0)
	_axis_action("photo_look_up", [], JOY_AXIS_RIGHT_Y, -1.0)
	_axis_action("photo_look_down", [], JOY_AXIS_RIGHT_Y, 1.0)
	# A confirms and B backs out in every menu (the Controls list says so): the engine's own menu
	# actions carry no pad A or B here (checked 2026-10-23: ui_accept and ui_cancel were keys only).
	_menu_pad("ui_accept", JOY_BUTTON_A)
	_menu_pad("ui_cancel", JOY_BUTTON_B)
	# The shipped game starts fullscreen (D-027). Editor-binary runs (agent captures) stay windowed:
	# a project-wide fullscreen start defeats the off-screen no_focus override and grabs the screen.
	var presets: Dictionary = Content.section("display")["graphics"]
	for problem: String in GraphicsPresets.errors(presets):
		push_error("tuning.json: " + problem)
	KeyBinds.snapshot()  # the defaults, before the player's own bindings go on top
	PlayerSettings.load_saved(OS.has_feature("template"))
	PlayerSettings.apply()
	PlayerSettings.apply_language()
	_cjk_fallback()


func _cjk_fallback() -> void:
	var cjk: Font = load(CJK_FONT)
	for path in FONTS:
		var font: Font = load(path)
		if not font.fallbacks.has(cjk):
			var list := font.fallbacks
			list.append(cjk)
			font.fallbacks = list


func _process(_delta: float) -> void:
	Engine.max_fps = PlayerSettings.frame_cap(get_tree().paused)
	var level := PlayerSettings.graphics_level()
	if level != _graphics:
		_graphics = level
		PlayerSettings.apply_graphics(get_tree().root)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		PlayerSettings.set_fullscreen(not PlayerSettings.fullscreen)


func _axis_action(action: String, keys: Array[Key], axis: JoyAxis, direction: float) -> void:
	_add_keys(action, keys)
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = direction
	InputMap.action_add_event(action, motion)


func _button_action(action: String, keys: Array[Key], button: JoyButton) -> void:
	_add_keys(action, keys)
	if button != JOY_BUTTON_INVALID:
		var press := InputEventJoypadButton.new()
		press.button_index = button
		InputMap.action_add_event(action, press)


func _menu_pad(action: String, button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button
	if not InputMap.action_has_event(action, press):
		InputMap.action_add_event(action, press)


func _add_keys(action: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
