extends SceneTree
## The stadium's matches (D-078) at the game camera, in city 1 with a young kaiju just off the
## stadium's south-south-east wall (its contact with the wall in sight of the game camera): a
## still of each sport in play (afl.png, nfl.png, soccer.png, cricket.png), or with --clip an AFL
## match where the kaiju walks into the wall and every player runs, with a same-seed
## before/after pair (pair with --write-movie: ci_capture.sh --movie).
## --frametime instead times the AFL match's frames with the stadium's crowd off, then on.
## Needs a window and the no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_matches.gd -- --out=<dir> [--clip | --frametime]

const GuiInput := preload("res://tests/lib/gui_input.gd")
const SPORTS: Array[String] = ["afl", "nfl", "soccer", "cricket"]
const PLAY_FRAMES := 150  # frames of play before a still: the ball has been kicked about
## Clip lengths in physics frames (60 a second): play, then the kaiju walks into the wall.
const CLIP_PLAY := 90
const CLIP_FRAMES := 360
## The clip's same-seed pair: afl_before as the kaiju sets off, afl_after this long after the
## stadium's first chunk goes (players running for the tunnels).
const AFTER_FLEE := 60
## The kaiju comes in from the south-south-east (clear of the corner masts), starting KERB out
## from the wall's outer face.
const APPROACH := Vector2(0.48, 0.88)
const KERB := 3.5
const TIMED := 300  # --frametime: frames timed per run, after PLAY_FRAMES to settle

var _out := "user://matches"
var _clip := false
var _timed := false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--clip":
			_clip = true
		elif arg == "--frametime":
			_timed = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _timed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		for crowd: bool in [false, true]:
			StadiumCrowd.enabled = crowd
			await _time(crowd)
		StadiumCrowd.enabled = true
	elif _clip:
		await _match("afl", true)
	else:
		for id: String in SPORTS:
			await _match(id, false)
	quit()


## One rampage in city 1 playing `id`; a still after some play, or the clip of the wall going.
func _match(id: String, clip: bool) -> void:
	var walk := {"go": false}
	var rampage := _rampage(id, walk if clip else {})
	var game: StadiumMatch = GuiInput.find_script(rampage, StadiumMatch)
	var crowd: StadiumCrowd = GuiInput.find_script(rampage, StadiumCrowd)
	var start := game.on_pitch()
	var fled_at := -1
	for i: int in CLIP_FRAMES if clip else PLAY_FRAMES:
		await physics_frame
		walk["go"] = clip and i >= CLIP_PLAY
		if clip and i == CLIP_PLAY:
			_shot("afl_before")
		if game.fleeing and fled_at < 0:
			fled_at = i
		if clip and fled_at >= 0 and i == fled_at + AFTER_FLEE:
			_shot("afl_after")
	if not clip:
		_shot(id)
	print(
		(
			"%s: %d players, %d kicks; fled at frame %d, %d out, %d crushed, %d on the pitch"
			% [id, start, game.kicks, fled_at, game.escaped, game.killed, game.on_pitch()]
		)
	)
	print(
		(
			"crowd: %d seated at the start, %d out, %d fell with the seats, %d crushed, %d left"
			% [crowd.fans.size(), crowd.escaped, crowd.fallen, crowd.killed, crowd.in_stands()]
		)
	)
	StadiumMatch.force_sport = ""
	rampage.queue_free()
	await process_frame
	await process_frame


## The AFL match in play, timed: mean frame time, and the CPU and GPU render times.
func _time(crowd: bool) -> void:
	var rampage := _rampage("afl", {"go": false})
	for _i: int in PLAY_FRAMES:
		await process_frame
	var rid := root.get_viewport_rid()
	var sums := Vector3.ZERO
	var started := Time.get_ticks_usec()
	for _i: int in TIMED:
		await process_frame
		sums += Vector3(
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(rid),
			RenderingServer.viewport_get_measured_render_time_gpu(rid)
		)
	var frame := (Time.get_ticks_usec() - started) / 1000.0 / TIMED
	sums /= TIMED
	print(
		(
			"frametime crowd %s: frame %.2f ms, process %.2f ms, render cpu %.2f ms, gpu %.2f ms"
			% ["on" if crowd else "off", frame, sums.x, sums.y, sums.z]
		)
	)
	StadiumMatch.force_sport = ""
	rampage.queue_free()
	await process_frame
	await process_frame


## City 1 with `id` in the stadium and the kaiju off its south-south-east wall, walking in once
## walk["go"]; with no `walk` (the stills) it waits off the north wall instead, so the game
## camera looks down over the whole pitch rather than across the near rim.
func _rampage(id: String, walk: Dictionary) -> Rampage:
	StadiumMatch.force_sport = id
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	var sim := rampage.sim
	var stadium: RampageSim.Building = null
	for b: RampageSim.Building in sim.buildings:
		if b.landmark == str(Content.sports()["pitch"]["landmark"]):
			stadium = b
	var out := APPROACH.normalized() if not walk.is_empty() else Vector2(0, -1)
	var wall := out / (out / (Vector2(stadium.w, stadium.d) * 0.5)).length()
	sim.kaiju_pos = Vector2(stadium.x, stadium.z) + wall + out * KERB
	sim.facing = -out
	rampage.scripted = func(s: RampageSim) -> Dictionary:
		if not walk.get("go", false):
			return {"move": Vector2.ZERO}
		var to := Vector2(stadium.x, stadium.z) - s.kaiju_pos
		return {"move": to.normalized() if to.length() > 1.0 else Vector2.ZERO}
	root.add_child(rampage)
	return rampage


func _shot(shot_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
