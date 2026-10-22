class_name ClawTrail
extends RefCounted
## The raking claw's streak, drawn from the arm itself (BipedSwing.pose_rake): while the arm swings
## down and across, a short mark is laid between where each claw tine was last frame and where it
## is now, so the streak follows the arm's real arc from the first swing frame and each piece is
## gone a few frames later (trail_s). Three tines stacked up the claw, in ClawSlash's colour family.
## Presentation only. "claw_fx" tuning: streaks, streak_thick, streak_gap, trail_s.

var _rig: Node3D
var _marks: Array[Dictionary] = []  # {"node": MeshInstance3D, "mat": material, "left": seconds}
var _last := Vector3.INF
var _cfg := Content.section("claw_fx")
var _box := BoxMesh.new()


func _init(rig: Node3D) -> void:
	_rig = rig
	_box.size = Vector3.ONE


## One frame: `tip` is where the claw is now and `drawing` whether the arm is mid-swing (a mark
## is laid from last frame's tip); older marks fade by dt.
func update(tip: Vector3, drawing: bool, dt: float) -> void:
	for i: int in range(_marks.size() - 1, -1, -1):
		var mark := _marks[i]
		mark["left"] = Num.f(mark["left"]) - dt
		var mat: StandardMaterial3D = mark["mat"]
		mat.albedo_color.a = clampf(Num.f(mark["left"]) / Num.f(_cfg["trail_s"]), 0.0, 1.0)
		if Num.f(mark["left"]) <= 0.0:
			(mark["node"] as Node).queue_free()
			_marks.remove_at(i)
	if drawing and _last.is_finite():
		_lay(_last, tip)
	_last = tip if drawing else Vector3.INF


func _lay(from: Vector3, to: Vector3) -> void:
	var size := _rig.global_transform.basis.get_scale().x
	var streaks := Num.i(_cfg["streaks"])
	var thick := Num.f(_cfg["streak_thick"]) * size
	var length := from.distance_to(to)
	if length < 0.001 * size:
		return
	for n: int in streaks:
		var lift := Vector3.UP * (n - (streaks - 1) * 0.5) * Num.f(_cfg["streak_gap"]) * size
		var node := MeshInstance3D.new()
		node.mesh = _box
		var mat := ClawSlash.marks_material(_cfg)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rig.get_tree().root.add_child(node)
		var up := Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT
		node.look_at_from_position((from + to) * 0.5 + lift, to + lift, up)
		node.scale = Vector3(thick, thick * 0.35, length * 1.15)
		_marks.append({"node": node, "mat": mat, "left": Num.f(_cfg["trail_s"])})
