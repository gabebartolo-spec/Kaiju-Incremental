extends SceneTree
## Frame time with the Tripo city pool (D-256) on and off in one session, so both see the same
## machine load: --rounds alternating takes (on, off, on, off...) of the stage 3 city (seed 0)
## with the stage 3 body on autoplay, each timed over its first --window seconds and again after
## --seconds of rampage. Prints per take the median frame (wall clock), its 95th percentile, GPU
## and logic ms, then the averages per mode. Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 3840x2160 --windowed --script tools/capture/bench_pool_frames.gd \
##     -- --preset=medium --rounds=4 --seconds=60 --window=5

const Kit := preload("res://tools/capture/capture_kit.gd")
const STAGE := 3
const SETTLE := 30  ## frames after the load before timing
const SLOW_X := 2.0  ## a frame over this times the take's median is printed with its split

var _rounds := 4
var _seconds := 60.0
var _window := 5.0
## --hold=M: stream_view.hold_m for every take (the memory reference: --hold=0 is the old stream);
## -1 keeps the data's.
var _hold := -1.0


func _initialize() -> void:
	var a := Kit.args(
		{"preset": "", "rounds": _rounds, "seconds": _seconds, "window": _window, "hold": _hold}
	)
	_hold = Num.f(a["hold"])
	PlayerSettings.graphics = str(a["preset"])
	_rounds = Num.i(a["rounds"])
	_seconds = Num.f(a["seconds"])
	_window = Num.f(a["window"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Kit.measure_on(self)
	var cfg: Dictionary = CityGrowth.tuning_for(Content.tuning(), STAGE)["city"]
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[STAGE - 1], "reptilian")
	var zero := PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])
	var sums := {"on": zero.duplicate(), "off": zero.duplicate()}
	for k: int in _rounds:
		var on := k % 2 == 0
		var city := cfg if on else _off(cfg)
		var layout := CityGen.generate(Seeds.make("city", 0), city)
		var rampage := Kit.autoplay(self, "reptilian", stats, 2, layout)
		if _hold >= 0.0:
			var view: Dictionary = rampage.sim.city["stream_view"]
			view["hold_m"] = _hold
		await rampage.wait_loaded()
		await Kit.frames(self, SETTLE)
		var start := await _take(_window)
		var rest := _seconds - _window * 2.0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < rest * 1000.0:
			await process_frame
		var late := await _take(_window)
		var mode := "on" if on else "off"
		print(
			(
				"take %d pool %s: start %s; after %.0f s %s"
				% [k, mode, _line(start), _seconds, _line(late)]
			)
		)
		print("  worst costs (ms): ", _worst(rampage.cost_usec))
		print("  ", _memory(rampage))
		var s: PackedFloat64Array = sums[mode]
		for n: int in 4:
			s[n] += start[n] / (_rounds / 2.0)
			s[n + 4] += late[n] / (_rounds / 2.0)
		sums[mode] = s
		rampage.queue_free()
		await Kit.frames(self, 10)
	for mode: String in ["on", "off"]:
		var s: PackedFloat64Array = sums[mode]
		print("pool %s mean: start %s; late %s" % [mode, _line(s.slice(0, 4)), _line(s.slice(4))])
	quit()


## [median wall-clock frame ms, average GPU render ms, 95th-percentile frame ms, median logic ms
## (process + physics)] over the next `seconds`: medians, as other jobs on the PC add spikes.
## Prints every frame over SLOW_X times the median with where its time went: process, physics,
## GPU, render CPU, and per-system costs when probes fill Engine meta "frame_cost"; then those
## costs summed over the slow frames, the costliest first.
func _take(seconds: float) -> PackedFloat64Array:
	var rid := root.get_viewport_rid()
	var walls: Array[float] = []
	var logic: Array[float] = []
	var rows: Array[Array] = []
	var gpu := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	Engine.set_meta("frame_cost", {})
	while Time.get_ticks_usec() - t0 < seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var wall := (now - last) / 1000.0
		last = now
		var split := PackedFloat64Array(
			[
				wall,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				RenderingServer.viewport_get_measured_render_time_gpu(rid),
				RenderingServer.viewport_get_measured_render_time_cpu(rid),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			]
		)
		rows.append([split, Engine.get_meta("frame_cost", {})])
		Engine.set_meta("frame_cost", {})
		walls.append(wall)
		gpu += split[3]
		logic.append(split[1] + split[2])
	walls.sort()
	logic.sort()
	var n := maxi(1, walls.size())
	_slow_frames(rows, walls[n / 2])
	_means(rows)
	return PackedFloat64Array(
		[walls[n / 2], gpu / n, walls[mini(n - 1, int(n * 0.95))], logic[n / 2]]
	)


static func _slow_frames(rows: Array[Array], median: float) -> void:
	var total: Dictionary = {}
	var slow := 0
	for row: Array in rows:
		var split: PackedFloat64Array = row[0]
		if split[0] <= median * SLOW_X:
			continue
		slow += 1
		var costs: Dictionary = row[1]
		var parts: Array[String] = []
		for key: String in costs:
			total[key] = Num.i(total.get(key, 0)) + Num.i(costs[key])
			if Num.i(costs[key]) >= 5000:
				parts.append("%s %d" % [key, Num.i(costs[key]) / 1000])
		print(
			(
				"  slow %.0f ms: process %.0f physics %.0f gpu %.0f render cpu %.0f | %s"
				% [split[0], split[1], split[2], split[3], split[4], ", ".join(parts)]
			)
		)
	var keys: Array = total.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return Num.i(total[a]) > Num.i(total[b]))
	var top: Array[String] = []
	for k: Variant in keys.slice(0, 8):
		top.append("%s %d" % [k, Num.i(total[k]) / 1000])
	print("  %d slow frames (> %.0f ms); summed: %s" % [slow, median * SLOW_X, ", ".join(top)])


## The mean per frame of each split (process, physics, GPU, render CPU) and of each probed cost
## over a take, the costliest first: what every frame pays, as against the slow frames.
static func _means(rows: Array[Array]) -> void:
	var split_sum := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var total: Dictionary = {}
	for row: Array in rows:
		var split: PackedFloat64Array = row[0]
		for k: int in split.size():
			split_sum[k] += split[k]
		var costs: Dictionary = row[1]
		for key: String in costs:
			total[key] = Num.i(total.get(key, 0)) + Num.i(costs[key])
	var n := maxf(1.0, rows.size())
	var keys: Array = total.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return Num.i(total[a]) > Num.i(total[b]))
	var top: Array[String] = []
	for k: Variant in keys.slice(0, 12):
		top.append("%s %.1f" % [k, Num.i(total[k]) / 1000.0 / n])
	print(
		(
			("  mean/frame: wall %.0f process %.1f physics %.1f gpu %.1f render cpu %.1f"
			+ " draws %.0f prims %.2f M objects %.0f | %s")
			% [
				split_sum[0] / n,
				split_sum[1] / n,
				split_sum[2] / n,
				split_sum[3] / n,
				split_sum[4] / n,
				split_sum[5] / n,
				split_sum[6] / n,
				split_sum[7] / n,
				", ".join(top)
			]
		)
	)


## The six costliest sim steps and event kinds of a take (Rampage.cost_usec), worst first.
static func _worst(costs: Dictionary) -> String:
	var keys: Array = costs.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return Num.i(costs[a]) > Num.i(costs[b]))
	var out: Array[String] = []
	for k: Variant in keys.slice(0, 6):
		out.append("%s %.1f" % [k, Num.f(costs[k]) / 1000.0])
	return ", ".join(out)


## The stream's load at the take's end: buildings within stream_view.hold_m of the kaiju (held
## meshed), meshed buildings and chunks, static and video memory.
static func _memory(rampage: Rampage) -> String:
	var view: Dictionary = rampage.sim.city["stream_view"]
	var hold := Num.f(view.get("hold_m", 0.0))
	var held := 0
	for b: RampageSim.Building in rampage.sim.buildings:
		held += int(Vector2(b.x, b.z).distance_to(rampage.sim.kaiju_pos) <= hold)
	var meshed := 0
	var chunks := 0
	for node: Node in rampage.find_children("*", "", true, false):
		if not node is BuildingStream:
			continue
		var stream: BuildingStream = node
		chunks += stream.resident_chunks()
		for n: int in rampage.sim.buildings.size():
			meshed += int(stream.built(n) != null)
	return (
		"held within %.0f m: %d; meshed %d buildings, %d chunks; static %.0f MB, video %.0f MB"
		% [
			hold,
			held,
			meshed,
			chunks,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		]
	)


static func _line(t: PackedFloat64Array) -> String:
	return "frame %.1f ms (p95 %.1f) gpu %.1f ms logic %.1f ms" % [t[0], t[2], t[1], t[3]]


## `cfg` with the pool's placement off (today's city).
static func _off(cfg: Dictionary) -> Dictionary:
	var out := cfg.duplicate()
	var shared_book: Dictionary = cfg["building_pool"]
	var book := shared_book.duplicate()
	var shared_pl: Dictionary = book["placement"]
	var pl := shared_pl.duplicate()
	pl["on"] = false
	book["placement"] = pl
	out["building_pool"] = book
	return out
