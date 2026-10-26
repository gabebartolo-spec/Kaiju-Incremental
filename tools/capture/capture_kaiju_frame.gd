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

const Kit := preload("res://tools/capture/capture_kit.gd")

var _species := "reptilian"
var _out := "user://kaiju_frame"


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"species": _species, "out": _out})
	_species = str(a["species"])
	_out = str(a["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var stats := Kit.stats(_species)
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Kit.autoplay(self, _species, stats, 0, layout)
	await Kit.ticks(self, PLAY_FRAMES)
	paused = true
	await Kit.frames(self, SETTLE_FRAMES)
	Kit.measure_on(self)
	var ms := await Kit.render_ms(self, TIME_FRAMES)
	print(
		(
			"KAIJU_FRAME %s gpu %.2f ms cpu %.2f ms avg over %d frames"
			% [_species, ms[0], ms[1], TIME_FRAMES]
		)
	)
	var shot := root.get_texture().get_image()
	shot.save_png(_out.path_join("game.png"))
	var kaiju := rampage.find_children("*", "KaijuModel", true, false)
	if not kaiju.is_empty():
		var size := Vector2(shot.get_size())
		var at := (kaiju[0] as Node3D).global_position + Vector3(0, 3, 0)
		var px := Kit.image_point(self, root.get_camera_3d(), at, size)
		var crop := Vector2i(Vector2(CROP) * size.y / 1080.0)
		Kit.crop_2x(shot, px, crop, _out.path_join("kaiju_2x.png"))
	quit()
