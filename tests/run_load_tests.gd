extends "res://tests/lib/runner.gd"
## Load suite: a grown city loads fast (adult-city playability): the party-wall pass grows
## about linearly and the city streams its far buildings in after the rampage starts
## (BuildingStream). Headless; the stream check meshes a Behemoth city.
##   godot --headless --path . --script tests/run_load_tests.gd

const LoadLandmark := preload("res://tests/lib/load_landmark.gd")

## Real time to wait for the stream to finish (headless frames are not real seconds).
const STREAM_WAIT_MS := 120000


func suite_name() -> String:
	return "Load"


func run_checks() -> void:
	await _t("_check_party_walls")
	await _t("_check_bake_kept")
	await _t("_check_bake_pruned")
	await _h("LoadLandmark", func() -> void: LoadLandmark.new(check).run())
	await _t("_check_stream")
	await _t("_check_stream_budget")


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
## the adult city loads without millions of comparisons.
func _check_party_walls() -> void:
	var young := _sim_at(1).buildings
	var fast := BuildingView.party_walls(young)
	var young_pairs := BuildingView.pair_checks
	var slow: Array[Dictionary] = []
	for a: RampageSim.Building in young:
		var sides := {}
		for other: RampageSim.Building in young:
			if other == a or a.is_rail() or other.is_rail():  # a viaduct shares no wall
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
	var adult := _sim_at(3).buildings
	BuildingView.party_walls(adult)
	var per_young := Num.f(young_pairs) / young.size()
	var per_adult := Num.f(BuildingView.pair_checks) / adult.size()
	check(
		per_adult < per_young * 2.0 and BuildingView.pair_checks < adult.size() * 20,
		(
			"party-wall pairs grow about linearly: %.1f per building young, %.1f at adult (%d)"
			% [per_young, per_adult, BuildingView.pair_checks]
		)
	)


## a building touched before its turn is built on the spot; in the end every building is real.
func _check_stream() -> void:
	var sim := _sim_at(2)
	sim.city["load_chunks"] = 3000
	sim.city["stream_chunks"] = 1 << 30  # no memory cap here: every building streams in
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


## A big city keeps only a chunk budget meshed (the biggest stage swapped at 10+ GB when every
## building streamed in): the nearest buildings to the kaiju stay meshed, a building the rampage
## touched is never freed, and as the kaiju walks away the far untouched ones go back to boxes
## while the ones he reaches are meshed.
func _check_stream_budget() -> void:
	var sim := _sim_at(3)
	sim.city["load_chunks"] = 3000
	sim.city["stream_chunks"] = 30000
	var colors: Array[Color] = []
	for b: RampageSim.Building in sim.buildings:
		colors.append(Color.GRAY)
	var stream := BuildingStream.new(sim, colors)
	root.add_child(stream)
	var spot := sim.kaiju_pos
	var near := _nearest_plain(sim, spot)
	var deadline := Time.get_ticks_msec() + STREAM_WAIT_MS
	while not stream.complete() and Time.get_ticks_msec() < deadline:
		await process_frame
	var cap := 30000 + _ring_slack(sim)
	check(
		stream.resident_chunks() <= cap and stream.resident_chunks() > 3000,
		"the stream stops at its chunk budget (%d meshed, budget 30000)" % stream.resident_chunks()
	)
	var missing := 0
	for n: int in sim.buildings.size():
		missing += 1 if stream.built(n) == null else 0
	check(missing > 0, "a city over the budget keeps some buildings as boxes (%d)" % missing)
	var touched := stream.view(near)  # the rampage touches the nearest building
	# The kaiju walks to the far side of the city.
	var far := Vector2.ZERO
	var far_d := 0.0
	for b: RampageSim.Building in sim.buildings:
		if b.landmark == "" and spot.distance_to(Vector2(b.x, b.z)) > far_d:
			far_d = spot.distance_to(Vector2(b.x, b.z))
			far = Vector2(b.x, b.z)
	sim.kaiju_pos = far
	var arrived := _nearest_plain(sim, far)
	var other := _nearest_plain(sim, spot, near)
	var digest := _digest(stream.built(other))
	while (
		(stream.built(arrived) == null or stream.built(other) != null)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	check(stream.built(arrived) != null, "the building the kaiju walks up to is meshed")
	check(stream.built(other) == null, "an untouched building far behind him goes back to a box")
	check(
		stream.built(near) == touched and touched.is_inside_tree(),
		"a building the rampage touched is never freed"
	)
	while not stream.complete() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(
		(
			stream.resident_chunks()
			<= cap + sim.buildings[near].w * sim.buildings[near].d * sim.buildings[near].height
		),
		"walking on keeps the meshed chunks inside the budget (%d)" % stream.resident_chunks()
	)
	# He walks back: the freed building meshes again, identical to before.
	sim.kaiju_pos = spot
	while stream.built(other) == null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(
		stream.built(other) != null and _digest(stream.built(other)) == digest,
		"a building freed and met again meshes identically"
	)
	var wanted := _nearest_plain(sim, far, arrived)
	check(
		stream.view(wanted) != null and stream.built(wanted) != null,
		"a reached building is meshed on the spot"
	)
	stream.queue_free()
	await process_frame


## The nearest ordinary building to `at`, other than `skip`.
func _nearest_plain(sim: RampageSim, at: Vector2, skip: int = -1) -> int:
	var best := -1
	var best_d := INF
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		var d := at.distance_to(Vector2(b.x, b.z))
		if n != skip and b.landmark == "" and d < best_d:
			best = n
			best_d = d
	return best


## Slack for the buildings the plan keeps inside the evict margin and the touched ones.
func _ring_slack(sim: RampageSim) -> int:
	var most := 0
	for b: RampageSim.Building in sim.buildings:
		most = maxi(most, b.w * b.d * b.height)
	return most * 4


## A fingerprint of a view's baked meshes and debris sources.
func _digest(view: BuildingView) -> int:
	if view == null:
		return 0
	return hash([view.mesher.shell.get_faces(), view.mesher.slabs.get_faces(), view.mesher.samples])
