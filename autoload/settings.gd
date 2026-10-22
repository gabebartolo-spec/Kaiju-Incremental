extends Node
## Input actions (keyboard and controller), the F11 toggle, and loading the player's settings
## at start (PlayerSettings, autoload/player_settings.gd, holds and saves them), and the frame cap
## each frame (PlayerSettings.frame_cap: lower in menus and pause).

const DEADZONE := 0.2

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
	_pad_menus()
	# The shipped game starts fullscreen (D-027). Editor-binary runs (agent captures) stay windowed:
	# a project-wide fullscreen start defeats the off-screen no_focus override and grabs the screen.
	var presets: Dictionary = Content.section("display")["graphics"]
	for problem: String in GraphicsPresets.errors(presets):
		push_error("tuning.json: " + problem)
	PlayerSettings.load_saved(OS.has_feature("template"))
	PlayerSettings.apply()


func _process(_delta: float) -> void:
	Engine.max_fps = PlayerSettings.frame_cap(get_tree().paused)
	var level := PlayerSettings.graphics_level()
	if level != _graphics:
		_graphics = level
		PlayerSettings.apply_graphics(get_tree().root)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		PlayerSettings.set_fullscreen(not PlayerSettings.fullscreen)


## The pad drives every menu: A accepts, B cancels, the d-pad moves focus. Added where the engine's
## own UI actions lack the pad button (a pad-only player could not press a focused button).
func _pad_menus() -> void:
	var buttons := {
		"ui_accept": JOY_BUTTON_A,
		"ui_cancel": JOY_BUTTON_B,
		"ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP,
		"ui_down": JOY_BUTTON_DPAD_DOWN,
	}
	for action: String in buttons:
		var button: JoyButton = buttons[action]
		var have := false
		for event: InputEvent in InputMap.action_get_events(action):
			var pad := event as InputEventJoypadButton
			have = have or (pad != null and pad.button_index == button)
		if not have:
			var press := InputEventJoypadButton.new()
			press.button_index = button
			InputMap.action_add_event(action, press)


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


func _add_keys(action: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
