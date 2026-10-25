extends "res://tests/lib/powers_base.gd"
## Trains suite (the director 2026-10-21 #63 "train stations + tracks with trains on them", #69
## "Derail and smash"): an elevated line runs up one avenue with a station; trains run on a
## schedule, speeding up, cruising and stopping at the station; a stomp on a train derails it,
## the cars slide on with their momentum, slew and fall off the viaduct, and pay biomass like
## vehicles; a train behind stops short of the wreck. Player-effect fixture "trains.derail":
## the same seeded run with the kaiju stomping on the passing train against it standing away.
##   godot --headless --path . --script tests/run_trains_tests.gd

const AWAY := Vector2(-30, -30)


func suite_name() -> String:
	return "Trains"


func run_checks() -> void:
	await _t("_check_line_and_schedule")
	await _t("_check_station_stop")
	await _t("_check_stomp_derails")
	await _t("_check_train_behind_stops")
	await _t("_check_seeded")
	await _t("_check_walk_through_pillar")
	await _t("_check_walk_through_station")
	await _t("_check_building_topples_on_line")
	await _t("_check_carve_replay")


## The kaiju stands well clear of the line (its standing stomps would break the track).
func _scene() -> RampageSim:
	var sim := _sim("reptilian", {}, [], AWAY)
	sim.kaiju_pos = Vector2(Rail.avenue_x(sim.city) + AWAY.x, AWAY.y)
	return sim


## Steps until a train is running with its lead car past `share` of the line (or gives up).
func _until_running(sim: RampageSim, share: float) -> Rail.Train:
	for _i: int in roundi(120.0 / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
		for train: Rail.Train in sim.rail.trains:
			if train.state == Rail.RUN and train.s > sim.rail.length * share:
				return train
	return null


func _check_line_and_schedule() -> void:
	var sim := _scene()
	check(sim.rail != null and sim.rail.length > 40.0, "an elevated line runs up an avenue")
	var train := _until_running(sim, 0.1)
	check(train != null, "a train comes along on the schedule")
	if train == null:
		return
	check(
		train.cars.size() >= 4 and train.cars.size() <= 7,
		"a train is a locomotive and its carriages: %d cars" % train.cars.size()
	)
	var gap := train.cars[0].pos.distance_to(train.cars[1].pos)
	var want := Num.f(sim.rail.cfg["car_length"]) + Num.f(sim.rail.cfg["coupler_gap"])
	check(absf(gap - want) < 0.05, "the cars follow each other at the coupled spacing: %.2f" % gap)


func _check_station_stop() -> void:
	var sim := _scene()
	var stopped := false
	var v_max := 0.0
	for _i: int in roundi(150.0 / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
		for train: Rail.Train in sim.rail.trains:
			v_max = maxf(v_max, train.v)
			stopped = stopped or train.state == Rail.DWELL
	check(stopped, "a train stops at the station")
	var cruise := Num.f(sim.rail.cfg["cruise"])
	check(v_max > cruise * 0.9 and v_max <= cruise + 0.01, "it cruises at speed: %.2f" % v_max)


## The fixture: the kaiju stands on the passing train's second car (its stomp falls at once)
## against standing away; only the stomp derails the train and pays.
func _check_stomp_derails() -> void:
	var hit := _derail_run(true)
	var miss := _derail_run(false)
	var only_hit: bool = hit["derailed"] == true and miss["derailed"] == false
	check(
		only_hit,
		"trains.derail: the stomp derails the train, standing away does not: %s / %s" % [hit, miss]
	)
	check(
		Num.f(hit["rubble"]) > Num.f(miss["rubble"]),
		"trains.derail: the wreck pays biomass: %s / %s" % [hit["rubble"], miss["rubble"]]
	)
	check(
		Num.f(hit["off_line"]) > 1.0,
		"trains.derail: the cars leave the line: %.2f units" % Num.f(hit["off_line"])
	)
	check(Num.f(hit["fell"]) > 0.0, "trains.derail: a car falls off the viaduct")


func _derail_run(stomp: bool) -> Dictionary:
	var sim := _scene()
	var train := _until_running(sim, 0.2)
	if train == null:
		return {"derailed": false, "rubble": 0.0, "off_line": 0.0, "fell": 0.0}
	var rubble := sim.rubble
	if stomp:
		sim.kaiju_pos = train.cars[1].pos
	var derailed := false
	for _i: int in roundi(6.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			derailed = derailed or str(event["type"]) == "train_derailed"
	var off := 0.0
	var fell := 0.0
	for car: Rail.Car in train.cars:
		off = maxf(off, absf(car.pos.x - sim.rail.track_x(train.dir)))
		fell = maxf(fell, sim.rail.deck_y - car.y)
	return {"derailed": derailed, "rubble": sim.rubble - rubble, "off_line": off, "fell": fell}


## A broken track ahead: the next train brakes and stops short of it.
func _check_train_behind_stops() -> void:
	var sim := _scene()
	var train := _until_running(sim, 0.05)
	if train == null:
		check(false, "a train runs")
		return
	var at := train.s + 30.0
	sim.rail.break_track(at)
	for _i: int in roundi(25.0 / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
	check(
		train.state == Rail.STOPPED and train.s < at and train.s > at - 12.0,
		"a train stops short of the broken track: head %.1f, break %.1f" % [train.s, at]
	)


func _check_seeded() -> void:
	var a := _derail_run(true)
	var b := _derail_run(true)
	check(str(a) == str(b), "a derailment replays the same: %s / %s" % [a, b])


## ---- The railway breaks like every building (the director 2026-10-25, on trains.mp4: "the
## kaiju just clips right into the building, zero carve, it needs to be destroyed with the same
## logic as all other buildings"; "if buildings fall on the track they should damage it too";
## "should the railway itself (pillars, deck, station) break when the kaiju walks through it?"
## "Yes, all of it"). Every fixture is the player's effect: real walking, a real topple.


## A true/false field of a result.
func _is(r: Dictionary, key: String) -> bool:
	var v: bool = r.get(key, false)
	return v


## Part ids of `kind` that are no longer standing.
func _down(sim: RampageSim, kind: String) -> Array:
	var out: Array = []
	for part: RailParts.Part in sim.rail.parts.list:
		if part.kind == kind and not part.alive:
			out.append(part.id)
	return out


## The kaiju (a croc body) set down `gap` west of `at` facing east, to walk east with real input.
func _walker(at: Vector2, gap: float) -> RampageSim:
	var sim := _scene()
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(at.x - gap, at.y)
	sim.facing = EAST
	sim.body.heading = EAST
	return sim


## The west side's part of `kind` nearest `share` of the way down the line (null: none).
func _part_near(sim: RampageSim, kind: String, share: float) -> RailParts.Part:
	var want: float = sim.rail.point(sim.rail.length * share, 1).y
	var best: RailParts.Part = null
	for part: RailParts.Part in sim.rail.parts.list:
		if part.kind != kind or part.x > sim.rail.track_x(1) + 0.1:
			continue
		if best == null or absf(part.z0 - want) < absf(best.z0 - want):
			best = part
	return best


func _alive_string(sim: RampageSim) -> String:
	var out := ""
	for part: RailParts.Part in sim.rail.parts.list:
		out += "1" if part.alive else "0"
	return out


## Walks east into the pillar 80% down the line and on for a minute; what the player sees.
func _pillar_walk() -> Dictionary:
	var sim := _scene()
	var pillar := _part_near(sim, "pillar", 0.8)
	if pillar == null:
		return {"ok": false}
	sim = _walker(Vector2(pillar.x, pillar.z0), 8.0)
	var snapped_at := -1.0
	var seen := {}
	for i: int in roundi(60.0 / DT):
		for event: Dictionary in sim.step(DT, EAST, false, 0):
			seen[str(event["type"])] = true
		if snapped_at < 0.0 and not sim.rail.parts.list[pillar.id].alive:
			snapped_at = i * DT
	var stopped := false
	for train: Rail.Train in sim.rail.trains:
		stopped = stopped or train.state == Rail.STOPPED or train.state == Rail.WRECK
	var landed := 0
	for part: RailParts.Part in sim.rail.parts.list:
		landed += int(part.landed and part.kind == "span")
	return {
		"ok": true,
		"snapped_at": snapped_at,
		"spans_down": _down(sim, "span").size(),
		"landed": landed,
		"broken": sim.rail.broken().size(),
		"stopped": stopped,
		"events": seen.keys(),
		"alive": _alive_string(sim),
		"rubble": snappedf(sim.rubble, 0.001),
	}


## Player-effect fixture: walking into a pillar snaps it, the deck spans it held drop into the
## street, the track is broken there and the trains behind stop short or plough in.
func _check_walk_through_pillar() -> void:
	var r := _pillar_walk()
	check(_is(r, "ok"), "the railway has pillars as parts of its own to break")
	if not _is(r, "ok"):
		return
	var events: Array = r["events"]
	check(Num.f(r["snapped_at"]) >= 0.0, "walking into a pillar snaps it: %s" % [r])
	check(Num.i(r["spans_down"]) >= 1, "the deck spans it held are down: %s" % [r])
	check(Num.i(r["landed"]) >= 1, "a fallen span lands in the street: %s" % [r])
	check(Num.i(r["broken"]) >= 1, "the track is broken where the span fell: %s" % [r])
	check(_is(r, "stopped"), "a train behind stops short of the gap or ploughs in: %s" % [r])
	check(events.has("rail_part_broken"), "the break is an event the view reads: %s" % [r])


## Player-effect fixture: the kaiju walking through the station carves it, platforms and canopy.
func _check_walk_through_station() -> void:
	var sim := _scene()
	var seg := _part_near(sim, "station", 0.4)
	check(seg != null, "the station is made of parts of its own to break")
	if seg == null:
		return
	sim = _walker(Vector2(seg.x, (seg.z0 + seg.z1) * 0.5), 10.0)
	var before := _down(sim, "station").size()
	for _i: int in roundi(30.0 / DT):
		sim.step(DT, EAST, false, 0)
	var after := _down(sim, "station").size()
	check(after - before >= 2, "walking through the station breaks its platforms: %d" % after)


## Player-effect fixture: a tower toppled across the viaduct breaks the span it lands on and
## the train on it derails. The tower's base is eaten just before the train arrives under it.
func _check_building_topples_on_line() -> void:
	var r := _topple_run()
	check(_is(r, "ok"), "a tower beside the line can be toppled onto it")
	if not _is(r, "ok"):
		return
	check(_is(r, "toppled"), "the tower topples: %s" % [r])
	check(Num.i(r["spans_down"]) >= 1, "the toppled tower breaks the span it lands on: %s" % [r])
	check(Num.i(r["broken"]) >= 1, "and the track there: %s" % [r])
	check(_is(r, "derailed"), "the train on that span derails: %s" % [r])


func _topple_run() -> Dictionary:
	var probe := _scene()
	if probe.rail.parts.list.is_empty():
		return {"ok": false}
	var line_x: float = probe.rail.track_x(1)
	var bz: float = probe.rail.point(probe.rail.length * 0.7, 1).y
	var floors := 8
	var layout: Array[Dictionary] = [_b(line_x - 5.0, bz, Vector3i(4, 8, floors))]
	var sim := _sim("reptilian", {}, layout, AWAY)
	sim.kaiju_pos = Vector2(line_x - 30.0, bz)  # west of the tower: it falls away from him
	var fall_s := sqrt(2.0 * floors / Num.f(sim.city["fall_gravity"])) * 1.8
	var base: Array[Vector3i] = []
	for x: int in 4:
		for z: int in 8:
			base.append(Vector3i(x, 0, z))
	var cut := false
	for _i: int in roundi(70.0 / DT):
		for train: Rail.Train in sim.rail.trains:
			var ahead: float = train.cars[0].pos.y + train.v * fall_s
			if not cut and train.dwelled and train.state == Rail.RUN and ahead >= bz - 1.0:
				cut = true
				sim.damage_chunks(0, base, INF)
		sim.step(DT, Vector2.ZERO, false, 0)
	return {
		"ok": true,
		"toppled": sim.collapse.toppled == 1,
		"spans_down": _down(sim, "span").size(),
		"broken": sim.rail.broken().size(),
		"derailed": sim.rail.derailed >= 1,
		"alive": _alive_string(sim),
	}


## The seeded replay: the same walk twice breaks the same parts in the same way.
func _check_carve_replay() -> void:
	var a := _pillar_walk()
	var b := _pillar_walk()
	check(_is(a, "ok") and str(a) == str(b), "a carved railway replays the same: %s / %s" % [a, b])
