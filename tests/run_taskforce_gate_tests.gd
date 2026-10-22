extends "res://tests/lib/taskforce_suite.gd"
## The Taskforce's gates and numbers (D-160, D-161), beside tests/run_taskforce_tests.gd: it joins
## once about 3 minutes of rampage time in the adolescent city are carried in (the save keeps the
## clock and a reload carries on); armour softens a railgun hit like a tank shell's; a perch lost
## mid-aim cancels the shot; ice halves the walk.
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0.


func suite_name() -> String:
	return "TaskforceGate"


func run_checks() -> void:
	await _t("_check_first_arrival")
	await _t("_check_city_clock")
	await _t("_check_armour")
	await _t("_check_mid_aim")
	await _t("_check_ice_walk")


func _check_first_arrival() -> void:
	var need := Num.f(Content.section("taskforce")["first_arrival"]["city_seconds"])
	check(need == 180.0, "about 3 minutes of rampage time in the adolescent city (%.0f s)" % need)
	var short := _adolescent()
	_open(short)
	short.army_units.taskforce.carried = need - 1.0
	_run(short, 40.0)
	check(short.army_units.taskforce.agents.is_empty(), "one second short: still army-only")
	var due := _adolescent()
	_open(due)
	due.army_units.taskforce.carried = need
	_run(due, 40.0)
	check(not due.army_units.taskforce.agents.is_empty(), "at the time the squads join the rampage")


func _check_city_clock() -> void:
	var young := _sim("reptilian", {}, 0, CityGrowth.tuning_for(Content.tuning(), 1))
	young.time_left = 1.0e9
	_run(young, 10.0)
	check(Num.f(young.result()["city_seconds"]) == 0.0, "time in the baby city does not count")
	var first := _adolescent()
	first.time_left = 1.0e9
	_run(first, 10.0)
	var kept := Num.f(first.result()["city_seconds"])
	check(absf(kept - 10.0) < 0.05, "a rampage adds its seconds there (%.2f)" % kept)
	var save := SaveFile.new_save("reptilian")
	check(Num.f(save["city_seconds"]) == 0.0, "a new save starts the clock at 0")
	var old: Dictionary = SaveFile.migrate({"version": 2})
	check(Num.f(old["city_seconds"]) == 0.0, "an older save loads with 0")
	save["city_seconds"] = kept
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(save))
	var back: Dictionary = SaveFile.migrate(parsed)
	check(Num.f(back["city_seconds"]) == kept, "save and reload keep the clock")
	var next := _adolescent()
	next.time_left = 1.0e9
	next.army_units.taskforce.carried = Num.f(back["city_seconds"])
	_run(next, 5.0)
	var total := Num.f(next.result()["city_seconds"])
	check(absf(total - (kept + 5.0)) < 0.05, "the next rampage carries on from it (%.2f)" % total)


func _check_armour() -> void:
	var hurt: Array[float] = []
	for armour: float in [0.0, 3.0, 1000.0]:
		var sim := _adolescent()
		_open(sim)
		sim.stats["armor"] = armour
		_perched(sim, true)
		var hit := _first(_run(sim, 4.0, "railgun_hit"), "railgun_hit")
		hurt.append(Num.f(hit.get("damage", -1.0)))
	var full := _adolescent().max_hp * 0.08
	var least := Num.f(_adolescent().army["min_damage"])
	check(is_equal_approx(hurt[0], full), "no armour: the full 8%% (%.2f)" % hurt[0])
	check(is_equal_approx(hurt[1], full - 3.0), "armour 3 softens it like a shell (%.2f)" % hurt[1])
	check(is_equal_approx(hurt[2], least), "never below the army's minimum (%.2f)" % hurt[2])


func _check_mid_aim() -> void:
	var sim := _adolescent()
	_open(sim)
	var agent := _perched(sim, true)
	_run(sim, 4.0, "railgun_aim")
	check(agent.state == Taskforce.AIM, "the agent is aiming")
	var cells: Array[Vector3i] = [agent.cell]
	sim.damage_chunks(agent.building, cells, 1.0e6)
	var events := _run(sim, 3.0)
	var died := _first(events, "agent_died")
	check(
		not died.is_empty() and _first(events, "railgun_hit").is_empty(),
		"a roof lost mid-aim knocks the gunner over and no shot comes: %s" % [_types(events)]
	)


func _check_ice_walk() -> void:
	var reach: Array[float] = []
	for iced: bool in [false, true]:
		var sim := _adolescent()
		_open(sim)
		var way := _face_free_way(sim)
		if iced:
			sim.army_units.taskforce.frost.frost_left = 4.0
		var from := sim.kaiju_pos
		_run(sim, 1.5, "", way)
		reach.append(from.distance_to(sim.kaiju_pos))
	var share := reach[1] / maxf(reach[0], 0.001)
	check(
		reach[0] > 3.0 and share > 0.4 and share < 0.6,
		"iced, the kaiju walks half as far (%.1f vs %.1f)" % [reach[1], reach[0]]
	)
