extends SceneTree
## Where the "start a run" and "quit" freeze lands (director 2026-10-20, b2-30 and b2-29).
## Times, in wall-clock ms: layout + Rampage.setup, add_child (the whole _ready), the first frames'
## gaps after it, then the teardown (queue_free + the frames after) and the quit. Needs a window
## (shader compile and GPU upload are part of the freeze).
##
##   godot --path . --resolution 3840x2160 --windowed --script tools/capture/bench_run_start.gd \
##     -- --species=reptilian --frames=30

var _species := "reptilian"
var _frames := 30
## Seconds of autoplayed rampage before the teardown (the streaming finishes, debris exists).
var _play := 0.0
## Quit the whole game with the rampage alive instead of freeing it (prints the unix time).
var _quit := false
## Build the way the game does (Rampage.staged: frame by frame behind the loading screen).
var _staged := false
## --stage=N: build growth stage N's city (CityGrowth.layout) instead of the body size's.
var _stage := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--frames="):
			_frames = arg.substr(9).to_int()
		elif arg.begins_with("--play="):
			_play = arg.substr(7).to_float()
		elif arg == "--quit":
			_quit = true
		elif arg == "--staged":
			_staged = true
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8).to_int()
	_run.call_deferred()


func _ms(since: int) -> String:
	return "%.1f ms" % ((Time.get_ticks_usec() - since) / 1000.0)


func _run() -> void:
	await process_frame
	var species := Content.species_def(_species)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {}, _species)
	)
	var t := Time.get_ticks_usec()
	var tier := _stage if _stage > 0 else Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	print("START layout: ", _ms(t))
	t = Time.get_ticks_usec()
	var rampage := Rampage.new()
	rampage.staged = _staged
	rampage.setup(species, stats, layout, 0)
	print("START setup (sim): ", _ms(t))
	t = Time.get_ticks_usec()
	root.add_child(rampage)
	print("START add_child (_ready): ", _ms(t))
	var worst := 0.0
	var load_frames := 0
	var last := Time.get_ticks_usec()
	while not rampage.is_loaded:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		if (now - last) / 1000.0 > 100.0:
			print("START   load frame %d: %.0f ms" % [load_frames, (now - last) / 1000.0])
		last = now
		load_frames += 1
	print(
		(
			"START loaded: %s since add_child, %d frames, worst frame %.0f ms"
			% [_ms(t), load_frames, worst]
		)
	)
	var gaps: Array[String] = []
	for i: int in _frames:
		t = Time.get_ticks_usec()
		await process_frame
		var gap := (Time.get_ticks_usec() - t) / 1000.0
		if gap > 20.0:
			gaps.append("f%d %.0f ms" % [i, gap])
	print("START frames over 20 ms: ", gaps)
	if _play > 0.0:
		rampage.set_autoplay(true)
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < _play * 1000.0 and not rampage.sim.over:
			await process_frame
		print("PLAYED %.0f s, chunks destroyed %d" % [_play, rampage.sim.chunks_destroyed])
	if _quit:
		print("QUIT at unix %.3f" % Time.get_unix_time_from_system())
		QuitGame.now(self)
		return
	rampage.sim.over = true
	t = Time.get_ticks_usec()
	rampage.queue_free()
	await process_frame
	print("TEARDOWN free + 1 frame: ", _ms(t))
	t = Time.get_ticks_usec()
	await process_frame
	print("TEARDOWN next frame: ", _ms(t))
	quit()
