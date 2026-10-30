extends RefCounted
## The trains suite's falls onto and off the viaduct (bar 3, and a toppled tower): `scene` builds
## the suite's sim with the kaiju clear of the line (split out of run_trains_tests.gd to keep
## files small).

const Base := preload("res://tests/lib/powers_base.gd")
const RailProbe := preload("res://tests/lib/rail_probe.gd")


## Bar 3: a span cut through at both ends falls as an island and breaks when it lands (its
## chunks pay as rubble); the track over it is broken.
static func cut_span_falls(check: Callable, scene: Callable) -> void:
	var sim: RampageSim = scene.call()
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
	for _i: int in roundi(3.0 / Base.DT):
		for event: Dictionary in sim.step(Base.DT, Vector2.ZERO, false, 0):
			if str(event["type"]) == "fall_land" and Num.i(event["building"]) == n:
				landed = landed or event["scrap"] == false
	check.call(dropped >= 1, "railway.carve: the cut span falls as an island: %d" % dropped)
	check.call(
		landed and sim.rubble > paid,
		"railway.carve: it breaks when it lands: %.2f > %.2f" % [sim.rubble, paid]
	)
	check.call(paid > rubble, "railway.carve: the cut pays: %.2f > %.2f" % [paid, rubble])
	check.call(not rail.broken().is_empty(), "railway.carve: the cut breaks the track")


## A tower toppling onto the viaduct carves the deck where it lands, as it does any building.
static func falling_building_damages_track(check: Callable, scene: Callable) -> void:
	var sim: RampageSim = scene.call()
	var rail := sim.rail
	var mid := rail.point(rail.length * 0.75, 1).y
	var n := RailProbe.piece_at(sim, mid)
	var x := rail.centre_x()
	sim.collapse._crush_strip(Vector2(x - 8.0, mid), Vector2(x + 8.0, mid), 1.5, -1)
	sim.step(Base.DT, Vector2.ZERO, false, 0)
	var g: Carving.Grid = sim.carving.grids.get(n, null)
	check.call(
		g != null and sim.carving.cells_carved > 0, "railway.carve: a toppled tower carves the deck"
	)
	check.call(not rail.broken().is_empty(), "railway.carve: the track under its strip is broken")
