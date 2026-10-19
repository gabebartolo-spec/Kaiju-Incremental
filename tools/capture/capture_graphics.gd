extends SceneTree
## Graphics High vs Balanced (PR #92) on the same paused frame of a young rampage: high.png,
## balanced.png, and 2x crops of the kaiju (kaiju_*.png) and of a stretch of buildings
## (edge_*.png). Run at 3840x2160 on CI:
##
##   tools/capture/ci_capture.sh --renderer=gl_compatibility --resolution=3840x2160 \
##     capture_graphics.gd -- --out=<dir>

const PLAY_FRAMES := 300  # autoplay before the shot: the kaiju is into the city
const CROP := Vector2i(480, 270)  # crop size at 4K, shown at 2x
const EDGE_AT := Vector2(0.3, 0.3)  # the building crop's centre, as a fraction of the frame

var _out := "user://graphics"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
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
	var cam := root.get_camera_3d()
	var kaiju := rampage.find_children("*", "Kaiju*", true, false)
	var at := Vector3.ZERO
	if not kaiju.is_empty():
		at = (kaiju[0] as Node3D).global_position
	for level: String in ["high", "balanced"]:
		PlayerSettings.graphics = level
		for _i: int in 20:
			await process_frame
		var shot := root.get_texture().get_image()
		shot.save_png(_out.path_join(level + ".png"))
		var size := Vector2(shot.get_size())
		var px := (
			cam.unproject_position(at + Vector3(0, 2, 0)) * size / root.get_visible_rect().size
		)
		_crop(shot, px, "kaiju_" + level)
		_crop(shot, size * EDGE_AT, "edge_" + level)
	print("GRAPHICS shots in %s" % _out)
	PlayerSettings.graphics = ""
	quit()


func _crop(shot: Image, centre: Vector2, name: String) -> void:
	var size := shot.get_size()
	var corner := Vector2i(centre) - CROP / 2
	corner = corner.clamp(Vector2i.ZERO, size - CROP)
	var part := shot.get_region(Rect2i(corner, CROP))
	part.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
	part.save_png(_out.path_join(name + ".png"))
