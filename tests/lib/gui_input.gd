extends RefCounted
## Real input for flow checks: a mouse click at a control's centre and key presses, pushed
## through the viewport and Input the way a player's would arrive, never a handler call.


## Left-clicks the centre of `control` (press, then release, as a mouse does).
static func click(tree: SceneTree, control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		tree.root.push_input(event, true)
		await tree.process_frame


## Drags the mouse across `control` from one fraction of its width to another, along its
## middle: press, move in steps, release (a slider's grabber follows like a player's drag).
static func drag(tree: SceneTree, control: Control, from: float, to: float) -> void:
	var rect := control.get_global_rect()
	var at := func(f: float) -> Vector2:
		return Vector2(rect.position.x + rect.size.x * f, rect.get_center().y)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at.call(from)
	press.global_position = press.position
	tree.root.push_input(press, true)
	await tree.process_frame
	for k: int in range(1, 6):
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.position = at.call(lerpf(from, to, k / 5.0))
		move.global_position = move.position
		tree.root.push_input(move, true)
		await tree.process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = at.call(to)
	release.global_position = release.position
	tree.root.push_input(release, true)
	await tree.process_frame


## Presses and releases a key (both its keycode and physical keycode, so UI actions and the
## game's physical-key actions both see it).
static func key(tree: SceneTree, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame


## Types `text` into whatever has focus, one key at a time the way a keyboard sends it (keycode
## and the character), so a TextEdit takes it as typing and the game sees the same keys.
static func type(tree: SceneTree, text: String) -> void:
	for i: int in text.length():
		var ch := text.substr(i, 1)
		var code: Key = KEY_SPACE if ch == " " else OS.find_keycode_from_string(ch.to_upper())
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.unicode = text.unicode_at(i)
			event.pressed = pressed
			Input.parse_input_event(event)
			await tree.process_frame


## Presses and releases a pad button (JOY_BUTTON_*) the way a controller sends it.
static func pad(tree: SceneTree, button_index: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button_index
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame


## Pushes a pad stick all the way along `axis` (JOY_AXIS_*) by `value` (-1..1) and lets go.
static func stick(tree: SceneTree, axis: JoyAxis, value: float) -> void:
	for amount: float in [value, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = amount
		Input.parse_input_event(event)
		await tree.process_frame


## The first visible Button under `node` whose text starts with `prefix`, or null.
static func button(node: Node, prefix: String) -> Button:
	for found: Node in node.find_children("*", "Button", true, false):
		var b: Button = found
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


## The first node under `node` (or `node` itself) whose script is `script`, or null.
static func find_script(node: Node, script: Script) -> Node:
	if node.get_script() == script:
		return node
	for child: Node in node.get_children():
		var hit := find_script(child, script)
		if hit != null:
			return hit
	return null
