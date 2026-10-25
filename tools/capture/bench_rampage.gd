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
const WINDOW_S := 5.0

var _species := "reptilian"
var _seconds := 30.0
var _stage := 0


func _initialize() -> void:
	var a := Kit.args(
		{"species": _species, "seconds": _seconds, "stage": _stage, "nofx": false, "preset": ""}
	)
	PostFx.enabled = a["nofx"] != true
	PlayerSettings.graphics = str(a["preset"])
	_species = str(a["species"])
	_seconds = Num.f(a["seconds"])
	_stage = Num.i(a["stage"])
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
	Kit.measure_on(self)
	await Kit.frames(self, 30)
	var frames := 0
	var gpu_sum := 0.0
	var gpu_max := 0.0
	var cpu_max := 0.0
	var logic_max := 0.0
	var slow := 0
	var gap_max := 0.0
	# Frame time over the first and the last WINDOW_S seconds: [frames, gap sum ms, gpu sum ms].
	var head := [0, 0.0, 0.0]
	var tail := [0, 0.0, 0.0]
	var last := Time.get_ticks_usec()
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < _seconds * 1000.0 and not rampage.sim.over:
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
		var t := (Time.get_ticks_msec() - start) / 1000.0
		for win: Array in [head if t < WINDOW_S else [], tail if t > _seconds - WINDOW_S else []]:
			if not win.is_empty():
				win[0] += 1
				win[1] += gap
				win[2] += gpu
		if gap > 33.4:
			slow += 1
			print("slow frame: %.1fms at %.1fs" % [gap, (Time.get_ticks_msec() - start) / 1000.0])
	print("frame gaps: worst %.1fms, %d of %d frames over 33 ms" % [gap_max, slow, frames])
	for win: Array in [["first", head], ["last", tail]]:
		var got: Array = win[1]
		var n := maxi(1, Num.i(got[0]))
		print(
			(
				"frame time, %s %.0f s: %.2f ms (gpu %.2f ms) over %d frames"
				% [win[0], WINDOW_S, Num.f(got[1]) / n, Num.f(got[2]) / n, got[0]]
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
