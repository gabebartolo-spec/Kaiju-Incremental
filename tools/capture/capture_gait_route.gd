extends SceneTree
## The croc titan at one growth step on one route in the real rampage, at the gameplay camera, for
## the motion critic (D-177 "Motion first"): walk -> 90 deg turn -> stop, or a held curve (the stick
## swept round at --sweep deg/s, the motion gate's). The route starts once he stands on the bank
## ("ROUTE starts at frame N": trim the movie there). Measures the camera on the way: where the
## drawn body sits across the frame (x, -1..1 edge to edge) and how far the camera's look-ahead
## points off his heading (deg), each 0.5 s, and their range.
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_gait_route.gd -- --stage=Behemoth --route=walk_turn
## --stage=young|Behemoth|Colossus, --route=walk_turn|curve|straight, --sweep=30, --seconds=6.5.

const Kit := preload("res://tools/capture/capture_kit.gd")
const STAGES := {
	"young": {},
	"Behemoth": {"evolve1": 1},
	"Colossus": {"evolve1": 1, "evolve2": 1},
}
const TURN_AT := 2.2
const STOP_AT := 4.4
const CURVE_FROM := 1.0

var _stage := "Behemoth"
var _route := "walk_turn"
var _sweep := 30.0
var _seconds := 6.5
var _t := -1.0
var _rampage: Rampage
var _xs: Array[float] = []
var _leads: Array[float] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--route="):
			_route = arg.substr(8)
		elif arg.begins_with("--sweep="):
			_sweep = float(arg.substr(8))
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_rampage = Rampage.new()
	var species := Content.species_def("reptilian")
	var levels: Dictionary = STAGES[_stage]
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	_rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	_rampage.scripted = _input
	root.add_child(_rampage)
	while (_t < 0.0 or _t < _seconds) and not _rampage.sim.over:
		await physics_frame
		if _t >= 0.0:
			_measure()
	print(
		(
			"CAMERA %s %s: body across the frame x %.3f..%.3f, look-ahead off heading %.0f..%.0f deg"
			% [_stage, _route, _xs.min(), _xs.max(), _leads.min(), _leads.max()]
		)
	)
	quit()


## Stands until he is on the bank, then the route: up the screen, then the stick's turn or sweep.
func _input(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {"move": Vector2.ZERO}
	if _t < 0.0:
		_t = 0.0
		print("ROUTE starts at frame %d" % Engine.get_frames_drawn())
	else:
		_t += 1.0 / 60.0
	return {"move": _stick(_t)}


func _stick(t: float) -> Vector2:
	match _route:
		"walk_turn":
			if t >= STOP_AT:
				return Vector2.ZERO
			return Vector2(0, -1) if t < TURN_AT else Vector2(1, 0)
		"curve":
			return Vector2(0, -1).rotated(-deg_to_rad(_sweep) * maxf(0.0, t - CURVE_FROM))
	return Vector2(0, -1)


## The drawn body's place across the frame and the look-ahead's angle off the heading.
func _measure() -> void:
	var cam: Camera3D = _rampage._camera
	var local := cam.global_transform.affine_inverse() * _rampage._kaiju.focus()
	var aspect := 16.0 / 9.0
	var x := local.x / (-local.z * tan(deg_to_rad(cam.fov) * 0.5) * aspect)
	var lead: Vector3 = _rampage._follow.lead
	var flat := Vector2(lead.x, lead.z / Num.f(Content.section("camera")["lead_depth_share"]))
	var off := 0.0
	if flat.length() > 0.01:
		off = rad_to_deg(absf(flat.angle_to(_rampage.sim.body.heading)))
	_xs.append(x)
	_leads.append(off)
	if roundi(_t * 60.0) % 30 == 0:
		print("t %.1f  x %+.3f  look-ahead off heading %3.0f deg" % [_t, x, off])
