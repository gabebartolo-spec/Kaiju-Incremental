extends SceneTree
## Records a kaiju's locomotion the way the game drives it (sim-style position and heading,
## stomps on the sim's beat, a roar), for the motion review. Walk, curve, a sharp turn, stand,
## roar, walk again. Prints the planted-foot drift and the rig's cost per frame at the end.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_motion.gd -- --species=reptilian --stage=adult --cam=game
## --cam=side follows close from the side. Headless (no movie) just prints the measurements.

const FPS := 60.0
const CAMERA_OFFSET := Vector3(0, 27, 19)  # scenes/rampage.gd
const SCALES := {"baby": 0.5, "adolescent": 0.9, "adult": 1.3}

var _species := "reptilian"
var _stage := "adult"
var _cam := "game"
var _seconds := 15.0
var _side_dir := Vector3(0, 0, -1)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--cam="):
			_cam = arg.substr(6)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
	_run.call_deferred()


## Where the stick points at time t (sim input), or zero to stand.
func _input_at(t: float) -> Vector2:
	if t < 1.0:
		return Vector2.ZERO
	if t < 4.5:
		return Vector2(0, -1)
	if t < 6.5:
		var a := (t - 4.5) * 0.6
		return Vector2(sin(a), -cos(a))
	if t < 9.0:
		return Vector2(-1, -0.3).normalized()
	if t < 12.0:
		return Vector2.ZERO
	return Vector2(0.3, 1).normalized()


func _run() -> void:
	await process_frame
	var empty: Array[Dictionary] = []
	var sim := RampageSim.new({}, Content.tuning(), empty, Seeds.make("army", 0))
	var stage := Node3D.new()
	stage.add_child(CityView.new(sim, Seeds.make("fx", 0), false))
	var def: Dictionary = Content.species_def(_species)
	var stats: Dictionary = def["stats"]
	var speed := Num.f(stats["speed"])
	var interval := Num.f(stats["stomp_interval"])
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(_species, colors, _stage)
	var body_scale: float = SCALES.get(_stage, 1.0)
	kaiju.scale = Vector3.ONE * body_scale
	stage.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = 55.0 if _cam == "game" else 40.0
	stage.add_child(cam)
	root.add_child(stage)
	var pos := Vector2.ZERO
	var at := Vector3.ZERO
	var facing := Vector2(0, -1)
	var stomp_in := interval
	var roared := false
	var worst_usec := 0
	var total_usec := 0
	var frames := 0
	var dt := 1.0 / FPS
	while frames < int(_seconds * FPS):
		var t := frames / FPS
		var move := _input_at(t)
		if move.length() > 0.05:
			pos += move.limit_length(1.0) * speed * dt
			facing = move.normalized()
		at = at.lerp(Vector3(pos.x, 0, pos.y), minf(1.0, dt * 12.0))
		kaiju.position = at
		kaiju.rotation.y = lerp_angle(
			kaiju.rotation.y, atan2(-facing.x, -facing.y), minf(1.0, dt * 10.0)
		)
		stomp_in -= dt
		if stomp_in <= 0.0:
			stomp_in += interval
			kaiju.stomp()
		if t >= 10.0 and not roared:
			roared = true
			kaiju.roar()
		var t0 := Time.get_ticks_usec()
		kaiju.animate(dt, move.length())
		var spent := Time.get_ticks_usec() - t0
		worst_usec = maxi(worst_usec, spent)
		total_usec += spent
		_place(cam, at, facing, body_scale)
		await process_frame
		frames += 1
	var drift := kaiju.foot_drift()
	var hip := kaiju.hip_height()
	print(
		(
			"MOTION %s %s: foot drift max %.4f (%.2f%% of hip %.2f); rig %.3f ms avg, %.3f worst"
			% [
				_species,
				_stage,
				drift,
				100.0 * drift / maxf(0.0001, hip),
				hip,
				total_usec / 1000.0 / maxi(1, frames),
				worst_usec / 1000.0,
			]
		)
	)
	quit()


func _place(cam: Camera3D, at: Vector3, facing: Vector2, body_scale: float) -> void:
	if _cam == "game":
		var zoom := 0.75 + 0.4 * body_scale
		cam.position = at + CAMERA_OFFSET * zoom
		cam.look_at(at + Vector3(0, 3.5 * body_scale, 0))
		return
	_side_dir = _side_dir.lerp(Vector3(facing.x, 0, facing.y), 0.02).normalized()
	var fwd := _side_dir
	var side := fwd.cross(Vector3.UP).normalized()
	cam.position = at + (side * 16.0 + Vector3(0, 4.0, 0) + fwd * 2.0) * body_scale
	cam.look_at(at + Vector3(0, 3.6, 0) * body_scale)
