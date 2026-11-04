extends Node
## Threat Level readout evidence (D-422, D-461): runs scenes/globe_view.tscn in a real window and
## shows the plate at 0, 10, 50, 80, 99 and 100 percent (value, colour, size, place), then with
## Ostia Minor's panel open (its Threat line reads in the plate's units). Quits (exit 0 = every
## check passed). Run behind the GPU slot (D-376) with the 1080p off-screen
## override.cfg:
##   godot --path . tools/overworld/threat_proof.tscn -- --out=<dir>
## Stills: threat_<value>.png per level, and threat_panel.png (a fresh campaign with the panel
## open). Results go to <dir>/results.json.

const Kit := preload("res://tools/capture/capture_kit.gd")
const GLOBE := preload("res://scenes/globe_view.tscn")

const WANT_SIZE := Vector2i(1920, 1080)  # D-339: 1080p is the baseline the readout is judged at
const WARMUP_S := 1.0  # seconds for the globe to settle before the first still

var _globe: GlobeView
var _missions: GlobeMissions
var _fails: Array[String] = []
## The levels shown (percent of the cap).
const LEVELS: Array[float] = [0.0, 10.0, 50.0, 80.0, 99.0, 100.0]
## The first continent in the globe's sequence (its panel is the one shown).
var _panel_id := ""


func _ready() -> void:
	TranslationServer.set_locale("en")  # the expected strings are English
	_panel_id = str(Content.continents()[0]["id"])
	_globe = GLOBE.instantiate()
	add_child(_globe)
	for child: Node in _globe.get_children():
		if child is GlobeMissions:
			_missions = child as GlobeMissions
	_run.call_deferred()


func _run() -> void:
	if not Kit.window_ok():
		get_tree().quit(2)
		return
	var out := _out_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var medium: Dictionary = Content.section("display")["graphics"]["medium"]
	GraphicsPresets.apply(medium, get_viewport())
	_globe.spin = false
	await _wait(WARMUP_S)
	var shows: Array[Dictionary] = []
	var last := {}
	for level: float in LEVELS:
		last = await _show(out, level)
		shows.append(last)
	var colours: Array[Color] = []
	for row: Dictionary in shows:
		colours.append(Color(str(row["colour"])))
	if colours[0] == colours[colours.size() - 1] or colours[0] == colours[1]:
		_fails.append("the colour does not shift with the level: %s" % [colours])
	_missions.use_save({"conquered": [], "bonuses": {}, "threat": 0.0})
	_missions.show_panel(_panel_id)
	await _still(out.path_join("threat_panel.png"))
	var box := _missions.threat.get_global_rect()
	var card := _missions.panel.get_global_rect()
	if box.intersects(card):
		_fails.append("the readout %s overlaps the panel %s" % [box, card])
	var size := DisplayServer.window_get_size()
	if size != WANT_SIZE:
		_fails.append("window %s, not %s" % [size, WANT_SIZE])
	var res := {"window": [size.x, size.y], "shows": shows, "fails": _fails}
	res["pass"] = _fails.is_empty()
	var f := FileAccess.open(out.path_join("results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	print("threat_proof: ", JSON.stringify(res))
	get_tree().quit(0 if res["pass"] else 1)


## The plate at a Threat Level: its text, colour, height and place must match the data.
func _show(out: String, level: float) -> Dictionary:
	_missions.use_save({"conquered": [], "bonuses": {}, "threat": level})
	var plate := _missions.threat
	var want := "%d%%" % floori(level)
	var path := out.path_join("threat_%d.png" % floori(level))
	await _still(path)
	var box := plate.get_global_rect()
	_check_edge(path, box, want)
	if plate.value_text() != want:
		_fails.append("%s: the readout says %s" % [want, plate.value_text()])
	if plate.value_colour() != ThreatReadout.colour_for(level):
		_fails.append("%s: the value is not in the ramp's colour" % want)
	if not plate.visible or not get_viewport().get_visible_rect().encloses(box):
		_fails.append("%s: the plate %s is not on screen" % [want, box])
	if absf(box.size.y - Num.f(ThreatReadout.config()["height"])) > 4.0:
		var tall := Num.i(ThreatReadout.config()["height"])
		_fails.append("%s: the plate is %d px tall, not about %d" % [want, box.size.y, tall])
	var margin := UiKit.safe_margin()
	if box.position != margin:
		_fails.append("%s: the plate sits at %s, not the safe margin %s" % [want, box.position, margin])
	return {
		"threat": level,
		"text": plate.value_text(),
		"colour": plate.value_colour().to_html(false),
		"rect": [box.position.x, box.position.y, box.size.x, box.size.y],
	}


## The border is whole: its bottom two rows are the edge colour along the plate's full width.
func _check_edge(path: String, box: Rect2, want: String) -> void:
	var img := Image.load_from_file(path)
	var edge := UiKit.ACCENT
	var bad := 0
	var rows := Num.i(ThreatReadout.config()["border"])
	for n: int in rows:
		var y := int(box.end.y) - 1 - n
		for x: int in range(int(box.position.x), int(box.end.x)):
			if img.get_pixel(x, y).to_html(false) != edge.to_html(false):
				bad += 1
	if bad > 0:
		_fails.append("%s: %d border pixels on the bottom %d rows are not yellow" % [want, bad, rows])


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
	return OS.get_user_data_dir().path_join("threat_proof")
