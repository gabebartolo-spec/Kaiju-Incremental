extends SceneTree
## Where the slow frames of a heavy-destruction rampage go (b2-3). An autoplayed rampage (the
## same as bench_rampage) logs every frame's wall-clock gap with what Rampage spent in it (sim
## step and each event kind), the engine's process and physics times, and the live counts
## (physics debris, nodes, active bodies). The worst frames are listed at the end. Needs a
## window; put an off-screen no_focus override.cfg in the project first.
##
##   godot --path . --windowed --resolution 1920x1080 --script tools/capture/bench_heavy.gd \
##     -- --species=reptilian --seconds=60 --slow=50

var _species := "reptilian"
var _seconds := 60.0
var _slow := 50.0
var _worst: Array[Dictionary] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg.begins_with("--slow="):
			_slow = arg.substr(7).to_float()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def(_species)
	var levels := {"claws": 4, "hide": 3, "rage": 3, "quake": 2, "evolve1": 1, "sig_power": 2}
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 2
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	for _i: int in 30:
		await process_frame
	var city: CityView = null
	for node: Node in rampage.get_children():
		if node is CityView:
			city = node
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var frames := 0
	var gap_sum := 0.0
	var gap_max := 0.0
	var over := 0
	var last := Time.get_ticks_usec()
	var start := Time.get_ticks_msec()
	rampage.spent_usec.clear()
	while Time.get_ticks_msec() - start < _seconds * 1000.0 and not rampage.sim.over:
		await process_frame
		var now := Time.get_ticks_usec()
		var gap := (now - last) / 1000.0
		last = now
		frames += 1
		gap_sum += gap
		gap_max = maxf(gap_max, gap)
		var row := _row(rampage, city, vp, gap, (Time.get_ticks_msec() - start) / 1000.0)
		rampage.spent_usec.clear()
		if gap > _slow:
			over += 1
			_worst.append(row)
			print(_line(row))
	print(
		(
			"frames %d avg gap %.1f ms worst %.1f ms, %d over %.0f ms, chunks destroyed %d"
			% [
				frames,
				gap_sum / maxi(1, frames),
				gap_max,
				over,
				_slow,
				rampage.sim.chunks_destroyed
			]
		)
	)
	print("worst single sim tick: ", rampage.worst_tick)
	print(_cache_tally(rampage))
	print("settle time (ms) over the run: ", VoxelFrame.PROF)
	_worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["gap"] > b["gap"])
	print("WORST 12:")
	for k: int in mini(12, _worst.size()):
		print(_line(_worst[k]))
	quit()


func _row(rampage: Rampage, city: CityView, vp: RID, gap: float, at: float) -> Dictionary:
	var debris: DebrisField = city.get("_debris")
	var bodies: Array = debris.get("_bodies")
	var queue: Array = debris.get("_queue")
	var costs := {}
	for key: Variant in rampage.spent_usec:
		var ms := Num.f(rampage.spent_usec[key]) / 1000.0
		if ms >= 1.0:
			costs[key] = snappedf(ms, 0.1)
	return {
		"at": at,
		"gap": gap,
		"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"gpu": RenderingServer.viewport_get_measured_render_time_gpu(vp),
		"rcpu": RenderingServer.viewport_get_measured_render_time_cpu(vp),
		"debris": bodies.size(),
		"queued": queue.size(),
		"active": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"pairs": int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"costs": costs,
	}


## The settle cache's tally over every carved building: fast and full settles, and why it gave up.
func _cache_tally(rampage: Rampage) -> String:
	var fast := 0
	var full := 0
	var quiet := 0
	var why := {}
	for n: Variant in rampage.sim.carving.grids:
		var g: Carving.Grid = rampage.sim.carving.grids[n]
		var cache: VoxelSettleCache = g.frame.get("_cache")
		if cache == null:
			continue
		fast += cache.fast
		quiet += cache.quiet
		full += cache.full
		for k: Variant in cache.why:
			why[k] = Num.i(why.get(k, 0)) + Num.i(cache.why[k])
	return "settle cache: %d fast, %d full (%d without a fall); gave up: %s" % [fast, full, quiet, str(why)]


func _line(r: Dictionary) -> String:
	return (
		(
			"%.1fs gap %.0f proc %.0f phys %.0f gpu %.0f rcpu %.0f | debris %d (+%d) active %d"
			+ " pairs %d nodes %d draws %d | %s"
		)
		% [
			r["at"],
			r["gap"],
			r["proc"],
			r["phys"],
			r["gpu"],
			r["rcpu"],
			r["debris"],
			r["queued"],
			r["active"],
			r["pairs"],
			r["nodes"],
			r["draws"],
			str(r["costs"])
		]
	)
