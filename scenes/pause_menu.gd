class_name PauseMenu
extends CanvasLayer
## The rampage's pause menu. Runs while the tree is paused: Resume (or Pause / cancel again),
## Settings, or End Rampage (the rampage ends now and keeps what it earned).

signal end_pressed

const LAYER := 30

var _col: VBoxContainer
var _resume: Button


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	UiKit.full_rect(dim)
	add_child(dim)
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	add_child(centre)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(600, 0)
	centre.add_child(panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 16)
	panel.add_child(_col)
	var title := UiKit.label("PAUSED", UiKit.SIZE_TITLE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)
	_resume = _add("RESUME", UiKit.ACCENT, resume)
	_add("SETTINGS", UiKit.PANEL_EDGE, _open_settings)
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


func _add(text: String, fill: Color, action: Callable) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_HEAD, fill)
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(action)
	_col.add_child(b)
	return b
