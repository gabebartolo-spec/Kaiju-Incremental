class_name SettingsMenu
extends Control
## Settings: volume and sound-effects volume, camera motion, fullscreen (F11), UI scale for the
## TV, and the controls for keyboard and pad. An overlay over whatever opened it (title or
## pause); Back or cancel reports `closed`. Every change goes through PlayerSettings, which
## applies and saves it.

signal closed

const VOLUME_STEP := 10.0
## The time-of-day button spans the sliders' column (two 200 px buttons and the gap between).
const TIME_WIDTH := 425.0

## Sound effects (the SFX bus).
var effects: HSlider
## Camera motion (shake, footfall dip, breath swing).
var motion: HSlider
var _volume: HSlider
var _volume_text: Label
var _effects_text: Label
var _motion_text: Label
var _fullscreen: Button
var _scale: Button
var _fps: Button
var _graphics: Button
var _time: Button


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
	col.add_theme_constant_override("separation", 6)  # 6, not 10 or 14: it all fits at 125%
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
	motion = _slider(col, "Camera motion", PlayerSettings.motion())
	motion.value_changed.connect(
		func(value: float) -> void: PlayerSettings.set_camera_motion(value / 100.0)
	)
	_motion_text = motion.get_parent().get_child(2)

	_fullscreen = _choice(200.0, func() -> void: PlayerSettings.set_fullscreen(not _is_full()))
	_scale = _choice(200.0, func() -> void: PlayerSettings.next_ui_scale())
	# One row for both screen settings, so the time-of-day row fits the TV at the largest UI scale.
	var screen := _row(col, "Display")
	screen.add_child(_fullscreen)
	screen.add_child(_scale)
	_fps = _choice(200.0, func() -> void: PlayerSettings.next_fps_cap())
	_graphics = _choice(200.0, func() -> void: PlayerSettings.next_graphics())
	# One row for both GPU settings, so the screen still fits the TV at the largest UI scale.
	var gpu := _row(col, "Graphics and frame cap")
	gpu.add_child(_graphics)
	gpu.add_child(_fps)
	# The time-of-day button spans the sliders' column, edge to edge (D-145).
	_time = _choice(TIME_WIDTH, func() -> void: PlayerSettings.next_time_of_day())
	_row(col, "Time of day").add_child(_time)
	_add_controls(col)

	var back := UiKit.button("BACK", UiKit.SIZE_HEAD)
	back.pressed.connect(close)
	col.add_child(back)
	_refresh()
	_volume.grab_focus.call_deferred()


## A settings button (its text is set by _refresh) that does `on_press`.
func _choice(width: float, on_press: Callable) -> Button:
	var button := UiKit.button("", UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	button.custom_minimum_size = Vector2(width, 56)
	button.pressed.connect(on_press)
	return button


## The controls list, keyboard and pad, at the body size.
func _add_controls(col: Control) -> void:
	col.add_child(UiKit.label("CONTROLS", UiKit.SIZE_HEAD, UiKit.WARN))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 0)
	col.add_child(grid)
	for heading: String in ["", "Keyboard", "Pad"]:
		grid.add_child(UiKit.label(heading, UiKit.SIZE_BODY, UiKit.MUTED))
	var controls: Array[Array] = PlayerSettings.CONTROLS
	for entry: Array in controls:
		# A row tied to a species (its 4th entry) shows only when that species is playable.
		if entry.size() > 3 and not Demo.allows(str(entry[3])):
			continue
		for at: int in 3:
			grid.add_child(UiKit.label(str(entry[at]), UiKit.SIZE_BODY, UiKit.TEXT))


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
	_motion_text.text = "%d%%" % roundi(motion.value)
	_fullscreen.text = "FULLSCREEN: %s" % ("ON" if _is_full() else "OFF")
	_scale.text = "UI SCALE: %d%%" % roundi(PlayerSettings.ui_scale * 100.0)
	_fps.text = "UNLIMITED" if PlayerSettings.cap() == 0 else "%d FPS" % PlayerSettings.cap()
	_graphics.text = PlayerSettings.graphics_level().to_upper()
	_time.text = "< %s >" % TimeOfDay.label(PlayerSettings.time_of_day).to_upper()  # steps on press


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
	UiKit.slider_look(slider)
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
