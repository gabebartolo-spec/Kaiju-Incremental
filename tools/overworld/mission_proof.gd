extends Node
## Overworld plan row G5 evidence (D-431): runs scenes/globe_view.tscn in a real window on a fresh
## campaign and plays one mission through the real pointer and buttons, and quits (exit 0 = every
## check passed). Run behind the GPU slot (D-376) with the 1080p off-screen override.cfg:
##   godot --path . tools/overworld/mission_proof.tscn -- --out=<dir>
## Stills: 1_panel.png (Ostia Minor clicked, its panel), 2_mission.png (LAUNCH: WIN / LOSE),
## 3_lost.png (LOSE: back on the panel), 4_pick.png (WIN: the three bonuses), 5_won.png (a bonus
## kept: the globe back out, Ostia Minor green, Carthago and Thule open). Results go to
## <dir>/results.json.

const Kit := preload("res://tools/capture/capture_kit.gd")
const GLOBE := preload("res://scenes/globe_view.tscn")

const ID := "ostia_minor"
const KEEP := 1  # the bonus kept, of the three
const WANT_SIZE := Vector2i(1920, 1080)  # D-339: judged at 1080p
const SETTLE_S := 0.3  # past GlobeView.FLY_S before a still
const WARMUP_S := 1.0

var _globe: GlobeView
var _fails: Array[String] = []


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
	_globe.spin = false
	await _wait(WARMUP_S)
	await _pick_ostia(out)
	var panel := _globe.mission_panel()
	var mission := _globe.mission()
	panel.launch_button().pressed.emit()
	_expect(mission.visible, "LAUNCH opens the mission")
	await _still(out.path_join("2_mission.png"))
	mission.buttons()[1].pressed.emit()
	_expect(not mission.visible and panel.visible, "LOSE returns to the panel")
	_expect(_conquered().is_empty(), "LOSE changes nothing")
	await _still(out.path_join("3_lost.png"))
	panel.launch_button().pressed.emit()
	mission.buttons()[0].pressed.emit()
	_expect(mission.buttons().size() == 3, "WIN offers three bonuses")
	await _still(out.path_join("4_pick.png"))
	mission.buttons()[KEEP].pressed.emit()
	await _wait(GlobeView.FLY_S + SETTLE_S)
	_expect(_conquered() == [ID], "WIN conquers Ostia Minor")
	_expect(not _globe.locked("carthago") and not _globe.locked("thule"), "Carthago, Thule open")
	await _still(out.path_join("5_won.png"))
	_finish(out)


## Turns Ostia Minor to the front and clicks it through the real input path.
func _pick_ostia(out: String) -> void:
	_globe.fly_to(ID)
	await _wait(GlobeView.FLY_S + SETTLE_S)
	var at := _globe.camera().unproject_position(_globe.surface_global(_globe.anchor_of(ID)))
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		Input.parse_input_event(click)
		await get_tree().process_frame
	await _wait(GlobeView.FLY_S + SETTLE_S)
	_expect(_globe.mission_panel().visible, "a click on Ostia Minor opens its panel")
	await _still(out.path_join("1_panel.png"))


func _finish(out: String) -> void:
	var size := DisplayServer.window_get_size()
	var res := {
		"window": [size.x, size.y],
		"save": _globe.save(),
		"fails": _fails,
		"pass": _fails.is_empty() and size == WANT_SIZE,
	}
	var f := FileAccess.open(out.path_join("results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	print("globe_g5: ", JSON.stringify(res))
	get_tree().quit(0 if res["pass"] else 1)


func _conquered() -> Array:
	return _globe.save().get("conquered", [])


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


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
	return OS.get_user_data_dir().path_join("globe_g5")
