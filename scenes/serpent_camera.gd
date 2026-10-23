class_name SerpentCamera
extends RefCounted
## The serpent's own camera (director 2026-10-24, "Higher, more top-down": unlike the croc and the
## Komodo it does not swing with each turn): camera_height m up and camera_back m south of its
## aim, yaw and pitch fixed, so the whole S reads and a turn turns only the serpent. It aims at a
## point led by the head (motion critic round 3): camera_lead_s of the head's velocity ahead of it,
## less camera_behind m back along its heading, so on a long leg the head rides about a third of
## the way down the frame with the body behind it in view. The aim is followed critically damped
## (Damped, camera_follow_s), so a start, a turn or a stop eases the shot rather than jolting it.
## Presentation only (data/tuning.json "serpent").

var _cfg: Dictionary
var _chase: Damped
## The serpent's way as the shot's lead follows it: eased over camera_sway_s, so a turn swings the
## lead round gently and the head sways less on screen (round 4 critic: "damp the camera sway
## about 30%").
var _way := Vector2.ZERO


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


## The camera's transform this frame following `body`: its lead eased round with the turns.
func follow(body: SerpentBody, delta: float) -> Transform3D:
	if _way == Vector2.ZERO:
		_way = body.heading
	# eased by distance travelled, so once the serpent stops its lead holds still too
	var moving := body.speed / Num.f(_cfg["speed"])
	var ease := 1.0 - exp(-delta * moving / Num.f(_cfg["camera_sway_s"]))
	_way = _way.slerp(body.heading, ease).normalized()
	return step(target(_cfg, body, _way), delta)


## Where the camera aims for `body` now: led by the head (see the class note), along `way` (its
## eased heading; zero: the heading itself).
static func target(cfg: Dictionary, body: SerpentBody, way := Vector2.ZERO) -> Vector3:
	var ahead := body.speed * Num.f(cfg["camera_lead_s"]) - Num.f(cfg["camera_behind"])
	var at := body.pos + (body.heading if way == Vector2.ZERO else way) * ahead
	return Vector3(at.x, 0.0, at.y)


## How far down the frame (0 top, 1 bottom) a camera at `xform` (vertical `fov_deg`) sees
## `point`.
static func screen_down(xform: Transform3D, fov_deg: float, point: Vector3) -> float:
	var p := xform.affine_inverse() * point
	return 0.5 - 0.5 * (p.y / -p.z) / tan(deg_to_rad(fov_deg) * 0.5)


## How far across the frame (0 left, 1 right) a camera at `xform` (vertical `fov_deg`, `aspect`
## wide over tall) sees `point`.
static func screen_across(
	xform: Transform3D, fov_deg: float, point: Vector3, aspect := 16.0 / 9.0
) -> float:
	var p := xform.affine_inverse() * point
	return 0.5 + 0.5 * (p.x / -p.z) / (tan(deg_to_rad(fov_deg) * 0.5) * aspect)


## The middle of the body: the mean of its centreline at `samples` points from head to tail.
static func middle(body: SerpentBody, samples: int = 9) -> Vector3:
	var sum := Vector2.ZERO
	for k: int in samples:
		sum += body.centre_at(body.length() * k / (samples - 1.0))
	var mid := sum / samples
	return Vector3(mid.x, 0.0, mid.y)
