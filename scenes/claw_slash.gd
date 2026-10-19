class_name ClawSlash
extends RefCounted
## The claw swipe's cue (Claws, D-095): three hot claw streaks drawn across the rake in front of
## the croc at arm height, opening along the stroke as the arm strikes and fading in a quarter
## second. Additive and thin, so it never hides the kaiju (D-025). Presentation only.

const SECONDS := 0.25
## Waits out the arm's lift (BipedSwing.RAKE_SECONDS x RAKE_LIFT) so the streaks open with the
## strike.
const DELAY := BipedSwing.RAKE_SECONDS * BipedSwing.RAKE_LIFT
const STREAKS := 3
## The stroke runs down and across (rad), mirrored by the raking side.
const TILT := 0.45
## Where the streaks sit: a share of the way from the rake's near edge to its far edge, and a
## share of its top (arm height).
const DEPTH_SHARE := 0.35
const HEIGHT_SHARE := 0.6
## Streak thickness and spacing as shares of the rake's half width.
const THICK_SHARE := 0.05
const GAP_SHARE := 0.22


## event: a sim "swipe" event (side, near, far, width, top); ahead: the facing on the ground.
static func play(
	parent: Node3D, kaiju_at: Vector3, ahead: Vector3, event: Dictionary, tint: Color
) -> void:
	var half := Num.f(event["width"])
	var depth := lerpf(Num.f(event["near"]), Num.f(event["far"]), DEPTH_SHARE)
	var side := Num.f(event["side"])
	var across := ahead.cross(Vector3.UP).normalized()
	var root := Node3D.new()
	parent.add_child(root)
	var centre := kaiju_at + ahead * depth
	centre.y = Num.f(event["top"]) * HEIGHT_SHARE
	var frame := Basis(across, Vector3.UP, -ahead).rotated(ahead, side * TILT)
	root.global_transform = Transform3D(frame, centre)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = tint.lightened(0.5)
	var box := BoxMesh.new()
	box.size = Vector3(half * 2.0, half * THICK_SHARE, half * THICK_SHARE)
	box.material = mat
	for n: int in STREAKS:
		var streak := MeshInstance3D.new()
		streak.mesh = box
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.position = Vector3(0, (n - 1) * half * GAP_SHARE, 0)
		root.add_child(streak)
	root.scale = Vector3(0.01, 1, 1)
	root.visible = false
	var tween := root.create_tween()
	tween.tween_interval(DELAY)
	tween.tween_callback(root.show)
	tween.tween_property(root, "scale:x", 1.0, SECONDS * 0.4)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, SECONDS)
	tween.tween_callback(root.queue_free)
