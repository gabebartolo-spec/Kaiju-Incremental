class_name CameraFollow
extends RefCounted
## The gameplay camera's follow (Rampage._place_camera), on its own so the tests replay the real
## path (R 19.4, comment #27): the aim eases toward the kaiju's drawn body, the offset eases
## toward its rest (CameraTuning offset x zoom), and the eye is the aim plus the offset.
## Presentation only.

## How fast the aim catches up with the kaiju's drawn body, and the offset with its rest (1/s).
const FOCUS_FOLLOW := 12.0
const OFFSET_FOLLOW := 5.0
## The camera looks this high over the aim (per body scale).
const LOOK_UP := 3.5

var focus: Vector3
var offset: Vector3


func _init(p_focus: Vector3, p_offset: Vector3) -> void:
	focus = p_focus
	offset = p_offset


## Eases toward the body at `target` and the rest offset `rest` (already zoomed).
func step(target: Vector3, rest: Vector3, delta: float) -> void:
	focus = focus.lerp(target, minf(1.0, delta * FOCUS_FOLLOW))
	offset = offset.lerp(rest, minf(1.0, delta * OFFSET_FOLLOW))


func eye() -> Vector3:
	return focus + offset


func look_at(body_scale: float) -> Vector3:
	return focus + Vector3(0, LOOK_UP * body_scale, 0)
