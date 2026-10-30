class_name TankModel
extends Node3D
## The main battle tank (D-297, D-309): a Tripo model cut into hull, turret and gun
## (assets/vehicles/tank*), voxelized per part with the texture's own colours, facing -Z, the
## node's origin under the hull's centre. The turret turns and the gun elevates about their
## real hinges (tank.parts.json); fire() kicks the gun back. At night (the street lamps lit) an
## amber beacon flashes on the turret roof (vehicles.tank_beacon). Presentation only.

const BASE := "res://assets/vehicles/tank"
## Hull paint (the model's mean colour, military olive), for wreck debris.
const PAINT := Color("6d7854")

var _turret: Node3D
var _barrel: Node3D
var _cfg: Dictionary
var _barrel_rest := Vector3.ZERO
var _muzzle := Vector3.ZERO  # in the barrel's space
var _kick := 0.0  # recoil, 1 at the shot, easing back to 0
var _beacon: MeshInstance3D  # null by day
var _clock := 0.0


func _init() -> void:
	_cfg = Content.section("vehicles")
	var parts := VehicleParts.new(BASE, Num.f(_cfg["tank_height"]))
	var centre := parts.pivot("hull") * Vector3(1, 0, 1)
	add_child(parts.build("hull", -centre, 3))
	_turret = parts.hinge("turret", self, centre, 3)
	_barrel = parts.hinge("barrel", _turret, parts.pivot("turret"), 3)
	_barrel_rest = _barrel.position
	_muzzle = Vector3(0, 0, parts.front("barrel") - parts.pivot("barrel").z)
	if Look.value("lamp_energy") > 0.0:
		_add_beacon()


func _process(delta: float) -> void:
	if _beacon != null:
		_clock += delta
		var beacon: Dictionary = _cfg["tank_beacon"]
		_beacon.visible = fposmod(_clock, Num.f(beacon["period"])) < Num.f(beacon["on"])
	_kick = maxf(0.0, _kick - delta / Num.f(_cfg["recoil_seconds"]))
	_barrel.position = _barrel_rest + Vector3(0, 0, Num.f(_cfg["recoil"]) * _kick * _kick)


## The night beacon: an emissive ball on the turret's roof, on its own beat (a seeded start).
func _add_beacon() -> void:
	var beacon: Dictionary = _cfg["tank_beacon"]
	var ball := SphereMesh.new()
	ball.radius = Num.f(beacon["size"])
	ball.height = ball.radius * 2.0
	ball.material = CityView.glow(Color(str(beacon["color"])), Num.f(beacon["energy"]))
	_beacon = MeshInstance3D.new()
	_beacon.mesh = ball
	_beacon.position = Vector3(0, Num.f(_cfg["tank_height"]) + ball.radius, 0)
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beacon)  # the node stands on the ground: the roof is tank_height up
	_clock = fposmod(float(get_instance_id()) * 0.37, Num.f(beacon["period"]))


## Turns the turret and elevates the gun toward `target` (world space), at most `turn_rate`
## radians a second, so a tank turning its hull keeps its gun on the kaiju.
func aim(target: Vector3, delta: float) -> void:
	var local := to_local(target) - _turret.position
	var yaw := atan2(-local.x, -local.z)
	var step := Num.f(_cfg["turret_turn"]) * delta
	var diff := wrapf(yaw - _turret.rotation.y, -PI, PI)
	_turret.rotation.y += clampf(diff, -step, step)
	var reach := Vector2(local.x, local.z).length()
	var pitch := atan2(local.y - _barrel_rest.y, maxf(reach, 0.01))
	var top := Num.f(_cfg["gun_elevation"])
	_barrel.rotation.x = move_toward(_barrel.rotation.x, clampf(pitch, -0.1, top), step)


## Kicks the gun back; returns the muzzle in world space, where the shell leaves.
func fire() -> Vector3:
	_kick = 1.0
	return _barrel.to_global(_muzzle)


## Where the muzzle is now (world space).
func muzzle() -> Vector3:
	return _barrel.to_global(_muzzle)


## A plain coloured box at pos (a fired shell, say).
static func box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	return mi
