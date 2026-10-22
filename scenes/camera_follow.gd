class_name CameraFollow
extends RefCounted
## The gameplay camera's follow (Rampage._place_camera), on its own so the tests replay the real
## path (R 19.4, comment #27): the aim eases toward the kaiju's drawn body, the offset eases
## toward its rest (CameraTuning offset x zoom), and the eye is the aim plus the offset. Camera A
## (D-121, research 19.3): once the kaiju has moved for "lead_hold" s, the camera slides, its aim
## with it, toward where it is going (CameraTuning.lead units, more toward the camera), eased at
## "lead_ease"/s; no new lead during a dash or leap. Only "lead_depth_share" of it runs along
## the view (the camera's z): a lead toward or away from the camera would change the kaiju's
## distance, so its size would bob and its head ride up the frame; for the same reason the aim
## keeps up with the body at once along the view. Across it (and up) the aim, and the lead, are
## critically damped (Damped: velocity continuous, camera.follow_s, acceleration capped at
## camera.follow_accel per body scale), so a turn or a stop pans up to speed and back down over
## many frames, never in one (motion critic round 2). HeadFrame then tilts the aim up when the
## drawn head would ride into the frame's top margin. Presentation only.

## How fast the offset catches up with its rest (1/s).
const OFFSET_FOLLOW := 5.0
## The camera looks this high over the aim (per body scale).
const LOOK_UP := 3.5

var focus: Vector3
var offset: Vector3
var lead := Vector3.ZERO
## The scale of the body framed (the acceleration cap grows with it), as of step_lead.
var framed_scale := 1.0
## The head-room tilt (set on the first aim, for the kaiju it frames).
var head: HeadFrame
var _cfg: Dictionary = Content.section("camera")
var _moving_for := 0.0
var _last := Vector3.INF
var _chase: Damped
var _lead_chase := Damped.new()


func _init(p_focus: Vector3, p_offset: Vector3) -> void:
	focus = p_focus
	offset = p_offset
	_chase = Damped.new(p_focus)


## Eases toward the body at `target` and the rest offset `rest` (already zoomed). Along the
## view (the offset's ground direction) the aim keeps up with the body at once: a lag there would
## move the camera nearer or farther as the body walks toward or away from it (its size would bob).
func step(target: Vector3, rest: Vector3, delta: float) -> void:
	var view := Vector3(offset.x, 0.0, offset.z).normalized()
	focus += view * (target - focus).dot(view)
	_chase.value = focus
	_chase.velocity -= view * _chase.velocity.dot(view)
	var accel := Num.f(_cfg["follow_accel"]) * framed_scale
	focus = _chase.step(target, Num.f(_cfg["follow_s"]), accel, delta)
	offset = offset.lerp(rest, minf(1.0, delta * OFFSET_FOLLOW))


## The look-ahead from the body's position `at` this frame, for a body of `body_scale`; `hold`:
## dashing or leaping (keep the lead it has).
func step_lead(at: Vector3, body_scale: float, hold: bool, delta: float) -> void:
	framed_scale = body_scale
	var target := Vector3.ZERO
	if _last != Vector3.INF and delta > 0.0:
		var v := (at - _last) / delta
		v.y = 0.0
		var moving := v.length() > Num.f(_cfg["lead_moving"]) * body_scale
		_moving_for = _moving_for + delta if moving else 0.0
		if hold:
			target = lead
		elif _moving_for >= Num.f(_cfg["lead_hold"]):
			var dir := v.normalized()
			var toward := 1.0 + (Num.f(_cfg["lead_toward_camera"]) - 1.0) * maxf(0.0, dir.z)
			target = dir * CameraTuning.lead(body_scale) * toward
			target.z *= Num.f(_cfg["lead_depth_share"])
	_last = at
	_lead_chase.value = lead
	lead = _lead_chase.step(target, 1.0 / Num.f(_cfg["lead_ease"]), 0.0, delta)


func eye() -> Vector3:
	return focus + offset + lead


func look_at(body_scale: float) -> Vector3:
	return focus + lead + Vector3(0, LOOK_UP * body_scale, 0)


## Where the camera looks this frame for `kaiju` (body of `body_scale`, camera `fov` degrees):
## look_at, tilted up by HeadFrame when the drawn head would ride too high (`view`: the camera's
## fov in degrees and the camera shake's pitch this frame in radians).
func aim(kaiju: Node3D, body_scale: float, view: Vector2, delta: float) -> Vector3:
	if head == null:
		head = HeadFrame.new(kaiju)
	return head.aim(eye(), look_at(body_scale), view, delta)


## The drawn body's points the building fade keeps in sight (HeadFrame.sight).
func sight() -> PackedVector3Array:
	return head.sight() if head != null else PackedVector3Array()
