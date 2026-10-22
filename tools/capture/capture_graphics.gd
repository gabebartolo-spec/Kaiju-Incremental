extends SceneTree
## Every graphics preset (tuning "display" graphics, GraphicsPresets) on the same paused frame of
## a young rampage (reptilian, city seed 0, PLAY_FRAMES physics ticks): <level>.png, 2x crops of
## the kaiju (kaiju_*.png) and of a stretch of buildings (edge_*.png), and one GRAPHICS line per
## level with the GPU render time averaged over TIME_FRAMES frames. "balanced_old" is Medium with
## MSAA off (the Balanced row before the presets), for the 4K default's cost check. Run locally:
##
##   godot --fixed-fps 60 --resolution 1920x1080 --script capture_graphics.gd -- --out=<dir>
## or on CI: tools/capture/ci_capture.sh --resolution=3840x2160 capture_graphics.gd -- --out=<dir>

const PLAY_FRAMES := 300  # autoplay before the shot: the kaiju is into the city
const CROP := Vector2i(480, 270)  # crop size at 4K, shown at 2x
const EDGE_AT := Vector2(0.3, 0.3)  # the building crop's centre, as a fraction of the frame
const SETTLE_FRAMES := 20  # frames after a level change before the shot
const TIME_FRAMES := 120  # frames the GPU time is averaged over

const Kit := preload("res://tools/capture/capture_kit.gd")

var _out := "user://graphics"


func _initialize() -> void:
	_out = str(Kit.args({"out": _out})["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var stats := Kit.stats("reptilian")
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Kit.autoplay(self, "reptilian", stats, 0, layout)
	await Kit.ticks(self, PLAY_FRAMES)
	paused = true
	var cam := root.get_camera_3d()
	var kaiju := rampage.find_children("*", "Kaiju*", true, false)
	var at := Vector3.ZERO
	if not kaiju.is_empty():
		at = (kaiju[0] as Node3D).global_position
	var levels: Array[String] = []
	var table: Dictionary = Content.section("display")["graphics"]
	for level: Variant in table.keys():
		levels.append(str(level))
		if level == "medium":
			levels.append("balanced_old")
	Kit.measure_on(self)
	for level: String in levels:
		PlayerSettings.graphics = "medium" if level == "balanced_old" else level
		await Kit.frames(self, SETTLE_FRAMES)
		if level == "balanced_old":
			root.msaa_3d = Viewport.MSAA_DISABLED
			await Kit.frames(self, SETTLE_FRAMES)
		var ms := await Kit.render_ms(self, TIME_FRAMES)
		print("GRAPHICS %s gpu %.2f ms avg over %d frames" % [level, ms[0], TIME_FRAMES])
		var shot := root.get_texture().get_image()
		shot.save_png(_out.path_join(level + ".png"))
		var size := Vector2(shot.get_size())
		var px := Kit.image_point(self, cam, at + Vector3(0, 2, 0), size)
		Kit.crop_2x(shot, px, CROP, _out.path_join("kaiju_" + level + ".png"))
		Kit.crop_2x(shot, size * EDGE_AT, CROP, _out.path_join("edge_" + level + ".png"))
	print("GRAPHICS shots in %s" % _out)
	PlayerSettings.graphics = ""
	quit()
