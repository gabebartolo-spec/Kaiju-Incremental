extends RefCounted
## b2-30 (director 2026-10-20: "starting a run freezes the screen for 2-3 seconds"): a run started
## through Main builds its scene over several frames behind a loading screen, nothing steps until
## it is built, and leaving mid-build is safe (queued workers stop, nothing waits on them).
## Seeded by design: the city layout and the army use pinned streams; no check reads the clock.

const FlowHandover := preload("res://tests/lib/flow_handover.gd")
## Frames a staged build may take at most; a hung build fails here instead of hanging the suite.
const LOAD_FRAME_CAP := 6000
## A staged build spans at least this many frames (a one-call build spans none).
const MIN_STAGES := 4


static func run(tree: SceneTree, check: Callable) -> void:
	await _staged_build(tree, check)
	await _leave_mid_build(tree, check)
	await _plain_build(tree, check)
	await FlowHandover.run(tree, check)  # the run's start, then its hand-over (research 19, 20)


static func _rampage(staged: bool) -> Rampage:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.staged = staged
	rampage.setup(species, stats, layout, 0)
	return rampage


static func _staged_build(tree: SceneTree, check: Callable) -> void:
	var rampage := _rampage(true)
	tree.root.add_child(rampage)
	check.call(not rampage.is_loaded, "a staged run is not built when add_child returns")
	check.call(
		not rampage.find_children("*", "LoadingOverlay", false, false).is_empty(),
		"a loading screen is up while it builds"
	)
	var risen := rampage.sim.emerge.risen()
	var overlay: LoadingOverlay = rampage.find_children("*", "LoadingOverlay", false, false)[0]
	var shown := 0
	var frames := 0
	while not rampage.is_loaded and frames < LOAD_FRAME_CAP:
		if is_instance_valid(overlay):
			shown = overlay.done()
		await tree.physics_frame
		frames += 1
	if is_instance_valid(overlay):
		shown = overlay.done()
	check.call(
		shown == LoadingOverlay.STAGES,
		"the loading meter fills before it goes (%d of %d stages)" % [shown, LoadingOverlay.STAGES]
	)
	check.call(rampage.is_loaded, "the staged build finishes (%d frames)" % frames)
	check.call(frames >= MIN_STAGES, "it is built over several frames, not one call: %d" % frames)
	check.call(
		rampage.sim.emerge.risen() == risen, "the sim stood still while it built (%.2f)" % risen
	)
	await tree.process_frame
	check.call(
		rampage.find_children("*", "LoadingOverlay", false, false).is_empty(),
		"the loading screen is gone once it is built"
	)
	check.call(
		(
			rampage.find_children("*", "KaijuModel", true, false).size() == 1
			and rampage.find_children("*", "RampageHud", true, false).size() == 1
		),
		"the finished run has its kaiju and its HUD"
	)
	for _i: int in 30:
		await tree.physics_frame
	check.call(rampage.sim.emerge.risen() > risen, "the sim steps once it is built")
	rampage.queue_free()
	await tree.process_frame


static func _leave_mid_build(tree: SceneTree, check: Callable) -> void:
	var rampage := _rampage(true)
	tree.root.add_child(rampage)
	for _i: int in 3:
		await tree.process_frame
	check.call(not rampage.is_loaded, "three frames in, the run is still building")
	var streams := rampage.find_children("*", "BuildingStream", true, false)
	rampage.queue_free()
	for _i: int in 5:
		await tree.process_frame
	check.call(not is_instance_valid(rampage), "leaving mid-build frees the run without a stall")
	var alive := 0
	for s: Variant in streams:
		alive += 1 if is_instance_valid(s) else 0
	check.call(
		alive == 0, "its building stream went with it (%d of %d left)" % [alive, streams.size()]
	)


static func _plain_build(tree: SceneTree, check: Callable) -> void:
	var rampage := _rampage(false)
	tree.root.add_child(rampage)
	check.call(
		rampage.is_loaded, "an unstaged run (tests, captures) is built when add_child returns"
	)
	rampage.queue_free()
	await tree.process_frame
