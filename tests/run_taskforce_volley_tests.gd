extends "res://tests/lib/taskforce_suite.gd"
## A Taskforce squad's volleys, round after round (D-178 "Lock together, fire in turn", beside
## tests/run_taskforce_gate_tests.gd, which has the first volley's numbers): gunners whose
## railguns are ready on the same step all lock on in one step, whatever their cooldown, and
## again in every later round (a gunner's cooldown counts from the volley's first shot, so the
## squad stays together); a gunner whose roof is gone takes no slot in the volley.
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0.


func suite_name() -> String:
	return "TaskforceVolley"


func run_checks() -> void:
	await _t("_check_ready_together")
	await _t("_check_rounds")
	await _t("_check_fallen_roof")


## A rampage with `size` planted gunners of one squad on one roof, each railgun `cooldown`
## seconds from ready, the Taskforce not opened (no other squad joins).
func _squad(size: int, cooldown: float) -> RampageSim:
	var sim := _adolescent()
	sim.time_left = 1.0e9
	sim.army_units.taskforce.squad_sizes.append(size)
	for _n: int in size:
		_perched(sim, true).rail_cd = cooldown
	return sim


## Steps `sim` for `seconds` with its gunners held on their roofs (they would hop on after a
## shot) and the kaiju standing and healed; every railgun event as {"step", "type", "agent"}.
func _watch(sim: RampageSim, seconds: float) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for n: int in roundi(seconds / DT):
		for agent: Taskforce.Agent in sim.army_units.taskforce.agents:
			agent.wait = 1.0e9
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, RampageSim.STOMP):
			if str(event["type"]).begins_with("railgun_"):
				seen.append({"step": n, "type": str(event["type"]), "agent": Num.i(event["agent"])})
		sim.hp = sim.max_hp
	return seen


## The steps on which `type` events happened, in order, each once.
func _steps(seen: Array[Dictionary], type: String) -> Array[int]:
	var steps: Array[int] = []
	for event: Dictionary in seen:
		if str(event["type"]) == type and not steps.has(Num.i(event["step"])):
			steps.append(Num.i(event["step"]))
	return steps


func _count(seen: Array[Dictionary], type: String) -> int:
	return seen.filter(func(e: Dictionary) -> bool: return str(e["type"]) == type).size()


## Four gunners whose railguns come ready on the same step (0.5 s and 6 s from ready) lock on in
## one step: a gunner listed after the opener is ready on that step too, not a step later.
func _check_ready_together() -> void:
	for cooldown: float in [0.5, 6.0]:
		var sim := _squad(4, cooldown)
		var seen := _watch(sim, cooldown + 4.0)
		var locks := _steps(seen, "railgun_locked")
		check(
			_count(seen, "railgun_locked") == 4 and locks.size() == 1,
			(
				"four gunners ready together (%.1f s) lock in one step: %d locks on steps %s"
				% [cooldown, _count(seen, "railgun_locked"), locks]
			)
		)


## Three rounds of a squad of four, each round locking the whole squad in one step: the cooldown
## counts from the volley's first shot (gunner n trails it by n x squad_gap), so every gunner
## still fires once per cooldown and the squad is ready together again.
func _check_rounds() -> void:
	var sim := _squad(4, 0.0)
	var rail: Dictionary = sim.army_units.taskforce.cfg["railgun"]
	var cooldown := Num.f(rail["cooldown"])
	var seen := _watch(sim, cooldown * 2.0 + 9.0)
	var locks := _steps(seen, "railgun_locked")
	var shots := _count(seen, "railgun_hit") + _count(seen, "railgun_missed")
	check(
		locks.size() == 3 and _count(seen, "railgun_locked") == 12,
		(
			"three rounds, each locks the squad of four in one step: %d locks on steps %s"
			% [_count(seen, "railgun_locked"), locks]
		)
	)
	check(shots == 12, "every gunner fires once a round: %d shots in three rounds" % shots)


## A gunner listed between the opener and another squadmate whose roof chunk is gone takes no
## slot in the volley and puts no line up: the squadmate's shot follows the opener's by one gap.
func _check_fallen_roof() -> void:
	var sim := _adolescent()
	sim.time_left = 1.0e9
	var tf := sim.army_units.taskforce
	tf.squad_sizes.append(3)
	var first := _perched(sim, true)
	var roof := sim.buildings[first.building]
	var corner := Vector3i(0, roof.height - 1, 0)
	var lost := tf.place_agent(first.building, corner)
	lost.rail_cd = 0.0
	lost.frost_cd = 1.0e9
	var last := _perched(sim, true)
	var cells: Array[Vector3i] = [corner]
	sim.damage_chunks(first.building, cells, 1.0e6)
	var seen := _watch(sim, 6.0)
	var aimed: Array[int] = []
	var shot_at := {}
	for event: Dictionary in seen:
		match str(event["type"]):
			"railgun_aim":
				aimed.append(Num.i(event["agent"]))
			"railgun_hit", "railgun_missed":
				shot_at[Num.i(event["agent"])] = Num.i(event["step"])
	check(
		aimed.has(first.id) and aimed.has(last.id) and not aimed.has(lost.id),
		"the gunner whose roof is gone puts no line up (aimed: %s, lost %d)" % [aimed, lost.id]
	)
	var gap := Num.f(tf.cfg["railgun"]["squad_gap"])
	var apart := (Num.i(shot_at.get(last.id, -1)) - Num.i(shot_at.get(first.id, -1))) * DT
	check(
		shot_at.has(first.id) and shot_at.has(last.id) and absf(apart - gap) < DT * 1.5,
		"it took no slot: the next shot follows by one gap (%.2f s, gap %.2f s)" % [apart, gap]
	)
