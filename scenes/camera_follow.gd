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
## drawn head would ride into the frame's top margin. D-330: the offset is held in the camera's
## own frame and turned by `yaw`, which eases (camera.turn_follow /s) to sit behind his facing,
## so the camera stays at his back and turns with him, as heavy as his turn. Presentation only.

## How fast the offset catches up with its rest (1/s).
const OFFSET_FOLLOW := 5.0
## The camera looks this high over the aim (per body scale).
const LOOK_UP := 3.5

var focus: Vector3
var offset: Vector3
var lead := Vector3.ZERO
## The camera's turn round the body (radians about +y; 0 = the offset as tuned, behind a body
## facing -z).
var yaw := 0.0
## The scale of the body framed (the acceleration cap grows with it), as of step_lead.
var framed_scale := 1.0
## The head-room tilt (set on the first aim, for the kaiju it frames).
var head: HeadFrame
var _cfg: Dictionary = Content.section("camera")
var _moving_for := 0.0
var _yaw_set := false
var _last := Vector3.INF
var _chase: Damped
var _lead_chase := Damped.new()


func _init(p_focus: Vector3, p_offset: Vector3) -> void:
	focus = p_focus
	offset = p_offset
	_chase = Damped.new(p_focus)


## Eases toward the body at `target` and the rest offset `p_rest` (already zoomed). Along the
## view (the offset's ground direction) the aim keeps up with the body at once: a lag there would
## move the camera nearer or farther as the body walks toward or away from it (its size would bob).
func step(target: Vector3, p_rest: Vector3, delta: float) -> void:
	var turned := _turned(offset)
	var view := Vector3(turned.x, 0.0, turned.z).normalized()
	focus += view * (target - focus).dot(view)
	_chase.value = focus
	_chase.velocity -= view * _chase.velocity.dot(view)
	var accel := Num.f(_cfg["follow_accel"]) * framed_scale
	focus = _chase.step(target, Num.f(_cfg["follow_s"]), accel, delta)
	offset = offset.lerp(p_rest, minf(1.0, delta * OFFSET_FOLLOW))


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
			var dir := v.normalized().rotated(Vector3.UP, -yaw)  # in the camera's frame
			var toward := 1.0 + (Num.f(_cfg["lead_toward_camera"]) - 1.0) * maxf(0.0, dir.z)
			target = dir * CameraTuning.lead(body_scale) * toward
			target.z *= Num.f(_cfg["lead_depth_share"])
			target = _turned(target)
	_last = at
	_lead_chase.value = lead
	lead = _lead_chase.step(target, 1.0 / Num.f(_cfg["lead_ease"]), 0.0, delta)


## Eases `yaw` to sit behind a body facing `facing` (ground x, z); the first call (run start)
## or `snap` puts it there at once.
func step_yaw(facing: Vector2, delta: float, snap := false) -> void:
	if facing.length_squared() < 1e-6:
		return
	var want := atan2(-facing.x, -facing.y)
	var gap := wrapf(want - yaw, -PI, PI)
	var ease := minf(1.0, delta * Num.f(_cfg["turn_follow"]))
	yaw = want if snap or not _yaw_set else yaw + gap * ease
	_yaw_set = true


func eye() -> Vector3:
	return focus + _turned(offset) + lead


func _turned(v: Vector3) -> Vector3:
	return v.rotated(Vector3.UP, yaw)


func look_at(body_scale: float) -> Vector3:
	return focus + lead + Vector3(0, LOOK_UP * body_scale, 0)


## Where the camera looks this frame for `kaiju` (body of `body_scale`, camera `fov` degrees):
## look_at, tilted up by HeadFrame when the drawn head would ride too high (`view`: the camera's
## fov in degrees and the camera shake's pitch this frame in radians).
func aim(kaiju: Node3D, body_scale: float, view: Vector2, delta: float) -> Vector3:
	if head == null:
		head = HeadFrame.new(kaiju)
	return head.aim(eye(), look_at(body_scale), view, delta)
