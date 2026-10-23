class_name ClawTrail
extends RefCounted
## The claw rake's streak, impact flash and claw glint, drawn for the game camera, not glued to the
## hand (which the body hides behind the torso at the hit; critic rounds 1 and 2): a slash ribbon
## authored from the swing's own arc (ClawSweep: from the cocked hand's last visible
## spot, across over the body at the snout line, out past the far flank) whose head reaches the
## snout line on the sim's hit frame, three soft claw marks with a tapered tail, ramped in over two
## frames and faded from the tail, drawn over the body; at the hit a flash (white-hot core, streak
## colour) with line sparks fanning along the sweep and (in ClawSlash) street dust; before it a
## glint on the cocked claw so the wind-up reads on a dark street. One ImmediateMesh redrawn every
## frame from the rake's clock. Presentation only. "claw_fx" tuning: slash_*, streak_color,
## streak_thick.

const STEPS := 20
const FAN := 16
const SPARKS := 8
## Half a mark's width, as a share of streak_thick; the marks are this many half-widths apart.
const MARK_HALF := 0.35
const MARK_GAP := 2.4
const FLASH_ALPHA: Array[float] = [1.0, 0.7, 0.4, 0.15]

var _rig: Node3D
var _view: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _cfg := Content.section("claw_fx")
var _drawn := false
# This frame's camera and body scale, set by _look().
var _eye := Vector3.ZERO
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _size := 1.0


func _init(rig: Node3D) -> void:
	_rig = rig


## True when this frame has the slash, flash or glint on screen (for the tests).
func drawn() -> bool:
	return _drawn


## Draws this frame's effects from the rake's clock (nothing when no rake runs).
func sweep(rake: ClawRake) -> void:
	_mesh.clear_surfaces()
	_drawn = false
	if _view != null:
		_view.visible = false
	if not rake.active() or not rake.sweep.is_set() or not _rig.is_inside_tree():
		return
	var rel := rake.t - rake.hit_time()
	var glint := _glinting(rake.t, rel)
	var slashing := _slashing(rel)
	var flashing := rel >= 0.0 and rel < Num.f(_cfg["slash_flash_s"])
	if not (glint or slashing or flashing):
		return
	_ensure_view()
	_look()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if glint:
		_fan(rake.sweep.tip_world(), 0.12 * _size, (0.6 + 0.4 * sin(rake.t * 40.0)) * 0.8)
	if slashing:
		_slash(rake.sweep.path_world(), rel)
	if flashing:
		_flash(rake, rel)
	_mesh.surface_end()
	_view.visible = true
	_drawn = true


func _glinting(at: float, rel: float) -> bool:
	return at >= Num.f(_cfg["slash_glint_from_s"]) and rel < -Num.f(_cfg["slash_pre_s"])


func _slashing(rel: float) -> bool:
	return rel >= -Num.f(_cfg["slash_pre_s"]) and rel <= _slash_end()


## Seconds past the hit when the slash has faded away.
func _slash_end() -> float:
	return Num.f(_cfg["slash_post_s"]) + Num.f(_cfg["slash_fade_s"])


## This frame's camera and body scale.
func _look() -> void:
	var cam := _rig.get_viewport().get_camera_3d()
	_eye = cam.global_position if cam != null else _rig.global_position + Vector3(0, 8, 30)
	_right = cam.global_basis.x if cam != null else Vector3.RIGHT
	_up = cam.global_basis.y if cam != null else Vector3.UP
	_size = _rig.global_transform.basis.get_scale().x


## The ribbon `rel` seconds from the hit: its head runs the curve from -slash_pre_s to slash_post_s,
## then the tail catches up (the streak fades from the tail).
func _slash(path: Array[Vector3], rel: float) -> void:
	var pre := Num.f(_cfg["slash_pre_s"])
	var post := Num.f(_cfg["slash_post_s"])
	var head := clampf((rel + pre) / (pre + post), 0.0, 1.0)
	var length := Num.f(_cfg["slash_len"])
	var tail := maxf(0.0, head - length)
	if rel > post:
		tail = lerpf(
			1.0 - length, 1.0, clampf((rel - post) / Num.f(_cfg["slash_fade_s"]), 0.0, 1.0)
		)
	var ramp := clampf((rel + pre) / Num.f(_cfg["slash_ramp_s"]), 0.0, 1.0)
	if tail < head:
		_ribbon(path, tail, head, ramp)


## The impact: a flash at the hit, brightest on its first frame, and the line sparks.
func _flash(rake: ClawRake, rel: float) -> void:
	var count := FLASH_ALPHA.size()
	var frame := clampi(int(rel / Num.f(_cfg["slash_flash_s"]) * count), 0, count - 1)
	var at := rake.sweep.hit_world()
	var alpha := FLASH_ALPHA[frame]
	_fan(at, Num.f(_cfg["slash_flash_size"]) * _size * (1.0 + 0.2 * frame), alpha)
	_sparks(at, rake.sweep.path_world(), frame, alpha)


func _ensure_view() -> void:
	if _view != null:
		return
	_view = MeshInstance3D.new()
	_view.mesh = _mesh
	_view.material_override = ClawSlash.ribbon_material()
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.extra_cull_margin = 100.0
	_rig.get_tree().root.add_child(_view)


func _color(alpha: float) -> Color:
	var c := Color(str(_cfg["streak_color"]))
	c.a = alpha
	return c


func _core(alpha: float) -> Color:
	var c := Color(str(_cfg["streak_color"])).lerp(Color.WHITE, 0.6)
	c.a = alpha
	return c


func _vertex(at: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(at)


## The sweep's point at p (0..1): a quadratic curve through the start, the hit (p = 0.5) and the
## end.
func _curve(path: Array[Vector3], p: float) -> Vector3:
	var q := 1.0 - p
	return path[0] * q * q + path[1] * 2.0 * q * p + path[2] * p * p


func _slope(path: Array[Vector3], p: float) -> Vector3:
	return (path[1] - path[0]) * 2.0 * (1.0 - p) + (path[2] - path[1]) * 2.0 * p


## A soft ribbon of three claw marks along the curve from p_tail to p_head: bright at the head, the
## tail tapered to a point and faded, the edges fading out (no stair-stepped bands).
func _ribbon(path: Array[Vector3], p_tail: float, p_head: float, amp: float) -> void:
	var half := Num.f(_cfg["streak_thick"]) * _size * MARK_HALF
	for mark: int in range(-1, 2):
		var before: Array[Array] = []
		for k: int in STEPS + 1:
			var u := float(k) / STEPS
			var p := lerpf(p_tail, p_head, u)
			var c := _curve(path, p)
			var across := _slope(path, p).cross((_eye - c).normalized()).normalized()
			var w := half * smoothstep(0.0, 0.3, u)
			var centre := c + across * mark * half * MARK_GAP
			var alpha := amp * smoothstep(0.0, 0.35, u) * (1.0 - 0.3 * absi(mark))
			var row: Array[Array] = [
				[centre - across * w, _color(0.0)],
				[centre, _core(alpha)],
				[centre + across * w, _color(0.0)],
			]
			if k > 0:
				for side: int in 2:  # the left cell, then the right one
					_tri(before[side], before[side + 1], row[side])
					_tri(before[side + 1], row[side + 1], row[side])
			before = row


## One triangle from three [point, colour] pairs.
func _tri(a: Array, b: Array, c: Array) -> void:
	for pair: Array in [a, b, c]:
		var at: Vector3 = pair[0]
		var color: Color = pair[1]
		_vertex(at, color)


## A soft disc facing the camera: a white-hot core fading to the streak colour and out.
func _fan(at: Vector3, radius: float, alpha: float) -> void:
	for i: int in FAN:
		var a0 := TAU * i / FAN
		var a1 := TAU * (i + 1) / FAN
		_vertex(at, _core(alpha))
		_vertex(at + (_right * cos(a0) + _up * sin(a0)) * radius, _color(0.0))
		_vertex(at + (_right * cos(a1) + _up * sin(a1)) * radius, _color(0.0))


## Line sparks fanning from the hit along the sweep's direction on screen: bright at the root, gone
## at the tip, longer each frame.
func _sparks(at: Vector3, path: Array[Vector3], frame: int, alpha: float) -> void:
	var slope := _slope(path, 0.5)
	var along := Vector2(slope.dot(_right), slope.dot(_up)).normalized()
	for i: int in SPARKS:
		var spread := deg_to_rad(lerpf(-60.0, 60.0, float(i) / (SPARKS - 1)))
		var d2 := along.rotated(spread)
		var d3 := _right * d2.x + _up * d2.y
		var side := _right * -d2.y + _up * d2.x
		var near := at + d3 * 0.25 * _size
		var far := near + d3 * (0.9 + 0.4 * frame + 0.15 * (i % 3)) * _size
		var hw := 0.035 * _size
		_vertex(near - side * hw, _core(alpha))
		_vertex(near + side * hw, _core(alpha))
		_vertex(far, _color(0.0))
