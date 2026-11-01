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


## Every building's place, size, kind and chunk count, and the city's chunk total.
static func _digest(sim: RampageSim) -> int:
	var parts: Array = [sim.chunks_total]
	for b: RampageSim.Building in sim.buildings:
		parts.append(
			[b.x, b.z, b.w, b.d, b.height, b.tier, b.style, b.landmark, b.model, b.start_chunks]
		)
	return hash(var_to_bytes(parts))
