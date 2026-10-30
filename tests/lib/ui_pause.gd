extends RefCounted
## The UI suite's pause menu and shared highlight checks (split out of run_ui_tests.gd to keep
## files small).

## The UI canvas (project.godot, D-027): every check measures in its logical pixels.
const CANVAS := Vector2i(1920, 1080)


## Critic r1 item 5: every pause button's label clears its edges by 40 px or more, the End
## Rampage button says only "END RAMPAGE", with its note on a line of its own.
static func pause(tree: SceneTree, check: Callable) -> void:
	var window := tree.root.size
	tree.root.size = CANVAS
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	await tree.process_frame
	await tree.process_frame
	var tight: Array[String] = []
	var names: Array[String] = []
	for node: Node in menu.find_children("*", "Button", true, false):
		var b: Button = node
		names.append(b.text)
		if b.size.x - b.get_minimum_size().x < 40.0:
			tight.append("%s (%.0f of %.0f)" % [b.text, b.get_minimum_size().x, b.size.x])
	var notes: Array[String] = []
	for node: Node in menu.find_children("*", "Label", true, false):
		notes.append((node as Label).text)
	check.call(tight.is_empty(), "pause labels clear their button edges by 40 px: %s" % [tight])
	check.call(names.has("END RAMPAGE"), "the End Rampage button says END RAMPAGE: %s" % [names])
	check.call(
		notes.any(func(t: String) -> bool: return t.to_lower().contains("biomass")),
		"a small note line says the biomass is kept: %s" % [notes]
	)
	menu.free()
	await tree.process_frame
	tree.root.size = window


## Director 2026-10-22: the mouse and the keyboard share one highlight, so two buttons are never
## lit at once (the title showed CONTINUE focused and SETTINGS hovered, both yellow).
static func hover_focus(tree: SceneTree, check: Callable) -> void:
	var box := VBoxContainer.new()
	var first := UiKit.button("FIRST")
	var second := UiKit.button("SECOND")
	box.add_child(first)
	box.add_child(second)
	tree.root.add_child(box)
	await tree.process_frame
	first.grab_focus()
	second.mouse_entered.emit()
	check.call(
		second.has_focus() and not first.has_focus(), "hovering a button moves the focus onto it"
	)
	var off := UiKit.button("OFF")
	off.disabled = true
	box.add_child(off)
	await tree.process_frame
	off.mouse_entered.emit()
	check.call(second.has_focus(), "hovering a disabled button leaves the focus where it was")
	box.free()
	await tree.process_frame
