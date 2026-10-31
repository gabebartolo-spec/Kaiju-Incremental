extends "res://tests/lib/leap_flight.gd"
## The croc's leap on the dash button (Dash, D-259 "a leap that lands on a building and crushes it
## with a shockwave (replaces the dash)"): it aims at the standing building ahead in reach (else the
## full reach), crouches, flies its stage's flight time and lands; nothing breaks before the contact
## (D-166), the landing breaks the building through the carve path, a ring hurts and flings tanks
## outward, the body takes no stick through the leap, the button waits out its cooldown, a frost
## coat shatters, and the same seed replays the same leap. Player-effect fixture "croc.leap": the
## same seeded rampage with the leap pressed and with it walked breaks a different city.
## Seeded by design: every sim is Seeds.make("army", 0); the fixture city is Seeds.make("city", 0).


func suite_name() -> String:
	return "Leap"


func run_checks() -> void:
	await _t("_check_aims_ahead")
	await _t("_check_open_ground")
	await _t("_check_tower_wall")
	await _t("_check_shoulder_measured")
	await _t("_check_low_roof")
	await _t("_check_tall_side")
	await _t("_check_breath_no_leap")
	await _t("_check_nowhere_to_land")
	await _t("_check_no_water")
	await _t("_check_phases")
	await _t("_check_ring_and_fling")
	await _t("_check_cooldown_and_frost")
	await _t("_check_replay")
	await _t("_check_effect")



## The breath press never starts the leap (director 2026-10-31: the croc floated while it breathed,
## as the breath and the dash shared bit 4); the dash press alone still does.
func _check_breath_no_leap() -> void:
	var breath := _croc({}, [])
	breath.step(DT, Vector2.ZERO, false, RampageSim.BREATH)
	var dash := _croc({}, [])
	dash.step(DT, Vector2.ZERO, false, BUTTON)
	var leaps := [breath.body.dash.on(), dash.body.dash.on()]
	check(
		RampageSim.BREATH & BUTTON == 0 and not breath.body.dash.on() and dash.body.dash.on(),
		"the breath press leaves the croc standing, the dash press leaps (breath, dash): %s" % [leaps]
	)


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
		var step := sim.step(DT, Vector2.ZERO, false, 0)
		if not _first(step, "leap_land").is_empty():
			landed = true
			at_contact = sim.chunks_destroyed - was
			break
		early += sim.chunks_destroyed
	check(landed and early == 0, "nothing breaks in the crouch or the flight (%d)" % early)
	check(at_contact > 0, "the landing blow breaks chunks on contact (%d)" % at_contact)
	var feet := sim.kaiju_pos + sim.facing * sim.body.feet_ahead()
	var roof := sim.body.dash.arc.land_y
	check(
		feet.distance_to(ahead) < 0.05 and roof == Num.f(layout[0]["h"]),
		(
			"the feet land on the building's roof, centre %.2f off, %.1f up"
			% [feet.distance_to(ahead), roof]
		)
	)
	var left := sim.buildings[0].frame.alive_count
	check(left < before, "the landing breaks the building (%d of %d chunks left)" % [left, before])
	var side := sim.buildings[1].frame.alive_count
	check(sim.chunks_destroyed > 0, "the landing pays (%d chunks destroyed)" % sim.chunks_destroyed)
	check(side > 0, "the building off to the side still stands (%d chunks)" % side)


## D-091: at a tower that dwarfs the young croc the leap comes down on the street before it, never
## inside it; the landing's ring reaches its wall and it is chewed, slowly.
func _check_tower_wall() -> void:
	var probe := _croc({}, [])
	var reach := Num.f(_stage(probe)["reach"]) * probe.body_scale()
	var tower := _block(_ahead(probe, reach * 0.6), 6, 12)
	tower["tier"] = 3
	var sim := _croc({}, [tower])
	var before := sim.buildings[0].frame.alive_count
	var worst := 0
	var ring := {}
	sim.step(DT, Vector2.ZERO, false, BUTTON)
	for _n: int in roundi(5.0 / DT):
		if not sim.body.dash.on():
			break
		var land := _first(sim.step(DT, Vector2.ZERO, false, 0), "leap_land")
		ring = ring if land.is_empty() else land
		worst = maxi(worst, Dictionary(sim.body.inside(sim.kaiju_pos, sim.body.heading)).size())
	check(
		sim.body.dash.landings == 1 and worst == 0,
		"the leap flies and lands clear of the tower, never inside it (%d inside)" % worst
	)
	var at: Vector2 = ring.get("at", Vector2.INF)
	var b := sim.buildings[0]
	var gap := Vector2(
		maxf(absf(at.x - b.x) - b.w * 0.5, 0.0), maxf(absf(at.y - b.z) - b.d * 0.5, 0.0)
	)
	check(
		gap.length() < 2.0 * Num.f(ring.get("radius", 0.0)),
		"the landing's ring reaches the tower's wall (%.1f from it)" % gap.length()
	)
	for _n: int in roundi(3.0 / DT):
		sim.step(DT, Vector2.ZERO, false, 0)  # standing at the wall: its stomps chew on (D-091)
	var left := b.frame.alive_count
	check(left < before, "the tower is chewed, slowly (%d of %d chunks left)" % [left, before])


## D-361: at every growth stage the data's shoulder (the roof height a leap may land on, as a share
## of the body's drawn height) is the drawn model's: its shoulder joint over its height.
func _check_shoulder_measured() -> void:
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		var sim := _croc(levels, [])
		var got := Num.f(_stage(sim).get("shoulder", 0.0))
		var want := _rig_shoulder(sim)
		check(
			want > 0.0 and absf(got - want) <= 0.005,
			"%s: the leap's shoulder is the model's (data %.3f, rig %.3f)" % [stage, got, want]
		)


## D-361: at every growth stage a roof at his shoulder or lower is still landed on, feet on it.
func _check_low_roof() -> void:
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		var probe := _croc(levels, [])
		var reach := Num.f(_stage(probe)["reach"]) * probe.body_scale()
		var ahead := _ahead(probe, reach * 0.6)
		var low := _block(ahead, 4, maxi(2, floori(_shoulder_y(probe))))
		var sim := _croc(levels, [low])
		var leap := _first(sim.step(DT, Vector2.ZERO, false, BUTTON), "leap")
		_finish(sim)
		var feet := sim.kaiju_pos + sim.facing * sim.body.feet_ahead()
		check(
			(
				Num.i(leap.get("building", -2)) == 0
				and Num.f(leap.get("roof", 0.0)) == Num.f(low["h"])
				and sim.body.dash.arc.land_y == Num.f(low["h"])
				and feet.distance_to(ahead) < 0.05
			),
			(
				"%s: a %d-high roof (shoulder %.2f) is landed on, feet %.2f off its centre: %s"
				% [stage, Num.i(low["h"]), _shoulder_y(probe), feet.distance_to(ahead), leap]
			)
		)


## D-361 ("Tall ones: hit the side"): at every growth stage a target taller than his shoulder
## takes the leap in its side: the arc never rises over it or comes down on its roof, the body
## carves into its side in flight (below its roof; a carved tower may then come down, Collapse),
## and the feet come down on the street at its foot, where the landing's smash and ring hit it.
func _check_tall_side() -> void:
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		var probe := _croc(levels, [])
		var reach := Num.f(_stage(probe)["reach"]) * probe.body_scale()
		var tall := _block(_ahead(probe, reach * 0.6), 6, ceili(_shoulder_y(probe) * 2.0))
		var sim := _croc(levels, [tall])
		var b := sim.buildings[0]
		var before := b.frame.alive_count
		var leap := _first(sim.step(DT, Vector2.ZERO, false, BUTTON), "leap")
		var watched := _watch_leap(sim, b)
		var apex := Num.f(watched["apex"])
		var flown := Num.i(watched["flown"])
		var side := Num.i(watched["side"])
		var land: Dictionary = watched["land"]
		var at: Vector2 = land.get("at", Vector2.INF)
		var step := Num.f(sim.body.dash.cfg["landing_step"])
		check(
			(
				Num.i(leap.get("building", -2)) == 0
				and Num.f(leap.get("roof", -1.0)) == 0.0
				and sim.body.dash.arc.land_y == 0.0
				and apex < float(b.height)
			),
			(
				"%s: a %d-high tower (shoulder %.2f) is never landed on: roof %.1f, apex %.2f"
				% [stage, b.height, _shoulder_y(probe), Num.f(leap.get("roof", -1.0)), apex]
			)
		)
		check(
			side > 0,
			(
				"%s: the body carves its side in flight (%d chunks, %d below its roof)"
				% [stage, flown, side]
			)
		)
		check(
			not _inside(b, at) and _gap(b, at) <= step + 0.01 and sim.body.dash.height() == 0.0,
			(
				"%s: the feet land on the street at its foot (%.2f from its wall)"
				% [stage, _gap(b, at)]
			)
		)
		check(
			(
				Num.i(land.get("building", -2)) == 0
				and _gap(b, at) < Num.f(land.get("radius", 0.0))
				and (b.frame.alive_count < before - flown or b.frame.alive_count == 0)
			),
			(
				"%s: the landing's smash and ring hit it (ring %.2f, %d of %d left)"
				% [stage, Num.f(land.get("radius", 0.0)), b.frame.alive_count, before]
			)
		)


## A press with nowhere to land but where it stands starts no leap (no cooldown, no count): facing
## out at the arena's edge, and with its snout at the wall of a tower it may not land on (D-091).
func _check_nowhere_to_land() -> void:
	var edge := _croc({}, [])
	edge.kaiju_pos = Vector2(0.0, -edge.arena_half)
	edge.facing = Vector2(0, -1)
	edge.body.heading = edge.facing
	var events := edge.step(DT, Vector2.ZERO, false, BUTTON)
	check(
		_first(events, "leap").is_empty() and edge.body.dash.dashes == 0,
		"facing out at the arena edge, a press does not leap (%d)" % edge.body.dash.dashes
	)
	check(
		edge.body.dash.ready_in == 0.0, "nor spends the cooldown (%.2f)" % edge.body.dash.ready_in
	)
	var probe := _croc({}, [])
	var front := 0.0
	for d: Array in probe.body.discs():
		front = maxf(front, Num.f(d[0]) + Num.f(d[1]))
	var face := 30.0 - front * probe.body_scale()  # the tower's near wall at the snout's tip
	var tower := _block(Vector2(0.0, face - 3.0), 6, 12)
	tower["tier"] = 3
	var sim := _croc({}, [tower])
	events = sim.step(DT, Vector2.ZERO, false, BUTTON)
	check(
		(
			_first(events, "leap").is_empty()
			and sim.body.dash.dashes == 0
			and sim.body.dash.ready_in == 0.0
		),
		(
			"snout at a tower's wall, a press does not leap or spend the cooldown (%d)"
			% sim.body.dash.dashes
		)
	)


## Director 2026-10-31 ("sometimes the kaiju can walk on water, even leaving crack fissures"):
## risen, it never walks or leaps into the sea bay's water (Emergence.wet); facing the bay from the
## shore, a walk stops at the water's edge and a leap comes down on dry land.
func _check_no_water() -> void:
	var probe := _croc({}, [])
	var shore := _shore(probe)
	check(shore.size() == 2, "the arena has sea bay water by its shore (%s)" % [shore])
	if shore.size() != 2:
		return
	var dry: Vector2 = shore[0]
	var out: Vector2 = shore[1]
	var walker := _facing(dry, out)
	var wet := 0
	for _n: int in roundi(4.0 / DT):
		walker.step(DT, out, false, 0)
		wet += int(walker.emerge.wet(walker.kaiju_pos))
	check(wet == 0, "walking at the bay it never steps into the water (%d wet steps)" % wet)
	var leaper := _facing(dry, out)
	leaper.step(DT, Vector2.ZERO, false, BUTTON)
	_finish(leaper)
	check(
		not leaper.emerge.wet(leaper.kaiju_pos),
		"a leap out over the bay lands on dry land (%s)" % [leaper.kaiju_pos]
	)


## A dry spot in the arena a step from the sea bay's water and the way out to it ([] with none).
func _shore(sim: RampageSim) -> Array:
	var step := 2.0
	var x := -sim.arena_half
	while x <= sim.arena_half:
		var z := -sim.arena_half
		while z <= sim.arena_half:
			var p := Vector2(x, z)
			if not sim.emerge.wet(p):
				for out: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					if sim.emerge.wet(p + out * step) and sim.emerge.wet(p + out * step * 4.0):
						return [p, out]
			z += step
		x += step
	return []


## A croc on open ground at `at`, facing `out`.
func _facing(at: Vector2, out: Vector2) -> RampageSim:
	var sim := _croc({}, [])
	sim.kaiju_pos = at
	sim.facing = out
	sim.body.heading = out
	return sim


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
