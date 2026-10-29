class_name KaijuCreation
extends Control
## Kaiju Creation, the new-game opening (D-207): a lab close-up on a petri dish (CreationLab).
## Pick a genome from the rack (CreationRack: the croc lit, the Komodo and serpent greyed and
## locked), it is poured into the dish; inject Special K (the kaiju juice), the kaiju genome
## takes the reptile genome over, the camera rushes into the dish to black and an egg cracks
## (a crack, a pause, a couple more cracks: tuning "creation" "cracks"; the director 2026-10-26),
## then `created` hands the species to Main, whose first run opens with the rise from the sea bay
## (the pause, then the roar as the head breaks the water). Presentation only: the sim
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
const INJECT_TEXT := "INJECT SPECIAL K"

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
## The lab's sounds (tuning "creation" "sounds"): the room's loops, the takeover's crackle, and the
## trip phase whose cue last played.
var _loops: Array[AudioStreamPlayer] = []
var _crackle: AudioStreamPlayer
## The takeover's one-shots, cut at the black so the egg crack is heard alone.
var _shots: Array[AudioStreamPlayer] = []
var _phase := -1
## The hit-stops' white flash (CreationLab.flash).
var _white: ColorRect


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
	_white = ColorRect.new()
	_white.color = Color(1, 1, 1, 0)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_white)
	add_child(_white)
	_add_overlay()
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_black)
	add_child(_black)
	for sound: Variant in _sounds()["loops"]:
		_loops.append(_play(str(sound), true))


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
	# Drawn from the first frame: "when visible" waits for a frame on show, so it flashed black.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	# The panels sit low on the left, clear of the rack and the dish the camera frames.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	_rack_panel = _add_rack(col)
	_dish_panel = _add_dish_panel(col)
	_dish_panel.visible = false
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
	_play(str(_sounds()["pick"]))
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
	_phase = -1
	var s := _sounds()
	match next:
		Step.TAKEOVER:
			_play(str(s["strike"]))
			_crackle = _play(str(s["crackle"]), true)
		Step.ZOOM:
			_shots.append(_play(str(s["dive"])))
		Step.BLACK:
			for player: AudioStreamPlayer in _loops + _shots:
				if is_instance_valid(player):
					player.stop()


func _physics_process(_delta: float) -> void:
	if not _ticks.has(step):
		return
	_tick += 1
	var t := minf(float(_tick) / Num.i(_ticks[step]), 1.0)
	match step:
		Step.PLACE:
			lab.place(_picked, t)
			_trip_cue(t, "place")
		Step.INJECT:
			lab.inject(t)
			_trip_cue(t, "inject")
		Step.TAKEOVER:
			lab.takeover(t)
			_overload_cue(t)
		Step.ZOOM:
			lab.zoom(t)
			_black.color.a = smoothstep(_black_from, 1.0, t)
		Step.BLACK:
			_cracks_due()
	_white.color.a = lab.flash * PlayerSettings.flash_scale()  # Reduce flashing (D-259)
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
			_begin(Step.BLACK)
			_cracks_due()
		Step.BLACK:
			_begin(Step.DONE)
			created.emit(str(_titans[_picked]["species"]))


## The egg's cracks in the black (tuning "creation" "cracks", each a cut of "crack_sound": from
## from_s for len_s, at_s seconds into the black), each on the tick it falls due.
func _cracks_due() -> void:
	var cfg := Content.section("creation")
	var played := cues.count(str(cfg["crack_sound"]))
	var cracks: Array = cfg["cracks"]
	if played >= cracks.size():
		return
	var next: Dictionary = cracks[played]
	if _tick < roundi(Num.f(next["at_s"]) * Engine.physics_ticks_per_second):
		return
	var crack := _play(str(cfg["crack_sound"]))
	if crack != null:
		crack.play(Num.f(next["from_s"]))
		get_tree().create_timer(Num.f(next["len_s"])).timeout.connect(crack.queue_free)


static func _sounds() -> Dictionary:
	return Content.section("creation")["sounds"]


## The injector's cue for each trip phase it enters (servo swings, the draw, the dispense).
func _trip_cue(t: float, key: String) -> void:
	var p := CreationInjector.phase(t, key)
	if p == _phase:
		return
	_phase = p
	var trip: Dictionary = _sounds()["trip"]
	if trip.has(str(p)):
		_play(str(trip[str(p)]))


## The crackle stops and the overload bangs at the second hit-stop.
func _overload_cue(t: float) -> void:
	var timing: Dictionary = Content.section("creation")["timing"]
	var lead := Num.f(_sounds()["overload_lead_s"]) / Num.f(timing["takeover_s"])
	if _crackle == null or t < Num.f(CreationSet.cfg()["overload_at"]) - lead:
		return
	_crackle.stop()
	_crackle = null
	_shots.append(_play(str(_sounds()["overload"])))


## Plays assets/sfx/<sound>.ogg and notes the cue (with no file it is reached in silence). A loop
## lives under the screen and stops with it; a one-shot lives under the root, so it outlives the
## screen (the egg crack plays into the run).
func _play(sound: String, loop := false) -> AudioStreamPlayer:
	cues.append(sound)
	var path := "res://assets/sfx/%s.ogg" % sound
	if not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer.new()
	var stream: AudioStream = load(path)
	if loop and stream is AudioStreamOggVorbis:
		stream = stream.duplicate() as AudioStream
		(stream as AudioStreamOggVorbis).loop = true
	player.stream = stream
	player.bus = AudioBuses.of(sound)
	var levels: Dictionary = Content.section("sfx")["volume_db"]
	player.volume_db = Num.f(levels.get(sound, 0.0))
	if loop:
		add_child(player)
	else:
		player.finished.connect(player.queue_free)
		get_tree().root.add_child(player)
	player.play()
	return player
