extends SceneTree
## One mid-rampage frame at the game camera (autoplay, city seed 0, run 0, PLAY_FRAMES physics
## ticks, then paused) saved as <out>/game.png with a 2x crop round the kaiju (kaiju_2x.png), and
## one KAIJU_FRAME line: the GPU and CPU render time averaged over TIME_FRAMES frames of that frame.
## For before/after checks of a kaiju asset change (D-107 double voxels). Needs a window:
##
##   godot --path . --windowed --fixed-fps 60 --resolution 3840x2160 \
##     --script tools/capture/capture_kaiju_frame.gd -- --species=reptilian --out=<dir>

const PLAY_FRAMES := 600  # 10 s of autoplay: the kaiju is among buildings, mid-rampage
const SETTLE_FRAMES := 20
const TIME_FRAMES := 240
const CROP := Vector2i(480, 270)  # at 1080p; scaled with the frame

var _species := "reptilian"
var _out := "user://kaiju_frame"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def(_species)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	root.add_child(rampage)
	rampage.set_autoplay(true)
	for _i: int in PLAY_FRAMES:
		await physics_frame
	paused = true
	for _i: int in SETTLE_FRAMES:
		await process_frame
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var gpu := 0.0
	var cpu := 0.0
	for _i: int in TIME_FRAMES:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	print(
		(
			"KAIJU_FRAME %s gpu %.2f ms cpu %.2f ms avg over %d frames"
			% [_species, gpu / TIME_FRAMES, cpu / TIME_FRAMES, TIME_FRAMES]
		)
	)
	var shot := root.get_texture().get_image()
	shot.save_png(_out.path_join("game.png"))
	var kaiju := rampage.find_children("*", "KaijuModel", true, false)
	if not kaiju.is_empty():
		var cam := root.get_camera_3d()
		var size := Vector2(shot.get_size())
		var at := (kaiju[0] as Node3D).global_position + Vector3(0, 3, 0)
		var px := cam.unproject_position(at) * size / root.get_visible_rect().size
		var crop := Vector2i(Vector2(CROP) * size.y / 1080.0)
		var corner := (Vector2i(px) - crop / 2).clamp(Vector2i.ZERO, shot.get_size() - crop)
		var part := shot.get_region(Rect2i(corner, crop))
		part.resize(crop.x * 2, crop.y * 2, Image.INTERPOLATE_NEAREST)
		part.save_png(_out.path_join("kaiju_2x.png"))
	quit()
