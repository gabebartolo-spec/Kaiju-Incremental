extends SceneTree
## The stadium's matches (D-078) at the game camera, in city 1 with a young kaiju at the
## stadium's south kerb: a still of each sport in play (afl.png, nfl.png, soccer.png,
## cricket.png), or with --clip an AFL match where the kaiju walks into the wall and every player
## runs (pair with --write-movie: ci_capture.sh --movie). Needs a window and the no-focus
## override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_matches.gd -- --out=<dir> [--clip]

const GuiInput := preload("res://tests/lib/gui_input.gd")
const SPORTS: Array[String] = ["afl", "nfl", "soccer", "cricket"]
const PLAY_FRAMES := 150  # frames of play before a still: the ball has been kicked about
const CLIP_PLAY := 45  # clip: frames of play before the kaiju walks into the wall
const CLIP_FRAMES := 180  # clip: about 6 s at 30 fps
const KERB := 2.5  # the kaiju's start, this far south of the stadium's footprint

var _out := "user://matches"
var _clip := false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--clip":
			_clip = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _clip:
		await _match("afl", true)
	else:
		for id: String in SPORTS:
			await _match(id, false)
	quit()


## One rampage in city 1 playing `id`; a still after some play, or the clip of the wall going.
func _match(id: String, clip: bool) -> void:
	StadiumMatch.force_sport = id
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	var sim := rampage.sim
	sim.time_left = 1.0e6
	var stadium: RampageSim.Building = null
	for b: RampageSim.Building in sim.buildings:
		if b.landmark == str(Content.sports()["pitch"]["landmark"]):
			stadium = b
	sim.kaiju_pos = Vector2(stadium.x, stadium.z + stadium.d * 0.5 + KERB)
	sim.facing = Vector2(0, -1)
	var walk := {"go": false}
	rampage.scripted = func(s: RampageSim) -> Dictionary:
		if not walk["go"]:
			return {"move": Vector2.ZERO}
		var to := Vector2(stadium.x, stadium.z) - s.kaiju_pos
		return {"move": to.normalized() if to.length() > 1.0 else Vector2.ZERO}
	root.add_child(rampage)
	var game: StadiumMatch = GuiInput.find_script(rampage, StadiumMatch)
	var start := game.on_pitch()
	var fled_at := -1
	for i: int in CLIP_FRAMES if clip else PLAY_FRAMES:
		await physics_frame
		walk["go"] = clip and i >= CLIP_PLAY
		if game.fleeing and fled_at < 0:
			fled_at = i
	if not clip:
		_shot(id)
	print(
		(
			"%s: %d players, %d kicks; fled at frame %d, %d out, %d crushed, %d on the pitch"
			% [id, start, game.kicks, fled_at, game.escaped, game.killed, game.on_pitch()]
		)
	)
	StadiumMatch.force_sport = ""
	rampage.queue_free()
	await process_frame
	await process_frame


func _shot(shot_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
