extends SceneTree
## Facade pop-in probe (director 2026-10-28: "pop-in textures on the building facades", "blurry
## turns sharp"). A real rampage on the game camera (city seed 0, reptilian, dusk) walking a
## recorded route (capture_one_look.gd --route=record), logging per frame what a facade goes
## through as the kaiju nears it, so the cause is a number, not a look:
##   frames.csv  one line a frame: frame, kaiju-to-camera depth D, the far blur's start
##               (D * far_blur_start) and full-blur depth, the buildings meshed, the last cutoff.
##   swaps.csv   every stand-in <-> meshed building swap that is on screen: frame, building,
##               up (1 = box became the real building), nearest-face depth, depth / blur start,
##               blur share there (0 sharp .. 1 full), projected height in px, building height.
##   sharp.csv   up to SHARP_MAX buildings on screen near the blur's start: frame, building,
##               depth, blur share, meshed, sharpness (mean luma gradient of a SHARP_PX crop).
## The same run with --set=far_blur_amount=0 is the "blur off" arm; the route and the seed are the
## same, so a building's two series line up frame for frame (analysis: facade_popin_stats.py).
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_facade_popin.gd -- --route-file=<route.json> --out=<dir> \
##     [--seconds=40] [--time=dusk] [--set=far_blur_amount=0] [--graphics=medium]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SHARP_MAX := 6
const SHARP_PX := 40
const MIN_PX := 56.0  # a facade this tall and wide on screen is tracked for sharpness
const FPS := 60.0
const LIT_LUMA := 0.45  # a pixel brighter than this reads as a lit window

var _seconds := 40.0
var _out := "user://facade_popin"
var _time := "dusk"
var _graphics := "medium"
var _stage := 2
var _route_file := ""
var _sets: Dictionary = {}
var _route: Array = []
var _steps := 0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
		elif arg.begins_with("--graphics="):
			_graphics = arg.substr(11)
		elif arg.begins_with("--stage="):
			_stage = int(arg.substr(8))
		elif arg.begins_with("--route-file="):
			_route_file = arg.substr(13)
		elif arg.begins_with("--set="):
			for pair: String in arg.substr(6).split(","):
				var kv := pair.split("=")
				_sets[kv[0]] = float(kv[1]) if kv[1].is_valid_float() else kv[1]
		elif arg == "--calm":
			PlayerSettings.camera_motion = 0.0
	PlayerSettings.camera_motion = 0.0  # a pair frames the same way
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	PlayerSettings.graphics = _graphics
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[_stage - 1], "reptilian")
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(Content.species_def("reptilian"), stats, layout, 0)
	Content.set_time(_time)
	var look := Content.look()
	for key: String in _sets:
		look[key] = _sets[key]
	var blur_start: float = Look.value("far_blur_start")
	var blur_ramp: float = Look.value("far_blur_ramp")
	root.add_child(rampage)
	rampage.set_physics_process(false)
	var city: CityView = rampage.get("_city")
	var stream: BuildingStream = city.get("_stream")
	while not stream.complete():
		await process_frame
	for _i: int in 10:
		await process_frame
	rampage.set_physics_process(true)
	for child: Node in rampage.get_children():
		if child is BreathAim:
			child.set_physics_process(false)
			child.set_process(false)
			(child as BreathAim).visible = false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_route_file))
	if not parsed is Array:
		push_error("FPOP no route at %s" % _route_file)
		quit(1)
		return
	_route = parsed
	rampage.scripted = _scripted
	while rampage.sim.emerge.active:
		await physics_frame
	var frames_csv := FileAccess.open(_out.path_join("frames.csv"), FileAccess.WRITE)
	var swaps_csv := FileAccess.open(_out.path_join("swaps.csv"), FileAccess.WRITE)
	var sharp_csv := FileAccess.open(_out.path_join("sharp.csv"), FileAccess.WRITE)
	frames_csv.store_line("frame,D,blur_start,blur_full,meshed,cutoff,blur_amount")
	swaps_csv.store_line("frame,n,up,depth,ratio,blur,px_h,height,landmark,waited,wanted")
	sharp_csv.store_line("frame,n,depth,blur,meshed,sharp")
	var blur_amount: float = Look.value("far_blur_amount")
	var sim := rampage.sim
	var was := PackedByteArray()
	was.resize(sim.buildings.size())
	for n: int in was.size():
		was[n] = 1 if stream.built(n) != null else 0
	var waited := PackedInt32Array()  # frames a box stood in view (a facade this big)
	waited.resize(sim.buildings.size())
	# ...of those, the frames its stream rank was inside the cutoff (wanted meshed)
	var wanted := PackedInt32Array()
	wanted.resize(sim.buildings.size())
	var cutoff: float = stream.get("_cutoff")
	var rank: StreamRank = stream.get("_rank")
	var look_csv := FileAccess.open(_out.path_join("swap_look.csv"), FileAccess.WRITE)
	look_csv.store_line("frame,n,up,depth,px_h,luma_before,luma_after,lit_before,lit_after,diff")
	var prev_shot: Image = null
	var cam := root.get_viewport().get_camera_3d()
	var rect := root.get_visible_rect()
	for f: int in roundi(_seconds * FPS):
		await process_frame
		if sim.over:
			break
		var at: Vector3 = rampage.get("_kaiju_at")
		var fwd := -cam.global_transform.basis.z
		var depth_k := (at - cam.global_position).dot(fwd)
		var start := depth_k * blur_start
		var full := depth_k * (blur_start + blur_ramp)
		var meshed := 0
		cutoff = stream.get("_cutoff")
		var shot: Image = null
		var pending: Array[Array] = []  # [n, up, depth, px height, box] of a swap this frame
		# [distance of the depth from the blur start, n, depth, blur, px rect]
		var cands: Array[Array] = []
		for n: int in sim.buildings.size():
			var b := sim.buildings[n]
			if b.is_rail():
				continue
			var up := 1 if stream.built(n) != null else 0
			meshed += up
			var near := _near_depth(b, cam, fwd)
			var box := _screen_box(b, cam)
			var in_view := box.size.x > 1.0 and box.size.y > 1.0 and rect.intersects(box)
			var blur := _blur_share(near, start, full - start) * (1.0 if blur_amount > 0.0 else 0.0)
			if up != was[n]:
				if in_view:
					swaps_csv.store_line(
						(
							"%d,%d,%d,%.1f,%.2f,%.2f,%d,%d,%d,%d,%d"
							% [
								f,
								n,
								up,
								near,
								near / maxf(start, 0.1),
								blur,
								box.size.y,
								b.height,
								1 if b.landmark != "" else 0,
								waited[n],
								wanted[n]
							]
						)
					)
				if in_view and box.size.x >= MIN_PX and box.size.y >= MIN_PX:
					pending.append([n, up, near, box.size.y, box])
				if up == 1:
					waited[n] = 0
					wanted[n] = 0
				was[n] = up
			if up == 0 and in_view and box.size.x >= MIN_PX and box.size.y >= MIN_PX:
				waited[n] += 1
				wanted[n] += 1 if rank.rank(n, sim.kaiju_pos) < cutoff else 0
			if in_view and box.size.x >= MIN_PX and box.size.y >= MIN_PX and near > 0.0:
				var share_probe := _blur_share(near, start, full - start)
				if near > start * 0.45 and near < full * 1.3:
					cands.append([absf(near - start), n, near, blur, box, up, share_probe])
		frames_csv.store_line(
			(
				"%d,%.1f,%.1f,%.1f,%d,%.1f,%.3f"
				% [f, depth_k, start, full, meshed, stream.get("_cutoff"), blur_amount]
			)
		)
		if shot == null and (not cands.is_empty() or not pending.is_empty()):
			shot = root.get_viewport().get_texture().get_image()
		if not pending.is_empty() and prev_shot != null:
			for c: Array in pending:
				var box: Rect2 = c[4]
				var before := _crop_stats(prev_shot, box, rect)
				var after := _crop_stats(shot, box, rect)
				look_csv.store_line(
					(
						"%d,%d,%d,%.1f,%d,%.3f,%.3f,%.3f,%.3f,%.3f"
						% [
							f,
							c[0],
							c[1],
							c[2],
							c[3],
							before[0],
							after[0],
							before[1],
							after[1],
							_crop_diff(prev_shot, shot, box, rect)
						]
					)
				)
		prev_shot = shot
		if not cands.is_empty():
			cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			for k: int in mini(SHARP_MAX, cands.size()):
				var c := cands[k]
				var box: Rect2 = c[4]
				sharp_csv.store_line(
					(
						"%d,%d,%.1f,%.2f,%d,%.3f"
						% [f, c[1], c[2], c[3], c[5], _sharpness(shot, box, rect)]
					)
				)
	frames_csv.close()
	swaps_csv.close()
	sharp_csv.close()
	look_csv.close()
	print("FPOP done, %s" % _out)
	quit()


## The DoF's blur share at `depth`: 0 before its start, 1 once the ramp is over.
func _blur_share(depth: float, start: float, ramp: float) -> float:
	return clampf((depth - start) / maxf(ramp, 0.001), 0.0, 1.0)


## Depth along the view of the building's nearest top or base corner in front of the camera.
func _near_depth(b: RampageSim.Building, cam: Camera3D, fwd: Vector3) -> float:
	var best := INF
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			var corner := Vector3(b.x + sx * b.w, 0.0, b.z + sz * b.d)
			best = minf(best, (corner - cam.global_position).dot(fwd))
	return best


## The building's box on screen (zero size when it is behind the camera).
func _screen_box(b: RampageSim.Building, cam: Camera3D) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			for y: float in [0.0, float(b.height)]:
				var p := Vector3(b.x + sx * b.w, y, b.z + sz * b.d)
				if cam.is_position_behind(p):
					return Rect2()
				var s := cam.unproject_position(p)
				lo = lo.min(s)
				hi = hi.max(s)
	return Rect2(lo, hi - lo)


## The SHARP_PX crop at the middle of `box` as [mean luma, share of pixels brighter than LIT_LUMA].
func _crop_stats(shot: Image, box: Rect2, rect: Rect2) -> Array[float]:
	var corner := _crop_corner(shot, box, rect)
	var sum := 0.0
	var lit := 0.0
	for y: int in SHARP_PX:
		for x: int in SHARP_PX:
			var c := shot.get_pixel(corner.x + x, corner.y + y).get_luminance()
			sum += c
			lit += 1.0 if c > LIT_LUMA else 0.0
	var n := float(SHARP_PX * SHARP_PX)
	return [sum / n, lit / n]


## Mean absolute luma difference between the same crop in two frames (the size of the pop).
func _crop_diff(a: Image, b: Image, box: Rect2, rect: Rect2) -> float:
	var corner := _crop_corner(a, box, rect)
	var sum := 0.0
	for y: int in SHARP_PX:
		for x: int in SHARP_PX:
			var pa := a.get_pixel(corner.x + x, corner.y + y).get_luminance()
			sum += absf(pa - b.get_pixel(corner.x + x, corner.y + y).get_luminance())
	return sum / float(SHARP_PX * SHARP_PX)


func _crop_corner(shot: Image, box: Rect2, rect: Rect2) -> Vector2i:
	var scale := Vector2(shot.get_size()) / rect.size
	var inner := box.intersection(rect)
	var centre := (inner.position + inner.size * 0.5) * scale
	return (Vector2i(centre) - Vector2i(SHARP_PX, SHARP_PX) / 2).clamp(
		Vector2i.ZERO, shot.get_size() - Vector2i(SHARP_PX + 1, SHARP_PX + 1)
	)


## Mean luma gradient of a SHARP_PX crop at the middle of `box` (kept inside the screen), on the
## drawn frame `shot` (the screen is the viewport's size; the image may be scaled).
func _sharpness(shot: Image, box: Rect2, rect: Rect2) -> float:
	var scale := Vector2(shot.get_size()) / rect.size
	var inner := box.intersection(rect)
	var centre := (inner.position + inner.size * 0.5) * scale
	var corner := (Vector2i(centre) - Vector2i(SHARP_PX, SHARP_PX) / 2).clamp(
		Vector2i.ZERO, shot.get_size() - Vector2i(SHARP_PX + 1, SHARP_PX + 1)
	)
	var sum := 0.0
	for y: int in SHARP_PX:
		for x: int in SHARP_PX:
			var c := shot.get_pixel(corner.x + x, corner.y + y).get_luminance()
			sum += absf(c - shot.get_pixel(corner.x + x + 1, corner.y + y).get_luminance())
			sum += absf(c - shot.get_pixel(corner.x + x, corner.y + y + 1).get_luminance())
	return sum / float(SHARP_PX * SHARP_PX * 2)


## capture_one_look.gd's replay: the recorded input of each step.
func _scripted(p_sim: RampageSim) -> Dictionary:
	if p_sim.emerge.active:
		return {}
	var at: Array = _route[mini(_steps, _route.size() - 1)]
	_steps += 1
	return {
		"move": Vector2(Num.f(at[0]), Num.f(at[1])),
		"signature": Num.f(at[2]) > 0.5,
		"held": Num.f(at[3]) > 0.5,
		"ultimate": Num.f(at[4]) > 0.5,
	}
