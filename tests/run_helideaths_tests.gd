extends "res://tests/lib/powers_base.gd"
## Helicopter deaths suite (AirWing, D-140, D-141, D-145): a hard killing blow blows a helicopter
## apart in the air; a light one sends it spinning down, its crew sometimes bailing out, and the
## wreck smashes the building it lands on (never the kaiju) and sets it burning with City Ablaze;
## a grabbed one only leaves the sky; the falls draw their own seeded stream, so spawns replay as
## before. Player-effect fixture "heli.deaths": the same downed helicopter breaks a building when
## it spins down onto it and breaks nothing when it is blown apart. Headless.
##   godot --headless --path . --script tests/run_helideaths_tests.gd

const ABLAZE := {"r_ablaze": 1}
const KAIJU_AT := Vector2(-20, 0)


func suite_name() -> String:
	return "HeliDeaths"


func run_checks() -> void:
	await _t("_check_burst")
	await _t("_check_spin_crash")
	await _t("_check_crash_fire")
	await _t("_check_grabbed")
	await _t("_check_topple")
	await _t("_check_seeded")


## One 3 x 3 x 4 block at the origin and one helicopter in the sky.
func _scene(levels: Dictionary) -> RampageSim:
	var sim := _sim("reptilian", levels, [_b(0, 0, Vector3i(3, 3, 4))], KAIJU_AT)
	sim.air.spawn()
	return sim


## Downs the only helicopter with a last blow of `blow` (its hp first set just under it).
func _down(sim: RampageSim, blow: float) -> Dictionary:
	var heli: AirWing.Heli = sim.air.helis[0]
	heli.hp = blow * 0.5
	sim.events.clear()
	sim.air.hit(func(_p: Vector2, _r: float) -> float: return 1.0, blow, true)
	for event: Dictionary in sim.events:
		if str(event["type"]) == "heli_destroyed":
			return event
	return {}


## Steps until the wreck lands (or `seconds` pass); returns the crash event, with "hurt": the
## kaiju's health lost on the crash's own step (other attackers may hurt it before), or {}.
func _until_crash(sim: RampageSim, seconds: float) -> Dictionary:
	for i: int in roundi(seconds / DT):
		var hp := sim.hp
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			if str(event["type"]) == "heli_crashed":
				event["hurt"] = hp - sim.hp
				return event
	return {}


## Spun down onto the block: its wreck is aimed straight at it.
func _aim_at_block(sim: RampageSim) -> void:
	var down: AirWing.Falling = sim.air.falling[0]
	down.pos = Vector2.ZERO
	down.drift = Vector2.ZERO


func _check_burst() -> void:
	var sim := _scene({})
	var hp := Num.f(sim.air.cfg["hp"])
	var rubble := sim.rubble
	var event := _down(sim, hp)
	check(
		str(event.get("fate", "")) == "burst" and sim.air.falling.is_empty(),
		"a killing blow of its full hp blows the helicopter apart in the air: %s" % event
	)
	check(
		sim.air.destroyed == 1 and sim.rubble > rubble,
		"a helicopter blown apart counts and pays (%d, %.1f)" % [sim.air.destroyed, sim.rubble]
	)
	var before := _alive(sim, 0)
	_until_crash(sim, 4.0)
	check(_alive(sim, 0) == before, "a helicopter blown apart in the air breaks no building")


func _check_spin_crash() -> void:
	var sim := _scene({})
	var hp := Num.f(sim.air.cfg["hp"])
	var event := _down(sim, hp * 0.2)
	check(
		str(event.get("fate", "")) == "spin" and sim.air.falling.size() == 1,
		"a glancing killing blow sends it spinning down: %s" % event
	)
	check(sim.air.helis.is_empty(), "a falling wreck no longer circles or fires")
	_aim_at_block(sim)
	var before := _alive(sim, 0)
	var crash := _until_crash(sim, Num.f(sim.air.cfg["fall_seconds"]) + 1.0)
	check(not crash.is_empty(), "the wreck reaches the street within its fall time")
	check(
		_alive(sim, 0) < before,
		"heli.deaths: the wreck smashes the block it lands on (%d -> %d)" % [before, _alive(sim, 0)]
	)
	check(
		Num.f(crash.get("hurt", 1.0)) <= 0.0,
		"a crashing wreck never hurts the kaiju (%.2f)" % Num.f(crash.get("hurt", 1.0))
	)
	check(sim.air.falling.is_empty(), "a crashed wreck is gone from the falling list")


func _check_crash_fire() -> void:
	for levels: Dictionary in [ABLAZE, {}]:
		var sim := _scene(levels)
		_down(sim, Num.f(sim.air.cfg["hp"]) * 0.2)
		_aim_at_block(sim)
		_until_crash(sim, Num.f(sim.air.cfg["fall_seconds"]) + 1.0)
		var burning := sim.powers.fire.state[0] >= FireSpread.State.BURNING
		var owned := not levels.is_empty()
		check(
			burning == owned,
			(
				"a wreck sets the block burning only with City Ablaze (owned %s, burning %s)"
				% [owned, burning]
			)
		)


func _check_grabbed() -> void:
	var sim := _scene({})
	sim.air.helis[0].hp = 0.0
	sim.events.clear()
	sim.air.clear_dead(true)
	var fates: Array = sim.events.map(func(e: Dictionary) -> String: return str(e.get("fate", "")))
	check(
		fates == ["grabbed"] and sim.air.falling.is_empty(),
		"a helicopter a tentacle grabs only leaves the sky: %s" % [fates]
	)


## A tower toppling through a helicopter knocks it spinning down; a short one does not.
func _check_topple() -> void:
	for height: float in [30.0, 3.0]:
		var sim := _scene({})
		var heli: AirWing.Heli = sim.air.helis[0]
		var start := heli.pos - Vector2(height * 0.5, 0)
		sim.events.clear()
		(
			sim
			. events
			. append(
				{
					"type": "fall_start",
					"kind": "topple",
					"pivot": Vector3(start.x, 0.0, start.y),
					"to": start + Vector2(height, 0),
					"width": 2.0,
				}
			)
		)
		sim.air.step(0.0)
		var downed := sim.air.falling.size() == 1
		check(
			downed == (height > sim.air.altitude()),
			(
				"a %.0f m tower toppling under a helicopter at %.0f m knocks it down: %s"
				% [height, sim.air.altitude(), downed]
			)
		)


## The same seed gives the same fall and crew; a fall never moves the spawn stream.
func _check_seeded() -> void:
	var runs: Array[Dictionary] = []
	for n: int in 2:
		var sim := _scene({})
		runs.append(_down(sim, Num.f(sim.air.cfg["hp"]) * 0.2))
	check(runs[0] == runs[1], "the same seed spins the same fall and crew: %s" % runs[0])
	var angles: Array[float] = []
	for blow_share: float in [0.2, 1.0]:  # a spin draws from the fall stream, a burst does not
		var sim := _scene({})
		_down(sim, Num.f(sim.air.cfg["hp"]) * blow_share)
		angles.append(sim.air.spawn().angle)
	check(
		is_equal_approx(angles[0], angles[1]),
		"a falling wreck leaves the next spawn where it would be: %s" % [angles]
	)
	var crews := 0
	for seed: int in 40:
		var sim := _sim("reptilian", {}, [_b(0, 0, Vector3i(3, 3, 4))], KAIJU_AT)
		sim.air = AirWing.new(sim, sim.air.cfg, Seeds.make("army", seed))
		sim.air.spawn()
		crews += Num.i(_down(sim, Num.f(sim.air.cfg["hp"]) * 0.2).get("crew", 0))
	check(crews > 0 and crews < 40 * 2, "some crews bail out, not all (%d in 40 falls)" % crews)
