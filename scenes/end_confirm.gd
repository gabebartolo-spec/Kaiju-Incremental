class_name EndConfirm
extends Control
## The pause menu's "Are you sure?" before End Rampage (director D-155): a small panel over the
## dimmed pause with KEEP PLAYING (focused, so a stray press never ends the run) and the yes
## button. Esc, a pad's B or KEEP PLAYING report `closed`; the yes button reports `confirmed`.
## Runs while the tree is paused.

signal confirmed
signal closed

var keep: Button
var yes: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := Content.section("pause")
	UiKit.full_rect(self)
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	add_child(centre)
	var panel := UiKit.panel()
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var title := UiKit.label(str(cfg["end_title"]), UiKit.SIZE_HEAD, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var line := UiKit.label(str(cfg["end_line"]), UiKit.SIZE_BODY, UiKit.MUTED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	keep = _button(row, str(cfg["end_keep"]), UiKit.ACCENT, _close)
	yes = _button(row, str(cfg["end_yes"]), UiKit.PANEL_EDGE, confirmed.emit)
	keep.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _button(row: Control, text: String, fill: Color, action: Callable) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_HEAD, fill)
	b.custom_minimum_size = Vector2(380, 76)
	b.pressed.connect(action)
	row.add_child(b)
	return b
