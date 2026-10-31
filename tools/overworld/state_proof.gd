extends Node
## Overworld plan row G3 evidence (D-430): runs scenes/globe_view.tscn in a real window with
## Ostia Minor and Thule conquered, so all three states show at once (Carthago and Silvania
## available; Mons Ferrata, Neptunia and Aurelia locked), and quits (exit 0 = every check passed).
## Run behind the GPU slot (D-376) with the 1080p off-screen override.cfg:
##   godot --path . tools/overworld/state_proof.tscn -- --out=<dir>
##   1. stills at STILL_YAWS with the markers (states_<deg>.png);
##   2. the screenshot test: the camera flies to each continent, the markers hide, and a BOX px
##      square at its anchor is read over PULSE_S (the available pulse's full cycle). Conquered
##      reads green, available yellow, locked shows no fill: its brightest frame stays under the
##      dimmest frame of any available one by READ_RATIO;
##   3. close stills of one continent per state (close_<id>.png).
## Results go to <dir>/results.json.

const Kit := preload("res://tools/capture/capture_kit.gd")
const GLOBE := preload("res://scenes/globe_view.tscn")

const CONQUERED: Array[String] = ["ostia_minor", "thule"]
const STILL_YAWS: Array[float] = [0.0, 90.0, 180.0, 270.0]  # degrees
const CLOSE_IDS: Array[String] = ["thule", "carthago", "mons_ferrata"]  # one per state
const WANT_SIZE := Vector2i(1920, 1080)  # D-339: judged at 1080p
const BOX := 31  # px, the square read at an anchor: several scanline periods, so bands average out
const PULSE_S := 2.0  # one cycle of the shader's pulse_hz 0.5
const SETTLE_S := 0.3  # past FLY_S before reading
const READ_RATIO := 1.5  # the dimmest available frame over the brightest locked one
const GREEN_RATIO := 1.3  # conquered: green over red
const YELLOW_BLUE := 2.0  # available: red over blue (yellow has next to none)
const WARMUP_S := 1.0

var _globe: GlobeView


func _ready() -> void:
	_globe = GLOBE.instantiate()
	add_child(_globe)
	_run.call_deferred()


func _run() -> void:
	if not Kit.window_ok():
		get_tree().quit(2)
		return
	var out := _out_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var medium: Dictionary = Content.section("display")["graphics"]["medium"]
	GraphicsPresets.apply(medium, get_viewport())
	var states := Campaign.states(Content.continents(), CONQUERED)
	_globe.set_states(states)
	_globe.spin = false
	await _wait(WARMUP_S)
	for deg: float in STILL_YAWS:
		_globe.yaw = deg_to_rad(deg)
		await _still(out.path_join("states_%d.png" % int(deg)))

	var reads: Array[Dictionary] = []
	_markers_shown(false)
	for def: Dictionary in Content.continents():
		var id: String = def["id"]
		_globe.fly_to(id)
		await _wait(GlobeView.FLY_S + SETTLE_S)
		var r := await _read(id)
		r["state"] = ["locked", "available", "conquered"][states[id]]
		reads.append(r)
	_markers_shown(true)
	for id: String in CLOSE_IDS:
		_globe.fly_to(id)
		await _wait(GlobeView.FLY_S + SETTLE_S)
		await _still(out.path_join("close_%s.png" % id))

	var verdict := _judge(reads)
	var size := DisplayServer.window_get_size()
	var res := {
		"window": [size.x, size.y],
		"conquered": CONQUERED,
		"reads": reads,
		"verdict": verdict,
		"pass": verdict["pass"] and size == WANT_SIZE,
	}
	var f := FileAccess.open(out.path_join("results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	print("globe_g3: ", JSON.stringify(res))
	get_tree().quit(0 if res["pass"] else 1)


## The BOX square at the continent's anchor, every frame over PULSE_S: its mean colour on the
## dimmest and the brightest frame (0..1 per channel).
func _read(id: String) -> Dictionary:
	var at := _globe.camera().unproject_position(_globe.surface_global(_globe.anchor_of(id)))
	var lo := Color(INF, INF, INF)
	var hi := Color(0, 0, 0)
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(PULSE_S * 1000000.0):
		await RenderingServer.frame_post_draw
		var c := _mean(get_viewport().get_texture().get_image(), Vector2i(at))
		if c.get_luminance() < lo.get_luminance():
			lo = c
		if c.get_luminance() > hi.get_luminance():
			hi = c
	return {"id": id, "at": [at.x, at.y], "dim": _rgb(lo), "bright": _rgb(hi)}


## Conquered reads green, available yellow on every frame, and the gap between the brightest
## locked frame and the dimmest available one is at least READ_RATIO.
func _judge(reads: Array[Dictionary]) -> Dictionary:
	var fails: Array[String] = []
	var locked_max := 0.0
	var available_min := INF
	for r: Dictionary in reads:
		var dim_rgb: Array = r["dim"]
		var bright_rgb: Array = r["bright"]
		var dim := _col(dim_rgb)
		var bright := _col(bright_rgb)
		match r["state"]:
			"conquered":
				if dim.g < dim.r * GREEN_RATIO:
					fails.append("%s does not read green" % r["id"])
			"available":
				if dim.r < dim.b * YELLOW_BLUE or dim.g >= dim.r * GREEN_RATIO:
					fails.append("%s does not read yellow" % r["id"])
				available_min = minf(available_min, dim.get_luminance())
			"locked":
				locked_max = maxf(locked_max, bright.get_luminance())
	var ratio := available_min / maxf(locked_max, 0.0001)
	if ratio < READ_RATIO:
		fails.append("available over locked only %.2f" % ratio)
	return {
		"locked_max": locked_max,
		"available_min": available_min,
		"ratio": ratio,
		"fails": fails,
		"pass": fails.is_empty()
	}


func _mean(img: Image, at: Vector2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	var half := BOX / 2
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			sum += img.get_pixelv(at + Vector2i(dx, dy))
	return sum / float(BOX * BOX)


func _rgb(c: Color) -> Array[float]:
	return [c.r, c.g, c.b]


func _col(a: Array) -> Color:
	var r: float = a[0]
	var g: float = a[1]
	var b: float = a[2]
	return Color(r, g, b)


func _markers_shown(on: bool) -> void:
	for child in _globe.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = on


func _still(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _out_dir() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			return a.trim_prefix("--out=")
	return OS.get_user_data_dir().path_join("globe_g3")
