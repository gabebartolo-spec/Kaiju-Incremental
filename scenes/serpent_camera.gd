class_name SerpentCamera
extends RefCounted
## The serpent's own camera (director 2026-10-24, "Higher, more top-down": unlike the croc and the
## Komodo it does not swing with each turn): camera_height m up and camera_back m south of the
## middle of the body, its yaw and pitch fixed, so the whole S reads and a turn turns only the
## serpent. It follows the body's middle critically damped (Damped, camera_follow_s), so a start or
## a stop eases the shot rather than jolting it. Presentation only (data/tuning.json "serpent").

var _cfg: Dictionary
var _chase: Damped


## velocity: how fast the body's middle already moves. A shot that opens mid-slither starts as
## if it had been following all along (moving with it, the follow's steady lag of velocity x
## camera_follow_s behind), so the first frames do not lurch.
func _init(cfg: Dictionary, focus: Vector3, velocity := Vector3.ZERO) -> void:
	_cfg = cfg
	_chase = Damped.new(focus - velocity * Num.f(cfg["camera_follow_s"]))
	_chase.velocity = velocity


## The camera's transform this frame for a body whose middle is at `focus`.
func step(focus: Vector3, delta: float) -> Transform3D:
	var aim := _chase.step(focus, Num.f(_cfg["camera_follow_s"]), 0.0, delta)
	var offset := Vector3(0.0, Num.f(_cfg["camera_height"]), Num.f(_cfg["camera_back"]))
	return Transform3D(Basis.looking_at(-offset), aim + offset)


## The middle of the body: the mean of its centreline at `samples` points from head to tail.
static func middle(body: SerpentBody, samples: int = 9) -> Vector3:
	var sum := Vector2.ZERO
	for k: int in samples:
		sum += body.centre_at(body.length() * k / (samples - 1.0))
	var mid := sum / samples
	return Vector3(mid.x, 0.0, mid.y)
