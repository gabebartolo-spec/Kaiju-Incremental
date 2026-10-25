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
	await _t("_check_walk_through_carves")
	await _t("_check_station_breaks")
	await _t("_check_falling_building_damages_track")


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


## Steps a sim whose kaiju stands at `at` (AWAY: where _scene puts it) for `seconds`; returns it.
func _stand_at(at: Vector2, seconds: float) -> RampageSim:
	var sim := _scene()
	sim.stats["stomp_damage"] = 0.0  # no stomps: only the body walking through breaks it
	if at != AWAY:
		sim.kaiju_pos = at
	for _i: int in roundi(seconds / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
	return sim


func _standing(sim: RampageSim) -> int:
	var n := 0
	for i: int in sim.rail.bay_hp.size():
		n += int(sim.rail.bay_standing(i))
	return n


## D-247 "pillars, deck and station break when the kaiju walks through": the kaiju on the
## viaduct breaks the bays under it and the track with them; standing clear leaves it whole.
func _check_walk_through_carves() -> void:
	var probe := _scene()
	var rail := probe.rail
	var on_line := rail.point(rail.length * 0.3, 1)
	on_line.x = rail.centre_x()
	var hit := _stand_at(on_line, 0.7)
	var clear := _stand_at(AWAY, 0.7)
	check(clear.rail.broken().is_empty(), "the line stands when the kaiju is clear of it")
	check(
		not hit.rail.broken().is_empty(),
		"railway.carve: walking into the railway breaks the track: %s" % [hit.rail.broken()]
	)
	check(
		_standing(hit) < _standing(clear),
		"railway.carve: bays under the kaiju are gone: %d of %d stand"
			% [_standing(hit), hit.rail.bay_hp.size()]
	)
	check(
		_standing(hit) > hit.rail.bay_hp.size() / 2,
		"railway.carve: only the bays at its feet break: %d stand" % _standing(hit)
	)


## The station goes with the bay under it.
func _check_station_breaks() -> void:
	var probe := _scene()
	var rail := probe.rail
	var at := rail.point(rail.station_s(1), 1)
	at.x = rail.centre_x()
	var hit := _stand_at(at, 0.7)
	check(not hit.rail.station_standing, "railway.carve: the station breaks when walked through")
	check(_scene().rail.station_standing, "the station stands untouched")


## A tower toppling onto the viaduct damages the bays under its strip.
func _check_falling_building_damages_track() -> void:
	var sim := _scene()
	var rail := sim.rail
	var mid := rail.point(rail.length * 0.5, 1).y
	rail.crushed(func(p: Vector2, r: float) -> bool: return absf(p.y - mid) <= r)
	check(
		_standing(sim) < rail.bay_hp.size() and not rail.broken().is_empty(),
		"railway.carve: a toppled building breaks the track under its strip"
	)
