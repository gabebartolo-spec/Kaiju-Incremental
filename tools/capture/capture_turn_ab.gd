extends SceneTree
## The croc titan's U-turn in the real rampage at the gameplay camera, for the director's A/B
## (D-187, "Heavier, slower": show me the stride at an about-face both ways): walk east along the
## river road, then the stick is reversed and held. --turn-slow sets the share of full stride the
## body keeps at an about-face (A: 0.1, it steps round almost on the spot; B: 0.5, it keeps the
## walking arc). The route starts once he stands on the bank; "CLIP starts at frame N" marks the
## shot (trim the movie there) and the run ends CLIP_S later.
##   godot --path . --resolution 1280x720 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_turn_ab.gd -- --stage=Behemoth --turn-slow=0.1
## --stage=Behemoth|Colossus, --run=3 (the run index: its time of day), --clear=x0,z0,x1,z1 (sim
## space: no buildings there, a bare road), --log=<csv> (per frame from the route's start: the
## sim's origin and heading, the drawn node and root bone, the drawn body yaw, both feet's planted
## flag and toe; the footfalls print as "FALL t side x z"; --headless, no movie, for numbers).
## The shot keeps him at full health (no low-health edge) and the breath's aim wedge hidden (the
## breath is held cooling down), so nothing but the turn is in frame.

const Kit := preload("res://tools/capture/capture_kit.gd")
const STAGES := {"Behemoth": {"evolve1": 1}, "Colossus": {"evolve1": 1, "evolve2": 1}}
## INLAND_U units inland off the river wall, then EAST_S s east along the road, then west.
const INLAND_U := 8.0
const EAST_S := 2.8
const CLIP_AFTER := 0.8
const CLIP_S := 8.0

var _stage := "Behemoth"
var _turn_slow := -1.0
var _run_index := 3  # Content.time_for_run(3) is noon: the legs read in daylight
var _clear := Rect2()
var _t := -1.0
var _from := Vector2.INF
var _east_t := INF
var _rampage: Rampage
var _log: FileAccess


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--turn-slow="):
			_turn_slow = float(arg.substr(12))
		elif arg.begins_with("--run="):
			_run_index = int(arg.substr(6))
		elif arg.begins_with("--log="):
			_log = FileAccess.open(arg.substr(6), FileAccess.WRITE)
			(
				_log
				. store_line(
					"t,kx,kz,heading,facing,stride,phase,nx,nz,rx,rz,body_yaw,state,speed,lp,lx,lz,rp,rx2,rz2"
				)
			)
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
		var at := Rect2(Num.f(b["x"]) - w, Num.f(b["z"]) - d, 2.0 * w, 2.0 * d)
		if not _clear.has_area() or not _clear.intersects(at):
			kept.append(b)
	print("city: %d buildings, %d cleared" % [city.size(), city.size() - kept.size()])
	_rampage.setup(species, stats, kept, _run_index)
	_rampage.scripted = _input
	root.add_child(_rampage)
	_rampage._kaiju.foot_planted.connect(
		func(side: String, _strength: float, at: Vector3) -> void:
			if _log != null and side != "tail" and _t >= 0.0:
				print("FALL %.3f %s %.3f %.3f" % [_t, side, at.x, at.z])
	)
	var end := INF
	while _t < 0.0 or _t < end:
		await physics_frame
		if _log != null and _t >= 0.0:
			_log_frame()
		if _east_t != INF and end == INF:
			end = _east_t + CLIP_AFTER + CLIP_S + 0.2
	print("done: %s turn_slow %.2f" % [_stage, _rampage.sim.body._turn_slow])
	quit()


## One --log row: the sim's body, the drawn node and root bone, the drawn yaw, both feet.
func _log_frame() -> void:
	var sim := _rampage.sim
	var kaiju: KaijuModel = _rampage._kaiju
	var gait := kaiju._rig.gait as ClipGait
	var root := kaiju.focus()
	var row := (
		"%.4f,%.4f,%.4f,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f,%s,%.3f"
		% [
			_t,
			sim.kaiju_pos.x,
			sim.kaiju_pos.y,
			rad_to_deg(atan2(sim.body.heading.x, -sim.body.heading.y)),
			rad_to_deg(atan2(sim.facing.x, -sim.facing.y)),
			sim.body.stride,
			sim.body.phase,
			kaiju.position.x,
			kaiju.position.z,
			root.x,
			root.z,
			rad_to_deg(gait.body_yaw),
			gait.state,
			gait.speed
		]
	)
	for i: int in 2:
		var toe := gait.rig.tail_world(gait.legs[i].names[2])
		row += ",%d,%.4f,%.4f" % [int(gait.legs[i].planted), toe.x, toe.z]
	_log.store_line(row)


## Stands until he is on the bank, then inland, east along the road, and the stick reversed.
func _input(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {"move": Vector2.ZERO}
	sim.hp = sim.max_hp  # no low-health edge in the shot
	sim.ability_ready_in = 1.0e9  # the breath's aim wedge (BreathAim) hides while it cools down
	if _t < 0.0:
		_t = 0.0
		_from = sim.kaiju_pos
		if _turn_slow >= 0.0:
			sim.body._turn_slow = _turn_slow
		print("ROUTE starts at frame %d at %s" % [Engine.get_frames_drawn(), sim.kaiju_pos])
	else:
		_t += 1.0 / 60.0
	if _east_t == INF and sim.kaiju_pos.y <= _from.y - INLAND_U:
		_east_t = _t
	if _east_t != INF and is_equal_approx(_t, _east_t + CLIP_AFTER):
		print("CLIP starts at frame %d" % Engine.get_frames_drawn())
	if _east_t == INF:
		return {"move": Vector2(0, -1)}
	return {"move": Vector2(1, 0) if _t - _east_t < EAST_S else Vector2(-1, 0)}
