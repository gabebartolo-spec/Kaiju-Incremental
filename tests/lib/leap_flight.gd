extends "res://tests/lib/leap_base.gd"
## The croc leap suite's flight and effect checks (run_leap_tests runs them): the phases, the
## ring and fling, the cooldown and frost, the replay and the player-effect fixture.


## Per stage: the crouch, flight, settle and recovery last the data's seconds; the body is in the
## air exactly the flight time, high in the middle and on the ground at both ends, and a stick held
## sideways through it moves nothing.
func _check_phases() -> void:
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		var sim := _croc(levels, [])
		var data := _stage(sim)
		var seen := {}
		var apex := 0.0
		var steps := 1
		var blows := 0  # stomps and claw rakes during the leap
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, BUTTON):
			blows += 1 if str(event["type"]) in ["stomp", "swipe", "swipe_windup"] else 0
		var air_from := sim.kaiju_pos
		while sim.body.dash.on() and steps < roundi(6.0 / DT):
			var phase := sim.body.dash.phase()
			seen[phase] = Num.i(seen.get(phase, 0)) + 1
			apex = maxf(apex, sim.body.dash.height())
			for event: Dictionary in sim.step(DT, Vector2(1, 0), false, 0):  # pushed east
				var kind := str(event["type"])
				blows += (
					1 if kind in ["stomp", "swipe", "swipe_windup"] and sim.body.dash.on() else 0
				)
			steps += 1
		check(blows == 0, "%s: no stomp or claw from crouch to recovery (%d)" % [stage, blows])
		var sideways := absf(sim.kaiju_pos.x - air_from.x)
		for phase: String in Dash.PHASES:
			var want := Num.f(data[phase + "_s"])
			var got := Num.i(seen.get(phase, 0)) * DT
			check(
				absf(got - want) <= DT * 1.01,
				"%s: the %s lasts %.3f s (data %.3f s)" % [stage, phase, got, want]
			)
		var top := sim.body.dash.arc.top  # over open ground: the clearance above the street
		check(
			apex > top * 0.95 and apex <= top + 0.001 and sim.body.dash.height() == 0.0,
			"%s: the body rises %.2f (apex %.2f) and is down after" % [stage, apex, top]
		)
		check(sideways < 0.001, "%s: the stick moves nothing in a leap (%.3f)" % [stage, sideways])


## The ring: a tank inside it is flung outward and hurt; one past twice its radius is untouched.
func _check_ring_and_fling() -> void:
	var sim := _croc({}, [])
	var ring := Num.f(_stage(sim)["ring"]) * sim.body_scale()
	var reach := Num.f(_stage(sim)["reach"]) * sim.body_scale()
	var centre := Vector2(0.0, 30.0 - sim.body.feet_ahead() - reach)
	var near := _tank(sim, 901, centre + Vector2(ring * 0.5, 0.0))
	var far := _tank(sim, 902, centre + Vector2(-ring * 2.5, 0.0))
	var held: Array[RampageSim.Tank] = [near, far]  # on their spots through the crouch and flight
	sim.step(DT, Vector2.ZERO, false, BUTTON)
	var events := _finish_held(sim, held)
	var land := _first(events, "leap_land")
	var flung := {}
	for event: Dictionary in events:
		if str(event["type"]) == "tank_flung":
			flung[Num.i(event["tank"])] = event
	var out := near.pos.distance_to(centre)
	var at: Vector2 = land.get("at", Vector2.INF)
	check(at.distance_to(centre) < 0.05, "the ring is centred under the feet: %s" % [land])
	check(
		flung.has(901) and out > ring * 0.5 + 1.0 and near.hp < 1000.0,
		(
			"a tank in the ring is flung out to %.1f (from %.1f) and hurt (hp %.0f)"
			% [out, ring * 0.5, near.hp]
		)
	)
	check(
		not flung.has(902) and far.hp == 1000.0,
		"a tank past twice the ring is untouched (hp %.0f)" % far.hp
	)


## A second press inside the cooldown does nothing; after it, it leaps again. A leap shatters frost.
func _check_cooldown_and_frost() -> void:
	var sim := _croc({}, [])
	var frost := sim.army_units.taskforce.frost
	frost.frost_left = 3.0
	var events := sim.step(DT, Vector2.ZERO, false, BUTTON)
	events.append_array(sim.step(DT, Vector2.ZERO, false, 0))
	var cracked := _first(events, "frost_cracked")
	check(
		frost.frost_left == 0.0 and not cracked.is_empty(),
		"the leap shatters the frost: %s" % [cracked]
	)
	_finish(sim)
	sim.step(DT, Vector2.ZERO, false, BUTTON)
	check(
		sim.body.dash.dashes == 1,
		"a press inside the cooldown is ignored (%d)" % sim.body.dash.dashes
	)
	for _n: int in roundi(Num.f(_stage(sim)["cooldown"]) / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
	sim.step(DT, Vector2.ZERO, false, BUTTON)
	check(
		sim.body.dash.dashes == 2, "after the cooldown it leaps again (%d)" % sim.body.dash.dashes
	)


## The same seed and presses replay the same leap through the seeded city.
func _check_replay() -> void:
	var a := _run_city(true)
	var b := _run_city(true)
	check(a == b, "the same seeded leap replays identically (%s)" % [a])


## Player-effect fixture "croc.leap": the same seeded rampage, the button pressed vs walked.
func _check_effect() -> void:
	var leapt := _run_city(true)
	var walked := _run_city(false)
	check(
		Num.i(leapt["landings"]) == 1 and Num.i(walked["landings"]) == 0,
		"croc.leap: one landing with the button, none without (%s / %s)" % [leapt, walked]
	)
	check(
		(
			Num.i(leapt["in_flight"]) == 0
			and Num.i(leapt["blocked"]) == 0
			and Num.f(leapt["roof"]) > 0.0
		),
		"croc.leap: a high arc onto a roof, nothing hit in flight (%s)" % [leapt]
	)
	check(
		Num.i(leapt["chunks"]) > Num.i(walked["chunks"]),
		(
			"croc.leap: the leap breaks more of the city than walking the same seconds (%d vs %d)"
			% [Num.i(leapt["chunks"]), Num.i(walked["chunks"])]
		)
	)
