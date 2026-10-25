extends SceneTree
## The railway on the game camera (the director 2026-10-21 #63, #69 "Derail and smash"; 2026-10-25
## on trains.mp4: "the kaiju just clips right into the building, zero carve ... it needs to be
## destroyed with the same logic as all other buildings", "Yes, all of it"): the kaiju is set on
## the clear avenue south of the station and WALKS NORTH with real input, no teleport into
## anything: his body snaps the stair, the platforms, the pillars; the spans they held drop into the
## street and a train dwelling in the station goes down with its span. Stills 01_start (before),
## 02_carving, 03_after; with --write-movie, the walk at game speed. Local GPU, off-screen
## no_focus override.cfg:
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 ##     --script tools/capture/capture_trains.gd -- --out=<dir>
##   godot --path . --resolution 3840x2160 --windowed --write-movie <dir>/clip.avi ##     --script tools/capture/capture_trains.gd -- --out=<dir> --clip

const DAY_RUN := 0
## How far south of the station's end the kaiju starts, how far north of the station he walks
## before he stops, and the frames held after he stops for the spans to fall and the dust to clear.
const START_SOUTH := 16.0
const WALK_PAST := 6.0
const AFTER := 150

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
	# Set down once on the clear avenue (no building there), facing north; everything after is input.
	_rampage.sim.kaiju_pos = Vector2(rail.avenue(), station.y + START_SOUTH)
	_rampage.sim.facing = Vector2(0, -1)
	_rampage.sim.body.heading = Vector2(0, -1)
	var train := await _train_dwelling()
	if train == null:
		printerr("trains: no train came to the station")
		quit(1)
		return
	await _frames(30)
	_shot("01_start")
	print("CLIP_FROM %d" % Engine.get_frames_drawn())
	await _walk_north(station.y - rail.station_length() - WALK_PAST, 60 * 12)
	_shot("02_carving")
	await _frames(AFTER)
	_shot("03_after")
	print("CLIP_TO %d" % Engine.get_frames_drawn())
	var down := 0
	for part: RailParts.Part in rail.parts.list:
		down += int(not part.alive)
	print("TRAINS_CAPTURE parts_down=%d derailed=%d -> %s" % [down, rail.derailed, _out])
	quit(0)


## The kaiju walks north (the move_up action held) until he is past `z` or the frames run out.
func _walk_north(z: float, frames: int) -> void:
	Input.action_press("move_up")
	for _i: int in frames:
		if _rampage.sim.kaiju_pos.y <= z:
			break
		await process_frame
	Input.action_release("move_up")


## Waits for a train to stand dwelling at the station.
func _train_dwelling() -> Rail.Train:
	for _i: int in 60 * 90:
		for train: Rail.Train in _rampage.sim.rail.trains:
			if train.state == Rail.DWELL:
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
