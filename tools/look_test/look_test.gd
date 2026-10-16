extends SceneTree
## Look test (throwaway, 2026-10-17): the same reptile adult doing the same walk, turn and roar
## in the real city, drawn one of three ways, so three runs can be laid side by side:
##   A = the current voxel-per-bone rig (KaijuRig as the game builds it)
##   B = the Tripo mesh, GPU-skinned from the same rig pose (tools/look_test/kaiju_skin.gd)
##   C = A's voxels as one watertight skinned lattice surface, same skin and pose
##   N = no kaiju (city only), the baseline for the frame cost
## Every run is deterministic (fixed fps, the motion capture's script), so frame n of each run is
## the same moment.
##
##   godot --path . --windowed --write-movie out.avi --fixed-fps 60 \
##     --script tools/look_test/look_test.gd -- --variant=B --cam=game --mesh_dir=<export_skin out>
## --stills=<dir>: also saves the side frames used for the joint crops, with hip and knee pixel
## positions (stills.json). Prints the per-frame cost at the end (LOOKTEST line).

const FPS := 60.0
const CAMERA_OFFSET := Vector3(0, 27, 19)  # scenes/rampage.gd
const BODY_SCALE := 1.3  # adult
const SIDE_DISTANCE := 21.0
const STILL_FRAMES: Array[int] = [150, 165, 180, 195, 210, 225]
const TITLES := {
	"A": "A  CURRENT: voxels, rigid per bone",
	"B": "B  SMOOTH: Tripo mesh, Tripo auto-rig weights",
	"C": "C  VOXEL-SNAP: rigid voxels on a smooth skin",
	"N": "N  no kaiju (cost baseline)",
}

var _variant := "A"
var _cam := "game"
var _mesh_dir := ""
var _stills := ""
var _seconds := 15.0
var _shake := 0.0
var _c_mode := "rigid"
var _kaiju: KaijuModel
var _skin_name := "skin.kmesh"
var _still_frames: Array[int] = STILL_FRAMES.duplicate()


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="):
			_variant = arg.substr(10)
		elif arg.begins_with("--cam="):
			_cam = arg.substr(6)
		elif arg.begins_with("--mesh_dir="):
			_mesh_dir = arg.substr(11)
		elif arg.begins_with("--stills="):
			_stills = arg.substr(9)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--c_mode="):
			_c_mode = arg.substr(9)
		elif arg.begins_with("--skin="):
			_skin_name = arg.substr(7)
		elif arg.begins_with("--still_frames="):
			_still_frames.clear()
			for part: String in arg.substr(15).split(","):
				_still_frames.append(int(part))
	_run.call_deferred()


## capture_motion.gd's script: stand, walk, curve, sharp turn, walk, stop, roar, reverse.
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


func _event_at(t: float) -> String:
	if t < 1.0:
		return "STAND"
	if t < 4.5:
		return "WALK"
	if t < 7.2:
		return "TURN"
	if t < 10.0:
		return "WALK"
	if t < 12.0:
		return "ROAR"
	return "WALK"


func _run() -> void:
	await process_frame
	var empty: Array[Dictionary] = []
	var sim := RampageSim.new({}, Content.tuning(), empty, Seeds.make("army", 0))
	var stage := Node3D.new()
	var city := CityView.new(sim, Seeds.make("fx", 0), false)
	stage.add_child(city)
	var ui := CanvasLayer.new()
	var title := _label(ui, 40, Vector2(0, 16))
	title.text = TITLES[_variant]
	var event := _label(ui, 30, Vector2(0, 70))
	stage.add_child(ui)
	var def: Dictionary = Content.species_def("reptilian")
	var stats: Dictionary = def["stats"]
	var speed := Num.f(stats["speed"])
	var interval := Num.f(stats["stomp_interval"])
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, "adult")
	kaiju.scale = Vector3.ONE * BODY_SCALE
	kaiju.foot_planted.connect(
		func(_side: String, strength: float, at: Vector3) -> void:
			city.fx.dust(at + Vector3(0, 0.2, 0), 1.1 * BODY_SCALE * (0.5 + strength))
			_shake = maxf(_shake, 0.14 * strength)
	)
	stage.add_child(kaiju)
	_kaiju = kaiju
	var skin: Node3D = null
	var fill: Node3D = null
	if _variant == "B" or _variant == "C":
		var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
		skin = (load("res://tools/look_test/kaiju_skin.gd") as GDScript).new()
		rig.add_child(skin)
		var mode := "skin" if _variant == "B" else _c_mode
		var c_mesh := "voxel_rigid.kmesh" if _c_mode == "rigid" else "voxel.kmesh"
		var mesh := _mesh_dir.path_join(_skin_name if _variant == "B" else c_mesh)
		skin.call("setup", rig, mesh, _mesh_dir.path_join("skin_albedo.jpg"), mode)
		if _variant == "C" and _c_mode == "rigid":
			# Round 2 filler: the watertight lattice, inset, shows wherever rigid cubes part.
			fill = (load("res://tools/look_test/kaiju_skin.gd") as GDScript).new()
			rig.add_child(fill)
			fill.call("setup", rig, _mesh_dir.path_join("voxel_fill.kmesh"), "", "voxel")
	elif _variant == "N":
		kaiju.visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0 if _cam == "game" else 40.0
	stage.add_child(cam)
	root.add_child(stage)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var pos := Vector2.ZERO
	var at := Vector3.ZERO
	var facing := Vector2(0, -1)
	var stomp_in := interval
	var roared := false
	var cpu_usec := 0
	var gpu_ms := 0.0
	var gpu_n := 0
	var prims := 0
	var stills: Array[Dictionary] = []
	var most := {"knee": [-1.0, 0], "hip": [-1.0, 0], "jaw": [-1.0, 0]}
	var jaw_ref := Quaternion.IDENTITY
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
		if skin != null:
			skin.call("sync")
		if fill != null:
			fill.call("sync")
		cpu_usec += Time.get_ticks_usec() - t0
		event.text = _event_at(t)
		_shake = maxf(0.0, _shake - dt * 3.0)
		_place(cam, at)
		var jitter := Vector3(sin(t * 91.0), cos(t * 77.0), 0) * _shake * 0.6
		cam.position += cam.global_transform.basis * jitter
		await process_frame
		if frames > 30:
			gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			gpu_n += 1
			prims += RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
			)
		var bent := _bends(kaiju)
		# The jaw counts by how far it opens in the roar from where it sat just before.
		var jaw_q: Quaternion = bent["jaw"]
		if frames == 595:
			jaw_ref = jaw_q
		bent["jaw"] = jaw_q.angle_to(jaw_ref) if t >= 10.0 else -1.0
		for key: String in most:
			var best: Array = most[key]
			var value: float = bent[key]
			if value > best[0]:
				most[key] = [value, frames]
		if _stills != "" and _cam != "game" and frames in _still_frames:
			stills.append(_still(cam, kaiju, frames))
		frames += 1
	if _stills != "":
		var f := FileAccess.open(_stills.path_join("stills_%s.json" % _variant), FileAccess.WRITE)
		f.store_string(JSON.stringify(stills, " "))
		f.close()
	print("FIND knee=%d hip=%d jaw=%d" % [most["knee"][1], most["hip"][1], most["jaw"][1]])
	print(
		(
			"LOOKTEST %s %s: rig+skin cpu %.3f ms/frame, frame gpu %.3f ms, %d primitives/frame"
			% [
				_variant,
				_cam,
				cpu_usec / 1000.0 / maxi(1, frames),
				gpu_ms / maxi(1, gpu_n),
				prims / maxi(1, gpu_n),
			]
		)
	)
	quit()


func _label(ui: CanvasLayer, size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(1920, size + 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	ui.add_child(label)
	return label


## Saves the frame and where the near (right) hip and knee are on it.
func _still(cam: Camera3D, kaiju: KaijuModel, frame: int) -> Dictionary:
	var path := _stills.path_join("%s_%d.png" % [_variant, frame])
	root.get_viewport().get_texture().get_image().save_png(path)
	var out := {"frame": frame, "png": path}
	for joint: String in ["leg_r0", "leg_r1", "leg_r2", "leg_l0", "leg_l1", "jaw", "head1"]:
		var node: Node3D = kaiju.find_children(joint, "Node3D", true, false)[0]
		out[joint] = cam.unproject_position(node.global_position)
	return out


## How bent the near knee and hip are, and how open the jaw is (radians), this frame.
func _bends(kaiju: KaijuModel) -> Dictionary:
	var at := {}
	var turn := {}
	for joint: String in ["spine0", "spine1", "leg_r0", "leg_r1", "leg_r2", "jaw", "head1"]:
		var node: Node3D = kaiju.find_children(joint, "Node3D", true, false)[0]
		at[joint] = node.global_position
		turn[joint] = node.global_basis.orthonormalized()
	var r0: Vector3 = at["leg_r0"]
	var r1: Vector3 = at["leg_r1"]
	var r2: Vector3 = at["leg_r2"]
	var s0: Vector3 = at["spine0"]
	var s1: Vector3 = at["spine1"]
	var jaw: Basis = turn["jaw"]
	var skull: Basis = turn["head1"]
	return {
		"knee": (r1 - r0).angle_to(r2 - r1),
		"hip": (s1 - s0).angle_to(r0 - r1),
		"jaw": (skull.inverse() * jaw).get_rotation_quaternion(),
	}


func _place(cam: Camera3D, at: Vector3) -> void:
	if _cam == "game":
		var zoom := 0.75 + 0.4 * BODY_SCALE
		cam.position = at + CAMERA_OFFSET * zoom
		cam.look_at(at + Vector3(0, 3.5 * BODY_SCALE, 0))
		return
	if _cam == "profile":
		# Always square to the kaiju's right side, close: for the joint crops.
		var right := _kaiju.global_basis.x.normalized()
		cam.position = at + right * SIDE_DISTANCE * 0.8 + Vector3(0, 4.0 * BODY_SCALE, 0)
		cam.look_at(at + Vector3(0, 3.6 * BODY_SCALE, 0))
		return
	cam.position = at + Vector3(SIDE_DISTANCE, 4.0 * BODY_SCALE, 0)
	cam.look_at(at + Vector3(0, 3.6 * BODY_SCALE, 0))
