extends SceneTree
## Load-screen art (comment #92, D-140): staged 4K stills of a real dusk rampage for the loading
## overlay's rotation. Each growth stage rises in its own city (seed 0) with the play skin and
## light; the run is scripted (walk in, stomp, breath, tail lash, the beam at stage 3) and at each
## moment the tree pauses, as photo mode does, while free cameras take the moment from several
## angles: hero low, side-on, over the shoulder, a high panorama. No HUD, no breath aim.
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_load_art.gd -- --out=<dir> [--stages=1,2,3] [--graphics=max]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 30
const WALK := 60 * 5
const AFTER := 60 * 6
const BREATH_AFTER := 10  # frames after the breath strikes (its delay grows with him)
const BEAM_LEVELS := {"r_shear": 1, "r_beam": 1}  # the Behemoth with his ultimate (D-203)
const LASH_STRIKE := 12
const BEAM_STREAM := 100  # wind-up, then the stream well under way

var _out := "user://load_art"
var _stages: Array[int] = [1, 2, 3]
var _graphics := "max"
var _press := {}
var _walk := false
var _target := Vector2(INF, INF)
var _steps := 0
var _rampage: Rampage
var _cam: Camera3D


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"out": _out, "stages": "1,2,3", "graphics": _graphics})
	_out = str(a["out"])
	_graphics = str(a["graphics"])
	_stages = []
	for s: String in str(a["stages"]).split(","):
		_stages.append(int(s))
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	PlayerSettings.graphics = _graphics
	PlayerSettings.camera_motion = 0.0  # no shake in a still
	for stage: int in _stages:
		await _stage_shots(stage)
	quit()


func _stage_shots(stage: int) -> void:
	var levels: Dictionary = Kit.STAGE_LEVELS[stage - 1].duplicate()
	if stage == 3:
		levels.merge(BEAM_LEVELS)
	var stats := Kit.stats("reptilian", levels, "reptilian")
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	_rampage = Rampage.new()
	_rampage.setup(Content.species_def("reptilian"), stats, layout, 0)
	Content.set_time("dusk")  # the demo plays at dusk only (D-359)
	root.add_child(_rampage)
	_rampage.set_physics_process(false)
	var city: CityView = _rampage.get("_city")
	var stream: BuildingStream = city.get("_stream")
	while not stream.complete():
		await process_frame
	await Kit.frames(self, 10)
	_rampage.set_physics_process(true)
	for child: Node in _rampage.get_children():
		if child is BreathAim:
			child.set_physics_process(false)
			child.set_process(false)
			(child as BreathAim).visible = false
	var hud: RampageHud = _rampage.get("_hud")
	hud.visible = false
	_cam = Kit.camera(_rampage)
	_steps = 0
	_walk = false
	_target = Vector2(INF, INF)
	_rampage.scripted = _scripted
	while _rampage.sim.emerge.active:
		await physics_frame
	var tag := "s%d" % stage
	await _physics(SETTLE)
	await _moment(tag + "_form", ["hero", "front", "side", "pano"])
	_walk = true
	await _physics(WALK)
	await _moment(tag + "_smash", ["hero", "over", "side", "pano"])
	_press = {"breath": true}
	await _physics(int(_rampage.sim.strikes.breath_delay() * 60.0) + BREATH_AFTER)
	await _moment(tag + "_breath", ["side", "front", "hero"])
	_press = {"signature": true}
	await _physics(LASH_STRIKE)
	await _moment(tag + "_lash", ["side", "over", "hero"])
	if _rampage.sim.powers.has_ultimate():
		_press = {"ultimate": true}
		await _physics(BEAM_STREAM)
		await _moment(tag + "_beam", ["side", "front", "over", "pano"])
	await _physics(AFTER)
	await _moment(tag + "_after", ["over", "pano", "top", "hero"])
	_rampage.queue_free()
	await Kit.frames(self, 4)


## Holds the world still (as photo mode does) and takes the moment from each angle.
func _moment(shot: String, angles: Array) -> void:
	paused = true
	_hide_ui(root)
	_cam.current = true
	for angle: String in angles:
		_place(angle)
		await Kit.frames(self, 4)
		print("LOADART %s" % Kit.still(self, _out, "%s_%s" % [shot, angle]))
	paused = false


## Every 2D layer goes (HUD, meters, numbers, cards) but the post effects, which are the look.
func _hide_ui(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer and not child is PostFx:
			(child as CanvasLayer).visible = false
		elif child is Control and node == root:
			(child as Control).visible = false
		_hide_ui(child)


## The staged cameras, sized by the body (its height) and the game camera's distance (it grows
## with him), facing the way he faces. A camera inside a building or looking through one turns
## round him (and then rises) until its view of him is clear.
func _place(angle: String) -> void:
	var sim := _rampage.sim
	var h := sim.reach_height()
	var r := (_rampage.camera_rest * CameraTuning.zoom(sim.body_scale())).length()
	var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var fwd := Vector3(sim.facing.x, 0.0, sim.facing.y)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var up := Vector3.UP
	var off := Vector3.ZERO  # the camera's offset from his feet
	var look := up * h * 0.55  # what it looks at, from his feet
	_cam.fov = 50.0
	match angle:
		"hero":  # low, in front and to one side, looking up at him
			off = fwd * r * 0.55 + right * r * 0.3 + up * h * 0.12
			look = up * h * 0.7
			_cam.fov = 62.0
		"front":
			off = fwd * r * 1.3 - right * r * 0.45 + up * h * 0.8
		"side":  # the breath and the beam run across the frame
			off = right * r * 0.9 + fwd * r * 0.15 + up * h * 0.45
			look = fwd * h * 0.8 + up * h * 0.5
		"over":  # over his shoulder at what he is breaking
			off = -fwd * r * 0.45 + right * r * 0.3 + up * h * 1.25
			look = fwd * r * 0.9 + up * h * 0.3
		"pano":  # high and wide: the city round him
			off = -fwd * r * 1.6 + right * r * 1.5 + up * h * 2.6
			look = fwd * r * 0.7
			_cam.fov = 58.0
		"top":
			off = fwd * r * 0.3 + right * r * 0.6 + up * r * 2.2
			look = fwd * r * 0.4
			_cam.fov = 58.0
	var chest := feet + up * h * 0.5
	for lift: int in 4:
		for turn: int in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8, 9]:
			var yaw := deg_to_rad(20.0 * turn)
			var pos := feet + off.rotated(Vector3.UP, yaw) + up * h * 0.6 * lift
			if _clear(pos, chest):
				_cam.position = pos
				_cam.look_at(feet + look.rotated(Vector3.UP, yaw))
				return
	_cam.position = feet + off + up * h * 2.4
	_cam.look_at(feet + look)


## True when no standing building's box holds `from` or cuts the line to `to` (its last tenth,
## round him, may: he stands among them).
func _clear(from: Vector3, to: Vector3) -> bool:
	var lo := Vector2(minf(from.x, to.x), minf(from.z, to.z)) - Vector2.ONE * 3.0
	var hi := Vector2(maxf(from.x, to.x), maxf(from.z, to.z)) + Vector2.ONE * 3.0
	for b: RampageSim.Building in _rampage.sim.buildings:
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		for i: int in 31:
			var p := from.lerp(to, i / 34.0)
			if (
				absf(p.x - b.x) < b.w * 0.5 + 1.5
				and absf(p.z - b.z) < b.d * 0.5 + 1.5
				and p.y < b.base + b.height + 1.5
			):
				return false
	return true


func _physics(n: int) -> void:
	for _i: int in n:
		await physics_frame


## Autoplay's walk to the nearest standing building once _walk is on; one-shot presses from _press.
func _scripted(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {}
	var input := {}
	if _walk:
		if _steps % 15 == 0 or _target.x == INF:
			_target = sim.nearest_standing(sim.kaiju_pos)
		var to := _target - sim.kaiju_pos
		if _target.x != INF and to.length() >= sim.stomp_radius() * 0.5:
			input["move"] = to.normalized()
	input.merge(_press, true)
	_press = {}
	_steps += 1
	return input
