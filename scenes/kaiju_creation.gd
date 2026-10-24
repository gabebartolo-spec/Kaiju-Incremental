class_name KaijuCreation
extends Control
## Kaiju Creation, the new-game opening (D-207): a lab close-up on a petri dish (CreationLab).
## Pick a genome from the rack (CreationRack: the croc lit, the Komodo and serpent greyed and
## locked), it is poured into the dish; inject the kaiju juice, the kaiju genome takes the reptile
## genome over, the camera rushes into the dish to black and an egg cracks; then `created` hands
## the species to Main, whose first run opens with the river rise. Presentation only: the sim
## never sees it. Paced in fixed physics ticks (tuning "creation" "timing"), so captures and
## tests see the same frames on any screen. Keyboard, pad and mouse; Esc / B goes back until the
## injection.

signal created(species_id: String)
signal back_pressed

enum Step { RACK, PLACE, DISH, INJECT, TAKEOVER, ZOOM, BLACK, DONE }

## The rack panel's width (px at 1080p) and the gap between its lines.
const PANEL_WIDTH := 600.0
const LINE_GAP := 12
const HINT := "ENTER / A  CHOOSE      ESC / B  BACK"
const INJECT_TEXT := "INJECT KAIJU JUICE"

## The step on show, and the sound cues reached so far in order (the egg crack's name).
var step := Step.RACK
var cues: Array[String] = []
var lab: CreationLab
var _titans: Array[Dictionary] = []
var _picked := -1
var _tick := 0
var _ticks: Dictionary = {}
var _black_from := 0.0
var _overlay: Control
var _rack_buttons: Array[Button] = []
var _rack_panel: Control
var _dish_panel: Control
var _dish_line: Label
var _inject: Button
var _black: ColorRect


## save: the save on disk ({} for none); the rack reads which titans it has unlocked.
func setup(save: Dictionary) -> void:
	_titans = CreationRack.titans(save)


func _ready() -> void:
	if _titans.is_empty():
		_titans = CreationRack.titans({})
	var cfg := Content.section("creation")
	var timing: Dictionary = cfg["timing"]
	var keys := {
		Step.PLACE: "place_s",
		Step.INJECT: "inject_s",
		Step.TAKEOVER: "takeover_s",
		Step.ZOOM: "zoom_s",
		Step.BLACK: "black_s",
	}
	for s: int in keys:
		_ticks[s] = maxi(1, roundi(Num.f(timing[keys[s]]) * Engine.physics_ticks_per_second))
	var zoom: Dictionary = cfg["lab"]["zoom"]
	_black_from = Num.f(zoom["black_from"])
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	_add_view()
	_add_overlay()
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_black)
	add_child(_black)


## How black the screen is (0..1): the zoom ends in full black, where the egg cracks.
func black() -> float:
	return _black.color.a


func _add_view() -> void:
	var view := SubViewportContainer.new()
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(view)
	add_child(view)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	# The game's anti-aliasing and render scale (a bare SubViewport draws cracks between blocks).
	GraphicsPresets.apply(PlayerSettings.graphics_row(), viewport)
	view.add_child(viewport)
	lab = CreationLab.new()
	lab.setup(_titans)
	viewport.add_child(lab)


## The broadcast frame (tape on top), the title and the rack panel down the left, the hint under.
func _add_overlay() -> void:
	_overlay = Control.new()
	UiKit.full_rect(_overlay)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	var top := UiKit.tape(18.0)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 18.0
	_overlay.add_child(top)
	var safe := MarginContainer.new()
	UiKit.full_rect(safe)
	UiKit.safe_area(safe)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", LINE_GAP * 2)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	safe.add_child(col)
	col.add_child(UiKit.header("KAIJU CREATION", UiKit.SIZE_HEAD))
	_rack_panel = _add_rack(col)
	_dish_panel = _add_dish_panel(col)
	_dish_panel.visible = false
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	col.add_child(UiKit.label(HINT, UiKit.SIZE_BODY, UiKit.MUTED))


## The rack: one button per genome; a locked one greyed, out of the focus order, marked LOCKED.
func _add_rack(col: VBoxContainer) -> Control:
	var panel := UiKit.panel()
	col.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", LINE_GAP)
	panel.add_child(box)
	box.add_child(UiKit.label("PICK A GENOME", UiKit.SIZE_HEAD, UiKit.ACCENT))
	for i: int in _titans.size():
		var titan := _titans[i]
		var text := "%s GENOME" % str(titan["name"])
		if titan["locked"] == true:
			text = "%s  -  LOCKED" % str(titan["name"])
		var b := UiKit.button(text, UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
		b.disabled = titan["selectable"] != true
		if b.disabled:
			b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick.bind(i))
		b.focus_entered.connect(func() -> void: lab.focus(i))
		box.add_child(b)
		_rack_buttons.append(b)
	for b: Button in _rack_buttons:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break
	return panel


## After the pour: what is in the dish, and the injection.
func _add_dish_panel(col: VBoxContainer) -> Control:
	var panel := UiKit.panel()
	col.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", LINE_GAP)
	panel.add_child(box)
	_dish_line = UiKit.label("", UiKit.SIZE_HEAD, UiKit.ACCENT)
	box.add_child(_dish_line)
	_inject = UiKit.button(INJECT_TEXT, UiKit.SIZE_BODY, UiKit.ACCENT)
	_inject.pressed.connect(_on_inject)
	box.add_child(_inject)
	return panel


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and step in [Step.RACK, Step.DISH]:
		get_viewport().set_input_as_handled()
		back_pressed.emit()


func _pick(index: int) -> void:
	if step != Step.RACK:
		return
	_picked = index
	for b: Button in _rack_buttons:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	_begin(Step.PLACE)


func _on_inject() -> void:
	if step != Step.DISH:
		return
	_overlay.visible = false
	_begin(Step.INJECT)


func _begin(next: Step) -> void:
	step = next
	_tick = 0


func _physics_process(_delta: float) -> void:
	if not _ticks.has(step):
		return
	_tick += 1
	var t := minf(float(_tick) / Num.i(_ticks[step]), 1.0)
	match step:
		Step.PLACE:
			lab.place(_picked, t)
		Step.INJECT:
			lab.inject(t)
		Step.TAKEOVER:
			lab.takeover(t)
		Step.ZOOM:
			lab.zoom(t)
			_black.color.a = smoothstep(_black_from, 1.0, t)
	if _tick >= Num.i(_ticks[step]):
		_advance()


func _advance() -> void:
	match step:
		Step.PLACE:
			_rack_panel.visible = false
			_dish_line.text = "%s GENOME IN THE DISH" % str(_titans[_picked]["name"])
			_dish_panel.visible = true
			_inject.grab_focus()
			_begin(Step.DISH)
		Step.INJECT:
			_begin(Step.TAKEOVER)
		Step.TAKEOVER:
			_begin(Step.ZOOM)
		Step.ZOOM:
			_black.color.a = 1.0
			_crack()
			_begin(Step.BLACK)
		Step.BLACK:
			_begin(Step.DONE)
			created.emit(str(_titans[_picked]["species"]))


## The egg crack in the black. Its file is a PLACEHOLDER (tuning "creation" "crack_sound"): with
## no file the cue is reached in silence. The player lives under the root, so the sound outlives
## the screen.
func _crack() -> void:
	var sound := str(Content.section("creation")["crack_sound"])
	cues.append(sound)
	var path := "res://assets/sfx/%s.ogg" % sound
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = AudioBuses.of(sound)
	var levels: Dictionary = Content.section("sfx")["volume_db"]
	player.volume_db = Num.f(levels.get(sound, 0.0))
	player.finished.connect(player.queue_free)
	get_tree().root.add_child(player)
	player.play()
