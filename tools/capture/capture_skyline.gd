extends SceneTree
## The far skyline rampage prototype (SkylineRampage, director 2026-10-21 comments #16) at the
## game camera: a young reptilian run autoplays into the city, then a still with the effect on
## (<time>_on.png) and a 2x crop round the far kaiju (<time>_beast_2x.png); --off: the same
## run and frame with the flag off (<time>_off.png). --perf: GPU/CPU frame time off then on.
## --clip: plays CLIP_FRAMES after the warm-up (record with --write-movie --fixed-fps 60).
## --stand=x,z: the kaiju stands there (the far shore shows only from the city's north half);
## --wide: a level telephoto at the north edge, to judge the far kaiju; --at=<s>: that moment.
## Needs a window.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_skyline.gd -- --out=<dir> --time=dusk [--off] [--perf]

const PLAY_FRAMES := 420  # the kaiju rises from the river and walks into the city
const CLIP_FRAMES := 600  # 10 s at 60 fps
const PERF_FRAMES := 120
const SETTLE_FRAMES := 90
const WIDE_AT := Vector3(0, 30, -60)
const WIDE_FOV := 14.0  # the clip's side-on telephoto: the beast fills about half the frame
const SAMPLE_STEP := 14.0  # --measure: seconds between the far rampage moments sampled
const SAMPLE_SPAN := 420.0  # about one full pace of the far shore
const SEEN_SHARE := 0.5  # a moment counts as seen when this share of its silhouette shows
const MIN_PIXELS := 150  # fewer magenta pixels than this and the beast is off screen
const CROP := Vector2i(480, 270)
const TIMES := {"dusk": 0, "night": 1, "morning": 2, "noon": 3}  # Content.time_for_run order

var _out := "user://skyline"
var _time := "dusk"
var _off := false
var _perf := false
var _clip := false
var _at := -1.0  # --at=<s>: jump the far rampage to this moment before the still
var _depths: Array[Vector2] = []  # --measure=depth:height,...: the far beast's placements to sweep
var _box := Rect2i()
var _wide := false  # --wide: a level camera at the north edge, for judging the far kaiju itself
var _stand := Vector2.INF  # --stand=x,z: the kaiju stands here for the shot (e.g. the north edge)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
		elif arg.begins_with("--at="):
			_at = float(arg.substr(5))
		elif arg.begins_with("--stand="):
			var xz := arg.substr(8).split(",")
			_stand = Vector2(float(xz[0]), float(xz[1]))
		elif arg.begins_with("--measure="):
			for d: String in arg.substr(10).split(","):
				var pair := d.split(":")
				_depths.append(Vector2(float(pair[0]), float(pair[1])))
		elif arg == "--wide":
			_wide = true
		elif arg == "--off":
			_off = true
		elif arg == "--perf":
			_perf = true
		elif arg == "--clip":
			_clip = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var cfg := Content.section("skyline_rampage")
	if not _depths.is_empty():
		for place: Vector2 in _depths:
			cfg["on"] = true
			cfg["path_depth"] = place.x
			cfg["height"] = place.y
			var rampage := await _start()
			await _sweep(rampage, place)
			rampage.queue_free()
			await process_frame
			await process_frame
		quit()
		return
	if _perf:
		for on: bool in [false, true]:
			cfg["on"] = on
			var rampage := await _start()
			print("SKYLINE perf %s %s" % ["on" if on else "off", await _measure()])
			rampage.queue_free()
			await process_frame
		quit()
		return
	if _off:  # the same run and frame with the flag off, as shipped today
		cfg["on"] = false
		await _start()
		await process_frame
		root.get_texture().get_image().save_png(_out.path_join(_time + "_off.png"))
		quit()
		return
	cfg["on"] = true
	var rampage := await _start()
	var far: SkylineRampage = rampage.find_children("*", "SkylineRampage", true, false)[0]
	if _at >= 0.0:
		far.jump_to(_at)
	_hide_card(rampage)
	if _clip:  # the game camera, then the side-on telephoto; the movie starts at frame 0
		print("SKYLINE clip game starts at frame %d" % Engine.get_frames_drawn())
		for _i: int in CLIP_FRAMES:
			await process_frame
		var lens := _wide_lens(far)
		rampage.process_mode = Node.PROCESS_MODE_DISABLED
		far.process_mode = Node.PROCESS_MODE_ALWAYS
		lens.current = true
		await process_frame
		print("SKYLINE clip side starts at frame %d" % Engine.get_frames_drawn())
		for _i: int in CLIP_FRAMES:
			await process_frame
		print("SKYLINE clip done, fallen %d" % far.fallen())
		quit()
		return
	var cam := root.get_camera_3d()
	if _wide:
		var lens := _wide_lens(far)
		lens.current = true
		cam = lens
		rampage.process_mode = Node.PROCESS_MODE_DISABLED  # the game camera keeps still
		far.process_mode = Node.PROCESS_MODE_ALWAYS
	await process_frame
	await process_frame
	var shot := root.get_texture().get_image()
	shot.save_png(_out.path_join(_time + ("_wide.png" if _wide else "_on.png")))
	var mid := far.beast_at() + Vector3(0, Num.f(cfg["height"]) * 0.5, 0)
	var px := cam.unproject_position(mid) * Vector2(shot.get_size()) / root.get_visible_rect().size
	_crop(shot, px, _time + "_beast_2x")
	print("SKYLINE %s t=%.1f fallen %d beast_px %s" % [_time, far.elapsed, far.fallen(), px])
	quit()


## A level telephoto at the north edge aimed at the beast's feet-to-head middle, side-on.
func _wide_lens(far: SkylineRampage) -> Camera3D:
	var lens := Camera3D.new()
	lens.fov = WIDE_FOV
	root.add_child(lens)
	lens.position = WIDE_AT
	var mid := (
		far.beast_at() + Vector3(0, Num.f(Content.section("skyline_rampage")["height"]) * 0.5, 0)
	)
	lens.look_at(Vector3(mid.x, mid.y, mid.z))
	return lens


func _hide_card(rampage: Rampage) -> void:
	for card: Node in rampage.find_children("*", "ControlsCard", true, false):
		(card as Control).visible = false


## How much of the beast's silhouette shows from the game camera at moments along its whole
## pace: the frame with the beast drawn flat magenta, against the same frame with every
## other thing in the city hidden (what it would show unhidden).
func _sweep(rampage: Rampage, place: Vector2) -> void:
	_hide_card(rampage)
	var far: SkylineRampage = rampage.find_children("*", "SkylineRampage", true, false)[0]
	var beast: FarBeast = far.find_children("*", "FarBeast", false, false)[0]
	var city: Node = far.get_parent()
	beast.set_probe(true)
	var seen := 0
	var total := 0
	var shares: Array[float] = []
	var t := 0.0
	while t < SAMPLE_SPAN:
		far.jump_to(t)
		await process_frame
		await process_frame
		var shot := root.get_texture().get_image()
		var shown := _magenta(shot)
		if t == 0.0:
			shot.save_png(_out.path_join("shown_%d.png" % roundi(place.x)))
		var hidden: Array[Node3D] = []
		for child: Node in city.get_children():
			if child != far and child is Node3D and (child as Node3D).visible:
				hidden.append(child)
				(child as Node3D).visible = false
		await process_frame
		var whole := _magenta(root.get_texture().get_image())
		var size := root.get_visible_rect().size
		var edge := (
			_box.position.y < 6
			or _box.position.x < 6
			or _box.end.x > size.x - 6
			or _box.end.y > size.y - 6
		)
		for child: Node3D in hidden:
			child.visible = true
		if t == 0.0:
			root.get_texture().get_image().save_png(
				_out.path_join("probe_%d.png" % roundi(place.x))
			)
		print("SKYLINE probe t=%.0f shown %d whole %d box %s" % [t, shown, whole, _box])
		var share := float(shown) / float(whole) if whole >= MIN_PIXELS and not edge else 0.0
		shares.append(share)
		total += 1
		seen += 1 if share >= SEEN_SHARE else 0
		t += SAMPLE_STEP
	var line := ""
	for share: float in shares:
		line += "%d " % roundi(share * 100.0)
	print(
		(
			"SKYLINE sweep depth %.0f height %.0f: %d of %d moments >= %d%% seen | %s"
			% [place.x, place.y, seen, total, roundi(SEEN_SHARE * 100.0), line]
		)
	)


## Magenta pixels (the probe, after tonemapping: pink) counted at half resolution; _box is their
## bounding box, so a beast cut off by the screen's edge can be told from one that is whole.
func _magenta(shot: Image) -> int:
	var n := 0
	var size := shot.get_size()
	_box = Rect2i(size, Vector2i.ZERO)
	for y: int in range(0, size.y, 2):
		for x: int in range(0, size.x, 2):
			var c := shot.get_pixel(x, y)
			var low := minf(c.r, c.b)
			if low > 0.6 and c.g < 0.7 * low:
				n += 1
				_box = _box.expand(Vector2i(x, y))
	return n


func _pink(c: Color) -> bool:
	return c.r > 0.75 and c.b > 0.7 and absf(c.r - c.b) < 0.15 and c.g > 0.3 and c.g < 0.6


func _start() -> Rampage:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, Num.i(TIMES.get(_time, 0)))
	root.add_child(rampage)
	rampage.set_autoplay(true)
	for _i: int in PLAY_FRAMES:
		await process_frame
	if _stand != Vector2.INF:
		rampage.set_autoplay(false)
		rampage.sim.kaiju_pos = _stand
		for _i: int in SETTLE_FRAMES:  # the camera eases after it
			await process_frame
	return rampage


## Render time of the frame: the screen plus every SubViewport (the far kaiju's little world),
## and the main loop's process time.
func _measure() -> String:
	var views: Array[RID] = [root.get_viewport_rid()]
	for node: Node in root.find_children("*", "SubViewport", true, false):
		views.append((node as SubViewport).get_viewport_rid())
	for vp: RID in views:
		RenderingServer.viewport_set_measure_render_time(vp, true)
	for _i: int in 20:
		await process_frame
	var gpu := 0.0
	var cpu := 0.0
	var process := 0.0
	for _i: int in PERF_FRAMES:
		await process_frame
		for vp: RID in views:
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var n := float(PERF_FRAMES)
	return (
		"render gpu %.2fms cpu %.2fms, process %.2fms, %d viewports"
		% [gpu / n, cpu / n, process / n, views.size()]
	)


func _crop(shot: Image, centre: Vector2, name: String) -> void:
	var size := shot.get_size()
	var corner := (Vector2i(centre) - CROP / 2).clamp(Vector2i.ZERO, size - CROP)
	var part := shot.get_region(Rect2i(corner, CROP))
	part.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
	part.save_png(_out.path_join(name + ".png"))
