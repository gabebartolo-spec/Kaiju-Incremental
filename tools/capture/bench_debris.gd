extends SceneTree
## CPU cost of CarveDebris bookkeeping at N live pieces, cache off versus on (render plan item 1).
## One physics world per pass, one burst of N pieces thrown high so most stay live, then FRAMES
## frames in which this script calls _physics_process and _process by hand and times each with
## Time.get_ticks_usec (the engine's own calls are switched off, so the times are exactly the
## CarveDebris work). Run with --fixed-fps 60 so one physics tick follows each frame.
##   godot --headless --fixed-fps 60 --path . --script tools/capture/bench_debris.gd \n##     -- --n=1000,3000
## Prints one BENCH_DEBRIS line per pass: p50 / p95 / max of (physics + process) in ms, the live
## count at the start and end, and the server reads per live piece per tick.

const FRAMES := 150
const SEED := 20261026

var _ns: Array[int] = [1000, 3000]
var _passes := 2


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			_ns.clear()
			for s: String in a.substr(4).split(",", false):
				_ns.append(int(s))
		elif a.begins_with("--passes="):
			_passes = int(a.substr(9))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	print(
		(
			"BENCH_DEBRIS godot=%s fps=%d"
			% [Engine.get_version_info()["string"], Engine.physics_ticks_per_second]
		)
	)
	for n: int in _ns:
		for pass_i: int in _passes:
			for opt: bool in [false, true]:
				await _pass(n, opt, pass_i)
	quit(0)


func _pass(n: int, opt: bool, pass_i: int) -> void:
	var view := SubViewport.new()
	view.own_world_3d = true
	view.size = Vector2i(64, 64)
	root.add_child(view)
	var space := view.find_world_3d().space
	var ground := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(ground, PhysicsServer3D.BODY_MODE_STATIC)
	var box := BoxShape3D.new()
	box.size = Vector3(800, 2, 800)
	PhysicsServer3D.body_add_shape(ground, box.get_rid())
	PhysicsServer3D.body_set_space(ground, space)
	PhysicsServer3D.body_set_state(
		ground, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), Vector3(0, -1, 0))
	)
	var d := CarveDebris.new()
	d.opt = opt
	d.site = CarveSite.new(1, Vector3(-10, 0, -10), Vector3i(20, 30, 20), 1)
	d.grid = PackedByteArray()
	view.add_child(d)
	d.set_process(false)
	d.set_physics_process(false)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var g: float = Num.f(d._cfg["piece_gravity"])
	for i: int in n:
		var at := Vector3(rng.randf_range(-8, 8), rng.randf_range(2, 14), rng.randf_range(-8, 8))
		var v := Vector3(
			rng.randf_range(-12, 12), rng.randf_range(18, 30), rng.randf_range(-12, 12)
		)
		var spin := Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		d.spawn(
			Transform3D(Basis(), at),
			Vector3.ONE * (1.0 if i % 4 else 2.0),
			Color(0.5, 0.4, 0.3),
			[v, spin, g, 1.0]
		)
	var live0: int = d.bodies()
	var times := PackedFloat64Array()
	var reads := 0
	var phys_ms := 0.0
	var draw_ms := 0.0
	var piece_ticks := 0
	for _f: int in FRAMES:
		await physics_frame
		var live: int = d.bodies()
		var r0: int = d.state_reads
		var t0 := Time.get_ticks_usec()
		d._physics_process(1.0 / 60.0)
		var t1 := Time.get_ticks_usec()
		d._process(1.0 / 60.0)
		var t2 := Time.get_ticks_usec()
		times.append((t2 - t0) / 1000.0)
		phys_ms += (t1 - t0) / 1000.0
		draw_ms += (t2 - t1) / 1000.0
		reads += d.state_reads - r0
		piece_ticks += live
	var live1: int = d.bodies()
	var sorted := times.duplicate()
	sorted.sort()
	var line := "BENCH_DEBRIS n=%d cache=%s pass=%d live %d->%d" % [n, opt, pass_i, live0, live1]
	line += (
		" p50 %.3f p95 %.3f max %.3f ms"
		% [sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.95)], sorted[-1]]
	)
	line += " (tick %.3f draw %.3f mean)" % [phys_ms / FRAMES, draw_ms / FRAMES]
	line += " reads/piece/tick %.2f" % (float(reads) / maxf(1.0, piece_ticks))
	print(line)
	d.queue_free()
	PhysicsServer3D.free_rid(ground)
	view.queue_free()
	await process_frame
