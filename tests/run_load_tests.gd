extends "res://tests/lib/runner.gd"
## Load suite: a grown city loads fast and its kaiju stays in sight (Apex playability): the
## party-wall pass grows about linearly, the city streams its far buildings in after the
## rampage starts (BuildingStream), and a tower between the camera and the kaiju fades to a
## screen door (BuildingFade, D-025). Headless; the stream check meshes a Behemoth city.
##   godot --headless --path . --script tests/run_load_tests.gd

## Real time to wait for the stream to finish (headless frames are not real seconds).
const STREAM_WAIT_MS := 120000


func suite_name() -> String:
	return "Load"


func run_checks() -> void:
	_check_party_walls()
	_check_building_fade()
	_check_landmark_view()
	await _check_stream()


func _tuning(tier: int) -> Dictionary:
	return CityGrowth.tuning_for(Content.tuning(), tier)


func _layout(tier: int) -> Array[Dictionary]:
	return CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))


func _sim_at(tier: int) -> RampageSim:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	return RampageSim.new(stats, _tuning(tier), _layout(tier), Seeds.make("army", 0))


## Party walls (which sides a neighbour covers) come out the same as comparing every pair,
## while the pairs compared grow about linearly with the building count, not with its square:
## an Apex city loads without 5.9M comparisons.
func _check_party_walls() -> void:
	var young := _sim_at(1).buildings
	var fast := BuildingView.party_walls(young)
	var young_pairs := BuildingView.pair_checks
	var slow: Array[Dictionary] = []
	for a: RampageSim.Building in young:
		var sides := {}
		for other: RampageSim.Building in young:
			if other == a:
				continue
			var gap_x := absf(a.x - other.x) - (a.w + other.w) * 0.5
			var gap_z := absf(a.z - other.z) - (a.d + other.d) * 0.5
			var side := Vector2i.ZERO
			if absf(gap_x) < 0.01 and gap_z < -0.01:
				side = Vector2i(1 if other.x > a.x else -1, 0)
			elif absf(gap_z) < 0.01 and gap_x < -0.01:
				side = Vector2i(0, 1 if other.z > a.z else -1)
			if side != Vector2i.ZERO:
				sides[side] = maxi(Num.i(sides.get(side, 0)), other.height)
		slow.append(sides)
	check(fast == slow, "the party-wall grid finds the same walls as comparing every pair")
	var apex := _sim_at(4).buildings
	BuildingView.party_walls(apex)
	var per_young := Num.f(young_pairs) / young.size()
	var per_apex := Num.f(BuildingView.pair_checks) / apex.size()
	check(
		per_apex < per_young * 2.0 and BuildingView.pair_checks < apex.size() * 20,
		(
			"party-wall pairs grow about linearly: %.1f per building young, %.1f at Apex (%d)"
			% [per_young, per_apex, BuildingView.pair_checks]
		)
	)


## The sight test behind the building screen door (D-025): a tower between the camera and the
## kaiju's body fades; one behind the kaiju, beside the sight line, or one the camera is in,
## does not.
func _check_building_fade() -> void:
	var eye := Vector3(0, 30, 40)
	var sight := BuildingFade.targets(Vector3.ZERO, 20.0, Vector3(0, 0, -3))
	var tower := RampageSim.Building.new()
	tower.w = 6
	tower.d = 6
	tower.height = 30
	tower.x = 0.0
	tower.z = 15.0
	var front := BuildingFade.blocks(eye, sight, tower)
	tower.z = -15.0
	var behind := BuildingFade.blocks(eye, sight, tower)
	tower.z = 15.0
	tower.x = 30.0
	var beside := BuildingFade.blocks(eye, sight, tower)
	check(
		front and not behind and not beside,
		"a tower fades only when it stands between camera and kaiju"
	)


## A landmark draws its baked model (LandmarkVoxels) on the building grid: every voxel inside its
## footprint and in a chunk the sim builds, so each one breaks with its chunk; it meshes to real
## faces and leaves debris samples in its chunks; hiding a chunk switches its voxels off.
func _check_landmark_view() -> void:
	var shape: Dictionary = Content.landmarks().get("stadium", {})
	var b := RampageSim.Building.new()
	b.w = Num.i(shape.get("w", 1))
	b.d = Num.i(shape.get("d", 1))
	b.height = Num.i(shape.get("h", 1))
	b.tier = 1
	b.landmark = "stadium"
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	var layers: Array = shape.get("chunks", [])
	b.frame.keep(layers)
	var t0 := Time.get_ticks_msec()
	var view := BuildingView.new(b, Color.GRAY)
	var build_ms := Time.get_ticks_msec() - t0
	var cells: Dictionary = view.voxels.vox.cells
	var res := BuildingVoxels.RES
	var stray := 0
	for c: Vector3i in cells:
		if not b.frame.alive(Vector3i(c.x / res, c.y / res, c.z / res)):
			stray += 1
	check(
		view.voxels is LandmarkVoxels and cells.size() > 10000 and stray == 0,
		(
			"the stadium's %d voxels all sit in chunks the sim builds (%d stray)"
			% [cells.size(), stray]
		)
	)
	var shell := view.mesher.shell
	var faces := shell.surface_get_array_len(0) / 4 if shell.get_surface_count() > 0 else 0
	check(
		faces > cells.size() / 2 and faces < cells.size() * 4,
		"the stadium meshes to its open faces only: %d faces for %d voxels" % [faces, cells.size()]
	)
	var sampled := view.mesher.samples.size()
	check(
		sampled * 2 > b.frame.alive_count,
		"most of its chunks throw debris when broken: %d of %d" % [sampled, b.frame.alive_count]
	)
	print("landmark view: stadium built in %d ms" % build_ms)
	view.free()


## a building touched before its turn is built on the spot; in the end every building is real.
func _check_stream() -> void:
	var sim := _sim_at(2)
	sim.city["load_chunks"] = 3000
	var colors: Array[Color] = []
	for b: RampageSim.Building in sim.buildings:
		colors.append(Color.GRAY)
	var stream := BuildingStream.new(sim, colors)
	root.add_child(stream)
	var at_load := stream.built_at_load()
	check(
		at_load > 0 and at_load < sim.buildings.size(),
		(
			"a big city meshes only its nearest buildings before the rampage (%d of %d)"
			% [at_load, sim.buildings.size()]
		)
	)
	var far := 0
	for n: int in sim.buildings.size():
		if stream.built(n) == null:
			far = n
	check(
		stream.view(far) != null,
		"a building the rampage touches before its turn is built on the spot"
	)
	var deadline := Time.get_ticks_msec() + STREAM_WAIT_MS
	while not stream.complete() and Time.get_ticks_msec() < deadline:
		await process_frame
	var missing := 0
	for n: int in sim.buildings.size():
		missing += 1 if stream.built(n) == null else 0
	check(stream.complete() and missing == 0, "every building streams in (%d missing)" % missing)
	stream.queue_free()
	await process_frame
