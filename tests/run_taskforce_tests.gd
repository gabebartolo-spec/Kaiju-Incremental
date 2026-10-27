extends "res://tests/lib/taskforce_suite.gd"
## The Anti Kaiju Taskforce, agents only (D-137, D-139, D-141, D-143, D-152): none in the
## young city, squads of 3-4 from the edge, 12 alive at most; a death (perch collapse) pays a
## tank's worth; same seed, same events; and the player-effect fixture "taskforce.agents". Its
## weapons (railgun, frost, claw swat) are in tests/run_taskforce_weapons_tests.gd.
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0.


func suite_name() -> String:
	return "Taskforce"


func run_checks() -> void:
	await _t("_check_stage_gate")
	await _t("_check_arrival_and_cap")
	await _t("_check_perch_death")
	await _t("_check_perch_fallback")
	await _t("_check_determinism")
	await _t("_check_effect")


func _check_stage_gate() -> void:
	var young := _sim("reptilian", {}, 0, CityGrowth.tuning_for(Content.tuning(), 1))
	_open(young)
	_run(young, 60.0)
	check(
		young.army_units.taskforce.agents.is_empty() and young.army_units.taskforce.cap() == 0,
		"the young city has no Taskforce (cap 0, none arrived in 60 s)"
	)
	var adolescent := _adolescent()
	check(adolescent.army_units.taskforce.cap() == 12, "the adolescent city allows 12 alive")
	var closed := _adolescent()  # no rampage time in the city yet: army-only (D-160)
	closed.chunks_total = 10000000
	closed.time_left = 1.0e9
	closed.chunks_destroyed = 5000
	_run(closed, 60.0)
	check(closed.army_units.taskforce.agents.is_empty(), "the first rampages bring no squad")


func _check_arrival_and_cap() -> void:
	var sim := _adolescent()
	_open(sim)
	var tf := sim.army_units.taskforce
	sim.hp = sim.max_hp
	var deployed := 0
	var most := 0
	var edge_ok := true
	var arrivals := 0
	for _n: int in roundi(180.0 / DT):
		var events := sim.step(DT, Vector2.ZERO, false)
		sim.hp = sim.max_hp
		for event: Dictionary in events:
			deployed += 1 if str(event["type"]) == "taskforce_deployed" else 0
		most = maxi(most, tf.agents.size())
		if tf.squad_sizes.size() > arrivals:
			arrivals = tf.squad_sizes.size()
			var newest := tf.agents[tf.agents.size() - 1]
			var ring := sim.arena_half + Num.f(tf.cfg["edge_inset"])
			edge_ok = edge_ok and absf(maxf(absf(newest.pos.x), absf(newest.pos.y)) - ring) < 6.0
	var sizes_ok := tf.squad_sizes.all(func(n: int) -> bool: return n >= 3 and n <= 4)
	check(deployed == 1, "taskforce_deployed fires once, for the first squad (%d)" % deployed)
	check(sizes_ok and arrivals >= 3, "squads of 3-4 keep coming: %s" % [tf.squad_sizes])
	check(most <= 12 and most >= 9, "never more than 12 alive, and it fills to the cap (%d)" % most)
	check(edge_ok, "each squad comes in at the map edge, just past the arena")
	var hurried := _adolescent()
	hurried.chunks_destroyed = 40000
	var slow := _adolescent()
	slow.chunks_destroyed = 200
	check(
		hurried.army_units.taskforce.interval() < slow.army_units.taskforce.interval(),
		"the more of the city has fallen, the shorter the wait for the next squad"
	)


func _check_perch_death() -> void:
	var sim := _adolescent()
	_open(sim)
	var tf := sim.army_units.taskforce
	var agent := _perched(sim, false)
	var before := sim.rubble
	_run(sim, 1.0)
	check(tf.agents.has(agent), "an agent holds its roof while the chunk under it stands")
	var b := sim.buildings[agent.building]
	var cells: Array[Vector3i] = [agent.cell]
	sim.damage_chunks(agent.building, cells, 1.0e6)
	check(not b.frame.alive(agent.cell), "the chunk under the agent was broken")
	var events := _run(sim, 0.2)
	var died := _first(events, "agent_died")
	check(
		not died.is_empty() and str(died["kind"]) == "perch_collapse",
		"the agent dies when its perch collapses: %s" % [died]
	)
	check(tf.agents.is_empty() and tf.kills == 1, "the dead agent is gone from the list, one kill")
	check(Num.i(sim.result()["agents"]) == 1, "the result counts the agent kill")
	check(
		sim.rubble > before + tf.kill_pay() - 0.001,
		"the kill pays biomass (%.1f -> %.1f)" % [before, sim.rubble]
	)
	check(
		absf(tf.kill_pay() - Num.f(sim.army["tank_rubble"]) * sim.stat("rubble_mult")) < 0.001,
		"a kill pays a tank's worth of biomass (%.1f, D-152)" % tf.kill_pay()
	)
	var adult := _sim("reptilian", {}, 0, CityGrowth.tuning_for(Content.tuning(), 3))
	check(
		adult.army_units.taskforce.kill_pay() > tf.kill_pay(),
		"a kill pays more in the adult city, as a tank does"
	)


## No tall roof is in the perch band at the map edge (nearest ~48 away): squads still perch.
func _check_perch_fallback() -> void:
	var sim := _adolescent()
	_open(sim)
	var tf := sim.army_units.taskforce
	_run(sim, 25.0)
	var held := tf.agents.filter(func(a: Taskforce.Agent) -> bool: return a.building >= 0)
	check(
		not tf.agents.is_empty() and held.size() == tf.agents.size(),
		"every agent has a roof to go to (%d of %d)" % [held.size(), tf.agents.size()]
	)
	var perched := tf.agents.filter(
		func(a: Taskforce.Agent) -> bool:
			return a.state == Taskforce.PERCH or a.state == Taskforce.AIM
	)
	check(not perched.is_empty(), "squads land on the nearest roofs (%d perched)" % perched.size())


func _check_determinism() -> void:
	var first := _fingerprint()
	var second := _fingerprint()
	check(
		first == second and first != "", "the same seed replays the same Taskforce, event for event"
	)
	check(first.contains("taskforce_deployed"), "the replayed run did bring a squad in")


## The event names, and where every agent was, over a 60 s run.
func _fingerprint() -> String:
	var sim := _adolescent()
	_open(sim)
	sim.hp = sim.max_hp
	var out := PackedStringArray()
	for n: int in roundi(60.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if (
				str(event["type"]).begins_with("taskforce")
				or str(event["type"]).begins_with("rail")
			):
				out.append("%d:%s" % [n, event["type"]])
		sim.hp = sim.max_hp
		if n % 60 == 0:
			for agent: Taskforce.Agent in sim.army_units.taskforce.agents:
				out.append(
					"%d,%d:%.2f,%.2f,%.2f" % [n, agent.id, agent.pos.x, agent.pos.y, agent.y]
				)
	return ",".join(out)


## The player-effect fixture "taskforce.agents": the same seeded run twice, the player walking into
## the city with the Taskforce held back in both, then smashing where it stands with the Taskforce
## let in on one (healed each step so it reads damage taken). Nothing else differs between the
## runs, so the whole difference in damage is the railgun hits.
func _check_effect() -> void:
	var on := _adolescent()
	var off := _adolescent()
	for sim: RampageSim in [on, off]:
		_open(sim)
		sim.army_units.taskforce.cfg["max_by_tier"] = [0, 0, 0, 0]
		_play(sim, 20.0)
	check(on.kaiju_pos == off.kaiju_pos, "both runs walked in alike")
	on.army_units.taskforce.cfg["max_by_tier"] = [0, 12, 12, 12]
	var with_tf := _play(on, 90.0, false)
	var without := _play(off, 90.0, false)
	var shots := Num.i(with_tf["railgun"])
	check(
		Num.f(with_tf["hurt"]) > Num.f(without["hurt"]),
		(
			"with the Taskforce on the kaiju takes more damage in 90 s (%.1f vs %.1f, max hp %.1f)"
			% [Num.f(with_tf["hurt"]), Num.f(without["hurt"]), on.max_hp]
		)
	)
	check(
		shots > 0 and Num.i(without["railgun"]) == 0,
		"the difference is railgun hits (%d on, %d off)" % [shots, without["railgun"]]
	)
	var worth := shots * on.max_hp * 0.08
	check(
		absf(Num.f(with_tf["hurt"]) - Num.f(without["hurt"]) - worth) < 0.01,
		"and only those: %d x 8%% of %.0f = %.1f" % [shots, on.max_hp, worth]
	)
