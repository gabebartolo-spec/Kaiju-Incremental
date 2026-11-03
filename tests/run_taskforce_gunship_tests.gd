extends "res://tests/lib/taskforce_suite.gd"
## The Taskforce's gunships (D-143, D-145, D-152): up to 2 in the adult city, none before it,
## beside the city's own helicopters; each fires a laser cannon at the kaiju and a blow that
## reaches the air downs one, paying and counting it. Each check is on vs off. Seeded by design:
## every sim is Seeds.make("army", 0) on the seeded city 0.


func suite_name() -> String:
	return "TaskforceGunships"


func run_checks() -> void:
	await _t("_check_adult_only")
	await _t("_check_laser_hurts")
	await _t("_check_downed_by_air_blow")


func _adult() -> RampageSim:
	var levels := {"evolve1": 1, "evolve2": 1}
	var sim := _sim("reptilian", levels, 0, CityGrowth.tuning_for(Content.tuning(), 3))
	_open(sim)
	return sim


func _check_adult_only() -> void:
	var adult := _adult()
	var young := _adolescent()
	_open(young)
	var shut := _adult()
	shut.army_units.taskforce.carried = 0.0  # the Taskforce has not joined yet
	for sim: RampageSim in [adult, young, shut]:
		sim.hp = 1.0e12
	_run(adult, 60.0)
	_run(young, 60.0)
	_run(shut, 60.0)
	var ships := adult.army_units.taskforce.gunships
	check(ships.cap() == 2, "up to 2 gunships in the adult city (D-152)")
	check(ships.ships.size() == 2, "two gunships fly in (on): %d" % ships.ships.size())
	check(young.army_units.taskforce.gunships.ships.is_empty(), "none in the adolescent city (off)")
	check(shut.army_units.taskforce.gunships.ships.is_empty(), "none before the Taskforce joins")


func _check_laser_hurts() -> void:
	var sim := _adult()
	sim.army_units.taskforce.carried = 0.0  # only the gunship placed here acts
	var ship := sim.army_units.taskforce.gunships.spawn()
	ship.cooldown = 0.0
	var hp := sim.hp
	var shots := _run(sim, 0.1, "gunship_laser")
	check(not _first(shots, "gunship_laser").is_empty(), "a ready gunship fires its laser")
	check(sim.hp < hp, "the laser hurts the kaiju")


func _check_downed_by_air_blow() -> void:
	var sim := _adult()
	var ships := sim.army_units.taskforce.gunships
	var ship := ships.spawn()
	var at := ship.pos
	var near := func(p: Vector2, _r: float) -> float: return 1.0 if p.distance_to(at) < 1.0 else 0.0
	var rubble := sim.rubble
	ships.hit(near, 100.0, false)
	check(ships.ships.has(ship), "a blow that cannot reach the air spares it (off)")
	ships.hit(near, 100.0, true)
	check(not ships.ships.has(ship), "a blow that reaches the air downs it (on, D-437)")
	check(sim.rubble > rubble and ships.kills == 1, "the kill pays biomass and counts")
	check(Num.i(sim.result()["helis"]) == 1, "the result counts it among the helicopters downed")
