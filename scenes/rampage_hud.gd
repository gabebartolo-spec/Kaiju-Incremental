class_name RampageHud
extends CanvasLayer
## The rampage HUD, as little as it can be so the kaiju and the city's fall fill the screen
## (director 2026-10-21): clock and the threat bar (D-259, the bar is the threat) on top, biomass
## bottom right, the breath, dash and ultimate as three rings bottom left, health as a red edge
## vignette, the controls on a card at the first rampage's start only; all inside the TV
## title-safe area, no text under 24 px. The news crawl slides up on big moments (RampageNews).
## Then the end beat (why it ended, big). Reads the sim; reports it by `beat_done`. Tuning "ui".

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
## The headline starts this far from the top: in the top third, the kaiju stays in view (px).
const BEAT_TOP := 64
## The biomass figure snaps to the true value once this close.
const ROLL_SNAP := 0.5
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
var vignette: HurtVignette
## The first-run controls card (null once it has gone, or when it was seen before).
var controls_card: ControlsCard
## The clock and threat bar (hidden while the end beat's headline is up).
var clock: HudClock
## The news crawl's big moments (RampageNews).
var news: RampageNews
var photo: Callable  ## Rampage.photo_mode: the pause menu's photo mode (unset in HUD suites)
## Everything on the HUD: hidden while a dialog (pause, the report) is up.
var _widgets: Control
var _hud: Dictionary
var _shown_biomass := 0.0
var _last_biomass := 0.0
var _pop: Tween
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


## The sim's result plus what only the view counts: the civilians it crushed and those who fled.
func result() -> Dictionary:
	return sim.result().merged(HudCounts.of(street))


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
	news = RampageNews.new(sim)
	_widgets.add_child(news)
	clock = HudClock.new(sim, _hud)
	safe.add_child(clock)
	safe.add_child(_lifted(_build_biomass(), true))
	safe.add_child(_lifted(_build_rings(), false))
	if not PlayerSettings.controls_seen:
		_show_controls(safe)
	_shown_biomass = sim.rubble
	_last_biomass = sim.rubble
	refresh()


## `part` raised so its visible bottom edge sits tuning "ui" hud bottom_margin up from the screen's
## edge: the rings and the biomass figure share one margin. `figure`: the part ends in the biomass
## number, whose letters sit above the bottom of their box by the font's descent less the outline.
func _lifted(part: Control, figure: bool) -> Control:
	var holder := MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_END
	holder.size_flags_horizontal = part.size_flags_horizontal
	part.size_flags_horizontal = Control.SIZE_FILL
	part.size_flags_vertical = Control.SIZE_FILL
	var lift := Num.f(_hud["bottom_margin"]) - UiKit.safe_margin().y
	if figure:
		lift -= figure_gap()
	holder.add_theme_constant_override("margin_bottom", maxi(0, roundi(lift)))
	holder.add_child(part)
	return holder


## How far the biomass number's visible bottom (outline included) sits above its box's bottom (px).
func figure_gap() -> float:
	var size := Num.i(_hud["biomass_size"])
	var font := ThemeDB.fallback_font
	var face := UiKit.font_for(size)
	if face != null:
		font = face
	else:
		var themed := biomass.get_theme_font("font") if biomass != null else null
		font = themed if themed != null else ThemeDB.fallback_font
	return font.get_descent(size) - UiKit.outline_px(size)


## Where the biomass number's visible bottom is on screen (y), and the rings' (the ui suite).
func figure_bottom() -> float:
	return biomass.get_global_rect().end.y - figure_gap()


func rings_bottom() -> float:
	# The ring's own size, not its popped scale: its centre does not move.
	return breath_ring.get_global_rect().get_center().y + breath_ring.size.y / 2.0


## Biomass, one boxless outlined figure in the bottom right (b2-10).
func _build_biomass() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	col.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var word := UiKit.label("BIOMASS", UiKit.SIZE_BODY, UiKit.TEXT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(word)
	biomass = UiKit.label("0", Num.i(_hud["biomass_size"]), UiKit.ACCENT)
	biomass.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	biomass.resized.connect(func() -> void: biomass.pivot_offset = biomass.size)
	col.add_child(biomass)
	return col


## Three small rings in the bottom left corner: the breath, dash and the ultimate, each an icon
## with a charge ring that fills clockwise. Dash and the ultimate show only when the kaiju has
## them (a missing one keeps its place, unseen, so the others never shift).
func _build_rings() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_SHRINK_END
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", Num.i(_hud["ring_gap"]))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := Num.f(_hud["ring_radius"])
	var small := Num.f(_hud["ring_small_radius"])
	var w := Num.f(_hud["ring_width"])
	breath_ring = HudRing.new(HudRing.Icon.BREATH, big, w)
	dash_ring = HudRing.new(HudRing.Icon.DASH, small, w)
	ultimate_ring = HudRing.new(HudRing.Icon.ULTIMATE, small, w)
	for ring: HudRing in [breath_ring, dash_ring, ultimate_ring]:
		ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ring)
	return row


func _input(event: InputEvent) -> void:
	var key := event is InputEventKey and (event as InputEventKey).pressed
	var pad := event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed
	if (key or pad) and controls_card != null and _card_age > CARD_MIN_SHOWN:
		dismiss_controls()


## The controls, once (b2-10): a card on the left that fades after tuning "ui" controls_card
## seconds; Settings > CONTROLS has them for good.
func _show_controls(safe: Control) -> void:
	controls_card = ControlsCard.new(true)
	# Bottom left, clear of the kaiju (screen centre) and of the rings (bottom centre).
	controls_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	controls_card.size_flags_vertical = Control.SIZE_SHRINK_END
	var place := MarginContainer.new()
	place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	place.size_flags_vertical = Control.SIZE_SHRINK_END
	# Above the rings in the corner.
	place.add_theme_constant_override(
		"margin_bottom", Num.i(UiKit.ui()["controls_card"]["first_run_lift"])
	)
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
	clock.refresh()
	var gain := sim.rubble - _last_biomass
	_last_biomass = sim.rubble
	if gain >= Num.f(_hud["biomass_pop_gain"]):
		_pop_biomass()
	# The sim's own floor on the cooldown (rampage_sim.gd), so the ring matches the button.
	breath_ring.set_ratio(1.0 - sim.ability_ready_in / maxf(0.5, sim.stat("ability_cooldown")))
	ultimate_ring.modulate.a = 1.0 if sim.powers.has_ultimate() else 0.0
	var ult_cd := Num.f(sim.powers_cfg["ultimate_cooldown"])
	ultimate_ring.set_ratio(1.0 - sim.ultimate_ready_in / maxf(0.001, ult_cd))
	var dash := sim.body.dash
	dash_ring.modulate.a = 1.0 if dash.available() else 0.0
	if dash.available():
		dash_ring.set_ratio(1.0 - dash.ready_in / maxf(0.001, dash.cooldown()))


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


## The pause menu's End Rampage: he dies (D-265): his overload plays out (DeathOverload), and the
## sim's run_over brings the end beat once the shards are down. Earnings are kept.
func _end_now() -> void:
	sim.end("ended")


## The end beat: the reason the rampage ended slams onto the screen while the city keeps falling
## at normal speed (D-259: slow motion only when a landmark falls, LandmarkSlowmo; time stays 1.0
## here). After BEAT_FRAMES (or a confirm once BEAT_MIN_FRAMES have shown, so a held attack button
## cannot skip it by accident) it reports `beat_done`.
func show_end_beat(reason: String) -> void:
	if _beat_frame >= 0:
		return
	_beat_frame = 0
	clock.visible = false
	news.muted = true
	news.visible = false
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.55, 0.25, 0.45 * PlayerSettings.flash_scale())  # Reduce flashing
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(flash)
	add_child(flash)
	var top := MarginContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(top)
	top.add_theme_constant_override("margin_top", BEAT_TOP)
	add_child(top)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(col)
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


## The clock's number (read by the ui suite).
func clock_label() -> Label:
	return clock.time


## True while the clock and its city meter are on screen.
func clock_visible() -> bool:
	return clock.is_visible_in_tree()


func beat_running() -> bool:
	return _beat_frame >= 0 and not _beat_done


## Opens the pause menu and stops the world (the menu runs while paused).
func pause() -> void:
	if sim.over or sim.death.active() or get_tree().paused:
		return
	var menu := PauseMenu.new(sim, str(species["id"]), photo)
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


## Leaving mid-pause (quit to title) must not leave the world slowed or paused.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


## Ends the end beat now (also the capture tool's skip); only while it is running.
func finish_beat() -> void:
	if not beat_running():
		return
	_beat_done = true
	visible = false  # the report takes over the screen; the city stays behind it
	beat_done.emit(result())
