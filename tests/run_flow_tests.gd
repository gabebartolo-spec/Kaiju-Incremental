extends "res://tests/lib/runner.gd"
## Flow suite: every screen builds headless and the rampage presentation survives a played
## rampage to its results panel without a script error.
##   godot --headless --path . --script tests/run_flow_tests.gd

const RAMPAGE_FRAMES := 60 * 75


func suite_name() -> String:
	return "Flow"


func run_checks() -> void:
	await _check_species_select()
	await _check_upgrade_screen()
	await _check_rampage()


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
		rampage.sim.layers_destroyed > 0,
		"the autoplayed kaiju destroys buildings (%d layers)" % rampage.sim.layers_destroyed
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
