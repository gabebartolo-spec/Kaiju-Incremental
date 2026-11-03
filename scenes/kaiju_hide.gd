class_name KaijuHide
extends AnimatableBody3D
## The kaiju's iron hide as one rigid physics body (director 2026-11-03): a capsule round him
## (FallContact.hide, tuning fall_contact) that follows the sim's kaiju every physics step, so
## debris fragments and broken building parts hit him, shatter and slide off, never pass through.
## Kinematic: nothing pushes him and he never deforms. Presentation only; the sim's own contact
## (FallContact) uses the same capsule.

var _sim: RampageSim
var _cfg: Dictionary
var _shape := CapsuleShape3D.new()


func _init(sim: RampageSim) -> void:
	_sim = sim
	_cfg = Content.section("fall_contact")
	sync_to_physics = false  # placed straight from the sim each step
	var col := CollisionShape3D.new()
	col.shape = _shape
	add_child(col)
	_follow()


func _physics_process(_delta: float) -> void:
	_follow()


## The hide now: [foot centre, head centre, radius].
func capsule() -> Array:
	return FallContact.hide(_sim, _cfg)


## `pos` moved clear of the hide (fragment_margin past its skin) when it lies inside or on it.
func outside(pos: Vector3) -> Vector3:
	var cap := capsule()
	var margin := Num.f(_cfg["fragment_margin"])
	if FallContact.hide_depth(pos, cap) <= -margin:
		return pos
	var a: Vector3 = cap[0]
	var b: Vector3 = cap[1]
	var t := clampf((pos - a).dot(b - a) / maxf(1e-6, (b - a).length_squared()), 0.0, 1.0)
	var on := a + (b - a) * t
	var away := pos - on
	if away.length_squared() < 1e-6:
		away = Vector3.RIGHT
	return on + away.normalized() * (Num.f(cap[2]) + margin)


func _follow() -> void:
	var cap := capsule()
	var a: Vector3 = cap[0]
	var b: Vector3 = cap[1]
	_shape.radius = Num.f(cap[2])
	_shape.height = a.distance_to(b) + 2.0 * _shape.radius
	position = (a + b) * 0.5  # CityView sits at the world origin, like DebrisField's pieces
