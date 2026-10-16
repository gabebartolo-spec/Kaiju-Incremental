extends "res://tests/lib/runner.gd"
## Sim suite: the upgrade tree, the city generator and the rampage, all headless and seeded.
## Includes the player-effect fixtures: an upgrade or a species changes what a scripted
## rampage achieves.
##   godot --headless --path . --script tests/run_sim_tests.gd

const SaveScript := preload("res://autoload/save_system.gd")
const DT := 1.0 / 30.0
const MAX_STEPS := 30 * 400


func suite_name() -> String:
	return "Sim"


func run_checks() -> void:
	_check_data()
	_check_tree()
	_check_city()
	_check_tier_gate()
	_check_determinism()
	_check_upgrade_effects()
	_check_species_differ()
	_check_army()
	_check_save_migrate()
	_check_looks()


func _tree(levels: Dictionary = {}) -> UpgradeTree:
	return UpgradeTree.new(Content.upgrades(), levels)


func _layout() -> Array[Dictionary]:
	return CityGen.generate(Seeds.make("city", 0), Content.section("city"))


func _sim(species_id: String, levels: Dictionary, run_index: int = 0) -> RampageSim:
	var species := Content.species_def(species_id)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, _tree(levels))
	var ability: Dictionary = species["ability"]
	var sim := RampageSim.new(stats, Content.tuning(), _layout(), Seeds.make("army", run_index))
	sim.ability_type = str(ability["type"])
	return sim


## Scripted player: walk to the nearest building it can topple, use the signature when ready.
func _autoplay(sim: RampageSim) -> Dictionary:
	var steps := 0
	while not sim.over and steps < MAX_STEPS:
		var best := Vector2.ZERO
		var best_d := INF
		for b: RampageSim.Building in sim.buildings:
			if b.layers > 0 and b.tier <= sim.size_tier():
				var d := sim.kaiju_pos.distance_to(Vector2(b.x, b.z))
				if d < best_d:
					best_d = d
					best = Vector2(b.x, b.z)
		var move := Vector2.ZERO
		if best_d < INF and best_d > sim.stomp_radius() * 0.6:
			move = (best - sim.kaiju_pos).normalized()
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
		price == 12 and tree.level("claws") == 1,
		"buying claws costs 12 and gives level 1, got %d / %d" % [price, tree.level("claws")]
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


func _check_tier_gate() -> void:
	var small := _sim("reptilian", {})
	var grown := _sim("reptilian", {"claws": 1, "hide": 1, "rage": 1, "evolve1": 1})
	var low := -1
	var tall := -1
	for i: int in small.buildings.size():
		if small.buildings[i].tier == 1 and low < 0:
			low = i
		if small.buildings[i].tier == 2 and tall < 0:
			tall = i
	var low_hit := small.buildings[low].layer_hp * 2.0
	check(
		small.damage_building(low, low_hit) == 2,
		"a small kaiju topples two layers of a low building with two layers' damage"
	)
	var tall_hit := small.buildings[tall].layer_hp * 3.0
	var small_lost := small.damage_building(tall, tall_hit)
	var grown_lost := grown.damage_building(tall, tall_hit)
	check(
		small_lost == 0 and grown_lost == 3,
		(
			"a mid-rise shrugs off a small kaiju (%d layers) but falls to an evolved one (%d layers)"
			% [small_lost, grown_lost]
		)
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
		Num.i(claws["rubble"]) > Num.i(base["rubble"]) * 1.3,
		(
			"five levels of claws earn clearly more rubble (%d vs %d)"
			% [Num.i(claws["rubble"]), Num.i(base["rubble"])]
		)
	)
	var rage := _autoplay(_sim("reptilian", {"claws": 1, "hide": 1, "rage": 5}))
	var few := _autoplay(_sim("reptilian", {"claws": 1, "hide": 1}))
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
		Num.i(evolved["rubble"]) > Num.i(unevolved["rubble"]),
		(
			"evolving earns more rubble (%d vs %d)"
			% [Num.i(evolved["rubble"]), Num.i(unevolved["rubble"])]
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
	check(leap.kaiju_pos.distance_to(before) > 5.0, "the insectoid's Leap Slam moves it forward")
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
		Content.looks().size() == 3 and missing.is_empty(), "three complete looks: %s" % [missing]
	)
	var default_id := str(Content.load_json("res://data/looks.json")["default"])
	check(str(Content.look()["id"]) == default_id, "the default look %s is the one in use" % default_id)
