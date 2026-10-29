extends "res://tests/lib/leap_base.gd"
## Flung tanks (TankFlight; director 2026-10-30: real flung tanks first, with Ricochet and Domino in
## the same PR). A launched tank flies an arc and lands where the old shove put it; a building in
## the way is carved and stops it. Player-effect fixtures "croc.ricochet" and "croc.domino": the
## same seeded throw with the node owned and not; "tank.topple": the same throw landing on its roof
## and on its tracks. Seeded: every sim is Seeds.make("army", 0)
## (leap_base._croc) on a hand-made layout, the tanks hand-placed and held fire.

## The throw: from the origin, east, to land THROW out on open ground.
const THROW := 12.0
const EAST := Vector2(1.0, 0.0)
const EAST_AXIS := Vector3(1.0, 0.0, 0.0)
## The wall: a WIDE x WIDE block TALL floors high, its west face WALL_AT east of the origin.
const WALL_AT := 6.0
const WIDE := 4
const TALL := 6
## Seconds watched for a throw to settle.
const WATCH_S := 4.0
## Launches in the tumble mix, and seconds watched after a landing for the army's next move.
const MIX := 16
const AFTER_S := 6.0


func suite_name() -> String:
	return "Tank flight"


func run_checks() -> void:
	await _t("_check_arc")
	await _t("_check_wall")
	await _t("_check_ricochet")
	await _t("_check_domino")
	await _t("_check_leap_flings")
	await _t("_check_tumble_mix")
	await _t("_check_topple")
	await _t("_check_replay")


## On open ground the tank leaves the street, comes down THROW out (where the shove put it) and
## drives again; in the air it neither drives nor fires.
func _check_arc() -> void:
	var sim := _croc({}, [])
	var tank := _tank(sim, 901, Vector2.ZERO)
	sim.flight.launch(tank, EAST, THROW)
	var apex := 0.0
	var landed := {}
	for _n: int in roundi(WATCH_S / DT):
		apex = maxf(apex, tank.height)
		landed = _event_of(sim.step(DT, Vector2.ZERO, false, 0), "tank_landed", 901, landed)
		if not landed.is_empty():
			break
	var at: Vector2 = landed.get("at", Vector2.INF)
	check(apex > 1.0, "a flung tank leaves the street (apex %.2f)" % apex)
	check(
		at.distance_to(EAST * THROW) < 0.3 and not tank.flying and tank.height == 0.0,
		"it lands %.1f out on open ground (thrown to %.1f): %s" % [at.x, THROW, landed]
	)


## A tower in the way: the throw carves its face and the tank drops at the foot, outside it.
func _check_wall() -> void:
	var run := _throw_at_wall({})
	check(Num.i(run["walls"]) == 1, "the tank hits the tower once (%d)" % Num.i(run["walls"]))
	check(Num.i(run["carved"]) > 0, "the hit carves the tower (%d chunks)" % Num.i(run["carved"]))
	var x := Num.f(run["x"])
	check(
		x < WALL_AT and x > WALL_AT - 2.0,
		"it drops at the foot of the tower, outside it (x %.2f, face %.1f)" % [x, WALL_AT]
	)


## Fixture "croc.ricochet": the same throw at the tower, with Ricochet it bounces back off the face
## and comes down well short of it; without, it drops at the foot.
func _check_ricochet() -> void:
	var off := _throw_at_wall({})
	var on := _throw_at_wall({"r_ricochet": 1})
	check(
		Num.i(on["bounces"]) >= 1 and Num.i(off["bounces"]) == 0,
		"Ricochet bounces the tank (%d) where it stopped (%d)" % [on["bounces"], off["bounces"]]
	)
	check(
		Num.f(on["x"]) < Num.f(off["x"]) - 1.5,
		(
			"with Ricochet it comes back off the face to x %.2f; without, x %.2f"
			% [Num.f(on["x"]), Num.f(off["x"])]
		)
	)


## Fixture "croc.domino": a thrown tank comes down on a second, the second on a third. Without
## Domino the others are untouched; level 1 knocks the second flying (not the third); level 2 the
## third too.
func _check_domino() -> void:
	var off := _throw_into_row({})
	var one := _throw_into_row({"r_domino": 1})
	var two := _throw_into_row({"r_domino": 2})
	check(
		str(off["launched"]) == str([901]) and Num.f(off["hp_b"]) == 1000.0,
		"without Domino the tank it lands on is untouched: %s" % [off]
	)
	check(
		(
			str(one["launched"]) == str([901, 902])
			and Num.f(one["hp_b"]) < 1000.0
			and Num.f(one["b_x"]) > THROW + 3.0
		),
		"Domino 1 knocks the second tank flying on east: %s" % [one]
	)
	check(
		str(two["launched"]) == str([901, 902, 903]),
		"Domino 2 carries the chain to the third: %s" % [two]
	)


## The leap's ring sends the tanks it reaches flying (they were slid before).
func _check_leap_flings() -> void:
	var sim := _croc({}, [])
	var ring := Num.f(_stage(sim)["ring"]) * sim.body_scale()
	var reach := Num.f(_stage(sim)["reach"]) * sim.body_scale()
	var centre := Vector2(0.0, 30.0 - sim.body.feet_ahead() - reach)
	var near := _tank(sim, 901, centre + Vector2(ring * 0.5, 0.0))
	var held: Array[RampageSim.Tank] = [near]
	sim.step(DT, Vector2.ZERO, false, BUTTON)
	var events := _finish_held(sim, held)
	check(
		not _event_of(events, "tank_launched", 901, {}).is_empty(),
		"the leap's ring launches the tank it reaches"
	)


## The same throws twice land the same: the tower throw with Ricochet, the Domino chain.
func _check_replay() -> void:
	var a := _throw_at_wall({"r_ricochet": 2})
	var b := _throw_at_wall({"r_ricochet": 2})
	var c := _throw_into_row({"r_domino": 2})
	var d := _throw_into_row({"r_domino": 2})
	var e := _tumble_mix()
	var f := _tumble_mix()
	check(a == b and c == d and e == f, "a replayed throw lands the same: %s / %s / %s" % [a, c, e])


## Director 2026-10-30 "Seeded mix": every launch tumbles about its own seeded axis, so of MIX
## throws no two spin alike; "Lands as it falls": some come down on their tracks, some do not.
func _check_tumble_mix() -> void:
	var mix := _tumble_mix()
	var axes: Array = mix["axes"]
	var unique := {}
	for axis: String in axes:
		unique[axis] = true
	check(unique.size() == MIX, "each of %d throws spins about its own axis: %s" % [MIX, axes])
	check(
		Num.f(mix["most"]) > 90.0, "a throw turns past its side in the air (%.0f deg)" % mix["most"]
	)
	var down := Num.i(mix["toppled"])
	check(
		down > 0 and down < MIX,
		"some land toppled and some on their tracks (%d of %d toppled)" % [down, MIX]
	)


## Fixture "tank.topple": the same throw toward the kaiju, rolled half over (lands on its roof)
## or not spun (lands on its tracks). Toppled, it never drives or fires again; upright, it does.
func _check_topple() -> void:
	var down := _throw_and_watch(true)
	var up := _throw_and_watch(false)
	check(
		str(down["toppled"]) == "true" and str(up["toppled"]) == "false",
		"rolled half over it lands on its roof, unspun on its tracks: %s / %s" % [down, up]
	)
	check(
		Num.i(down["fired"]) == 0 and Num.f(down["moved"]) == 0.0,
		"toppled, it neither fires nor drives: %s" % [down]
	)
	check(
		Num.i(up["fired"]) > 0 and Num.f(up["moved"]) > 0.0,
		"on its tracks the same tank fires and drives: %s" % [up]
	)


## MIX tanks thrown east side by side: each spin's axis, the most any turned off upright in the
## air (degrees), and how many landed toppled.
func _tumble_mix() -> Dictionary:
	var sim := _croc({}, [])
	var tanks: Array[RampageSim.Tank] = []
	var axes: Array[String] = []
	for i: int in MIX:
		var tank := _tank(sim, 901 + i, Vector2(-30.0, -45.0 + 6.0 * i))
		sim.flight.launch(tank, EAST, THROW)
		axes.append(str(tank.spin.normalized().snappedf(0.01)))
		tanks.append(tank)
	var most := 0.0
	for _n: int in roundi(WATCH_S / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
		for tank: RampageSim.Tank in tanks:
			if tank.flying:
				most = maxf(most, rad_to_deg((tank.tilt * Vector3.UP).angle_to(Vector3.UP)))
	return {"axes": axes, "most": snappedf(most, 0.1), "toppled": sim.flight.toppled}


## A tank thrown THROW east to land short of the kaiju, rolled half over about its way (`roll`)
## or not spun; then AFTER_S watched with its gun loaded: shots fired and how far it drove.
func _throw_and_watch(roll: bool) -> Dictionary:
	var sim := _croc({}, [])
	var tank := _tank(sim, 901, sim.kaiju_pos - EAST * (THROW + 8.0))
	sim.flight.launch(tank, EAST, THROW)
	var seconds := 2.0 * tank.vel.y / Num.f(sim.flight.cfg["gravity"])
	tank.spin = EAST_AXIS * PI / seconds if roll else Vector3.ZERO
	for _n: int in roundi(WATCH_S / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
		if not tank.flying:
			break
	var landed := tank.pos
	tank.cooldown = 0.5
	var fired := 0
	for _n: int in roundi(AFTER_S / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			if str(event["type"]) == "tank_fired":
				fired += 1
	return {
		"toppled": tank.toppled,
		"fired": fired,
		"moved": snappedf(tank.pos.distance_to(landed), 0.01)
	}


## Throws a tank from the origin east at the tower; where it ends and what it did.
func _throw_at_wall(levels: Dictionary) -> Dictionary:
	var at := Vector2(WALL_AT + WIDE * 0.5, 0.0)
	var sim := _croc(levels, [_block(at, WIDE, TALL)])
	var tank := _tank(sim, 901, Vector2.ZERO)
	var before := sim.chunks_destroyed
	sim.flight.launch(tank, EAST, THROW)
	for _n: int in roundi(WATCH_S / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
		if not tank.flying:
			break
	var carved := sim.chunks_destroyed - before
	return {
		"x": tank.pos.x, "bounces": tank.bounces, "walls": sim.flight.walls_hit, "carved": carved
	}


## Throws a tank from the origin east to land on a second; a third stands domino_reach on.
func _throw_into_row(levels: Dictionary) -> Dictionary:
	var sim := _croc(levels, [])
	var reach := Num.f(sim.flight.cfg["domino_reach"])
	var a := _tank(sim, 901, Vector2.ZERO)
	var b := _tank(sim, 902, EAST * THROW)
	var c := _tank(sim, 903, EAST * (THROW + reach))
	sim.flight.launch(a, EAST, THROW)
	var launched: Array[int] = [901]  # launched before the first step, which clears the events
	var b_x := b.pos.x
	for _n: int in roundi(WATCH_S / DT):
		for waiting: RampageSim.Tank in [b, c]:  # the convoy would drive them off their spots
			if not launched.has(waiting.id):
				waiting.pos = EAST * (THROW if waiting == b else THROW + reach)
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			var id := Num.i(event.get("tank", -1))
			if str(event["type"]) == "tank_launched" and id in [902, 903]:
				launched.append(id)
			if str(event["type"]) == "tank_landed" and id == 902:
				b_x = b.pos.x
	launched.sort()
	return {"launched": launched, "hp_b": b.hp, "b_x": b_x}


## The event of `kind` for tank `id` among `events`, else `fallback`.
func _event_of(
	events: Array[Dictionary], kind: String, id: int, fallback: Dictionary
) -> Dictionary:
	for event: Dictionary in events:
		if str(event["type"]) == kind and Num.i(event["tank"]) == id:
			return event
	return fallback
