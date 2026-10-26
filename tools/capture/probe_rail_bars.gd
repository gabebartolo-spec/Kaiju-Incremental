extends SceneTree
## The railway carve's pass bars (brief rail-carve, 2026-10-26), measured in the seeded sim on any
## revision (the bay model before, the voxel pieces after), so the same numbers fail first and
## pass after. Prints one RAIL_BAR line per bar.
##   godot --headless --path . --script tools/capture/probe_rail_bars.gd
## Bars: 1 the viaduct loses what a building loses at the same body contact (share of touched
## chunks' cells taken, cells taken outside them); 2 no piece loses > 25% in one step without a
## fall; 3 a 6-unit span cut at both ends falls and pays on landing; 4 nothing of the line is
## left inside the walking body.

const DT := 1.0 / 30.0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	await process_frame
	var line := _sim([]).rail
	var z := line.point(line.length * 0.75, 1).y
	var pieces := line.get("pieces") != null
	print("RAIL_BAR model=%s" % ("pieces" if pieces else "bays"))
	_bar1(z, pieces)
	_bar24(z, pieces)
	_bar3(z, pieces)
	quit(0)


## The line's piece indices (empty on the bay model).
func _pieces(sim: RampageSim) -> Array:
	var got: Variant = sim.rail.get("pieces")
	return got if got != null else []


func _sim(extra: Array[Dictionary]) -> RampageSim:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	)
	var all: Array[Dictionary] = extra.duplicate()
	all.append({"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0})
	var sim := RampageSim.new(stats, Content.tuning(), all, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.stats["stomp_damage"] = 0.0
	return sim


## Rail geometry the line still has: cells of its pieces, or (the bay model) bays standing.
func _rail_left(sim: RampageSim, pieces: bool) -> int:
	var n := 0
	if pieces:
		for i: int in _pieces(sim):
			var f := sim.carving.frame(i)
			n += f.alive_count if f != null else sim.buildings[i].frame.alive_count
		return n
	var hps: Array = sim.rail.get("bay_hp")
	for hp: float in hps:
		n += int(hp > 0.0)
	return n


## Bar 1: the body on the deck one step, against a plain building of the piece's size.
func _bar1(z: float, pieces: bool) -> void:
	var sim := _sim([])
	sim.kaiju_pos = Vector2(sim.rail.centre_x(), z)
	var bays_before := _rail_left(sim, false) if not pieces else 0
	var events: Array[Dictionary] = []
	for _i: int in roundi(0.7 / DT):
		events.append_array(sim.step(DT, Vector2.ZERO, false, 0))
	var carved := 0
	for e: Dictionary in events:
		var rail := pieces and _pieces(sim).has(Num.i(e.get("building", -1)))
		if rail and str(e["type"]) == "cells_carved":
			var index: PackedInt32Array = e["index"]
			carved += index.size()
	if not pieces:
		var gone := bays_before - _rail_left(sim, false)
		print(
			(
				"RAIL_BAR 1 FAIL: rail cells carved %d; whole bays hidden %d (each %.0f units of deck)"
				% [carved, gone, Num.f(sim.rail.cfg["bay_length"])]
			)
		)
		return
	var probe := _sim([])
	var n := -1
	for i: int in _pieces(probe):
		if absf(z - probe.buildings[i].z) < probe.buildings[i].d * 0.5:
			n = i
	var p := probe.buildings[n]
	var twin := {
		"x": p.x - 30.0, "z": p.z, "w": p.w, "d": p.d, "h": p.height, "tier": 1, "style": 0
	}
	var got: Array = []
	for target: int in [0, 1]:
		var s := _sim([twin])
		var m: int = _pieces(s)[_pieces(probe).find(n)] if target == 0 else 0
		var b := s.buildings[m]
		s.kaiju_pos = Vector2(b.x, b.z)
		s.carving._promote(m)
		var touched: Dictionary = s.body.inside(s.kaiju_pos, s.body.heading).get(m, {})
		var took := {}
		for e: Dictionary in s.step(DT, Vector2.ZERO, false, 0):
			if str(e["type"]) == "cells_carved" and Num.i(e["building"]) == m:
				var index: PackedInt32Array = e["index"]
				for i: int in index:
					took[i] = true
		var g: Carving.Grid = s.carving.grids[m]
		var full := 0
		var inside := 0
		for ci: int in g.full.size():
			if touched.has(Carving._chunk_cell(g, ci)):
				full += g.full[ci]
		for i: int in took:
			inside += int(touched.has(Carving._chunk_cell(g, g.chunk(i))))
		got.append(
			[touched.size(), took.size(), float(inside) / maxf(1.0, full), took.size() - inside]
		)
	var same: bool = absf(Num.f(got[0][2]) - Num.f(got[1][2])) < 0.01 and got[0][3] == got[1][3]
	print(
		(
			"RAIL_BAR 1 %s: [chunks touched, cells taken, share taken, taken outside] rail %s, building %s"
			% ["PASS" if same else "FAIL", got[0], got[1]]
		)
	)


## Bars 2 and 4: walk west to east across the line at z.
func _bar24(z: float, pieces: bool) -> void:
	var sim := _sim([])
	var x := sim.rail.centre_x()
	sim.kaiju_pos = Vector2(x - 12.0, z)
	sim.facing = Vector2(1, 0)
	sim.body.heading = Vector2(1, 0)
	var worst := 0.0
	var through := 0
	var steps := 0
	var half := Num.f(sim.rail.cfg["deck_width"]) * 0.5
	while sim.kaiju_pos.x < x + 12.0 and steps < 1200:
		steps += 1
		var before := _rail_left(sim, pieces)
		var events := sim.step(DT, Vector2(1, 0), false, 0)
		var fell := false
		for e: Dictionary in events:
			fell = fell or str(e["type"]) == "fall_start"
		var lost := before - _rail_left(sim, pieces)
		var whole := 18816.0 if pieces else 1.0  # a plain piece's cells, or one bay
		if not fell:
			worst = maxf(worst, lost / whole)
		if pieces:
			for b: int in sim.body.inside(sim.kaiju_pos, sim.body.heading):
				through += int(_pieces(sim).has(b))
		else:
			var bay: int = sim.rail.call("bay_at", z - sim.rail.point(0.0, 1).y)
			var near := absf(sim.kaiju_pos.x - x) < half + 1.0
			var standing: bool = sim.rail.call("bay_standing", bay)
			through += int(near and standing)
	print(
		(
			"RAIL_BAR 2 %s: most lost in one step without a fall %.0f%% (bar 25%%)"
			% ["PASS" if worst <= 0.25 else "FAIL", worst * 100.0]
		)
	)
	print(
		(
			"RAIL_BAR 4 %s: steps with the line standing inside the body %d of %d"
			% ["PASS" if through == 0 else "FAIL", through, steps]
		)
	)


## Bar 3: cut a span at both ends.
func _bar3(z: float, pieces: bool) -> void:
	var sim := _sim([])
	if not pieces:
		print(
			"RAIL_BAR 3 FAIL: no span can be cut: a bay has one hit-point pool, no islands, no falls"
		)
		return
	var n := -1
	for i: int in _pieces(sim):
		if absf(z - sim.buildings[i].z) < sim.buildings[i].d * 0.5:
			n = i
	var b := sim.buildings[n]
	var cut: Array[Vector3i] = []
	for cz: int in [1, roundi(Num.f(sim.rail.cfg["bay_length"])) - 1]:
		for x: int in b.w:
			for y: int in range(1, b.height):
				cut.append(Vector3i(x, y, cz))
	var amounts := PackedFloat32Array()
	amounts.resize(cut.size())
	amounts.fill(INF)
	sim.damage_cells(n, cut, amounts)
	var dropped := 0
	for f: RampageSim.Fall in sim.falls:
		dropped += int(f.building == n and f.kind == "drop" and not f.cells.is_empty())
	var paid := sim.rubble
	var landed := 0
	for _i: int in roundi(3.0 / DT):
		for e: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			if str(e["type"]) == "fall_land" and Num.i(e["building"]) == n and e["scrap"] == false:
				landed += 1
	var ok := dropped > 0 and landed > 0 and sim.rubble > paid
	print(
		(
			"RAIL_BAR 3 %s: islands %d, landed %d, rubble on landing %.2f"
			% ["PASS" if ok else "FAIL", dropped, landed, sim.rubble - paid]
		)
	)
