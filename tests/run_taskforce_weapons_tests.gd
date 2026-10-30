extends "res://tests/lib/taskforce_suite.gd"
## The Anti Kaiju Taskforce's weapons (D-145, D-152): the railgun tracks, locks and hits
## for 8% of max health only if the kaiju stays (a late step dodges it); frost refreshes, never
## stacks, and the dash shatters it; a claw swipe swats an agent out of the air. The agents
## themselves are in tests/run_taskforce_tests.gd (the same set-up, tests/lib/taskforce_suite.gd).
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0.


func suite_name() -> String:
	return "TaskforceWeapons"


func run_checks() -> void:
	await _t("_check_railgun_hit")
	await _t("_check_railgun_dodge")
	await _t("_check_frost")
	await _t("_check_swat")


func _check_railgun_hit() -> void:
	var sim := _adolescent()
	_open(sim)
	var agent := _perched(sim, true)
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
	check(
		is_equal_approx(Num.f(hit.get("share", 0.0)), 0.08),
		"the hit carries its 8%% share of max health, for the colour fringe (D-145): %s" % [hit]
	)
	agent.wait = 1.0e9  # it holds its roof (its hop would take it past the railgun's range here)
	var next := _run(sim, 10.0)  # it fires about every 12 s (D-152)
	check(
		_aims_by(next, agent.id).is_empty() and Num.f(rail["cooldown"]) == 12.0,
		"the same agent does not aim again within 10 s of its shot"
	)
	next = _run(sim, 8.0)
	check(not _first(next, "railgun_aim").is_empty(), "it aims again once its 12 s are up")


func _check_railgun_dodge() -> void:
	var late := _adolescent()
	_open(late)
	_street_start(late)  # the 1.5x city sets the bare start in the ring's lots
	var way := _face_free_way(late)  # settled on a clear way, so a step needs no turn
	check(way != Vector2.ZERO, "the kaiju has a clear way to step")
	_perched(late, true)
	var locked := _first(_run(late, 4.0, "railgun_locked"), "railgun_locked")
	check(not locked.is_empty(), "the aiming line locks shortly before the shot")
	var from := late.kaiju_pos
	# A late step after the lock, until just past the stage's lock (D-402: grown walk-offs ease in)
	var after := _run(late, late.army_units.taskforce.volley.lock_seconds() + 0.25, "", way)
	check(
		_first(after, "railgun_hit").is_empty() and not _first(after, "railgun_missed").is_empty(),
		"a step after the lock dodges the shot: %s" % [_types(after)]
	)
	var rail: Dictionary = late.army_units.taskforce.cfg["railgun"]
	check(
		from.distance_to(late.kaiju_pos) > Num.f(rail["hit_radius"]) + 1.0,
		"the step really left the lock behind (%.1f from it)" % from.distance_to(late.kaiju_pos)
	)
	var still := _adolescent()
	_open(still)
	_face_free_way(still)
	_perched(still, true)
	check(
		not _first(_run(still, 4.0), "railgun_hit").is_empty(),
		"a kaiju that stays put is hit (the dodge needs the step)"
	)
	var early := _adolescent()
	_open(early)
	_face_free_way(early)
	_perched(early, true)
	var tracked := _run(early, 0.5, "", way)  # a step while the line is tracking
	tracked.append_array(_run(early, 3.0))
	check(
		not _first(tracked, "railgun_hit").is_empty(),
		"a step before the lock is followed by the line and still hit: %s" % [_types(tracked)]
	)


func _check_frost() -> void:
	var sim := _adolescent()
	_street_start(sim)
	_open(sim)
	var way := _face_free_way(sim)
	var frost := sim.army_units.taskforce.frost
	var seconds := Num.f(frost.cfg["seconds"])
	check(frost.mult() == 1.0, "no frost, no slow")
	var halves := Num.f(frost.cfg["slow_mult"]) == 0.5
	check(seconds == 4.0 and halves, "frost halves speed for 4 s (D-152)")
	frost.launch(0, Vector3.ZERO)
	var events := _run(sim, Num.f(frost.cfg["flight_s"]) + 0.2)
	check(not _first(events, "frost_hit").is_empty(), "a grenade at the feet freezes the kaiju")
	check(
		is_equal_approx(frost.mult(), Num.f(frost.cfg["slow_mult"])) and frost.frost_left > 0.0,
		"the ice slows it (x%.2f)" % frost.mult()
	)
	var iced := sim.powers.speed_mult()
	var ice := frost.frost_left
	frost.frost_left = 0.0
	check(
		is_equal_approx(iced, sim.powers.speed_mult() * 0.5),
		"the walking speed is half what it is without the ice (%.2f)" % iced
	)
	frost.frost_left = ice
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
	frost.launch(2, Vector3.ZERO)  # walks off before it lands: the grenade finds nobody
	var from := sim.kaiju_pos
	var missed := _run(sim, Num.f(frost.cfg["flight_s"]) + 0.2, "", way)
	check(
		from.distance_to(sim.kaiju_pos) > Num.f(frost.cfg["radius"]),
		"the kaiju walked clear of the spot (%.1f away)" % from.distance_to(sim.kaiju_pos)
	)
	check(
		_first(missed, "frost_hit").is_empty() and frost.frost_left == 0.0,
		"a grenade that lands where the kaiju no longer stands does nothing"
	)
	frost.launch(3, Vector3.ZERO)
	_run(sim, Num.f(frost.cfg["flight_s"]) + 0.1)
	check(frost.frost_left > 0.0, "iced again for the leap test")
	var dashed := sim.step(DT, way, false, DASH_BUTTON)
	var shattered := _first(dashed, "frost_cracked")
	check(
		str(shattered.get("why", "")) == "dash" and frost.frost_left == 0.0,
		"the leap (dash button) shatters the ice early: %s" % [shattered]
	)
	var walled := _adolescent()  # a leap pressed facing the wall ahead shatters it at the press
	_open(walled)
	_street_start(walled)
	for n: int in 16:  # faces a way the leap has somewhere to land
		walled.facing = Vector2.from_angle(n * TAU / 16.0)
		if walled.body.dash.can_leap():
			break
	var cold := walled.army_units.taskforce.frost
	cold.launch(4, Vector3.ZERO)
	_run(walled, Num.f(cold.cfg["flight_s"]) + 0.1)
	var rammed := walled.step(DT, walled.facing, false, DASH_BUTTON)
	check(
		not _first(rammed, "leap").is_empty() and walled.body.dash.phase() == "crouch",
		"the leap at a wall starts its crouch: %s" % [_types(rammed)]
	)
	check(
		str(_first(rammed, "frost_cracked").get("why", "")) == "dash" and cold.frost_left == 0.0,
		"it still shatters the ice"
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
