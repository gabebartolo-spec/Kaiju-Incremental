extends "res://tests/lib/military_view.gd"
## The tanks move and fight like a professional military (D-066): they drive the road plan
## (never a building, a lot or an alley), keep their spacing as drawn (hull, turret and gun), take
## firing posts at standoff range and fall back when the kaiju closes. Whole autoplayed rampages
## on generated cities (RAMPAGE_SEEDS), at the young and Behemoth stages (and the Colossus city,
## where tanks enter round the kaiju, D-039, D-135), and the clip's scene through the game camera.
## The helicopters are today's (their flight is its own branch, claude/heli-flight). Helpers: the
## clumsy army's strays (MilitaryStray) and a boxed-in tank's bounded yield (MilitaryYield).
## Seeded by design: every run takes Seeds.make("city"/"army", seed).

const MilitaryStray := preload("res://tests/lib/military_stray.gd")
const MilitaryYield := preload("res://tests/lib/military_yield.gd")

## Parked-in-range tank-steps the rampages must see before their standoff share means anything.
const MIN_PARKED_IN_RANGE := 20
## The rampages' city and army seeds, pinned so the autoplay lingers where tanks take posts:
## since the body turns on arcs (turn-weight) seeds 0-2 saw none; a probe of seeds 0-11 found
## tanks parked in range only at the Behemoth tier, most on seeds 4 (26) and 8 (66). Re-probed
## after look-options' city changes (2026-10-21): Behemoth seeds 2 (25), 4 (6) and 8 (6), all in
## the band; seed 0 saw none. Re-probed seeds 0-11 when bigger bodies turned slower (turn-step,
## 2026-10-21): seeds 2, 4, 8 fell to 5 in all; Behemoth seeds 3 (27), 6 (73), 9 (54), 10 (31).
## Re-probed for D-135 (wider cities, army.spawn_radius per stage): the old seeds 3, 6, 9 park only
## 5 tank-steps in range on the shipped data, and in seeds 0-70 at the Behemoth only seeds 3 (5),
## 11 (16), 15 (20), 25 (13), 42 (7) and 17 (2) park any, so a tank standing in range is rare.
## Seeds 3, 11, 15 and 25 give 38 tank-steps on Windows against the bar of 20; CI (Linux) read 16
## where Windows read 21 on the earlier pin (float drift, the same seeds repeat exactly on one
## machine), so the margin is about 1.9x.
const RAMPAGE_SEEDS: Array[int] = [3, 11, 15, 25]


func suite_name() -> String:
	return "Military"


func run_checks() -> void:
	await _t("_check_view")
	await _t("_check_rampages")
	await _h("MilitaryStray", func() -> void: MilitaryStray.new(check, _rampage, _autoplay).run())
	await _h("MilitaryYield", func() -> void: MilitaryYield.new(check, _rampage).run())
	await _t("_check_standoff_held")
	await _t("_check_pivot_beside_parked")
	await _t("_check_rubble")


## Autoplayed rampages to the clock: every tank, every step, stays on a road and off every
## building and no two hulls overlap; a tank standing a second or more within range stands at
## standoff in its firing band, never up close, and none waits inside the danger radius (those
## beyond range are in reserve); tanks enter by road from outside the
## playable edge (in a city smaller than the spawn radius). Tanks take posts in range during
## the rampages too, and there are at least MIN_PARKED_IN_RANGE such tank-steps, so the standoff
## and danger bars never pass on nothing.
func _check_rampages() -> void:
	var off_road := 0
	var inside := 0
	var tank_samples := 0
	var closest := INF
	var overlaps := 0
	var parked := 0
	var skewed := 0
	var driving := 0
	var crabbing := 0
	var parked_in_band := 0
	var parked_reserve := 0
	var parked_close := 0
	var longest_in_danger := 0.0
	var entries_ok := true
	var entered := 0
	var where := ""
	for tier: int in LEVELS:
		for seed: int in RAMPAGE_SEEDS:
			var sim := _rampage(tier, seed)
			var roads := _roads(sim)
			var grid := _footprints(sim)
			var half := CityGen.half_extent(sim.city)
			var last := {}  # tank id -> position last step
			var still := {}  # tank id -> seconds it has stood still
			var heads := {}  # tank id -> where its hull points
			var hulls_was := {}  # ... and the step before (a hull still turning is not still)
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
					var was_at: Vector2 = last.get(tank.id, tank.pos)
					var drawn := sim.army_units.convoy.front(tank.id)  # the hull the view draws
					if drawn != Vector2.ZERO:
						heads[tank.id] = drawn
					elif tank.pos.distance_to(was_at) > 0.001:
						heads[tank.id] = (tank.pos - was_at).normalized()
					elif not heads.has(tank.id):
						heads[tank.id] = (sim.kaiju_pos - tank.pos).normalized()
					var head: Vector2 = heads[tank.id]
					if _hull_in_building(tank.pos, head, grid):
						inside += 1
				for tank: RampageSim.Tank in sim.tanks:
					for other: RampageSim.Tank in sim.tanks:
						if (
							other.id > tank.id
							and tank.pos.distance_to(other.pos) < HULL_LENGTH * 2.5
						):
							var hu: Vector2 = heads[tank.id]
							var hw: Vector2 = heads[other.id]
							if _tanks_touch(tank.pos, hu, other.pos, hw, sim.kaiju_pos):
								overlaps += 1
							closest = minf(closest, tank.pos.distance_to(other.pos))
					var d := tank.pos.distance_to(sim.kaiju_pos)
					var was: Vector2 = last.get(tank.id, Vector2(INF, INF))
					var turned: Vector2 = hulls_was.get(tank.id, Vector2.ZERO)
					var head_now: Vector2 = heads[tank.id]
					var standing := tank.pos.distance_to(was) < 0.001 and turned == head_now
					var for_s := Num.f(still.get(tank.id, 0.0)) + DT if standing else 0.0
					if was.x != INF and tank.pos.distance_to(was) >= 0.001:
						driving += 1
						if not _along_road(tank.pos, head_now, roads, DRIVE_DEG):
							crabbing += 1
					still[tank.id] = for_s
					if for_s >= 3.0:
						parked += 1
						var lies: Vector2 = heads[tank.id]
						if not _along_road(tank.pos, lies, roads):
							skewed += 1
					if for_s >= 1.0 and not _falling_back(sim, tank):  # where a tank chose to stand
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
				hulls_was = heads.duplicate()
				for tank: RampageSim.Tank in sim.tanks:
					last[tank.id] = tank.pos
	var in_band := float(parked_in_band) / maxf(1.0, float(parked_in_band + parked_close))
	print(
		(
			"RAMPAGES parked skewed %d of %d, driving skewed %d of %d, in band %.0f%% of %d"
			% [skewed, parked, crabbing, driving, in_band * 100.0, parked_in_band + parked_close]
		)
	)
	check(
		tank_samples > 2000 and inside == 0,
		(
			"no tank hull ever overlaps a building footprint (%d of %d tank-steps)"
			% [inside, tank_samples]
		)
	)
	check(
		parked > 100 and skewed == 0,
		(
			(
				"a tank standing still lies along its road, never mid-pivot (%d of %d parked"
				+ " tank-steps skewed past %.0f degrees)"
			)
			% [skewed, parked, ALIGN_DEG]
		)
	)
	check(
		driving > 1000 and crabbing == 0,
		(
			(
				"a driving tank keeps its hull along its road (%d of %d driving tank-steps past %.0f"
				% [crabbing, driving, DRIVE_DEG]
			)
			+ " degrees)"
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
			"no two tanks as drawn (hull, turret, gun) ever touch (%d pairs; closest %.2f m)"
			% [overlaps, closest]
		)
	)
	var standoff := float(parked_in_band) / maxf(1.0, float(parked_in_band + parked_close))
	check(
		parked_in_band + parked_close >= MIN_PARKED_IN_RANGE,
		(
			"the rampages see tanks parked in range: %d tank-steps (at least %d to judge standoff)"
			% [parked_in_band + parked_close, MIN_PARKED_IN_RANGE]
		)
	)
	check(
		parked_in_band > 0 and standoff >= 0.95 and longest_in_danger <= 1.0,
		(
			(
				"tanks hold standoff: %.0f%% of %d parked-in-range tank-steps sit in the firing"
				+ " band, not up close (%d in reserve beyond range); none stays inside the danger"
				+ " radius over 1 s (%.1f s)"
			)
			% [standoff * 100.0, parked_in_band + parked_close, parked_reserve, longest_in_danger]
		)
	)


## Tanks take firing posts at standoff when the kaiju gives them time (D-066): it stands where it
## spawns at the young stage for a whole run on each seed; tanks that stand a second or more
## within range are in the firing band, not up close, and there are enough of them to say so.
## (The rampages above only see this when the autoplay happens to linger: the stage-2 stadium
## used to hold it, red-115.)
func _check_standoff_held() -> void:
	var in_band := 0
	var close := 0
	for seed: int in SEEDS:
		var sim := _rampage(2, seed)
		var still := {}  # tank id -> seconds it has stood still
		var last := {}
		while not sim.over:
			sim.step(DT, Vector2.ZERO, false, RampageSim.STOMP)
			var reach := _reach(sim)
			var danger := _danger(sim)
			var now := {}
			for tank: RampageSim.Tank in sim.tanks:
				var was: Vector2 = last.get(tank.id, Vector2(INF, INF))
				var standing := tank.pos.distance_to(was) < 0.001
				var for_s := Num.f(still.get(tank.id, 0.0)) + DT if standing else 0.0
				still[tank.id] = for_s
				now[tank.id] = tank.pos
				var d := tank.pos.distance_to(sim.kaiju_pos)
				if for_s >= 1.0 and d <= reach + 1.0:
					if d >= danger - 0.5:
						in_band += 1
					else:
						close += 1
			last = now
	var share := float(in_band) / maxf(1.0, float(in_band + close))
	check(
		in_band > 40 and share >= 0.95,
		(
			(
				"with the kaiju standing still, tanks take firing posts at standoff: %d tank-steps"
				+ " in the band, %d up close (%.0f%%)"
			)
			% [in_band, close, share * 100.0]
		)
	)


## A tank falling back from the kaiju and held up (its road blocked) did not choose to stand where
## it is: it may be caught and die, and is not counted as parked or firing. Director 2026-10-22:
## "the tank doesnt need to avoid the breath, just let it die, even the most professional soldier
## wouldnt know to anticipate the breath in that moment". Tanks that chose their post still count.
func _falling_back(sim: RampageSim, tank: RampageSim.Tank) -> bool:
	var route: ConvoyRoute = sim.army_units.convoy.routes.get(tank.id)
	return route != null and route.retreating


## The named case behind a red PR #89 (tier 1, city seed 2, steps 531-535): a tank entering at the
## city edge stopped 4.9 m from one parked in the next road, inside each other's `clear` margin,
## and both then pivoted (one flip-flopping 6 degrees a step) until their drawn hulls touched. A
## pivot from inside that margin must never end with the drawn parts touching.
func _check_pivot_beside_parked() -> void:
	var sim := _rampage(1, 2)
	var target := Vector2(INF, INF)
	var touching := 0
	var checked := 0
	for steps: int in 600:
		target = _autoplay(sim, steps, target)
		for tank: RampageSim.Tank in sim.tanks:
			for other: RampageSim.Tank in sim.tanks:
				if other.id <= tank.id or tank.pos.distance_to(other.pos) > HULL_LENGTH * 2.5:
					continue
				var hu: Vector2 = sim.army_units.convoy.front(tank.id)
				var hw: Vector2 = sim.army_units.convoy.front(other.id)
				if hu == Vector2.ZERO or hw == Vector2.ZERO:
					continue
				checked += 1
				if _tanks_touch(tank.pos, hu, other.pos, hw, sim.kaiju_pos):
					touching += 1
	check(
		checked > 100 and touching == 0,
		(
			"tier 1 seed 2, first 600 steps: tanks pivoting beside a parked one never touch as"
			+ " drawn (%d touching of %d close pair-steps)" % [touching, checked]
		)
	)


## A tower toppled across a column's road closes it: tanks routed through it re-plan at once and
## never drive that road again.
func _check_rubble() -> void:
	var sim := _rampage(1, 0)
	var target := Vector2(INF, INF)
	var tank: RampageSim.Tank = null
	for steps: int in roundi(20.0 / DT):
		target = _autoplay(sim, steps, target)
		for t: RampageSim.Tank in sim.tanks:
			var r: ConvoyRoute = sim.army_units.convoy.routes[t.id]
			if tank == null and r.edges.size() >= 3:
				tank = t
		if tank != null:
			break
	if tank == null:
		check(false, "a tank with a road route to close")
		return
	var convoy := sim.army_units.convoy
	var route: ConvoyRoute = convoy.routes[tank.id]
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
