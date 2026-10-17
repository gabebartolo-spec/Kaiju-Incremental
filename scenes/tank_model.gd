class_name TankModel
extends Node3D
## The main battle tank (D-042): modelled in Blender (assets/source/vehicles/build_tank.py) and
## voxelized per part (tools/blender/voxelize_parts.py) at 2x real size, desert tan, facing -Z,
## the node's origin under the hull's centre. The turret turns and the gun elevates about their
## real hinges (tank.parts.json); fire() kicks the gun back. Presentation only.

const BASE := "res://assets/vehicles/tank"
## Hull tan, for wreck debris.
const TAN := Color("b89c6a")

var _turret: Node3D
var _barrel: Node3D
var _cfg: Dictionary
var _voxel := 0.0
var _barrel_rest := Vector3.ZERO
var _muzzle := Vector3.ZERO  # in the barrel's space
var _kick := 0.0  # recoil, 1 at the shot, easing back to 0


func _init() -> void:
	_cfg = Content.section("vehicles")
	var meta := Content.load_json(BASE + ".parts.json")
	var parts: Dictionary = meta.get("parts", {})
	_voxel = Num.f(_cfg["tank_height"]) / maxf(1.0, Num.f(meta.get("height", 2)) - 1.0)
	var hull: Dictionary = parts["hull"]
	var turret: Dictionary = parts["turret"]
	var barrel: Dictionary = parts["barrel"]
	var hull_at := _pivot(hull)
	var turret_at := _pivot(turret)
	var barrel_at := _pivot(barrel)
	var centre := Vector3(hull_at.x, 0.0, hull_at.z)
	add_child(_part(hull, -centre))
	_turret = Node3D.new()
	_turret.position = turret_at - centre
	add_child(_turret)
	_turret.add_child(_part(turret, -turret_at))
	_barrel = Node3D.new()
	_barrel_rest = barrel_at - turret_at
	_barrel.position = _barrel_rest
	_turret.add_child(_barrel)
	var gun := Kvox.read(BASE.get_base_dir().path_join(str(barrel["kvox"])))
	var front := 0
	for cell: Vector3i in gun.frames[0].cells:
		front = mini(front, cell.z)
	_muzzle = Vector3(0, 0, (front - barrel_at.z / _voxel) * _voxel)
	_barrel.add_child(_build(gun, -barrel_at))


func _process(delta: float) -> void:
	_kick = maxf(0.0, _kick - delta / Num.f(_cfg["recoil_seconds"]))
	_barrel.position = _barrel_rest + Vector3(0, 0, Num.f(_cfg["recoil"]) * _kick * _kick)


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


func _pivot(part: Dictionary) -> Vector3:
	var p: Array = part["pivot"]
	return Vector3(Num.f(p[0]), Num.f(p[1]), Num.f(p[2])) * _voxel


func _part(part: Dictionary, origin: Vector3) -> MultiMeshInstance3D:
	return _build(Kvox.read(BASE.get_base_dir().path_join(str(part["kvox"]))), origin)


func _build(model: Kvox, origin: Vector3) -> MultiMeshInstance3D:
	var vox: VoxelBuilder = model.frames[0]
	vox.salt = 3
	return vox.build({}, _voxel, 0.0, origin)


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
