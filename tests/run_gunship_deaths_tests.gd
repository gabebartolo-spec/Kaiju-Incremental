extends "res://tests/lib/powers_base.gd"
## Gunship deaths suite (TaskforceGunships, D-458): a Taskforce gunship dies as a helicopter
## does. A hard blow blows it apart in the air; a glancing one sends it spinning down as one of
## AirWing's falling wrecks, out of the sky at once; it falls from its altitude, crashes on the
## street within its fall time and is gone, its crash smashing the block it lands on through
## AirWing's own crash (never the kaiju); over a building it lands on the roof, early, never
## through it. Headless.
##   godot --headless --path . --script tests/run_gunship_deaths_tests.gd

const KAIJU_AT := Vector2(-20, 0)
const OPEN := Vector2(12, 12)  # open street, clear of the block at the origin
const FLOORS := 4


func suite_name() -> String:
	return "GunshipDeaths"


func run_checks() -> void:
	await _t("_check_burst")
	await _t("_check_falls_to_ground")
	await _t("_check_crash_damage")
	await _t("_check_lands_on_roof")


## One 3 x 3 x FLOORS block at the origin and one gunship in the sky.
func _scene() -> RampageSim:
	var sim := _sim("reptilian", {}, [_b(0, 0, Vector3i(3, 3, FLOORS))], KAIJU_AT)
	sim.army_units.taskforce.gunships.spawn()
	return sim


## Downs the only gunship with one blow of `blow`; returns its gunship_destroyed event.
func _down(sim: RampageSim, blow: float) -> Dictionary:
	sim.events.clear()
	sim.army_units.taskforce.gunships.hit(
		func(_p: Vector2, _r: float) -> float: return 1.0, blow, true
	)
	for event: Dictionary in sim.events:
		if str(event["type"]) == "gunship_destroyed":
			return event
	return {}


## Its wreck among AirWing's falling, or null.
func _wreck(sim: RampageSim, id: int) -> AirWing.Falling:
	for down: AirWing.Falling in sim.air.falling:
		if down.id == id:
			return down
	return null


## Spins the gunship down with its wreck falling straight onto `at`.
func _spin_onto(sim: RampageSim, at: Vector2) -> Dictionary:
	var event := _down(sim, Num.f(sim.air.cfg["burst_blow"]) * 0.2)
	var down := _wreck(sim, Num.i(event.get("heli", -1)))
	if down != null:
		down.pos = at
		down.drift = Vector2.ZERO
	return event


## Steps until wreck `id` crashes (or `seconds` pass); the crash event, with "t": the time it
## took and "hurt": the kaiju's health lost on the crash's step (no other attacker left), or {}.
func _until_crash(sim: RampageSim, id: int, seconds: float) -> Dictionary:
	for i: int in roundi(seconds / DT):
		sim.air.helis.clear()  # no other attacker fires, so only the crash could hurt him
		sim.tanks.clear()
		var hp := sim.hp
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			if str(event["type"]) == "heli_crashed" and Num.i(event["heli"]) == id:
				event["t"] = (i + 1) * DT
				event["hurt"] = hp - sim.hp
				return event
	return {}


func _check_burst() -> void:
	var sim := _scene()
	var ships := sim.army_units.taskforce.gunships
	var event := _down(sim, Num.f(sim.air.cfg["burst_blow"]))
	check(str(event.get("fate", "")) == "burst", "a blow of burst_blow blows it apart: %s" % event)
	check(ships.ships.is_empty() and sim.air.falling.is_empty(), "blown apart, nothing falls")
	check(ships.kills == 1, "it counts")


func _check_falls_to_ground() -> void:
	var sim := _scene()
	var ships := sim.army_units.taskforce.gunships
	var event := _spin_onto(sim, OPEN)
	var id := Num.i(event.get("heli", -1))
	check(str(event.get("fate", "")) == "spin", "a glancing blow spins it down: %s" % event)
	check(
		ships.ships.is_empty(), "a falling gunship is out of the sky: it no longer flies or fires"
	)
	var down := _wreck(sim, id)
	check(down != null and down.roofs, "its wreck falls as AirWing's own, landing on roofs")
	check(Num.f(event.get("y", 0.0)) == ships.altitude(), "it falls from its altitude: %s" % event)
	var fall := Num.f(sim.air.cfg["fall_seconds"])
	var crash := _until_crash(sim, id, fall + 1.0)
	check(not crash.is_empty(), "the wreck hits the ground within its fall time")
	check(
		absf(Num.f(crash.get("y", 1.0))) < 0.01,
		"on open street it lands on the ground (y %.2f)" % Num.f(crash.get("y", 1.0))
	)
	check(
		Num.f(crash.get("t", 0.0)) >= fall - DT,
		"it falls its whole fall time to the street (%.2f s)" % Num.f(crash.get("t", 0.0))
	)
	check(_wreck(sim, id) == null, "a crashed wreck is removed")


func _check_crash_damage() -> void:
	var sim := _scene()
	var id := Num.i(_spin_onto(sim, Vector2.ZERO).get("heli", -1))
	var before := _alive(sim, 0)
	var crash := _until_crash(sim, id, Num.f(sim.air.cfg["fall_seconds"]) + 1.0)
	check(not crash.is_empty(), "the wreck crashes onto the block")
	check(
		_alive(sim, 0) < before,
		"its crash smashes the block it lands on (%d -> %d)" % [before, _alive(sim, 0)]
	)
	check(
		Num.f(crash.get("hurt", 1.0)) <= 0.0,
		"a crashing gunship never hurts the kaiju (%.2f)" % Num.f(crash.get("hurt", 1.0))
	)


func _check_lands_on_roof() -> void:
	var sim := _scene()
	var id := Num.i(_spin_onto(sim, Vector2.ZERO).get("heli", -1))
	var fall := Num.f(sim.air.cfg["fall_seconds"])
	var crash := _until_crash(sim, id, fall + 1.0)
	var y := Num.f(crash.get("y", 0.0))
	check(
		y > FLOORS - 1.0 and y <= FLOORS + 0.01,
		"over the block it crashes on the roof, never through it (y %.2f, roof %d)" % [y, FLOORS]
	)
	check(
		Num.f(crash.get("t", fall)) < fall - DT,
		"it meets the roof before its fall time ends (%.2f s)" % Num.f(crash.get("t", fall))
	)
	var open := _scene()
	var oid := Num.i(_spin_onto(open, OPEN).get("heli", -1))
	var street := _until_crash(open, oid, fall + 1.0)
	check(
		absf(Num.f(street.get("y", 1.0))) < 0.01,
		"the same fall over open street goes on to the ground (off)"
	)
