extends SceneTree
## Records a kaiju's locomotion as the game drives it (sim position, heading, stage speed, stomps on
## the beat, a roar): walk, curve, turn, stand, roar, walk. Prints foot drift, rig cost.
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_motion.gd -- --species=reptilian --stage=adult --cam=game
## --cam=side: fixed side (+x); --cam=fixed holds by the first walk. Footfalls dust, dip as in play.
## --trace=<file.csv>: t, pelvis height and forward speed per frame (the rhythm plot).
## --pose-trace=<file.csv>: per frame the event, body x/z and heading, a hard hold, bone motion.
## Headless (no movie) prints the measurements; slide also in cm (a world unit = a 3.5 m storey).

const FPS := 60.0
const Rig := preload("res://tools/capture/motion_rig.gd")
const SCALES := {"baby": 0.5, "adolescent": 0.9, "adult": 1.3}
const CM_PER_UNIT := 350.0
const SIDE_PIVOT := 9.2  # s: the side clip's kaiju turns side-on when it stops (roar in profile)

var plants := PackedStringArray()  # every footfall: time, foot, world position, strength
var _species := "reptilian"
var _stage := "adult"
var _shot: Rig.Shot
var _cam := "game"
var _seconds := 15.0
var _roar_at := 10.0  # s; capture_clips.gd moves it
var _trace := ""
var _pose_trace := ""
var _poser := PoseTrace.new()
var _dip := 0.0
var _dip_shown := 0.0  # eased toward _dip, as Rampage eases its camera offset
var _focus := Vector3.ZERO
var _line: Line2D
var _guide: Line2D
var _label: Label
var _time := 0.0
var _tint := false
var _plumb: Line2D
var _shoulders := Rig.Shoulders.new()  # straight walk (2.0-4.5 s): the shoulder line


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--cam="):
			_cam = arg.substr(6)
		elif arg.begins_with("--pose-trace="):
			_pose_trace = arg.substr(13)
		elif arg.begins_with("--trace="):
			_trace = arg.substr(8)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg == "--tint":
			_tint = true
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
	_guide = Line2D.new()
	_guide.default_color = Color(1, 1, 1, 0.8)
	_guide.width = 2.0
	_line = Line2D.new()
	_line.default_color = Color(1, 0.2, 0.2)
	_line.width = 3.0
	ui.add_child(_guide)
	_plumb = Line2D.new()
	_plumb.default_color = Color(1, 1, 1, 0.8)
	_plumb.width = 2.0
	ui.add_child(_plumb)
	ui.add_child(_line)
	stage.add_child(ui)
	var def: Dictionary = Content.species_def(_species)
	var stats: Dictionary = def["stats"]
	var tuning := CityGrowth.tuning_for(
		Content.tuning(), ["baby", "adolescent", "adult"].find(_stage) + 1
	)
	var speed := Num.f(Growth.stage_stats(stats, tuning)["speed"])
	var interval := Num.f(stats["stomp_interval"])
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(_species, colors, _stage)
	_shot = Rig.Shot.new(_cam, _species, kaiju)
	var body_scale: float = SCALES.get(_stage, 1.0)
	kaiju.scale = Vector3.ONE * body_scale
	stage.add_child(kaiju)
	if _tint:
		Rig.tint_bones.call_deferred(kaiju)
	# Footfalls as in the rampage (Rampage._on_footfall): dust, a pale ring, a camera dip.
	kaiju.foot_planted.connect(
		func(side: String, strength: float, at: Vector3) -> void:
			var size := body_scale * (0.2 + strength)
			var tail := side == "tail"  # a tail slam throws its own puffs (Fx.shockwave)
			if not tail:
				city.fx.footfall(at + Vector3(0, 0.2, 0), Rampage.FOOTFALL_DUST * size)
			city.fx.shockwave(at, Rampage.FOOTFALL_RING * size, tail)
			var dip := (
				Rampage.FOOTFALL_DIP * maxf(Rampage.FOOTFALL_DIP_FLOOR, body_scale) * strength
			)
			_dip = maxf(_dip, dip)
			var row := [_time, side, at.x, at.y, at.z, strength, dip, _dip_px(dip, body_scale)]
			plants.append("%.3f,%s,%.3f,%.3f,%.3f,%.2f,%.3f,%.1f" % row)
	)
	var rows := PackedStringArray(["t,pelvis_y,forward_speed"])
	var feet := PackedStringArray(["t,foot,planted,x,z"])
	var poses := PackedStringArray(["t,event,x,z,yaw,holding,bone_motion,model_yaw"])
	plants.append("t,foot,x,y,z,strength,camera_dip_units,camera_dip_px_at_1080p")
	var last_pelvis := Vector3.ZERO
	var cam := Camera3D.new()
	cam.fov = CameraTuning.fov() if _cam == "game" else 40.0
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
		elif _cam == "side" and t >= SIDE_PIVOT:
			facing = Vector2(0, -1)  # standing, it turns side-on to the camera for the roar
		else:
			facing = _standing_facing(t, facing)
		at = at.lerp(Vector3(pos.x, 0, pos.y), minf(1.0, dt * 12.0))
		kaiju.position = at
		kaiju.rotation.y = lerp_angle(
			kaiju.rotation.y, atan2(-facing.x, -facing.y), minf(1.0, dt * 10.0)
		)
		stomp_in -= dt
		if stomp_in <= 0.0:
			stomp_in += interval
			kaiju.stomp()
		if t >= _roar_at and not roared:
			roared = true
			kaiju.roar()
		var t0 := Time.get_ticks_usec()
		kaiju.animate(dt, move.length())
		var spent := Time.get_ticks_usec() - t0
		worst_usec = maxi(worst_usec, spent)
		total_usec += spent
		_label.text = _event_at(t)
		_dip = move_toward(_dip, 0.0, dt * Rampage.DIP_RECOVER * _dip + dt * 0.05)
		# Cameras lock to the body as drawn (KaijuModel.focus), from the first frame (PR #54).
		_focus = kaiju.focus()
		_shot.place(
			cam,
			_focus if _cam in ["game", "side"] else at,
			Vector3(facing.x, 0, facing.y),
			body_scale
		)
		if _cam == "game":
			_dip_shown = _dip  # at once, as Rampage drops its camera (PR #54: eased, it was 1 px)
			cam.position.y -= _dip_shown * CameraTuning.zoom(body_scale)
		Rig.trace_feet(kaiju, t, feet)
		if _pose_trace != "":
			poses.append(_poser.row(kaiju, t, _event_at(t)))
		if _cam == "rear":
			_level_line(kaiju, cam)
			_plumb_line(kaiju, cam)
		if t >= 2.0 and t < 4.5:
			_shoulders.measure(kaiju, Vector3(facing.x, 0, facing.y))
		var pelvis := Rig.pelvis_of(kaiju)
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
		f = FileAccess.open(_trace.get_basename() + "_feet.csv", FileAccess.WRITE)
		f.store_string(String.chr(10).join(feet))
		f.close()
	if _pose_trace != "":
		var pf := FileAccess.open(_pose_trace, FileAccess.WRITE)
		pf.store_string(String.chr(10).join(poses))
		pf.close()
	if _shoulders.seen():
		print(_shoulders.report(_species, _stage))
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


## What the script is doing at time t, shown on the clip.
## Where a standing kaiju faces at time t (capture_clips.gd turns it on the spot).
func _standing_facing(_t: float, facing: Vector2) -> Vector2:
	return facing


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


## The shoulder line (red, through the two arm roots) over a level guide (white), with its tilt.
func _level_line(kaiju: KaijuModel, cam: Camera3D) -> void:
	for node: Node in kaiju.find_children("*", "KaijuRig", true, false):
		var rig := node as KaijuRig
		if not rig.has_bone("arm_l0") or not rig.has_bone("arm_r0"):
			return
		var a := rig.bone("arm_l0").global_position
		var b := rig.bone("arm_r0").global_position
		var sa := cam.unproject_position(a)
		var sb := cam.unproject_position(b)
		_line.points = PackedVector2Array([sa, sb])
		var mid := (sa + sb) * 0.5
		var half := absf(sb.x - sa.x) * 0.75
		_guide.points = PackedVector2Array([mid - Vector2(half, 0), mid + Vector2(half, 0)])
		var tilt := rad_to_deg(atan2(b.y - a.y, Vector2(b.x - a.x, b.z - a.z).length()))
		_label.text += "   shoulder tilt %.1f deg" % tilt


## How many pixels a camera dip moves the picture at 1080p for the gameplay camera.
func _dip_px(dip: float, body_scale: float) -> float:
	var zoom := CameraTuning.zoom(body_scale)
	var dist := CameraTuning.offset().length() * zoom
	return dip * zoom / (2.0 * dist * tan(deg_to_rad(CameraTuning.fov()) * 0.5)) * 1080.0


## A fixed plumb line straight up from the line of travel (where the spine should stay).
func _plumb_line(kaiju: KaijuModel, cam: Camera3D) -> void:
	var foot := kaiju.global_position
	var top := foot + Vector3.UP * maxf(1.0, _shoulders.height * 1.1)
	_plumb.points = PackedVector2Array([cam.unproject_position(foot), cam.unproject_position(top)])
