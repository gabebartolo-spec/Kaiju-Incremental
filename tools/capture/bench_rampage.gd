extends SceneTree
## Frame-time benchmark of a real, autoplayed rampage (debris physics, fires, the army, props).
## Reports average and worst GPU and CPU render time and the worst process + physics time,
## from the engine's own timers (window focus and vsync do not matter). Needs a window.
##
##   godot --path . --resolution 3840x2160 --windowed --script tools/capture/bench_rampage.gd \
##     -- --species=reptilian --seconds=30 [--stage=3]
## --stage=N plays growth stage N's city with that stage's body (capture_kit STAGE_LEVELS), e.g. the
## adult city (stage 3, D-135); without it, the mid-game build in the flow test's city.
## --nofx turns the post effects (PostFx, D-142) off for the cost comparison; --preset=<level>
## names the graphics preset (default: the one this screen would pick).

const Kit := preload("res://tools/capture/capture_kit.gd")
## The frame-time windows at the start and the end of the run (seconds).
## A start frame over this times the start's median is listed with its split (_slow_start).
const SLOW_X := 2.0
const WINDOW_S := 5.0

var _species := "reptilian"
var _seconds := 30.0
var _stage := 0
## --off=<script file>,...: nodes running those scripts are stopped and hidden (cost splits).
var _off: PackedStringArray = []
## --trace: every frame of the first window printed (gap, gpu, process, physics, render cpu).
var _trace := false


func _initialize() -> void:
	var a := Kit.args(
		{
			"species": _species,
			"seconds": _seconds,
			"stage": _stage,
			"nofx": false,
			"preset": "",
			"off": "",
			"trace": false
		}
	)
	PostFx.enabled = a["nofx"] != true
	PlayerSettings.graphics = str(a["preset"])
	_species = str(a["species"])
	_seconds = Num.f(a["seconds"])
	_stage = Num.i(a["stage"])
	_off = str(a["off"]).split(",", false)
	_trace = a["trace"] == true
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rampage: Rampage
	if _stage > 0:
		var levels: Dictionary = Kit.STAGE_LEVELS[_stage - 1]
		var layout := CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0))
		rampage = Kit.autoplay(self, _species, Kit.stats(_species, levels, _species), 2, layout)
	else:
		rampage = Kit.autoplay(self, _species, Kit.stats(_species, Kit.BENCH_LEVELS), 2)
	var vp := root.get_viewport_rid()
	_switch_off(rampage)
	var found := rampage.find_children("*", "BuildingStream", true, false)
	var stream: BuildingStream = found[0] if not found.is_empty() else null
	found = rampage.find_children("*", "StreetLife", true, false)
	var life: StreetLife = found[0] if not found.is_empty() else null
	Kit.measure_on(self)
	await Kit.frames(self, 30)
	var frames := 0
	var gpu_sum := 0.0
	var gpu_max := 0.0
	var cpu_max := 0.0
	var logic_max := 0.0
	var slow := 0
	var gap_max := 0.0
	# Frame time over the first and the last WINDOW_S seconds: [frames, gap sum ms, gpu sum ms,
	# process sum ms, physics sum ms].
	var head := [0, 0.0, 0.0, 0.0, 0.0]
	var tail := [0, 0.0, 0.0, 0.0, 0.0]
	# Per frame: [rampage s, gap, gpu, process, physics, probe costs, render cpu]. Probe costs:
	# usec per system that frame, from any probes filling Engine meta "frame_cost" (none: {}).
	var samples: Array[Array] = []
	Engine.set_meta("frame_cost", {})
	var last := Time.get_ticks_usec()
	var start := Time.get_ticks_msec()
	# Windows and length in the rampage's own seconds, so a slower build is compared over the same
	# play (a wall-clock run lets a fast one finish its rampage early); the wall cap is a guard.
	while (
		rampage.sim.elapsed < _seconds
		and Time.get_ticks_msec() - start < _seconds * 4000.0
		and not rampage.sim.over
	):
		await process_frame
		frames += 1
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		gpu_sum += gpu
		gpu_max = maxf(gpu_max, gpu)
		cpu_max = maxf(cpu_max, RenderingServer.viewport_get_measured_render_time_cpu(vp))
		var logic := (
			Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		)
		logic_max = maxf(logic_max, logic * 1000.0)
		var now := Time.get_ticks_usec()
		var gap := (now - last) / 1000.0
		last = now
		gap_max = maxf(gap_max, gap)
		var t := rampage.sim.elapsed
		if _trace and t < WINDOW_S:
			print(
				(
					"trace %.2fs: gap %.1f gpu %.1f process %.1f physics %.1f render cpu %.1f stream %d people %d"
					% [
						t,
						gap,
						gpu,
						Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
						Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
						RenderingServer.viewport_get_measured_render_time_cpu(vp),
						stream.resident_chunks() if stream != null else -1,
						_drawn(life)
					]
				)
			)
		samples.append(
			[
				t,
				gap,
				gpu,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Engine.get_meta("frame_cost", {}),
				RenderingServer.viewport_get_measured_render_time_cpu(vp)
			]
		)
		Engine.set_meta("frame_cost", {})
		if gap > 33.4:
			slow += 1
			print("slow frame: %.1fms at %.1fs" % [gap, (Time.get_ticks_msec() - start) / 1000.0])
	print("sim time %.1f s, over: %s" % [rampage.sim.elapsed, rampage.sim.end_reason])
	# The last window: the run's last WINDOW_S rampage seconds (it may end before --seconds).
	var end := rampage.sim.elapsed
	for sample: Array in samples:
		var at := Num.f(sample[0])
		for win: Array in [head if at < WINDOW_S else [], tail if at > end - WINDOW_S else []]:
			if not win.is_empty():
				win[0] += 1
				for k: int in range(1, 5):
					win[k] += Num.f(sample[k])
	_slow_start(samples)
	print("frame gaps: worst %.1fms, %d of %d frames over 33 ms" % [gap_max, slow, frames])
	for win: Array in [["first", head], ["last", tail]]:
		var got: Array = win[1]
		var n := maxi(1, Num.i(got[0]))
		print(
			(
				"frame time, %s %.0f s: %.2f ms (gpu %.2f, process %.2f, physics %.2f ms) over %d frames"
				% [
					win[0],
					WINDOW_S,
					Num.f(got[1]) / n,
					Num.f(got[2]) / n,
					Num.f(got[3]) / n,
					Num.f(got[4]) / n,
					got[0]
				]
			)
		)
	print(
		(
			(
				"bench %s: %d frames, gpu avg %.1fms max %.1fms, render cpu max %.1fms, logic max %.1fms,"
				+ " chunks destroyed %d"
			)
			% [
				_species,
				frames,
				gpu_sum / maxi(1, frames),
				gpu_max,
				cpu_max,
				logic_max,
				rampage.sim.chunks_destroyed
			]
		)
	)
	print("city: stage %d, %d buildings" % [_stage, rampage.sim.buildings.size()])
	print(
		"worst costs (ms): ",
		rampage.cost_usec.keys().map(
			func(k: Variant) -> String: return "%s %.1f" % [k, Num.f(rampage.cost_usec[k]) / 1000.0]
		)
	)
	for node: Node in rampage.get_children():
		if node is CityView:
			var city: CityView = node
			var street := city.street
			print(
				(
					"street life: %d people, %d cars, avg %.2fms worst %.2fms per frame"
					% [
						street.pos.size(),
						street.traffic.cars.size(),
						street.total_usec / 1000.0 / maxi(1, street.frames),
						street.worst_usec / 1000.0
					]
				)
			)
	quit()


func _switch_off(node: Node) -> void:
	for child: Node in node.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path.get_file() in _off:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			if child is Node3D:
				(child as Node3D).visible = false
			print("off: %s" % script.resource_path.get_file())
		_switch_off(child)


## How many people StreetLife drew this frame (-1 without one).
func _drawn(life: StreetLife) -> int:
	if life == null:
		return -1
	var sum := 0
	for mm: MultiMesh in life._mms:
		sum += mm.visible_instance_count
	return sum


## The first WINDOW_S rampage seconds: every frame over SLOW_X times their median, split into
## process, physics, GPU and render CPU and the probed systems over 5 ms; then the probed costs
## summed over those slow frames and over the whole window, the costliest first.
func _slow_start(samples: Array[Array]) -> void:
	var first: Array[Array] = samples.filter(func(r: Array) -> bool: return r[0] < WINDOW_S)
	if first.is_empty():
		return
	var gaps: Array[float] = []
	for row: Array in first:
		gaps.append(Num.f(row[1]))
	gaps.sort()
	var median := gaps[gaps.size() / 2]
	var on_slow := {}
	var on_all := {}
	var slow := 0
	for row: Array in first:
		var costs: Dictionary = row[5]
		var is_slow := Num.f(row[1]) > median * SLOW_X
		var parts: Array[String] = []
		for key: Variant in costs:
			on_all[key] = Num.i(on_all.get(key, 0)) + Num.i(costs[key])
			if is_slow:
				on_slow[key] = Num.i(on_slow.get(key, 0)) + Num.i(costs[key])
				if Num.i(costs[key]) >= 5000:
					parts.append("%s %d" % [key, Num.i(costs[key]) / 1000])
		if is_slow:
			slow += 1
			print(
				(
					"  slow %.0f ms at %.1f s: process %.0f physics %.0f gpu %.0f render cpu %.0f | %s"
					% [row[1], row[0], row[3], row[4], row[2], row[6], ", ".join(parts)]
				)
			)
	print("start: %d frames, median %.0f ms, %d slow" % [first.size(), median, slow])
	print("  summed on slow frames: %s" % _top(on_slow))
	print("  summed on all start frames: %s" % _top(on_all))


func _top(costs: Dictionary) -> String:
	var keys: Array = costs.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return Num.i(costs[a]) > Num.i(costs[b]))
	var top: Array[String] = []
	for k: Variant in keys.slice(0, 10):
		top.append("%s %d" % [k, Num.i(costs[k]) / 1000])
	return ", ".join(top)
