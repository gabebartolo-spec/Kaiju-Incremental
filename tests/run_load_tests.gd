extends "res://tests/lib/runner.gd"
## Load suite: a grown city loads fast and its kaiju stays in sight (Apex playability): the
## party-wall pass grows about linearly, the city streams its far buildings in after the
## rampage starts (BuildingStream), and a tower between the camera and the kaiju fades to a
## screen door (BuildingFade, D-025). Headless; the stream check meshes a Behemoth city.
##   godot --headless --path . --script tests/run_load_tests.gd

const LoadLandmark := preload("res://tests/lib/load_landmark.gd")
const FadeSpawn := preload("res://tests/lib/fade_spawn.gd")

## Real time to wait for the stream to finish (headless frames are not real seconds).
const STREAM_WAIT_MS := 120000


func suite_name() -> String:
	return "Load"


func run_checks() -> void:
	await _t("_check_party_walls")
	await _t("_check_building_fade")
	await _t("_check_fade_rise")
	await _h("FadeSpawn", func() -> void: FadeSpawn.new(check).run())
	await _t("_check_bake_kept")
	await _t("_check_bake_pruned")
	await _h("LoadLandmark", func() -> void: LoadLandmark.new(check).run())
	await _t("_check_stream")


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


## The next run of a stage builds the same city (one city seed), so each building's voxels and
## meshes are baked once and kept (director's playtest: run loads too slow): a second sim of the
## stage gets the very same meshes, a different building does not.
func _check_bake_kept() -> void:
	var first := _sim_at(1)
	var again := _sim_at(1)
	var a := BuildingView.new(first.buildings[0], Color.GRAY)
	var b := BuildingView.new(again.buildings[0], Color.GRAY)
	var other := BuildingView.new(again.buildings[1], Color.GRAY)
	check(
		a.mesher == b.mesher and a.mesher.shell == b.mesher.shell and other.mesher != a.mesher,
		"a stage's second run reuses each building's baked meshes, not another building's"
	)
	for view: BuildingView in [a, b, other]:
		view.free()


## The kept meshes are only the current city's: as the city grows between runs (other places,
## other sizes) the old layouts' buildings are dropped, so a 3-5 h game does not hold every
## city it ever had in memory.
func _check_bake_pruned() -> void:
	var counts: Array[int] = []
	for tier: int in [1, 2]:
		var sim := _sim_at(tier)
		var party := BuildingView.party_walls(sim.buildings)
		BuildingView.begin_city()
		for n: int in sim.buildings.size():
			BuildingView.new(sim.buildings[n], Color.GRAY, party[n]).free()
		BuildingView.end_city()
		counts.append(sim.buildings.size())
	check(
		BuildingView.cached() == counts[1],
		(
			"after two different cities only the second's buildings are kept: %d kept, %s built"
			% [BuildingView.cached(), counts]
		)
	)


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


## The sight test behind the building screen door (D-025, R 19.4): a tower between the camera
## and the kaiju's body or feet fades, and so does one the camera is in; one behind the kaiju,
## beside the sight line, or carved down to a stump below every sight line does not.
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
	tower.x = 0.0
	tower.z = 40.0
	tower.frame = Structure.new(tower.w, tower.d, tower.height, 1.0)
	var around := BuildingFade.blocks(Vector3(0, 20, 40), sight, tower)
	tower.z = 15.0
	for y: int in range(1, tower.height):
		for z: int in tower.d:
			for x: int in tower.w:
				tower.frame.remove(Vector3i(x, y, z))
	var stump := BuildingFade.blocks(eye, sight, tower)
	check(around and not stump, "a tower round the camera fades; a carved stump never does")


## The rise from the river (comment #27): the sight points spread over the part of the body above
## the water, so a low block in front of the surfacing kaiju fades; and a building already in the
## way on the run's first frame starts faded instead of easing in over the kaiju.
func _check_fade_rise() -> void:
	var eye := Vector3(0, 8, 40)
	var feet := Vector3(0, -20, 0)  # sunk: only the top of a 22-tall body is above the water
	var low := RampageSim.Building.new()
	low.w = 6
	low.d = 2
	low.height = 2
	low.z = 15.0
	var dry := BuildingFade.blocks(eye, BuildingFade.targets(feet, 22.0, Vector3.ZERO), low)
	var wet := BuildingFade.targets(feet, 22.0, Vector3.ZERO, -1.6)
	var above := true
	for p: Vector3 in wet:
		above = above and p.y >= -1.6
	check(
		above and not dry and BuildingFade.blocks(eye, wet, low),
		"under water the sight points cover the body above the surface, so a low block in front fades"
	)
	var buildings: Array[RampageSim.Building] = [low]
	var fade := BuildingFade.new(buildings, func(_n: int) -> BuildingView: return null)
	fade.update(eye, wet, 1.0 / 60.0)
	var first := fade.opacity(0)
	fade.update(eye, wet, 1.0 / 60.0)
	var later := BuildingFade.new(buildings, func(_n: int) -> BuildingView: return null)
	later.update(eye, PackedVector3Array([eye + Vector3(1, 0, 0)]), 1.0 / 60.0)
	later.update(eye, wet, 1.0 / 60.0)
	var floor_opacity := Num.f(Content.section("vehicles")["fade_opacity"])
	check(
		is_equal_approx(first, floor_opacity) and later.opacity(0) > floor_opacity,
		(
			(
				"a building in the way on the first frame starts faded (%.2f); one that comes in later"
				+ " eases (%.2f)"
			)
			% [first, later.opacity(0)]
		)
	)


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
	var queue := stream.queued()
	var first_plain := queue.size()
	var last_mark := -1
	for k: int in queue.size():
		if sim.buildings[queue[k]].landmark != "":
			last_mark = k
		elif first_plain == queue.size():
			first_plain = k
	var marks := 0  # every landmark: built at load, or queued ahead of every ordinary building
	for n: int in sim.buildings.size():
		marks += 1 if sim.buildings[n].landmark != "" else 0
	check(
		marks > 0 and last_mark < first_plain,
		(
			(
				"landmarks stream before any ordinary building, never long as a box (%d landmarks,"
				+ " last queued %d, first other %d)"
			)
			% [marks, last_mark, first_plain]
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
