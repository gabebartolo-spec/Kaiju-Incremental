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
const Kit := preload("res://tools/capture/capture_kit.gd")
const SCALES := {"baby": 0.5, "adolescent": 0.9, "adult": 1.3}
const CM_PER_UNIT := 350.0
## The side clip's kaiju turns side-on to the camera when it stops (s), so the roar is in profile.
const SIDE_PIVOT := 9.2

## Every footfall: time, which foot, where (world), strength (written next to the trace).
var plants := PackedStringArray()
var _species := "reptilian"
var _stage := "adult"
var _model: KaijuModel
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
## Straight walk (2.0-4.5 s): shoulder-centre lateral offset, tilt and yaw (deg), each min/max.
var _sh_lo := INF
var _sh_hi := -INF
var _sh_tilt := Vector2(INF, -INF)  # min, max (deg)
var _sh_yaw := Vector2(INF, -INF)
var _height := 0.0


func _initialize() -> void:
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
	_model = kaiju
	var body_scale: float = SCALES.get(_stage, 1.0)
	kaiju.scale = Vector3.ONE * body_scale
	stage.add_child(kaiju)
	if _tint:
		_tint_bones.call_deferred(kaiju)
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
		_place(
			cam,
			_focus if _cam in ["game", "side"] else at,
			Vector3(facing.x, 0, facing.y),
			body_scale
		)
		if _cam == "game":
			_dip_shown = _dip  # at once, as Rampage drops its camera (PR #54: eased, it was 1 px)
			cam.position.y -= _dip_shown * CameraTuning.zoom(body_scale)
		_trace_feet(kaiju, t, feet)
		if _pose_trace != "":
			poses.append(_poser.row(kaiju, t, _event_at(t)))
		if _cam == "rear":
			_level_line(kaiju, cam)
			_plumb_line(kaiju, cam)
		if t >= 2.0 and t < 4.5:
			_measure_shoulders(kaiju, Vector3(facing.x, 0, facing.y))
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
		f = FileAccess.open(_trace.get_basename() + "_feet.csv", FileAccess.WRITE)
		f.store_string(String.chr(10).join(feet))
		f.close()
	if _pose_trace != "":
		var pf := FileAccess.open(_pose_trace, FileAccess.WRITE)
		pf.store_string(String.chr(10).join(poses))
		pf.close()
	if _sh_hi > _sh_lo:
		var p2p := _sh_hi - _sh_lo
		var line := "SHOULDERS %s %s straight walk 2.0-4.5 s: lateral drift %.3f (%.2f%% of height %.2f)"
		line += "; tilt %.2f..%.2f deg (swing %.2f); yaw %.2f..%.2f deg (swing %.2f)"
		var tilt := _sh_tilt
		var yaw := _sh_yaw
		var vals := [_species, _stage, p2p, 100.0 * p2p / maxf(0.001, _height), _height]
		vals += [tilt.x, tilt.y, tilt.y - tilt.x, yaw.x, yaw.y, yaw.y - yaw.x]
		print(line % vals)
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


func _place(cam: Camera3D, at: Vector3, fwd: Vector3, body_scale: float) -> void:
	var right := fwd.cross(Vector3.UP).normalized()
	if _cam == "front34":  # ahead and to one side, at head height: the roar's hinge and gape
		cam.position = at + (fwd * 13.0 + right * 8.0 + Vector3(0, 8.5, 0)) * body_scale
		cam.look_at(at + Vector3(0, 7.5, 0) * body_scale)
		return
	if _cam == "front34w":  # the same angle, wider and lower: the whole body, arms included
		cam.position = at + (fwd * 19.0 + right * 12.0 + Vector3(0, 6.0, 0)) * body_scale
		cam.look_at(at + Vector3(0, 4.8, 0) * body_scale)
		return
	if _cam == "rear":  # straight behind at shoulder height: the shoulder line against level
		cam.position = at + (-fwd * 17.0 + Vector3(0, 7.0, 0)) * body_scale
		cam.look_at(at + Vector3(0, 6.5, 0) * body_scale)
		return
	if _cam == "fixed":
		cam.position = Vector3(34.0, 3.0 * body_scale + 3.0, -9.0)
		cam.look_at(Vector3(0, 2.5 * body_scale, -9.0))
		return
	if _cam == "game":
		Kit.place_game_camera(cam, _model, body_scale)
		return
	if _species == "cephalopod":  # a wide body needs a wider shot
		cam.position = at + Vector3(16.0 * 1.4, 4.0 * 1.4, 0) * body_scale
		cam.look_at(at + Vector3(0, 3.6, 0) * body_scale)
		return
	cam.position = at + Vector3(22.0, 5.0, 0) * body_scale  # side: the whole body in frame
	cam.look_at(at + Vector3(0, 4.8, 0) * body_scale)


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


## World position of the pelvis bone (the root of the trunk), or the model origin.
func _pelvis_of(kaiju: KaijuModel) -> Vector3:
	for node: Node in kaiju.find_children("spine0", "Node3D", true, false):
		return (node as Node3D).global_position
	return kaiju.global_position


## Every foot's world position and whether it is planted, each frame (the slide trace).
func _trace_feet(kaiju: KaijuModel, t: float, into: PackedStringArray) -> void:
	for node: Node in kaiju.find_children("*", "KaijuRig", true, false):
		var rig := node as KaijuRig
		if rig.gait is BipedGait:
			for leg: BipedGait.Leg in (rig.gait as BipedGait).legs:
				var p := rig.tail_world(leg.names[2])
				into.append("%.4f,%s,%d,%.4f,%.4f" % [t, leg.names[0], int(leg.planted), p.x, p.z])
		elif rig.gait is HexapodGait:
			for leg: HexapodGait.Leg in (rig.gait as HexapodGait).legs:
				var p := rig.tail_world(leg.names[2])
				into.append("%.4f,%s,%d,%.4f,%.4f" % [t, leg.id, int(leg.planted), p.x, p.z])


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


## --tint: each bone's voxels in one flat colour (arm roots red, forearms yellow, hands magenta,
## head cyan, chest white), to see which bone carries a stray piece in motion.
func _tint_bones(kaiju: KaijuModel) -> void:
	var hues := {
		"arm_l0": Color.RED,
		"arm_r0": Color.RED,
		"arm_l1": Color.YELLOW,
		"arm_r1": Color.YELLOW,
		"arm_l2": Color.MAGENTA,
		"arm_r2": Color.MAGENTA,
		"head0": Color.CYAN,
		"spine2": Color.WHITE
	}
	for node: Node in kaiju.find_children("*", "KaijuRig", true, false):
		var rig := node as KaijuRig
		for b: String in rig.bone_names():
			var mat := StandardMaterial3D.new()
			mat.albedo_color = hues.get(b, Color(0.25, 0.4, 0.25))
			for m: Node in rig.bone(b).get_children():
				if m is GeometryInstance3D:
					(m as GeometryInstance3D).material_override = mat


## The shoulder centre against the line of travel: lateral offset (world units), tilt and yaw.
func _measure_shoulders(kaiju: KaijuModel, fwd: Vector3) -> void:
	for node: Node in kaiju.find_children("*", "KaijuRig", true, false):
		var rig := node as KaijuRig
		if not rig.has_bone("arm_l0") or not rig.has_bone("arm_r0"):
			return
		var a := rig.bone("arm_l0").global_position
		var b := rig.bone("arm_r0").global_position
		var right := fwd.cross(Vector3.UP).normalized()
		var side := ((a + b) * 0.5 - kaiju.global_position).dot(right)
		_sh_lo = minf(_sh_lo, side)
		_sh_hi = maxf(_sh_hi, side)
		var flat := Vector3(b.x - a.x, 0, b.z - a.z)
		var tilt := rad_to_deg(atan2(b.y - a.y, flat.length()))
		_sh_tilt = Vector2(minf(_sh_tilt.x, tilt), maxf(_sh_tilt.y, tilt))
		var yaw := rad_to_deg(asin(clampf(flat.normalized().dot(fwd), -1.0, 1.0)))
		_sh_yaw = Vector2(minf(_sh_yaw.x, yaw), maxf(_sh_yaw.y, yaw))
		if rig.has_bone("head1"):
			_height = maxf(_height, rig.bone("head1").global_position.y - kaiju.global_position.y)


## A fixed plumb line straight up from the line of travel (where the spine should stay).
func _plumb_line(kaiju: KaijuModel, cam: Camera3D) -> void:
	var foot := kaiju.global_position
	var top := foot + Vector3.UP * maxf(1.0, _height * 1.1)
	_plumb.points = PackedVector2Array([cam.unproject_position(foot), cam.unproject_position(top)])
