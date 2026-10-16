extends SceneTree
## Joint close-ups for the voxel skin (D-041): drives a kaiju through capture_motion.gd's script
## (walk, curve, sharp turn, stop, roar, reverse) with a camera square to its right side, and
## finds, by measuring every frame, the joints that bend most. Run twice per kaiju:
##   godot --headless --path . --script tools/capture/capture_skin.gd -- --species=insectoid --find
## prints JOINTS bone@frame ... (the 3 most-bent joints, each at its worst frame); then
##   godot --path . --windowed --script tools/capture/capture_skin.gd -- --species=insectoid \
##     --stills=<dir> --frames=<f1,f2,f3> [--kaiju-rigid]
## saves <dir>/<variant>_<frame>.png and <variant>.json (each bone's pixel position per frame).
## Variant is "rigid" with --kaiju-rigid, else "skin".

const FPS := 60.0
const SCALES := {"baby": 0.5, "adolescent": 0.9, "adult": 1.3}
const DISTANCE := 17.0

var _species := "reptilian"
var _stage := "adult"
var _find := false
var _stills := ""
var _frames: Array[int] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg == "--find":
			_find = true
		elif arg.begins_with("--stills="):
			_stills = arg.substr(9)
		elif arg.begins_with("--out=") and _stills == "":  # CI captures (capture.yml) pass --out
			_stills = arg.substr(6)
		elif arg.begins_with("--frames="):
			for part: String in arg.substr(9).split(","):
				_frames.append(int(part))
	_run.call_deferred()


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
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(_species, colors, _stage)
	var body_scale: float = SCALES.get(_stage, 1.0)
	kaiju.scale = Vector3.ONE * body_scale
	stage.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	root.add_child(stage)
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var variant := "rigid" if VoxelSkin.show_rigid_voxels else "skin"
	var worst := {}  # bone -> [bend, frame]
	var shots: Array[Dictionary] = []
	var pos := Vector2.ZERO
	var at := Vector3.ZERO
	var facing := Vector2(0, -1)
	var stomp_in := Num.f(stats["stomp_interval"])
	var roared := false
	var dt := 1.0 / FPS
	var last: int = _frames.max() if not _frames.is_empty() else int(15.0 * FPS)
	for frame: int in last + 1:
		var t := frame / FPS
		var move := _input_at(t)
		if move.length() > 0.05:
			pos += move.limit_length(1.0) * Num.f(stats["speed"]) * dt
			facing = move.normalized()
		at = at.lerp(Vector3(pos.x, 0, pos.y), minf(1.0, dt * 12.0))
		kaiju.position = at
		kaiju.rotation.y = lerp_angle(
			kaiju.rotation.y, atan2(-facing.x, -facing.y), minf(1.0, dt * 10.0)
		)
		stomp_in -= dt
		if stomp_in <= 0.0:
			stomp_in += Num.f(stats["stomp_interval"])
			kaiju.stomp()
		if t >= 10.0 and not roared:
			roared = true
			kaiju.roar()
		kaiju.animate(dt, move.length())
		var right := kaiju.global_basis.x.normalized()
		cam.position = at + right * DISTANCE * body_scale + Vector3(0, 4.0 * body_scale, 0)
		cam.look_at(at + Vector3(0, 3.6 * body_scale, 0))
		await process_frame
		if _find:
			_measure(rig, frame, worst)
		elif frame in _frames:
			var path := _stills.path_join("%s_%d.png" % [variant, frame])
			root.get_viewport().get_texture().get_image().save_png(path)
			var px := {}
			for bone_name: String in rig.bone_names():
				var p := cam.unproject_position(rig.bone(bone_name).global_position)
				px[bone_name] = [p.x, p.y]
			shots.append({"frame": frame, "png": path, "bones": px})
	if _find:
		var ranked := worst.keys()
		ranked.sort_custom(
			func(a: String, b: String) -> bool: return Num.f(worst[a][0]) > Num.f(worst[b][0])
		)
		var picks: Array[String] = []
		for bone_name: String in ranked.slice(0, 3):
			var best: Array = worst[bone_name]
			picks.append("%s@%d" % [bone_name, best[1]])
		if worst.has("jaw") and not picks.has("jaw@%d" % worst["jaw"][1]):
			var jaw: Array = worst["jaw"]
			picks.append("jaw@%d" % jaw[1])  # the roar, always worth a look
		print("JOINTS ", " ".join(picks))
	else:
		var f := FileAccess.open(_stills.path_join(variant + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(shots))
		f.close()
	quit()


## Each joint's bend this frame (the turn between a bone and its parent beyond their rest
## angle), kept at its worst; only joints on the side facing the camera (or the midline) count.
func _measure(rig: KaijuRig, frame: int, worst: Dictionary) -> void:
	for bone_name: String in rig.bone_names():
		var parent := rig.parent_of(bone_name)
		var far_side := rig.head_of(bone_name).x < -0.3  # the camera is on the kaiju's right (+x)
		if (
			parent == ""
			or far_side
			or bone_name.begins_with("tail")
			or bone_name.begins_with("antenna")
		):
			continue
		var now := (
			(rig.bone(parent).global_basis.orthonormalized().inverse())
			* rig.bone(bone_name).global_basis.orthonormalized()
		)
		var rest := rig.rest_of(bone_name).basis.orthonormalized()
		var bend := (rest.inverse() * now).get_rotation_quaternion().get_angle()
		var best: Array = worst.get(bone_name, [-1.0, 0])
		if bend > best[0]:
			worst[bone_name] = [bend, frame]
