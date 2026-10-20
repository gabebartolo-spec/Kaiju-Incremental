extends SceneTree
## Times VoxelFrame (the GDScript oracle) on the destruction spike's paths: carve and settle per
## 30 Hz tick, avg / p95 / max in ms. A bench, not a test (it reads the clock).
##   godot --headless --path . --script tools/destruction_bench.gd -- [--res=8] [--block]

const Paths := preload("res://tests/lib/destruction_paths.gd")


func _initialize() -> void:
	var res := 8
	var block := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--res="):
			res = arg.substr(6).to_int()
		elif arg == "--block":
			block = true
	var frames: Array[VoxelFrame] = []
	var origins: Array[Vector3] = []
	var centres := Paths.layout(block)
	for n: int in centres.size():
		frames.append(Paths.office(Paths.units(block, n), res))
		origins.append(centres[n] - Vector3(3, 0, 3))
	var carve: Array[float] = []
	var settle: Array[float] = []
	var total: Array[float] = []
	for tick: int in roundi(Paths.SECONDS / Paths.TICK):
		var c_us := 0
		var s_us := 0
		for n: int in frames.size():
			var t := tick * Paths.TICK - n * 0.25
			if t < 0.0:
				continue
			var t0 := Time.get_ticks_usec()
			var removed := frames[n].carve_sphere(Paths.path(centres[n], t) - origins[n], 2.4)
			var t1 := Time.get_ticks_usec()
			if not removed.is_empty():
				frames[n].settle()
			c_us += t1 - t0
			s_us += Time.get_ticks_usec() - t1
		carve.append(c_us / 1000.0)
		settle.append(s_us / 1000.0)
		total.append((c_us + s_us) / 1000.0)
	print("BENCH VoxelFrame GDScript res=%d block=%s ticks=%d" % [res, block, total.size()])
	_line("carve", carve)
	_line("settle", settle)
	_line("tick", total)
	quit()


func _line(label: String, ms: Array[float]) -> void:
	var sorted := ms.duplicate()
	sorted.sort()
	var sum := 0.0
	for x: float in ms:
		sum += x
	print(
		(
			"  %-6s avg %7.2f  p95 %7.2f  max %7.2f ms"
			% [label, sum / ms.size(), sorted[int(sorted.size() * 0.95)], sorted[-1]]
		)
	)
