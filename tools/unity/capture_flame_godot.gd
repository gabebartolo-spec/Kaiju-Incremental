extends SceneTree
## Godot's side of the flame gate (D-470 U1): the game's own fires on the Unity slice's city block,
## at dusk, from the camera Unity's clip uses, one png per frame. The fires come from the Unity
## slice's data (unity/Assets/StreamingAssets/fire.json), so both engines burn the same roof.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 30 \
##     --script tools/unity/capture_flame_godot.gd -- \
##     --out=<dir> --eye=x,y,z --aim=x,y,z --frames=180
## Eye and aim are Godot axes. Needs a window (no --headless) and the no-focus override.cfg.

const Kit := preload("res://tools/capture/capture_kit.gd")
const FIRE_JSON := "res://unity/Assets/StreamingAssets/fire.json"
const SLICE_JSON := "res://unity/Assets/StreamingAssets/slice/slice.json"
## The stage and the time of day export_slice.gd exports.
const STAGE := 3
const TIME := "dusk"
## A run long enough that the clock never ends it mid-clip.
const RUN_SECONDS := 600.0
## Frames the fires burn before the first still: the smoke's column is full after a smoke's life.
const WARM_FRAMES := 330

var _out := "user://flame_clip"
var _frames := 180
var _eye := Vector3.ZERO
var _aim := Vector3.ZERO
var _rampage: Rampage


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"out": _out, "frames": _frames, "eye": "", "aim": ""})
	_out = str(a["out"])
	_frames = Num.i(a["frames"])
	_eye = _vector(str(a["eye"]))
	_aim = _vector(str(a["aim"]))
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _vector(text: String) -> Vector3:
	var parts := text.split_floats(",")
	return Vector3(parts[0], parts[1], parts[2])


func _run() -> void:
	await process_frame
	var layout := _slice_block(CityGrowth.layout(Content.tuning(), STAGE, Seeds.make("city", 0)))
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[STAGE - 1])
	_rampage = Kit.rampage("reptilian", stats, 1, layout)
	_rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	Content.set_time(TIME)  # after setup, which sets the run's own time
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	_rampage.sim.time_left = RUN_SECONDS
	_hide_hud(_rampage)
	var city: CityView = _rampage.get("_city")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIRE_JSON))
	# Beside the camera, out of shot: where the kaiju stands decides how much smoke clears.
	var kaiju: Array = data["clip_kaiju"]
	_rampage.sim.kaiju_pos = Vector2(Num.f(kaiju[0]), Num.f(kaiju[1]))
	for spot: Dictionary in data["spots"]:
		var fire := Fire.new(Num.f(spot["size"]), Num.f(spot["seed"]))
		fire.position = Vector3(Num.f(spot["x"]), Num.f(spot["y"]), Num.f(spot["z"]))
		city.add_child(fire)
	var cam := Kit.camera(_rampage)
	cam.position = _eye
	cam.look_at(_aim)
	cam.current = true
	await Kit.frames(self, WARM_FRAMES)
	for n: int in _frames:
		Kit.still(self, _out, "f%04d" % n)
		await process_frame
	quit()


## Only the buildings Unity's slice holds, so both engines burn the same roof in the same block.
func _slice_block(layout: Array[Dictionary]) -> Array[Dictionary]:
	var slice: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SLICE_JSON))
	var spots := {}
	for b: Dictionary in slice["buildings"]:
		spots[Vector2(Num.f(b["x"]), Num.f(b["z"]))] = true
	var out: Array[Dictionary] = []
	for entry: Dictionary in layout:
		if spots.has(Vector2(Num.f(entry["x"]), Num.f(entry["z"]))):
			out.append(entry)
	assert(out.size() == spots.size(), "the layout no longer holds the slice's block")
	print("flame clip: %d buildings of %d" % [out.size(), layout.size()])
	return out


func _hide_hud(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		_hide_hud(child)
