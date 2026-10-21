extends RefCounted
## Research 19 and 20, the hand-overs: a press made just before control returns is not lost
## (the rise from the river holds the sim back; InputLatch keeps the tap for its first live tick),
## the evolution reveal lasts the same on any display (fixed ticks, not drawn frames), and the
## camera's zoom curve is data and keeps the kaiju at or under a third of the screen's height at
## every stage. Seeded and clock-free: every press lands on a counted physics tick.

## Stages (size tiers) the camera check walks.
const STAGES := 4
## The most of the screen's height the kaiju may fill at any stage (research 19: threats around
## it stay in frame).
const SHARE_MAX := 0.35
## A dash pressed this many ticks before the handover (0.1 s at 60 ticks a second).
const EARLY_TICKS := 6
## A dash this many ticks before it (0.5 s) is stale: the latch forgets it.
const STALE_TICKS := 30
const FRAME_CAP := 60 * 20
const TICKS_PER_SECOND := 60.0


static func run(tree: SceneTree, check: Callable) -> void:
	await _latched_dash(tree, check)
	await _reveal_length(tree, check)
	_camera_share(check)


static func _rampage() -> Rampage:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	return rampage


## One run's scripted ticks: presses a dash on tick `press_at` and notes the dashes the sim counted
## before ticks `watch_a` and `watch_b` (a is read before tick watch_a's step, so it shows what
## ticks up to the one before it did). Returns {"a": dashes at watch_a, "b": dashes at watch_b}.
static func _play(tree: SceneTree, press_at: int, watch_a: int, watch_b: int) -> Dictionary:
	var rampage := _rampage()
	var seen := {"n": 0, "last_held": 0, "a": -1, "b": -1}
	rampage.scripted = func(sim: RampageSim) -> Dictionary:
		seen["n"] = Num.i(seen["n"]) + 1
		var n := Num.i(seen["n"])
		if sim.emerge.active:
			seen["last_held"] = n
		if n == watch_a:
			seen["a"] = sim.body.dash.dashes
		if n == watch_b:
			seen["b"] = sim.body.dash.dashes
		return {"dash": n == press_at}
	tree.root.add_child(rampage)
	var frames := 0
	while Num.i(seen["n"]) < watch_b and frames < FRAME_CAP:
		await tree.physics_frame
		frames += 1
	rampage.queue_free()
	await tree.process_frame
	return seen


## A dash pressed 0.1 s before the kaiju is on its feet fires on the first live tick; one pressed
## 0.5 s before is forgotten.
static func _latched_dash(tree: SceneTree, check: Callable) -> void:
	# A run that presses nothing: which tick hands over? (The same seeded rise every time.)
	var probe := await _play_to_handover(tree)
	var handover := Num.i(probe["last_held"])
	check.call(
		handover > STALE_TICKS + 2,
		"the rise lasts %d ticks, longer than the stale press" % handover
	)
	var early := await _play(tree, handover - EARLY_TICKS, handover + 1, handover + 2)
	check.call(
		Num.i(early["a"]) == 0 and Num.i(early["b"]) == 1,
		(
			"a dash %d ticks before the handover fires on the first live tick (%s then %s dashes)"
			% [EARLY_TICKS, early["a"], early["b"]]
		)
	)
	var stale := await _play(tree, handover - STALE_TICKS, handover + 1, handover + 2)
	check.call(
		Num.i(stale["b"]) == 0,
		"a dash pressed %d ticks before it is forgotten (dashes %s)" % [STALE_TICKS, stale["b"]]
	)


## A run with no presses, played until the sim is on its feet (so its handover tick is known).
static func _play_to_handover(tree: SceneTree) -> Dictionary:
	var rampage := _rampage()
	var seen := {"n": 0, "last_held": 0}
	rampage.scripted = func(sim: RampageSim) -> Dictionary:
		seen["n"] = Num.i(seen["n"]) + 1
		if sim.emerge.active:
			seen["last_held"] = Num.i(seen["n"])
		return {}
	tree.root.add_child(rampage)
	var frames := 0
	while rampage.sim.emerge.active and frames < FRAME_CAP:
		await tree.physics_frame
		frames += 1
	rampage.queue_free()
	await tree.process_frame
	return seen


## The reveal as a 60 Hz and a 144 Hz display would drive it: each drawn frame calls _process, each
## 1/60 s of the same clock calls _physics_process (a node that has no such method is skipped).
## Returns the seconds until it reports done.
static func _reveal_seconds(tree: SceneTree, fps: float) -> float:
	var species := Content.species_def("reptilian")
	var city: Dictionary = CityGrowth.for_stats({"size": 2})["city"]
	var reveal := EvolutionReveal.new()
	reveal.setup(species, {"size": 1}, {"size": 2}, city)
	reveal.process_mode = Node.PROCESS_MODE_DISABLED  # the engine does not also drive it
	tree.root.add_child(reveal)
	var finished := [false]
	reveal.done.connect(func() -> void: finished[0] = true)
	var t := 0.0
	var ticks := 0
	var dt := 1.0 / fps
	while not finished[0] and t < 30.0:
		t += dt
		_call_if_defined(reveal, "_process", dt)
		while float(ticks) < floorf(t * TICKS_PER_SECOND + 1.0e-6):
			ticks += 1
			_call_if_defined(reveal, "_physics_process", 1.0 / TICKS_PER_SECOND)
	if is_instance_valid(reveal):
		reveal.free()
	return t


static func _call_if_defined(node: Node, method: String, dt: float) -> void:
	var script: Script = node.get_script()
	for m: Dictionary in script.get_script_method_list():
		if m["name"] == method:
			node.call(method, dt)
			return


static func _reveal_length(tree: SceneTree, check: Callable) -> void:
	var at60 := _reveal_seconds(tree, 60.0)
	var at144 := _reveal_seconds(tree, 144.0)
	var want := float(EvolutionReveal.END_FRAME) / TICKS_PER_SECOND
	check.call(
		absf(at60 - want) < 0.05 and absf(at144 - want) < 0.05,
		(
			"the reveal lasts %.2f s at 60 fps and %.2f s at 144 fps (wanted %.2f s)"
			% [at60, at144, want]
		)
	)


## The kaiju's share of the screen's height at each stage (a pinhole estimate from the rest offset,
## the zoom curve and the vertical FOV): it grows with every stage and stays within SHARE_MAX.
static func _camera_share(check: Callable) -> void:
	var fov := deg_to_rad(Num.f(Content.section("camera")["fov"]))
	var shares: Array[float] = []
	for tier: int in range(1, STAGES + 1):
		var city: Dictionary = CityGrowth.tuning_for(Content.tuning(), tier)["city"]
		var scale := Growth.body_scale({"size": tier}, city)
		var height := Num.f(city["kaiju_height"]) * scale
		var offset := CameraTuning.offset() * CameraTuning.zoom(scale)
		var pitch := atan2(offset.y, offset.z)
		shares.append(height * cos(pitch) / (2.0 * offset.length() * tan(fov * 0.5)))
	var rising := true
	for i: int in range(1, shares.size()):
		rising = rising and shares[i] > shares[i - 1]
	check.call(rising, "the kaiju fills more of the screen at every stage: %s" % [shares])
	check.call(
		shares.back() <= SHARE_MAX,
		(
			"the adult fills %.0f%% of the screen's height at most (%.0f%%)"
			% [SHARE_MAX * 100.0, shares.back() * 100.0]
		)
	)
