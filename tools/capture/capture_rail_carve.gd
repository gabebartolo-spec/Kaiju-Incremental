extends SceneTree
## The croc walks into the viaduct and on into the station, carving both (D-247; the director
## 2026-10-26 "carve is a universal feature for all buildings"): it starts east of the line just
## north of the station and walks south-west with real input, through the narrow viaduct and
## into the station's platforms, in the game camera with the controls panel dismissed. Stills
## 01_before, 02_through, 03_after; with --clip no stills (use with --write-movie, ~6 s at 60 fps).
## Local GPU, 4K, off-screen no_focus override.cfg in the project:
##   godot --path . --resolution 3840x2160 --write-movie <dir>/clip.avi --fixed-fps 60 \
##     --script tools/capture/capture_rail_carve.gd -- --out=<dir> --clip

const DAY_RUN := 0
## Where it starts: this far east of the line's centre, this far north of the station's start.
const EAST := 7.0
const NORTH := 3.0
const SETTLE := 60
const WALK_FRAMES := 270
const AFTER := 90

var _out := "user://rail_carve"
var _clip := false
var _rampage: Rampage


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
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
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	var huds := _rampage.find_children("*", "RampageHud", true, false)
	if not huds.is_empty():
		(huds[0] as RampageHud).dismiss_controls()
	var rail := _rampage.sim.rail
	var station := RailLayout.station_z(_rampage.sim.city, rail.cfg)
	_rampage.sim.kaiju_pos = Vector2(rail.centre_x() + EAST, station.x - NORTH)
	_rampage.sim.facing = Vector2(-1, 1).normalized()
	_rampage.sim.body.heading = _rampage.sim.facing
	await _frames(SETTLE)
	_shot("01_before")
	print("CLIP_FROM %d" % Engine.get_frames_drawn())
	Input.action_press("move_left")
	Input.action_press("move_down")
	for i: int in WALK_FRAMES:
		await process_frame
		if i == WALK_FRAMES / 2:
			_shot("02_through")
	Input.action_release("move_left")
	Input.action_release("move_down")
	await _frames(AFTER)
	_shot("03_after")
	print("CLIP_TO %d" % Engine.get_frames_drawn())
	var carved := 0
	var station_cells := 0
	for n: int in rail.pieces:
		var f := _rampage.sim.carving.frame(n)
		if f == null:
			continue
		var full: Dictionary = RailLayout.laid(_rampage.sim.buildings[n], rail.cfg, f.res)[0]
		carved += full.size() - f.alive_count
		var st: Array = _rampage.sim.buildings[n].rail["station"]
		station_cells += full.size() - f.alive_count if not st.is_empty() else 0
	print(
		(
			"RAIL_CARVE cells_gone=%d station_cells_gone=%d breaks=%d station=%s kaiju=%s"
			% [
				carved,
				station_cells,
				rail.broken().size(),
				rail.station_standing,
				_rampage.sim.kaiju_pos
			]
		)
	)
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
