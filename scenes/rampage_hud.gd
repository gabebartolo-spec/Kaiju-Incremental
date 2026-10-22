class_name RampageHud
extends CanvasLayer
## The rampage HUD: health, clock, rubble, city destroyed, signature readiness; then the end
## beat (why it ended, big). Reads the sim; reports the beat's end through `beat_done`.

signal beat_done(result: Dictionary)

## Reason: headline, line under it.
const HEADLINES := {
	"defeated": ["BROUGHT DOWN", "The army got you this time"],
	"time": ["TIME UP", "Your rage is spent"],
	"city_fallen": ["THE CITY HAS FALLEN", "Nothing left standing"],
	"ended": ["RAMPAGE ENDED", "You called it off"],
}
## The end beat runs this many frames, and can be skipped after the first BEAT_MIN_FRAMES.
const BEAT_FRAMES := 150
const BEAT_MIN_FRAMES := 40
const BEAT_SIZE := 128
## The world runs at this speed during the end beat.
const END_SLOWMO := 0.3
## How opaque the plates behind the HUD's corner groups are.
const PLATE_ALPHA := 0.62

var sim: RampageSim
var species: Dictionary
## The crowd (null with no streets): only the view counts the civilians it crushed.
var street: StreetLife
## The end beat's headline (read by the flow suite and the captures).
var headline: Label
var _hp: ProgressBar
var _hp_text: Label
var _time: Label
var _rubble: Label
var _destruction: ProgressBar
var _ability: Label
var _ultimate: Label
var _dash: Label
## The HUD's bars and hints: hidden while a dialog (pause, the report) is up.
var _widgets: Control
var _clock_box: HazardBox
var _beat_frame := -1
var _beat_done := false


func _init(p_sim: RampageSim, p_species: Dictionary, p_street: StreetLife) -> void:
	sim = p_sim
	species = p_species
	street = p_street


## The sim's result plus what only the view counts: the civilians it crushed.
func result() -> Dictionary:
	return sim.result().merged({"civilians": street.civilians_killed() if street != null else 0})


func _ready() -> void:
	var root := MarginContainer.new()
	_widgets = root
	UiKit.full_rect(root)
	for side: String in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 28)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	top.add_child(_plate(left))
	left.add_child(UiKit.label(str(species["name"]).to_upper(), UiKit.SIZE_BODY, UiKit.MUTED))
	_hp = UiKit.bar(UiKit.ALERT, 30)
	left.add_child(_hp)
	_hp_text = UiKit.label("", UiKit.SIZE_SMALL)
	left.add_child(_hp_text)

	var clock_slot := CenterContainer.new()
	clock_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(clock_slot)
	_clock_box = UiKit.hazard(UiKit.ALERT, UiKit.ALERT, 0.0)
	_clock_box.set_content_margin_all(6)
	_clock_box.content_margin_left = 18
	_clock_box.content_margin_right = 18
	var clock := PanelContainer.new()
	clock.add_theme_stylebox_override("panel", _clock_box)
	clock_slot.add_child(clock)
	_time = UiKit.label("", 64)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.custom_minimum_size = Vector2(96, 0)
	clock.add_child(_time)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	top.add_child(_plate(right))
	_rubble = _right_label(right, "", UiKit.SIZE_HEAD, UiKit.WARN)
	_right_label(right, "CITY DESTROYED", UiKit.SIZE_SMALL, UiKit.MUTED)
	_destruction = UiKit.bar(UiKit.ACCENT, 22, true)
	right.add_child(_destruction)

	var bottom := VBoxContainer.new()
	var bottom_plate := _plate(bottom)
	bottom_plate.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(bottom_plate)
	_ability = UiKit.label("", UiKit.SIZE_HEAD)
	_ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_ability)
	_ultimate = UiKit.label("", UiKit.SIZE_BODY)
	_ultimate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_ultimate)
	_dash = UiKit.label("", UiKit.SIZE_BODY)
	_dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_dash)
	var hint := UiKit.label(
		"Move: WASD / left stick     Pause: Esc / Start", UiKit.SIZE_BODY, UiKit.MUTED
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	refresh()


## A dark broadcast plate behind a HUD group, so it reads over a bright street or a fire.
func _plate(content: Control) -> PanelContainer:
	var plate := PanelContainer.new()
	var box := UiKit.box(Color(UiKit.BG, PLATE_ALPHA), UiKit.BG, 0)
	box.set_content_margin_all(12)
	plate.add_theme_stylebox_override("panel", box)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(content)
	return plate


func _right_label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(l)
	return l


func refresh() -> void:
	_hp.max_value = sim.max_hp
	_hp.value = sim.hp
	_hp_text.text = "%d / %d" % [ceili(sim.hp), ceili(sim.max_hp)]
	_time.text = "%d" % ceili(maxf(0.0, sim.time_left))
	# The last ten seconds: the clock turns from alert red to hazard yellow.
	var hurry := sim.time_left < 10.0
	_clock_box.fill = UiKit.ACCENT if hurry else UiKit.ALERT
	_time.add_theme_color_override("font_color", UiKit.BG if hurry else Color.WHITE)
	_rubble.text = "BIOMASS  %d" % Num.i(floor(sim.rubble))
	_destruction.value = sim.destruction() * 100.0
	var ability: Dictionary = species["ability"]
	var ability_name := str(ability["name"]).to_upper()
	if sim.ability_ready_in <= 0.0:
		_ability.text = "%s  READY  [Space / A]" % ability_name
		_ability.add_theme_color_override("font_color", UiKit.GOOD)
	else:
		_ability.text = "%s  %.1fs" % [ability_name, sim.ability_ready_in]
		_ability.add_theme_color_override("font_color", UiKit.MUTED)
	_ultimate.visible = sim.powers.has_ultimate()
	if sim.ultimate_ready_in <= 0.0:
		_ultimate.text = "ULTIMATE  READY  [E / Y]"
		_ultimate.add_theme_color_override("font_color", UiKit.ACCENT)
	else:
		_ultimate.text = "ULTIMATE  %.0fs" % sim.ultimate_ready_in
		_ultimate.add_theme_color_override("font_color", UiKit.MUTED)
	var dash := sim.body.dash
	_dash.visible = dash.available()
	if dash.ready_in <= 0.0:
		_dash.text = "DASH  READY  [Shift / B]"
		_dash.add_theme_color_override("font_color", UiKit.GOOD)
	else:
		_dash.text = "DASH  %.1fs" % dash.ready_in
		_dash.add_theme_color_override("font_color", UiKit.MUTED)


## The rampage is over (the sim said so): show why, and tell the rest of the game.
func run_over(reason: String) -> void:
	refresh()
	show_end_beat(reason)
	get_node("/root/EventBus").emit_signal("run_ended", result())


## The pause menu's End Rampage: the sim ends the run now (earnings kept), then the end beat.
func _end_now() -> void:
	sim.end("ended")
	run_over("ended")


## The end beat: the reason the rampage ended slams onto the screen while the city keeps
## falling in slow motion. After BEAT_FRAMES (or a confirm once BEAT_MIN_FRAMES have shown, so
## a held attack button cannot skip it by accident) it reports `beat_done`.
func show_end_beat(reason: String) -> void:
	if _beat_frame >= 0:
		return
	_beat_frame = 0
	Engine.time_scale = END_SLOWMO
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.55, 0.25, 0.45)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(flash)
	add_child(flash)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(centre)
	add_child(centre)
	var col := VBoxContainer.new()
	centre.add_child(col)
	var lines: Array = HEADLINES.get(reason, ["RAMPAGE OVER", ""])
	headline = UiKit.label(str(lines[0]), BEAT_SIZE, UiKit.ACCENT)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(headline)
	var sub := UiKit.label(str(lines[1]), UiKit.SIZE_HEAD, UiKit.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	headline.pivot_offset = headline.get_combined_minimum_size() * 0.5
	var tween := create_tween().set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	headline.scale = Vector2.ONE * 2.4
	tween.tween_property(headline, "scale", Vector2.ONE, 0.35)
	tween.parallel().tween_property(flash, "color:a", 0.0, 0.6)


func beat_running() -> bool:
	return _beat_frame >= 0 and not _beat_done


func _process(_delta: float) -> void:
	if not beat_running():
		return
	_beat_frame += 1
	# World hints (float text) never show behind the headline, even one that pops late.
	get_tree().call_group(CityView.FLOAT_TEXT, "queue_free")
	if _beat_frame >= BEAT_FRAMES:
		finish_beat()


## Opens the pause menu and stops the world (the menu runs while paused).
func pause() -> void:
	if sim.over or get_tree().paused:
		return
	var menu := PauseMenu.new()
	menu.sim = sim
	menu.species_id = str(species["id"])
	menu.end_pressed.connect(_end_now)
	_widgets.visible = false
	menu.tree_exited.connect(func() -> void: _widgets.visible = not _beat_done)
	add_child(menu)
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _beat_frame < 0:
		get_viewport().set_input_as_handled()
		pause()
	elif beat_running() and _beat_frame >= BEAT_MIN_FRAMES and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		finish_beat()


## Leaving mid-beat or mid-pause (quit to title) must not leave the world slowed or paused.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


## Ends the end beat now (also the capture tool's skip); only while it is running.
func finish_beat() -> void:
	if not beat_running():
		return
	Engine.time_scale = 1.0
	_beat_done = true
	visible = false  # the report takes over the screen; the city stays behind it
	beat_done.emit(result())
