extends SceneTree
## The walk's weight at game speed (walk-m2 review): the reptilian at one stage, driven by the
## real sim at 60 Hz the way the rampage scene drives it (BodyContact.steer turns it on arcs, the
## head leads by turn_left), walks a course on an empty lot while a camera dollies with it.
## --course=straight (7 s), zigzag (the stick swings 70 deg every 1.5 s), turn90 (a walking 90 deg
## turn left) or rake (it stands with a level of Claws: the sim's claw rake every 2 s, cued to the
## model as the rampage does, PowersView). --cam=side (low, square to the walk) or front34 (ahead
## and to one side, head height) or game (the rampage camera: CameraTuning offset and zoom, eased
## focus, no shake). The side and front34 cameras follow the walk's heading, eased, so a turn
## swings them round; side34 sits to one side and a little ahead, so both feet show.
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
## A foot skates when it is this near the ground (world units) and moves faster than SKATE_SPEED
## (units/s) in the world: a foot in the air is lifted, a foot on the ground is still.
const SKATE_LOW := 0.08
const SKATE_SPEED := 3.0
const WALK_FROM := 0.5
const TURN_AT := 3.5  # when the turn90 course swings the stick
const CM_PER_UNIT := 350.0
## 1/s: how fast the side cameras swing to the walk's heading; quick, so the head's distance from
## the lens (and the kaiju's size in frame) drifts under 3% over 20 frames through a turn (the
## camera is close to locked to the body).
const CAM_EASE := 14.0
const FOCUS_FOLLOW := 12.0  # 1/s: the game camera's focus ease (as Rampage._place_camera)
## The side camera frames the whole body, snout to tail tip and soles to back, with this share of
## the frame to spare on every edge (lead 2026-10-27: the snout was cut and the toes touched the
## bottom edge); its fit is taken from the drawn body's box on its first frame.
const FIT_MARGIN := 0.05
## How far the side camera sits below the box's middle (hip heights per body unit away): the old
## side view's look up, 0.3 hip heights over 20 body units, so the angle stays the same.
const SIDE_LOOK_UP := 0.3 / 20.0

var _stage := "adult"
var _course := "straight"
var _cam_kind := "side"
var _seconds := 9.0
var _label := ""
var _show_label := true
var _log := false  # --log: print the yaw-rate steps, the framing drift and the walk-off ramp
var _focus := Vector3.INF  # the game camera's eased focus
var _side_fit := Vector3.INF  # the side camera's fit: (box middle ahead, its height, distance)


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--course="):
			_course = arg.substr(9)
		elif arg.begins_with("--cam="):
			_cam_kind = arg.substr(6)
		elif arg == "--no-label":
			_show_label = false
		elif arg == "--log":
			_log = true
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
	_label = "%s  %s  %s" % [_stage, _course, _cam_kind]
	_run.call_deferred()


## The stick at time t (zero: stand).
func _stick(t: float) -> Vector2:
	if t < WALK_FROM or _course == "rake":
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
	levels = levels.duplicate()
	if _course == "rake":
		levels["claws"] = 1
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
	var yaws: Array[float] = []  # the drawn body's yaw each frame
	var heights: Array[float] = []  # the drawn kaiju's height in pixels each frame
	var steps: Array[float] = []  # how far the kaiju walked each frame (world units)
	var toes: Array[Vector3] = []  # each foot's ground end each frame, left then right
	var last_at := sim.kaiju_pos
	var planted_at: Array[Vector3] = [Vector3.INF, Vector3.INF]  # each foot where it went down
	for f: int in int(_seconds / DT):
		var t := f * DT
		var move := _stick(t)
		for event: Dictionary in sim.step(DT, move, false, 0):
			_cue(kaiju, event)
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		var run := sim.powers.run
		kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio, run.blend(), run.slams)
		kaiju.animate(DT, move.length(), -sim.body.turn_left)
		way = way.slerp(sim.body.heading, minf(1.0, CAM_EASE * DT)).normalized()
		_place(cam, kaiju, way, bs)
		if _log:
			yaws.append((kaiju._rig.gait as BipedGait).body_yaw)
			heights.append(_height_px(cam, kaiju))
			steps.append(sim.kaiju_pos.distance_to(last_at))
			var gait: ClipGait = kaiju._rig.gait
			for i: int in 2:
				toes.append(kaiju._rig.tail_world(gait.legs[i].tip))
			last_at = sim.kaiju_pos
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
	if _log:
		_print_log(yaws, heights, steps)
		_print_skate(toes)
	quit()


## The sim's claw rake to the model, as the rampage hands it on (PowersView.on_event): the windup
## cue, then the rake.
func _cue(kaiju: KaijuModel, event: Dictionary) -> void:
	match str(event["type"]):
		"swipe_windup":
			kaiju.tail_sweep(Num.f(event["side"]), "claw_windup")
		"swipe":
			kaiju.tail_sweep(Num.f(event["side"]), "claw")


## The drawn kaiju's height on screen (px): its ground point to its head.
func _height_px(cam: Camera3D, kaiju: KaijuModel) -> float:
	var head := kaiju._rig.bone("head1").global_position
	return absf(cam.unproject_position(head).y - cam.unproject_position(kaiju.position).y)


## The log (director's motion bars): the yaw rate's biggest frame-to-frame step as a share of its
## peak, the framing's biggest change over any 20 frames, and the first frames of the walk-off.
func _print_log(yaws: Array[float], heights: Array[float], steps: Array[float]) -> void:
	var rates: Array[float] = []
	for i: int in range(1, yaws.size()):
		rates.append(wrapf(yaws[i] - yaws[i - 1], -PI, PI) / DT)
	var peak := 0.0
	var step := 0.0
	for i: int in rates.size():
		peak = maxf(peak, absf(rates[i]))
		step = maxf(step, absf(rates[i] - rates[i - 1]) if i > 0 else 0.0)
	var frame := 0.0
	for i: int in range(20, heights.size()):
		frame = maxf(frame, absf(heights[i] / maxf(heights[i - 20], 1.0) - 1.0))
	var ramp := ""
	for i: int in range(int(WALK_FROM / DT), int(WALK_FROM / DT) + 14):
		ramp += "%.0f " % (steps[i] / maxf(steps[int(WALK_FROM / DT) + 40], 0.0001) * 100.0)
	print(
		(
			(
				"LOG yaw rate peak %.0f deg/s, biggest frame step %.0f%% of peak; framing change over"
				+ " 20 frames %.1f%%; walk-off ramp (%% of speed at +40 frames): %s"
			)
			% [rad_to_deg(peak), step / maxf(peak, 0.0001) * 100.0, frame * 100.0, ramp]
		)
	)


## Prints the frames a foot skated (low, and sweeping over the ground), over the walk before the
## turn (the stick's change at TURN_AT, turn90) and over the turn, and the worst speed.
func _print_skate(toes: Array[Vector3]) -> void:
	var walk := 0
	var turn := 0
	var worst := 0.0
	var ground := INF  # a planted foot's height: the lowest the toes ever are
	for toe: Vector3 in toes:
		ground = minf(ground, toe.y)
	for n: int in range(2, toes.size()):
		var at := toes[n]
		var speed := Vector2(at.x - toes[n - 2].x, at.z - toes[n - 2].z).length() / DT
		if at.y - ground < SKATE_LOW and speed > SKATE_SPEED:
			if n / 2 * DT < TURN_AT:
				walk += 1
			else:
				turn += 1
				worst = maxf(worst, speed)
	print(
		(
			"SKATE foot-frames near the ground and sweeping: walk %d, turn %d, worst %.1f units/s"
			% [walk, turn, worst]
		)
	)


## How far (cm, ground plane) a planted foot's drawn bone has moved since it went down.
func _slide(kaiju: KaijuModel, planted_at: Array[Vector3]) -> float:
	var gait: ClipGait = kaiju._rig.gait
	var worst := 0.0
	for i: int in mini(2, gait.legs.size()):
		var leg: BipedLeg = gait.legs[i]
		var at := kaiju._rig.tail_world(leg.tip)  # the toe tip the gait locks, as capture_motion
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
	if _cam_kind == "side34":  # to one side and a little ahead, hip height: both feet in frame
		cam.position = at + (fwd * 10.0 + right * 30.0) * bs + Vector3(0, hip * 1.0, 0)
		cam.look_at(at + Vector3(0, hip * 0.9, 0))
		return
	if _side_fit == Vector3.INF:
		_side_fit = _fit_side(cam, kaiju, fwd, right)
	var mid := at + fwd * _side_fit.x + Vector3(0, _side_fit.y, 0)
	cam.position = mid + right * _side_fit.z - Vector3(0, SIDE_LOOK_UP * _side_fit.z * hip / bs, 0)
	cam.look_at(mid)


## The side camera's fit: the middle of the drawn body's box (ahead of its node along the walk, and
## its height) and the distance from it at which the box's length and height fill the frame less
## FIT_MARGIN on every edge (vertical fov, the window's aspect; the box's near side counted).
func _fit_side(cam: Camera3D, kaiju: KaijuModel, fwd: Vector3, right: Vector3) -> Vector3:
	var box := AABB()
	var first := true
	for node: Node in kaiju.find_children("*", "VisualInstance3D", true, false):
		var vis := node as VisualInstance3D
		if not vis.is_visible_in_tree():
			continue
		var b := vis.global_transform * vis.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var lo := INF
	var hi := -INF
	var near := 0.0
	for i: int in 8:
		var d := box.get_endpoint(i) - kaiju.position
		lo = minf(lo, d.dot(fwd))
		hi = maxf(hi, d.dot(fwd))
		near = maxf(near, d.dot(right))
	var bottom := minf(box.position.y, 0.0)
	var top := box.end.y
	var size := cam.get_viewport().get_visible_rect().size
	var half_h := tan(deg_to_rad(cam.fov * 0.5)) * (1.0 - 2.0 * FIT_MARGIN)
	var half_w := half_h * size.x / size.y
	var dist := maxf(0.5 * (hi - lo) / half_w, 0.5 * (top - bottom) / half_h) + near
	print(
		(
			"SIDE_FIT length %.2f height %.2f near %.2f distance %.2f"
			% [hi - lo, top - bottom, near, dist]
		)
	)
	return Vector3(0.5 * (lo + hi), 0.5 * (top + bottom), dist)
