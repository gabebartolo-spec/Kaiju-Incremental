extends RefCounted
## The bug / feedback panel on a gamepad alone (director D-153): joypad events only, no mouse and no
## key. A pad walks the pause menu to the report button, opens the panel, moves between the text
## box, SEND, CANCEL and OPEN FOLDER, sends, and backs out with B. Focus is read from the viewport,
## so a control that cannot be reached fails by name.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const UiFeedback := preload("res://tests/lib/ui_feedback.gd")


static func run(tree: SceneTree, check: Callable) -> void:
	var menu := PauseMenu.new()
	menu.sim = UiFeedback.played_sim()
	menu.species_id = "reptilian"
	tree.root.add_child(menu)
	tree.paused = true
	await UiFeedback.frames(tree, 3)
	var label := str(Content.section("feedback")["label"])
	var report := GuiInput.button(menu, label)
	var before := UiFeedback.reports().size()
	check.call(_on(tree, GuiInput.button(menu, "RESUME")), "pad: the pause menu opens on RESUME")
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_DOWN)
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_DOWN)
	check.call(_on(tree, report), "pad: down, down reaches the report button")
	var panel := await _press_a(tree, menu)
	check.call(
		panel != null and _on(tree, panel.box) and tree.paused,
		(
			"pad: A on the report button opens the panel with focus in its box, still paused (%s)"
			% [str(panel) + " " + _who(tree)]
		)
	)
	if panel == null:
		menu.queue_free()
		tree.paused = false
		return
	var send := GuiInput.button(panel, "SEND")
	var cancel := GuiInput.button(panel, "CANCEL")
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_DOWN)
	check.call(_on(tree, send), "pad: down from the box reaches SEND")
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_UP)
	check.call(_on(tree, panel.box), "pad: up from SEND returns to the box")
	await GuiInput.pad(tree, JOY_BUTTON_A)
	check.call(_on(tree, send), "pad: A in the box reaches SEND")
	await GuiInput.stick(tree, JOY_AXIS_LEFT_X, 1.0)
	check.call(_on(tree, cancel), "pad: the stick right reaches CANCEL")
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_LEFT)
	check.call(_on(tree, send), "pad: left returns to SEND")
	var opened: Array[String] = []
	panel.opener = func(path: String) -> int:
		opened.append(path)
		return OK
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 3)
	var problems := UiFeedback.problems(panel.report_path, "")
	check.call(
		UiFeedback.reports().size() == before + 1 and problems.is_empty(),
		"pad: A on SEND writes a good report (%s)" % [problems]
	)
	var open := GuiInput.button(panel, "OPEN FOLDER")
	check.call(_on(tree, open), "pad: after sending, focus is on OPEN FOLDER")
	await GuiInput.pad(tree, JOY_BUTTON_A)
	check.call(opened == [panel.report_path], "pad: A on OPEN FOLDER opens the folder")
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_RIGHT)
	check.call(_on(tree, GuiInput.button(panel, "DONE")), "pad: right reaches DONE")
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 3)
	check.call(
		not is_instance_valid(panel) and tree.paused and _on(tree, report),
		"pad: A on DONE closes the panel, still paused, focus back on the report button"
	)
	await _back_out(tree, check, menu, before + 1)
	menu.queue_free()
	tree.paused = false


## B closes the panel from the box; CANCEL by pad closes it; neither writes a report.
static func _back_out(tree: SceneTree, check: Callable, menu: PauseMenu, written: int) -> void:
	var panel := await _press_a(tree, menu)
	await GuiInput.pad(tree, JOY_BUTTON_B)
	await UiFeedback.frames(tree, 2)
	check.call(
		not is_instance_valid(panel) and tree.paused and is_instance_valid(menu),
		"pad: B closes only the panel (still paused, menu still up)"
	)
	panel = await _press_a(tree, menu)
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_DOWN)
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_RIGHT)
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 2)
	check.call(
		not is_instance_valid(panel) and UiFeedback.reports().size() == written,
		"pad: CANCEL closes the panel and writes nothing more"
	)


## Presses A on whatever has focus in the pause menu (the report button) and returns the panel.
static func _press_a(tree: SceneTree, menu: PauseMenu) -> FeedbackPanel:
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 6)
	return GuiInput.find_script(menu, FeedbackPanel) as FeedbackPanel


static func _on(tree: SceneTree, control: Control) -> bool:
	return control != null and tree.root.gui_get_focus_owner() == control


static func _who(tree: SceneTree) -> String:
	var focus := tree.root.gui_get_focus_owner()
	return "nothing" if focus == null else "%s %s" % [focus.get_class(), focus.get("text")]
