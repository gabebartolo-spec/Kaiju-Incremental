extends "res://tests/lib/taskforce_suite.gd"
## The adult city's Taskforce (D-143, D-145, D-152): gas soldiers whose cloud locks his specials
## (the signature and the ultimate), and walking mechs whose laser bombs land on blue rings
## 1.5 s after they appear and who die to one stomp. Each check is on vs off. Seeded by design:
## every sim is Seeds.make("army", 0) on the seeded city 0.


func suite_name() -> String:
	return "TaskforceAdult"


func run_checks() -> void:
	await _t("_check_gas_locks_specials")
	await _t("_check_gas_soldiers_adult_only")
	await _t("_check_mech_bombs")
	await _t("_check_mech_stomp")
	await _t("_check_mechs_adult_only")


## A rampage in the adult city (size tier 3), the Taskforce open.
func _adult() -> RampageSim:
	var levels := {"evolve1": 1, "evolve2": 1}
	var sim := _sim("reptilian", levels, 0, CityGrowth.tuning_for(Content.tuning(), 3))
	_open(sim)
	return sim


## Presses the signature every step for `seconds`: whether the breath wound up.
func _breathes(sim: RampageSim, seconds: float) -> bool:
	for _n: int in roundi(seconds / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, true):
			if str(event["type"]) == "strike_windup" and str(event["kind"]) == Strikes.BREATH:
				return true
	return false


func _check_gas_locks_specials() -> void:
	var gassed := _adult()
	var clear := _adult()
	gassed.army_units.taskforce.carried = 0.0  # no squad joins to throw a second cloud
	clear.army_units.taskforce.carried = 0.0
	gassed.army_units.taskforce.gas.launch(0, Vector3.ZERO)
	var landed := _run(gassed, 1.5, "gas_cloud")
	check(not _first(landed, "gas_cloud").is_empty(), "a gas grenade at his feet becomes a cloud")
	check(gassed.army_units.taskforce.gas.locked, "standing in the cloud locks his specials")
	check(not _breathes(gassed, 1.0), "in the cloud the breath cannot be pressed (on)")
	check(_breathes(clear, 1.0), "out of a cloud the same press breathes (off)")
	var seconds := Num.f(gassed.army_units.taskforce.gas.cfg["seconds"])
	check(is_equal_approx(seconds, 8.0), "a cloud lasts about 8 s (D-152)")
	_run(gassed, seconds + 1.0)
	check(
		gassed.army_units.taskforce.gas.clouds.is_empty() and _breathes(gassed, 2.0),
		"once the cloud clears the breath works again"
	)


func _check_gas_soldiers_adult_only() -> void:
	var adult := _adult()
	var young := _adolescent()
	_open(young)
	for _n: int in 4:
		adult.army_units.taskforce.spawn_squad()
		young.army_units.taskforce.spawn_squad()
	check(_gas_soldiers(adult) > 0, "the adult city's squads carry gas soldiers (on)")
	check(_gas_soldiers(young) == 0, "the adolescent city's squads carry none (off)")


func _gas_soldiers(sim: RampageSim) -> int:
	var n := 0
	for agent: Taskforce.Agent in sim.army_units.taskforce.agents:
		n += 1 if agent.gas else 0
	return n


func _check_mech_bombs() -> void:
	var still := _adult()
	var mechs := still.army_units.taskforce.mechs
	var mech := mechs.place(still.kaiju_pos + Vector2(10.0, 0.0), -1)
	mech.volley_cd = 0.0
	var hp := still.hp
	var seen := _run(still, 0.1, "mech_volley")
	var volley := _first(seen, "mech_volley")
	check(not volley.is_empty(), "a mech in range fires a volley of target rings")
	var rings: Array = volley.get("rings", [])
	check(rings.size() == Num.i(mechs.cfg["bombs"]), "one ring a bomb: %d" % rings.size())
	var warn := Num.f(mechs.cfg["warn"])
	check(is_equal_approx(warn, 1.5), "the rings warn 1.5 s before the bombs land (D-143)")
	check(
		_first(_run(still, warn - 0.2), "mech_bomb").is_empty(),
		"nothing lands before the warning is up"
	)
	var bomb := _first(_run(still, 0.4, "mech_bomb"), "mech_bomb")
	var bomb_hit: bool = bomb.get("hit", false)
	check(bomb_hit and still.hp < hp, "standing on the ring, the bomb hurts him (on)")
	var moved := _adult()
	var walker := moved.army_units.taskforce.mechs.place(moved.kaiju_pos + Vector2(10.0, 0.0), -1)
	walker.volley_cd = 0.0
	_run(moved, 0.1, "mech_volley")
	moved.army_units.taskforce.mechs.bombs.resize(1)  # only the ring on his feet
	moved.kaiju_pos += Vector2(0.0, 10.0)  # stepped clear of the ring on his feet
	var miss := _first(_run(moved, 2.0, "mech_bomb"), "mech_bomb")
	var miss_hit: bool = miss.get("hit", true)
	check(not miss.is_empty() and not miss_hit, "stepping off the ring dodges it (off)")


func _check_mech_stomp() -> void:
	var sim := _adult()
	var mechs := sim.army_units.taskforce.mechs
	var r := sim.stomp_radius()
	var near := mechs.place(sim.kaiju_pos + Vector2(r * 0.5, 0.0), -1)
	var far := mechs.place(sim.kaiju_pos + Vector2(r * 3.0, 0.0), -1)
	near.volley_cd = 1.0e9
	far.volley_cd = 1.0e9
	var rubble := sim.rubble
	sim.strikes.stomp(sim.kaiju_pos, 0.0)
	check(not mechs.mechs.has(near), "one stomp kills the mech under it (on, D-152)")
	check(mechs.mechs.has(far), "a mech out of the stomp's reach stands (off)")
	check(sim.rubble > rubble and mechs.kills == 1, "the kill pays biomass and counts")
	check(Num.i(sim.result()["mechs"]) == 1, "the result counts the mech kill")


func _check_mechs_adult_only() -> void:
	var adult := _adult()
	var young := _adolescent()
	_open(young)
	_run(adult, 30.0)
	_run(young, 30.0)
	check(adult.army_units.taskforce.mechs.cap() == 4, "up to 4 mechs walk the adult city (D-143)")
	check(not adult.army_units.taskforce.mechs.mechs.is_empty(), "mechs walk in (on)")
	check(young.army_units.taskforce.mechs.mechs.is_empty(), "none in the adolescent city (off)")
