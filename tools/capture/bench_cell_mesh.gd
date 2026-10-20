extends SceneTree
## Remesh cost of a carved building (D-094 WP4): a 6x6x16 glass tower and a 3x3x6 office are
## promoted to their fine grids (CellMesher + CellView), then carved again and again by
## stomp-sized spheres down their street face; each carve's remesh (its touched 16^3 blocks on
## the WorkerThreadPool, meshes swapped in) is timed from carved() to drawn. Native and GDScript
## paths. Prints p50/p95/max ms per carve, blocks per carve and the building's triangles.
## Seeded by design: fixed buildings and a fixed carve walk.
##   godot --headless --path . --script tools/capture/bench_cell_mesh.gd -- [--carves=60]

const RADII: Array[float] = [6.0, 12.0]  # cells: a claw bite, a stomp (RES 8: 0.75, 1.5 units)

var _carves := 60


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--carves="):
			_carves = arg.substr(9).to_int()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var native := ClassDB.class_exists("KaijuMesher")
	print("native mesher loaded: %s; worker threads: %d" % [native, OS.get_processor_count()])
	for spec: Array in [["glass tower 6x6x16", 6, 6, 16, 3, 2], ["office 3x3x6", 3, 3, 6, 2, 0]]:
		for use_native: bool in [true, false]:
			if use_native and not native:
				continue
			for radius: float in RADII:
				_bench(spec, use_native, radius)
	quit()


func _bench(spec: Array, use_native: bool, radius: float) -> void:
	var b := RampageSim.Building.new()
	b.x = 0.0
	b.z = 0.0
	b.w = spec[1]
	b.d = spec[2]
	b.height = spec[3]
	b.tier = spec[4]
	b.style = spec[5]
	var t0 := Time.get_ticks_usec()
	var voxels := BuildingVoxels.new(b, Color("9a6b52"))
	var grid := BuildingCells.new(b)
	var t1 := Time.get_ticks_usec()
	var mesher := CellMesher.new(voxels, grid, use_native)
	var t2 := Time.get_ticks_usec()
	var view := CellView.new(mesher, grid.cells, StandardMaterial3D.new())
	view.flush()
	var t3 := Time.get_ticks_usec()
	var cells := grid.cells
	var dims := mesher.dims
	var times: Array[float] = []
	var blocks := 0
	for k: int in _carves:
		# Walk down and across the street face, as a kaiju clawing its way down the tower.
		var centre := Vector3(
			float((k * 7) % dims.x), dims.y - 4.0 - float(k * dims.y) / _carves, dims.z - 2.0
		)
		cells = cells.duplicate()
		var lo := Vector3i(centre - Vector3.ONE * radius).max(Vector3i.ZERO)
		var hi := Vector3i(centre + Vector3.ONE * radius).min(dims - Vector3i.ONE)
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				for x: int in range(lo.x, hi.x + 1):
					var p := Vector3(x + 0.5, y + 0.5, z + 0.5) - centre
					if p.length_squared() <= radius * radius:
						cells[x + z * dims.x + y * dims.x * dims.z] = 0
		var s := Time.get_ticks_usec()
		view.carved(cells, lo, hi)
		view.flush()
		times.append((Time.get_ticks_usec() - s) / 1000.0)
		blocks += view.last_batch.size()
	var tris := 0
	for r: Vector3i in view.parts:
		var mi: MeshInstance3D = view.parts[r]
		var mesh: ArrayMesh = mi.mesh
		tris += mesh.surface_get_array_index_len(0) / 3
	times.sort()
	print(
		(
			(
				"%s %s r%d: grid+voxels %.0f ms, looks %.0f ms, first build %.0f ms (%d blocks);"
				+ " remesh per carve p50 %.2f p95 %.2f max %.2f ms, %.1f blocks a carve;"
				+ " %d triangles after %d carves"
			)
			% [
				spec[0],
				"native" if use_native else "gdscript",
				radius,
				(t1 - t0) / 1000.0,
				(t2 - t1) / 1000.0,
				(t3 - t2) / 1000.0,
				mesher.all_regions().size(),
				times[times.size() / 2],
				times[floori(times.size() * 0.95)],
				times[-1],
				float(blocks) / _carves,
				tris,
				_carves
			]
		)
	)
	view.free()
