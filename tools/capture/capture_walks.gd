extends SceneTree
## The walk's weight at game speed (walk-m2 review): the reptilian at one stage, driven by the
## real sim at 60 Hz the way the rampage scene drives it (BodyContact.steer turns it on arcs, the
## head leads by turn_left), walks a course on an empty lot while a camera dollies with it.
## --course=straight (7 s), zigzag (the stick swings 70 deg every 1.5 s) or turn90 (a walking
## 90 deg turn left). --cam=side (low, square to the walk) or front34 (ahead and to one side,
## head height) or game (the rampage camera: CameraTuning offset and zoom, eased focus, no
## shake). The side and front34 cameras follow the walk's heading, eased, so a turn swings
## them round.
## --no-label leaves the label off the picture (a clip for the director).
## Prints the worst planted-foot drift (cm; a world unit is a 3.5 m storey) at the end.
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 --write-movie <out.avi> \
##     --script tools/capture/capture_walks.gd -- --stage=adult --course=zigzag --cam=side

const DT := 1.0 / 60.0
const LEVELS := {
	"baby": {},
	"adolescent": {"evolve1": 1},
	"adult": {"evolve1": 1, "evolve2": 1},
}
const WALK_FROM := 0.5
const CM_PER_UNIT := 350.0
const CAM_EASE := 1.5  # 1/s: how fast the cameras swing to the walk's heading
const FOCUS_FOLLOW := 12.0  # 1/s: the game camera's focus ease (as Rampage._place_camera)

var _stage := "adult"
var _course := "straight"
var _cam_kind := "side"
var _seconds := 9.0
var _label := ""
var _show_label := true
var _focus := Vector3.INF  # the game camera's eased focus


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--course="):
			_course = arg.substr(9)
		elif arg.begins_with("--cam="):
			_cam_kind = arg.substr(6)
		elif arg == "--no-label":
			_show_label = false
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
	_label = "%s  %s  %s" % [_stage, _course, _cam_kind]
	_run.call_deferred()


## The stick at time t (zero: stand).
func _stick(t: float) -> Vector2:
	if t < WALK_FROM:
		return Vector2.ZERO
	match _course:
		"zigzag":
			if t >= 8.0:
				return Vector2.ZERO
			var side := 1.0 if int((t - WALK_FROM) / 1.5) % 2 == 0 else -1.0
			return Vector2(0.7 * side, -1.0).normalized()
		"turn90":
			if t >= 8.0:
				return Vector2.ZERO
			return Vector2(0, -1) if t < 3.5 else Vector2(-1, 0)
	return Vector2(0, -1) if t < 7.0 else Vector2.ZERO


func _run() -> void:
	await process_frame
	var def := Content.species_def("reptilian")
	var levels: Dictionary = LEVELS.get(_stage, {})
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(0, 30)
	var world := Node3D.new()
	world.add_child(CityView.new(sim, Seeds.make("fx", 0), false))
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, KaijuModel.stage_for(sim.size_tier()))
	var bs := sim.body_scale()
	kaiju.scale = Vector3.ONE * bs
	world.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = CameraTuning.fov() if _cam_kind == "game" else 40.0
	world.add_child(cam)
	var ui := CanvasLayer.new()
	var text := Label.new()
	text.position = Vector2(20, 14)
	text.add_theme_font_size_override("font_size", 26)
	text.text = _label
	ui.add_child(text)
	if _show_label:
		world.add_child(ui)
	else:
		ui.free()
	root.add_child(world)
	var way := Vector2(0, -1)  # the cameras' eased heading
	var drift := 0.0
	var planted_at: Array[Vector3] = [Vector3.INF, Vector3.INF]  # each foot where it went down
	for f: int in int(_seconds / DT):
		var t := f * DT
		var move := _stick(t)
		sim.step(DT, move, false, 0)
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
		kaiju.animate(DT, move.length(), -sim.body.turn_left)
		way = way.slerp(sim.body.heading, minf(1.0, CAM_EASE * DT)).normalized()
		_place(cam, kaiju, way, bs)
		var slid := _slide(kaiju, planted_at)
		if t > 1.5:  # past the first steps off the stand
			drift = maxf(drift, slid)
		await process_frame
	print(
		(
			"WALKS %s worst planted-foot drift %.1f cm, walked to %v, over %s"
			% [_label, drift, sim.kaiju_pos.snapped(Vector2(0.1, 0.1)), sim.over]
		)
	)
	quit()


## How far (cm, ground plane) a planted foot's drawn bone has moved since it went down.
func _slide(kaiju: KaijuModel, planted_at: Array[Vector3]) -> float:
	var gait: ClipGait = kaiju._rig.gait
	var worst := 0.0
	for i: int in mini(2, gait.legs.size()):
		var leg: BipedGait.Leg = gait.legs[i]
		var at := kaiju._rig.tail_world(leg.names[2])  # the foot's ground end, as capture_motion
		if not leg.planted:
			planted_at[i] = Vector3.INF
		elif planted_at[i] == Vector3.INF:
			planted_at[i] = at
		else:
			var d := Vector2(at.x - planted_at[i].x, at.z - planted_at[i].z).length()
			worst = maxf(worst, d * CM_PER_UNIT)
	return worst


func _place(cam: Camera3D, kaiju: KaijuModel, way: Vector2, bs: float) -> void:
	var fwd := Vector3(way.x, 0, way.y)
	var right := fwd.cross(Vector3.UP)
	var at := kaiju.position
	var hip := kaiju.hip_height()
	if _cam_kind == "game":  # as Rampage._place_camera, without the step dip and shake
		var aim := kaiju.focus()
		_focus = (aim if _focus == Vector3.INF else _focus.lerp(aim, minf(1.0, DT * FOCUS_FOLLOW)))
		cam.position = _focus + CameraTuning.offset() * CameraTuning.zoom(bs)
		cam.look_at(_focus + Vector3(0, 3.5 * bs, 0))
		return
	if _cam_kind == "front34":
		cam.position = at + (fwd * 13.0 + right * 8.0 + Vector3(0, 5.0, 0)) * bs
		cam.look_at(at + Vector3(0, hip * 1.1, 0))
		return
	cam.position = at + right * 20.0 * bs + Vector3(0, hip * 0.6, 0)
	cam.look_at(at + Vector3(0, hip * 0.9, 0))
