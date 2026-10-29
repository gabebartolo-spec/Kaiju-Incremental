extends RefCounted
## What tools/capture/capture_motion.gd reads off the rig and where it puts its camera: the pelvis,
## every foot's plant, the shoulder line over a straight walk, the --tint colours, and the shot
## (--cam=...). Split out of capture_motion.gd to keep it under the size cap; nothing is changed.

const Kit := preload("res://tools/capture/capture_kit.gd")


## World position of the pelvis bone (the root of the trunk), or the model origin.
static func pelvis_of(kaiju: KaijuModel) -> Vector3:
	for node: Node in kaiju.find_children("spine0", "Node3D", true, false):
		return (node as Node3D).global_position
	return kaiju.global_position


## Every foot's world position and whether it is planted, each frame (the slide trace).
static func trace_feet(kaiju: KaijuModel, t: float, into: PackedStringArray) -> void:
	for node: Node in kaiju.find_children("*", "KaijuRig", true, false):
		var rig := node as KaijuRig
		if rig.gait is BipedGait:
			for leg: BipedGait.Leg in (rig.gait as BipedGait).legs:
				var p := rig.tail_world(leg.tip)
				into.append("%.4f,%s,%d,%.4f,%.4f" % [t, leg.names[0], int(leg.planted), p.x, p.z])
		elif rig.gait is HexapodGait:
			for leg: HexapodGait.Leg in (rig.gait as HexapodGait).legs:
				var p := rig.tail_world(leg.names[2])
				into.append("%.4f,%s,%d,%.4f,%.4f" % [t, leg.id, int(leg.planted), p.x, p.z])


## --tint: each bone's voxels in one flat colour (arm roots red, forearms yellow, hands magenta,
## head cyan, chest white), to see which bone carries a stray piece in motion.
static func tint_bones(kaiju: KaijuModel) -> void:
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


## The shoulder centre against the line of travel over the straight walk (2.0-4.5 s): lateral
## offset (world units), tilt and yaw (deg), each min and max, and the height of the head bone.
class Shoulders:
	extends RefCounted
	var lo := INF
	var hi := -INF
	var tilt := Vector2(INF, -INF)  # min, max (deg)
	var yaw := Vector2(INF, -INF)
	var height := 0.0

	func measure(kaiju: KaijuModel, fwd: Vector3) -> void:
		for node: Node in kaiju.find_children("*", "KaijuRig", true, false):
			var rig := node as KaijuRig
			if not rig.has_bone("arm_l0") or not rig.has_bone("arm_r0"):
				return
			var a := rig.bone("arm_l0").global_position
			var b := rig.bone("arm_r0").global_position
			var right := fwd.cross(Vector3.UP).normalized()
			var side := ((a + b) * 0.5 - kaiju.global_position).dot(right)
			lo = minf(lo, side)
			hi = maxf(hi, side)
			var flat := Vector3(b.x - a.x, 0, b.z - a.z)
			var tilt_now := rad_to_deg(atan2(b.y - a.y, flat.length()))
			tilt = Vector2(minf(tilt.x, tilt_now), maxf(tilt.y, tilt_now))
			var yaw_now := rad_to_deg(asin(clampf(flat.normalized().dot(fwd), -1.0, 1.0)))
			yaw = Vector2(minf(yaw.x, yaw_now), maxf(yaw.y, yaw_now))
			if rig.has_bone("head1"):
				height = maxf(height, rig.bone("head1").global_position.y - kaiju.global_position.y)

	## True once a frame of the straight walk was measured.
	func seen() -> bool:
		return hi > lo

	func report(species: String, stage: String) -> String:
		var p2p := hi - lo
		var line := "SHOULDERS %s %s straight walk 2.0-4.5 s: lateral drift %.3f (%.2f%% of height %.2f)"
		line += "; tilt %.2f..%.2f deg (swing %.2f); yaw %.2f..%.2f deg (swing %.2f)"
		var vals := [species, stage, p2p, 100.0 * p2p / maxf(0.001, height), height]
		vals += [tilt.x, tilt.y, tilt.y - tilt.x, yaw.x, yaw.y, yaw.y - yaw.x]
		return line % vals


## Where the camera stands for --cam=<kind>, and what it looks at.
class Shot:
	extends RefCounted
	var kind := ""
	var species := ""
	var model: KaijuModel

	func _init(p_kind: String, p_species: String, p_model: KaijuModel) -> void:
		kind = p_kind
		species = p_species
		model = p_model

	func place(cam: Camera3D, at: Vector3, fwd: Vector3, body_scale: float) -> void:
		var right := fwd.cross(Vector3.UP).normalized()
		if kind == "front34":  # ahead and to one side, at head height: the roar's hinge and gape
			cam.position = at + (fwd * 13.0 + right * 8.0 + Vector3(0, 8.5, 0)) * body_scale
			cam.look_at(at + Vector3(0, 7.5, 0) * body_scale)
			return
		if kind == "front34w":  # the same angle, wider and lower: the whole body, arms included
			cam.position = at + (fwd * 19.0 + right * 12.0 + Vector3(0, 6.0, 0)) * body_scale
			cam.look_at(at + Vector3(0, 4.8, 0) * body_scale)
			return
		if kind == "rear":  # straight behind at shoulder height: the shoulder line against level
			cam.position = at + (-fwd * 17.0 + Vector3(0, 7.0, 0)) * body_scale
			cam.look_at(at + Vector3(0, 6.5, 0) * body_scale)
			return
		if kind == "fixed":
			cam.position = Vector3(34.0, 3.0 * body_scale + 3.0, -9.0)
			cam.look_at(Vector3(0, 2.5 * body_scale, -9.0))
			return
		if kind == "game":
			Kit.place_game_camera(cam, model, body_scale)
			return
		if species == "cephalopod":  # a wide body needs a wider shot
			cam.position = at + Vector3(16.0 * 1.4, 4.0 * 1.4, 0) * body_scale
			cam.look_at(at + Vector3(0, 3.6, 0) * body_scale)
			return
		cam.position = at + Vector3(22.0, 5.0, 0) * body_scale  # side: the whole body in frame
		cam.look_at(at + Vector3(0, 4.8, 0) * body_scale)
