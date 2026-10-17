class_name SettingsMenu
extends Control
## Settings: volume and sound-effects volume, fullscreen (F11), UI scale for the TV, and the
## controls for keyboard and pad. An overlay over whatever opened it (title or pause); Back or
## cancel reports `closed`. Every change goes through PlayerSettings, which applies and saves it.

signal closed

const VOLUME_STEP := 10.0

## Sound effects (the SFX bus).
var effects: HSlider
var _volume: HSlider
var _volume_text: Label
var _effects_text: Label
var _fullscreen: Button
var _scale: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(UiKit.BG, 0.92)
	UiKit.full_rect(dim)
	add_child(dim)
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	add_child(centre)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(980, 0)
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var title := UiKit.label("SETTINGS", UiKit.SIZE_TITLE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_volume = _slider(col, "Volume", PlayerSettings.volume)
	_volume.value_changed.connect(_on_volume)
	_volume_text = _volume.get_parent().get_child(2)
	effects = _slider(col, "Sound effects", PlayerSettings.sfx())
	effects.value_changed.connect(
		func(value: float) -> void: PlayerSettings.set_sfx_volume(value / 100.0)
	)
	_effects_text = effects.get_parent().get_child(2)

	_fullscreen = UiKit.button("", UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	_fullscreen.custom_minimum_size = Vector2(300, 56)
	_fullscreen.pressed.connect(func() -> void: PlayerSettings.set_fullscreen(not _is_full()))
	_row(col, "Fullscreen  (F11)").add_child(_fullscreen)
	_scale = UiKit.button("", UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	_scale.custom_minimum_size = Vector2(300, 56)
	_scale.pressed.connect(func() -> void: PlayerSettings.next_ui_scale())
	_row(col, "UI scale  (TV distance)").add_child(_scale)

	col.add_child(UiKit.label("CONTROLS", UiKit.SIZE_HEAD, UiKit.WARN))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	col.add_child(grid)
	for heading: String in ["", "Keyboard", "Pad"]:
		grid.add_child(UiKit.label(heading, UiKit.SIZE_SMALL, UiKit.MUTED))
	var controls: Array[Array] = PlayerSettings.CONTROLS
	for entry: Array in controls:
		grid.add_child(UiKit.label(str(entry[0]), UiKit.SIZE_SMALL, UiKit.TEXT))
		grid.add_child(UiKit.label(str(entry[1]), UiKit.SIZE_SMALL, UiKit.TEXT))
		grid.add_child(UiKit.label(str(entry[2]), UiKit.SIZE_SMALL, UiKit.TEXT))

	var back := UiKit.button("BACK", UiKit.SIZE_HEAD)
	back.pressed.connect(close)
	col.add_child(back)
	_refresh()
	_volume.grab_focus.call_deferred()


func _process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _on_volume(value: float) -> void:
	PlayerSettings.set_volume(value / 100.0)


func _refresh() -> void:
	_volume_text.text = "%d%%" % roundi(_volume.value)
	_effects_text.text = "%d%%" % roundi(effects.value)
	_fullscreen.text = "ON" if _is_full() else "OFF"
	_scale.text = "%d%%" % roundi(PlayerSettings.ui_scale * 100.0)


func _is_full() -> bool:
	return PlayerSettings.fullscreen


## A 0-100% slider row: name, slider, value text (the row's third child).
func _slider(parent: Control, text: String, value: float) -> HSlider:
	var row := _row(parent, text)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = VOLUME_STEP
	slider.custom_minimum_size = Vector2(420, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = round(value * 100.0)
	row.add_child(slider)
	var label := UiKit.label("", UiKit.SIZE_BODY)
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	return slider


func _row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)
	var name_label := UiKit.label(text, UiKit.SIZE_BODY)
	name_label.custom_minimum_size = Vector2(380, 0)
	row.add_child(name_label)
	return row
