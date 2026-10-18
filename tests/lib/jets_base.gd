extends "res://tests/lib/powers_base.gd"
## The jets suite's fixtures (tests/run_jets_tests.gd extends this) and its bombing checks: the
## kinds' turns, bombs landing where warned, the bomb-dodge player-effect fixture, bomb
## collateral and the Apex's bomber. Split out to keep each file under the 400-line cap.

const AT := Vector2(0, 0)


## A sim whose jets are on (`max`), its city hurt enough to call them in (the call-in mark
## lowered to the chunks already down: the test city is too small to reach the real one).
func _jet_sim(
	max_jets: int = 1,
	layout: Array[Dictionary] = [],
	species: String = "reptilian",
	levels: Dictionary = {}
) -> RampageSim:
	var sim := _sim(species, levels, layout, AT)
	sim.strike.cfg = sim.strike.cfg.duplicate(true)
	sim.strike.cfg["max"] = max_jets
	sim.strike.cfg["after_chunks"] = sim.chunks_destroyed
	return sim


## Steps until `type` is seen or `seconds` run out; the time it took (INF if never).
func _until(sim: RampageSim, type: String, seconds: float, move := Vector2.ZERO) -> float:
	for i: int in roundi(seconds / DT):
		for event: Dictionary in sim.step(DT, move, false):
			if str(event["type"]) == type:
				return (i + 1) * DT
	return INF


## A delta-wing striker alone (bombs, no rounds), its city hurt.
func _delta_sim(layout: Array[Dictionary] = []) -> RampageSim:
	var sim := _jet_sim(1, layout)
	sim.strike.cfg["order"] = ["delta"]
	sim.strike.cfg["yaw_jitter"] = 0.0
	return sim


## The kinds take turns in the stage's order, each with its own weapons and toughness.
func _check_kinds() -> void:
	var sim := _jet_sim(3)
	sim.strike.cfg["order"] = ["interceptor", "attacker", "delta"]
	var kinds: Array[String] = []
	var hp: Array[float] = []
	for _n: int in 4:
		var jet := sim.strike.spawn()
		kinds.append(jet.kind)
		hp.append(jet.hp)
	var weapons := (
		sim.strike.line(sim.strike.jets[2]).is_empty()
		and not sim.strike.targets(sim.strike.jets[2]).is_empty()
		and not sim.strike.line(sim.strike.jets[1]).is_empty()
		and not sim.strike.targets(sim.strike.jets[1]).is_empty()
	)
	check(
		kinds == ["interceptor", "attacker", "delta", "interceptor"] and hp[1] > hp[0] and weapons,
		"kinds take turns (%s): the attacker strafes, bombs and lasts; the delta bombs" % [kinds]
	)


## A delta drops its bombs on the spots it warned of, after the warning.
func _check_bombs() -> void:
	var sim := _delta_sim()
	var jet := sim.strike.spawn()
	var warned := PackedVector2Array()
	var landed := PackedVector2Array()
	var t_warn := INF
	var t_first := INF
	for i: int in roundi(6.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			var t := (i + 1) * DT
			match str(event["type"]):
				"jet_inbound":
					warned = event["bombs"]
					t_warn = t
				"jet_bomb":
					var at: Vector2 = event["at"]
					landed.append(at)
					t_first = minf(t_first, t)
	check(
		landed.size() == Num.i(sim.strike.cfg["kinds"]["delta"]["bombs"]) and landed == warned,
		"a delta's %d bombs land on the %d spots it warned of" % [landed.size(), warned.size()]
	)
	check(
		t_first - t_warn >= jet.lead - DT,
		"the warning comes %.2f s before the first bomb lands" % (t_first - t_warn)
	)


## Player-effect fixture, bombs: the same delta, the same seed; one kaiju stands, the other
## steps toward the camera as soon as the warning comes.
func _check_bomb_dodge() -> void:
	var hits: Array[int] = []
	for dodge: bool in [false, true]:
		var sim := _delta_sim()
		sim.strike.spawn()
		var move := Vector2.ZERO
		var n := 0
		for i: int in roundi(6.0 / DT):
			for event: Dictionary in sim.step(DT, move, false):
				if str(event["type"]) == "jet_inbound" and dodge:
					move = Vector2(0, 1)
				if str(event["type"]) == "jet_bomb" and event["hit"]:
					n += 1
		hits.append(n)
	check(
		hits[0] > 0 and hits[1] == 0,
		"getting out from under the bombs after the warning dodges them (%d vs %d)" % hits
	)


## Bomb blasts wreck the roofs round them, several floors deep, and pay no biomass.
func _check_bomb_collateral() -> void:
	var standing: Array[int] = []
	var rubble: Array[float] = []
	for pass_on: bool in [false, true]:
		var sim := _delta_sim([_b(4.8, 0, Vector3i(3, 3, 4))])
		if pass_on:
			sim.strike.spawn()
		else:
			sim.strike.cfg["max"] = 0
		_run(sim, 6.0, Vector2.ZERO)
		standing.append(_alive(sim, 0))
		rubble.append(sim.rubble)
	check(
		standing[0] - standing[1] > 9 and is_equal_approx(rubble[1], rubble[0]),
		(
			"a bomb wrecks more than a roof (%d vs %d chunks), paying no biomass (%.2f vs %.2f)"
			% [standing[1], standing[0], rubble[1], rubble[0]]
		)
	)


## The Apex's set-piece: the heavy bomber flies higher and slower than the fighters, takes far
## more to down, and carpet-bombs a long line through the kaiju's spot.
func _check_bomber() -> void:
	var sim := _jet_sim(2)
	sim.strike.cfg["order"] = ["interceptor", "bomber"]
	var fighter := sim.strike.spawn()
	var bomber := sim.strike.spawn()
	var landed := PackedVector2Array()
	for i: int in roundi(14.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "jet_bomb" and Num.i(event["jet"]) == bomber.id:
				var at: Vector2 = event["at"]
				landed.append(at)
	var carpet := landed[0].distance_to(landed[-1]) if landed.size() > 1 else 0.0
	check(
		(
			sim.strike.altitude(bomber) > sim.strike.altitude(fighter)
			and bomber.hp > fighter.hp * 3.0
			and landed.size() == Num.i(bomber.cfg["bombs"])
			and carpet > 20.0
		),
		(
			"the bomber flies %.0f over the fighters' %.0f and carpet-bombs %d bombs along %.0f u"
			% [sim.strike.altitude(bomber), sim.strike.altitude(fighter), landed.size(), carpet]
		)
	)
