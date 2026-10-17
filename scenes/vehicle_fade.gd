class_name VehicleFade
extends RefCounted
## A tank or helicopter between the camera and the kaiju fades to a screen door (D-025's rule
## for smoke), so a vehicle passing in front never hides the kaiju. Presentation only.

var _cfg: Dictionary
var _tanks: Callable
var _helis: Callable


## `tanks` and `helis` return the vehicle nodes now in the scene.
func _init(tanks: Callable, helis: Callable) -> void:
	_cfg = Content.section("vehicles")
	_tanks = tanks
	_helis = helis


## `kaiju_at` is the kaiju's feet; the camera looks 3.5 body scales above them.
func update(eye: Vector3, kaiju_at: Vector3, body_scale: float, delta: float) -> void:
	var at := kaiju_at + Vector3(0, 3.5 * body_scale, 0)
	var body := Num.f(Content.section("powers")["body_radius"]) * body_scale
	var step := delta / Num.f(_cfg["fade_seconds"])
	var nodes: Array = _tanks.call()
	for node: Node3D in nodes:
		_ease(node, _blocks(node.global_position, eye, at, body + Num.f(_cfg["tank_clear"])), step)
	nodes = _helis.call()
	for node: Node3D in nodes:
		_ease(node, _blocks(node.global_position, eye, at, body + Num.f(_cfg["heli_clear"])), step)


## Whether `p` is within `clear` of the line from the eye to the kaiju, nearer the eye.
static func _blocks(p: Vector3, eye: Vector3, at: Vector3, clear: float) -> bool:
	var t := clampf((p - eye).dot(at - eye) / maxf((at - eye).length_squared(), 0.001), 0.0, 1.0)
	return t < 1.0 and p.distance_to(eye.lerp(at, t)) < clear


func _ease(node: Node3D, blocks: bool, step: float) -> void:
	var now: float = node.get_meta("opacity", 1.0)
	var low := Num.f(_cfg["fade_opacity"])
	var next := move_toward(now, low if blocks else 1.0, step)
	if next != now:
		node.set_meta("opacity", next)
		VehicleParts.set_opacity(node, next)
