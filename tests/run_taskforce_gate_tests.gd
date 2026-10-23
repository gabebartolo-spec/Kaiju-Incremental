extends "res://tests/lib/taskforce_suite.gd"
## The Taskforce's gates and numbers (D-160, D-161), beside tests/run_taskforce_tests.gd: it joins
## once about 3 minutes of rampage time in the adolescent city are carried in (the save keeps the
## clock and a reload carries on); armour softens a railgun hit like a tank shell's; a perch lost
## mid-aim cancels the shot; ice halves the walk; one squad's railgun shots are staggered (D-166).
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0.


func suite_name() -> String:
	return "TaskforceGate"


func run_checks() -> void:
	await _t("_check_first_arrival")
	await _t("_check_city_clock")
	await _t("_check_armour")
	await _t("_check_mid_aim")
	await _t("_check_ice_walk")
	await _t("_check_chewed_top")
	await _t("_check_frost_radius")
	await _t("_check_volley")


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
	check(absf(Num.f(back["city_seconds"]) - kept) < 0.001, "save and reload keep the clock")
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


## A city whose tops were chewed away still gives a squad somewhere to land: the highest chunk that
## stands, not only the roof (a roof lost left every agent hovering).
func _check_chewed_top() -> void:
	var sim := _adolescent()
	_open(sim)
	var floors := Num.i(sim.army_units.taskforce.cfg["perch_min_height"])
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.height < floors:
			continue
		var cells: Array[Vector3i] = []
		for x: int in b.w:
			for z: int in b.d:
				cells.append(Vector3i(x, b.height - 1, z))
		sim.damage_chunks(i, cells, 1.0e6)
	var agent := Taskforce.Agent.new()
	var spot := sim.army_units.taskforce.perch.pick(agent, [])
	check(not spot.is_empty(), "with every roof chewed off an agent still finds a perch")
	if spot.is_empty():
		return
	var b := sim.buildings[Num.i(spot[0])]
	var cell: Vector3i = spot[1]
	check(
		b.frame.alive(cell) and cell.y < b.height - 1,
		"it is a lower chunk that stands: %s" % [cell]
	)


## The grenade ices a kaiju that stands where it was thrown and misses one that kept walking, even
## slowly (D-161: moving dodges them).
func _check_frost_radius() -> void:
	var sim := _adolescent()
	_open(sim)
	var frost := sim.army_units.taskforce.frost
	var slow_walk := Num.f(Content.section("kaiju")["speed"]) * 0.5 * Num.f(frost.cfg["flight_s"])
	frost.grenades.append([0.0, sim.kaiju_pos + Vector2(slow_walk, 0.0)])
	_run(sim, 0.1)
	check(frost.frost_left == 0.0, "a slow walker (%.1f u off the spot) is not iced" % slow_walk)
	frost.grenades.append([0.0, sim.kaiju_pos])
	_run(sim, 0.1)
	check(frost.frost_left > 0.0, "a kaiju standing still is")


## D-166 "Stagger the shots": one squad never lands more than 2 hits in a second, which leaves the
## dash time to save the kaiju (D-161). A squad of five is planted lined up (railguns ready, one
## roof, the kaiju standing in range) beside a second squad of three; every shot is timed and each
## squad's worst 1 s window counted. With `squad_gap` at 0 (the old rule) the same fixture lands all
## five of the first squad inside one second.
func _check_volley() -> void:
	var rail: Dictionary = Content.section("taskforce")["railgun"]
	var gap := Num.f(rail["squad_gap"])
	check(gap > 0.5, "a gap over half a second keeps a squad to 2 shots a second (%.2f s)" % gap)
	var old := _volley(0.0)
	var lined_up: Array = old[0]
	check(
		_worst_second(lined_up) == 5,
		"without the gap the lined-up squad lands all five at once (%d)" % _worst_second(lined_up)
	)
	var shots := _volley(gap)
	var first: Array = shots[0]
	var second: Array = shots[1]
	check(first.size() == 5 and second.size() == 3, "every gunner still fires: %s" % [shots])
	check(
		_worst_second(first) <= 2 and _worst_second(second) <= 2,
		(
			"a squad lands at most 2 hits in any second (%d and %d)"
			% [_worst_second(first), _worst_second(second)]
		)
	)
	var spaced := true
	for n: int in range(1, first.size()):
		spaced = spaced and Num.f(first[n]) - Num.f(first[n - 1]) >= gap - 0.001
	check(spaced, "the squad's shots are at least %.1f s apart: %s" % [gap, first])
	check(
		absf(Num.f(first[0]) - Num.f(second[0])) < gap,
		"the gap is kept per squad: the second squad's first shot is not held up by the first"
	)


## The times, in seconds, of every shot a planted squad of five (index 0) and a squad of three
## (index 1) fires over 10 s with the kaiju standing, the squads' `squad_gap` set to `gap`; each
## squad's times in order.
func _volley(gap: float) -> Array:
	var sim := _adolescent()
	sim.time_left = 1.0e9
	var tf := sim.army_units.taskforce
	tf.cfg["railgun"]["squad_gap"] = gap
	var squad_of := {}
	for squad: int in 2:
		tf.squad_sizes.append(5 - squad * 2)
		for _n: int in 5 - squad * 2:
			squad_of[_perched(sim, true).id] = squad
	var times: Array = [[], []]
	for n: int in roundi(10.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) in ["railgun_hit", "railgun_missed"]:
				var list: Array = times[squad_of[Num.i(event["agent"])]]
				list.append((n + 1) * DT)
		sim.hp = sim.max_hp
	return times


## The most shots inside any 1 s window (both ends counted) of these times.
func _worst_second(times: Array) -> int:
	var worst := 0
	for start: float in times:
		worst = maxi(
			worst,
			times.filter(func(t: float) -> bool: return t >= start and t <= start + 1.0).size()
		)
	return worst
