extends Node3D
## Overworld F1 spike (throwaway, roadmap row F1): the hologram globe the campaign hub will sit on.
## A sphere MeshInstance3D with the hologram ShaderMaterial (hologram.gdshader) in the Emergency
## Broadcast palette (UiKit, D-061), idle spin, drag to spin, and one Marker3D on the surface
## projected each frame with Camera3D.unproject_position() into a Control, the pattern the mission
## markers will use.
##
## Open it in the editor (or run the scene) to spin it by hand: left-drag turns it, release
## resumes the idle spin. With `-- --auto --out=<dir>` it runs the F1 evidence and quits
## (exit 0 = every check passed):
##   1. a strip of stills as the marker crosses the visible face (marker_strip_*.png), the middle
##      one also the 1080p still (globe_1080p.png);
##   2. a scripted drag: the globe turns by exactly the drag's pixels times DRAG_RAD_PER_PX;
##   3. MEASURE_S seconds of frame times on the Medium preset, vsync off (avg fps, 1% low, p99);
##   throughout, the marker check: just before each frame draws, the Control's centre equals
##   unproject_position() of the marker and the camera ray through it passes through the marker.
## Results go to <dir>/results.json. Windowed runs on the shared PC go through C:/kt/gpu_slot.sh
## (D-376).

const Kit := preload("res://tools/capture/capture_kit.gd")
const HOLOGRAM := preload("res://tools/spikes/globe_f1/hologram.gdshader")

const RADIUS := 1.0
const SEGMENTS := 96
const RINGS := 48
const CAMERA_DISTANCE := 3.4
const CAMERA_FOV := 38.0
const START_TILT := 0.3  # rad, the globe leans toward the camera so the north reads
const TILT_LIMIT := 1.1  # rad either way
const IDLE_SPIN := 0.25  # rad/s
const DRAG_RAD_PER_PX := 0.006
## The test marker's place on the globe, degrees.
const MARKER_LAT := 20.0
const MARKER_LON := 0.0
const BLIP_RADIUS := 14.0

# marker angle off the camera, degrees
const STRIP_ANGLES: Array[float] = [-60.0, -30.0, 0.0, 30.0, 60.0]
const START_ANGLE := -85.0
const DRAG_PX := Vector2(240.0, -60.0)
const DRAG_STEPS := 12
const WARMUP_S := 2.0
const MEASURE_S := 10.0
const FPS_BAR := 60.0
const MAX_ERR_PX := 0.5
const MAX_RAY_DIST := 0.001  # m
const DRAG_TOLERANCE := 0.0001  # rad

var _camera: Camera3D
var _tilt: Node3D
var _globe: MeshInstance3D
var _marker: Marker3D
var _blip: Blip
var _yaw := 0.0
var _dragging := false
var _spin := true
# marker check, sampled at frame_pre_draw
var _checked := 0
var _hidden := 0
var _max_err := 0.0
var _max_ray := 0.0


## The marker's on-screen mark: a ring and a cross in the alert red.
class Blip:
	extends Control

	func _draw() -> void:
		var c := size / 2.0
		draw_arc(c, size.x / 2.0 - 2.0, 0.0, TAU, 32, UiKit.ALERT, 3.0, true)
		draw_line(c - Vector2(size.x / 2.0 + 6.0, 0.0), c - Vector2(4.0, 0.0), UiKit.ALERT, 2.0)
		draw_line(c + Vector2(4.0, 0.0), c + Vector2(size.x / 2.0 + 6.0, 0.0), UiKit.ALERT, 2.0)
		draw_circle(c, 3.0, UiKit.ACCENT)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UiKit.BG
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.position = Vector3(0.0, 0.0, CAMERA_DISTANCE)
	add_child(_camera)

	_tilt = Node3D.new()
	_tilt.rotation.x = START_TILT
	add_child(_tilt)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = SEGMENTS
	sphere.rings = RINGS
	var mat := ShaderMaterial.new()
	mat.shader = HOLOGRAM
	mat.set_shader_parameter("tint", UiKit.ACCENT)
	_globe = MeshInstance3D.new()
	_globe.mesh = sphere
	_globe.material_override = mat
	_tilt.add_child(_globe)

	_marker = Marker3D.new()
	var lat := deg_to_rad(MARKER_LAT)
	var lon := deg_to_rad(MARKER_LON)
	_marker.position = Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)) * RADIUS
	_globe.add_child(_marker)

	var layer := CanvasLayer.new()
	add_child(layer)
	_blip = Blip.new()
	_blip.size = Vector2.ONE * BLIP_RADIUS * 2.0
	_blip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_blip)

	RenderingServer.frame_pre_draw.connect(_check_marker)
	if "--auto" in OS.get_cmdline_user_args():
		_run_auto.call_deferred()


func _process(delta: float) -> void:
	if _spin and not _dragging:
		_yaw += IDLE_SPIN * delta
	_globe.rotation.y = _yaw
	_place_marker()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_yaw += motion.relative.x * DRAG_RAD_PER_PX
		_tilt.rotation.x = clampf(
			_tilt.rotation.x + motion.relative.y * DRAG_RAD_PER_PX, -TILT_LIMIT, TILT_LIMIT
		)


## Projects the marker into the Control layer; hidden while it is on the far side of the globe.
func _place_marker() -> void:
	_globe.force_update_transform()
	var p := _marker.global_position
	var normal := (p - _globe.global_position).normalized()
	var facing := normal.dot((_camera.global_position - p).normalized()) > 0.0
	_blip.visible = facing
	if facing:
		_blip.position = _camera.unproject_position(p) - _blip.size / 2.0


## Just before the frame draws: the mark sits where the marker projects now (no frame of lag) and
## the camera ray through the mark's centre passes through the marker.
func _check_marker() -> void:
	if not _blip.visible:
		_hidden += 1
		return
	var p := _marker.global_position
	var centre := _blip.position + _blip.size / 2.0
	_max_err = maxf(_max_err, centre.distance_to(_camera.unproject_position(p)))
	var origin := _camera.project_ray_origin(centre)
	var dir := _camera.project_ray_normal(centre)
	_max_ray = maxf(_max_ray, (p - origin).cross(dir).length())
	_checked += 1


## The marker's angle round the globe's axis from the camera, degrees (0 = facing the camera).
func _marker_angle() -> float:
	var p := _marker.global_position
	return rad_to_deg(atan2(p.x, p.z))


func _run_auto() -> void:
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
	_yaw = deg_to_rad(START_ANGLE - MARKER_LON)
	await _wait(WARMUP_S)

	var stills: Array[String] = []
	for i: int in STRIP_ANGLES.size():
		while _marker_angle() < STRIP_ANGLES[i]:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join("marker_strip_%d.png" % i)
		get_viewport().get_texture().get_image().save_png(path)
		stills.append(path)
		if is_zero_approx(STRIP_ANGLES[i]):
			get_viewport().get_texture().get_image().save_png(out.path_join("globe_1080p.png"))

	var drag := await _drag_test()
	var fps := await _measure()
	var res := {
		"viewport":
		[get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"preset": "medium",
		"scale_3d": preset["scale"],
		"vsync": "disabled",
		"renderer": RenderingServer.get_video_adapter_name(),
		"fps": fps,
		"marker":
		{
			"frames_checked": _checked,
			"frames_hidden": _hidden,
			"max_err_px": _max_err,
			"max_ray_dist_m": _max_ray,
			"pass": _checked > 0 and _max_err <= MAX_ERR_PX and _max_ray <= MAX_RAY_DIST,
		},
		"drag": drag,
		"stills": stills,
	}
	res["pass"] = fps["pass"] and res["marker"]["pass"] and drag["pass"]
	var f := FileAccess.open(out.path_join("results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	print("globe_f1: ", JSON.stringify(res))
	get_tree().quit(0 if res["pass"] else 1)


## Presses the left button, moves DRAG_PX in DRAG_STEPS motion events, releases; the globe must turn
## by exactly DRAG_PX times DRAG_RAD_PER_PX (the idle spin pauses while the button is down).
func _drag_test() -> Dictionary:
	var at := get_viewport().get_visible_rect().size / 2.0
	var yaw0 := _yaw
	var tilt0 := _tilt.rotation.x
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
	var yaw := _yaw - yaw0
	var tilt := _tilt.rotation.x - tilt0
	await get_tree().process_frame
	var want_yaw := DRAG_PX.x * DRAG_RAD_PER_PX
	var want_tilt := DRAG_PX.y * DRAG_RAD_PER_PX
	return {
		"yaw": yaw,
		"want_yaw": want_yaw,
		"tilt": tilt,
		"want_tilt": want_tilt,
		"spin_resumed": _spin and not _dragging,
		"pass":
		(
			absf(yaw - want_yaw) < DRAG_TOLERANCE
			and absf(tilt - want_tilt) < DRAG_TOLERANCE
			and not _dragging
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
	return OS.get_user_data_dir().path_join("globe_f1")
