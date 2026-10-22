extends "res://tests/lib/taskforce_suite.gd"
## The Anti Kaiju Taskforce, agents only (Taskforce, TaskforceFrost; D-137, D-139, D-141, D-143,
## D-145): none in the young city, squads of 3-4 from the map edge and never more than 12 alive;
## an agent dies when its perch collapses or a claw swipe swats it in the air (and pays biomass);
## the railgun's line tracks, locks shortly before the shot and hits for 8% of max health only
## if the kaiju stays in the lock (a late step dodges it); frost refreshes and never stacks and
## the dash shatters it; the same seed replays the same events; and the player-effect fixture
## "taskforce.agents": the same run with the Taskforce off leaves the kaiju healthier.
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0.


func suite_name() -> String:
	return "Taskforce"


func run_checks() -> void:
	await _t("_check_stage_gate")
	await _t("_check_arrival_and_cap")
	await _t("_check_perch_death")
	await _t("_check_railgun_hit")
	await _t("_check_railgun_dodge")
	await _t("_check_frost")
	await _t("_check_swat")
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
	var closed := _adolescent()  # the city has not fallen enough yet: nobody comes
	closed.chunks_total = 10000000
	closed.time_left = 1.0e9
	closed.army_units.taskforce.cfg["after_chunks"] = 1000000000
	_run(closed, 60.0)
	check(closed.army_units.taskforce.agents.is_empty(), "no squad before the city has fallen")


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
	check(
		sim.rubble > before + Num.f(tf.cfg["rubble"]) * sim.stat("rubble_mult") - 0.001,
		"the kill pays biomass (%.1f -> %.1f)" % [before, sim.rubble]
	)


func _check_railgun_hit() -> void:
	var sim := _adolescent()
	_open(sim)
	_perched(sim, true)
	var rail: Dictionary = sim.army_units.taskforce.cfg["railgun"]
	var aim := 0.0
	var hit: Dictionary = {}
	var steps := 0
	for _n: int in roundi(4.0 / DT):
		var events := sim.step(DT, Vector2.ZERO, false)
		steps += 1
		if not _first(events, "railgun_aim").is_empty():
			aim = steps * DT
		hit = _first(events, "railgun_hit")
		if not hit.is_empty():
			aim = steps * DT - aim
			break
	check(not hit.is_empty(), "a perched agent with the kaiju in range fires its railgun")
	check(
		(
			absf(Num.f(hit.get("damage", 0.0)) - sim.max_hp * Num.f(rail["share"])) < 0.0001
			and Num.f(rail["share"]) == 0.08
		),
		(
			"the railgun costs 8%% of max health (%.2f of %.2f)"
			% [Num.f(hit.get("damage", 0.0)), sim.max_hp]
		)
	)
	check(
		aim >= Num.f(rail["aim_seconds"]) - DT and aim <= Num.f(rail["aim_seconds"]) + DT,
		(
			"the aiming line is up %.2f s before the hit (aim_seconds %.1f)"
			% [aim, Num.f(rail["aim_seconds"])]
		)
	)


func _check_railgun_dodge() -> void:
	var late := _adolescent()
	_open(late)
	_perched(late, true)
	var late_events := _run(late, 4.0, "railgun_locked")
	var locked := _first(late_events, "railgun_locked")
	check(not locked.is_empty(), "the aiming line locks shortly before the shot")
	var way := _free_way(late)
	check(way != Vector2.ZERO, "the kaiju has a clear way to step")
	var after := _run(late, 1.0, "", way)  # a late step, after the lock
	check(
		_first(after, "railgun_hit").is_empty() and not _first(after, "railgun_missed").is_empty(),
		"a step after the lock dodges the shot: %s" % [_types(after)]
	)
	var early := _adolescent()
	_open(early)
	_perched(early, true)
	var tracked := _run(early, 0.5, "", _free_way(early))  # a step while the line is tracking
	tracked.append_array(_run(early, 3.0))
	check(
		not _first(tracked, "railgun_hit").is_empty(),
		"a step before the lock is followed by the line and still hit: %s" % [_types(tracked)]
	)


func _check_frost() -> void:
	var sim := _adolescent()
	_open(sim)
	var frost := sim.army_units.taskforce.frost
	var seconds := Num.f(frost.cfg["seconds"])
	check(frost.mult() == 1.0, "no frost, no slow")
	frost.launch(0, Vector3.ZERO)
	var events := _run(sim, Num.f(frost.cfg["flight_s"]) + 0.2)
	check(not _first(events, "frost_hit").is_empty(), "a grenade at the feet freezes the kaiju")
	check(
		is_equal_approx(frost.mult(), Num.f(frost.cfg["slow_mult"])) and frost.frost_left > 0.0,
		"the ice slows it (x%.2f)" % frost.mult()
	)
	_run(sim, seconds * 0.6)
	var left := frost.frost_left
	frost.launch(1, Vector3.ZERO)
	var again := _run(sim, Num.f(frost.cfg["flight_s"]) + 0.1)
	var hit := _first(again, "frost_hit")
	var refreshed: bool = hit.get("refreshed", false)
	check(
		refreshed and frost.frost_left > left and frost.frost_left <= seconds,
		(
			"a second grenade refreshes the ice to %.1f s, never beyond one grenade's %.1f s"
			% [frost.frost_left, seconds]
		)
	)
	check(
		is_equal_approx(frost.mult(), Num.f(frost.cfg["slow_mult"])),
		"several grenades never stack the slow"
	)
	var thaw := _run(sim, seconds + 0.5)
	var cracked := _first(thaw, "frost_cracked")
	check(
		str(cracked.get("why", "")) == "thaw" and frost.mult() == 1.0,
		"left alone the ice thaws and cracks off: %s" % [cracked]
	)
	frost.launch(2, Vector3.ZERO)
	_run(sim, Num.f(frost.cfg["flight_s"]) + 0.1)
	check(frost.frost_left > 0.0, "iced again for the dash test")
	var dashed := sim.step(DT, Vector2(0, -1), false, DASH_BUTTON)
	var shattered := _first(dashed, "frost_cracked")
	check(
		str(shattered.get("why", "")) == "dash" and frost.frost_left == 0.0,
		"the dash shatters the ice early: %s" % [shattered]
	)
	frost.launch(3, Vector3.ZERO)
	var way := _free_way(sim)
	var missed := _run(sim, Num.f(frost.cfg["flight_s"]) + 0.2, "", way)  # it walks off
	check(
		_first(missed, "frost_hit").is_empty() and frost.frost_left == 0.0,
		"a grenade that lands where the kaiju no longer stands does nothing"
	)


func _check_swat() -> void:
	var sim := _adolescent("reptilian", {"evolve1": 1, "claws": 5})
	_open(sim)
	var tf := sim.army_units.taskforce
	var bs := sim.body_scale()
	var mid := (Num.f(sim.powers_cfg["swipe_near"]) + Num.f(sim.powers_cfg["swipe_far"])) * 0.5 * bs
	var agent := tf.place_agent(_roof(sim, tf), Vector3i.ZERO)
	agent.state = Taskforce.HOP  # mid-air, in front of the kaiju, within the swipe's reach
	agent.pos = sim.kaiju_pos + sim.facing * mid
	agent.y = 1.0
	agent.from = Vector3(agent.pos.x, agent.y, agent.pos.y)
	agent.to = agent.from
	agent.flight = 1000.0
	agent.flight_len = 1000.0
	var before := sim.rubble
	var events := _run(sim, 8.0, "agent_died")
	var died := _first(events, "agent_died")
	check(not _first(events, "swipe").is_empty(), "the claw swipe came round")
	check(
		not died.is_empty() and str(died["kind"]) == "swatted" and Num.i(died["agent"]) == agent.id,
		"a claw swipe swats an agent out of the air: %s" % [died]
	)
	check(died.has("wall") and died.has("hit"), "it spins into a nearby wall: %s" % [died])
	check(not tf.agents.has(agent) and tf.kills == 1, "the swatted agent is gone, one kill")
	check(sim.rubble > before, "the swat pays biomass")
	var other := _adolescent()
	var holding := _perched(other, false)
	other.army_units.taskforce.swat(func(_p: Vector2, _r: float) -> float: return 1.0, 1000.0)
	check(
		other.army_units.taskforce.agents.has(holding),
		"an agent perched on a roof is not swatted: only one in the air is"
	)


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


## The player-effect fixture "taskforce.agents": the same seeded run, Taskforce on and off.
func _check_effect() -> void:
	var on := _adolescent()
	var off := _adolescent()
	_open(on)
	_open(off)
	off.army_units.taskforce.cfg["max_by_tier"] = [0, 0, 0, 0]
	var hurt_on := _hurt_in(on, 90.0)
	var hurt_off := _hurt_in(off, 90.0)
	check(
		hurt_on > hurt_off,
		(
			"with the Taskforce on the kaiju takes more damage in 90 s (%.1f vs %.1f, max hp %.1f)"
			% [hurt_on, hurt_off, on.max_hp]
		)
	)
