extends SceneTree
## Rampage escalation stills and clip (EscalationView, D-154). For each time of day and each
## destruction level it builds the city, ruins seeded-random whole buildings through the sim's real
## damage (sim.damage_chunks, so sim.destruction() is the real share) until the level is reached,
## keeps the buildings nearest the kaiju standing, lets the escalation settle, and saves
## <out>/<time>_d<level>.png plus <time>_d<level>_nokaiju.png (the same frame without the kaiju,
## for the contrast measure in tools/capture/escalation_sheet.py).
##   --clip: one night clip instead: destruction rises from 0 to --to over --seconds (the sim's real
##           damage, a few buildings a frame) with the real easing, as PNG frames in <out>/clip/.
##   --baseline: the EscalationView is removed (the frame as it was before this change).
## Needs the off-screen no_focus override.cfg (a window) and --fixed-fps 60.
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60
##     --script tools/capture/capture_escalation.gd -- --out=<dir> [--times=dusk,night] [--levels=0,0.4,0.8]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 20
const KEEP_NEAR := 4  # buildings nearest the kaiju are never ruined: the near streets stay readable
const EASE_STEPS := 8  # settle calls of EASE_SECONDS each (the real easing, run fast)
const EASE_SECONDS := 3.0
const FRAME := 1.0 / 60.0
const CAMERA_AIM := 3.5  # metres above the feet, times body scale

var _out := "user://escalation"
var _a := {}


func _initialize() -> void:
	_a = Kit.args(
		{
			"out": _out,
			"times": "dusk,night,morning,noon",
			"levels": "0,0.4,0.8",
			"clip": false,
			"to": 0.8,
			"seconds": 6.0,
			"baseline": false,
		}
	)
	_out = str(_a["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if (_a["clip"] == true):
		await _clip()
		quit()
		return
	for time: String in str(_a["times"]).split(","):
		for level: String in str(_a["levels"]).split(","):
			await _still(time, float(level))
	quit()


class Rig:
	var stage: Node3D
	var city: CityView
	var sim: RampageSim
	var kaiju: Node3D
	var cam: Camera3D
	var order: Array[int] = []  # building indices in the order they are ruined
	var next := 0


func _rig(time: String) -> Rig:
	Content.set_time(time)
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[1])
	var sim := RampageSim.new(stats, Content.tuning(), Kit.flow_city(), Seeds.make("army", 0))
	var rig := Rig.new()
	rig.sim = sim
	rig.stage = Node3D.new()
	rig.city = CityView.new(sim, Seeds.make("fx", 0))
	rig.stage.add_child(rig.city)
	var at := Vector3(sim.kaiju_pos.x, 0, sim.kaiju_pos.y)
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	rig.kaiju = KaijuModel.new("reptilian", colors)
	rig.kaiju.position = at
	rig.kaiju.scale = Vector3.ONE * sim.body_scale()
	rig.kaiju.rotation.y = PI  # facing the camera's far side, the way the game walks
	rig.stage.add_child(rig.kaiju)
	rig.cam = Kit.camera(rig.stage)
	rig.cam.position = at + Kit.GAME_CAMERA * CameraTuning.zoom(sim.body_scale())
	root.add_child(rig.stage)
	rig.cam.look_at(at + Vector3(0, CAMERA_AIM * sim.body_scale(), 0))
	rig.cam.current = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var near: Array[int] = []
	for i: int in sim.buildings.size():
		near.append(i)
	near.sort_custom(
		func(x: int, y: int) -> bool:
			return (
				Vector2(sim.buildings[x].x, sim.buildings[x].z).distance_to(sim.kaiju_pos)
				< Vector2(sim.buildings[y].x, sim.buildings[y].z).distance_to(sim.kaiju_pos)
			)
	)
	for i: int in near.slice(KEEP_NEAR):
		if sim.buildings[i].in_arena:
			rig.order.append(i)
	for i: int in range(rig.order.size() - 1, 0, -1):  # seeded shuffle
		var j := rng.randi_range(0, i)
		var t := rig.order[i]
		rig.order[i] = rig.order[j]
		rig.order[j] = t
	return rig


## Ruins whole buildings in the rig's order until sim.destruction() reaches `level`.
func _ruin_to(rig: Rig, level: float) -> void:
	var at := Vector3(rig.sim.kaiju_pos.x, 0, rig.sim.kaiju_pos.y)
	while rig.sim.destruction() < level and rig.next < rig.order.size():
		var index := rig.order[rig.next]
		rig.next += 1
		var b := rig.sim.buildings[index]
		var cells: Array[Vector3i] = []
		for y: int in b.height:
			for x: int in b.w:
				for z: int in b.d:
					cells.append(Vector3i(x, y, z))
		rig.sim.damage_chunks(index, cells, 9999.0)
	for event: Dictionary in rig.sim.events:  # the chunks vanish; falls are not drawn in a still
		if str(event["type"]) == "chunks_broken":
			var cells: Array[Vector3i] = event["cells"]
			rig.city.chunks_broken(Num.i(event["building"]), cells, at)
	rig.sim.events.clear()


func _escalation(rig: Rig) -> EscalationView:
	for node: Node in rig.city.get_children():
		if node is EscalationView:
			return node as EscalationView
	return null


func _still(time: String, level: float) -> void:
	var rig := _rig(time)
	await Kit.frames(self, SETTLE)
	var view := _escalation(rig)
	if (_a["baseline"] == true) and view != null:
		view.queue_free()
		view = null
	_ruin_to(rig, level)
	await Kit.frames(self, 2)
	if view != null:
		for _i: int in EASE_STEPS:  # the real easing and blackout spread, run fast
			view._process(EASE_SECONDS)
	await Kit.frames(self, SETTLE)
	var name := "%s_d%s" % [time, str(level).replace(".", "")]
	Kit.still(self, _out, name)
	rig.kaiju.visible = false
	await Kit.frames(self, 3)
	Kit.still(self, _out, name + "_nokaiju")
	print(
		(
			"ESC %s level %.2f destruction %.3f blackout floors %s"
			% [time, level, rig.sim.destruction(), "n/a" if view == null else "see log"]
		)
	)
	rig.stage.queue_free()
	await process_frame
	_forget_buildings()


## BuildingView keeps baked meshes between runs (their lit windows are baked in, per time of
## day): a capture that changes time in one process must drop them or the next time reuses the
## first one's windows.
func _forget_buildings() -> void:
	BuildingView.begin_city()
	BuildingView.end_city()


## One night clip: destruction rises 0 -> --to over --seconds, frames saved as PNGs.
func _clip() -> void:
	var rig := _rig("night")
	await Kit.frames(self, SETTLE)
	var dir := _out.path_join("clip")
	DirAccess.make_dir_recursive_absolute(dir)
	var frames := int(Num.f(_a["seconds"]) * 60.0)
	var to := Num.f(_a["to"])
	for f: int in frames:
		_ruin_to(rig, to * float(f + 1) / frames)
		await process_frame
		if f % 2 == 0:  # 30 fps out of a 60 fps run
			Kit.still(self, dir, "f%04d" % (f / 2))
	print("CLIP frames ", frames / 2, " destruction ", rig.sim.destruction())
	rig.stage.queue_free()
