extends "res://tests/lib/military_base.gd"
## The military suite's helicopter checks (D-066), kept here so run_military_tests.gd stays
## under its line cap: pairs, break-offs when faced, attack runs, and how they fly (nose, fire
## cone, roof clearance, no pivoting on the spot).


## Two helicopters fly as a pair: the second is the first one's wingman, close enough to read as
## a pair, and their rotors never meet over 30 s of orbits, runs and break-offs.
func _check_heli_pairs() -> void:
	var sim := _rampage(2, 0)
	sim.air.cfg["hp"] = 1000000.0  # the pair must not be shot down mid-check
	var lead := sim.air.spawn()
	var wing := sim.air.spawn()
	var closest := INF
	var together := 0
	for i: int in roundi(30.0 / DT):
		sim.step(DT, Vector2.ZERO, false)
		closest = minf(closest, lead.pos.distance_to(wing.pos))
		if lead.pos.distance_to(wing.pos) < 25.0:
			together += 1
	check(
		wing.wing_of == lead.id and closest >= ROTOR_CLEAR and together > roundi(25.0 / DT),
		(
			(
				"a second helicopter flies wing on the first: never closer than %.1f m, within"
				+ " 25 m for %d of %d steps"
			)
			% [closest, together, roundi(30.0 / DT)]
		)
	)


## Facing a helicopter makes it break off: a kaiju that keeps turning to face it for 10 s is
## never dived on (after the first second it never comes inside its cruise distance; it may
## swing wider as it turns about).
func _check_heli_faced() -> void:
	var sim := _rampage(2, 0)
	var heli := sim.air.spawn()
	var closest := INF
	for i: int in roundi(10.0 / DT):
		sim.facing = (heli.pos - sim.kaiju_pos).normalized()
		sim.step(DT, Vector2.ZERO, false)
		if i > roundi(1.0 / DT):
			closest = minf(closest, heli.pos.distance_to(sim.kaiju_pos))
	check(
		closest >= heli.cruise - 0.3,
		(
			"a helicopter the kaiju faces never dives on it (closest %.2f m, cruise %.2f m)"
			% [closest, heli.cruise]
		)
	)


## With the kaiju looking away, a helicopter makes deliberate attack runs: in to its attack radius
## and back out to cruise, more than once in 20 s.
func _check_heli_run() -> void:
	var sim := _rampage(2, 0)
	var heli := sim.air.spawn()
	var runs := 0
	var inside := false
	for i: int in roundi(20.0 / DT):
		sim.facing = -(heli.pos - sim.kaiju_pos).normalized()
		sim.step(DT, Vector2.ZERO, false)
		var d := heli.pos.distance_to(sim.kaiju_pos)
		if not inside and d <= sim.air.attack_radius() + 0.5:
			inside = true
			runs += 1
		elif inside and d >= heli.cruise - 0.5:
			inside = false
	check(runs >= 2, "a helicopter makes deliberate attack runs in and out (%d in 20 s)" % runs)


## Helicopters fly like gunships over whole Behemoth rampages (the sky open from the start): they
## fire only on a run with the nose within fire_cone of the kaiju (never on the break-off), keep
## their rotor clear of every roof under it, and never pivot on the spot (a nose swinging faster
## than 45 degrees a second always comes with 3 m/s or more over the ground).
func _check_heli_flight() -> void:
	var bad_shots := 0
	var shots := 0
	var lowest := INF
	var hovers := 0
	var turns := 0
	var cone := Num.f(Content.section("air")["formation"]["fire_cone"]) + 1.0
	for seed: int in SEEDS:
		var sim := _rampage(2, seed)
		sim.air.cfg["after_chunks"] = 0
		var was := {}  # heli id -> [pos, front] the step before
		var target := Vector2(INF, INF)
		var steps := 0
		while not sim.over:
			target = _autoplay(sim, steps, target)
			steps += 1
			for event: Dictionary in sim.events:
				if str(event["type"]) != "heli_fired":
					continue
				shots += 1
				for heli: AirWing.Heli in sim.air.helis:
					var off := rad_to_deg(absf(heli.front.angle_to(sim.kaiju_pos - heli.pos)))
					if (
						heli.id == Num.i(event["heli"])
						and (off > cone or heli.state != AirWing.RUN)
					):
						bad_shots += 1
			for heli: AirWing.Heli in sim.air.helis:
				lowest = minf(lowest, heli.alt - _roof_under(sim, heli.pos, ROTOR_CLEAR * 0.5))
				var before: Array = was.get(heli.id, [])
				if not before.is_empty():
					var at: Vector2 = before[0]
					var nose: Vector2 = before[1]
					if rad_to_deg(absf(nose.angle_to(heli.front))) / DT > 45.0:
						turns += 1
						if heli.pos.distance_to(at) / DT < 3.0:
							hovers += 1
				was[heli.id] = [heli.pos, heli.front]
	check(
		shots > 20 and bad_shots == 0,
		(
			"helicopters fire only on a run, nose on the kaiju (%d of %d bursts not)"
			% [bad_shots, shots]
		)
	)
	check(lowest >= 1.0, "a helicopter's rotor stays clear of every roof (lowest %.1f m)" % lowest)
	check(
		turns > 20 and hovers == 0,
		(
			"helicopters turn in flight, never on the spot (%d of %d fast turns hovering)"
			% [hovers, turns]
		)
	)
