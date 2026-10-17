class_name TitleScreen
extends Control
## The main menu: Continue (when a save exists), New Kaiju (asks first if it would replace a
## save), Settings and Quit. Reports the choice by signal; main.gd owns the save.

signal continue_pressed
signal new_game_pressed

## The crawl along the bottom of the menu.
const NEWS: Array[String] = [
	"MONSTER SIGHTED OFFSHORE",
	"RESIDENTS URGED TO STAY INDOORS",
	"ARMY PLACED ON HIGH ALERT",
	"EXPERTS: 'IT IS STILL GROWING'",
]

## summary: "" for no save, else what Continue resumes (e.g. "Reptilian, 3 rampages").
var summary := ""
var _col: VBoxContainer
var _buttons: VBoxContainer
var _first: Button


func setup(p_summary: String) -> void:
	summary = p_summary


func _ready() -> void:
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	_add_broadcast_frame()
	_col = VBoxContainer.new()
	UiKit.full_rect(_col)
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_col.add_theme_constant_override("separation", 24)
	add_child(_col)
	var kicker := UiKit.label("CIVIL DEFENCE ALERT", UiKit.SIZE_BODY, UiKit.ALERT)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(kicker)
	var title := UiKit.label("KAIJU INCREMENTAL", 104, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)
	var sub := UiKit.label("Grow. Evolve. Flatten the city.", UiKit.SIZE_HEAD, UiKit.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(sub)
	_buttons = VBoxContainer.new()
	_buttons.custom_minimum_size = Vector2(560, 0)
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	_col.add_child(_buttons)
	_show_main()


## Hazard tape along the top edge and the news crawl along the bottom: the city has seen you.
func _add_broadcast_frame() -> void:
	var top := UiKit.tape(18.0)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 18.0
	add_child(top)
	var lines := PackedStringArray(NEWS)
	if summary != "":
		lines.insert(0, "%s STILL AT LARGE" % summary.get_slice(",", 0).to_upper())
	var crawl := NewsTicker.new(lines)
	crawl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	crawl.offset_top = -NewsTicker.HEIGHT
	add_child(crawl)


func _show_main() -> void:
	_clear()
	if summary != "":
		_add("CONTINUE", UiKit.ACCENT, func() -> void: continue_pressed.emit())
		_note(summary)
	var fresh_fill := UiKit.PANEL_EDGE if summary != "" else UiKit.ACCENT
	_add("NEW KAIJU", fresh_fill, _on_new)
	_add("SETTINGS", UiKit.PANEL_EDGE, _open_settings)
	if not OS.has_feature("web"):
		_add("QUIT", UiKit.PANEL_EDGE, func() -> void: get_tree().quit())


func _on_new() -> void:
	if summary == "":
		new_game_pressed.emit()
		return
	_clear()
	_note("Start over? Your %s and every evolution are lost." % summary)
	_add("KEEP MY KAIJU", UiKit.ACCENT, _show_main)
	_add("YES, START OVER", UiKit.BAD, func() -> void: new_game_pressed.emit())


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	_col.visible = false  # nothing behind the settings can take focus
	settings.closed.connect(
		func() -> void:
			_col.visible = true
			_show_main()
	)
	add_child(settings)


func _clear() -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_first = null


func _add(text: String, fill: Color, action: Callable) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_HEAD, fill)
	b.custom_minimum_size = Vector2(0, 80)
	b.pressed.connect(action)
	_buttons.add_child(b)
	if _first == null:
		_first = b
		b.grab_focus.call_deferred()
	return b


func _note(text: String) -> void:
	var l := UiKit.label(text, UiKit.SIZE_BODY, UiKit.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buttons.add_child(l)
