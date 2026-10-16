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
