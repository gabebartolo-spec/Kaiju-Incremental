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
				if l.text.to_upper().contains(word) and l.get_parent() is not GridContainer:
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
