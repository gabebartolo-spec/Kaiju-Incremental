class_name SlotList
extends VBoxContainer
## The save slots under the title's logo (director 2026-10-26: "Three slots (Recommended)"): one
## row per slot, the slot's specimen and kaiju on a wide plate and DELETE beside it; an empty slot
## says EMPTY. Continue picks a filled slot (empty ones are greyed); New Kaiju picks any slot, and a
## filled one asks first. DELETE always asks first. BACK, Esc or a pad's B return to the title.
## Reports by signal; main.gd owns the saves.

signal picked(slot: int)
signal delete_confirmed(slot: int)
signal back_pressed

enum Mode { CONTINUE, NEW }

## The one line over the slots, per mode.
const PICK_CONTINUE := "Pick a kaiju to wake."
const PICK_NEW := "Pick a slot for the new kaiju."
const EMPTY := "EMPTY"
## A filled slot this build cannot play (a demo save in the full game, or a species it leaves out).
const LOCKED := "NOT IN THIS VERSION"
## A slot whose file cannot be read (corrupt, or saved by a newer version): kept, never EMPTY.
const UNREADABLE := "UNREADABLE"
## A slot plate's height (px at 1080p): three rows and BACK fit above the news ticker.
const ROW_HEIGHT := 96.0
const BACK_HEIGHT := 72.0
const ROW_GAP := 12
## The slot plate takes this many shares of a row and DELETE one.
const SLOT_SHARE := 3.0
## The line over the slots, one size up from body text so it reads on a TV.
const NOTE_SIZE := 30

var mode := Mode.CONTINUE
## One per slot: {"slot": n, "taken": bool, "continues": bool, "specimen": "SPECIMEN K-01",
## "summary": "Reptilian, 3 rampages, 120 biomass", "species": "Reptilian"}.
var slots: Array[Dictionary] = []
## The slot whose plate takes focus first (0: the first one that can be picked).
var focus_slot := 0
## True while an "are you sure?" is up: Esc goes back to the slots, not the title.
var _asking := false


func setup(p_mode: Mode, p_slots: Array[Dictionary], p_focus := 0) -> void:
	mode = p_mode
	slots = p_slots
	focus_slot = p_focus


func _ready() -> void:
	add_theme_constant_override("separation", ROW_GAP)
	_show_list()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _asking:
			_show_list()
		else:
			back_pressed.emit()


## The text on slot `info`'s plate.
static func plate_text(info: Dictionary) -> String:
	var head := TranslationServer.translate("SLOT %d") % Num.i(info["slot"])
	if info.get("taken", false) != true:
		return "%s\n%s" % [head, TranslationServer.translate(EMPTY)]
	if info.get("readable", true) != true:
		return "%s\n%s" % [head, TranslationServer.translate(UNREADABLE)]
	var line := (
		str(info["summary"])
		if info.get("continues", false) == true
		else TranslationServer.translate(LOCKED)
	)
	return "%s - %s\n%s" % [head, str(info["specimen"]), line.to_upper()]


func _show_list() -> void:
	_clear()
	_asking = false
	_note(tr(PICK_CONTINUE) if mode == Mode.CONTINUE else tr(PICK_NEW))
	var plates: Array[Button] = []
	for info: Dictionary in slots:
		plates.append(_add_row(info))
	var back := _button(tr("BACK"), UiKit.PANEL_EDGE, back_pressed.emit, self)
	back.custom_minimum_size = Vector2(0.0, BACK_HEIGHT)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var focus: Button = null
	for i: int in plates.size():
		var plate := plates[i]
		if plate.disabled:
			continue
		if focus == null or Num.i(slots[i]["slot"]) == focus_slot:
			focus = plate
	(focus if focus != null else back).grab_focus.call_deferred()


## A slot's row: its plate, and DELETE when it holds a save (an empty slot keeps the gap, so every
## plate is the same width).
func _add_row(info: Dictionary) -> Button:
	var n := Num.i(info["slot"])
	var taken: bool = info.get("taken", false) == true
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	add_child(row)
	var fill := UiKit.ACCENT if taken else UiKit.PANEL_EDGE
	var plate := _button(plate_text(info), fill, _on_plate.bind(info), row)
	plate.name = "Slot%d" % n
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_stretch_ratio = SLOT_SHARE
	plate.disabled = mode == Mode.CONTINUE and not (taken and info.get("continues", false) == true)
	if plate.disabled:
		plate.focus_mode = Control.FOCUS_NONE  # the pad steps over a slot it cannot pick
	if taken:
		var del := _button(tr("DELETE"), UiKit.PANEL_EDGE, _ask_delete.bind(info), row)
		del.name = "Delete%d" % n
		del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	return plate


func _on_plate(info: Dictionary) -> void:
	var n := Num.i(info["slot"])
	if mode == Mode.CONTINUE or info.get("taken", false) != true:
		picked.emit(n)
		return
	_ask(
		tr("Start over in slot %d? Your %s and every evolution are lost.") % [n, _who(info)],
		tr("YES, START OVER"),
		func() -> void: picked.emit(n)
	)


func _ask_delete(info: Dictionary) -> void:
	var n := Num.i(info["slot"])
	_ask(
		tr("Delete slot %d? Your %s and every evolution are lost.") % [n, _who(info)],
		tr("YES, DELETE"),
		func() -> void: delete_confirmed.emit(n)
	)


## "Are you sure?": the question, KEEP MY KAIJU (focused, so a stray press keeps it) and the yes.
func _ask(question: String, yes_text: String, yes: Callable) -> void:
	_clear()
	_asking = true
	_note(question)
	var keep := _button(tr("KEEP MY KAIJU"), UiKit.ACCENT, _show_list, self)
	_button(yes_text, UiKit.BAD, yes, self)
	keep.grab_focus.call_deferred()


func _who(info: Dictionary) -> String:
	if info.get("readable", true) != true:
		return tr("unreadable save")
	var species := tr(str(info.get("species", "")))
	return "%s (%s)" % [species, str(info["specimen"])] if species != "" else str(info["specimen"])


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func _button(text: String, fill: Color, action: Callable, into: Container) -> Button:
	var b := UiKit.button(text, UiKit.SIZE_BODY, fill)
	HazardBox.drop_pointer(b)
	b.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	b.pressed.connect(action)
	into.add_child(b)
	return b


func _note(text: String) -> void:
	var l := UiKit.label(text, NOTE_SIZE, UiKit.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
