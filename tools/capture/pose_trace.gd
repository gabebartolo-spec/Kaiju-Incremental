class_name PoseTrace
extends RefCounted
## capture_motion.gd's --pose-trace rows (see there): remembers every bone's last position.

var _last_bones := PackedVector3Array()


## One pose-trace row: the body root bone's world place and heading, and the summed movement of
## every bone since the last frame (0 means dead still).
func row(kaiju: KaijuModel, t: float, event: String) -> String:
	for node: Node in kaiju.find_children("*", "KaijuRig", true, false):
		var rig := node as KaijuRig
		var names := rig.bone_names()
		var body := rig.bone(names[0])
		var fwd := -body.global_transform.basis.z
		var moved := 0.0
		var now := PackedVector3Array()
		for n: String in names:
			now.append(rig.tail_world(n))
		if _last_bones.size() == now.size():
			for i: int in now.size():
				moved += (now[i] - _last_bones[i]).length()
		_last_bones = now
		var holding := 0
		if rig.gait is HexapodGait:
			holding = int((rig.gait as HexapodGait).holding)
		var p := body.global_position
		return (
			"%.4f,%s,%.4f,%.4f,%.4f,%d,%.5f,%.4f"
			% [t, event, p.x, p.z, atan2(-fwd.x, -fwd.z), holding, moved, kaiju.rotation.y]
		)
	return "%.4f" % t
