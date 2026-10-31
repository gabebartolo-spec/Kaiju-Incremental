extends Node
## Overworld plan row G2 evidence: runs scenes/globe_view.tscn in a real window and quits
## (exit 0 = every check passed). Run behind the GPU slot (D-376) with the 1080p off-screen
## override.cfg:
##   godot --path . tools/overworld/globe_proof.tscn -- --out=<dir>
##   1. stills of the globe at STILL_YAWS, the pointer at the screen centre, recording what it
##      hovers (globe_<deg>.png);
##   2. a scripted drag: the globe turns by the drag's pixels times DRAG_RAD_PER_PX, picks nothing;
##   3. MEASURE_S seconds of frame times on the Medium preset, vsync off (avg fps, 1% low, p99).
## Results go to <dir>/results.json.

const Kit := preload("res://tools/capture/capture_kit.gd")
const GLOBE := preload("res://scenes/globe_view.tscn")

const STILL_YAWS: Array[float] = [0.0, 90.0, 180.0, 270.0]  # degrees
const WANT_SIZE := Vector2i(1920, 1080)  # D-339: judged at 1080p
const DRAG_PX := Vector2(240.0, -60.0)
const DRAG_STEPS := 12
const DRAG_TOLERANCE := 0.0001  # rad
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

	var centre := get_viewport().get_visible_rect().size / 2.0
	var stills: Array[Dictionary] = []
	_globe.spin = false
	for deg: float in STILL_YAWS:
		_globe.yaw = deg_to_rad(deg)
		await get_tree().process_frame
		var move := InputEventMouseMotion.new()
		move.position = centre
		Input.parse_input_event(move)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join("globe_%d.png" % int(deg))
		get_viewport().get_texture().get_image().save_png(path)
		stills.append({"yaw_deg": deg, "hovered": _globe.hovered, "path": path})
	_globe.spin = true

	var drag := await _drag_test(centre)
	var fps := await _measure()
	var size := DisplayServer.window_get_size()
	var res := {
		"window": [size.x, size.y],
		"preset": "medium",
		"vsync": "disabled",
		"renderer": RenderingServer.get_video_adapter_name(),
		"fps": fps,
		"drag": drag,
		"stills": stills,
	}
	res["pass"] = fps["pass"] and drag["pass"] and size == WANT_SIZE
	var f := FileAccess.open(out.path_join("results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	print("globe_g2: ", JSON.stringify(res))
	get_tree().quit(0 if res["pass"] else 1)


## Presses the left button, moves DRAG_PX in DRAG_STEPS motion events, releases: the globe turns
## by exactly DRAG_PX times DRAG_RAD_PER_PX (the idle spin pauses while the button is down) and a
## drag is not a pick.
func _drag_test(at: Vector2) -> Dictionary:
	var yaw0 := _globe.yaw
	var tilt0 := _globe.tilt()
	var picks := _picked.size()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	Input.parse_input_event(press)
	await get_tree().process_frame
	var step := DRAG_PX / DRAG_STEPS
	for i: int in DRAG_STEPS:
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		at += step
		move.position = at
		move.relative = step
		Input.parse_input_event(move)
		await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	Input.parse_input_event(release)
	var yaw := _globe.yaw - yaw0
	var tilt := _globe.tilt() - tilt0
	await get_tree().process_frame
	var want_yaw := DRAG_PX.x * GlobeView.DRAG_RAD_PER_PX
	var want_tilt := DRAG_PX.y * GlobeView.DRAG_RAD_PER_PX
	return {
		"yaw": yaw,
		"want_yaw": want_yaw,
		"tilt": tilt,
		"want_tilt": want_tilt,
		"picked": _picked.size() - picks,
		"pass":
		(
			absf(yaw - want_yaw) < DRAG_TOLERANCE
			and absf(tilt - want_tilt) < DRAG_TOLERANCE
			and _picked.size() == picks
		),
	}


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
	return OS.get_user_data_dir().path_join("globe_g2")
