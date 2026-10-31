extends Node
## Overworld plan row G4 evidence: runs scenes/globe_view.tscn in a real window and quits
## (exit 0 = every check passed). Run behind the GPU slot (D-376) with the 1080p off-screen
## override.cfg:
##   godot --path . tools/overworld/marker_proof.tscn -- --out=<dir>
##   1. stills of the markers at STILL_YAWS (markers_<deg>.png);
##   2. SPIN_S seconds of live idle spin: every frame, every marker that draws (alpha at least
##      DRAWN_ALPHA; one on the very rim has faded to nothing) hit-tests to its own continent;
##   3. for each of FLY_IDS, a real click on its marker (turned FLY_OFFSET off the centre): the
##      camera arrives with the continent at the screen centre, zoomed in (fly_<id>.png), the
##      spin holds; Esc flies back out and the spin resumes (out_<id>.png);
##   4. MEASURE_S seconds of frame times on the Medium preset, vsync off (avg fps, 1% low, p99).
## Results go to <dir>/results.json.

const Kit := preload("res://tools/capture/capture_kit.gd")
const GLOBE := preload("res://scenes/globe_view.tscn")

const STILL_YAWS: Array[float] = [0.0, 90.0, 180.0, 270.0]  # degrees
const WANT_SIZE := Vector2i(1920, 1080)  # D-339: judged at 1080p
const SPIN_S := 6.0
const DRAWN_ALPHA := 1.0 / 255.0  # the faintest alpha that changes a pixel
const FLY_IDS: Array[String] = ["ostia_minor", "thule", "neptunia"]  # low, far north, islands
const FLY_OFFSET := 0.6  # rad, how far round from the centre a clicked continent starts
const SETTLE_S := 0.3  # past FLY_S before the arrival is read
const HOLD_S := 1.0  # the spin must not move the selected globe over this long
const DIST_TOLERANCE := 0.001
const YAW_TOLERANCE := 0.0001
const WARMUP_S := 2.0
const MEASURE_S := 10.0
const FPS_BAR := 60.0

var _globe: GlobeView
var _picked: Array[String] = []


func _ready() -> void:
	_globe = GLOBE.instantiate()
	add_child(_globe)
	_globe.continent_picked.connect(func(id: String) -> void: _picked.append(id))
	_run.call_deferred()


func _run() -> void:
	if not Kit.window_ok():
		get_tree().quit(2)
		return
	var out := _out_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var preset: Dictionary = Content.section("display")["graphics"]["medium"]
	GraphicsPresets.apply(preset, get_viewport())
	# Uncapped, to see the headroom: the Settings autoload puts the menu frame cap back every frame.
	get_node("/root/Settings").set_process(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _wait(WARMUP_S)

	var stills: Array[Dictionary] = []
	_globe.spin = false
	for deg: float in STILL_YAWS:
		_globe.yaw = deg_to_rad(deg)
		await _still(out.path_join("markers_%d.png" % int(deg)))
		stills.append({"yaw_deg": deg, "shown": _shown()})
	_globe.spin = true

	var attached := await _attached_test()
	var flights: Array[Dictionary] = []
	var flights_pass := true
	for id: String in FLY_IDS:
		var f := await _fly_test(id, out)
		flights.append(f)
		flights_pass = flights_pass and f["pass"]
	var fps := await _measure()
	var size := DisplayServer.window_get_size()
	var res := {
		"window": [size.x, size.y],
		"preset": "medium",
		"vsync": "disabled",
		"renderer": RenderingServer.get_video_adapter_name(),
		"fps": fps,
		"attached": attached,
		"flights": flights,
		"stills": stills,
	}
	res["pass"] = fps["pass"] and attached["pass"] and flights_pass and size == WANT_SIZE
	var f := FileAccess.open(out.path_join("results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	print("globe_g4: ", JSON.stringify(res))
	get_tree().quit(0 if res["pass"] else 1)


## Live idle spin for SPIN_S: every drawn frame, each marker that draws reads its own continent
## through the hit test at its screen point; rim_skipped counts the shown-but-faded ones.
func _attached_test() -> Dictionary:
	var frames := 0
	var checked := 0
	var rim := 0
	var misses: Array[String] = []
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(SPIN_S * 1000000.0):
		await RenderingServer.frame_post_draw
		frames += 1
		for def: Dictionary in Content.continents():
			var id: String = def["id"]
			var m := _globe.marker(id)
			if not m.visible:
				continue
			if m.modulate.a < DRAWN_ALPHA:
				rim += 1
				continue
			checked += 1
			var hit := _globe.continent_at(m.position)
			if hit != id and misses.size() < 10:
				misses.append("%s read '%s' at %s a=%.3f" % [id, hit, m.position, m.modulate.a])
	return {
		"frames": frames,
		"checked": checked,
		"rim_skipped": rim,
		"misses": misses,
		"pass": misses.is_empty(),
	}


## Turns the continent FLY_OFFSET off the centre, clicks its marker with real input events, waits
## out the flight and reads the arrival; then Esc flies back out.
func _fly_test(id: String, out: String) -> Dictionary:
	var n := _globe.anchor_of(id)
	_globe.spin = false
	_globe.yaw = -atan2(n.x, n.z) + FLY_OFFSET
	_globe.set_tilt(asin(n.y))
	await get_tree().process_frame
	await get_tree().process_frame
	var at := _globe.marker(id).position
	var picks := _picked.size()
	_globe.spin = true
	for down: bool in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = at
		Input.parse_input_event(b)
		await get_tree().process_frame
	await _wait(GlobeView.FLY_S + SETTLE_S)
	var centre := get_viewport().get_visible_rect().size / 2.0
	var at_centre := _globe.continent_at(centre)
	var dist := _globe.camera().position.z
	await _still(out.path_join("fly_%s.png" % id))
	var yaw0 := _globe.yaw
	await _wait(HOLD_S)
	var held := absf(_globe.yaw - yaw0) < YAW_TOLERANCE
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait(GlobeView.FLY_S + SETTLE_S)
	var out_dist := _globe.camera().position.z
	var yaw1 := _globe.yaw
	await _wait(HOLD_S)
	var resumed := _globe.yaw - yaw1 > GlobeView.IDLE_SPIN * HOLD_S * 0.5
	await _still(out.path_join("out_%s.png" % id))
	var picked := _picked.slice(picks)
	return {
		"id": id,
		"clicked_at": [at.x, at.y],
		"picked": picked,
		"centre_reads": at_centre,
		"zoom_distance": dist,
		"spin_held": held,
		"out_distance": out_dist,
		"spin_resumed": resumed,
		"pass":
		(
			picked == [id]
			and at_centre == id
			and absf(dist - GlobeView.ZOOM_DISTANCE) < DIST_TOLERANCE
			and held
			and absf(out_dist - GlobeView.CAMERA_DISTANCE) < DIST_TOLERANCE
			and resumed
		),
	}


func _still(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _shown() -> Array[String]:
	var ids: Array[String] = []
	for def: Dictionary in Content.continents():
		var id: String = def["id"]
		if _globe.marker(id).visible:
			ids.append(id)
	return ids


## Frame times over MEASURE_S of free spin: average fps, the 1% low (fps of the slowest 1% of
## frames) and the 99th-percentile frame time.
func _measure() -> Dictionary:
	var times: Array[float] = []
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < int(MEASURE_S * 1000000.0):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var elapsed := (last - start) / 1000000.0
	var sorted := times.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	var slow := sorted.slice(int(sorted.size() * 0.99))
	var slow_ms := 0.0
	for t: float in slow:
		slow_ms += t
	slow_ms /= slow.size()
	var avg := times.size() / elapsed
	return {
		"frames": times.size(),
		"seconds": elapsed,
		"avg_fps": avg,
		"low1_fps": 1000.0 / slow_ms,
		"p99_ms": p99,
		"max_ms": sorted[-1],
		"pass": avg >= FPS_BAR and 1000.0 / slow_ms >= FPS_BAR,
	}


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _out_dir() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			return a.trim_prefix("--out=")
	return OS.get_user_data_dir().path_join("globe_g4")
