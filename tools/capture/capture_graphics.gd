extends SceneTree
## Every graphics preset (tuning "display" graphics, GraphicsPresets) on the same paused frame of
## a young rampage (reptilian, city seed 0, PLAY_FRAMES physics ticks): <level>.png, 2x crops of
## the kaiju (kaiju_*.png) and of a stretch of buildings (edge_*.png), and one GRAPHICS line per
## level with the GPU render time averaged over TIME_FRAMES frames. "balanced_old" is Medium with
## MSAA off (the Balanced row before the presets), for the 4K default's cost check. Run locally:
##
##   godot --fixed-fps 60 --resolution 1920x1080 --script capture_graphics.gd -- --out=<dir>
## or on CI: tools/capture/ci_capture.sh --resolution=3840x2160 capture_graphics.gd -- --out=<dir>

const PLAY_FRAMES := 300  # autoplay before the shot: the kaiju is into the city (--play=N)
const CROP := Vector2i(480, 270)  # crop size at 4K, shown at 2x
const EDGE_AT := Vector2(0.3, 0.3)  # the building crop's centre, as a fraction of the frame
const ALIGN := 256  # frame-number multiple the settle and shots start from
const SETTLE_FRAMES := 20  # frames after a level change before the shot
const TIME_FRAMES := 120  # frames the GPU time is averaged over

var _out := "user://graphics"
var _play := PLAY_FRAMES
var _hide := false  # --hide-kaiju: the kaiju and every particle system hidden (see _hide_moving)
var _only: PackedStringArray = []  # --levels=a,b: only these presets


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--hide-kaiju":
			_hide = true
		elif arg.begins_with("--play="):
			_play = arg.substr(7).to_int()
		elif arg.begins_with("--levels="):
			_only = arg.substr(9).split(",")
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
	for _i: int in _play:
		await physics_frame
	# The buildings stream in on worker threads: a still taken before the last one lands is not
	# the same still twice (the pixel diff of a before/after pair needs it).
	for stream: Node in rampage.find_children("*", "", true, false).filter(_is_stream):
		while not (stream as BuildingStream).complete():
			await physics_frame
	# The renderer's dither (SSAO, soft shadows) and the water follow the frame number, so a
	# before/after pair needs the shot on the same frame number: start from a multiple of ALIGN.
	while Engine.get_frames_drawn() % ALIGN != 0:
		await physics_frame
	if _hide:
		_hide_moving(rampage)
	paused = true
	var cam := root.get_camera_3d()
	var kaiju := rampage.find_children("*", "Kaiju*", true, false)
	var at := Vector3.ZERO
	if not kaiju.is_empty():
		at = (kaiju[0] as Node3D).global_position
	var levels: Array[String] = []
	var table: Dictionary = Content.section("display")["graphics"]
	for level: Variant in table.keys():
		if _only.is_empty() or str(level) in _only:
			levels.append(str(level))
		if level == "medium" and _only.is_empty():
			levels.append("balanced_old")
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for level: String in levels:
		PlayerSettings.graphics = "medium" if level == "balanced_old" else level
		for _i: int in SETTLE_FRAMES:
			await process_frame
		if level == "balanced_old":
			root.msaa_3d = Viewport.MSAA_DISABLED
			for _i: int in SETTLE_FRAMES:
				await process_frame
		var total := 0.0
		for _i: int in TIME_FRAMES:
			await process_frame
			total += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		print(
			"GRAPHICS %s gpu %.2f ms avg over %d frames" % [level, total / TIME_FRAMES, TIME_FRAMES]
		)
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


## The kaiju's body and the particle systems vary from run to run (their own physics and random
## draws, not seeded by the sim), so a before/after pixel diff of the city hides them.
func _hide_moving(rampage: Rampage) -> void:
	var kaiju: Node3D = rampage._kaiju
	kaiju.visible = false
	for node: Node in rampage.find_children("*", "", true, false):
		if node is GPUParticles3D or node is CPUParticles3D:
			(node as Node3D).visible = false


func _is_stream(node: Node) -> bool:
	return node is BuildingStream


func _crop(shot: Image, centre: Vector2, name: String) -> void:
	var size := shot.get_size()
	var corner := Vector2i(centre) - CROP / 2
	corner = corner.clamp(Vector2i.ZERO, size - CROP)
	var part := shot.get_region(Rect2i(corner, CROP))
	part.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
	part.save_png(_out.path_join(name + ".png"))
