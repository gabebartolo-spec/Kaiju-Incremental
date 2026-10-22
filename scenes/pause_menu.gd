class_name PauseMenu
extends CanvasLayer
## The rampage's pause menu. Runs while the tree is paused: Resume (or Pause / cancel again),
## Settings, the bug / feedback report (D-145) or End Rampage (the rampage ends now and keeps
## what it earned).

signal end_pressed

const LAYER := 30

## The rampage being paused and its species id: what a feedback report says about the run.
var sim: RampageSim
var species_id := ""
var _dim: ColorRect
var _centre: CenterContainer
var _col: VBoxContainer
var _resume: Button
var _report: Button


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	UiKit.full_rect(_dim)
	add_child(_dim)
	_centre = CenterContainer.new()
	UiKit.full_rect(_centre)
	add_child(_centre)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(600, 0)
	_centre.add_child(panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 16)
	panel.add_child(_col)
	var title := UiKit.label("PAUSED", UiKit.SIZE_TITLE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)
	_resume = _add("RESUME", UiKit.ACCENT, resume)
	_add("SETTINGS", UiKit.PANEL_EDGE, _open_settings)
	if sim != null:
		_report = _add(str(Content.section("feedback")["label"]), UiKit.PANEL_EDGE, _open_report)
	_add("END RAMPAGE  (keep biomass)", UiKit.PANEL_EDGE, _end)
	_resume.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not _col.visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()


func resume() -> void:
	get_tree().paused = false
	queue_free()


func _end() -> void:
	get_tree().paused = false
	end_pressed.emit()
	queue_free()


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	_col.visible = false  # nothing behind the settings can take focus
	settings.closed.connect(
		func() -> void:
			_col.visible = true
			_resume.grab_focus.call_deferred()
	)
	add_child(settings)


## Takes the picture first, with the menu hidden so neither it nor the panel is in it, then opens
## the report panel over the dimmed pause (the tree stays paused; the menu is hidden, so Esc is
## the panel's).
func _open_report() -> void:
	_col.visible = false  # the buttons take no click or key while the panel is up
	_centre.visible = false  # and the empty hazard-tape box is not in the picture
	_dim.visible = false
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":  # a headless run never draws, so never signals
		await RenderingServer.frame_post_draw
	var shot := FeedbackReport.grab(get_viewport())
	_dim.visible = true
	var panel := FeedbackPanel.new()
	panel.setup(shot, FeedbackReport.facts(sim, species_id, get_viewport()))
	panel.closed.connect(
		func() -> void:
			_col.visible = true
			_centre.visible = true
			_report.grab_focus.call_deferred()
	)
	add_child(panel)


func _add(text: String, fill: Color, action: Callable) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_HEAD, fill)
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(action)
	_col.add_child(b)
	return b
