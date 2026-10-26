extends SceneTree
## What the stadium's first hit costs the sim (WP6 follow-up: "stadium first hit 246 ms hitch"):
## times the first hit_area that reaches it and the second, then the fine-grid promotion
## (CellPromoter.on_hit / LandmarkCells) on a fresh sim, cold (the model read) and warm.
##
##   godot --headless --path . --script tools/capture/probe_landmark_hit.gd


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	var index := -1
	for n: int in sim.buildings.size():
		if sim.buildings[n].landmark == "stadium":
			index = n
	var b := sim.buildings[index]
	print("stadium %d: %d x %d x %d chunks" % [index, b.w, b.height, b.d])
	sim.kaiju_pos = Vector2(b.x, b.z + b.d * 0.5 + 1.0)
	var centre := sim.kaiju_pos
	var force := func(p: Vector2, r: float) -> float:
		return clampf(1.0 - (p.distance_to(centre) - r) / 12.0, 0.0, 1.0)
	for k: int in 6:
		var t := Time.get_ticks_usec()
		sim.hit_area(force, 3.0)
		print(
			(
				"hit %d: %.1f ms, promoted %s (%d grids), %d of %d left"
				% [
					k,
					(Time.get_ticks_usec() - t) / 1000.0,
					sim.carving.promoted(index),
					sim.carving.grids.size(),
					b.frame.alive_count,
					b.w * b.height * b.d
				]
			)
		)
	var promoter := CellPromoter.new()
	for k: int in 2:
		var t := Time.get_ticks_usec()
		var fresh := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
		var made := (Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		var cells := promoter.on_hit(index, fresh.buildings[index])
		promoter.grids.clear()
		print(
			(
				"promote (%s): %.1f ms for %d cells (sim built in %.0f ms)"
				% [
					"cold" if k == 0 else "warm",
					(Time.get_ticks_usec() - t) / 1000.0,
					cells.cells.size(),
					made
				]
			)
		)
	quit()
