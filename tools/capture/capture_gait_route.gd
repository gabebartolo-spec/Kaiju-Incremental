extends SceneTree
## The croc titan at one growth step on one route in the real rampage, at the gameplay camera, for
## the motion critic (D-177 "Motion first"): walk east along the river road, turn back west, stop
## (--clear keeps buildings, rubble and dust off his legs), or a held curve (the stick swept round
## at --sweep deg/s, the motion gate's). The route starts once he stands on the bank
## ("ROUTE starts at frame N": trim the movie there). Measures the camera on the way: where the
## drawn body sits across the frame (x, -1..1 edge to edge) and how far the camera's look-ahead
## (across the view) is from the one his heading would give (world units), each 0.5 s, and their
## range.
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_gait_route.gd -- --stage=Behemoth --route=walk_turn
## --stage=young|Behemoth|Colossus, --route=walk_turn|curve|straight, --sweep=30, --seconds=30,
## --run=3 (the run index: its time of day), --clear=x0,z0,x1,z1 (sim space: no buildings there).

const Kit := preload("res://tools/capture/capture_kit.gd")
const STAGES := {
	"young": {},
	"Behemoth": {"evolve1": 1},
	"Colossus": {"evolve1": 1, "evolve2": 1},
}
## walk_turn: INLAND_U units inland off the river wall (the young croc's foot hung over it), then
## EAST_S s east along the road, WEST_S s back west, then he stands; the clip starts CLIP_AFTER s
## into the walk east, once it has settled (the opening turn and camera swoop left out: motion
## critic 2026-10-23), and runs CLIP_S.
const INLAND_U := 8.0
const EAST_S := 2.8
const WEST_S := 2.2
const CLIP_AFTER := 0.8
const CLIP_S := 6.4
const CURVE_FROM := 1.0

var _stage := "Behemoth"
var _route := "walk_turn"
var _sweep := 30.0
var _seconds := 30.0  # walk_turn ends with its clip
var _clear := Rect2()  # buildings left out of the city here (sim space): a bare road, no crush
var _run_index := 3  # Content.time_for_run(3) is noon: the legs read in daylight
var _t := -1.0
var _from := Vector2.INF  # where the route starts (sim space)
var _east_t := INF  # when the walk east starts (s)
var _rampage: Rampage
var _xs: Array[float] = []
var _leads: Array[float] = []
var _feet := {"both_yaw": 0.0, "run": 0.0, "worst": 0.0, "lifts": 0, "last_yaw": INF}
var _was_down: Array[bool] = [true, true]
var _csv: FileAccess  # --csv: per frame and foot, the toe (world), the yaws (steps.py)


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
		elif arg.begins_with("--run="):
			_run_index = int(arg.substr(6))
		elif arg.begins_with("--csv="):
			_csv = FileAccess.open(arg.substr(6), FileAccess.WRITE)
			_csv.store_line("t,leg,planted,wtx,wtz,flen,yaw,cyaw,syaw,state")
		elif arg.begins_with("--clear="):
			var v := arg.substr(8).split_floats(",")
			_clear = Rect2(v[0], v[1], v[2] - v[0], v[3] - v[1])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	PlayerSettings.controls_seen = true  # no first-run controls card over the shot
	_rampage = Rampage.new()
	var species := Content.species_def("reptilian")
	var levels: Dictionary = STAGES[_stage]
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var city := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var kept: Array[Dictionary] = []
	for b: Dictionary in city:
		var w := Num.f(b["w"])
		var d := Num.f(b["d"])
		var at := Rect2(Num.f(b["x"]) - w, Num.f(b["z"]) - d, 2.0 * w, 2.0 * d)  # generous either way
		if not _clear.has_area() or not _clear.intersects(at):
			kept.append(b)
	print("city: %d buildings, %d cleared" % [city.size(), city.size() - kept.size()])
	_rampage.setup(species, stats, kept, _run_index)
	_rampage.scripted = _input
	root.add_child(_rampage)
	while (_t < 0.0 or _t < _seconds) and not _rampage.sim.over:
		await physics_frame
		if _t >= 0.0:
			_measure()
	print(
		(
			"FEET %s %s: %d lifts; body yaw with both feet down %.0f deg in all, %.0f deg in a row at most"
			% [_stage, _route, _feet["lifts"], _feet["both_yaw"], _feet["worst"]]
		)
	)
	print(
		(
			"CAMERA %s %s: body across the frame x %.3f..%.3f, look-ahead off the heading's %.2f..%.2f u"
			% [_stage, _route, _xs.min(), _xs.max(), _leads.min(), _leads.max()]
		)
	)
	quit()


## Stands until he is on the bank, then the route: along the road and back, or the sweep.
func _input(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {"move": Vector2.ZERO}
	if _t < 0.0:
		_t = 0.0
		_from = sim.kaiju_pos
		print("ROUTE starts at frame %d at %s" % [Engine.get_frames_drawn(), sim.kaiju_pos])
	else:
		_t += 1.0 / 60.0
	if _route == "walk_turn" and _east_t == INF and sim.kaiju_pos.y <= _from.y - INLAND_U:
		_east_t = _t
		_seconds = _t + CLIP_AFTER + CLIP_S + 0.2
	if _east_t != INF and is_equal_approx(_t, _east_t + CLIP_AFTER):
		print("CLIP starts at frame %d" % Engine.get_frames_drawn())
	return {"move": _stick(_t)}


func _stick(t: float) -> Vector2:
	match _route:
		"walk_turn":
			var u := t - _east_t
			if _east_t == INF:
				return Vector2(0, -1)
			if u < EAST_S:
				return Vector2(1, 0)
			return Vector2(-1, 0) if u < EAST_S + WEST_S else Vector2.ZERO
		"curve":
			return Vector2(0, -1).rotated(-deg_to_rad(_sweep) * maxf(0.0, t - CURVE_FROM))
	return Vector2(0, -1)


## The drawn body's place across the frame and the look-ahead's angle off the heading.
func _measure() -> void:
	_measure_feet()
	var cam: Camera3D = _rampage._camera
	var local := cam.global_transform.affine_inverse() * _rampage._kaiju.focus()
	var aspect := 16.0 / 9.0
	var x := local.x / (-local.z * tan(deg_to_rad(cam.fov) * 0.5) * aspect)
	var cfg := Content.section("camera")
	var heading := Vector3(_rampage.sim.body.heading.x, 0.0, _rampage.sim.body.heading.y)
	var toward := 1.0 + (Num.f(cfg["lead_toward_camera"]) - 1.0) * maxf(0.0, heading.z)
	var by_heading := heading.x * CameraTuning.lead(_rampage.sim.body_scale()) * toward
	var off := _rampage._follow.lead.x - by_heading  # across the view (its only part, depth 0)
	_xs.append(x)
	_leads.append(off)
	if roundi(_t * 60.0) % 30 == 0:
		print("t %.1f  x %+.3f  look-ahead off the heading's %+.2f u" % [_t, x, off])


## Foot lifts, and how far the drawn body yaws while both feet are down (a swivel on the spot).
func _measure_feet() -> void:
	var gait := _rampage._kaiju._rig.gait as ClipGait
	var down := 0
	for i: int in 2:
		var planted: bool = gait.legs[i].planted
		if _csv != null:
			_log_foot(gait, i)
		if _was_down[i] and not planted:
			_feet["lifts"] = Num.i(_feet["lifts"]) + 1
		_was_down[i] = planted
		down += 1 if planted else 0
	var last := Num.f(_feet["last_yaw"])
	var turn := 0.0 if last == INF else absf(rad_to_deg(wrapf(gait.body_yaw - last, -PI, PI)))
	_feet["last_yaw"] = gait.body_yaw
	if down == 2:
		_feet["both_yaw"] = Num.f(_feet["both_yaw"]) + turn
		_feet["run"] = Num.f(_feet["run"]) + turn
		_feet["worst"] = maxf(Num.f(_feet["worst"]), Num.f(_feet["run"]))
	else:
		_feet["run"] = 0.0


## One --csv row: foot i's toe (world, flat), the foot's length, the body's, chest's and sim's yaw.
func _log_foot(gait: ClipGait, i: int) -> void:
	var rig := gait.rig
	var names: PackedStringArray = gait.legs[i].names
	var toe := rig.tail_world(names[2])
	var chest := rig.bone("spine2").global_transform.basis.x
	var heading := _rampage.sim.body.heading
	_csv.store_line(
		(
			"%.4f,%d,%d,%.4f,%.4f,%.4f,%.2f,%.2f,%.2f,%s"
			% [
				_t,
				i,
				int(gait.legs[i].planted),
				toe.x,
				toe.z,
				(toe - rig.bone(names[2]).global_position).length(),
				rad_to_deg(gait.body_yaw),
				rad_to_deg(atan2(-chest.x, -chest.z)),
				rad_to_deg(atan2(-heading.x, -heading.y)),
				gait.state
			]
		)
	)
