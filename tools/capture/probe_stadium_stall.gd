extends SceneTree
## Where the stadium collapse's frame stalls go (lead, 2026-10-19): an autoplayed reptilian
## starts at the stadium's south kerb (the flow suite's set-up) and smashes it; every frame logs
## its wall-clock gap and Rampage's own per-frame costs (sim.step and each event kind), and every
## frame over --slow ms is printed with its breakdown. Also times one settle() of the whole
## stadium and the view's lift_piece of one section. Uses nothing newer than #57, so it runs at
## the pre-#59 base too. Runs on CI (capture.yml); never on the director's PC.
##
##   godot --path . --script tools/capture/probe_stadium_stall.gd -- --frames=1500 --slow=40

var _frames := 1500
var _slow := 40.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames = arg.substr(9).to_int()
		elif arg.begins_with("--slow="):
			_slow = arg.substr(7).to_float()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rampage := Rampage.new()
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(species, stats, CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0)), 0)
	root.add_child(rampage)
	for _i: int in 30:
		await process_frame
	var sim := rampage.sim
	var stadium: RampageSim.Building = null
	var index := -1
	for n: int in sim.buildings.size():
		if sim.buildings[n].landmark == "stadium":
			stadium = sim.buildings[n]
			index = n
	var t := Time.get_ticks_usec()
	stadium.frame.settle()  # whole and standing: nothing comes down, but it walks every chunk
	print(
		(
			"settle(): %.2f ms for %d chunks"
			% [(Time.get_ticks_usec() - t) / 1000.0, stadium.frame.alive_count]
		)
	)
	var city: CityView = null
	for node: Node in rampage.get_children():
		if node is CityView:
			city = node
	_time_lift(city, stadium, index)
	sim.kaiju_pos = Vector2(stadium.x, stadium.z + stadium.d * 0.5 + 1.0)
	rampage.set_autoplay(true)
	var whole := stadium.frame.alive_count
	var totals := {}
	var worst := {}
	var slow := 0
	var gap_max := 0.0
	var last := Time.get_ticks_usec()
	for frame: int in _frames:
		rampage.cost_usec = {}
		await physics_frame
		await process_frame
		var now := Time.get_ticks_usec()
		var gap := (now - last) / 1000.0
		last = now
		gap_max = maxf(gap_max, gap)
		var parts: Array[String] = []
		for k: String in rampage.cost_usec:
			var ms := Num.f(rampage.cost_usec[k]) / 1000.0
			totals[k] = Num.f(totals.get(k, 0.0)) + ms
			worst[k] = maxf(Num.f(worst.get(k, 0.0)), ms)
			if ms >= 1.0:
				parts.append("%s %.1f" % [k, ms])
		var physics := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if gap > _slow:
			slow += 1
			print(
				(
					"slow f%d %.2fs: gap %.1f ms, physics %.1f, stadium %d/%d [%s]"
					% [
						frame,
						frame / 60.0,
						gap,
						physics,
						stadium.frame.alive_count,
						whole,
						", ".join(parts)
					]
				)
			)
		if sim.over or stadium.frame.alive_count == 0:
			break
	print("frames over %.0f ms: %d, worst gap %.1f ms" % [_slow, slow, gap_max])
	for k: String in worst:
		print("  %s: worst %.1f ms, total %.0f ms" % [k, worst[k], totals[k]])
	print("stadium left: %d of %d chunks" % [stadium.frame.alive_count, whole])
	quit()


## One arc section's view work, as fall_start does it (the piece is freed again).
func _time_lift(city: CityView, stadium: RampageSim.Building, index: int) -> void:
	var cells: Array[Vector3i] = []
	for y: int in range(2, stadium.height):
		for z: int in stadium.d:
			for x: int in stadium.w:
				var c := Vector3i(x, y, z)
				if stadium.frame.alive(c) and stadium.frame.arcs.arc_at(x, z) == 30:
					cells.append(c)
	var view: BuildingView = null
	for node: Node in city.find_children("*", "", true, false):
		if node is BuildingView and (node as BuildingView).b == stadium:
			view = node
	if view == null:
		print("lift_piece: no stadium view")
		return
	var t := Time.get_ticks_usec()
	var piece := view.lift_piece(cells, Vector3(stadium.x, 2, stadium.z))
	var spent := (Time.get_ticks_usec() - t) / 1000.0
	print("lift_piece: %.2f ms for %d chunks (building %d)" % [spent, cells.size(), index])
	piece.free()
