extends "res://tests/lib/runner.gd"
## The croc's leap on the dash button (Dash, D-259 "a leap that lands on a building and crushes it
## with a shockwave (replaces the dash)"): it aims at the standing building ahead in reach (else the
## full reach), crouches, flies its stage's flight time and lands; nothing breaks before the contact
## (D-166), the landing breaks the building through the carve path, a ring hurts and flings tanks
## outward, the body takes no stick through the leap, the button waits out its cooldown, a frost
## coat shatters, and the same seed replays the same leap. Player-effect fixture "croc.leap": the
## same seeded rampage with the leap pressed and with it walked breaks a different city.
## Seeded by design: every sim is Seeds.make("army", 0); the fixture city is Seeds.make("city", 0).

const DT := 1.0 / 60.0
const BUTTON := 4  # Dash.BUTTON
## The growth steps: the young croc, Behemoth, Colossus (the leap's three stages).
const STAGES := {"young": {}, "Behemoth": {"evolve1": 1}, "Colossus": {"evolve1": 1, "evolve2": 1}}
## The fixture: seconds walked before the press, then seconds watched after it.
const FIXTURE_LEAD_S := 1.0
const FIXTURE_WATCH_S := 4.0


func suite_name() -> String:
	return "Leap"


func run_checks() -> void:
	await _t("_check_aims_ahead")
	await _t("_check_open_ground")
	await _t("_check_tower_wall")
	await _t("_check_phases")
	await _t("_check_ring_and_fling")
	await _t("_check_cooldown_and_frost")
	await _t("_check_replay")
	await _t("_check_effect")


## The reptilian at `levels`, as Rampage builds it, standing at (0, 30) facing north, on `layout`
## plus a small block far behind it, so the run is not over for want of a city.
func _croc(levels: Dictionary, p_layout: Array[Dictionary]) -> RampageSim:
	var layout := p_layout.duplicate()
	layout.append(_block(Vector2(38.0, 38.0), 2, 2))
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.ability_type = "cone"
	sim.body.use_species("reptilian")
	sim.time_left = 1.0e9
	sim.kaiju_pos = Vector2(0.0, 30.0)
	return sim


## A building of `w` x `w` cells, `h` floors, centred at `at`.
func _block(at: Vector2, w: int, h: int) -> Dictionary:
	return {"x": at.x, "z": at.y, "w": w, "d": w, "h": h, "tier": 1, "style": 0}


## Where the feet of a croc at (0, 30) facing north land on a building centre `ahead` units on.
func _ahead(sim: RampageSim, ahead: float) -> Vector2:
	return Vector2(0.0, 30.0 - sim.body.feet_ahead() - ahead)


## Steps the sim until the leap is over (at most 5 s), returning every event on the way.
func _finish(sim: RampageSim, stick: Vector2 = Vector2.ZERO) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for _n: int in roundi(5.0 / DT):
		if not sim.body.dash.on():
			break
		seen.append_array(sim.step(DT, stick, false, 0))
	return seen


func _first(events: Array[Dictionary], kind: String) -> Dictionary:
	for event: Dictionary in events:
		if str(event["type"]) == kind:
			return event
	return {}


## The leap picks the standing building ahead in reach (not one off to the side, not one beyond
## reach) and lands the feet on it; the crouch breaks nothing, the contact's blow breaks it (D-166).
func _check_aims_ahead() -> void:
	var probe := _croc({}, [])
	var reach := Num.f(_stage(probe)["reach"]) * probe.body_scale()
	var ahead := _ahead(probe, reach * 0.6)
	var layout: Array[Dictionary] = [
		_block(ahead, 4, 3),
		_block(ahead + Vector2(reach * 0.4, reach * 0.3), 4, 3),  # nearer but 53 deg off the facing
		_block(_ahead(probe, reach * 1.4), 4, 3),  # beyond reach
	]
	layout[1]["z"] = 30.0 - probe.body.feet_ahead() - reach * 0.3
	var sim := _croc({}, layout)
	var before := sim.buildings[0].frame.alive_count
	var events := sim.step(DT, Vector2.ZERO, false, BUTTON)
	var leap := _first(events, "leap")
	check(Num.i(leap.get("building", -2)) == 0, "the leap aims at the building ahead: %s" % [leap])
	var early := 0
	var landed := false
	var at_contact := 0
	for _n: int in roundi(5.0 / DT):
		var was := sim.chunks_destroyed
		var crouching := sim.body.dash.phase() == "crouch"
		var step := sim.step(DT, Vector2.ZERO, false, 0)
		if not _first(step, "leap_land").is_empty():
			landed = true
			at_contact = sim.chunks_destroyed - was
			break
		early += sim.chunks_destroyed if crouching else 0
	check(landed and early == 0, "the crouch breaks nothing (%d chunk-steps)" % early)
	check(at_contact > 0, "the landing blow breaks chunks on contact (%d)" % at_contact)
	var feet := sim.kaiju_pos + sim.facing * sim.body.feet_ahead()
	check(
		feet.distance_to(ahead) < 0.05,
		"the feet land on the building's centre (%.2f off)" % feet.distance_to(ahead)
	)
	var left := sim.buildings[0].frame.alive_count
	check(left < before, "the landing breaks the building (%d of %d chunks left)" % [left, before])
	var side := sim.buildings[1].frame.alive_count
	check(sim.chunks_destroyed > 0, "the landing pays (%d chunks destroyed)" % sim.chunks_destroyed)
	check(side > 0, "the building off to the side still stands (%d chunks)" % side)


## D-091: at a tower that dwarfs the young croc the leap comes down against its wall, never inside
## it, and the landing still chews into it.
func _check_tower_wall() -> void:
	var probe := _croc({}, [])
	var reach := Num.f(_stage(probe)["reach"]) * probe.body_scale()
	var tower := _block(_ahead(probe, reach * 0.6), 6, 12)
	tower["tier"] = 3
	var sim := _croc({}, [tower])
	var before := sim.buildings[0].frame.alive_count
	var worst := 0
	sim.step(DT, Vector2.ZERO, false, BUTTON)
	for _n: int in roundi(5.0 / DT):
		if not sim.body.dash.on():
			break
		sim.step(DT, Vector2.ZERO, false, 0)
		worst = maxi(worst, Dictionary(sim.body.inside(sim.kaiju_pos, sim.body.heading)).size())
	var left := sim.buildings[0].frame.alive_count
	check(
		sim.body.dash.landings == 1 and worst == 0,
		"the leap flies and lands clear of the tower, never inside it (%d inside)" % worst
	)
	check(left < before, "the landing chews the tower (%d of %d chunks left)" % [left, before])


## With nothing standing ahead in reach, the leap flies its full reach along the facing.
func _check_open_ground() -> void:
	var sim := _croc({}, [])
	var from := sim.kaiju_pos
	sim.step(DT, Vector2.ZERO, false, BUTTON)
	_finish(sim)
	var reach := Num.f(_stage(sim)["reach"]) * sim.body_scale()
	var flown := (from - sim.kaiju_pos).dot(Vector2(0, 1))
	check(
		absf(flown - reach) < 0.05 and sim.body.dash.landings == 1,
		"over open ground it lands at full reach (%.2f of %.2f)" % [flown, reach]
	)


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
		sim.step(DT, Vector2.ZERO, false, BUTTON)
		var air_from := sim.kaiju_pos
		while sim.body.dash.on() and steps < roundi(6.0 / DT):
			var phase := sim.body.dash.phase()
			seen[phase] = Num.i(seen.get(phase, 0)) + 1
			apex = maxf(apex, sim.body.dash.height())
			sim.step(DT, Vector2(1, 0), false, 0)  # pushed east the whole way
			steps += 1
		var sideways := absf(sim.kaiju_pos.x - air_from.x)
		for phase: String in Dash.PHASES:
			var want := Num.f(data[phase + "_s"])
			var got := Num.i(seen.get(phase, 0)) * DT
			check(
				absf(got - want) <= DT * 1.01,
				"%s: the %s lasts %.3f s (data %.3f s)" % [stage, phase, got, want]
			)
		var top := Num.f(data["apex"]) * sim.body_scale()
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
	sim.step(DT, Vector2.ZERO, false, BUTTON)
	var events := _finish(sim)
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


func _tank(sim: RampageSim, id: int, at: Vector2) -> RampageSim.Tank:
	var tank := RampageSim.Tank.new()
	tank.id = id
	tank.pos = at
	tank.hp = 1000.0
	tank.cooldown = 1.0e9
	sim.tanks.append(tank)
	return tank


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
		Num.i(leapt["chunks"]) > Num.i(walked["chunks"]),
		(
			"croc.leap: the leap breaks more of the city than walking the same seconds (%d vs %d)"
			% [Num.i(leapt["chunks"]), Num.i(walked["chunks"])]
		)
	)


## The croc walks north into the seeded city FIXTURE_LEAD_S, then (with `leap`) presses the button,
## and is watched FIXTURE_WATCH_S with the stick held north.
func _run_city(leap: bool) -> Dictionary:
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := _croc({}, layout)
	sim.kaiju_pos = Vector2(0.0, CityGen.half_extent(sim.city))
	var north := Vector2(0, -1)
	for _n: int in roundi(FIXTURE_LEAD_S / DT):
		sim.step(DT, north, false, 0)
	sim.step(DT, north, false, BUTTON if leap else 0)
	for _n: int in roundi(FIXTURE_WATCH_S / DT):
		sim.step(DT, north, false, 0)
	return {
		"landings": sim.body.dash.landings,
		"chunks": sim.chunks_destroyed,
		"rubble": snappedf(sim.rubble, 0.001),
		"at": sim.kaiju_pos.snapped(Vector2(0.001, 0.001)),
	}


func _stage(sim: RampageSim) -> Dictionary:
	var stages: Array = sim.body.dash.cfg["stages"]["reptilian"]
	return stages[clampi(sim.size_tier() - 1, 0, stages.size() - 1)]
