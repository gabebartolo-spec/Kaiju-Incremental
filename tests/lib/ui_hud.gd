extends RefCounted
## The UI suite's HUD checks (tests/run_ui_tests.gd): a RampageHud over a real sim (city seed 0),
## stepped by hand. Minimal (b2-10, research 15): no text under 24 px, no controls text, no HP
## bar, everything inside the title-safe area, the boxed clock at the top, biomass boxless in the
## bottom right, the breath ring bottom centre and filling with the cooldown (b2-12), health as
## a vignette that widens as HP falls, beats low and flashes on a hit (b2-13), and the controls
## card once (b2-10).

const CANVAS := Vector2i(1920, 1080)
const MIN_TEXT := 24
## Frames of a fixed step to let the vignette settle.
const SETTLE := 120
const DT := 1.0 / 60.0

var t: SceneTree
var check: Callable


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	var window := t.root.size
	t.root.size = CANVAS
	PlayerSettings.controls_seen = false
	var sim := _sim()
	var hud := RampageHud.new(sim, Content.species_def("reptilian"), null)
	t.root.add_child(hud)
	await t.process_frame
	await t.process_frame
	_layout(hud)
	_card(hud)
	_ring(hud, sim)
	_vignette(hud, sim)
	_meter(hud, sim)
	await _keys(hud)
	await _beat(hud)
	hud.queue_free()
	var again := RampageHud.new(sim, Content.species_def("reptilian"), null)
	t.root.add_child(again)
	await t.process_frame
	check.call(again.controls_card == null, "the controls card shows once: not on the next rampage")
	again.queue_free()
	await t.process_frame
	t.root.size = window


func _sim() -> RampageSim:
	var tuning := Content.tuning()
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(tuning, 1, Seeds.make("city", 0))
	return RampageSim.new(stats, CityGrowth.tuning_for(tuning, 1), layout, Seeds.make("army", 0))


func _layout(hud: RampageHud) -> void:
	var view := t.root.get_visible_rect()
	var m := UiKit.safe_margin()
	var safe := view.grow_individual(-m.x, -m.y, -m.x, -m.y)
	var small: Array[String] = []
	var outside: Array[String] = []
	var said: Array[String] = []
	for node: Node in hud.find_children("*", "Control", true, false):
		var c: Control = node
		if not c.is_visible_in_tree() or c is HurtVignette or c.get_parent() is ProgressBar:
			continue
		if c.get_parent() == hud or c.get_class() == "MarginContainer":
			continue
		if not safe.grow(1.0).encloses(c.get_global_rect()):
			outside.append("%s %s" % [c.get_class(), c.get_global_rect()])
		if c is Label:
			var l: Label = c
			if l.get_theme_font_size("font_size") < MIN_TEXT:
				small.append(l.text)
			for word: String in ["WASD", "SPACE", "SHIFT", "/ ", "HP"]:
				var keycap: bool = l.get_meta("keycap", false)
				if l.text.to_upper().contains(word) and l.get_parent() is not GridContainer and not keycap:
					said.append(l.text)
	check.call(small.is_empty(), "no HUD text under %d px: %s" % [MIN_TEXT, small])
	check.call(outside.is_empty(), "the HUD sits inside the TV title-safe area: %s" % [outside])
	check.call(said.is_empty(), "the HUD shows no controls or health text: %s" % [said])
	var bars := hud.find_children("*", "ProgressBar", true, false)
	check.call(
		bars.size() == 1, "one meter on the HUD (the city's), no health bar: %d" % bars.size()
	)
	var at := hud.biomass.get_global_rect().get_center()
	var boxed := false
	var up: Node = hud.biomass.get_parent()
	while up != hud:
		boxed = boxed or up is PanelContainer
		up = up.get_parent()
	check.call(
		at.x > view.size.x * 0.75 and at.y > view.size.y * 0.75 and not boxed,
		"biomass is one boxless figure in the bottom right (%s, boxed %s)" % [at, boxed]
	)
	var ring := hud.breath_ring.get_global_rect().get_center()
	check.call(
		absf(ring.x - view.size.x / 2.0) < 8.0 and ring.y > view.size.y * 0.8,
		"the breath ring sits bottom centre (%s)" % [ring]
	)


func _card(hud: RampageHud) -> void:
	var card := hud.controls_card
	check.call(
		card != null and card.is_visible_in_tree() and PlayerSettings.controls_seen,
		"the first rampage shows the controls card and remembers it was seen"
	)
	if card == null:
		return
	var texts: Array[String] = []
	for node: Node in card.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	check.call(
		texts.has("Dash") and texts.has("Shift") and texts.has("Move"),
		"the card lists the controls, dash included: %s" % [texts]
	)
	var rows := card.find_children("*", "GridContainer", true, false)
	var count := 0
	if not rows.is_empty():
		count = (rows[0] as GridContainer).get_child_count() / 3 - 1
	check.call(count == 3, "the first-run card has 3 rows (move, signature, dash): %d" % count)
	check.call(
		texts.any(func(x: String) -> bool: return x.to_upper().contains("ANY KEY")),
		"the first-run card says to press any key: %s" % [texts]
	)
	var view := t.root.get_visible_rect()
	check.call(
		absf(card.get_global_rect().get_center().x - view.size.x / 2.0) < 8.0
		and card.get_global_rect().position.y > hud.city_meter.get_global_rect().end.y,
		"the card is centred below the timer and its meter (%s)" % [card.get_global_rect()]
	)
	var full: Array[String] = []
	for entry: Array in PlayerSettings.CONTROLS:
		full.append(str(entry[2]))
	check.call(
		not full.has("Keyboard only"), "the pad column has no 'Keyboard only' text: %s" % [full]
	)


func _ring(hud: RampageHud, sim: RampageSim) -> void:
	var cd := maxf(0.5, sim.stat("ability_cooldown"))
	sim.ability_ready_in = cd * 0.5
	hud.refresh()
	var half := hud.breath_ring.ratio
	sim.ability_ready_in = 0.0
	hud.refresh()
	check.call(
		is_equal_approx(half, 0.5) and hud.breath_ring.is_ready() and hud.breath_ring.scale.x > 1.0,
		(
			"the breath ring fills with the cooldown (%.2f at half) and pops when ready (%.2f)"
			% [half, hud.breath_ring.scale.x]
		)
	)


func _vignette(hud: RampageHud, sim: RampageSim) -> void:
	var v := hud.vignette
	var widths: Array[float] = []
	var beats: Array[bool] = []
	for share: float in [1.0, 0.6, 0.2]:
		sim.hp = sim.max_hp * share
		for _i: int in SETTLE:
			v.step(DT)
		widths.append(v.width)
		beats.append(v.beating())
	check.call(
		widths[0] < 0.001 and widths[1] > widths[0] and widths[2] > widths[1],
		"the hurt vignette is gone at full health and widens as health falls: %s" % [widths]
	)
	check.call(
		beats == [false, false, true], "the heart beats only when health is low: %s" % [beats]
	)
	sim.hp = sim.max_hp
	for _i: int in SETTLE:
		v.step(DT)
	var calm := v.strength
	sim.hp = sim.max_hp * 0.95
	v.step(DT)
	check.call(
		v.strength > calm + 0.2 and v.width > 0.1,
		"a hit flashes the screen edge (%.2f -> %.2f)" % [calm, v.strength]
	)


## Critic r1 item 2: the city meter is a real gauge (big enough to read, fills with the share
## destroyed), the hurt vignette peaks at about half its old opacity.
func _meter(hud: RampageHud, sim: RampageSim) -> void:
	sim.chunks_total = 100
	sim.chunks_destroyed = 35
	hud.refresh()
	var meter: ProgressBar = hud.city_meter
	check.call(
		absf(meter.value - 35.0) < 0.5 and meter.size.y >= 16.0 and meter.size.x >= 300.0,
		"the city meter is %s and reads 35%% when 35%% is destroyed (value %.1f)" % [meter.size, meter.value]
	)
	var peak := 0.0
	sim.hp = sim.max_hp * 0.2
	for _i: int in SETTLE:
		hud.vignette.step(DT)
		peak = maxf(peak, hud.vignette.strength)
	sim.hp = sim.max_hp
	check.call(peak <= 0.45, "the hurt vignette peaks at about half the old opacity (%.2f)" % peak)
	sim.chunks_destroyed = 0


## Critic r1 item 2: a key (or pad button) under each ring, 24 px or more, following the last
## device used.
func _keys(hud: RampageHud) -> void:
	var names := {"breath_key": ["Space", "A"], "dash_key": ["Shift", "B"], "ultimate_key": ["E", "Y"]}
	var rings := {"breath_key": hud.breath_ring, "dash_key": hud.dash_ring, "ultimate_key": hud.ultimate_ring}
	for key: String in names:
		var l: Label = hud.get(key)
		var ring: Control = rings[key]
		check.call(
			l != null and l.text.to_upper() == str(names[key][0]).to_upper()
			and l.get_theme_font_size("font_size") >= MIN_TEXT
			and l.get_global_rect().position.y >= ring.get_global_rect().get_center().y,
			"%s shows %s under its ring at %d px or more" % [key, names[key][0], MIN_TEXT]
		)
	hud.call("_input", InputEventJoypadButton.new())
	await t.process_frame
	var pad: Label = hud.get("dash_key")
	check.call(pad != null and pad.text.to_upper() == "B", "the dash key turns to the pad's B after a pad press")
	hud.call("_input", InputEventKey.new())


## Critic r1 item 6: the end beat's headline and its line sit in the top third, so the kaiju and
## the city it is wrecking stay in view.
func _beat(hud: RampageHud) -> void:
	hud.show_end_beat("time")
	await t.create_timer(0.8, true, false, true).timeout
	var view := t.root.get_visible_rect()
	var box := hud.headline.get_global_rect()
	var parent: Control = hud.headline.get_parent()
	var low := parent.get_global_rect().end.y
	hud.finish_beat()
	check.call(
		low <= view.size.y / 3.0 + 1.0 and box.position.y >= 0.0,
		"the end beat sits in the top third (ends at %.0f of %.0f)" % [low, view.size.y]
	)
