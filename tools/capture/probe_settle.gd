extends SceneTree
## Where one VoxelFrame.settle() goes (b2-3): on the biggest buildings of a seeded city, carves
## a sphere out of the middle and times the support flood, the island scan, the topple rule and
## the whole settle.
##
##   godot --headless --path . --script tools/capture/probe_settle.gd -- --count=4

const Kit := preload("res://tools/capture/capture_kit.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var count := Num.i(Kit.args({"count": 4})["count"])
	var sim := Kit.stage_sim(Kit.stats("reptilian"), 1, Content.tuning())
	var party := BuildingView.party_walls(sim.buildings)
	var order: Array[int] = []
	for n: int in sim.buildings.size():
		if sim.buildings[n].landmark == "":
			order.append(n)
	order.sort_custom(
		func(a: int, c: int) -> bool:
			return (
				sim.buildings[a].w * sim.buildings[a].height * sim.buildings[a].d
				> sim.buildings[c].w * sim.buildings[c].height * sim.buildings[c].d
			)
	)
	for k: int in mini(count, order.size()):
		var b := sim.buildings[order[k]]
		var g := BuildingCells.new(b, party[order[k]])
		var f := VoxelFrame.new(Vector3i(b.w, b.height, b.d), g.res, Content.materials())
		f.adopt(g.dims, g.offset, g.cells)
		var mid := Vector3(b.w * 0.5, b.height * 0.5, b.d * 0.5)
		f.carve_sphere(mid, 1.2)
		var t := Time.get_ticks_usec()
		var support := VoxelSupport.new(f)
		var t1 := Time.get_ticks_usec()
		var islands := support.islands().size()
		var t2 := Time.get_ticks_usec()
		var topples := support.topple().size()
		var t3 := Time.get_ticks_usec()
		var parts := f.settle()
		var t4 := Time.get_ticks_usec()
		print(
			(
				(
					"b%d %dx%dx%d grid %d cells: flood %.1f ms, islands %.1f (%d), topple %.1f (%d);"
					+ " whole settle %.1f ms (%d parts)"
				)
				% [
					order[k],
					b.w,
					b.height,
					b.d,
					f.cells.size(),
					(t1 - t) / 1000.0,
					(t2 - t1) / 1000.0,
					islands,
					(t3 - t2) / 1000.0,
					topples,
					(t4 - t3) / 1000.0,
					parts.size()
				]
			)
		)
	quit()
