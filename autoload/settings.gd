extends Node
## Input actions (keyboard and controller) and display toggles.

const DEADZONE := 0.2


func _ready() -> void:
	_axis_action("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_axis_action("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_axis_action("move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_axis_action("move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_button_action("signature", [KEY_SPACE], JOY_BUTTON_A)
	_button_action("ultimate", [KEY_E], JOY_BUTTON_Y)
	_button_action("toggle_fullscreen", [KEY_F11], JOY_BUTTON_INVALID)
	# The shipped game starts fullscreen (D-027). Editor-binary runs (agent captures) stay windowed:
	# a project-wide fullscreen start defeats the off-screen no_focus override and grabs the screen.
	if OS.has_feature("template"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)


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
