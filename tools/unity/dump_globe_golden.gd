extends SceneTree
## Writes how Godot's hologram globe (scenes/globe_view.gd) turns, flies, hit-tests and places its
## markers, so the Unity port (unity/Assets/Scripts/GameLogic/GlobeOrbit.cs) can be checked
## against it number for number.
##
##   APPDATA=<scratch> godot --headless --path . --script tools/unity/dump_globe_golden.gd
##
## Output: unity/SimTests/golden/globe.txt, read by GlobeHoloCheck
## (`dotnet run --project unity/SimTests`). V: the viewport (w, h). I: the idle spin (step, yaw,
## tilt, camera z). T: a continent's fly-to target (id, yaw, tilt, distance) from the start pose;
## F / O: the flight to it and back out (id, step, yaw, tilt, camera z, flying). G: continent_at
## over a grid (y, then one mask value per column, 0 the sea). M: the markers at a yaw (yaw,
## index, visible, x, y, alpha). D: a drag and a click (what, yaw, tilt, selected, flying).

const OUT := "res://unity/SimTests/golden/globe.txt"
const DT := 1.0 / 60.0
const IDLE_STEPS := 60
const EVERY := 10
const FLY_STEPS := 50
const FLY_EVERY := 7
const START_YAW := 0.4
const GRID_YAW := 0.7
const GRID_STEP := 30
const MARKER_YAWS := 6
const DRAG := [Vector2(30.0, 0.0), Vector2(0.0, 20.0), Vector2(-12.0, -9.0)]
const NUDGE := Vector2(2.0, 1.0)  # inside CLICK_SLOP_PX: still a click

var _lines: PackedStringArray = []
var _globe: GlobeView


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_globe = (load("res://scenes/globe_view.tscn") as PackedScene).instantiate() as GlobeView
	root.add_child(_globe)
	_globe.set_process(false)
	_globe.set_process_unhandled_input(false)
	# One conquest: Ostia Minor conquered, the next two offered, the rest locked (D-420).
	_globe.use_save({"conquered": ["ostia_minor"], "threat": 10.0})
	var size := _globe.get_viewport().get_visible_rect().size
	_lines.append("V %d %d" % [size.x, size.y])
	_idle()
	var ids: Array[String] = []
	for def: Dictionary in Content.continents():
		ids.append(str(def["id"]))
	for id in ids:
		_flight(id)
	_grid()
	_markers(ids.size())
	_drag(ids)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("globe golden: %d lines" % _lines.size())
	quit()


func _reset(yaw: float) -> void:
	_globe.yaw = yaw
	_globe.set_tilt(GlobeView.START_TILT)
	_globe.camera().position.z = GlobeView.CAMERA_DISTANCE
	_globe.selected = ""
	_globe._fly_t = 1.0
	_globe._dragging = false
	_globe._process(0.0)


func _pose() -> String:
	return "%.6f %.6f %.6f" % [_globe.yaw, _globe.tilt(), _globe.camera().position.z]


func _idle() -> void:
	_reset(0.0)
	for s in IDLE_STEPS + 1:
		if s % EVERY == 0:
			_lines.append("I %d %s" % [s, _pose()])
		_globe._process(DT)


func _flight(id: String) -> void:
	_reset(START_YAW)
	_globe.fly_to(id)
	var to: Vector3 = _globe._fly_to
	_lines.append("T %s %.6f %.6f %.6f" % [id, to.x, to.y, to.z])
	for tag: String in ["F", "O"]:
		if tag == "O":
			_globe.fly_out()
		for s in FLY_STEPS:
			_globe._process(DT)
			if s % FLY_EVERY == 0 or s == FLY_STEPS - 1:
				_lines.append("%s %s %d %s %d" % [tag, id, s, _pose(), int(_globe.flying())])


func _grid() -> void:
	_reset(GRID_YAW)
	var size := _globe.get_viewport().get_visible_rect().size
	var ids: Array[String] = []
	for def: Dictionary in Content.continents():
		ids.append(str(def["id"]))
	for y in range(0, int(size.y), GRID_STEP):
		var row := ""
		for x in range(0, int(size.x), GRID_STEP):
			row += str(ids.find(_globe.continent_at(Vector2(x, y))) + 1)
		_lines.append("G %d %s" % [y, row])


func _markers(count: int) -> void:
	for k in MARKER_YAWS:
		_reset(float(k))
		for n in count:
			var m := _globe.marker(str(Content.continents()[n]["id"]))
			_lines.append(
				(
					"M %.6f %d %d %.4f %.4f %.6f"
					% [float(k), n, int(m.visible), m.position.x, m.position.y, m.modulate.a]
				)
			)


func _press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	_globe._unhandled_input(e)


func _move(at: Vector2, by: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.relative = by
	_globe._unhandled_input(e)


func _drag(ids: Array[String]) -> void:
	_reset(START_YAW)
	var centre := _globe.get_viewport().get_visible_rect().size / 2.0
	var at := centre
	_press(at, true)
	for by: Vector2 in DRAG:
		at += by
		_move(at, by)
	_press(at, false)
	_lines.append("D drag %s %s %d" % [_pose(), _or_none(_globe.selected), int(_globe.flying())])
	# A click (a nudge inside the slop) on the first offered continent's marker picks it.
	_reset(START_YAW)
	var open := ""
	for id in ids:
		if not _globe.locked(id) and _globe.marker(id).visible:
			open = id
			break
	var point := _globe.marker(open).position
	_press(point, true)
	_move(point + NUDGE, NUDGE)
	_press(point + NUDGE, false)
	_lines.append("D click %s %s %d" % [_pose(), _or_none(_globe.selected), int(_globe.flying())])


func _or_none(id: String) -> String:
	return id if id != "" else "-"
