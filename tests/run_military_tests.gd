extends "res://tests/lib/military_base.gd"
## The army moves and fights like a professional military (D-066): tanks drive the road plan
## (never a building, a lot or an alley), keep their spacing, take firing posts at standoff range
## and fall back when the kaiju closes; helicopters fly in pairs, make deliberate attack runs that
## stop short of the kaiju's body, and break off when it faces them. Whole autoplayed rampages on
## generated cities, seeds 0-2, at the young and Behemoth stages (and the Apex city, where tanks
## enter round the kaiju, D-039). Includes the player-effect fixture (charging the guns).
## Seeded by design: every run takes Seeds.make("city"/"army", seed).


func suite_name() -> String:
	return "Military"


func run_checks() -> void:
	await process_frame
	_check_rampages()
	_check_heli_pairs()
	_check_heli_faced()
	_check_heli_run()
	_check_rubble()
	_check_charge_effect()


## Autoplayed rampages to the clock: every tank, every step, stays on a road and off every
## building and no two hulls overlap; a tank standing still 3 s or more within range stands at
## standoff in its firing band, never up close, and none waits inside the danger radius (those
## beyond range are in reserve); tanks enter by road from outside the
## playable edge (in a city smaller than the spawn radius); helicopters never fly into the kaiju.
func _check_rampages() -> void:
	var off_road := 0
	var inside := 0
	var tank_samples := 0
	var closest := INF
	var overlaps := 0
	var parked := 0
	var parked_in_band := 0
	var parked_reserve := 0
	var parked_close := 0
	var longest_in_danger := 0.0
	var entries_ok := true
	var entered := 0
	var heli_gap := INF
	var heli_samples := 0
	var where := ""
	for tier: int in LEVELS:
		for seed: int in SEEDS:
			var sim := _rampage(tier, seed)
			if tier == 2:  # the sky is open: helicopters up from the start
				sim.air.cfg["after_chunks"] = 0
			var roads := _roads(sim)
			var grid := _footprints(sim)
			var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
			var half := CityGen.half_extent(sim.city)
			var last := {}  # tank id -> position last step
			var still := {}  # tank id -> seconds it has stood still
			var heads := {}  # tank id -> the way it last moved (or faces the kaiju)
			var danger_t := {}  # tank id -> seconds parked inside the danger radius
			var convoy: Dictionary = sim.army.get("convoy", {})
			var box := sim.arena_half + Num.f(convoy.get("entry_depth", 0.0))
			var edge_entries := box <= Num.f(sim.army["spawn_radius"])
			var target := Vector2(INF, INF)
			var steps := 0
			while not sim.over:  # the game's own run length (run_seconds)
				target = _autoplay(sim, steps, target)
				steps += 1
				var reach := _reach(sim)
				var danger := _danger(sim)
				for tank: RampageSim.Tank in sim.tanks:
					tank_samples += 1
					if not last.has(tank.id):
						entered += 1
						if edge_entries and maxf(absf(tank.pos.x), absf(tank.pos.y)) < half - 0.01:
							entries_ok = false
					if not _on_road(tank.pos, roads):
						off_road += 1
						if where == "":
							where = (
								"tier %d seed %d tank %d at %v" % [tier, seed, tank.id, tank.pos]
							)
					if _in_building(tank.pos, grid):
						inside += 1
					var was_at: Vector2 = last.get(tank.id, tank.pos)
					if tank.pos.distance_to(was_at) > 0.001:
						heads[tank.id] = (tank.pos - was_at).normalized()
					elif not heads.has(tank.id):
						heads[tank.id] = (sim.kaiju_pos - tank.pos).normalized()
				for tank: RampageSim.Tank in sim.tanks:
					for other: RampageSim.Tank in sim.tanks:
						if (
							other.id > tank.id
							and tank.pos.distance_to(other.pos) < HULL_LENGTH * 1.2
						):
							var hu: Vector2 = heads[tank.id]
							var hw: Vector2 = heads[other.id]
							var hull := Vector2(HULL_LENGTH, HULL_HALF_WIDTH * 2.0) * 0.5
							if _hulls_overlap(tank.pos, hu, other.pos, hw, hull):
								overlaps += 1
							closest = minf(closest, tank.pos.distance_to(other.pos))
					var d := tank.pos.distance_to(sim.kaiju_pos)
					var was: Vector2 = last.get(tank.id, Vector2(INF, INF))
					var for_s := (
						Num.f(still.get(tank.id, 0.0)) + DT
						if tank.pos.distance_to(was) < 0.001
						else 0.0
					)
					still[tank.id] = for_s
					if for_s >= 3.0:
						parked += 1
						if d >= danger - 0.5 and d <= reach + 1.0:
							parked_in_band += 1
						elif d > reach + 1.0:
							parked_reserve += 1
						else:
							parked_close += 1
						if d < danger - 0.5:
							var t := Num.f(danger_t.get(tank.id, 0.0)) + DT
							danger_t[tank.id] = t
							longest_in_danger = maxf(longest_in_danger, t)
						else:
							danger_t[tank.id] = 0.0
					else:
						danger_t[tank.id] = 0.0
				last = {}
				for tank: RampageSim.Tank in sim.tanks:
					last[tank.id] = tank.pos
				for heli: AirWing.Heli in sim.air.helis:
					heli_samples += 1
					var clear := Num.f(sim.air.cfg["heli_radius"])
					heli_gap = minf(heli_gap, heli.pos.distance_to(sim.kaiju_pos) - body - clear)
	check(
		tank_samples > 2000 and inside == 0,
		(
			"no tank hull ever overlaps a building footprint (%d of %d tank-steps)"
			% [inside, tank_samples]
		)
	)
	check(
		off_road == 0,
		(
			"every tank drives on an avenue or street, never a lot or an alley (%d off: %s)"
			% [off_road, where]
		)
	)
	check(
		entries_ok and entered > 20,
		"all %d tanks enter by road from outside the playable edge" % entered
	)
	check(
		overlaps == 0,
		(
			"no two tank hulls ever overlap (%d tank-step pairs; closest centres %.2f m)"
			% [overlaps, closest]
		)
	)
	var standoff := float(parked_in_band) / maxf(1.0, float(parked_in_band + parked_close))
	check(
		parked_in_band > 300 and standoff >= 0.95 and longest_in_danger <= 1.0,
		(
			(
				"tanks hold standoff: %.0f%% of %d parked-in-range tank-steps sit in the firing"
				+ " band, not up close (%d in reserve beyond range); none stays inside the danger"
				+ " radius over 1 s (%.1f s)"
			)
			% [standoff * 100.0, parked_in_band + parked_close, parked_reserve, longest_in_danger]
		)
	)
	check(
		heli_samples > 500 and heli_gap >= HELI_CLEAR,
		(
			(
				"helicopters never fly into the kaiju: their hit circle stays %.1f m clear of its"
				+ " body (closest %.2f m, %d samples)"
			)
			% [HELI_CLEAR, heli_gap, heli_samples]
		)
	)


## Two helicopters fly as a pair: the second is the first one's wingman and the two never close
## inside an airframe of each other over 30 s of orbits and runs.
func _check_heli_pairs() -> void:
	var sim := _rampage(2, 0)
	var lead := sim.air.spawn()
	var wing := sim.air.spawn()
	var closest := INF
	var together := 0
	for i: int in roundi(30.0 / DT):
		sim.step(DT, Vector2.ZERO, false)
		closest = minf(closest, lead.pos.distance_to(wing.pos))
		if lead.pos.distance_to(wing.pos) < 20.0:
			together += 1
	check(
		wing.wing_of == lead.id and closest >= HELI_HALF * 1.2 and together > roundi(25.0 / DT),
		(
			(
				"a second helicopter flies wing on the first: never closer than %.1f m, within"
				+ " 20 m for %d of %d steps"
			)
			% [closest, together, roundi(30.0 / DT)]
		)
	)


## Facing a helicopter makes it break off: a kaiju that keeps turning to face it for 10 s is
## never dived on (its distance never falls more than 0.3 m after the first second).
func _check_heli_faced() -> void:
	var sim := _rampage(2, 0)
	var heli := sim.air.spawn()
	var start := INF
	var fell := 0.0
	for i: int in roundi(10.0 / DT):
		sim.facing = (heli.pos - sim.kaiju_pos).normalized()
		sim.step(DT, Vector2.ZERO, false)
		var d := heli.pos.distance_to(sim.kaiju_pos)
		if i == roundi(1.0 / DT):
			start = d
		if i > roundi(1.0 / DT):
			fell = maxf(fell, start - d)
			start = maxf(start, d)
	check(fell <= 0.3, "a helicopter the kaiju faces never dives on it (closed %.2f m)" % fell)


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


## A tower toppled across a column's road closes it: tanks routed through it re-plan at once and
## never drive that road again.
func _check_rubble() -> void:
	var sim := _rampage(1, 0)
	var target := Vector2(INF, INF)
	var tank: RampageSim.Tank = null
	for steps: int in roundi(20.0 / DT):
		target = _autoplay(sim, steps, target)
		for t: RampageSim.Tank in sim.tanks:
			var r: Convoy.Route = sim.army_units.convoy.routes[t.id]
			if tank == null and r.edges.size() >= 3:
				tank = t
		if tank != null:
			break
	if tank == null:
		check(false, "a tank with a road route to close")
		return
	var convoy := sim.army_units.convoy
	var route: Convoy.Route = convoy.routes[tank.id]
	var e := -1
	for leg: int in route.edges:
		if leg >= 0 and leg != route.edge:
			e = leg
			break
	var a := convoy.graph.nodes[convoy.graph.edge_a[e]]
	var b := convoy.graph.nodes[convoy.graph.edge_b[e]]
	var mid := (a + b) * 0.5
	var across := (b - a).normalized().orthogonal()
	sim.events.append(
		{
			"type": "fall_land",
			"kind": "topple",
			"from": mid - across * 4.0,
			"to": mid + across * 4.0,
			"width": 3.0
		}
	)
	sim.army_units.step(0.0)
	var rerouted := not route.edges.has(e) and convoy.graph.blocked[e] != 0
	var drove := false
	for steps: int in roundi(20.0 / DT):
		target = _autoplay(sim, steps, target)
		if not sim.tanks.has(tank):
			break
		var q := Geometry2D.get_closest_point_to_segment(tank.pos, a, b)
		if q.distance_to(tank.pos) < 0.5 and q.distance_to(a) > 3.0 and q.distance_to(b) > 3.0:
			drove = true
	check(
		rerouted and not drove,
		(
			"a toppled tower closes its road: the tank re-routes at once (%s) and never drives it (%s)"
			% [rerouted, drove]
		)
	)


## Player-effect fixture (D-066): the same seed, a kaiju charging the nearest tank for 40 s. The
## tanks fall back before it, so a charge crushes fewer of them than it does with the danger
## radius off (the old drive-in-and-sit army).
func _check_charge_effect() -> void:
	var kills: Array[int] = []
	for danger: float in [0.0, Num.f(Content.section("army")["convoy"]["danger"])]:
		var sim := _rampage(1, 1)
		sim.army_units.convoy.cfg = sim.army_units.convoy.cfg.duplicate()
		sim.army_units.convoy.cfg["danger"] = danger
		for steps: int in roundi(40.0 / DT):
			var move := Vector2.ZERO
			var best := INF
			for tank: RampageSim.Tank in sim.tanks:
				var d := tank.pos.distance_to(sim.kaiju_pos)
				if d < best:
					best = d
					move = (tank.pos - sim.kaiju_pos).normalized()
			sim.step(DT, move, false)
		kills.append(sim.tanks_destroyed)
	check(
		kills[1] < kills[0],
		(
			"falling back saves tanks from a charging kaiju (%d crushed vs %d without)"
			% [kills[1], kills[0]]
		)
	)
