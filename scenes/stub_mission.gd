class_name StubMission
extends Control
## The stand-in mission LAUNCH opens until the globe starts real cities (Overworld plan row G5,
## director 2026-11-01: "Win/Lose stub + pick"): a plain screen with WIN and LOSE. WIN shows the
## continent's three bonuses and the player keeps one (D-421), which ends it with won; LOSE ends
## it with lost and nothing changes.

signal won(id: String, bonus_id: String)
signal lost(id: String)

const GAP := 24  # px between the screen's lines

## The continent whose mission this is.
var id := ""

var _column: VBoxContainer


func _init() -> void:
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	add_child(centre)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", GAP)
	centre.add_child(_column)
	visible = false


## Opens the mission for one continent (a Content.continents() row) on its WIN / LOSE choice.
func start(def: Dictionary) -> void:
	id = str(def["id"])
	_clear()
	_column.add_child(UiKit.header(tr(str(def["name"])).to_upper(), UiKit.SIZE_TITLE))
	_column.add_child(_centred(tr("Stand-in mission: the city comes later")))
	var win := UiKit.button(tr("WIN"), UiKit.SIZE_HEAD)
	win.pressed.connect(_pick.bind(def))
	_column.add_child(win)
	var lose := UiKit.button(tr("LOSE"), UiKit.SIZE_HEAD, UiKit.ALERT)
	lose.pressed.connect(func() -> void: lost.emit(id))
	_column.add_child(lose)
	visible = true
	_focus.call_deferred(win)


## The won screen: one button per bonus the continent offers; pressing one keeps it.
func _pick(def: Dictionary) -> void:
	_clear()
	_column.add_child(UiKit.header(tr("WIN ONE:"), UiKit.SIZE_TITLE))
	var offered: Array = def["bonuses"]
	for pick: Dictionary in offered:
		var b := UiKit.button(MissionPanel.bonus_text(pick, self), UiKit.SIZE_BODY)
		b.pressed.connect(func() -> void: won.emit(id, str(pick["id"])))
		_column.add_child(b)
		if _column.get_child_count() == 2:
			_focus.call_deferred(b)


## The buttons on the screen now, top to bottom.
func buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in _column.get_children():
		if child is Button:
			out.append(child as Button)
	return out


## Focus for the pad and keys, unless the button was cleared away before the frame ended.
func _focus(b: Button) -> void:
	if b.is_inside_tree():
		b.grab_focus()


func _centred(text: String) -> Label:
	var l := UiKit.label(text, UiKit.SIZE_BODY, UiKit.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _clear() -> void:
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
