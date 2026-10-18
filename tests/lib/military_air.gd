extends "res://tests/lib/military_base.gd"
## The military suite's helicopter checks (D-066), kept here so run_military_tests.gd stays
## under its line cap: pairs, break-offs when faced, attack runs, and how they fly (nose, fire
## cone, roof clearance, no pivoting on the spot).


## Two helicopters fly as a pair: the second is the first one's wingman, close enough to read as
## a pair, never within PAIR_LATERAL of it across the ground (one never passes under the other),
## stacked higher, and on the same side of it through every turn, over 30 s of orbits, runs and
## break-offs.
func _check_heli_pairs() -> void:
	var sim := _rampage(2, 0)
	sim.air.cfg["hp"] = 1000000.0  # the pair must not be shot down mid-check
	var lead := sim.air.spawn()
	var wing := sim.air.spawn()
	var closest := INF
	var together := 0
	var stacked := 0
	var swaps := 0
	var was := 0.0
	var steps := roundi(30.0 / DT)
	for i: int in steps:
		sim.step(DT, Vector2.ZERO, false)
		closest = minf(closest, lead.pos.distance_to(wing.pos))
		if lead.pos.distance_to(wing.pos) < 30.0:
			together += 1
		if wing.alt >= lead.alt + 1.5:
			stacked += 1
		var side := signf(wrapf(wing.angle - lead.angle, -PI, PI))
		if was != 0.0 and side != was:
			swaps += 1
		was = side
	check(
		wing.wing_of == lead.id and closest >= PAIR_LATERAL and together > roundi(25.0 / DT),
		(
			(
				"a second helicopter flies wing on the first: never within %.1f m across the ground"
				% closest
			)
			+ ", within 30 m for %d of %d steps" % [together, steps]
		)
	)
	check(
		stacked > steps * 0.9 and swaps == 0,
		(
			"the wingman flies stacked over its lead (%d of %d steps) and never crosses it (%d)"
			% [stacked, steps, swaps]
		)
	)


## Facing a helicopter makes it break off: a kaiju that keeps turning to face it for 10 s is
## never dived on (after the first second it never comes inside its cruise distance, or where
## the game camera's frame draws that in, the closest the frame ever asks of it).
func _check_heli_faced() -> void:
	var sim := _rampage(2, 0)
	var heli := sim.air.spawn()
	var closest := INF
	var framed := INF
	for i: int in roundi(10.0 / DT):
		sim.facing = (heli.pos - sim.kaiju_pos).normalized()
		sim.step(DT, Vector2.ZERO, false)
		framed = minf(framed, _framed_cruise(sim, heli))
		if i > roundi(1.0 / DT):
			closest = minf(closest, heli.pos.distance_to(sim.kaiju_pos))
	check(
		closest >= framed - 1.0 and closest > sim.air.attack_radius() + 0.5,  # (1 m: its samples)
		(
			"a helicopter the kaiju faces never dives on it (closest %.2f m, framed cruise %.2f m)"
			% [closest, framed]
		)
	)


## Its cruise on its bearing, drawn in to stay in the game camera's frame (AirSpace.reach).
func _framed_cruise(sim: RampageSim, heli: AirWing.Heli) -> float:
	var at := sim.air.space.reach(heli.angle, Vector2(sim.air.attack_radius(), heli.cruise))
	return at if at >= 0.0 else heli.cruise


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
		elif inside and d >= _framed_cruise(sim, heli) - 0.5:
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
	var form: Dictionary = Content.section("air")["formation"]
	var cone := FIRE_YAW
	var worst := 0.0
	var highs := 0  # heli-steps above cruise
	var drops := 0  # ... coming down
	var stays := 0  # ... with no roof in reach to need it (it should be coming down)
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
					if heli.id == Num.i(event["heli"]):
						worst = maxf(worst, off)
					if (
						heli.id == Num.i(event["heli"])
						and (off > cone or heli.state != AirWing.RUN)
					):
						bad_shots += 1
			for heli: AirWing.Heli in sim.air.helis:
				lowest = minf(lowest, heli.alt - _roof_under(sim, heli.pos, ROTOR_CLEAR * 0.5))
				var before: Array = was.get(heli.id, [])
				var cruise := sim.air.altitude()
				if heli.wing_of >= 0:  # a wingman flies stacked over its lead
					cruise += Num.f(form["stagger"])
				if heli.alt > cruise + 0.05:
					highs += 1
					# Up only for a roof within its look-ahead, or one just passed (still coming down).
					var lag := (
						(heli.alt - cruise) / Num.f(form["climb"]) * Num.f(form["break_speed"])
					)
					var speed := 0.0
					if before.size() > 2:
						var at_was: Vector2 = before[0]
						speed = heli.pos.distance_to(at_was) / DT
					var ahead := speed * Num.f(form["climb_ahead"])
					var reach := (
						Num.f(form["facade"]) + Num.f(form["look_ahead"]) + ahead + lag * 1.5
					)
					if _roof_under(sim, heli.pos, reach) + Num.f(form["roof_clear"]) <= cruise:
						stays += 1
					if before.size() > 2 and heli.alt < Num.f(before[2]) - 0.001:
						drops += 1
				if not before.is_empty():
					var at: Vector2 = before[0]
					var nose: Vector2 = before[1]
					if rad_to_deg(absf(nose.angle_to(heli.front))) / DT > 45.0:
						turns += 1
						if heli.pos.distance_to(at) / DT < 3.0:
							hovers += 1
				was[heli.id] = [heli.pos, heli.front, heli.alt]
	check(
		shots > 20 and bad_shots == 0,
		(
			(
				"helicopters fire only on a run, nose within %.0f deg of the kaiju (%d of %d bursts not;"
				% [FIRE_YAW, bad_shots, shots]
			)
			+ " worst %.1f deg)" % worst
		)
	)
	check(lowest >= 1.0, "a helicopter's rotor stays clear of every roof (lowest %.1f m)" % lowest)
	check(
		highs > 50 and drops > 20 and stays == 0,
		(
			(
				"a helicopter climbs only for the roofs ahead and comes back down after (%d of %d"
				% [stays, highs]
			)
			+ " steps up with no roof near, %d coming down)" % drops
		)
	)
	check(
		turns > 20 and hovers == 0,
		(
			"helicopters turn in flight, never on the spot (%d of %d fast turns hovering)"
			% [hovers, turns]
		)
	)
