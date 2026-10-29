class_name OptionsPage
extends Control
## A page that Settings opens over itself (CONTROLS, ACCESSIBILITY): the settings card's look
## (UiKit panel on a dark screen, the title, rows of a name and its buttons, BACK at the foot).
## A page builds its rows in _build() and sets its buttons' text in _refresh() (every frame).
## Back or cancel reports `closed` and frees it.

signal closed

## The buttons' column (px at 1080p), as wide as the settings card's.
const SPAN := 420.0
const BUTTON_GAP := 20.0
const NAME_WIDTH := 380.0
const CHOICE_MARGIN := 8.0
const BACK_MARGIN := 10.0
const BLOCK_GAP := 14

var _title: String
var _first: Control


func _init(title: String) -> void:
	_title = title


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	var dim := ColorRect.new()
	dim.color = UiKit.BG
	UiKit.full_rect(dim)
	add_child(dim)
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	add_child(centre)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(980, 0)
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var title := UiKit.label(_title, UiKit.SIZE_TITLE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_build(col)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", int(BUTTON_GAP))
	for b: Button in _foot_buttons():
		foot.add_child(b)
	var back := UiKit.button(tr("BACK"), UiKit.SIZE_HEAD)
	HazardBox.trim_height(back, BACK_MARGIN)
	back.pressed.connect(close)
	foot.add_child(back)
	col.add_child(gap(foot, BLOCK_GAP))
	_refresh()
	(_first if _first != null else back).grab_focus.call_deferred()


## The page's rows, under its title.
func _build(_col: VBoxContainer) -> void:
	pass


## Buttons beside BACK at the foot.
func _foot_buttons() -> Array[Button]:
	return []


## Sets every button's text from the settings.
func _refresh() -> void:
	pass


func _process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


## A button that does `on_press` and takes its share of a row's span; the first one made takes
## focus when the page opens.
func choice(on_press: Callable) -> Button:
	var button := UiKit.button("", UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HazardBox.drop_pointer(button)
	HazardBox.trim_height(button, CHOICE_MARGIN)
	button.pressed.connect(on_press)
	if _first == null:
		_first = button
	return button


## A row: `text` and, in the span beside it, `items` (buttons or labels) in equal parts.
func row(col: Control, text: String, items: Array[Control]) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	var name_label := UiKit.label(text, UiKit.SIZE_BODY)
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	line.add_child(name_label)
	var span := HBoxContainer.new()
	span.custom_minimum_size = Vector2(SPAN, 0)
	span.add_theme_constant_override("separation", int(BUTTON_GAP))
	for item: Control in items:
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		span.add_child(item)
	line.add_child(span)
	col.add_child(line)
	return line


## `node` with `top` px of space above it.
static func gap(node: Control, top: int) -> Control:
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_top", top)
	box.add_child(node)
	return box


static func cycle(value: String) -> String:
	return "< %s >" % TranslationServer.translate(value)
