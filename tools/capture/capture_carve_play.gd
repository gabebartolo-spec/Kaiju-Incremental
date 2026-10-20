extends SceneTree
## Carving in the real rampage (D-094 in play): an upgraded croc titan walks to the tallest
## tower it can break, by real key presses (W/A/S/D events through Input, never the sim's
## step or a handler), and stomps at its base until the tower comes down; the camera is the
## game's. Prints the carve counts (buildings promoted, carves, falls, islands, live bodies,
## rubble) and, with --bench, frame times from the engine's own timers. Headless gives the
## counts only.
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 30 \
##     --write-movie <dir>/clip.avi --script tools/capture/capture_carve_play.gd -- --seconds=30
##   godot --path . --resolution 1920x1080 --windowed --script tools/capture/capture_carve_play.gd \
##     -- --bench --graphics=balanced --seconds=30
## --carving=off runs the same input on the chunk path (data flag destruction.carving_enabled).

const KEYS := {"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D}

var _seconds := 30.0
var _bench := false
var _graphics := ""
var _species := "reptilian"
var _out := ""
var _carving := ""
var _islands := false
var _held := {}
var _rampage: Rampage
var _target := -1


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg == "--islands":
			_islands = true
		elif arg == "--bench":
			_bench = true
		elif arg.begins_with("--graphics="):
			_graphics = arg.substr(11)
		elif arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--carving="):
			_carving = arg.substr(10)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _carving != "":
		Content.section("destruction")["carving_enabled"] = _carving == "on"
	if _graphics != "":
		PlayerSettings.graphics = _graphics
		PlayerSettings.apply_graphics(root)
	var species := Content.species_def(_species)
	var levels := {"claws": 4, "hide": 3, "rage": 3, "quake": 2, "evolve1": 1, "sig_power": 2}
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	_rampage = Rampage.new()
	_rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 2
	)
	_rampage.autoplay_signature = false
	root.add_child(_rampage)
	var sim := _rampage.sim
	_target = _tallest(sim)
	var t := sim.buildings[_target]
	print(
		(
			"CARVE target building %d: %dx%dx%d tier %d at (%.1f, %.1f), kaiju tier %d"
			% [_target, t.w, t.d, t.height, t.tier, t.x, t.z, sim.size_tier()]
		)
	)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var frames := 0
	var gpu_sum := 0.0
	var gpu_max := 0.0
	var gap_max := 0.0
	var slow := 0
	var gaps := PackedFloat32Array()
	var last := Time.get_ticks_usec()
	var steps := roundi(_seconds * Engine.physics_ticks_per_second)
	var step := 0
	var fell_at := -1
	while step < steps and not sim.over:
		await physics_frame
		step += 1
		_steer(sim, t)
		if fell_at < 0 and _city().carve != null and _city().carve.falls > 0:
			fell_at = step
			print(
				(
					"CARVE first carved fall at step %d (%.1fs)"
					% [step, float(step) / Engine.physics_ticks_per_second]
				)
			)
		if step % 150 == 0:
			_report(step)
		if _islands and fell_at > 0 and (step - fell_at) % 15 == 0 and step - fell_at <= 300:
			_report_islands(step)
		if _bench:
			frames += 1
			var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
			gpu_sum += gpu
			gpu_max = maxf(gpu_max, gpu)
			var now := Time.get_ticks_usec()
			var gap := (now - last) / 1000.0
			last = now
			if frames > 30:
				gaps.append(gap)
				gap_max = maxf(gap_max, gap)
				if gap > 33.4:
					slow += 1
					_report_slow(step, gap)
			_rampage.frame_usec.clear()
			if _city().carve != null:
				_city().carve.frame_usec.clear()
	_release_all()
	_report(step)
	if _bench and not gaps.is_empty():
		var sorted := gaps.duplicate()
		sorted.sort()
		var mean := 0.0
		for g: float in gaps:
			mean += g
		mean /= gaps.size()
		print(
			(
				(
					"CARVE bench %s graphics %s: %d frames, mean %.1fms (%.0f fps), p95 %.1fms, worst %.1fms,"
					+ " %d over 33 ms, gpu avg %.1fms max %.1fms"
				)
				% [
					_species,
					PlayerSettings.graphics_level(),
					gaps.size(),
					mean,
					1000.0 / mean,
					sorted[floori(sorted.size() * 0.95)],
					gap_max,
					slow,
					gpu_sum / maxi(1, frames),
					gpu_max
				]
			)
		)
	print("CARVE worst costs (ms): ", _costs(_rampage.cost_usec))
	if _city().carve != null:
		print("CARVE carve costs (ms): ", _costs(_city().carve.cost_usec))
	PlayerSettings.graphics = ""
	_rampage.queue_free()
	await process_frame
	await process_frame
	quit()


## The tallest standing tower the kaiju can break (tier at most its own), nearest first on ties.
func _tallest(sim: RampageSim) -> int:
	var best := -1
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if b.landmark != "" or b.tier > sim.size_tier():
			continue
		if best < 0 or b.height > sim.buildings[best].height:
			best = n
		elif b.height == sim.buildings[best].height:
			var here := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
			var there := Vector2(sim.buildings[best].x, sim.buildings[best].z).distance_to(
				sim.kaiju_pos
			)
			if here < there:
				best = n
	return best


## Holds the keys toward the tower's near face while it stands; then stands still.
func _steer(sim: RampageSim, t: RampageSim.Building) -> void:
	var want := Vector2.ZERO
	if t.frame.alive_count > 0:
		var to := Vector2(t.x, t.z) - sim.kaiju_pos
		var stop := maxf(t.w, t.d) * 0.5 + sim.stomp_radius() * 0.4
		if to.length() > stop:
			want = to.normalized()
	_hold("right", want.x > 0.38)
	_hold("left", want.x < -0.38)
	_hold("down", want.y > 0.38)
	_hold("up", want.y < -0.38)


func _hold(dir: String, on: bool) -> void:
	if _held.get(dir, false) == on:
		return
	_held[dir] = on
	var event := InputEventKey.new()
	event.keycode = KEYS[dir]
	event.physical_keycode = KEYS[dir]
	event.pressed = on
	Input.parse_input_event(event)


func _release_all() -> void:
	for dir: String in KEYS:
		_hold(dir, false)


func _city() -> CityView:
	for node: Node in _rampage.get_children():
		if node is CityView:
			return node
	return null


func _report(step: int) -> void:
	var city := _city()
	var t := _rampage.sim.buildings[_target]
	var line := (
		"CARVE step %d: target alive %d/%d chunks"
		% [step, t.frame.alive_count, t.w * t.d * t.height]
	)
	if city.carve != null:
		var c := city.carve
		var form := ", promoted %d, carves %d, falls %d, islands %d, live %d, rubble %d"
		form += " (max/building %d, dropped %d)"
		var islands := c.physics.islands().size()
		var live := c.physics.live_bodies()
		var rubble := [
			c.physics.rubble_pieces(), c.physics.rubble_max(), c.physics.rubble_dropped()
		]
		line += form % ([c.promoted, c.carves, c.falls, islands, live] + rubble)
	print(line)


## "name ms" per worst cost (usec).
func _costs(usec: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: String in usec:
		out.append("%s %.1f" % [k, Num.f(usec[k]) / 1000.0])
	return out


## A frame over 33 ms (--bench): what the rampage and the carving spent in it.
func _report_slow(step: int, gap: float) -> void:
	var c := _city().carve
	var live := c.physics.live_bodies() if c != null else 0
	var spent := _costs(_rampage.frame_usec)
	if c != null:
		spent.append_array(_costs(c.frame_usec))
	print("CARVE slow step %d: %.1fms, live %d, spent (ms) %s" % [step, gap, live, spent])


## Each island's tilt from upright (degrees), height of its centre, speed, spin and state.
func _report_islands(step: int) -> void:
	for island: IslandBody in _city().carve.physics.islands():
		var tilt := rad_to_deg(island.global_basis.y.angle_to(Vector3.UP))
		var low := INF
		var high := -INF
		for child: Node in island.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
				var mi := child as MeshInstance3D
				var box := mi.global_transform * mi.mesh.get_aabb()
				low = minf(low, box.position.y)
				high = maxf(high, box.end.y)
		print(
			(
				"CARVE island step %d b%d cells %d: tilt %.0f, y %.1f (%.1f..%.1f), v %.2f, w %.2f, %s"
				% [
					step,
					island.site.key,
					island.cell_count(),
					tilt,
					island.global_position.y,
					low,
					high,
					island.linear_velocity.length(),
					island.angular_velocity.length(),
					(
						"settled"
						if island.settled_now
						else ("following" if island.following() else "free")
					)
				]
			)
		)
