extends "res://tests/lib/runner.gd"
## Sim suite: the upgrade tree, the city generator and the rampage, all headless and seeded.
## Includes the player-effect fixtures: an upgrade or a species changes what a scripted
## rampage achieves.
##   godot --headless --path . --script tests/run_sim_tests.gd

const SaveScript := preload("res://autoload/save_file.gd")
const SimRooftops := preload("res://tests/lib/sim_rooftops.gd")
const SimBodyContact := preload("res://tests/lib/sim_body_contact.gd")
const DT := 1.0 / 30.0
const MAX_STEPS := 30 * 400


func suite_name() -> String:
	return "Sim"


func run_checks() -> void:
	await _t("_check_data")
	await _t("_check_tree")
	await _t("_check_city")
	await _t("_check_structure")
	await _t("_check_topple_crush")
	await _t("_check_toughness")
	await _t("_check_determinism")
	await _t("_check_upgrade_effects")
	await _t("_check_species_differ")
	await _t("_check_army")
	await _h("SimRooftops", func() -> void: SimRooftops.new(check, _sim, _autoplay).run())
	await _h("SimBodyContact", func() -> void: SimBodyContact.new(check, _sim, _autoplay).run())
	await _t("_check_save_migrate")
	await _t("_check_looks")
	await _t("_check_growth")


func _tree(levels: Dictionary = {}) -> UpgradeTree:
	return UpgradeTree.new(Content.upgrades(), levels)


func _layout(city: Dictionary = Content.section("city")) -> Array[Dictionary]:
	return CityGen.generate(Seeds.make("city", 0), city)


func _sim(
	species_id: String, levels: Dictionary, run_index: int = 0, tuning: Dictionary = {}
) -> RampageSim:
	var species := Content.species_def(species_id)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, _tree(levels))
	var ability: Dictionary = species["ability"]
	var tune := Content.tuning() if tuning.is_empty() else tuning
	var city: Dictionary = tune["city"]
	var sim := RampageSim.new(stats, tune, _layout(city), Seeds.make("army", run_index))
	sim.ability_type = str(ability["type"])
	sim.body.use_species(species_id)
	return sim


## Scripted player: walk to the nearest standing building, use the signature when ready.
func _autoplay(sim: RampageSim, max_steps: int = MAX_STEPS) -> Dictionary:
	var steps := 0
	var target := Vector2(INF, INF)
	while not sim.over and steps < max_steps:
		if steps % 15 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
			move = (target - sim.kaiju_pos).normalized()
		sim.step(DT, move, sim.ability_ready_in <= 0.0)
		steps += 1
	return sim.result()


func _check_data() -> void:
	check(
		Content.species().size() == 3,
		"three species are defined, not %d" % Content.species().size()
	)
	var ids: Array[String] = []
	for def: Dictionary in Content.species():
		ids.append(str(def["id"]))
	check(
		ids == ["reptilian", "insectoid", "cephalopod"],
		"the species are reptilian, insectoid, cephalopod: %s" % [ids]
	)
	var tree := _tree()
	var dangling: Array[String] = []
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var requires: Array = def["requires"]
		var costs: Array = def["cost"]
		for req: String in requires:
			if not tree.defs.has(req):
				dangling.append("%s needs unknown %s" % [id, req])
		if costs.size() != tree.max_level(id):
			dangling.append(
				"%s has %d costs for %d levels" % [id, costs.size(), tree.max_level(id)]
			)
	check(
		dangling.is_empty(),
		"every upgrade has known prerequisites and one cost per level: %s" % [dangling]
	)


func _check_tree() -> void:
	var tree := _tree()
	check(tree.can_buy("claws", 100), "a root upgrade can be bought with enough rubble")
	check(not tree.can_buy("claws", 5), "an upgrade cannot be bought without enough rubble")
	check(not tree.can_buy("stride", 1000), "an upgrade with unmet prerequisites is locked")
	var price := tree.buy("claws", 100)
	check(
		price == 15 and tree.level("claws") == 1,
		"buying claws costs 15 and gives level 1, got %d / %d" % [price, tree.level("claws")]
	)
	check(tree.is_unlocked("stride"), "owning claws unlocks Long Stride")
	var maxed := _tree({"evolve1": 1})
	check(
		(
			maxed.is_maxed("evolve1")
			and maxed.cost("evolve1") == -1
			and maxed.buy("evolve1", 99999) == 0
		),
		"a maxed upgrade has no cost and cannot be bought again"
	)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), _tree({"claws": 2})
	)
	check(
		is_equal_approx(Num.f(stats["stomp_damage"]), 16.0),
		"two levels of claws add 6 stomp power to a reptilian's 10, got %s" % stats["stomp_damage"]
	)
	var clamped := _tree({"claws": 99, "ghost": 3})
	check(
		clamped.level("claws") == 5 and not clamped.levels.has("ghost"),
		"saved levels are clamped to the max and unknown upgrades dropped"
	)


func _check_city() -> void:
	var a := _layout()
	var b := _layout()
	check(
		a.size() > 60 and a == b,
		"the city is the same %d buildings every time from the same seed" % a.size()
	)
	var tiers := {}
	for entry: Dictionary in a:
		tiers[Num.i(entry["tier"])] = true
	check(
		tiers.has(1) and tiers.has(2) and tiers.has(3),
		"the city has towers of at least three tiers: %s" % [tiers.keys()]
	)


func _check_structure() -> void:
	# A floor knocked out from under a block: everything above drops.
	var block := Structure.new(3, 3, 6, 10.0)
	for x: int in 3:
		for z: int in 3:
			block.remove(Vector3i(x, 2, z))
	var parts := block.settle()
	var dropped: Array = parts[0]["cells"] if parts.size() == 1 else []
	check(
		parts.size() == 1 and str(parts[0]["kind"]) == "drop" and dropped.size() == 27,
		"with a floor gone, the 27 chunks above it drop: %s" % [parts.size()]
	)
	# A tower whose base is eaten away on one side tips over toward the missing side.
	var tower := Structure.new(3, 3, 12, 10.0)
	for x: int in 2:
		for z: int in 3:
			tower.remove(Vector3i(x, 0, z))
	var tipping := tower.settle()
	var topples := tipping.size() == 1 and str(tipping[0]["kind"]) == "topple"
	var dir: Vector2i = tipping[0]["dir"] if topples else Vector2i.ZERO
	check(
		topples and dir == Vector2i(-1, 0), "an undermined tower topples toward the gap: %s" % [dir]
	)
	# A tower with a sound base stands.
	var sound := Structure.new(3, 3, 12, 10.0)
	sound.remove(Vector3i(0, 0, 0))
	check(sound.settle().is_empty(), "a tower missing one corner chunk still stands")


## A toppled tower lands across the street and smashes the building it falls on.
func _check_topple_crush() -> void:
	var layout: Array[Dictionary] = [
		{"x": 0.0, "z": 0.0, "w": 3, "d": 3, "h": 14, "tier": 1, "style": 0},
		{"x": -6.0, "z": 0.0, "w": 3, "d": 3, "h": 4, "tier": 1, "style": 1},
	]
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), _tree()
	)
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	var base: Array[Vector3i] = []
	for x: int in 2:
		for z: int in 3:
			base.append(Vector3i(x, 0, z))
	var before := sim.buildings[1].frame.alive_count
	sim.damage_chunks(0, base, 999.0)
	check(
		sim.falls.size() == 1 and sim.falls[0].kind == "topple",
		"breaking the base sets the tower toppling"
	)
	var rubble_before := sim.rubble
	var landed := false
	for i: int in 30 * 5:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "fall_land":
				landed = true
		if landed:
			break
	check(landed, "the toppling tower lands within five seconds")
	check(sim.buildings[1].frame.alive_count < before, "the tower smashes the building it falls on")
	check(sim.rubble > rubble_before, "a toppled tower pays rubble when it lands")


## A tower above the kaiju's size is tougher; the same blow breaks a low building's floor.
func _check_toughness() -> void:
	var small := _sim("reptilian", {})
	var low := -1
	var tall := -1
	for i: int in small.buildings.size():
		if small.buildings[i].tier == 1 and low < 0:
			low = i
		if small.buildings[i].tier == 3 and tall < 0:
			tall = i
	var hit := Num.f(Content.section("city")["chunk_hp"]) * 1.1
	var low_cell: Array[Vector3i] = [Vector3i(0, 0, 0)]
	check(small.damage_chunks(low, low_cell, hit) == 1, "a blow breaks a low building's chunk")
	var tall_cell: Array[Vector3i] = [Vector3i(0, 0, 0)]
	check(
		small.damage_chunks(tall, tall_cell, hit) == 0,
		"the same blow does not break a tower's chunk"
	)


func _check_determinism() -> void:
	var first := _autoplay(_sim("reptilian", {}))
	var second := _autoplay(_sim("reptilian", {}))
	check(first == second, "the same rampage replays identically: %s vs %s" % [first, second])
	check(
		Num.i(first["rubble"]) > 10,
		"a fresh reptilian earns some rubble in its first rampage, got %d" % Num.i(first["rubble"])
	)
	check(
		str(first["reason"]) in ["time", "defeated"],
		"a first rampage ends by time or defeat, got %s" % first["reason"]
	)


func _check_upgrade_effects() -> void:
	var base := _autoplay(_sim("reptilian", {}))
	var claws := _autoplay(_sim("reptilian", {"claws": 5}))
	check(
		Num.f(claws["destruction"]) > Num.f(base["destruction"]) * 1.15,
		(
			"five levels of claws break clearly more of the city (%.3f vs %.3f)"
			% [Num.f(claws["destruction"]), Num.f(base["destruction"])]
		)
	)
	# Thick hide so both runs last to the clock: a defeat would end them at the same moment.
	var rage := _autoplay(_sim("reptilian", {"claws": 1, "hide": 5, "rage": 5}))
	var few := _autoplay(_sim("reptilian", {"claws": 1, "hide": 5}))
	check(
		Num.f(rage["destruction"]) > Num.f(few["destruction"]),
		(
			"a longer rampage destroys more (%.3f vs %.3f)"
			% [Num.f(rage["destruction"]), Num.f(few["destruction"])]
		)
	)
	var evolved := _autoplay(_sim("reptilian", {"claws": 3, "hide": 3, "rage": 3, "evolve1": 1}))
	var unevolved := _autoplay(_sim("reptilian", {"claws": 3, "hide": 3, "rage": 3}))
	check(
		Num.f(evolved["destruction"]) > Num.f(unevolved["destruction"]),
		(
			"evolving destroys more (%.3f vs %.3f)"
			% [Num.f(evolved["destruction"]), Num.f(unevolved["destruction"])]
		)
	)


func _check_species_differ() -> void:
	var results: Array[Dictionary] = []
	for id: String in ["reptilian", "insectoid", "cephalopod"]:
		results.append(_autoplay(_sim(id, {})))
	check(
		results[0] != results[1] and results[1] != results[2] and results[0] != results[2],
		"each species plays out a different rampage: %s" % [results]
	)
	var leap := _sim("insectoid", {})
	var before := leap.kaiju_pos
	leap.step(DT, Vector2.ZERO, true)
	var expected := Num.f(leap.city["leap_distance"]) * leap.body_scale()
	check(
		leap.kaiju_pos.distance_to(before) >= expected * 0.95,
		"the insectoid's Leap Slam carries it its leap distance (%.1f)" % expected
	)
	var ring := _sim("cephalopod", {})
	var reach_ok := ring.ability_reach() > ring.stomp_radius()
	check(reach_ok, "the cephalopod's Tentacle Lash reaches further than its stomp")


func _check_army() -> void:
	var soft := _sim("reptilian", {})
	var armoured := _sim("reptilian", {"hide": 1, "scales": 4})
	for i: int in 30 * 30:
		soft.step(DT, Vector2.ZERO, false)
		armoured.step(DT, Vector2.ZERO, false)
	var soft_loss := soft.max_hp - soft.hp
	var armoured_loss := armoured.max_hp - armoured.hp
	check(
		soft.tanks.size() > 0 and soft_loss > 0.0,
		"standing still, the army arrives and hurts the kaiju (lost %.1f)" % soft_loss
	)
	check(
		armoured_loss < soft_loss,
		"armoured scales cut the damage taken (%.1f vs %.1f)" % [armoured_loss, soft_loss]
	)


func _check_save_migrate() -> void:
	check(
		Num.i(SaveScript.migrate({"version": 1, "rubble": 5}).get("rubble", 0)) == 5,
		"a version 1 save loads"
	)
	check(SaveScript.migrate({"version": 99}).is_empty(), "a save from a newer version is refused")


## Every look (data/looks.json) carries every key presentation reads, and the default exists.
func _check_looks() -> void:
	var keys: Array[String] = [
		"label",
		"name",
		"sky_top",
		"sky_horizon",
		"ambient",
		"sun_color",
		"sun_energy",
		"sun_pitch",
		"fog_color",
		"fog_density",
		"saturation",
		"contrast",
		"glow",
		"voxel_inset",
		"color_noise",
		"crease_strength",
		"crease_radius",
		"crease_depth_step",
		"crease_normal_step",
		"crease_fade_near",
		"crease_fade_far",
		"kaiju_roughness",
		"window_lit",
		"window_glow",
		"accent_glow",
		"kaiju_lift",
		"styles",
		"roof",
		"window",
		"window_lit_color",
		"outskirts",
		"asphalt",
		"lot",
	]
	var missing: Array[String] = []
	for look: Dictionary in Content.looks():
		for key: String in keys:
			if not look.has(key):
				missing.append("%s.%s" % [look["id"], key])
	check(
		Content.looks().size() >= 1 and missing.is_empty(), "every look is complete: %s" % [missing]
	)
	var default_id := str(Content.load_json("res://data/looks.json")["default"])
	check(
		str(Content.look()["id"]) == default_id,
		"the default look %s is the one in use" % default_id
	)


## The kaiju starts young, smaller than the city's towers, and grows with every upgrade level
## and much more with each evolution (director, 2026-10-16).
func _check_growth() -> void:
	var young := _sim("reptilian", {}).body_scale()
	var grown := _sim("reptilian", {"claws": 5, "hide": 5}).body_scale()
	var evolved := _sim("reptilian", {"claws": 5, "hide": 5, "rage": 1, "evolve1": 1}).body_scale()
	check(
		young < 0.6 and young < grown and grown < evolved,
		"growth: young %.2f < upgraded %.2f < evolved %.2f" % [young, grown, evolved]
	)
	var tallest := 0
	for b: RampageSim.Building in _sim("reptilian", {}).buildings:
		tallest = maxi(tallest, b.height)
	check(
		young * 10.0 < tallest * 0.5,
		"a young kaiju (%.1f tall) is dwarfed by the towers (%d)" % [young * 10.0, tallest]
	)
