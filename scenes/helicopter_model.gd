class_name HelicopterModel
extends Node3D
## The attack helicopter (D-042): modelled in Blender (assets/source/vehicles/build_heli.py) and
## voxelized per part (tools/blender/voxelize_parts.py) at 2x real size, desert tan, facing -Z,
## the node's origin under the mast, level with the wheels. The main and tail rotors spin about
## their real hubs; the chin gun aims at aim()'s target and fire() returns its muzzle.
## Presentation only.

const BASE := "res://assets/vehicles/heli"
## Body tan, for wreck debris.
const TAN := Color("b89c6a")
## Below this sine of the angle to straight down, look_at() has no stable up: keep the last aim.
const MIN_TILT := 0.05

var _main_rotor: Node3D
var _tail_rotor: Node3D
var _gun: Node3D
var _cfg: Dictionary
var _muzzle := Vector3.ZERO  # in the gun's space


func _init() -> void:
	_cfg = Content.section("vehicles")
	var parts := VehicleParts.new(BASE, Num.f(_cfg["heli_height"]))
	var centre := parts.pivot("body") * Vector3(1, 0, 1)
	add_child(parts.build("body", -centre, 5))
	_main_rotor = parts.hinge("main_rotor", self, centre, 5)
	_tail_rotor = parts.hinge("tail_rotor", self, centre, 5)
	_gun = parts.hinge("gun", self, centre, 5)
	_muzzle = Vector3(0, 0, parts.front("gun") - parts.pivot("gun").z)


func _process(delta: float) -> void:
	_main_rotor.rotation.y += delta * Num.f(_cfg["main_rotor_spin"])
	_tail_rotor.rotation.x += delta * Num.f(_cfg["tail_rotor_spin"])


## Points the chin gun at `target` (world space).
func aim(target: Vector3) -> void:
	if not _gun.is_inside_tree():
		return
	var to := target - _gun.global_position
	if to.length() > 0.01 and Vector2(to.x, to.z).length() > to.length() * MIN_TILT:
		_gun.look_at(target)


## Where the chin gun's muzzle is now (world space): where a burst leaves.
func fire() -> Vector3:
	return _gun.to_global(_muzzle)
