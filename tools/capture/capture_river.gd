extends SceneTree
## The start of a run (D-083): the kaiju rises from the city's river and steps out, on the game
## camera, at a stage (1 hatchling, 2 adolescent, 3 adult: capture_kit STAGE_LEVELS). Prints the frame it emerged on. Pair with
## --write-movie for the clip. Needs a window: CI, or off-screen with the no-focus override.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 30 \
##     --write-movie <dir>/clip.avi --script tools/capture/capture_river.gd -- --stage=1
##   ... -- --still-at=<s> --out=<dir>  (also a PNG of the frame that many seconds in; a comma list
##   such as --still-at=0.5,1.0,1.5 saves one PNG per time)
##   ... -- --side=<m>  (a close side camera that far east of the rise point, at the street,
##   looking west across the bay: the deck he bursts through and the shore he climbs)
##   ... -- --short  (the run intro's short cut, as on a run with nothing new to show; default:
##   the whole intro, as on the first run)

const Kit := preload("res://tools/capture/capture_kit.gd")

var _stage := 1
var _seconds := 4.5
var _still_at: Array[float] = []
var _out := "user://river"
var _side := 0.0
var _full := true


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = clampi(arg.substr(8).to_int(), 1, Kit.STAGE_LEVELS.size())
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg.begins_with("--still-at="):
			for at: String in arg.substr(11).split(","):
				_still_at.append(at.to_float())
		elif arg.begins_with("--side="):
			_side = arg.substr(7).to_float()
		elif arg == "--short":
			_full = false
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), Kit.STAGE_LEVELS[_stage - 1], "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	rampage.full_intro = _full
	rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0)), 0
	)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	print(
		(
			"river: stage %d, size tier %d, rises at %s"
			% [_stage, rampage.sim.size_tier(), rampage.sim.kaiju_pos]
		)
	)
	var cam: Camera3D = _side_camera(rampage.sim.kaiju_pos) if _side > 0.0 else null
	var frames := roundi(_seconds * Engine.physics_ticks_per_second)
	var emerged := -1
	var stills: Array[int] = []
	for at: float in _still_at:
		stills.append(roundi(at * Engine.physics_ticks_per_second))
	for frame: int in frames:
		await physics_frame
		if cam:
			cam.make_current()  # over the game camera, every frame
		if frame in stills:
			var at := float(frame) / Engine.physics_ticks_per_second
			var shot := _out.path_join("river_s%d_%.2fs.png" % [_stage, at])
			root.get_texture().get_image().save_png(shot)
			print("saved ", shot)
		if emerged < 0 and not rampage.sim.emerge.active:
			emerged = frame
			print(
				(
					"river: emerged on physics frame %d (%.2f s), at %s"
					% [frame, float(frame) / Engine.physics_ticks_per_second, rampage.sim.kaiju_pos]
				)
			)
	quit()


## A fixed camera _side metres east of the rise, 4 m up, looking west a little north of it.
func _side_camera(rise: Vector2) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	var aim := Vector3(rise.x, 1.0, rise.y - 4.0)
	cam.look_at_from_position(aim + Vector3(_side, 3.0, 0.0), aim, Vector3.UP)
	return cam
