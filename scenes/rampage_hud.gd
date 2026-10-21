class_name RampageHud
extends CanvasLayer
## The rampage HUD, kept minimal (b2-10..13, research 15): the boxed clock at the top with a thin
## city-destroyed meter under it, biomass as one boxless figure bottom right, the breath (with
## dash and the ultimate beside it) as rings bottom centre, health as a red edge vignette, and
## the controls on a card at the start of the first rampage only. Everything sits inside the TV
## title-safe area; no text under 24 px. Then the end beat (why it ended, big). Reads the sim;
## reports the beat's end through `beat_done`. Sizes and timings: tuning "ui".

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
## The biomass figure snaps to the true value once this close.
const ROLL_SNAP := 0.5
## The clock's digits keep at least this width, so the box does not jump as they change.
const CLOCK_MIN_WIDTH := 96.0
## The first-run card ignores keys for this long, so the key that started the run is not "any key".
const CARD_MIN_SHOWN := 0.6

var sim: RampageSim
var species: Dictionary
## The crowd (null with no streets): only the view counts the civilians it crushed.
var street: StreetLife
## The end beat's headline (read by the flow suite and the captures).
var headline: Label
## The HUD's parts (read by the flow suite and the captures).
var biomass: Label
var breath_ring: HudRing
var dash_ring: HudRing
var ultimate_ring: HudRing
## The key (or pad button) under each ring; it follows the last device used.
var breath_key: Label
var dash_key: Label
var ultimate_key: Label
var vignette: HurtVignette
## The first-run controls card (null once it has gone, or when it was seen before).
var controls_card: ControlsCard
var _time: Label
var _clock: PanelContainer
var city_meter: ProgressBar
## Everything on the HUD: hidden while a dialog (pause, the report) is up.
var _widgets: Control
var _clock_box: HazardBox
var _hud: Dictionary
var _shown_biomass := 0.0
var _last_biomass := 0.0
var _last_second := -1
var _pop: Tween
var _dash_column: Control
var _ultimate_column: Control
var _pad := false
var _card_left := 0.0
var _card_age := 0.0
var _card_fading := false
var _beat_frame := -1
var _beat_done := false


func _init(p_sim: RampageSim, p_species: Dictionary, p_street: StreetLife) -> void:
	sim = p_sim
	species = p_species
	street = p_street
	_hud = UiKit.ui()["hud"]


## The sim's result plus what only the view counts: the civilians it crushed.
func result() -> Dictionary:
	return sim.result().merged({"civilians": street.civilians_killed() if street != null else 0})


func _ready() -> void:
	_widgets = Control.new()
	UiKit.full_rect(_widgets)
	_widgets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_widgets)
	vignette = HurtVignette.new(sim)
	_widgets.add_child(vignette)
	var safe := MarginContainer.new()
	UiKit.full_rect(safe)
	UiKit.safe_area(safe)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_widgets.add_child(safe)
	safe.add_child(_build_clock())
	safe.add_child(_build_biomass())
	safe.add_child(_build_rings())
	if not PlayerSettings.controls_seen:
		_show_controls(safe)
	_shown_biomass = sim.rubble
	_last_biomass = sim.rubble
	refresh()


## The boxed clock (b2-10: "the timer at the top is good") and the city meter under it.
func _build_clock() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_box = UiKit.hazard(UiKit.ALERT, UiKit.ALERT, 0.0)
	_clock_box.set_content_margin_all(6)
	_clock_box.content_margin_left = 18
	_clock_box.content_margin_right = 18
	_clock = PanelContainer.new()
	_clock.add_theme_stylebox_override("panel", _clock_box)
	_clock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_clock.resized.connect(func() -> void: _clock.pivot_offset = _clock.size / 2.0)
	col.add_child(_clock)
	_time = UiKit.label("", Num.i(_hud["clock_size"]))
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.custom_minimum_size = Vector2(CLOCK_MIN_WIDTH, 0)
	_clock.add_child(_time)
	var meter: Array = _hud["meter_size"]
	city_meter = UiKit.bar(UiKit.ACCENT, Num.i(meter[1]), true)
	city_meter.custom_minimum_size.x = Num.f(meter[0])
	city_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(city_meter)
	return col


## Biomass, one boxless outlined figure in the bottom right (b2-10).
func _build_biomass() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	col.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var word := UiKit.label("BIOMASS", Num.i(_hud["biomass_label_size"]), UiKit.TEXT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(word)
	biomass = UiKit.label("0", Num.i(_hud["biomass_size"]), UiKit.ACCENT)
	biomass.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	biomass.resized.connect(func() -> void: biomass.pivot_offset = biomass.size)
	col.add_child(biomass)
	return col


## The breath ring bottom centre, where the health bar was (b2-12, b2-13); dash and the
## ultimate in smaller rings either side, each shown only when the kaiju has it (a missing one
## keeps its place, unseen, so the breath ring stays dead centre). A key cap under each ring
## names its button; every column is the same width so the breath column is centred.
func _build_rings() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_SHRINK_END
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Num.i(_hud["ring_gap"]))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := Num.f(_hud["ring_radius"])
	var small := Num.f(_hud["ring_small_radius"])
	var w := Num.f(_hud["ring_width"])
	dash_ring = HudRing.new(HudRing.Icon.DASH, small, w)
	breath_ring = HudRing.new(HudRing.Icon.BREATH, big, w)
	ultimate_ring = HudRing.new(HudRing.Icon.ULTIMATE, small, w)
	_dash_column = _ring_column(dash_ring)
	row.add_child(_dash_column)
	row.add_child(_ring_column(breath_ring))
	_ultimate_column = _ring_column(ultimate_ring)
	row.add_child(_ultimate_column)
	dash_key = _dash_column.get_child(1).get_child(0)
	breath_key = row.get_child(1).get_child(1).get_child(0)
	ultimate_key = _ultimate_column.get_child(1).get_child(0)
	_set_keys()
	return row


## A ring with its key cap under it, in a column of the shared width.
func _ring_column(ring: HudRing) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(Num.f(_hud["ring_column"]), 0)
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.size_flags_vertical = Control.SIZE_SHRINK_END
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(ring)
	var cap := PanelContainer.new()
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiKit.box(Color(UiKit.BG, 0.8), UiKit.MUTED, 2)
	box.set_content_margin_all(2)
	box.content_margin_left = 12
	box.content_margin_right = 12
	cap.add_theme_stylebox_override("panel", box)
	var key := UiKit.label("", Num.i(_hud["key_size"]), UiKit.TEXT)
	key.set_meta("keycap", true)
	cap.add_child(key)
	col.add_child(cap)
	return col


## The key caps' text for the last device used: keyboard keys, or the pad's buttons.
func _set_keys() -> void:
	breath_key.text = "A" if _pad else "SPACE"
	dash_key.text = "B" if _pad else "SHIFT"
	ultimate_key.text = "Y" if _pad else "E"


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var key := event is InputEventKey
	if (pad or key) and pad != _pad and not (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.5):
		_pad = pad
		_set_keys()
	var pressed := (
		(key and (event as InputEventKey).pressed and not (event as InputEventKey).echo)
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	)
	if pressed and controls_card != null and _card_age > CARD_MIN_SHOWN:
		dismiss_controls()


## The controls, once (b2-10): a card on the left that fades after tuning "ui" controls_card
## seconds; Settings > CONTROLS has them for good.
func _show_controls(safe: Control) -> void:
	controls_card = ControlsCard.new(true)
	controls_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	controls_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var place := MarginContainer.new()
	place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place.add_theme_constant_override("margin_top", Num.i(UiKit.ui()["controls_card"]["first_run_top"]))
	place.add_child(controls_card)
	safe.add_child(place)
	_card_left = Num.f(UiKit.ui()["controls_card"]["seconds"])
	PlayerSettings.mark_controls_seen()


## Fades the controls card out now (its time is up; the capture tool calls it too).
func dismiss_controls() -> void:
	if controls_card == null or _card_fading:
		return
	_card_fading = true
	var card := controls_card
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 0.0, Num.f(UiKit.ui()["controls_card"]["fade_s"]))
	tween.tween_callback(card.get_parent().queue_free)
	tween.tween_callback(func() -> void: controls_card = null)


func refresh() -> void:
	var second := ceili(maxf(0.0, sim.time_left))
	_time.text = "%d" % second
	# The last seconds: the clock turns from alert red to hazard yellow and pulses each second.
	var hurry := sim.time_left < Num.f(_hud["hurry_seconds"])
	_clock_box.fill = UiKit.ACCENT if hurry else UiKit.ALERT
	_time.add_theme_color_override("font_color", UiKit.BG if hurry else Color.WHITE)
	if hurry and second != _last_second and _last_second >= 0 and not sim.over:
		_clock.scale = Vector2.ONE * Num.f(_hud["hurry_pulse_scale"])
		create_tween().tween_property(_clock, "scale", Vector2.ONE, Num.f(_hud["hurry_pulse_s"]))
	_last_second = second
	city_meter.value = sim.destruction() * 100.0
	var gain := sim.rubble - _last_biomass
	_last_biomass = sim.rubble
	if gain >= Num.f(_hud["biomass_pop_gain"]):
		_pop_biomass()
	# The sim's own floor on the cooldown (rampage_sim.gd), so the ring matches the button.
	breath_ring.set_ratio(1.0 - sim.ability_ready_in / maxf(0.5, sim.stat("ability_cooldown")))
	_ultimate_column.modulate.a = 1.0 if sim.powers.has_ultimate() else 0.0
	var ult_cd := Num.f(sim.powers_cfg["ultimate_cooldown"])
	ultimate_ring.set_ratio(1.0 - sim.ultimate_ready_in / maxf(0.001, ult_cd))
	var dash := sim.body.dash
	_dash_column.modulate.a = 1.0 if dash.available() else 0.0
	if dash.available():
		dash_ring.set_ratio(1.0 - dash.ready_in / maxf(0.001, Num.f(dash.cfg["cooldown"])))


func _process(delta: float) -> void:
	_roll_biomass(delta)
	if controls_card != null and not _card_fading:
		_card_left -= delta
		_card_age += delta
		if _card_left <= 0.0:
			dismiss_controls()
	if not beat_running():
		return
	_beat_frame += 1
	# World hints (float text) never show behind the headline, even one that pops late.
	get_tree().call_group(CityView.FLOAT_TEXT, "queue_free")
	if _beat_frame >= BEAT_FRAMES:
		finish_beat()


## The figure rolls toward the true biomass (R 15.5) rather than ticking digit by digit.
func _roll_biomass(delta: float) -> void:
	var rate := Num.f(_hud["biomass_roll_rate"])
	_shown_biomass = lerpf(_shown_biomass, sim.rubble, 1.0 - exp(-rate * delta))
	if absf(sim.rubble - _shown_biomass) < ROLL_SNAP:
		_shown_biomass = sim.rubble
	biomass.text = "%d" % Num.i(floor(_shown_biomass))


## A big gain pops the figure once (one pop at a time: biomass ticks all the time).
func _pop_biomass() -> void:
	if _pop != null and _pop.is_running():
		return
	biomass.scale = Vector2.ONE * Num.f(_hud["biomass_pop_scale"])
	_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(biomass, "scale", Vector2.ONE, Num.f(_hud["biomass_pop_s"]))


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


## Opens the pause menu and stops the world (the menu runs while paused).
func pause() -> void:
	if sim.over or get_tree().paused:
		return
	var menu := PauseMenu.new()
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
