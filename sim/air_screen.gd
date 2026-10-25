class_name AirScreen
extends RefCounted
## Where a helicopter and the kaiju fall on the player's screen (D-183, director 2026-10-25: nothing
## is ever drawn over the hero). A pinhole model of the gameplay camera from its data (`camera`:
## offset x zoom, vertical fov) looking at the pilots' smoothed anchor: the kaiju's hull is a box
## (snout to tail, a body radius either side, kaiju_height tall) projected to a screen rectangle, a
## helicopter a circle of `heli_bound` (rotor disc and hull) at its altitude. They overlap when the
## circle comes within `margin` of the rectangle. Pure, no nodes.


## The camera's eye for a kaiju of `body_scale` looking at `anchor` (ground point), and the point
## it looks at (3.5 body scales up, as VehicleFade's line).
static func aim(body_scale: float, anchor: Vector2) -> Vector3:
	return Vector3(anchor.x, 3.5 * body_scale, anchor.y)


static func eye(body_scale: float, anchor: Vector2) -> Vector3:
	var cam: Dictionary = Content.section("camera")
	var rest: Array = cam["offset"]
	var zoom := Num.f(cam["zoom_base"]) + Num.f(cam["zoom_per_scale"]) * body_scale
	return aim(body_scale, anchor) + Vector3(Num.f(rest[0]), Num.f(rest[1]), Num.f(rest[2])) * zoom


## `world` on the screen: x and y in half-screen heights from the centre (so a circle stays round),
## z the depth from the eye.
static func project(body_scale: float, anchor: Vector2, world: Vector3) -> Vector3:
	var view := _basis(body_scale, anchor)
	var v := world - eye(body_scale, anchor)
	var depth := maxf(0.01, v.dot(view[0]))
	var half := tan(deg_to_rad(Num.f(Content.section("camera")["fov"])) * 0.5)
	return Vector3(v.dot(view[1]) / (depth * half), v.dot(view[2]) / (depth * half), depth)


## The kaiju's hull box on the screen (half-screen heights, as `project`).
static func hull(sim: RampageSim, anchor: Vector2) -> Rect2:
	var cfg: Dictionary = Content.section("air")["screen"]
	var bs := sim.body_scale()
	var half_len := sim.body.length() * 0.5
	var half_wide := Num.f(sim.powers_cfg["body_radius"]) * bs * Num.f(cfg["hull_pad"])
	var tall := sim.reach_height()
	var along := sim.facing
	var across := sim.facing.orthogonal()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for a: float in [-half_len, half_len]:
		for w: float in [-half_wide, half_wide]:
			for h: float in [0.0, tall]:
				var at := sim.kaiju_pos + along * a + across * w
				var p := project(bs, anchor, Vector3(at.x, sim.stand_y + h, at.y))
				lo = lo.min(Vector2(p.x, p.y))
				hi = hi.max(Vector2(p.x, p.y))
	return Rect2(lo, hi - lo)


## Does a helicopter at `pos` (ground point, at the air wing's altitude) overlap the kaiju's hull on
## the screen, within `margin` half-screen heights? The bound is `heli_bound` world units round it.
static func overlaps(sim: RampageSim, anchor: Vector2, pos: Vector2, margin: float) -> bool:
	var cfg: Dictionary = Content.section("air")["screen"]
	var bs := sim.body_scale()
	var p := project(bs, anchor, Vector3(pos.x, sim.air.altitude(), pos.y))
	var half := tan(deg_to_rad(Num.f(Content.section("camera")["fov"])) * 0.5)
	var radius := Num.f(cfg["heli_bound"]) / (p.z * half) + margin
	var box := hull(sim, anchor)
	var near := Vector2(
		clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y)
	)
	return Vector2(p.x, p.y).distance_to(near) < radius


## The camera's [forward, right, up] unit vectors looking at `anchor`.
static func _basis(body_scale: float, anchor: Vector2) -> Array[Vector3]:
	var forward := (aim(body_scale, anchor) - eye(body_scale, anchor)).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward)
	return [forward, right, up]
