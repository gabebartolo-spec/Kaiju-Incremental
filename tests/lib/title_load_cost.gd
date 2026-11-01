class_name TitleLoadCost
extends RefCounted
## The title's load-cost fixtures (the UI suite, tests/lib/ui_title.gd).


## The title builds its plan and sim on a worker (TitleBackdrop._make_sim) so the menu keeps
## drawing: that sim is the one the main thread builds, building for building. Off (the same call
## on the main thread) gives the same digest; a different seed does not, so the check can fail.
static func run(check: Callable) -> void:
	var cfg := Content.section("title")
	var tier := Num.i(cfg["city_tier"])
	var tuning := CityGrowth.tuning_for(Content.tuning(), tier)
	var on := TitleBackdrop.new()
	var task := WorkerThreadPool.add_task(on.call.bind("_make_sim", tuning, tier))
	WorkerThreadPool.wait_for_task_completion(task)
	var off := TitleBackdrop.new()
	off.call("_make_sim", tuning, tier)
	var worker: RampageSim = on.get("_sim")
	var main: RampageSim = off.get("_sim")
	var other := RampageSim.new(
		{},
		tuning,
		CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 1)),
		Seeds.make("army", 0)
	)
	check.call(
		worker.buildings.size() > 0 and _digest(worker) == _digest(main),
		(
			"the title's sim built on a worker equals the main thread's (%d buildings)"
			% worker.buildings.size()
		)
	)
	check.call(_digest(other) != _digest(main), "another seed's city differs (the digest can fail)")
	for sim: RampageSim in [worker, main, other]:
		sim.dispose()
	on.free()
	off.free()


## The city builds its outskirts each in a frame of its own (CityView._ready, perf 2026-11): staged
## (on), the frame that lays the ground has no skyline yet and the next no boats, so no one frame
## builds all three; unstaged (off, as tests and captures build it) all three come in one call.
static func split(check: Callable, tree: SceneTree) -> void:
	var seen := {}
	for on: bool in [true, false]:
		var tuning := Content.tuning()
		var layout := CityGrowth.layout(tuning, 1, Seeds.make("city", 0))
		var tier := CityGrowth.tuning_for(tuning, 1)
		var sim := RampageSim.new({}, tier, layout, Seeds.make("army", 0))
		var city := CityView.new(sim, Seeds.make("fx", 0))
		city.stages.on = on
		tree.root.add_child(city)
		var frames: Array[String] = [_parts(city)]
		if on:
			for _n: int in 2:
				await tree.process_frame
				frames.append(_parts(city))
			tree.root.remove_child(city)  # its build sees it left on its next frame and stops
			await tree.process_frame
		seen[on] = frames
		city.free()
		sim.dispose()
	var want: Array[String] = ["ground", "ground skyline", "ground skyline boats"]
	check.call(
		seen[true] == want,
		"staged, ground, skyline and boats come a frame apart: %s" % [seen[true]]
	)
	check.call(
		seen[false] == ["ground skyline boats"],
		"unstaged, all three in one call: %s" % [seen[false]]
	)


## Which of the ground, the far skyline and the boats the city has built so far.
static func _parts(city: CityView) -> String:
	var parts: Array[String] = []
	if city.get_children().any(func(n: Node) -> bool: return n is CityGround):
		parts.append("ground")
	if city.get_children().any(func(n: Node) -> bool: return n is CitySkyline):
		parts.append("skyline")
	if city.boats != null:
		parts.append("boats")
	return " ".join(parts)


## Every building's place, size, kind and chunk count, and the city's chunk total.
static func _digest(sim: RampageSim) -> int:
	var parts: Array = [sim.chunks_total]
	for b: RampageSim.Building in sim.buildings:
		parts.append(
			[b.x, b.z, b.w, b.d, b.height, b.tier, b.style, b.landmark, b.model, b.start_chunks]
		)
	return hash(var_to_bytes(parts))
