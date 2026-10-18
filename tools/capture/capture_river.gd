extends SceneTree
## The start of a run (D-083): the kaiju rises from the city's river and steps out, on the game
## camera, at a stage (1 young, 2 Behemoth). Prints the frame it emerged on. Pair with
## --write-movie for the clip. Needs a window: CI, or off-screen with the no-focus override.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 30 \
##     --write-movie <dir>/clip.avi --script tools/capture/capture_river.gd -- --stage=1

const LEVELS: Array[Dictionary] = [{"claws": 2, "hide": 2}, {"claws": 3, "evolve1": 1}]

var _stage := 1
var _seconds := 4.5


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = clampi(arg.substr(8).to_int(), 1, LEVELS.size())
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS[_stage - 1])
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0)), 0
	)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	print(
		(
			"river: stage %d, size tier %d, rises at %s"
			% [_stage, rampage.sim.size_tier(), rampage.sim.kaiju_pos]
		)
	)
	var frames := roundi(_seconds * Engine.physics_ticks_per_second)
	var emerged := -1
	for frame: int in frames:
		await physics_frame
		if emerged < 0 and not rampage.sim.emerge.active:
			emerged = frame
			print(
				(
					"river: emerged on physics frame %d (%.2f s), at %s"
					% [frame, float(frame) / Engine.physics_ticks_per_second, rampage.sim.kaiju_pos]
				)
			)
	quit()
