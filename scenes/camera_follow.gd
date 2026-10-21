class_name CameraFollow
extends RefCounted
## The gameplay camera's follow (Rampage._place_camera), on its own so the tests replay the real
## path (R 19.4, comment #27): the aim eases toward the kaiju's drawn body, the offset eases
## toward its rest (CameraTuning offset x zoom), and the eye is the aim plus the offset. Camera A
## (D-121, research 19.3): once the kaiju has moved for "lead_hold" s, the camera slides, its aim
## with it, toward where it is going (CameraTuning.lead units, more toward the camera), eased at
## "lead_ease"/s; no new lead during a dash or leap. Only "lead_depth_share" of it runs along
## the view (the camera's z): a lead toward or away from the camera would change the kaiju's
## distance, so its size would bob and its head ride up the frame. Presentation only.

## How fast the aim catches up with the kaiju's drawn body, and the offset with its rest (1/s).
const FOCUS_FOLLOW := 12.0
const OFFSET_FOLLOW := 5.0
## The camera looks this high over the aim (per body scale).
const LOOK_UP := 3.5

var focus: Vector3
var offset: Vector3
var lead := Vector3.ZERO
var _cfg: Dictionary = Content.section("camera")
var _moving_for := 0.0
var _last := Vector3.INF


func _init(p_focus: Vector3, p_offset: Vector3) -> void:
	focus = p_focus
	offset = p_offset


## Eases toward the body at `target` and the rest offset `rest` (already zoomed).
func step(target: Vector3, rest: Vector3, delta: float) -> void:
	focus = focus.lerp(target, minf(1.0, delta * FOCUS_FOLLOW))
	offset = offset.lerp(rest, minf(1.0, delta * OFFSET_FOLLOW))


## The look-ahead from the body's position `at` this frame, for a body of `body_scale`; `hold`:
## dashing or leaping (keep the lead it has).
func step_lead(at: Vector3, body_scale: float, hold: bool, delta: float) -> void:
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
	lead = lead.lerp(target, minf(1.0, delta * Num.f(_cfg["lead_ease"])))


func eye() -> Vector3:
	return focus + offset + lead


func look_at(body_scale: float) -> Vector3:
	return focus + lead + Vector3(0, LOOK_UP * body_scale, 0)
