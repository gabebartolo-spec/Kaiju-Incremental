extends "res://tests/lib/leap_base.gd"
## The tank flight suite's building checks (TankHold; director 2026-11-01: "when a tank hits a
## building it needs to carve it, it would be really cool if a tank could even wedge into and get
## stuck in the bigger buildings or if they land ontop of a building they could crush it").
## Player-effect fixtures "tank.bore" (a slow and a fast throw into a thick block: both bore a hull
## hole and stick, the fast one deeper), "tank.wedge" (the same throw at a thin and a thick block:
## out the far side vs wedged), "tank.roof" (dropped on a roof from low and high vs on the street:
## floors caved in, more the higher) and "tank.husk" (a wreck on a roof with its building standing
## vs broken under it). Seeded as run_tank_flight_tests.

## The block's west face, east of the origin; a thin and a thick block's width; its floors.
const FACE_AT := 6.0
const THIN := 2
const THICK := 16
const FLOORS := 8
## A slow and a fast throw (metres it would carry on open ground).
const SLOW := 8.0
const FAST := 30.0
## Drops onto the roof: metres above it.
const LOW_DROP := 0.3
const HIGH_DROP := 12.0
## Seconds watched for a throw or drop to settle.
const SETTLE_S := 4.0
## The roof block's centre, east of the origin.
const THROW_LAND := 20.0


## Fixture "tank.bore": both throws bore at least a hull-sized hole (bore_half to each side,
## wall_floors high) and stick inside the block; the fast one sticks deeper.
func _check_bore() -> void:
	var slow := _throw_into(THICK, SLOW)
	var fast := _throw_into(THICK, FAST)
	var sim := _croc({}, [])
	var hold: Dictionary = sim.flight.cfg["hold"]
	var hull := (
		floori(Num.f(hold["bore_half"]) * 2.0)
		* Num.i(sim.flight.cfg["wall_floors"])
		* floori(Num.f(hold["bore_min"]))
	)
	for run: Dictionary in [slow, fast]:
		check(
			Num.i(run["carved"]) >= hull and Num.i(run["wedged"]) == 1,
			(
				"a throw bores a hull-sized hole (%d chunks, hull %d) and sticks: %s"
				% [run["carved"], hull, run]
			)
		)
		check(Num.f(run["x"]) > FACE_AT, "it sticks inside the block: %s" % [run])
	check(
		Num.f(fast["x"]) > Num.f(slow["x"]) + 1.0 and Num.i(fast["carved"]) > Num.i(slow["carved"]),
		(
			"the fast throw bores deeper: x %.2f vs %.2f, %d vs %d chunks"
			% [fast["x"], slow["x"], fast["carved"], slow["carved"]]
		)
	)


## Fixture "tank.wedge": the same throw goes out the far side of a thin block and flies on; a
## thick one holds it, wedged, kept as a husk.
func _check_wedge() -> void:
	var thin := _throw_into(THIN, SLOW)
	var thick := _throw_into(THICK, SLOW)
	var husk: bool = thick["husk"]
	check(
		Num.i(thin["through"]) == 1 and Num.f(thin["x"]) > FACE_AT + THIN,
		"through a thin block and out the far side: %s" % [thin]
	)
	check(
		Num.i(thick["wedged"]) == 1 and Num.i(thick["through"]) == 0 and husk,
		"stuck in a thick block, kept as a husk: %s" % [thick]
	)


## Fixture "tank.roof": dropped on a roof the tank caves floors in and ends inside, more of them
## the higher it fell; dropped on the street it caves nothing.
func _check_roof() -> void:
	var street := _drop(false, HIGH_DROP)
	var low := _drop(true, LOW_DROP)
	var high := _drop(true, HIGH_DROP)
	check(
		Num.i(street["punched"]) == 0 and Num.f(street["height"]) == 0.0,
		"on the street it caves nothing in: %s" % [street]
	)
	check(
		Num.i(low["punched"]) == 1 and Num.f(low["height"]) < FLOORS,
		"a low drop caves the roof in and ends inside: %s" % [low]
	)
	check(
		Num.f(high["height"]) < Num.f(low["height"]),
		"a high drop caves more floors in: height %.1f vs %.1f" % [high["height"], low["height"]]
	)


## Fixture "tank.husk": the wreck stays where the roof gave way while the building stands; with the
## floors under it broken it falls to the street and is cleared (tank_husk_down).
func _check_husk() -> void:
	for broken: bool in [false, true]:
		var sim := _croc({}, [_block(Vector2(THROW_LAND, 0.0), THICK, FLOORS)])
		var tank := _tank(sim, 901, Vector2(THROW_LAND, 0.0))
		_fall(tank, FLOORS + LOW_DROP)
		_watch(sim, SETTLE_S)
		var rested := tank.height
		if broken:
			var b := sim.buildings[0]
			var cells: Array[Vector3i] = []
			for y: int in b.height:
				for x: int in b.w:
					for z: int in b.d:
						if b.frame.alive(Vector3i(x, y, z)):
							cells.append(Vector3i(x, y, z))
			var amounts := PackedFloat32Array()
			amounts.resize(cells.size())
			amounts.fill(1.0e9)
			sim.damage_cells(0, cells, amounts)
		var down := false
		for _n: int in roundi(SETTLE_S / DT):
			for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
				down = down or str(event["type"]) == "tank_husk_down"
		var kept := sim.flight.hold.husks.has(tank)
		if broken:
			check(down and not kept, "its floors broken, the husk falls and is cleared")
		else:
			check(
				kept and not down and tank.height == rested and rested > 0.0,
				"the husk stays on its floor (%.1f) while the building stands" % rested
			)


## Throws a tank from the origin east, `distance` on open ground, at a block `width` wide.
func _throw_into(width: int, distance: float) -> Dictionary:
	var sim := _croc({}, [_block(Vector2(FACE_AT + width * 0.5, 0.0), width, FLOORS)])
	var tank := _tank(sim, 901, Vector2.ZERO)
	var before := sim.chunks_destroyed
	sim.flight.launch(tank, Vector2(1.0, 0.0), distance)
	var husk := false
	for _n: int in roundi(SETTLE_S / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			if str(event["type"]) == "tank_destroyed" and Num.i(event["tank"]) == 901:
				husk = event.get("husk", false) == true
	var hold := sim.flight.hold
	return {
		"x": tank.pos.x,
		"carved": sim.chunks_destroyed - before,
		"wedged": hold.wedged,
		"through": hold.through,
		"husk": husk,
	}


## Drops a tank from `above` metres over the roof of a block (or over the street).
func _drop(roofed: bool, above: float) -> Dictionary:
	var layout: Array[Dictionary] = []
	if roofed:
		layout.append(_block(Vector2(THROW_LAND, 0.0), THICK, FLOORS))
	var sim := _croc({}, layout)
	var tank := _tank(sim, 901, Vector2(THROW_LAND, 0.0))
	_fall(tank, (float(FLOORS) if roofed else 0.0) + above)
	_watch(sim, SETTLE_S)
	return {"punched": sim.flight.hold.punched, "height": tank.height}


## Sets `tank` falling from `height`.
func _fall(tank: RampageSim.Tank, height: float) -> void:
	tank.height = height
	tank.vel = Vector3.ZERO
	tank.flying = true


func _watch(sim: RampageSim, seconds: float) -> void:
	for _n: int in roundi(seconds / DT):
		sim.step(DT, Vector2.ZERO, false, 0)
