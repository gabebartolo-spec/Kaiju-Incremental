extends SceneTree
## The run intro into a turn (D-325, D-330): the whole intro on the croc's first run, the pivot
## ending behind him, the hand-over onto the game camera, then he walks on and turns, and the
## camera swings round behind him as heavily as he turns. One clip at game speed, the game camera,
## no overlay. Local GPU, off-screen no_focus override.cfg, fixed 60 fps:
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/clip.avi \
##     --script tools/capture/capture_intro_follow.gd -- --turn=<east|west|south|north>
## The log names the drawn frames (the movie's frame index) where the run was built, where the
## kaiju broke the surface, and where the intro handed over, so the clip can be cut to the intro's
## last seconds and the turn (about 6 s: --from=<frame> --seconds=<s> of the movie).
## Seeded by design: the run's army seed, the fixed frame clock, a scripted stick.

const WALK_STEPS := 50  # steps straight ahead after the hand-over, then the turn
const PLAY_STEPS := 200  # steps of play shown after the hand-over
const FRAME_CAP := 60 * 30

var _turn := Vector2(1.0, 0.0)  # the stick the turn pushes (world: +x east, +z south)
var _steps := -1  # steps since the hand-over (-1: the rise still holds the sim)


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--turn="):
			_turn = _stick(arg.substr(7))
	_run.call_deferred()


func _stick(word: String) -> Vector2:
	match word:
		"west":
			return Vector2(-1.0, 0.0)
		"north":
			return Vector2(0.0, -1.0)
		"south":
			return Vector2(0.0, 1.0)
	return Vector2(1.0, 0.0)


## The stick at this step after the hand-over: straight ahead, then the turn.
func _move(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {"move": Vector2.ZERO}
	_steps += 1
	return {"move": Vector2(0.0, 1.0) if _steps < WALK_STEPS else _turn}


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var run := Rampage.new()
	run.full_intro = true
	run.setup(species, stats, layout, 0)
	run.autoplay_signature = false
	run.scripted = _move
	root.add_child(run)
	while not run.is_loaded and Engine.get_frames_drawn() < FRAME_CAP:
		await process_frame
	var built := Engine.get_frames_drawn()
	print("INTRO_FOLLOW run built on drawn frame %d" % built)
	var broke := false
	while (_steps < PLAY_STEPS) and Engine.get_frames_drawn() < FRAME_CAP:
		await process_frame
		if not broke and run.sim.emerge.surfaced:
			broke = true
			print("INTRO_FOLLOW surfaced on drawn frame %d" % Engine.get_frames_drawn())
		if _steps == 0:
			print("INTRO_FOLLOW handover on drawn frame %d" % Engine.get_frames_drawn())
			_steps = 1
	print(
		(
			"INTRO_FOLLOW done on drawn frame %d, facing %s, camera turned %.1f deg"
			% [
				Engine.get_frames_drawn(),
				run.sim.facing.snappedf(0.001),
				rad_to_deg(run.sim.body.view.turn)
			]
		)
	)
	quit(0)
