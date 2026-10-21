extends SceneTree
## Where one building's promotion to its fine grid goes (Carving._promote, b2-3): over the first
## buildings of a seeded city, times BuildingCells.new, the emptying of the dead chunks, the
## VoxelFrame adopt and the per-cell live count, and prints the totals.
##
##   godot --headless --path . --script tools/capture/probe_promote.gd -- --count=12


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var count := 12
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			count = arg.substr(8).to_int()
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	var party := BuildingView.party_walls(sim.buildings)
	var sum := {}
	var done := 0
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if b.landmark != "" or done >= count:
			continue
		done += 1
		var t := Time.get_ticks_usec()
		var cells := BuildingCells.new(b, party[n])
		var t1 := Time.get_ticks_usec()
		for y: int in b.frame.h:
			for z: int in b.frame.d:
				for x: int in b.frame.w:
					if not b.frame.alive(Vector3i(x, y, z)):
						cells.clear_chunk(Vector3i(x, y, z))
		var t2 := Time.get_ticks_usec()
		var f := VoxelFrame.new(Vector3i(b.w, b.height, b.d), cells.res, [])
		f.adopt(cells.dims, cells.offset, cells.cells)
		var t3 := Time.get_ticks_usec()
		var live := 0
		var bytes := f.cells
		for i: int in bytes.size():
			if bytes[i] != VoxelFrame.EMPTY:
				live += 1
		var t4 := Time.get_ticks_usec()
		var parts := {"new": t1 - t, "clear": t2 - t1, "frame": t3 - t2, "count": t4 - t3}
		for k: String in parts:
			sum[k] = Num.f(sum.get(k, 0.0)) + parts[k] / 1000.0
		print(
			(
				"b%d %dx%dx%d %d cells (%d live): %s"
				% [n, b.w, b.height, b.d, bytes.size(), live, str(parts)]
			)
		)
	print("totals ms over %d buildings: %s" % [done, str(sum)])
	quit()
