extends "res://tests/lib/runner.gd"
## Flow suite: every screen builds headless and the rampage presentation survives a played
## rampage to its results panel without a script error.
##   godot --headless --path . --script tests/run_flow_tests.gd

const RAMPAGE_FRAMES := 60 * 75
const POWER_FRAMES := 60 * 45
## Upgrades whose look the power checks prove: heavy stomps, recharge, scales, regeneration.
const UPGRADED := {
	"claws": 3,
	"hide": 1,
	"scales": 2,
	"evolve1": 1,
	"rage": 1,
	"regen": 2,
	"sig_power": 2,
	"sig_recharge": 4
}


func suite_name() -> String:
	return "Flow"


func run_checks() -> void:
	await _check_species_select()
	await _check_upgrade_screen()
	await _check_rampage()
	await _check_powers("reptilian", "breath", UPGRADED)
	await _check_powers("insectoid", "leap", {})
	await _check_powers("cephalopod", "lash", {})


func _check_species_select() -> void:
	var select := SpeciesSelect.new()
	root.add_child(select)
	await process_frame
	var buttons := select.find_children("*", "Button", true, false)
	check(buttons.size() == 3, "the species screen offers three choices, found %d" % buttons.size())
	var picked: Array[String] = []
	select.chosen.connect(func(id: String) -> void: picked.append(id))
	var second: Button = buttons[1]
	second.pressed.emit()
	check(picked == ["insectoid"], "choosing the second card picks the insectoid: %s" % [picked])
	select.queue_free()
	await process_frame


func _check_upgrade_screen() -> void:
	var tree := UpgradeTree.new(Content.upgrades())
	var screen := UpgradeScreen.new()
	screen.setup(tree, 30, Content.species_def("reptilian"), Content.section("kaiju"))
	root.add_child(screen)
	await process_frame
	var buttons := screen.find_children("*", "Button", true, false)
	check(
		buttons.size() == tree.order.size() + 1, "the tree shows a button per upgrade plus Rampage"
	)
	var claws: Button = null
	for node: Node in buttons:
		var b: Button = node
		if b.text.begins_with("Sharpened Claws"):
			claws = b
	check(claws != null, "Sharpened Claws is on the tree")
	if claws != null:
		claws.pressed.emit()
		check(
			tree.level("claws") == 1 and screen.rubble == 18,
			"pressing Sharpened Claws buys it for 12 (rubble %d)" % screen.rubble
		)
	screen.queue_free()
	await process_frame


func _check_rampage() -> void:
	var rampage := Rampage.new()
	var species := Content.species_def("cephalopod")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	rampage.set_autoplay(true)
	var results: Array[Dictionary] = []
	rampage.finished.connect(func(r: Dictionary) -> void: results.append(r))
	root.add_child(rampage)
	var frames := 0
	while not rampage.sim.over and frames < RAMPAGE_FRAMES:
		await physics_frame
		frames += 1
	check(rampage.sim.over, "an autoplayed rampage ends within %d frames" % RAMPAGE_FRAMES)
	check(
		rampage.sim.chunks_destroyed > 0,
		"the autoplayed kaiju destroys buildings (%d chunks)" % rampage.sim.chunks_destroyed
	)
	await process_frame
	var go: Button = null
	for node: Node in rampage.find_children("*", "Button", true, false):
		var b: Button = node
		if b.text.begins_with("EVOLVE"):
			go = b
	check(go != null, "the results panel offers EVOLVE")
	if go != null:
		go.pressed.emit()
	check(
		results.size() == 1 and Num.i(results[0]["rubble"]) >= 0,
		"EVOLVE reports the rampage result"
	)
	rampage.queue_free()
	await process_frame


## Each signature attack plays its own effect; the upgraded kaiju also shows its upgrades
## (cracking stomps, ready pulse, glancing shells, healing motes) and a plain one does not crack
## the street.
func _check_powers(species_id: String, kind: String, levels: Dictionary) -> void:
	var species := Content.species_def(species_id)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	var played := rampage.ability_fx.played
	var frames := 0
	var want: Array[String] = [kind]
	if not levels.is_empty():
		want.append_array(["cracks", "ready", "deflect", "regen"])
	while frames < POWER_FRAMES and not rampage.sim.over:
		await physics_frame
		frames += 1
		if want.all(func(k: String) -> bool: return played.has(k)):
			break
	check(played.has(kind), "%s's signature plays its %s effect: %s" % [species_id, kind, played])
	if levels.is_empty():
		if species_id == "cephalopod":
			check(not played.has("cracks"), "an unupgraded kaiju's stomps do not crack the street")
	else:
		for k: String in ["cracks", "ready", "deflect", "regen"]:
			check(played.has(k), "the upgraded %s shows %s: %s" % [species_id, k, played])
	rampage.queue_free()
	await process_frame
