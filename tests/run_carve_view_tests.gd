extends "res://tests/lib/runner.gd"
## Carve view suite (destruction plan stage 1, D-327, D-094 option A): a building the sim carves
## is drawn in play from its own fine grid (CityCarve). A seeded rampage on an empty stage: the
## kaiju stomps a tower until the sim promotes and carves it, then its base is cut and it falls.
## Every frame: the baked shell hides only once the fine view is wholly drawn and up to date; a
## falling piece shows only when its own view is drawn and the cells it carries have left the
## standing view the same frame (no gap, no ghost). Once all is down: the standing view shows
## exactly the sim's grid (CellMesher.drawn of it, every block a fresh mesh of it) and every piece
## held exactly its fall's cells. Off (destruction.carve_view), the baked view draws as before.
## Seeded: one hand-placed tower, Seeds "army" 0, scripted input.
##   godot --headless --path . --script tests/run_carve_view_tests.gd

const DT := 1.0 / 15.0
const TOWER := {"x": 0.0, "z": 0.0, "w": 3, "d": 3, "h": 14, "tier": 1, "style": 0}
const STOMP_AT := Vector2(2.6, 0.0)
const AWAY := Vector2(-12.0, 0.0)
const MAX_FRAMES := 900


func suite_name() -> String:
	return "Carve view"


func run_checks() -> void:
	await _t("_check_rampage_draws_the_grid")
	await _t("_check_off_keeps_the_baked_view")


func _sim() -> RampageSim:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(stats, Content.tuning(), [TOWER.duplicate()], Seeds.make("army", 0))
	sim.ability_type = str(Content.species_def("reptilian")["ability"]["type"])
	return sim


func _city(sim: RampageSim) -> CityView:
	var city := CityView.new(sim, Seeds.make("fx", 0), false)
	root.add_child(city)
	return city


## Hands the sim's events to the city as Rampage does; returns the falls the fine view drew,
## each {"node", "index", "mats"}.
func _feed(city: CityView, events: Array[Dictionary]) -> Array[Dictionary]:
	var sim := city.sim
	var at := Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	var fine: Array[Dictionary] = []
	for e: Dictionary in events:
		match str(e["type"]):
			"cells_promoted", "cells_carved", "fall_start":
				city.on_cells(e)
				if str(e["type"]) == "fall_start":
					_note_fine(city, e, fine)
			"chunks_broken":
				var cells: Array[Vector3i] = e["cells"]
				city.chunks_broken(Num.i(e["building"]), cells, at)
			"fall_land":
				city.fall_land(e)
	return fine


## A fall the fine view draws (its node is CityCarve's, not a lifted chunk piece).
func _note_fine(city: CityView, e: Dictionary, fine: Array[Dictionary]) -> void:
	var f: Dictionary = city._falling[Num.i(e["id"])]
	var node: Node3D = f["node"]
	if node.has_meta("since"):
		fine.append({"node": node, "index": e["index"], "mats": e["mats"]})


## One sim step with the kaiju standing at `at`, fed to the city, then one drawn frame.
func _step(city: CityView, at: Vector2, w: Dictionary) -> void:
	city.sim.kaiju_pos = at
	var pieces: Array = w["pieces"]
	pieces.append_array(_feed(city, city.sim.step(DT, Vector2.ZERO, false)))
	await process_frame
	_watch(city, w)


## This frame's invariants (w: the tallies).
func _watch(city: CityView, w: Dictionary) -> void:
	var site: CityCarve.Site = city.carve._sites.get(0, null)
	if site == null or site.cv == null:
		return
	var view: BuildingView = site.view
	var cv: CellView = site.cv
	if view._shell.visible == view.fine:
		w["shell"] += 1  # the shell and the fine view both shown, or neither
	if view.fine and not (cv.visible and cv.is_drawn):
		w["early"] += 1
	if view.fine and not w["was_fine"] and not cv.settled():
		w["early"] += 1  # switched while a carve was still to draw
	w["was_fine"] = view.fine
	for h: Dictionary in site.held:
		if not is_instance_valid(h["node"]):
			continue
		var node: Node3D = h["node"]
		if node.visible:
			w["ghost"] += 1  # shown while its cells still stand
		elif Num.i(h["upto"]) <= cv.drawn_carves:
			w["gap"] += 1  # its cells are gone and it is not shown
	for p: Dictionary in w["pieces"]:
		_watch_piece(site.mesher, p, w)


## A piece on screen is drawn; the first frame its own view is drawn, it is checked against its
## fall's cells.
func _watch_piece(m: CellMesher, p: Dictionary, w: Dictionary) -> void:
	if not is_instance_valid(p["node"]) or p.has("checked"):
		return
	var node: Node3D = p["node"]
	var own: CellView = null
	for child: Node in node.get_children():
		own = child as CellView if child is CellView else own
	if node.visible and (own == null or not own.is_drawn):
		w["blank"] += 1
	if own == null or not own.is_drawn:
		return
	p["checked"] = true
	var cells := PackedByteArray()
	cells.resize(m.dims.x * m.dims.y * m.dims.z)
	var index: PackedInt32Array = p["index"]
	var mats: PackedByteArray = p["mats"]
	for k: int in index.size():
		cells[index[k]] = mats[k]
	var want := m.drawn(cells)
	var stale := _stale(m, own, want, own.arrays.keys())
	w["checked"] += 1
	w["piece_off"] += int(own._cells != want) + stale
	w["most"] = maxi(Num.i(w["most"]), index.size())


## Blocks of `view` (of these) whose shown mesh is not a fresh mesh of `cells`.
func _stale(m: CellMesher, view: CellView, cells: PackedByteArray, regions: Array) -> int:
	var off := 0
	for r: Vector3i in regions:
		var fresh := m.mesh_region(cells, r)
		var shown: Array = view.arrays.get(r, [])
		if shown.is_empty() or CellMesher.digest(shown) != CellMesher.digest(fresh):
			off += 1
		var verts: PackedVector3Array = fresh[0]
		if view.parts.has(r) != (verts.size() > 0):
			off += 1
	return off


func _tallies() -> Dictionary:
	return {
		"pieces": [],
		"shell": 0,
		"early": 0,
		"was_fine": false,
		"ghost": 0,
		"gap": 0,
		"blank": 0,
		"checked": 0,
		"piece_off": 0,
		"most": 0,
		"frames": 0
	}


## The tower's base on +x, cut through (the carving suite's topple), fed to the city.
func _cut_base(city: CityView, w: Dictionary) -> void:
	var cut: Array[Vector3i] = []
	for x: int in [1, 2]:
		for z: int in 3:
			cut.append(Vector3i(x, 0, z))
	var before := city.sim.events.size()
	city.sim.kaiju_pos = AWAY
	city.sim.damage_chunks(0, cut, 999.0)
	var pieces: Array = w["pieces"]
	pieces.append_array(_feed(city, city.sim.events.slice(before)))


## Whether the fine view has drawn everything the sim did and nothing still falls.
func _all_down(city: CityView) -> bool:
	var site: CityCarve.Site = city.carve._sites.get(0, null)
	return (
		city._falling.is_empty()
		and site != null
		and site.task < 0
		and site.ops.is_empty()
		and site.held.is_empty()
		and site.cv != null
		and site.cv.settled()
	)


func _check_rampage_draws_the_grid() -> void:
	var sim := _sim()
	var city := _city(sim)
	city.carve.keep_arrays = true
	var w := _tallies()
	while not (city._stream.view(0).fine and sim.carving.promoted(0)) and w["frames"] < MAX_FRAMES:
		await _step(city, STOMP_AT, w)
		w["frames"] += 1
	check(
		city._stream.view(0).fine,
		"the stomped tower is drawn from its fine grid (%d frames)" % w["frames"]
	)
	_cut_base(city, w)
	while not _all_down(city) and w["frames"] < MAX_FRAMES * 2:
		await _step(city, AWAY, w)
		w["frames"] += 1
	check(_all_down(city), "the tower came down and the view caught up (%d frames)" % w["frames"])
	check(
		w["shell"] == 0 and w["early"] == 0,
		(
			"the shell hid only once the fine view was drawn and up to date (%d, %d)"
			% [w["shell"], w["early"]]
		)
	)
	check(
		w["ghost"] == 0 and w["gap"] == 0 and w["blank"] == 0,
		(
			"every piece showed the frame its cells left the tower, drawn (%d ghost, %d gap, %d blank)"
			% [w["ghost"], w["gap"], w["blank"]]
		)
	)
	var pieces: Array = w["pieces"]
	check(
		w["checked"] == pieces.size() and w["most"] > 1000 and w["piece_off"] == 0,
		(
			"every falling piece held exactly its fall's cells (%d of %d, largest %d, %d off)"
			% [w["checked"], pieces.size(), w["most"], w["piece_off"]]
		)
	)
	_check_standing(city)
	city.queue_free()
	await process_frame


## The standing view shows exactly the sim's grid now.
func _check_standing(city: CityView) -> void:
	var site: CityCarve.Site = city.carve._sites[0]
	var m: CellMesher = site.mesher
	var cv: CellView = site.cv
	var want := m.drawn(city.sim.carving.frame(0).cells)
	var stale := _stale(m, cv, want, m.all_regions())
	check(
		cv._cells == want and stale == 0 and city.carve.unseen == 0,
		(
			"the standing view is a fresh mesh of the sim's grid (%s, %d blocks off, %d unseen)"
			% [cv._cells == want, stale, city.carve.unseen]
		)
	)


func _check_off_keeps_the_baked_view() -> void:
	var sim := _sim()
	var city := _city(sim)
	check(city.carve.on, "the fine view is on by default (destruction.carve_view)")
	city.carve.on = false
	var w := _tallies()
	for n: int in 60:
		await _step(city, STOMP_AT, w)
	var view := city._stream.view(0)
	check(
		sim.carving.promoted(0) and view.cells_view == null and view._shell.visible,
		"off, the carved tower keeps its baked view (promoted %s)" % sim.carving.promoted(0)
	)
	city.queue_free()
	await process_frame
