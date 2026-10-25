extends SceneTree
## The kaiju walks into the railway and carves it (D-247 "pillars, deck and station break when
## the kaiju walks through"): it starts beside the viaduct a little north of the station and
## walks west through it with real input; the bays under it fall away. Stills 01_before,
## 02_through, 03_after; with --clip no stills (use with --write-movie, ~6 s). Local GPU,
## off-screen no_focus override.cfg:
##   godot --path . --resolution 1920x1080 --windowed --write-movie <dir>/clip.avi \
##     --script tools/capture/capture_rail_carve.gd -- --out=<dir> --clip

const DAY_RUN := 0
const BESIDE := 5.0
const NORTH_OF_STATION := 9.0
const WALK_FRAMES := 240
const AFTER := 90

var _out := "user://rail_carve"
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
	_rampage.sim.kaiju_pos = Vector2(rail.centre_x() + BESIDE, station.y - NORTH_OF_STATION)
	await _frames(90)
	_shot("01_before")
	print("CLIP_FROM %d" % Engine.get_frames_drawn())
	Input.action_press("move_left")
	for i: int in WALK_FRAMES:
		await process_frame
		if i == WALK_FRAMES / 2:
			_shot("02_through")
		if _rampage.sim.kaiju_pos.x < rail.centre_x() - BESIDE - 2.0:
			break
	Input.action_release("move_left")
	await _frames(AFTER)
	_shot("03_after")
	print("CLIP_TO %d" % Engine.get_frames_drawn())
	var gone := 0
	for i: int in rail.bay_hp.size():
		gone += int(not rail.bay_standing(i))
	print("RAIL_CARVE bays_gone=%d of %d station=%s" % [gone, rail.bay_hp.size(), rail.station_standing])
	quit(0)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	if _clip:
		return
	var path := _out.path_join("%s.png" % shot_name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("still %s" % path)
