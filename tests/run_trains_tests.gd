extends "res://tests/lib/powers_base.gd"
## Trains suite (the director 2026-10-21 #63 "train stations + tracks with trains on them", #69
## "Derail and smash"): an elevated line runs up one avenue with a station; trains run on a
## schedule, speeding up, cruising and stopping at the station; a stomp on a train derails it,
## the cars slide on with their momentum, slew and fall off the viaduct, and pay biomass like
## vehicles; a train behind stops short of the wreck. Player-effect fixture "trains.derail":
## the same seeded run with the kaiju stomping on the passing train against it standing away.
##   godot --headless --path . --script tests/run_trains_tests.gd

const RailProbe := preload("res://tests/lib/rail_probe.gd")
const AWAY := Vector2(-30, -30)


func suite_name() -> String:
	return "Trains"


func run_checks() -> void:
	await _t("_check_line_and_schedule")
	await _t("_check_clear_of_spawn")
	await _t("_check_station_stop")
	await _t("_check_stomp_derails")
	await _t("_check_train_behind_stops")
	await _t("_check_seeded")
	await _t("_check_pieces_are_buildings")
	await _t("_check_contact_like_buildings")
	await _t("_check_walk_through_carves")
	await _t("_check_cut_span_falls")
	await _t("_check_falling_building_damages_track")
	await _t("_check_break_under_train_derails")


## The kaiju stands well clear of the line (its standing stomps would break the track).
func _scene() -> RampageSim:
	var sim := _sim("reptilian", {}, [], AWAY)
	sim.body.use_species("reptilian")  # the body as a solid (BodyContact), as in a run
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
	var x := Rail.avenue_x(sim.city)  # the fixed front (D-381) once pushed it to its west end
	check(
		absf(x) < sim.arena_half,
		"the line's avenue is in the arena: x %.0f within ±%.0f" % [x, sim.arena_half]
	)
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


## The viaduct stands clear of where the kaiju sets off (the middle of the south ring, x = 0) at
## every stage, so its first steps are not held up by it (the 1.5x city put it 10 m off: a 1.6 m
## walk in 1.5 s; tuning city "avenue_spawn_clear").
func _check_clear_of_spawn() -> void:
	var off: Array[float] = []
	var keep := 0.0
	for stage: int in [1, 2, 3]:
		var city: Dictionary = CityGrowth.tuning_for(Content.tuning(), stage)["city"]
		keep = Num.f(city["avenue_spawn_clear"])
		off.append(absf(Rail.avenue_x(city)))
	var nearest: float = off.min()
	check(
		keep > 0.0 and nearest >= keep,
		(
			"the viaduct stands %s m off the kaiju's start at the three stages (at least %.0f)"
			% [off, keep]
		)
	)


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


## D-247, the director 2026-10-25 "it needs to be destroyed with the same logic as all other
## buildings": every piece of the viaduct and the station is a building the shared carve takes,
## and stands on its own until something breaks it.
func _check_pieces_are_buildings() -> void:
	var sim := _scene()
	var rail := sim.rail
	check(
		rail.pieces.size() >= 4,
		"railway.carve: the line is built of pieces: %d" % rail.pieces.size()
	)
	var carved := 0
	var falls := 0
	var station := 0
	for n: int in rail.pieces:
		var b := sim.buildings[n]
		carved += int(b.is_rail() and sim.carving.takes(n))
		var st: Array = b.rail["station"]
		station += int(not st.is_empty())
		sim.carving._promote(n)
		var before := sim.falls.size()
		sim.collapse.settle(n)
		falls += sim.falls.size() - before
	check(
		carved == rail.pieces.size(),
		"railway.carve: the shared carve takes every piece: %d" % carved
	)
	check(station >= 1, "railway.carve: the station is part of the pieces round its stop")
	check(
		falls == 0, "railway.carve: the whole viaduct stands on its own columns: %d falls" % falls
	)


## The kaiju's body on piece n's deck, and on building m of the same size the same way: per touched
## chunk (BodyContact's rule, the same for both), the share of its cells the contact took, and the
## cells it took outside the chunks it touched. [rail share, building share, rail outside, building
## outside].
func _contact_side_by_side() -> Array:
	var probe := _scene()
	var n := RailProbe.piece_at(probe, probe.rail.point(probe.rail.length * 0.75, 1).y)
	var p := probe.buildings[n]
	var twin := _b(p.x - 30.0, p.z, Vector3i(p.w, p.d, p.height))
	var out := []
	for target: int in [0, 1]:
		var sim := _sim("reptilian", {}, [twin], AWAY)
		sim.body.use_species("reptilian")
		sim.stats["stomp_damage"] = 0.0
		sim.tail.on = false  # the body's own rule, side by side (the tail has its own suite)
		var m := sim.rail.pieces[probe.rail.pieces.find(n)] if target == 0 else 0
		var b := sim.buildings[m]
		sim.kaiju_pos = Vector2(b.x, b.z)
		sim.carving._promote(m)
		var touched: Dictionary = sim.body.inside(sim.kaiju_pos, sim.body.heading).get(m, {})
		var events := sim.step(DT, Vector2.ZERO, false, 0)
		var g: Carving.Grid = sim.carving.grids[m]
		var took := RailProbe.carved(events, m)
		var full := 0
		var inside := 0
		for ci: int in g.full.size():
			if touched.has(Carving._chunk_cell(g, ci)):
				full += g.full[ci]
		for i: int in took:
			inside += int(touched.has(Carving._chunk_cell(g, g.chunk(i))))
		out.append(float(inside) / maxf(1.0, full))
		out.append(took.size() - inside)
	return [out[0], out[2], out[1], out[3]]


## Bar 1 (lead, 2026-10-26): a rail piece loses voxels by the same rule and granularity as a
## building at the same contact, side by side in the same seed.
func _check_contact_like_buildings() -> void:
	var got := _contact_side_by_side()
	check(Num.f(got[1]) > 0.0, "railway.carve: the body takes the building it touches: %s" % [got])
	check(
		absf(Num.f(got[0]) - Num.f(got[1])) < 0.01 and Num.i(got[2]) == Num.i(got[3]),
		"railway.carve: the viaduct loses what a building loses at the same contact: %s" % [got]
	)


## Walks the kaiju across the line at world z (west to east); returns [steps, steps that ended
## with a rail chunk still inside the body, the most one piece lost in one step without a fall
## (share of its cells), cells carved from the pieces].
func _cross(z: float) -> Array:
	var sim := _scene()
	sim.stats["stomp_damage"] = 0.0
	var x := sim.rail.centre_x()
	sim.kaiju_pos = Vector2(x - 12.0, z)
	sim.facing = EAST
	sim.body.heading = EAST
	var cells := {}
	for n: int in sim.rail.pieces:
		var laid: Dictionary = (
			RailLayout.laid(sim.buildings[n], sim.rail.cfg, CellGrid.cell_res())[0]
		)
		cells[n] = laid.size()
	var through := 0
	var worst := 0.0
	var carved := 0
	var steps := 0
	while sim.kaiju_pos.x < x + 12.0 and steps < roundi(40.0 / DT):
		steps += 1
		var events := sim.step(DT, EAST, false, 0)
		var lost := {}
		var fell := {}
		for event: Dictionary in events:
			var b := Num.i(event.get("building", -1))
			if not cells.has(b):
				continue
			if str(event["type"]) == "cells_carved":
				var index: PackedInt32Array = event["index"]
				lost[b] = Num.i(lost.get(b, 0)) + index.size()
			elif str(event["type"]) == "fall_start":
				fell[b] = true
		for b: int in lost:
			carved += Num.i(lost[b])
			if not fell.has(b):
				worst = maxf(worst, Num.f(lost[b]) / Num.f(cells[b]))
		for b: int in sim.body.inside(sim.kaiju_pos, sim.body.heading):
			through += int(cells.has(b))
	return [steps, through, worst, carved]


## Bars 2 and 4: the croc never walks through the viaduct or the station without carving it, and
## no piece loses more than a quarter of its voxels in one step without falling parts.
func _check_walk_through_carves() -> void:
	var probe := _scene()
	var rail := probe.rail
	for z: float in [rail.point(rail.length * 0.75, 1).y, rail.point(rail.station_s(1), 1).y]:
		var got := _cross(z)
		check(Num.i(got[3]) > 0, "railway.carve: walking across at z %.0f carves it: %s" % [z, got])
		check(
			Num.i(got[1]) == 0, "railway.carve: nothing of it is left inside the body: %s" % [got]
		)
		check(
			Num.f(got[2]) <= 0.25,
			"railway.carve: no piece loses > 25%% at once unfalling: %s" % [got]
		)
	var hit := _stand_at(Vector2(rail.centre_x(), rail.point(rail.station_s(1), 1).y), 0.7)
	check(not hit.rail.station_standing, "railway.carve: the station breaks when walked through")
	check(_scene().rail.station_standing, "the station stands untouched")


## Bar 3: a span cut through at both ends falls as an island and breaks when it lands (its
## chunks pay as rubble); the track over it is broken.
func _check_cut_span_falls() -> void:
	var sim := _scene()
	var rail := sim.rail
	var n := RailProbe.piece_at(sim, rail.point(rail.length * 0.75, 1).y)
	var b := sim.buildings[n]
	var cut: Array[Vector3i] = []
	for z: int in [1, roundi(Num.f(rail.cfg["bay_length"])) - 1]:
		for x: int in b.w:
			for y: int in range(1, b.height):
				cut.append(Vector3i(x, y, z))
	var amounts := PackedFloat32Array()
	amounts.resize(cut.size())
	amounts.fill(INF)
	var rubble := sim.rubble
	sim.damage_cells(n, cut, amounts)
	var dropped := 0
	var landed := false
	for falling: RampageSim.Fall in sim.falls:
		dropped += int(
			falling.building == n and falling.kind == "drop" and not falling.cells.is_empty()
		)
	var paid := sim.rubble
	for _i: int in roundi(3.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			if str(event["type"]) == "fall_land" and Num.i(event["building"]) == n:
				landed = landed or event["scrap"] == false
	check(dropped >= 1, "railway.carve: the cut span falls as an island: %d" % dropped)
	check(
		landed and sim.rubble > paid,
		"railway.carve: it breaks when it lands: %.2f > %.2f" % [sim.rubble, paid]
	)
	check(paid > rubble, "railway.carve: the cut pays: %.2f > %.2f" % [paid, rubble])
	check(not rail.broken().is_empty(), "railway.carve: the cut breaks the track")


## A tower toppling onto the viaduct carves the deck where it lands, as it does any building.
func _check_falling_building_damages_track() -> void:
	var sim := _scene()
	var rail := sim.rail
	var mid := rail.point(rail.length * 0.75, 1).y
	var n := RailProbe.piece_at(sim, mid)
	var x := rail.centre_x()
	sim.collapse._crush_strip(Vector2(x - 8.0, mid), Vector2(x + 8.0, mid), 1.5, -1)
	sim.step(DT, Vector2.ZERO, false, 0)
	var g: Carving.Grid = sim.carving.grids.get(n, null)
	check(
		g != null and sim.carving.cells_carved > 0, "railway.carve: a toppled tower carves the deck"
	)
	check(not rail.broken().is_empty(), "railway.carve: the track under its strip is broken")


## The deck going from under a running train derails it.
func _check_break_under_train_derails() -> void:
	var sim := _scene()
	var train := _until_running(sim, 0.3)
	if train == null:
		check(false, "a train runs")
		return
	var at := train.cars[2].pos
	var n := RailProbe.piece_at(sim, at.y)
	var b := sim.buildings[n]
	var cz := floori(at.y - (b.z - b.d * 0.5))
	sim.damage_chunks(
		n, [Vector3i(floori(at.x - (b.x - b.w * 0.5)), 1, cz)] as Array[Vector3i], INF
	)
	sim.step(DT, Vector2.ZERO, false, 0)
	check(train.state == Rail.WRECK, "railway.carve: the train over a broken deck derails")
