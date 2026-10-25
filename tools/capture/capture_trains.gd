extends SceneTree
## The railway on the game camera (the director 2026-10-21 #63, #69 "Derail and smash"; 022): the
## kaiju waits beside the viaduct near the station, a train comes along, the kaiju steps onto it
## and stomps, the train derails and smashes. Stills 01_station, 02_train, 03_derail (mid
## tumble), 04_wreck; with --write-movie, the run from the train's approach to the wreck at game
## speed. Local GPU, off-screen no_focus override.cfg:
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_trains.gd -- --out=<dir>
##   godot --path . --resolution 1920x1080 --windowed --write-movie <dir>/clip.avi \
##     --script tools/capture/capture_trains.gd -- --out=<dir> --clip

const DAY_RUN := 0
## How far beside the line the kaiju waits, how close the train comes before the clip starts,
## and the frames held after the stomp for the tumble and the wreck.
const BESIDE := 3.0
const APPROACH := 26.0
const TUMBLE := 36
const WRECK := 200

var _out := "user://trains"
var _clip := false
var _rampage: Rampage


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
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	_rampage = Rampage.new()
	_rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0)), DAY_RUN
	)
	_rampage.autoplay_signature = false
	root.add_child(_rampage)
	while _rampage.sim.emerge.active:
		await physics_frame
	var rail := _rampage.sim.rail
	var station := rail.point(rail.station_s(1), 1)
	_rampage.sim.kaiju_pos = Vector2(rail.track_x(-1) + BESIDE, station.y + 13.0)
	await _frames(150)
	_shot("01_station")
	var train := await _train_near(APPROACH)
	if train == null:
		printerr("trains: no train came")
		quit(1)
		return
	print("CLIP_FROM %d" % Engine.get_frames_drawn())
	await _frames(50)
	_shot("02_train")
	await _walk_on(train)
	await _frames(TUMBLE)
	_shot("03_derail")
	await _frames(WRECK)
	_shot("04_wreck")
	print("CLIP_TO %d" % Engine.get_frames_drawn())
	print("TRAINS_CAPTURE derailed=%d -> %s" % [rail.derailed, _out])
	quit(0)


## The kaiju walks west onto the line (real input) as the train's lead car comes level, and
## stops once it stands on the track; its footfalls stomp the train.
func _walk_on(train: Rail.Train) -> void:
	var rail := _rampage.sim.rail
	for _i: int in 60 * 10:
		if absf(train.cars[0].pos.y - _rampage.sim.kaiju_pos.y) < 6.0 or train.state == Rail.WRECK:
			break
		await process_frame
	Input.action_press("move_left")
	for _i: int in 60 * 3:
		if _rampage.sim.kaiju_pos.x <= rail.track_x(train.dir) + 0.4 or train.state == Rail.WRECK:
			break
		await process_frame
	Input.action_release("move_left")


## Waits for a running train whose lead car is within `within` of the kaiju.
func _train_near(within: float) -> Rail.Train:
	for _i: int in 60 * 90:
		for train: Rail.Train in _rampage.sim.rail.trains:
			var near := train.cars[0].pos.distance_to(_rampage.sim.kaiju_pos) < within
			if train.state == Rail.RUN and near:
				return train
		await process_frame
	return null


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	if _clip:
		return
	var path := _out.path_join("%s.png" % shot_name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("still %s" % path)
