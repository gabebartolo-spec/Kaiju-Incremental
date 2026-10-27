extends "res://tests/lib/runner.gd"
## Shared fixtures for the croc leap suite (run_leap_tests): the croc standing at (0, 30) on a
## hand-made layout, the stage data, the tank, and the seeded-city fixture run.

const DT := 1.0 / 60.0
const BUTTON := 4  # Dash.BUTTON
## The growth steps: the young croc, Behemoth, Colossus (the leap's three stages).
const STAGES := {"young": {}, "Behemoth": {"evolve1": 1}, "Colossus": {"evolve1": 1, "evolve2": 1}}
## The fixture: seconds walked before the press, then seconds watched after it.
const FIXTURE_LEAD_S := 1.0
const FIXTURE_WATCH_S := 4.0
const FIXTURE_MAX_N := 600


## The reptilian at `levels`, as Rampage builds it, standing at (0, 30) facing north, on `layout`
## plus a small block far behind it, so the run is not over for want of a city.
func _croc(levels: Dictionary, p_layout: Array[Dictionary]) -> RampageSim:
	var layout := p_layout.duplicate()
	layout.append(_block(Vector2(38.0, 38.0), 2, 2))
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.ability_type = "cone"
	sim.body.use_species("reptilian")
	sim.time_left = 1.0e9
	sim.kaiju_pos = Vector2(0.0, 30.0)
	return sim


## A building of `w` x `w` cells, `h` floors, centred at `at`.
func _block(at: Vector2, w: int, h: int) -> Dictionary:
	return {"x": at.x, "z": at.y, "w": w, "d": w, "h": h, "tier": 1, "style": 0}


## Where the feet of a croc at (0, 30) facing north land on a building centre `ahead` units on.
func _ahead(sim: RampageSim, ahead: float) -> Vector2:
	return Vector2(0.0, 30.0 - sim.body.feet_ahead() - ahead)


## Steps the sim until the leap is over (at most 5 s), returning every event on the way.
func _finish(sim: RampageSim, stick: Vector2 = Vector2.ZERO) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for _n: int in roundi(5.0 / DT):
		if not sim.body.dash.on():
			break
		seen.append_array(sim.step(DT, stick, false, 0))
	return seen


## Like _finish, but every tank in `held` is put back on the spot it has now before each step until
## the landing: a young croc's firing band now reaches a tank standing in its way, so the convoy
## drives it toward a post, and this fixture tests the ring, not that driving.
func _finish_held(sim: RampageSim, held: Array[RampageSim.Tank]) -> Array[Dictionary]:
	var spots: Array[Vector2] = []
	for tank: RampageSim.Tank in held:
		spots.append(tank.pos)
	var seen: Array[Dictionary] = []
	var landed := false
	for _n: int in roundi(5.0 / DT):
		if not sim.body.dash.on():
			break
		if not landed:
			for i: int in held.size():
				held[i].pos = spots[i]
		var events := sim.step(DT, Vector2.ZERO, false, 0)
		landed = landed or not _first(events, "leap_land").is_empty()
		seen.append_array(events)
	return seen


func _first(events: Array[Dictionary], kind: String) -> Dictionary:
	for event: Dictionary in events:
		if str(event["type"]) == kind:
			return event
	return {}


func _tank(sim: RampageSim, id: int, at: Vector2) -> RampageSim.Tank:
	var tank := RampageSim.Tank.new()
	tank.id = id
	tank.pos = at
	tank.hp = 1000.0
	tank.cooldown = 1.0e9
	sim.tanks.append(tank)
	return tank


## The croc walks north into the seeded city FIXTURE_LEAD_S and on until a roof it can land on is
## ahead (at most FIXTURE_MAX_N steps), then (with `leap`) presses the button,
## and is watched FIXTURE_WATCH_S with the stick held north.
func _run_city(leap: bool) -> Dictionary:
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := _croc({}, layout)
	sim.kaiju_pos = Vector2(0.0, CityGen.half_extent(sim.city))
	var north := Vector2(0, -1)
	for _n: int in roundi(FIXTURE_LEAD_S / DT):
		sim.step(DT, north, false, 0)
	var more := 0  # walks on until a roof it can land on is ahead (a tower is _check_tower_wall's,
	# a tall one's side _check_tall_side's) and its body stands clear of every building
	while not _clear_roof_ahead(sim, north) and more < FIXTURE_MAX_N:
		sim.step(DT, north, false, 0)
		more += 1
	sim.step(DT, north, false, BUTTON if leap else 0)
	var in_flight := 0  # chunks broken and building overlaps while the body is in the air
	for _n: int in roundi(FIXTURE_WATCH_S / DT):
		var flying := sim.body.dash.phase() == "flight"
		var was := sim.body.broken
		sim.step(DT, north, false, 0)
		if flying and sim.body.dash.phase() == "flight":
			in_flight += sim.body.broken - was
			in_flight += sim.body.inside(sim.kaiju_pos, sim.body.heading).size()
	return {
		"in_flight": in_flight,
		"roof": sim.body.dash.arc.land_y,
		"blocked": sim.body.dash.arc.blocked,
		"landings": sim.body.dash.landings,
		"chunks": sim.chunks_destroyed,
		"rubble": snappedf(sim.rubble, 0.001),
		"at": sim.kaiju_pos.snapped(Vector2(0.001, 0.001)),
		"walked_on": more,
	}


## Steps a pressed leap at building `b` to its end: its highest lift ("apex"), the chunks of `b`
## broken while the body is still in the air ("flown"), those below its roof ("side"), and the
## landing event ("land", empty if none).
func _watch_leap(sim: RampageSim, b: RampageSim.Building) -> Dictionary:
	var out := {"apex": 0.0, "flown": 0, "side": 0, "land": {}}
	for _n: int in roundi(5.0 / DT):
		if not sim.body.dash.on():
			break
		var was := b.frame.alive_count
		var roof_was := _roof_cells(b)
		var events := sim.step(DT, Vector2.ZERO, false, 0)
		out["apex"] = maxf(Num.f(out["apex"]), sim.body.dash.height())
		var land: Dictionary = out["land"]
		if land.is_empty() and sim.body.dash.phase() == "flight":
			var lost := was - b.frame.alive_count
			out["flown"] = Num.i(out["flown"]) + lost
			out["side"] = Num.i(out["side"]) + lost - (roof_was - _roof_cells(b))
		if land.is_empty():
			out["land"] = _first(events, "leap_land")
	return out


## True when a roof the croc can land on (D-361: at its shoulder or lower) is ahead along `dir`
## and no standing building lies within its body's discs: LeapArc skips those at take-off (it
## stands among them) and the flight carves them (D-268), so a leap there is not a clear arc.
func _clear_roof_ahead(sim: RampageSim, dir: Vector2) -> bool:
	if Num.f(sim.body.dash.aim_at(sim.kaiju_pos, dir)["roof"]) <= 0.0:
		return false
	var s := sim.body_scale()
	for d: Array in sim.body.discs():
		var c := sim.kaiju_pos + dir * Num.f(d[0]) * s
		for b: RampageSim.Building in sim.buildings:
			var gap := Vector2(
				maxf(absf(c.x - b.x) - b.w * 0.5, 0.0), maxf(absf(c.y - b.z) - b.d * 0.5, 0.0)
			)
			if b.frame.alive_count > 0 and gap.length() < Num.f(d[1]) * s:
				return false
	return true


## The drawn model's shoulder as a share of its height at the sim's growth stage: the shoulder
## joint (arm_l0's head) in assets/kaiju/reptilian_<stage>.rig.json over the model's height (D-361).
func _rig_shoulder(sim: RampageSim) -> float:
	var models: Array[String] = ["baby", "adolescent", "adult"]
	var model := models[clampi(sim.size_tier() - 1, 0, models.size() - 1)]
	var path := "res://assets/kaiju/reptilian_%s.rig.json" % model
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for bone: Dictionary in rig["bones"]:
		if str(bone["name"]) == "arm_l0":
			return Num.f(bone["head"][1]) / Num.f(rig["height"])
	return 0.0


## How high the drawn shoulder stands above the street, world units (the model is drawn
## kaiju_height x body scale tall).
func _shoulder_y(sim: RampageSim) -> float:
	return _rig_shoulder(sim) * sim.reach_height()


## How far `p` lies outside building `b`'s footprint (0 on or inside it), and whether it is inside.
func _gap(b: RampageSim.Building, p: Vector2) -> float:
	return (
		Vector2(maxf(absf(p.x - b.x) - b.w * 0.5, 0.0), maxf(absf(p.y - b.z) - b.d * 0.5, 0.0))
		. length()
	)


func _inside(b: RampageSim.Building, p: Vector2) -> bool:
	return absf(p.x - b.x) < b.w * 0.5 - 0.001 and absf(p.y - b.z) < b.d * 0.5 - 0.001


## Standing cells in building `b`'s top row (its roof).
func _roof_cells(b: RampageSim.Building) -> int:
	var out := 0
	for x: int in b.w:
		for z: int in b.d:
			out += 1 if b.frame.alive(Vector3i(x, b.height - 1, z)) else 0
	return out


func _stage(sim: RampageSim) -> Dictionary:
	var stages: Array = sim.body.dash.cfg["stages"]["reptilian"]
	return stages[clampi(sim.size_tier() - 1, 0, stages.size() - 1)]
