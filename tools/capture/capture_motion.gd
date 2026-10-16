extends SceneTree
## Records a kaiju's locomotion the way the game drives it (sim-style position and heading,
## stomps on the sim's beat, a roar), for the motion review. Walk, curve, a sharp turn, stand,
## roar, walk again. Prints the planted-foot drift and the rig's cost per frame at the end.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_motion.gd -- --species=reptilian --stage=adult --cam=game
## --cam=side tracks the kaiju from one fixed side (the world +x side, no orbit); --cam=fixed
## holds still beside the first straight walk (for judging foot slide by eye). Footfalls kick
## dust and nudge the camera as in the rampage; the scripted events are labelled on screen.
## --trace=<file.csv>: t, pelvis height and forward speed per frame (the rhythm plot).
## Headless (no movie) just prints the measurements. Slide is
## also given in cm, taking a world unit as one storey (3.5 m).

const FPS := 60.0
const CAMERA_OFFSET := Vector3(0, 27, 19)  # scenes/rampage.gd
const SCALES := {"baby": 0.5, "adolescent": 0.9, "adult": 1.3}
const CM_PER_UNIT := 350.0

var _species := "reptilian"
var _stage := "adult"
var _cam := "game"
var _seconds := 15.0
var _trace := ""
var _shake := 0.0
var _label: Label
var _time := 0.0
## Every footfall: time, which foot, where (world), strength (written next to the trace).
var plants := PackedStringArray()


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--cam="):
			_cam = arg.substr(6)
		elif arg.begins_with("--trace="):
			_trace = arg.substr(8)
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
	var city := CityView.new(sim, Seeds.make("fx", 0), false)
	stage.add_child(city)
	var ui := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(24, 18)
	_label.add_theme_font_size_override("font_size", 28)
	ui.add_child(_label)
	stage.add_child(ui)
	var def: Dictionary = Content.species_def(_species)
	var stats: Dictionary = def["stats"]
	var speed := Num.f(stats["speed"])
	var interval := Num.f(stats["stomp_interval"])
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(_species, colors, _stage)
	var body_scale: float = SCALES.get(_stage, 1.0)
	kaiju.scale = Vector3.ONE * body_scale
	stage.add_child(kaiju)
	kaiju.foot_planted.connect(
		func(side: String, strength: float, at: Vector3) -> void:
			plants.append("%.3f,%s,%.3f,%.3f,%.3f,%.2f" % [_time, side, at.x, at.y, at.z, strength])
			city.fx.dust(at + Vector3(0, 0.2, 0), 1.1 * body_scale * (0.5 + strength))
			_shake = maxf(_shake, 0.14 * strength)
	)
	var rows := PackedStringArray(["t,pelvis_y,forward_speed"])
	plants.append("t,foot,x,y,z,strength")
	var last_pelvis := Vector3.ZERO
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
		_time = t
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
		_label.text = _event_at(t)
		_shake = maxf(0.0, _shake - dt * 3.0)
		_place(cam, at, body_scale)
		var jitter := Vector3(sin(t * 91.0), cos(t * 77.0), 0) * _shake * 0.6
		cam.position += cam.global_transform.basis * jitter
		var pelvis := _pelvis_of(kaiju)
		if frames > 0:
			var fwd := Vector3(facing.x, 0, facing.y)
			rows.append("%.4f,%.4f,%.4f" % [t, pelvis.y, (pelvis - last_pelvis).dot(fwd) / dt])
		last_pelvis = pelvis
		await process_frame
		frames += 1
	if _trace != "":
		var f := FileAccess.open(_trace, FileAccess.WRITE)
		f.store_string(String.chr(10).join(rows))
		f.close()
		f = FileAccess.open(_trace.get_basename() + "_plants.csv", FileAccess.WRITE)
		f.store_string(String.chr(10).join(plants))
		f.close()
	var drift := kaiju.foot_drift()
	var hip := kaiju.hip_height()
	print(
		(
			"MOTION %s %s: foot drift max %.4f (%.1f cm, %.2f%% of hip %.2f); rig %.3f ms avg, %.3f worst"
			% [
				_species,
				_stage,
				drift,
				drift * CM_PER_UNIT,
				100.0 * drift / maxf(0.0001, hip),
				hip,
				total_usec / 1000.0 / maxi(1, frames),
				worst_usec / 1000.0,
			]
		)
	)
	quit()


func _place(cam: Camera3D, at: Vector3, body_scale: float) -> void:
	if _cam == "fixed":
		cam.position = Vector3(34.0, 3.0 * body_scale + 3.0, -9.0)
		cam.look_at(Vector3(0, 2.5 * body_scale, -9.0))
		return
	if _cam == "game":
		var zoom := 0.75 + 0.4 * body_scale
		cam.position = at + CAMERA_OFFSET * zoom
		cam.look_at(at + Vector3(0, 3.5 * body_scale, 0))
		return
	cam.position = at + Vector3(16.0, 4.0, 0) * body_scale
	cam.look_at(at + Vector3(0, 3.6, 0) * body_scale)


## What the script is doing at time t, shown on the clip.
func _event_at(t: float) -> String:
	if t < 1.0:
		return "STAND (stomps)"
	if t < 4.5:
		return "WALK"
	if t < 6.5:
		return "CURVE"
	if t < 7.2:
		return "SHARP TURN"
	if t < 9.0:
		return "WALK"
	if t < 10.0:
		return "STOP (stomps)"
	if t < 12.0:
		return "ROAR" if t < 11.8 else "STAND"
	return "REVERSE + WALK"


## World position of the pelvis bone (the root of the trunk), or the model origin.
func _pelvis_of(kaiju: KaijuModel) -> Vector3:
	for node: Node in kaiju.find_children("spine0", "Node3D", true, false):
		return (node as Node3D).global_position
	return kaiju.global_position
