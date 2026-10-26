extends SceneTree
## Before/after of the light pool (R 12.1, R 12.2): the same seeded, autoplayed night rampage
## (city seed 0, the reptilian, the game camera) with the pool on (--pool=on, as shipped) or off
## (--pool=off: every lamp, fire and beacon a real light with no distance fade, as before).
## Saves stills and prints how many lights exist and are drawn at each; --seconds=N then measures
## frame rate (wall-clock and GPU time) over N seconds. Needs a window. Use --fixed-fps 60 for
## stills and leave it off for the fps line.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_light_pool.gd -- --pool=off --out=<dir>
##   godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility ... (compat)

var _pool := true
var _time := "night"
var _out := "user://light_pool"
var _tag := "forward"
var _seconds := 0.0
var _stills: Array[float] = [14.0, 24.0]


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pool="):
			_pool = arg.substr(7) == "on"
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	Content.set_time(_time)
	var rampage := Rampage.new()
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(
		species,
		stats,
		CityGen.generate(Seeds.make("city", 0), Content.section("city")),
		Content.times().find(_time)
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	await physics_frame
	while rampage.sim.emerge.active:
		await physics_frame
	var frames := 0
	if _seconds > 0.0:
		await _measure(rampage)
		quit()
		return
	for at: float in _stills:
		while frames < int(at * 60.0) and not rampage.sim.over:
			await physics_frame
			frames += 1
			_force_unpooled()
		await process_frame
		_force_unpooled()
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/%s_%s_t%02d.png" % [_out, _tag, "pool" if _pool else "nopool", int(at)]
		image.save_png(path)
		print(_lights(), " ", path)
	quit()


## The old behaviour: every light real, no distance fade (called each frame, as fires appear).
func _force_unpooled() -> void:
	if _pool:
		return
	for node: Node in get_nodes_in_group(PooledLight.GROUP):
		var light: PooledLight = node
		light.distance_fade_enabled = false
		light.set_wanted(true)
		light.weight = 1.0
		light.visible = true
		light.light_energy = light.energy
	for node: Node in get_nodes_in_group(LightPool.GROUP):
		node.process_mode = Node.PROCESS_MODE_DISABLED


func _lights() -> String:
	var total := 0
	var drawn := 0
	var lit := 0
	for node: Node in get_nodes_in_group(PooledLight.GROUP):
		var light: PooledLight = node
		total += 1
		if light.visible:
			drawn += 1
			lit += 1 if light.light_energy > 0.0 else 0
	return (
		"lights: %d in the city, %d drawn, %d with energy (pool %s)"
		% [total, drawn, lit, "on" if _pool else "off"]
	)


func _measure(rampage: Rampage) -> void:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for _i: int in 60:
		await process_frame
		_force_unpooled()
	var frames := 0
	var gpu_sum := 0.0
	var gpu_max := 0.0
	var cpu_sum := 0.0
	var worst := 0.0
	var lights_sum := 0
	var start := Time.get_ticks_usec()
	var last := start
	while (Time.get_ticks_usec() - start) < _seconds * 1000000.0 and not rampage.sim.over:
		await process_frame
		_force_unpooled()
		frames += 1
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		gpu_sum += gpu
		gpu_max = maxf(gpu_max, gpu)
		cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		lights_sum += (
			get_nodes_in_group(PooledLight.GROUP)
			. filter(func(n: Node) -> bool: return (n as PooledLight).visible)
			. size()
		)
	var wall := (last - start) / 1000000.0
	print(
		(
			(
				"fps %s %s pool %s: %.1f fps over %.1f s (%d frames), worst frame %.1f ms, gpu avg"
				+ " %.2f ms max %.2f ms, render cpu avg %.2f ms, drawn lights avg %.1f, %s"
			)
			% [
				_tag,
				_time,
				"on" if _pool else "off",
				frames / maxf(wall, 0.001),
				wall,
				frames,
				worst,
				gpu_sum / maxi(1, frames),
				gpu_max,
				cpu_sum / maxi(1, frames),
				float(lights_sum) / maxi(1, frames),
				_lights()
			]
		)
	)
