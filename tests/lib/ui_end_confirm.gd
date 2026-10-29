extends RefCounted
## The pause menu's "Are you sure?" before End Rampage (director D-155), driven by a real mouse
## click, real keys and joypad events: END RAMPAGE alone ends nothing, KEEP PLAYING (focused),
## Esc and a pad's B come back to the menu with the run still on, and only YES ends it.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const UiFeedback := preload("res://tests/lib/ui_feedback.gd")
## More D-pad presses than the pause menu has buttons (D-385: the walk stops on END RAMPAGE).
const MAX_DOWNS := 12


static func run(tree: SceneTree, check: Callable) -> void:
	var ended: Array[bool] = []
	var menu := _menu(tree, ended)
	await UiFeedback.frames(tree, 3)
	await GuiInput.click(tree, GuiInput.button(menu, "END RAMPAGE"))
	await UiFeedback.frames(tree, 3)
	var ask := GuiInput.find_script(menu, EndConfirm) as EndConfirm
	check.call(
		ask != null and ended.is_empty() and tree.paused,
		"clicking END RAMPAGE asks first: nothing ends, still paused"
	)
	if ask == null:
		menu.queue_free()
		tree.paused = false
		return
	check.call(_on(tree, ask.keep), "the question opens on KEEP PLAYING, never on the yes button")
	check.call(GuiInput.button(menu, "RESUME") == null, "the pause buttons are hidden behind it")
	await GuiInput.key(tree, KEY_ESCAPE)
	await UiFeedback.frames(tree, 3)
	check.call(
		not is_instance_valid(ask) and tree.paused and ended.is_empty(),
		"Esc closes only the question: still paused, the run goes on"
	)
	check.call(_on(tree, GuiInput.button(menu, "RESUME")), "focus returns to RESUME")
	await _pad_round(tree, check, menu, ended)
	await _yes_by_click(tree, check, ended)


## A pad alone: down to END RAMPAGE, A asks, A on KEEP PLAYING and B both come back, right to
## YES, A ends.
static func _pad_round(
	tree: SceneTree, check: Callable, menu: PauseMenu, ended: Array[bool]
) -> void:
	check.call(await _down_to_end(tree, menu), "pad: pressing down from RESUME reaches END RAMPAGE")
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 3)
	var ask := GuiInput.find_script(menu, EndConfirm) as EndConfirm
	check.call(ask != null and _on(tree, ask.keep), "pad: A on END RAMPAGE asks, on KEEP PLAYING")
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 3)
	check.call(
		not is_instance_valid(ask) and ended.is_empty() and tree.paused,
		"pad: A on KEEP PLAYING closes it, the run goes on"
	)
	await GuiInput.pad(tree, JOY_BUTTON_A)  # focus is back on RESUME: that resumes, so re-pause
	await UiFeedback.frames(tree, 2)
	check.call(not tree.paused, "pad: A back on RESUME resumes (the question left no stuck focus)")
	tree.paused = true
	menu = _menu(tree, ended)
	await UiFeedback.frames(tree, 3)
	await _down_to_end(tree, menu)
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 3)
	ask = GuiInput.find_script(menu, EndConfirm) as EndConfirm
	await GuiInput.pad(tree, JOY_BUTTON_B)
	await UiFeedback.frames(tree, 3)
	check.call(
		not is_instance_valid(ask) and ended.is_empty() and tree.paused,
		"pad: B closes the question, the run goes on"
	)
	await _down_to_end(tree, menu)  # RESUME is focused again: down to END RAMPAGE
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 3)
	ask = GuiInput.find_script(menu, EndConfirm) as EndConfirm
	await GuiInput.pad(tree, JOY_BUTTON_DPAD_RIGHT)
	check.call(_on(tree, ask.yes), "pad: right from KEEP PLAYING reaches YES")
	await GuiInput.pad(tree, JOY_BUTTON_A)
	await UiFeedback.frames(tree, 3)
	check.call(ended == [true] and not tree.paused, "pad: A on YES ends the run and unpauses")
	ended.clear()
	tree.paused = false


static func _yes_by_click(tree: SceneTree, check: Callable, ended: Array[bool]) -> void:
	var menu := _menu(tree, ended)
	tree.paused = true
	await UiFeedback.frames(tree, 3)
	await GuiInput.click(tree, GuiInput.button(menu, "END RAMPAGE"))
	await UiFeedback.frames(tree, 3)
	await GuiInput.click(tree, GuiInput.button(menu, "YES"))
	await UiFeedback.frames(tree, 3)
	check.call(ended == [true] and not tree.paused, "clicking YES ends the run and unpauses")


## Presses D-pad down until END RAMPAGE has the focus, at most MAX_DOWNS times; true once it has.
static func _down_to_end(tree: SceneTree, menu: PauseMenu) -> bool:
	var end := GuiInput.button(menu, "END RAMPAGE")
	for _i: int in MAX_DOWNS:
		if _on(tree, end):
			return true
		await GuiInput.pad(tree, JOY_BUTTON_DPAD_DOWN)
	return _on(tree, end)


static func _menu(tree: SceneTree, ended: Array[bool]) -> PauseMenu:
	var menu := PauseMenu.new()
	menu.sim = UiFeedback.played_sim()
	menu.species_id = "reptilian"
	menu.end_pressed.connect(func() -> void: ended.append(true))
	tree.root.add_child(menu)
	tree.paused = true
	return menu


static func _on(tree: SceneTree, control: Control) -> bool:
	return control != null and tree.root.gui_get_focus_owner() == control
