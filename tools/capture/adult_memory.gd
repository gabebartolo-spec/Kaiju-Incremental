extends SceneTree
## Adult (stage 3) city memory probe (headless): loads the adult city (the biggest, D-135), rises,
## then autoplays a rampage for 60 s of sim time, printing static memory, meshed buildings and
## the slowest streaming step
## at load, 10 s and 60 s. Fails (exit 1) over PEAK_MB or over a 50 ms streaming step.
##   godot --headless --path . --script res://tools/capture/adult_memory.gd
## Run one at a time: the old stream took 10+ GB in 8 s here.

const Kit := preload("res://tools/capture/capture_kit.gd")
const ADULT_STAGE := 3  # the last growth stage (D-135: three steps)
const PEAK_MB := 6144
const HITCH_MS := 50.0
const SECONDS := 60.0

var _rampage: Rampage
var _peak := 0
var _worst := 0.0
var _t0 := 0
var _clock := 0.0
var _peak_private := 0


func _initialize() -> void:
	_run.call_deferred()


func _meshed() -> int:
	var stream := _stream()
	var k := 0
	for n: int in _rampage.sim.buildings.size():
		k += 1 if stream.built(n) != null else 0
	return k


## The process's private bytes in MB (what the OS holds, GPU driver copies included), or -1.
func _private_mb() -> int:
	var out := []
	var code := OS.execute(
		"powershell",
		[
			"-NoProfile",
			"-Command",
			"[int]((Get-Process -Id %d).PrivateMemorySize64/1MB)" % OS.get_process_id()
		],
		out
	)
	return int(str(out[0]).strip_edges()) if code == 0 and not out.is_empty() else -1


func _note(tag: String) -> void:
	var mb := OS.get_static_memory_usage() / 1048576
	_peak = maxi(_peak, mb)
	var priv := _private_mb()
	_peak_private = maxi(_peak_private, priv)
	print(
		(
			(
				"MEM %-8s static %5d MB  peak %5d MB  meshed %d/%d  resident %d chunks  pinned %d"
				+ "  worst stream step %.0f ms  private %d MB  video %d MB  sim %.1f s  wall %d s"
			)
			% [
				tag,
				mb,
				_peak,
				_meshed(),
				_rampage.sim.buildings.size(),
				_stream().resident_chunks(),
				_pinned(),
				_worst,
				priv,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576,
				_el(),
				(Time.get_ticks_msec() - _t0) / 1000
			]
		)
	)


func _run() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec()
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), Kit.STAGE_LEVELS[ADULT_STAGE - 1], "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	_rampage = Rampage.new()
	var layout := CityGrowth.layout(Content.tuning(), ADULT_STAGE, Seeds.make("city", 0))
	_rampage.setup(species, stats, layout, 0)
	_rampage.set_autoplay(true)
	root.add_child(_rampage)
	while not _rampage.is_loaded:
		await process_frame
	_clock = _rampage.sim.time_left
	_note("load")
	while _rampage.sim.emerge.active:
		await physics_frame
	var start := _el()
	var marks := {10.0: "10 s", 30.0: "30 s", 60.0: "60 s"}
	var last := Time.get_ticks_usec()
	while _el() - start < SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		var last_before := last
		last = now
		if (now - last_before) / 1000.0 > 3000.0:
			print(
				(
					"SLOW frame %.0f ms at sim %.1f  proc %.0f phys %.0f ms"
					% [
						(now - last_before) / 1000.0,
						_el() - start,
						Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
						Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
					]
				)
			)
		_worst = _stream().worst_usec / 1000.0
		_peak = maxi(_peak, OS.get_static_memory_usage() / 1048576)
		for at: float in marks.keys():
			if _el() - start >= at:
				_note(str(marks[at]))
				marks.erase(at)
	_peak = maxi(_peak, _peak_private)
	var ok := _peak <= PEAK_MB and _worst <= HITCH_MS
	print(
		(
			"RESULT %s peak %d MB (limit %d), worst stream step %.0f ms (limit %.0f)"
			% ["PASS" if ok else "FAIL", _peak, PEAK_MB, _worst, HITCH_MS]
		)
	)
	quit(0 if ok else 1)


func _el() -> float:
	return _clock - _rampage.sim.time_left


func _stream() -> BuildingStream:
	var city: CityView = _rampage.get("_city")
	return city.get("_stream")


func _pinned() -> int:
	var pinned: PackedByteArray = _stream().get("_pinned")
	var k := 0
	for v: int in pinned:
		k += v
	return k
