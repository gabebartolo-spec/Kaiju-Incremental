class_name FeedbackPanel
extends Control
## The pause menu's bug / feedback panel (D-145): a text box with SEND and CANCEL. SEND writes the
## report folder (FeedbackReport) and the panel says where it went, with OPEN FOLDER. Runs while
## the tree is paused; the box takes every key typed into it, so nothing reaches the rampage.
## Cancel (or Esc, or a pad's back button) reports `closed` without writing anything.

signal closed

## Opens a folder on the player's desktop; a test swaps it for a recorder.
var opener: Callable = OS.shell_open
## Where the report went (absolute path), once SEND has written it.
var report_path := ""
var box: TextEdit
var status: Label
var _prompt: Label
var _shot: Image
var _details: Dictionary
var _write_row: HBoxContainer
var _done_row: HBoxContainer
var _open: Button
var _done: Button
var _send_button: Button


## `shot`: the rampage as it stood before this panel opened; `details`: FeedbackReport.facts.
func setup(shot: Image, details: Dictionary) -> void:
	_shot = shot
	_details = details


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := Content.section("feedback")
	UiKit.full_rect(self)
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	add_child(centre)
	var panel := UiKit.panel()
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var title := UiKit.label(tr(str(cfg["title"])), UiKit.SIZE_HEAD, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_prompt = UiKit.label(tr(str(cfg["prompt"])), UiKit.SIZE_BODY, UiKit.MUTED)
	col.add_child(_prompt)
	box = _text_box(cfg)
	col.add_child(box)
	status = UiKit.label("", UiKit.SIZE_BODY)
	status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	status.custom_minimum_size.x = Num.f(cfg["box_width"])
	status.visible = false
	col.add_child(status)
	_write_row = _row(col)
	_send_button = _button(_write_row, tr(str(cfg["send"])), UiKit.ACCENT, _send)
	var cancel := _button(_write_row, tr(str(cfg["cancel"])), UiKit.PANEL_EDGE, _close)
	for b: Button in [_send_button, cancel]:
		b.focus_neighbor_top = b.get_path_to(box)  # a pad's up returns to the box
	_done_row = _row(col)
	_open = _button(_done_row, tr(str(cfg["open_folder"])), UiKit.ACCENT, _open_folder)
	_done = _button(_done_row, tr(str(cfg["done"])), UiKit.PANEL_EDGE, _close)
	_done_row.visible = false
	box.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _send() -> void:
	var cfg := Content.section("feedback")
	var result := FeedbackReport.write(box.text, _details, _shot, FeedbackReport.stamp_now())
	var ok: bool = result["ok"]
	report_path = str(result["path"])
	if ok:
		status.text = tr(str(cfg["saved"])).replace("{path}", report_path)
	else:
		status.text = tr(str(cfg["failed"])).replace("{error}", str(result["error"]))
	status.add_theme_color_override("font_color", UiKit.GOOD if ok else UiKit.BAD)
	status.visible = true
	box.visible = false
	_prompt.visible = false
	_write_row.visible = false
	_done_row.visible = true
	_open.visible = ok
	var next: Button = _open if ok else _done
	next.grab_focus.call_deferred()


## A pad cannot type, and a TextEdit keeps every d-pad and stick move for its caret: a pad's down
## or A (never a keyboard's, where Enter is a new line) hands focus to SEND, so a pad can reach
## every control. Up from a button comes back (focus_neighbor_top); B is cancel.
func _pad_leaves_box(event: InputEvent) -> void:
	var from_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if from_pad and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_accept")):
		box.accept_event()
		_send_button.grab_focus()


func _open_folder() -> void:
	if not report_path.is_empty():
		opener.call(report_path)


func _close() -> void:
	closed.emit()
	queue_free()


func _text_box(cfg: Dictionary) -> TextEdit:
	var t := TextEdit.new()
	t.custom_minimum_size = Vector2(
		Num.f(cfg["box_width"]), Num.f(cfg["box_lines"]) * (UiKit.SIZE_BODY + 10)
	)
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.add_theme_font_size_override("font_size", UiKit.SIZE_BODY)
	t.add_theme_color_override("font_color", UiKit.TEXT)
	t.add_theme_color_override("caret_color", UiKit.ACCENT)
	t.add_theme_color_override("selection_color", Color(UiKit.ACCENT, 0.35))
	t.add_theme_stylebox_override("normal", UiKit.box(Color(0, 0, 0, 0.75), UiKit.PANEL_EDGE, 2))
	t.add_theme_stylebox_override("focus", UiKit.box(Color(0, 0, 0, 0.75), UiKit.ACCENT, 2))
	var limit := Num.i(cfg["max_chars"])
	t.gui_input.connect(_pad_leaves_box)
	t.text_changed.connect(
		func() -> void:
			if t.text.length() > limit:
				t.text = t.text.substr(0, limit)
				t.set_caret_column(t.get_line(t.get_caret_line()).length())
	)
	return t


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row


func _button(row: Control, text: String, fill: Color, action: Callable) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_HEAD, fill)
	b.custom_minimum_size = Vector2(300, 76)
	b.pressed.connect(action)
	row.add_child(b)
	return b
