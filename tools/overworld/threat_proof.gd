extends Node
## Threat Level readout evidence (D-422): runs scenes/globe_view.tscn in a real window and shows
## the readout over four campaigns: fresh (0%), Ostia Minor won (its share), the five continents
## before the capital won (their summed shares) and the sixth won (100%, Aurelia open). Quits
## (exit 0 = every check passed). Run behind the GPU slot (D-376) with the 1080p off-screen
## override.cfg:
##   godot --path . tools/overworld/threat_proof.tscn -- --out=<dir>
## Stills: threat_<value>.png per campaign, and threat_panel.png (the last campaign with Ostia
## Minor's panel open: the readout clears it). Results go to <dir>/results.json.

const Kit := preload("res://tools/capture/capture_kit.gd")
const GLOBE := preload("res://scenes/globe_view.tscn")

const PANEL_ID := "ostia_minor"
const WANT_SIZE := Vector2i(1920, 1080)  # D-339: judged at 1080p
const WARMUP_S := 1.0

var _globe: GlobeView
var _missions: GlobeMissions
var _fails: Array[String] = []


func _ready() -> void:
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
	var outside: Array[String] = []
	for def: Dictionary in Content.continents():
		if not def.get("capital", false):
			outside.append(str(def["id"]))
	var shows: Array[Dictionary] = []
	for wins: Array in [[], [PANEL_ID], outside.slice(0, outside.size() - 1), outside]:
		shows.append(await _show(out, wins))
	_missions.panel.show_for(Content.continent(PANEL_ID))
	await _still(out.path_join("threat_panel.png"))
	var box := _missions.threat_label.get_global_rect()
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


## A campaign with `wins` conquered (Campaign.conquer, no bonus): the readout must show the save's
## Threat Level as a whole percent, on screen.
func _show(out: String, wins: Array) -> Dictionary:
	var save := {"conquered": [], "bonuses": {}, "threat": 0.0}
	for id: String in wins:
		save = Campaign.conquer(save, Content.continent(id), "")
	_missions.use_save(save)
	var value := roundi(Num.f(save["threat"]))
	var label := _missions.threat_label
	var want := tr("Threat %d%%") % value
	await _still(out.path_join("threat_%d.png" % value))
	var box := label.get_global_rect()
	if label.text != want:
		_fails.append("%d wins: the readout says %s, not %s" % [wins.size(), label.text, want])
	if not label.visible or not get_viewport().get_visible_rect().encloses(box):
		_fails.append("%d wins: the readout %s is not on screen" % [wins.size(), box])
	return {
		"wins": wins,
		"threat": value,
		"text": label.text,
		"rect": [box.position.x, box.position.y, box.size.x, box.size.y],
		"aurelia_locked": _globe.locked("aurelia"),
	}


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
